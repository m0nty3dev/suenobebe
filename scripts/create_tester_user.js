const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function createTesterUser() {
  const user = await admin.auth().createUser({
    email: 'tester@suenobebe.app',
    password: 'Tester2026!',
    displayName: 'Tester Google Play',
    emailVerified: true,
  });
  console.log('Usuario creado:', user.uid);
  console.log('Email:', user.email);
  console.log('Password: Tester2026!');
  process.exit(0);
}

createTesterUser().catch(err => {
  console.error('Error:', err.message);
  process.exit(1);
});
