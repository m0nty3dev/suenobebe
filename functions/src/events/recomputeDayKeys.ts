import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { REGION, TIMEZONE } from '../config/region';

function toMadridDateKey(date: Date): string {
  const parts = new Intl.DateTimeFormat('es-ES', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date).split('/'); // dd/mm/yyyy
  return `${parts[2]}-${parts[1]}-${parts[0]}`;
}

const db = admin.firestore();

/**
 * Recalculates dayKey for events between consecutive morning_wake timestamps.
 * Triggered when a morning_wake event is created or updated (§9.4).
 *
 * dayKey rule: event belongs to the day of the most recent morning_wake <= event.startAt.
 * If no prior morning_wake exists, dayKey = local date of event.startAt.
 */
export const recomputeDayKeys = functions.firestore.onDocumentWritten(
  {
    document: 'babies/{babyId}/events/{eventId}',
    region: REGION,
    timeoutSeconds: 120,
  },
  async (event) => {
    const afterData = event.data?.after?.data();
    const beforeData = event.data?.before?.data();

    // Only process morning_wake events
    const eventType = afterData?.type ?? beforeData?.type;
    if (eventType !== 'morning_wake') return;

    // Only act on creates and meaningful updates (startAt change)
    const isCreate = !event.data?.before?.exists;
    const startAtChanged =
      afterData?.startAt?.toMillis() !== beforeData?.startAt?.toMillis();
    if (!isCreate && !startAtChanged) return;

    const babyId = event.params.babyId;
    const morningWakeStartAt = afterData?.startAt as admin.firestore.Timestamp | undefined;
    if (!morningWakeStartAt) return;

    // Find the NEXT morning_wake after this one (defines the end of the window)
    const nextMorningSnap = await db
      .collection('babies').doc(babyId)
      .collection('events')
      .where('type', '==', 'morning_wake')
      .where('startAt', '>', morningWakeStartAt)
      .orderBy('startAt')
      .limit(1)
      .get();

    const windowStart = morningWakeStartAt;
    const windowEnd = nextMorningSnap.empty
      ? null
      : nextMorningSnap.docs[0].data().startAt as admin.firestore.Timestamp;

    // dayKey for this morning_wake: local Madrid date of startAt
    const newDayKey = toMadridDateKey(morningWakeStartAt.toDate());

    // Fetch all events in [windowStart, windowEnd)
    let query = db
      .collection('babies').doc(babyId)
      .collection('events')
      .where('startAt', '>=', windowStart);
    if (windowEnd) {
      query = query.where('startAt', '<', windowEnd);
    }
    const eventsSnap = await query.get();

    // Batch-update dayKey for events that have the wrong dayKey.
    // Chunk into groups of 490 to stay under the Firestore batch limit (500).
    const toUpdate = eventsSnap.docs.filter(
      (doc) => doc.data().dayKey !== newDayKey,
    );

    for (let i = 0; i < toUpdate.length; i += 490) {
      const chunk = toUpdate.slice(i, i + 490);
      const batch = db.batch();
      for (const doc of chunk) {
        batch.update(doc.ref, { dayKey: newDayKey });
      }
      await batch.commit();
    }

    functions.logger.info(
      `recomputeDayKeys: ${toUpdate.length} events updated for baby ${babyId} to dayKey ${newDayKey} (${eventsSnap.size} in window)`,
    );
  },
);
