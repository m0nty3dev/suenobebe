import * as functions from "firebase-functions/v2";
import { REGION } from '../config/region';
import * as admin from "firebase-admin";



function generateCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export const createInvitation = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }

    const { babyId } = request.data as { babyId: string };
    if (!babyId) {
      throw new functions.https.HttpsError("invalid-argument", "babyId is required");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    // Verify user is a caregiver of this baby
    const babyDoc = await db.collection("babies").doc(babyId).get();
    if (!babyDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Baby not found");
    }
    const baby = babyDoc.data()!;
    const caregivers = baby.caregivers as string[];

    if (!caregivers.includes(uid)) {
      throw new functions.https.HttpsError("permission-denied", "Not a caregiver of this baby");
    }

    if (caregivers.length >= 2) {
      throw new functions.https.HttpsError(
        "failed-precondition",
        "This baby already has 2 caregivers"
      );
    }

    // Generate unique code
    let code: string;
    let attempts = 0;
    do {
      code = generateCode();
      attempts++;
      if (attempts > 10) {
        throw new functions.https.HttpsError("internal", "Could not generate unique code");
      }
      const existing = await db.collection("invitations").doc(code).get();
      if (!existing.exists || existing.data()?.used === true) break;
    } while (true);

    const expiresAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + 24 * 60 * 60 * 1000
    );

    await db.collection("invitations").doc(code).set({
      babyId,
      createdBy: uid,
      expiresAt,
      used: false,
      usedBy: null,
      usedAt: null,
    });

    functions.logger.info("Invitation created", { code, babyId, createdBy: uid });
    return { code };
  }
);

