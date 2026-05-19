import * as functions from 'firebase-functions/v2';
import { onTaskDispatched } from 'firebase-functions/v2/tasks';
import * as admin from 'firebase-admin';
import { getFunctions } from 'firebase-admin/functions';
import { REGION } from '../config/region';

const db = admin.firestore();

interface EventDoc {
  type: string;
  startAt: admin.firestore.Timestamp;
  endAt?: admin.firestore.Timestamp;
  durationSec?: number;
  dayKey: string;
  metadata?: { bottleMl?: number };
}

interface NightWakeInterval {
  startMs: number;
  endMs: number;
}

function prevDayKey(dayKey: string): string {
  const d = new Date(dayKey + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().substring(0, 10);
}

function nextDayKey(dayKey: string): string {
  const d = new Date(dayKey + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().substring(0, 10);
}

async function computeAndWriteDay(babyId: string, dayKey: string): Promise<void> {
  const snap = await db
    .collection('babies').doc(babyId)
    .collection('events').where('dayKey', '==', dayKey).get();

  const events = snap.docs.map((d) => d.data() as EventDoc);

  let totalSleepDayMinutes = 0;
  let totalSleepNightMinutes = 0;
  let napCount = 0;
  let nightWakeCount = 0;
  let feedingCount = 0;
  let totalFeedingMinutes = 0;
  let totalBottleMl = 0;
  let morningWakeAt: admin.firestore.Timestamp | null = null;
  let bedtimeAt: admin.firestore.Timestamp | null = null;
  // Collect closed night_wake intervals to subtract from night sleep duration.
  const nightWakeIntervals: NightWakeInterval[] = [];

  for (const e of events) {
    const durSec = e.durationSec
      ?? (e.endAt ? (e.endAt.toMillis() - e.startAt.toMillis()) / 1000 : 0);
    const dur = Math.round(durSec / 60);

    switch (e.type) {
      case 'nap':
        napCount++;
        totalSleepDayMinutes += dur;
        break;
      case 'night_wake':
        // Counts wakes, does NOT contribute to sleep minutes.
        nightWakeCount++;
        if (e.endAt) {
          nightWakeIntervals.push({ startMs: e.startAt.toMillis(), endMs: e.endAt.toMillis() });
        } else {
          // Live night_wake: subtract up to now so night sleep is not overstated
          // while the baby is still awake. Auto-corrects when endAt is written.
          nightWakeIntervals.push({ startMs: e.startAt.toMillis(), endMs: Date.now() });
        }
        break;
      case 'bedtime':
        // Take earliest bedtime if multiple
        if (!bedtimeAt || e.startAt.toMillis() < bedtimeAt.toMillis()) {
          bedtimeAt = e.startAt;
        }
        break;
      case 'morning_wake':
        // Take earliest morningWake if multiple
        if (!morningWakeAt || e.startAt.toMillis() < morningWakeAt.toMillis()) {
          morningWakeAt = e.startAt;
        }
        break;
      case 'nursing':
      case 'bottle':
        feedingCount++;
        totalFeedingMinutes += dur;
        if (e.type === 'bottle' && e.metadata?.bottleMl) {
          totalBottleMl += e.metadata.bottleMl;
        }
        break;
    }
  }

  // Night sleep: bedtime of this day → morningWake of the NEXT day (§7 spec),
  // minus the time the baby was awake during the night (night_wake intervals).
  if (bedtimeAt) {
    const ndk = nextDayKey(dayKey);
    const nextMorningSnap = await db
      .collection('babies').doc(babyId)
      .collection('events')
      .where('dayKey', '==', ndk)
      .where('type', '==', 'morning_wake')
      .orderBy('startAt')
      .limit(1)
      .get();

    let nightEnd: admin.firestore.Timestamp;
    if (!nextMorningSnap.empty) {
      nightEnd = nextMorningSnap.docs[0].data().startAt as admin.firestore.Timestamp;
    } else {
      // No morningWake yet — use now as live estimate (capped at 12h)
      nightEnd = admin.firestore.Timestamp.fromMillis(Date.now());
    }

    const windowStart = bedtimeAt.toMillis();
    const windowEnd = nightEnd.toMillis();
    let nightMins = Math.round((windowEnd - windowStart) / 60000);

    // Subtract night_wake durations that overlap with [bedtime, morningWake].
    for (const nw of nightWakeIntervals) {
      const overlapStart = Math.max(nw.startMs, windowStart);
      const overlapEnd = Math.min(nw.endMs, windowEnd);
      if (overlapEnd > overlapStart) {
        nightMins -= Math.round((overlapEnd - overlapStart) / 60000);
      }
    }

    // Cap at 720 min (12 h) — anything longer is a data anomaly.
    // Clamp instead of dropping so the value is never silently zeroed.
    if (nightMins > 0) {
      totalSleepNightMinutes = Math.min(nightMins, 720);
    }
  }

  await db.collection('babies').doc(babyId)
    .collection('dailyStats').doc(dayKey).set({
      date: dayKey,
      totalSleepDayMinutes,
      totalSleepNightMinutes,
      totalSleepMinutes: totalSleepDayMinutes + totalSleepNightMinutes,
      napCount,
      nightWakeCount,
      feedingCount,
      totalFeedingMinutes,
      totalBottleMl,
      morningWakeAt,
      bedtimeAt,
      eventsCount: events.length,
      computedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: false });
}

// Firestore trigger: enqueues a deduplicated Cloud Task instead of computing
// directly. Multiple rapid event writes for the same babyId+dayKey within the
// 10-second delay window result in a single computation (deduplication via task ID).
export const computeDailyStats = functions.firestore.onDocumentWritten(
  {
    document: 'babies/{babyId}/events/{eventId}',
    region: REGION,
    timeoutSeconds: 30,
  },
  async (event) => {
    const babyId = event.params.babyId;
    const afterData = event.data?.after?.data() as EventDoc | undefined;
    const beforeData = event.data?.before?.data() as EventDoc | undefined;
    const dayKey = afterData?.dayKey ?? beforeData?.dayKey;
    const eventType = afterData?.type ?? beforeData?.type;
    if (!dayKey) return;

    // Task ID = babyId-dayKey: tasks with the same ID are deduplicated within
    // Cloud Tasks' 4-minute window. Rapid burst of writes → one computation.
    const taskId = `${babyId}-${dayKey}`;
    const queue = getFunctions().taskQueue(
      `locations/${REGION}/functions/computeDailyStatsTask`,
    );

    try {
      await queue.enqueue(
        { babyId, dayKey, eventType },
        { id: taskId, scheduleDelaySeconds: 10 },
      );
    } catch (err: unknown) {
      const code = (err as { code?: number }).code;
      const msg = (err as { message?: string }).message ?? '';
      if (code === 6 || msg.includes('ALREADY_EXISTS')) {
        // Task already queued for this babyId+dayKey — nothing to do.
        return;
      }
      // Cloud Tasks unavailable (e.g. queue not yet created after fresh deploy):
      // fall back to direct computation so stats are never silently skipped.
      functions.logger.warn('Cloud Tasks enqueue failed, falling back to direct computation', { err, babyId, dayKey });
      await computeAndWriteDay(babyId, dayKey);
      if (eventType === 'morning_wake') {
        const pdk = prevDayKey(dayKey);
        const prevStatsDoc = await db.collection('babies').doc(babyId).collection('dailyStats').doc(pdk).get();
        if (prevStatsDoc.exists) await computeAndWriteDay(babyId, pdk);
      }
      if (eventType === 'bedtime') {
        const ndk = nextDayKey(dayKey);
        const nextStatsDoc = await db.collection('babies').doc(babyId).collection('dailyStats').doc(ndk).get();
        if (nextStatsDoc.exists) await computeAndWriteDay(babyId, ndk);
      }
    }
  }
);

// Cloud Tasks handler: does the actual stats computation. The queue is named
// 'computeDailyStatsTask' and is auto-created by Firebase on first deploy.
export const computeDailyStatsTask = onTaskDispatched(
  {
    retryConfig: { maxAttempts: 3, minBackoffSeconds: 10 },
    rateLimits: { maxConcurrentDispatches: 5 },
    region: REGION,
  },
  async (req) => {
    const { babyId, dayKey, eventType } = req.data as {
      babyId: string;
      dayKey: string;
      eventType?: string;
    };

    await computeAndWriteDay(babyId, dayKey);

    // If a morning_wake was written, also recompute the PREVIOUS day
    // because that day's night sleep ends with this morningWake.
    if (eventType === 'morning_wake') {
      const pdk = prevDayKey(dayKey);
      const prevStatsDoc = await db
        .collection('babies').doc(babyId)
        .collection('dailyStats').doc(pdk).get();
      if (prevStatsDoc.exists) {
        await computeAndWriteDay(babyId, pdk);
      }
    }

    // If a bedtime was written, also recompute the NEXT day.
    if (eventType === 'bedtime') {
      const ndk = nextDayKey(dayKey);
      const nextStatsDoc = await db
        .collection('babies').doc(babyId)
        .collection('dailyStats').doc(ndk).get();
      if (nextStatsDoc.exists) {
        await computeAndWriteDay(babyId, ndk);
      }
    }
  },
);
