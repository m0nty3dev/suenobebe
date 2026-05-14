import * as functions from 'firebase-functions/v2';
import * as admin from 'firebase-admin';
import { REGION, TIMEZONE } from '../config/region';


const INACTIVITY_THRESHOLD_HOURS = 3;
const QUIET_HOURS_START = 22; // 22:00
const QUIET_HOURS_END = 8;    // 08:00

function isQuietHours(localHour: number): boolean {
  return localHour >= QUIET_HOURS_START || localHour < QUIET_HOURS_END;
}

function isWithinDaytime(
  localHour: number,
  estimatedMorningWake: string,
  estimatedBedtime: string
): boolean {
  const [wakeH] = estimatedMorningWake.split(":").map(Number);
  const [bedH] = estimatedBedtime.split(":").map(Number);
  return localHour >= wakeH && localHour < bedH;
}

export const checkInactivity = functions.scheduler.onSchedule(
  {
    schedule: "*/30 * * * *", // every 30 minutes
    timeZone: TIMEZONE,
    region: REGION,
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    // Convert to Europe/Madrid local hour regardless of server timezone
    const madridHour = parseInt(
      new Intl.DateTimeFormat('es-ES', {
        timeZone: TIMEZONE,
        hour: 'numeric',
        hour12: false,
      }).format(now),
      10,
    );

    // Skip quiet hours globally — most babies in same timezone in Spain
    if (isQuietHours(madridHour)) {
      functions.logger.info("Quiet hours — skipping inactivity check");
      return;
    }

    const thresholdMs = INACTIVITY_THRESHOLD_HOURS * 60 * 60 * 1000;
    const thresholdTimestamp = admin.firestore.Timestamp.fromMillis(
      Date.now() - thresholdMs,
    );
    // Use Madrid date for dayKey, not UTC date
    const todayKey = new Intl.DateTimeFormat('es-ES', {
      timeZone: TIMEZONE,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    }).format(now).split('/').reverse().join('-'); // dd/mm/yyyy → yyyy-mm-dd

    // Only check babies with an active subscription state — expired/on_hold
    // babies are not actively using the app so no inactivity push is needed.
    const babiesSnap = await db
      .collection("babies")
      .where("subscription.status", "in", [
        "none", "trial", "active", "grace", "cancelled",
      ])
      .get();

    for (const babyDoc of babiesSnap.docs) {
      const baby = babyDoc.data();
      const babyId = babyDoc.id;
      const estimatedMorningWake: string = baby.estimatedMorningWake ?? "08:00";
      const estimatedBedtime: string = baby.estimatedBedtime ?? "22:00";

      // Check if we're in daytime for this baby
      if (!isWithinDaytime(madridHour, estimatedMorningWake, estimatedBedtime)) {
        continue;
      }

      // Find most recent event today
      const recentEventSnap = await db
        .collection("babies")
        .doc(babyId)
        .collection("events")
        .where("dayKey", "==", todayKey)
        .orderBy("createdAt", "desc")
        .limit(1)
        .get();

      let shouldNotify = false;

      if (recentEventSnap.empty) {
        // No events today at all — check if enough time has passed since morning wake
        const morningWakeH = parseInt(estimatedMorningWake.split(":")[0], 10);
        if (madridHour >= morningWakeH + INACTIVITY_THRESHOLD_HOURS) {
          shouldNotify = true;
        }
      } else {
        const lastEventData = recentEventSnap.docs[0].data();
        const lastCreatedAt = lastEventData.createdAt as admin.firestore.Timestamp;
        if (lastCreatedAt.toMillis() < thresholdTimestamp.toMillis()) {
          shouldNotify = true;
        }
      }

      if (!shouldNotify) continue;

      // Get caregivers' FCM tokens
      const caregivers = (baby.caregivers ?? []) as string[];
      const babyName: string = baby.name ?? "el bebé";

      // Load all caregivers in parallel instead of sequentially.
      const userSnaps = await Promise.all(
        caregivers.map((uid) => db.collection("users").doc(uid).get()),
      );

      const messages: admin.messaging.TokenMessage[] = [];
      // Track deviceId→userId for token cleanup after sending.
      const tokenToUserDevice: Record<string, { userId: string; deviceId: string }> = {};

      for (const userSnap of userSnaps) {
        if (!userSnap.exists) continue;
        const userData = userSnap.data()!;
        const fcmTokens = userData.fcmTokens as
          | Record<string, { token: string }>
          | undefined;
        if (!fcmTokens) continue;

        for (const [deviceId, entry] of Object.entries(fcmTokens)) {
          const token = entry.token;
          messages.push({
            token,
            notification: {
              title: `¿Está durmiendo ${babyName}?`,
              body: `Llevas más de ${INACTIVITY_THRESHOLD_HOURS}h sin registrar nada. ¿Todo bien?`,
            },
            android: {
              priority: "normal",
              notification: { channelId: "inactivity" },
            },
            data: { type: "inactivity", babyId },
          });
          tokenToUserDevice[token] = { userId: userSnap.id, deviceId };
        }
      }

      if (messages.length === 0) continue;

      const batchResponse = await admin.messaging().sendEach(messages);

      // Remove tokens that are no longer valid (unregistered / invalid).
      for (let i = 0; i < batchResponse.responses.length; i++) {
        const resp = batchResponse.responses[i];
        if (resp.success) continue;
        const errorCode = (resp.error as { code?: string } | undefined)?.code;
        if (
          errorCode === "messaging/registration-token-not-registered" ||
          errorCode === "messaging/invalid-registration-token"
        ) {
          const token = messages[i].token as string;
          const meta = tokenToUserDevice[token];
          if (meta) {
            db.collection("users").doc(meta.userId).update({
              [`fcmTokens.${meta.deviceId}`]: admin.firestore.FieldValue.delete(),
            }).catch(() => { /* best-effort */ });
          }
        }
      }
    }

    functions.logger.info("Inactivity check completed");
  }
);


