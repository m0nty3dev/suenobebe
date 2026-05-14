import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { REGION } from '../config/region';

const db = admin.firestore();

async function markExpired(refs: admin.firestore.DocumentReference[]): Promise<void> {
  const chunks = [];
  for (let i = 0; i < refs.length; i += 490) {
    chunks.push(refs.slice(i, i + 490));
  }
  for (const chunk of chunks) {
    const batch = db.batch();
    for (const ref of chunk) {
      batch.update(ref, {
        'subscription.status': 'trial_expired',
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

export const expireTrials = functions.scheduler.onSchedule(
  {
    schedule: '0 * * * *', // every hour
    timeZone: 'Europe/Madrid',
    region: REGION,
  },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const toExpire: admin.firestore.DocumentReference[] = [];

    // Babies in 'trial' status whose expiresAt or hardExpiresAt has passed
    const trialSnap = await db
      .collection('babies')
      .where('subscription.status', '==', 'trial')
      .get();

    for (const doc of trialSnap.docs) {
      const trial = doc.data().trial as {
        expiresAt?: admin.firestore.Timestamp;
        hardExpiresAt?: admin.firestore.Timestamp;
      };
      const expired =
        (trial?.expiresAt && trial.expiresAt.toMillis() <= now.toMillis()) ||
        (trial?.hardExpiresAt && trial.hardExpiresAt.toMillis() <= now.toMillis());
      if (expired) toExpire.push(doc.ref);
    }

    // Babies in 'none' status whose hardExpiresAt has passed (never registered an event).
    // Firestore-level filter avoids loading entire collection.
    // Requires composite index: subscription.status ASC + trial.hardExpiresAt ASC.
    const noneSnap = await db
      .collection('babies')
      .where('subscription.status', '==', 'none')
      .where('trial.hardExpiresAt', '<=', now)
      .get();

    for (const doc of noneSnap.docs) {
      toExpire.push(doc.ref);
    }

    if (toExpire.length > 0) {
      await markExpired(toExpire);
      functions.logger.info(`Expired ${toExpire.length} trials`);
    }
  },
);
