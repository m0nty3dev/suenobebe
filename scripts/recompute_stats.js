/**
 * Recomputes dailyStats for all babies for the last N days.
 *
 * Usage:
 *   node scripts/recompute_stats.js [days]
 *
 * Examples:
 *   node scripts/recompute_stats.js        # last 30 days (default)
 *   node scripts/recompute_stats.js 60     # last 60 days
 *
 * Requires: firebase-admin, scripts/serviceAccountKey.json
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const DAYS = parseInt(process.argv[2] ?? '30', 10);

// Madrid timezone helper
function toMadridDateKey(date) {
  const parts = new Intl.DateTimeFormat('es-ES', {
    timeZone: 'Europe/Madrid',
    year: 'numeric', month: '2-digit', day: '2-digit',
  }).format(date).split('/');
  return `${parts[2]}-${parts[1]}-${parts[0]}`;
}

function prevDayKey(dayKey) {
  const d = new Date(dayKey + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() - 1);
  return d.toISOString().substring(0, 10);
}

function nextDayKey(dayKey) {
  const d = new Date(dayKey + 'T00:00:00Z');
  d.setUTCDate(d.getUTCDate() + 1);
  return d.toISOString().substring(0, 10);
}

/** Same logic as computeDailyStats Cloud Function. */
async function computeAndWriteDay(babyId, dayKey) {
  const snap = await db
    .collection('babies').doc(babyId)
    .collection('events').where('dayKey', '==', dayKey).get();

  const events = snap.docs.map(d => d.data());

  let totalSleepDayMinutes = 0;
  let totalSleepNightMinutes = 0;
  let napCount = 0;
  let nightWakeCount = 0;
  let feedingCount = 0;
  let totalFeedingMinutes = 0;
  let totalBottleMl = 0;
  let morningWakeAt = null;
  let bedtimeAt = null;
  const nightWakeIntervals = [];

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
        nightWakeCount++;
        if (e.endAt) {
          nightWakeIntervals.push({ startMs: e.startAt.toMillis(), endMs: e.endAt.toMillis() });
        }
        break;
      case 'bedtime':
        if (!bedtimeAt || e.startAt.toMillis() < bedtimeAt.toMillis()) bedtimeAt = e.startAt;
        break;
      case 'morning_wake':
        if (!morningWakeAt || e.startAt.toMillis() < morningWakeAt.toMillis()) morningWakeAt = e.startAt;
        break;
      case 'nursing':
      case 'bottle':
        feedingCount++;
        totalFeedingMinutes += dur;
        if (e.type === 'bottle' && e.metadata?.bottleMl) totalBottleMl += e.metadata.bottleMl;
        break;
    }
  }

  // Night sleep: bedtime → morningWake of next day, minus night_wake intervals
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

    const nightEnd = nextMorningSnap.empty
      ? admin.firestore.Timestamp.fromMillis(Date.now())
      : nextMorningSnap.docs[0].data().startAt;

    const windowStart = bedtimeAt.toMillis();
    const windowEnd = nightEnd.toMillis();
    let nightMins = Math.round((windowEnd - windowStart) / 60000);

    for (const nw of nightWakeIntervals) {
      const overlapStart = Math.max(nw.startMs, windowStart);
      const overlapEnd = Math.min(nw.endMs, windowEnd);
      if (overlapEnd > overlapStart) nightMins -= Math.round((overlapEnd - overlapStart) / 60000);
    }

    if (nightMins > 0 && nightMins <= 720) totalSleepNightMinutes = nightMins;
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

async function main() {
  const now = new Date();
  const dayKeys = [];
  for (let i = 0; i < DAYS; i++) {
    const d = new Date(now.getTime() - i * 24 * 60 * 60 * 1000);
    dayKeys.push(toMadridDateKey(d));
  }

  const babiesSnap = await db.collection('babies').get();
  console.log(`Recomputing ${DAYS} days for ${babiesSnap.size} babies...`);

  let total = 0;
  for (const babyDoc of babiesSnap.docs) {
    const babyId = babyDoc.id;
    const babyName = babyDoc.data().name ?? babyId;
    process.stdout.write(`  [${babyName}] `);

    for (const dayKey of dayKeys) {
      await computeAndWriteDay(babyId, dayKey);
      process.stdout.write('.');
      total++;
    }
    console.log(` ${dayKeys.length} days OK`);
  }

  console.log(`\nDone. ${total} dailyStats documents written.`);
  process.exit(0);
}

main().catch(err => {
  console.error(err);
  process.exit(1);
});
