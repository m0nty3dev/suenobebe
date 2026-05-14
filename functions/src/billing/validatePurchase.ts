import * as functions from "firebase-functions/v2";
import { REGION } from '../config/region';
import * as admin from "firebase-admin";
import { google } from "googleapis";



export const validatePlayBillingPurchase = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }

    const { purchaseToken, productId } = request.data as {
      purchaseToken: string;
      productId: string;
    };

    if (!purchaseToken || !productId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "purchaseToken and productId are required"
      );
    }

    const uid = request.auth.uid;

    // Look up which baby this user belongs to
    const usersSnap = await admin.firestore().collection("users").doc(uid).get();
    if (!usersSnap.exists) {
      throw new functions.https.HttpsError("not-found", "User not found");
    }
    const userData = usersSnap.data()!;
    const babyId = userData.currentBabyId as string | undefined;
    if (!babyId) {
      throw new functions.https.HttpsError("not-found", "No baby associated with user");
    }

    // Reject if purchaseToken is already linked to a different baby (prevents token reuse).
    const existingSnap = await admin
      .firestore()
      .collection("babies")
      .where("subscription.purchaseToken", "==", purchaseToken)
      .limit(1)
      .get();
    if (!existingSnap.empty && existingSnap.docs[0].id !== babyId) {
      throw new functions.https.HttpsError(
        "already-exists",
        "purchaseToken already linked to another account"
      );
    }

    // Validate with Google Play Developer API
    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const androidpublisher = google.androidpublisher({ version: "v3", auth });

    const packageName = "com.monty.suenobebe";
    let expiresAtMs: number;
    let autoRenew = false;
    let plan: "monthly" | "annual";

    if (productId === "sb_monthly_399") {
      plan = "monthly";
    } else if (productId === "sb_annual_1199") {
      plan = "annual";
    } else {
      throw new functions.https.HttpsError("invalid-argument", "Unknown productId");
    }

    try {
      const result = await androidpublisher.purchases.subscriptions.get({
        packageName,
        subscriptionId: productId,
        token: purchaseToken,
      });

      const sub = result.data;

      // If the purchase was made with applicationUserName (obfuscatedAccountId),
      // verify it matches the authenticated uid to prevent token theft across accounts.
      const externalAccountId = sub.obfuscatedExternalAccountId;
      if (externalAccountId && externalAccountId !== uid) {
        throw new functions.https.HttpsError(
          "permission-denied",
          "purchaseToken was not purchased by this account"
        );
      }

      expiresAtMs = parseInt(sub.expiryTimeMillis ?? "0", 10);
      autoRenew = sub.autoRenewing === true;

      const cancelReason = sub.cancelReason;
      const paymentState = sub.paymentState;

      let status: string;
      if (paymentState === 0) {
        // Payment pending
        status = "on_hold";
      } else if (paymentState === 1 || paymentState === 2) {
        // Active or free trial
        if (cancelReason !== undefined && cancelReason !== null) {
          status = "cancelled";
        } else {
          status = "active";
        }
      } else {
        status = "expired";
      }

      await admin.firestore().collection("babies").doc(babyId).update({
        "subscription.status": status,
        "subscription.plan": plan,
        "subscription.source": "play_billing",
        "subscription.purchaseToken": purchaseToken,
        "subscription.productId": productId,
        "subscription.expiresAt": admin.firestore.Timestamp.fromMillis(expiresAtMs),
        "subscription.autoRenew": autoRenew,
        "subscription.lastVerifiedAt": admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return { success: true, status };
    } catch (err: unknown) {
      functions.logger.error("Error validating purchase", err);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to validate purchase"
      );
    }
  }
);

export const acknowledgePurchase = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }

    const { purchaseToken, productId } = request.data as {
      purchaseToken: string;
      productId: string;
    };

    if (!purchaseToken || !productId) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "purchaseToken and productId are required"
      );
    }

    const auth = new google.auth.GoogleAuth({
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const androidpublisher = google.androidpublisher({ version: "v3", auth });

    try {
      await androidpublisher.purchases.subscriptions.acknowledge({
        packageName: "com.monty.suenobebe",
        subscriptionId: productId,
        token: purchaseToken,
      });
      return { success: true };
    } catch (err: unknown) {
      functions.logger.error("Error acknowledging purchase", err);
      throw new functions.https.HttpsError("internal", "Failed to acknowledge purchase");
    }
  }
);

