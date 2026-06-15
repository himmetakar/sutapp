/**
 * reset_stocks.js — firebase-tools'un kendi auth modülünü kullanarak
 * Firestore'daki tank stoklarını sıfırlar.
 */

const path = require('path');
const https = require('https');
const fs = require('fs');
const os = require('os');

const PROJECT_ID = 'sutapp-9d33c';
const FIREBASE_TOOLS_PATH = path.join(
  process.env.APPDATA, 'npm', 'node_modules', 'firebase-tools'
);

async function getValidToken() {
  // firebase-tools'un credential modülünü kullan
  try {
    const { default: auth } = await import(
      path.join(FIREBASE_TOOLS_PATH, 'lib', 'auth.js').replace(/\\/g, '/')
    );
    const token = await auth.getAccessToken({});
    if (token && token.access_token) return token.access_token;
  } catch(e1) {
    // fallback: configstore'dan refresh et
  }

  // Configstore'dan refresh_token ile yeni token al
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const refreshToken = config?.tokens?.refresh_token;
  if (!refreshToken) throw new Error('refresh_token bulunamadı');

  // google-auth-library ile token yenile
  const { GoogleAuth, UserRefreshClient } = require('google-auth-library');
  const client = new UserRefreshClient(
    '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    'j9iVZfS7bnB__nGRj_lwDdth',
    refreshToken
  );
  const tokenResponse = await client.getAccessToken();
  return tokenResponse.token;
}

function firestoreRequest(method, urlPath, body, token) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: 'firestore.googleapis.com',
      path: urlPath,
      method,
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    };
    const req = https.request(options, res => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 400) reject(new Error(`HTTP ${res.statusCode}: ${data.substring(0,200)}`));
        else resolve(data ? JSON.parse(data) : {});
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

async function listDocs(collection, token) {
  const docs = [];
  let pageToken;
  do {
    let url = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}?pageSize=300`;
    if (pageToken) url += `&pageToken=${pageToken}`;
    const res = await firestoreRequest('GET', url, null, token);
    if (res.documents) docs.push(...res.documents);
    pageToken = res.nextPageToken;
  } while (pageToken);
  return docs;
}

async function patchStok(docName, stokValue, token) {
  const docPath = docName.split('/documents')[1];
  await firestoreRequest(
    'PATCH',
    `/v1/projects/${PROJECT_ID}/databases/(default)/documents${docPath}?updateMask.fieldPaths=stok`,
    { fields: { stok: { doubleValue: stokValue } } },
    token
  );
}

async function main() {
  console.log('\n🔑 Token alınıyor...');
  let token;
  try {
    // google-auth-library doğrudan dene
    const { UserRefreshClient } = require('google-auth-library');
    const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
    const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
    const refreshToken = config?.tokens?.refresh_token;
    
    const client = new UserRefreshClient(
      '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
      'j9iVZfS7bnB__nGRj_lwDdth',
      refreshToken
    );
    const t = await client.getAccessToken();
    token = t.token;
    console.log('✓ Token alındı (google-auth-library)\n');
  } catch(e) {
    console.error('Token alınamadı:', e.message);
    process.exit(1);
  }

  // tanklar.stok → 0
  console.log('  tanklar koleksiyonu okunuyor...');
  const tankDocs = await listDocs('tanklar', token);
  console.log(`  ${tankDocs.length} tank bulundu`);
  for (const doc of tankDocs) {
    const stok = doc.fields?.stok?.doubleValue ?? doc.fields?.stok?.integerValue ?? '?';
    process.stdout.write(`  ${doc.name.split('/').pop()} (stok=${stok}) → 0... `);
    await patchStok(doc.name, 0, token);
    console.log('✓');
  }

  // araclar.tanklar[].stok → 0
  console.log('\n  araclar koleksiyonu okunuyor...');
  const aracDocs = await listDocs('araclar', token);
  console.log(`  ${aracDocs.length} araç bulundu`);
  for (const doc of aracDocs) {
    const tanklarField = doc.fields?.tanklar;
    if (!tanklarField?.arrayValue?.values?.length) continue;
    const plaka = doc.fields?.plaka?.stringValue ?? doc.name.split('/').pop();
    const zeroed = tanklarField.arrayValue.values.map(v => {
      if (!v.mapValue) return v;
      const m = { ...v.mapValue.fields };
      m.stok = { doubleValue: 0 };
      return { mapValue: { fields: m } };
    });
    process.stdout.write(`  ${plaka} araç tank güncelleniyor... `);
    const docPath = doc.name.split('/documents')[1];
    await firestoreRequest(
      'PATCH',
      `/v1/projects/${PROJECT_ID}/databases/(default)/documents${docPath}?updateMask.fieldPaths=tanklar`,
      { fields: { tanklar: { arrayValue: { values: zeroed } } } },
      token
    );
    console.log('✓');
  }

  console.log('\n✅ TAMAMLANDI — Tüm tank stokları 0\'a sıfırlandı!');
}

main().catch(err => {
  console.error('\n❌ HATA:', err.message);
  process.exit(1);
});
