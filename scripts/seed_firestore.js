/**
 * Seed script para Firestore — ejecutar una sola vez.
 *
 * Uso:
 *   node scripts/seed_firestore.js
 *
 * Requiere: firebase-admin, google-services.json en la misma carpeta o
 * GOOGLE_APPLICATION_CREDENTIALS apuntando a la clave de servicio.
 */

const admin = require('firebase-admin');

// Inicializar con la clave de servicio descargada de Firebase Console
// > Configuración del proyecto > Cuentas de servicio > Generar nueva clave privada
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://suenobebe-e0a32.firebaseio.com',
});

const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

// ────────────────────────────────────────────────────────────────────────────
// sleep_defaults: basado en recomendaciones pediátricas de la AAP y estudios
// de sueño infantil. Editable en cualquier momento desde Firestore Console.
// Formato morningWake y bedtime: "HH:mm"
// ────────────────────────────────────────────────────────────────────────────
const sleepDefaults = {
  ranges: [
    // Recién nacidos: sin ciclo día/noche establecido — se usan valores generales
    { minMonths: 0,  maxMonths: 2,  morningWake: '07:30', bedtime: '21:00' },
    // 3-5 meses: empiezan a consolidar el sueño nocturno
    { minMonths: 3,  maxMonths: 5,  morningWake: '07:00', bedtime: '20:30' },
    // 6-8 meses: sueño nocturno más largo, 2-3 siestas durante el día
    { minMonths: 6,  maxMonths: 8,  morningWake: '06:45', bedtime: '20:00' },
    // 9-11 meses: transición a 2 siestas
    { minMonths: 9,  maxMonths: 11, morningWake: '07:00', bedtime: '19:30' },
    // 12-17 meses: 1-2 siestas, bedtime adelantado
    { minMonths: 12, maxMonths: 17, morningWake: '07:00', bedtime: '19:30' },
    // 18-23 meses: 1 siesta
    { minMonths: 18, maxMonths: 23, morningWake: '07:15', bedtime: '20:00' },
    // 24-35 meses: 1 siesta, bedtime similar
    { minMonths: 24, maxMonths: 35, morningWake: '07:30', bedtime: '20:30' },
    // 36+ meses: siesta opcional, más independencia
    { minMonths: 36, maxMonths: 999, morningWake: '07:30', bedtime: '21:00' },
  ],
};

// ────────────────────────────────────────────────────────────────────────────
// legal config
// ────────────────────────────────────────────────────────────────────────────
const legalConfig = {
  privacyVersion: 1,
  termsVersion: 1,
  privacyUrl: 'https://suenobebe.app/privacy',
  termsUrl: 'https://suenobebe.app/terms',
  updatedAt: admin.firestore.FieldValue.serverTimestamp(),
};

// ────────────────────────────────────────────────────────────────────────────
// products config
// ────────────────────────────────────────────────────────────────────────────
const productsConfig = {
  monthly: { productId: 'sb_monthly_399', priceText: '3,99 €', highlighted: false },
  annual: { productId: 'sb_annual_1199', priceText: '11,99 €', highlighted: true },
};

async function seed() {
  console.log('🌱 Iniciando seed de Firestore...\n');

  // sleep_defaults
  await db.collection('config').doc('sleep_defaults').set(sleepDefaults);
  console.log('✅ /config/sleep_defaults — escritos', sleepDefaults.ranges.length, 'rangos');

  // legal
  await db.collection('config').doc('legal').set(legalConfig);
  console.log('✅ /config/legal — escrito');

  // products
  await db.collection('config').doc('products').set(productsConfig);
  console.log('✅ /config/products — escrito');

  console.log('\n✨ Seed completado correctamente.');
  process.exit(0);
}

seed().catch((err) => {
  console.error('❌ Error en seed:', err);
  process.exit(1);
});
