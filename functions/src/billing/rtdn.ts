import * as functions from "firebase-functions/v2";
import { REGION } from '../config/region';
import * as admin from "firebase-admin";
import { google } from "googleapis";
import { OAuth2Client } from "google-auth-library";

const oauthClient = new OAuth2Client();


const PACKAGE_NAME = "com.monty.suenobebe";

// Notification types from Google Play Real-time Developer Notifications
enum SubscriptionNotificationType {
  RECOVERED = 1,
  RENEWED = 2,
  CANCELED = 3,
  PURCHASED = 4,
  ON_HOLD = 5,
  IN_GRACE_PERIOD = 6,
  RESTARTED = 7,
  PRICE_CHANGE_CONFIRMED = 8,
  DEFERRED = 9,
  PAUSED = 10,
  PAUSE_SCHEDULE_CHANGED = 11,
  REVOKED = 12,
  EXPIRED = 13,
}

interface RTDNPayload {
  version: string;
  packageName: string;
  eventTimeMillis: string;
  subscriptionNotification?: {
    version: string;
    notificationType: number;
    purchaseToken: string;
    subscriptionId: string;
  };
}

async function getBabyIdByToken(purchaseToken: string): Promise<string | null> {
  const snap = await admin
    .firestore()
    .collection("babies")
    .where("subscription.purchaseToken", "==", purchaseToken)
    .limit(1)
    .get();
  if (snap.empty) return null;
  return snap.docs[0].id;
}

async function refreshSubscriptionStatus(
  babyId: string,
  purchaseToken: string,
  subscriptionId: string
): Promise<void> {
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  const androidpublisher = google.androidpublisher({ version: "v3", auth });

  const result = await androidpublisher.purchases.subscriptions.get({
    packageName: PACKAGE_NAME,
    subscriptionId,
    token: purchaseToken,
  });

  const sub = result.data;
  const expiresAtMs = parseInt(sub.expiryTimeMillis ?? "0", 10);
  const autoRenew = sub.autoRenewing === true;

  const cancelReason = sub.cancelReason;
  const paymentState = sub.paymentState;

  let status: string;
  if (paymentState === 0) {
    status = "on_hold";
  } else if (sub.userCancellationTimeMillis && cancelReason === 0) {
    status = "cancelled";
  } else if (paymentState === 1 || paymentState === 2) {
    status = "active";
  } else {
    status = "expired";
  }

  await admin.firestore().collection("babies").doc(babyId).update({
    "subscription.status": status,
    "subscription.expiresAt": admin.firestore.Timestamp.fromMillis(expiresAtMs),
    "subscription.autoRenew": autoRenew,
    "subscription.lastVerifiedAt": admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

export const playBillingRTDN = functions.https.onRequest(
  { region: REGION },
  async (req, res) => {
    try {
      // Verify the request comes from Google Pub/Sub (OIDC token in Authorization header).
      // Skip in emulator where no real tokens are available.
      if (process.env.FUNCTIONS_EMULATOR !== "true") {
        const authHeader = req.headers.authorization ?? "";
        if (!authHeader.startsWith("Bearer ")) {
          functions.logger.warn("RTDN: missing OIDC token");
          res.status(401).send("Unauthorized");
          return;
        }
        try {
          const ticket = await oauthClient.verifyIdToken({
            idToken: authHeader.slice(7),
          });
          const payload = ticket.getPayload();
          // Pub/Sub push uses a Google-managed service account
          if (!payload?.email_verified || !payload.email?.endsWith(".gserviceaccount.com")) {
            functions.logger.warn("RTDN: invalid OIDC token issuer", { email: payload?.email });
            res.status(403).send("Forbidden");
            return;
          }
        } catch (err) {
          functions.logger.warn("RTDN: OIDC verification failed", err);
          res.status(401).send("Invalid token");
          return;
        }
      }

      // Pub/Sub pushes a base64-encoded message
      const body = req.body as {
        message?: { data?: string; messageId?: string };
      };
      if (!body.message?.data) {
        res.status(400).send("No message data");
        return;
      }

      // Idempotency: Pub/Sub may deliver the same message more than once.
      // Record processed messageIds so duplicate deliveries are no-ops.
      const messageId = body.message.messageId ?? null;
      if (messageId) {
        const idempotencyRef = admin
          .firestore()
          .collection("processedRTDNs")
          .doc(messageId);
        const already = await idempotencyRef.get();
        if (already.exists) {
          functions.logger.info("Duplicate RTDN — already processed", {
            messageId,
          });
          res.status(200).send("OK");
          return;
        }
        // Mark as processed before doing any work (optimistic — acceptable since
        // the worst case of a crash after this is missing one status update).
        // expiresAt enables Firestore TTL policy to auto-delete after 7 days.
        await idempotencyRef.set({
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
          expiresAt: admin.firestore.Timestamp.fromMillis(
            Date.now() + 7 * 24 * 60 * 60 * 1000,
          ),
        });
      }

      const decoded = Buffer.from(body.message.data, "base64").toString("utf8");
      const payload = JSON.parse(decoded) as RTDNPayload;

      const notification = payload.subscriptionNotification;
      if (!notification) {
        // Could be a test notification or other type
        res.status(200).send("OK");
        return;
      }

      const { purchaseToken, subscriptionId, notificationType } = notification;
      const babyId = await getBabyIdByToken(purchaseToken);

      if (!babyId) {
        functions.logger.warn("No baby found for purchaseToken", { purchaseToken });
        res.status(200).send("OK");
        return;
      }

      switch (notificationType) {
        case SubscriptionNotificationType.PURCHASED:
        case SubscriptionNotificationType.RENEWED:
        case SubscriptionNotificationType.RECOVERED:
        case SubscriptionNotificationType.RESTARTED:
          await refreshSubscriptionStatus(babyId, purchaseToken, subscriptionId);
          break;

        case SubscriptionNotificationType.CANCELED:
          await admin.firestore().collection("babies").doc(babyId).update({
            "subscription.status": "cancelled",
            "subscription.autoRenew": false,
            "subscription.lastVerifiedAt": admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          break;

        case SubscriptionNotificationType.ON_HOLD:
          await admin.firestore().collection("babies").doc(babyId).update({
            "subscription.status": "on_hold",
            "subscription.lastVerifiedAt": admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          break;

        case SubscriptionNotificationType.IN_GRACE_PERIOD:
          await admin.firestore().collection("babies").doc(babyId).update({
            "subscription.status": "grace",
            "subscription.lastVerifiedAt": admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          break;

        case SubscriptionNotificationType.EXPIRED:
        case SubscriptionNotificationType.REVOKED:
          await admin.firestore().collection("babies").doc(babyId).update({
            "subscription.status": "expired",
            "subscription.autoRenew": false,
            "subscription.lastVerifiedAt": admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          break;

        default:
          functions.logger.info("Unhandled notification type", { notificationType });
      }

      res.status(200).send("OK");
    } catch (err: unknown) {
      functions.logger.error("Error processing RTDN", err);
      res.status(500).send("Internal error");
    }
  }
);

