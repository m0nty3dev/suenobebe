import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { REGION, TIMEZONE } from '../config/region';

const FALLBACK_MORNING_WAKE = '08:00';
const FALLBACK_BEDTIME = '22:00';

interface SleepDefault {
  minMonths: number;
  maxMonths: number;
  morningWake: string;
  bedtime: string;
}

function ageInMonths(birthDate: Date, now: Date): number {
  return (
    (now.getFullYear() - birthDate.getFullYear()) * 12 +
    (now.getMonth() - birthDate.getMonth())
  );
}

function timeToMinutes(t: string): number {
  const [h, m] = t.split(':').map(Number);
  return h * 60 + m;
}

function minutesToTime(mins: number): string {
  const h = Math.floor(mins / 60) % 24;
  const m = Math.round(mins % 60);
  return `${String(h).padStart(2, '0')}:${String(m).padStart(2, '0')}`;
}

function averageTimes(times: string[]): string {
  if (times.length === 0) return FALLBACK_MORNING_WAKE;
  const total = times.reduce((sum, t) => sum + timeToMinutes(t), 0);
  return minutesToTime(total / times.length);
}

/** Format a UTC timestamp as HH:MM in Madrid timezone. */
function toMadridHHMM(date: Date): string {
  return new Intl.DateTimeFormat('es-ES', {
    timeZone: TIMEZONE,
    hour: '2-digit',
    minute: '2-digit',
    hour12: false,
  }).format(date).replace(':', ':'); // e.g. "07:30"
}

/** Get YYYY-MM-DD in Madrid timezone. */
function toMadridDateKey(date: Date): string {
  const parts = new Intl.DateTimeFormat('es-ES', {
    timeZone: TIMEZONE,
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(date).split('/'); // dd/mm/yyyy
  return `${parts[2]}-${parts[1]}-${parts[0]}`;
}

export const recomputeEstimates = functions.scheduler.onSchedule(
  {
    schedule: '0 3 * * *', // daily at 03:00 Madrid time
    timeZone: TIMEZONE,
    region: REGION,
  },
  async () => {
    const db = admin.firestore();

    // Load sleep defaults
    const configDoc = await db.collection('config').doc('sleep_defaults').get();
    const sleepDefaults: SleepDefault[] = configDoc.exists
      ? (configDoc.data()!.ranges as SleepDefault[])
      : [];

    const babiesSnap = await db.collection('babies').get();
    const now = new Date();
    const todayKey = toMadridDateKey(now);

    // 7 days ago in Madrid timezone
    const sevenDaysAgoDate = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const fromKey = toMadridDateKey(sevenDaysAgoDate);

    // Process babies in parallel chunks of 50 to avoid N+1 sequential queries
    // that would exceed Cloud Function timeout at scale.
    const CHUNK_SIZE = 50;
    const BATCH_LIMIT = 490;
    const docs = babiesSnap.docs;

    for (let chunkStart = 0; chunkStart < docs.length; chunkStart += CHUNK_SIZE) {
      const chunkDocs = docs.slice(chunkStart, chunkStart + CHUNK_SIZE);

      const updates = await Promise.all(
        chunkDocs.map(async (babyDoc) => {
          const baby = babyDoc.data();
          const birthDate = baby.birthDate?.toDate?.() as Date | undefined;

          let defaultMorningWake = FALLBACK_MORNING_WAKE;
          let defaultBedtime = FALLBACK_BEDTIME;
          if (birthDate) {
            const months = ageInMonths(birthDate, now);
            const match = sleepDefaults.find(
              (r) => months >= r.minMonths && months <= r.maxMonths,
            );
            if (match) {
              defaultMorningWake = match.morningWake;
              defaultBedtime = match.bedtime;
            }
          }

          const statsSnap = await db
            .collection('babies')
            .doc(babyDoc.id)
            .collection('dailyStats')
            .where(admin.firestore.FieldPath.documentId(), '>=', fromKey)
            .where(admin.firestore.FieldPath.documentId(), '<=', todayKey)
            .get();

          const morningWakeTimes: string[] = [];
          const bedtimeTimes: string[] = [];

          for (const stat of statsSnap.docs) {
            const data = stat.data();
            if (data.morningWakeAt) {
              const t = (data.morningWakeAt as admin.firestore.Timestamp).toDate();
              morningWakeTimes.push(toMadridHHMM(t));
            }
            if (data.bedtimeAt) {
              const t = (data.bedtimeAt as admin.firestore.Timestamp).toDate();
              bedtimeTimes.push(toMadridHHMM(t));
            }
          }

          const estimatedMorningWake =
            morningWakeTimes.length > 0
              ? averageTimes(morningWakeTimes)
              : defaultMorningWake;
          const estimatedBedtime =
            bedtimeTimes.length > 0 ? averageTimes(bedtimeTimes) : defaultBedtime;

          return { ref: babyDoc.ref, estimatedMorningWake, estimatedBedtime };
        }),
      );

      // Write this chunk's updates in batches of 490.
      for (let i = 0; i < updates.length; i += BATCH_LIMIT) {
        const batchSlice = updates.slice(i, i + BATCH_LIMIT);
        const batch = db.batch();
        for (const u of batchSlice) {
          batch.update(u.ref, {
            estimatedMorningWake: u.estimatedMorningWake,
            estimatedBedtime: u.estimatedBedtime,
            estimatesRecomputedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    }

    functions.logger.info(`Estimates recomputed for ${docs.length} babies`);
  },
);
