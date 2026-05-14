import * as functions from "firebase-functions/v2";
import { REGION } from '../config/region';
import * as admin from "firebase-admin";


const EXPORT_EXPIRY_SECONDS = 24 * 60 * 60; // 24 hours

function escapeCsv(value: unknown): string {
  if (value === null || value === undefined) return "";
  const str = String(value);
  if (str.includes(",") || str.includes('"') || str.includes("\n")) {
    return `"${str.replace(/"/g, '""')}"`;
  }
  return str;
}

function timestampToIso(ts: admin.firestore.Timestamp | null | undefined): string {
  if (!ts) return "";
  return ts.toDate().toISOString();
}

export const exportUserData = functions.https.onCall(
  { region: REGION },
  async (request) => {
    if (!request.auth) {
      throw new functions.https.HttpsError("unauthenticated", "Not authenticated");
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    // Fetch user data
    const userDoc = await db.collection("users").doc(uid).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError("not-found", "User not found");
    }

    const userData = userDoc.data()!;
    const babyId = userData.currentBabyId as string | undefined;

    if (!babyId) {
      throw new functions.https.HttpsError("not-found", "No baby found for this user");
    }

    // Verify caregiver access
    const babyDoc = await db.collection("babies").doc(babyId).get();
    if (!babyDoc.exists) {
      throw new functions.https.HttpsError("not-found", "Baby not found");
    }

    const baby = babyDoc.data()!;
    const caregivers = baby.caregivers as string[];
    if (!caregivers.includes(uid)) {
      throw new functions.https.HttpsError("permission-denied", "Not a caregiver");
    }

    // Fetch all events
    const eventsSnap = await db
      .collection("babies")
      .doc(babyId)
      .collection("events")
      .orderBy("startAt", "asc")
      .get();

    // Build CSV with BOM for Excel compatibility
    const BOM = "\uFEFF";
    const headers = [
      "id",
      "type",
      "startAt",
      "endAt",
      "durationSec",
      "status",
      "dayKey",
      "breast",
      "leftDurationSec",
      "rightDurationSec",
      "bottleMl",
      "note",
      "createdBy",
      "createdAt",
      "updatedAt",
    ];

    const rows: string[] = [headers.join(",")];

    for (const eventDoc of eventsSnap.docs) {
      const e = eventDoc.data();
      const meta = e.metadata ?? {};
      const row = [
        eventDoc.id,
        e.type,
        timestampToIso(e.startAt),
        timestampToIso(e.endAt),
        e.durationSec ?? "",
        e.status,
        e.dayKey,
        meta.breast ?? "",
        meta.leftDurationSec ?? "",
        meta.rightDurationSec ?? "",
        meta.bottleMl ?? "",
        meta.note ?? "",
        e.createdBy,
        timestampToIso(e.createdAt),
        timestampToIso(e.updatedAt),
      ]
        .map(escapeCsv)
        .join(",");
      rows.push(row);
    }

    const csvContent = BOM + rows.join("\r\n");

    // Upload to Firebase Storage
    const timestamp = Date.now();
    const filePath = `exports/${uid}/${timestamp}.csv`;
    const bucket = admin.storage().bucket();
    const file = bucket.file(filePath);

    await file.save(csvContent, {
      contentType: "text/csv; charset=utf-8",
      metadata: {
        contentDisposition: `attachment; filename="suenobebe_export_${timestamp}.csv"`,
      },
    });

    // Generate signed URL valid for 24 hours
    const [signedUrl] = await file.getSignedUrl({
      action: "read",
      expires: Date.now() + EXPORT_EXPIRY_SECONDS * 1000,
    });

    functions.logger.info("Data exported", { uid, filePath });
    return { url: signedUrl, expiresIn: EXPORT_EXPIRY_SECONDS };
  }
);

