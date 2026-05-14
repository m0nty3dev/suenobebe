import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { REGION } from '../config/region';

const db = admin.firestore();

interface CreateEventData {
  babyId: string;
  type: string;
  startAt: number; // epoch ms
  endAt?: number | null;
  durationSec?: number | null;
  status: 'live' | 'completed';
  dayKey: string;
  metadata?: {
    breast?: string | null;
    leftDurationSec?: number | null;
    rightDurationSec?: number | null;
    bottleMl?: number | null;
    note?: string | null;
  };
}

export const createEventCallable = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'Not authenticated');
    }

    const uid = request.auth.uid;
    const data = request.data as CreateEventData;

    if (!data.babyId || !data.type || !data.startAt || !data.dayKey || !data.status) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    // Verify caller is a caregiver
    const babyRef = db.collection('babies').doc(data.babyId);
    const babySnap = await babyRef.get();
    if (!babySnap.exists) {
      throw new functions.https.HttpsError('not-found', 'Baby not found');
    }
    const baby = babySnap.data()!;
    if (!(baby.caregivers as string[]).includes(uid)) {
      throw new functions.https.HttpsError('permission-denied', 'Not a caregiver');
    }

    const startAt = admin.firestore.Timestamp.fromMillis(data.startAt);
    const endAt = data.endAt != null
      ? admin.firestore.Timestamp.fromMillis(data.endAt)
      : null;

    // For completed events, validate no-overlap
    if (data.status === 'completed') {
      const effectiveEnd = endAt ?? startAt;
      const overlapSnap = await db
        .collection('babies').doc(data.babyId)
        .collection('events')
        .where('dayKey', '==', data.dayKey)
        .where('startAt', '<', effectiveEnd)
        .get();

      for (const doc of overlapSnap.docs) {
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

    const now = admin.firestore.Timestamp.fromMillis(Date.now());

    return await db.runTransaction(async (tx) => {
      // Close any existing live event
      if (data.status === 'live') {
        const liveSnap = await db
          .collection('babies').doc(data.babyId)
          .collection('events')
          .where('status', '==', 'live')
          .limit(1)
          .get();
        if (!liveSnap.empty) {
          const liveDoc = liveSnap.docs[0];
          const liveEv = liveDoc.data();
          const liveDur = Math.round(
            (now.toMillis() - liveEv.startAt.toMillis()) / 1000,
          );
          tx.update(liveDoc.ref, {
            status: 'completed',
            endAt: now,
            durationSec: liveDur,
            updatedAt: now,
          });
        }
      }

      // Set trial.firstEventAt if empty
      const trial = baby.trial as Record<string, unknown> | undefined;
      if (!trial?.firstEventAt) {
        tx.update(babyRef, { 'trial.firstEventAt': now });
      }

      // Create the event
      const eventRef = db
        .collection('babies').doc(data.babyId)
        .collection('events').doc();

      const eventData = {
        type: data.type,
        startAt,
        endAt,
        durationSec: data.durationSec ?? null,
        status: data.status,
        dayKey: data.dayKey,
        metadata: {
          breast: data.metadata?.breast ?? null,
          leftDurationSec: data.metadata?.leftDurationSec ?? null,
          rightDurationSec: data.metadata?.rightDurationSec ?? null,
          bottleMl: data.metadata?.bottleMl ?? null,
          note: data.metadata?.note ?? null,
        },
        createdBy: uid,
        createdAt: now,
        updatedAt: now,
      };

      tx.set(eventRef, eventData);

      return { eventId: eventRef.id, isFirstEvent: !trial?.firstEventAt };
    });
  },
);
