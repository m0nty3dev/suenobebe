import * as functions from "firebase-functions/v2";
import { REGION } from '../config/region';
import * as admin from "firebase-admin";



const BATCH_LIMIT = 490;

async function deleteSubcollections(
  db: admin.firestore.Firestore,
  docRef: admin.firestore.DocumentReference
): Promise<void> {
  const subcollections = await docRef.listCollections();
  for (const sub of subcollections) {
    const snap = await sub.get();
    // Chunk to stay under Firestore batch limit (500).
    for (let i = 0; i < snap.docs.length; i += BATCH_LIMIT) {
      const chunk = snap.docs.slice(i, i + BATCH_LIMIT);
      const batch = db.batch();
      chunk.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }
}

async function deleteBabyAndData(
  db: admin.firestore.Firestore,
  babyId: string
): Promise<void> {
  const babyRef = db.collection("babies").doc(babyId);

  // Delete subcollections in chunks to avoid batch limit.
  const subcollections = await babyRef.listCollections();
  for (const sub of subcollections) {
    const snap = await sub.get();
    for (let i = 0; i < snap.docs.length; i += BATCH_LIMIT) {
      const chunk = snap.docs.slice(i, i + BATCH_LIMIT);
      const batch = db.batch();
      chunk.forEach((doc) => batch.delete(doc.ref));
      await batch.commit();
    }
  }

  // Delete baby photo from Storage
  try {
    const bucket = admin.storage().bucket();
    await bucket.file(`babies/${babyId}/photo.jpg`).delete();
  } catch {
    // File may not exist
  }

  // Delete baby document
  await babyRef.delete();
  functions.logger.info("Baby deleted", { babyId });
}

export const cleanupGracePeriod = functions.scheduler.onSchedule(
  {
    schedule: "0 4 * * *", // daily at 04:00
    timeZone: "Europe/Madrid",
    region: REGION,
  },
  async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();

    // Find users whose deletion grace period has passed
    const usersSnap = await db
      .collection("users")
      .where("deletionScheduledAt", "<=", now)
      .get();

    for (const userDoc of usersSnap.docs) {
      const uid = userDoc.id;
      void userDoc.data();

      functions.logger.info("Processing account deletion", { uid });

      try {
        // Find babies where this user is a caregiver
        const babiesSnap = await db
          .collection("babies")
          .where("caregivers", "array-contains", uid)
          .get();

        for (const babyDoc of babiesSnap.docs) {
          const babyId = babyDoc.id;
          const baby = babyDoc.data();
          const caregivers = baby.caregivers as string[];
          const adminId = baby.adminId as string;

          const remainingCaregivers = caregivers.filter((c) => c !== uid);

          if (remainingCaregivers.length === 0) {
            // No other caregivers — schedule baby for deletion
            // Check if baby already has a deletionScheduledAt
            if (!baby.deletionScheduledAt) {
              const babyDeletionAt = admin.firestore.Timestamp.fromMillis(
                Date.now() + 7 * 24 * 60 * 60 * 1000
              );
              await db.collection("babies").doc(babyId).update({
                deletionScheduledAt: babyDeletionAt,
              });
            } else {
              // Grace period for baby already passed
              const babyDeletionAt = baby.deletionScheduledAt as admin.firestore.Timestamp;
              if (babyDeletionAt.toMillis() <= now.toMillis()) {
                await deleteBabyAndData(db, babyId);
              }
            }
          } else {
            // Other caregivers remain — remove this user
            const updates: Record<string, unknown> = {
              caregivers: admin.firestore.FieldValue.arrayRemove(uid),
              [`caregiversInfo.${uid}`]: admin.firestore.FieldValue.delete(),
              updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            };

            // Transfer admin if needed
            if (adminId === uid && remainingCaregivers.length > 0) {
              updates.adminId = remainingCaregivers[0];
              // Update role in caregiversInfo
              updates[`caregiversInfo.${remainingCaregivers[0]}.role`] = "admin";
            }

            await db.collection("babies").doc(babyId).update(updates);
            functions.logger.info("Removed caregiver from baby", { uid, babyId });
          }
        }

        // Delete user document and subcollections
        await deleteSubcollections(db, userDoc.ref);
        await userDoc.ref.delete();

        // Delete Firebase Auth account
        await admin.auth().deleteUser(uid);

        // Remove FCM exports from Storage
        try {
          const bucket = admin.storage().bucket();
          await bucket.deleteFiles({ prefix: `exports/${uid}/` });
        } catch {
          // May not exist
        }

        functions.logger.info("User account deleted", { uid });
      } catch (err: unknown) {
        functions.logger.error("Error deleting user account", { uid, err });
      }
    }

    functions.logger.info("Cleanup grace period completed");
  }
);

