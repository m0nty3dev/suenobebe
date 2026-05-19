/**
 * Seed /config/sleep_defaults en Firestore.
 *
 * Uso:
 *   node scripts/seed_sleep_defaults.js
 *
 * Requiere serviceAccountKey.json en scripts/ (descargado de Firebase Console
 * > Configuración del proyecto > Cuentas de servicio > Generar nueva clave privada)
 *
 * Este documento lo lee la Cloud Function recomputeEstimates para seleccionar
 * los horarios de despertar/dormir por defecto según la edad del bebé.
 * Sin él, TODOS los bebés reciben 08:00/22:00 independientemente de la edad.
 *
 * Fuente: Weissbluth (2015), Mindell (2010), AASM paediatric guidelines.
 * Los valores de morningWake y bedtime son medias típicas para España.
 */

const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Rangos de edad con horarios típicos de despertar y dormir.
// Deben ser coherentes con _ageTable en predict_next_nap.dart.
const ranges = [
  { minMonths: 0,  maxMonths: 1,  morningWake: '07:00', bedtime: '20:00' },
  { minMonths: 2,  maxMonths: 3,  morningWake: '07:00', bedtime: '20:30' },
  { minMonths: 4,  maxMonths: 5,  morningWake: '07:00', bedtime: '19:30' },
  { minMonths: 6,  maxMonths: 8,  morningWake: '07:00', bedtime: '19:00' },
  { minMonths: 9,  maxMonths: 13, morningWake: '07:00', bedtime: '19:00' },
  { minMonths: 14, maxMonths: 17, morningWake: '07:30', bedtime: '19:30' },
  { minMonths: 18, maxMonths: 23, morningWake: '07:30', bedtime: '20:00' },
  { minMonths: 24, maxMonths: 35, morningWake: '07:30', bedtime: '20:30' },
  { minMonths: 36, maxMonths: 60, morningWake: '07:30', bedtime: '21:00' },
];

async function seed() {
  await db.collection('config').doc('sleep_defaults').set(
    { ranges, updatedAt: admin.firestore.FieldValue.serverTimestamp() },
    { merge: false },
  );
  console.log(`✅ /config/sleep_defaults sembrado con ${ranges.length} rangos de edad.`);
  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Error:', err);
  process.exit(1);
});
