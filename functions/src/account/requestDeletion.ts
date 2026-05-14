import * as functions from "firebase-functions/v2";
import { REGION } from '../config/region';
import * as admin from "firebase-admin";


const GRACE_PERIOD_DAYS = 7;

export const requestAccountDeletion = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    const deletionScheduledAt = admin.firestore.Timestamp.fromMillis(
      Date.now() + GRACE_PERIOD_DAYS * 24 * 60 * 60 * 1000
    );

    await db.collection("users").doc(uid).update({
      deletionScheduledAt,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info("Account deletion requested", { uid, deletionScheduledAt });
    return { success: true, deletionScheduledAt };
  }
);

export const cancelAccountDeletion = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    await db.collection("users").doc(uid).update({
      deletionScheduledAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    functions.logger.info("Account deletion cancelled", { uid });
    return { success: true };
  }
);

