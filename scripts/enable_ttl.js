/**
 * Enables Firestore TTL policy on processedRTDNs.expiresAt.
 * Run once: node --use-system-ca scripts/enable_ttl.js
 */
const { GoogleAuth } = require('google-auth-library');
const https = require('https');

const PROJECT = 'suenobebe-e0a32';
const DATABASE = '(default)';
const COLLECTION = 'processedRTDNs';
const FIELD = 'expiresAt';

const serviceAccount = require('./serviceAccountKey.json');

async function enableTtl() {
  const auth = new GoogleAuth({
    credentials: serviceAccount,
    scopes: ['https://www.googleapis.com/auth/cloud-platform'],
  });

  const client = await auth.getClient();
  const token = await client.getAccessToken();

  const name = `projects/${PROJECT}/databases/${DATABASE}/collectionGroups/${COLLECTION}/fields/${FIELD}`;
  const url = `https://firestore.googleapis.com/v1/${name}?updateMask=ttlConfig`;
  const body = JSON.stringify({ ttlConfig: {} });

  await new Promise((resolve, reject) => {
    const req = https.request(url, {
      method: 'PATCH',
      headers: {
        Authorization: `Bearer ${token.token}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body),
      },
    }, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log('✅ TTL habilitado en processedRTDNs.expiresAt');
          console.log('   (La política puede tardar unos minutos en activarse en Firestore)');
          resolve();
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        }
      });
    });
    req.on('error', reject);
    req.write(body);
    req.end();
  });
}

enableTtl().catch(err => {
  console.error('❌ Error:', err.message);
  process.exit(1);
});
