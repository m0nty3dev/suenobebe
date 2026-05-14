import * as functions from "firebase-functions/v2";
import { REGION } from '../config/region';
import * as admin from "firebase-admin";



export const acceptInvitation = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }

    const { code, alias } = request.data as { code: string; alias: string };
    if (!code || !alias) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "code and alias are required"
      );
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    const invitationRef = db.collection("invitations").doc(code);

    // Run in transaction to prevent race conditions
    await db.runTransaction(async (tx) => {
      const invitationDoc = await tx.get(invitationRef);

      if (!invitationDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Invitation not found");
      }

      const invitation = invitationDoc.data()!;

      if (invitation.used === true) {
        throw new functions.https.HttpsError(
          "already-exists",
          "Invitation already used"
        );
      }

      const expiresAt = invitation.expiresAt as admin.firestore.Timestamp;
      if (expiresAt.toMillis() < Date.now()) {
        throw new functions.https.HttpsError(
          "deadline-exceeded",
          "Invitation has expired"
        );
      }

      const babyId = invitation.babyId as string;
      const babyRef = db.collection("babies").doc(babyId);
      const babyDoc = await tx.get(babyRef);

      if (!babyDoc.exists) {
        throw new functions.https.HttpsError("not-found", "Baby not found");
      }

      const baby = babyDoc.data()!;
      const caregivers = baby.caregivers as string[];

      if (caregivers.includes(uid)) {
        throw new functions.https.HttpsError(
          "already-exists",
          "You are already a caregiver for this baby"
        );
      }

      if (caregivers.length >= 2) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "This baby already has 2 caregivers"
        );
      }

      // Add caregiver to baby
      tx.update(babyRef, {
        caregivers: admin.firestore.FieldValue.arrayUnion(uid),
        [`caregiversInfo.${uid}`]: {
          alias,
          role: "caregiver",
          joinedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Mark invitation as used
      tx.update(invitationRef, {
        used: true,
        usedBy: uid,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update user's currentBabyId if they don't have one
      const userRef = db.collection("users").doc(uid);
      const userDoc = await tx.get(userRef);
      if (userDoc.exists && !userDoc.data()?.currentBabyId) {
        tx.update(userRef, {
          currentBabyId: babyId,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

    functions.logger.info("Invitation accepted", { code, uid });
    return { success: true };
  }
);

