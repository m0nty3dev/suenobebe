import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { REGION } from '../config/region';

const db = admin.firestore();

export const deleteEventCallable = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    const uid = request.auth.uid;
    const { babyId, eventId } = request.data as { babyId: string; eventId: string };

    if (!babyId || !eventId) {
      throw new functions.https.HttpsError('invalid-argument', 'babyId and eventId are required');
    }

    // Verify caller is a caregiver
    const babySnap = await db.collection('babies').doc(babyId).get();
    if (!babySnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Baby not found');
    }
    if (!(babySnap.data()!.caregivers as string[]).includes(uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not a caregiver');
    }

    const eventRef = db.collection('babies').doc(babyId).collection('events').doc(eventId);
    const eventSnap = await eventRef.get();
    if (!eventSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Event not found');
    }

    await eventRef.delete();
    functions.logger.info('Event deleted', { babyId, eventId, deletedBy: uid });
    return { success: true };
  },
);
