/**
 * Deletes all babies EXCEPT the one specified as the real baby.
 * Also deletes their subcollections (events, dailyStats).
 *
 * Usage:
 *   node scripts/cleanup_test_babies.js <realBabyId>
 *
 * Example:
 *   node scripts/cleanup_test_babies.js BptNHIpqIpS8oHiBd6cF
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const db = admin.firestore();

const REAL_BABY_ID = process.argv[2];
if (!REAL_BABY_ID) {
  console.error('Usage: node scripts/cleanup_test_babies.js <realBabyId>');
  process.exit(1);
}

async function deleteCollection(colRef) {
  const snap = await colRef.get();
  if (snap.empty) return;
  const batch = db.batch();
  snap.docs.forEach(d => batch.delete(d.ref));
  await batch.commit();
}

async function main() {
  const babiesSnap = await db.collection('babies').get();
  const toDelete = babiesSnap.docs.filter(d => d.id !== REAL_BABY_ID);

  if (toDelete.length === 0) {
    console.log('Nothing to delete — only the real baby exists.');
    process.exit(0);
  }

  console.log(`Keeping: ${REAL_BABY_ID}`);
  console.log(`Deleting ${toDelete.length} test babies...\n`);

  for (const doc of toDelete) {
    const babyRef = doc.ref;
    const name = doc.data().name ?? doc.id;
    process.stdout.write(`  Deleting [${name}] (${doc.id})... `);

    await deleteCollection(babyRef.collection('events'));
    await deleteCollection(babyRef.collection('dailyStats'));
    await babyRef.delete();

    console.log('OK');
  }

  console.log('\nDone.');
  process.exit(0);
}

main().catch(err => { console.error(err); process.exit(1); });
