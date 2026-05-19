import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { REGION } from '../config/region';

const db = admin.firestore();

// Guard against the race condition where a concurrent purchase validation sets
// subscription.status='active' just before this function runs. Each baby is
// updated individually via a transaction that checks the current status instead
// of a blind batch update.
async function markExpiredIfStillTrial(
  refs: admin.firestore.DocumentReference[],
): Promise<number> {
  let updated = 0;
  for (const ref of refs) {
    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(ref);
        if (!snap.exists) return;
        const currentStatus = snap.data()!['subscription']?.status as string | undefined;
        // Only expire if still in a trial/none state — never overwrite 'active'.
        if (currentStatus !== 'trial' && currentStatus !== 'none') return;
        tx.update(ref, {
          'subscription.status': 'trial_expired',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        updated++;
      });
    } catch (err) {
      functions.logger.warn('expireTrials: transaction failed for baby', { babyId: ref.id, err });
    }
  }
  return updated;
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
      const updated = await markExpiredIfStillTrial(toExpire);
      functions.logger.info(`Expired ${updated} trials (${toExpire.length} candidates checked)`);
    }
  },
);
