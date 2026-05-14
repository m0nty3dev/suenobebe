import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { REGION } from '../config/region';

const db = admin.firestore();

interface UpdateEventData {
  babyId: string;
  eventId: string;
  startAt?: number;
  endAt?: number | null;
  bottleMl?: number | null;
  note?: string | null;
  leftDurationSec?: number | null;
  rightDurationSec?: number | null;
}

export const updateEventCallable = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    const uid = request.auth.uid;
    const data = request.data as UpdateEventData;

    if (!data.babyId || !data.eventId) {
      throw new functions.https.HttpsError('invalid-argument', 'babyId and eventId are required');
    }

    // Verify caller is a caregiver
    const babySnap = await db.collection('babies').doc(data.babyId).get();
    if (!babySnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Baby not found');
    }
    if (!(babySnap.data()!.caregivers as string[]).includes(uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not a caregiver');
    }

    // Fetch existing event
    const eventRef = db
      .collection('babies').doc(data.babyId)
      .collection('events').doc(data.eventId);
    const eventSnap = await eventRef.get();
    if (!eventSnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Event not found');
    }
    const existing = eventSnap.data()!;

    const startAt = data.startAt != null
      ? admin.firestore.Timestamp.fromMillis(data.startAt)
      : existing.startAt as admin.firestore.Timestamp;

    const endAt = data.endAt !== undefined
      ? (data.endAt != null ? admin.firestore.Timestamp.fromMillis(data.endAt) : null)
      : existing.endAt as admin.firestore.Timestamp | null;

    // Validate no-overlap (exclude this event itself)
    if (endAt != null) {
      const overlapSnap = await db
        .collection('babies').doc(data.babyId)
        .collection('events')
        .where('dayKey', '==', existing.dayKey)
        .where('startAt', '<', endAt)
        .get();

      for (const doc of overlapSnap.docs) {
        if (doc.id === data.eventId) continue;
        const ev = doc.data();
        const evEnd = ev.endAt ?? admin.firestore.Timestamp.fromMillis(Date.now());
        if (evEnd.toMillis() > startAt.toMillis()) {
          throw new functions.https.HttpsError(
            'already-exists',
            `Se solapa con ${ev.type} a las ${new Date(ev.startAt.toMillis()).toLocaleTimeString('es-ES')}`,
          );
        }
      }
    }

    let durationSec: number | null = null;
    if (endAt != null) {
      durationSec = Math.round((endAt.toMillis() - startAt.toMillis()) / 1000);
    }

    const updates: Record<string, unknown> = {
      startAt,
      updatedAt: admin.firestore.Timestamp.fromMillis(Date.now()),
    };

    if (endAt !== undefined) updates['endAt'] = endAt;
    if (durationSec !== null) updates['durationSec'] = durationSec;
    if (data.bottleMl !== undefined) updates['metadata.bottleMl'] = data.bottleMl;
    if (data.note !== undefined) updates['metadata.note'] = data.note;
    if (data.leftDurationSec !== undefined) updates['metadata.leftDurationSec'] = data.leftDurationSec;
    if (data.rightDurationSec !== undefined) updates['metadata.rightDurationSec'] = data.rightDurationSec;

    await eventRef.update(updates);
    return { success: true };
  },
);
