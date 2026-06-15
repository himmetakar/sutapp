/**
 * reset_milk_data_rest.js
 * Firebase REST API + Firebase CLI token ile çalışır.
 * Servis hesabı gerekmez.
 */

const https = require('https');
const fs = require('fs');
const os = require('os');
const path = require('path');

const PROJECT_ID = 'sutapp-9d33c';
const BASE_URL = `firestore.googleapis.com`;

// Firebase CLI token oku
function getAccessToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  const data = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const token = data?.tokens?.access_token;
  if (!token) throw new Error('Firebase CLI access_token bulunamadı. "firebase login" yapın.');
  return token;
}

function apiRequest(method, urlPath, body, token) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: BASE_URL,
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
        if (res.statusCode >= 400) {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
        } else {
          resolve(data ? JSON.parse(data) : {});
        }
      });
    });
    req.on('error', reject);
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}

// Koleksiyondaki tüm belgeleri listele
async function listDocs(collectionId, token, pageToken) {
  let url = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collectionId}?pageSize=300`;
  if (pageToken) url += `&pageToken=${pageToken}`;
  return apiRequest('GET', url, null, token);
}

// Tek belge sil
function deleteDoc(docName, token) {
  // docName: projects/.../databases/.../documents/collectionId/docId
  const docPath = docName.replace(`projects/${PROJECT_ID}/databases/(default)/documents`, '');
  return apiRequest('DELETE', `/v1/projects/${PROJECT_ID}/databases/(default)/documents${docPath}`, null, token);
}

// Belgeyi güncelle (patch)
function patchDoc(docName, fields, token) {
  const docPath = docName.replace(`projects/${PROJECT_ID}/databases/(default)/documents`, '');
  const updateMask = Object.keys(fields).map(f => `updateMask.fieldPaths=${f}`).join('&');
  return apiRequest('PATCH', `/v1/projects/${PROJECT_ID}/databases/(default)/documents${docPath}?${updateMask}`, { fields }, token);
}

async function deleteCollection(collectionId, token) {
  let deleted = 0;
  let pageToken;
  do {
    const res = await listDocs(collectionId, token, pageToken);
    const docs = res.documents || [];
    for (const doc of docs) {
      await deleteDoc(doc.name, token);
      deleted++;
    }
    pageToken = res.nextPageToken;
  } while (pageToken);
  return deleted;
}

async function resetAllTankStoks(token) {
  let updated = 0;
  let pageToken;
  do {
    const res = await listDocs('tanklar', token, pageToken);
    const docs = res.documents || [];
    for (const doc of docs) {
      await patchDoc(doc.name, { stok: { doubleValue: 0 } }, token);
      updated++;
    }
    pageToken = res.nextPageToken;
  } while (pageToken);
  return updated;
}

async function resetVehicleTankStocks(token) {
  let updated = 0;
  let pageToken;
  do {
    const res = await listDocs('araclar', token, pageToken);
    const docs = res.documents || [];
    for (const doc of docs) {
      const fields = doc.fields || {};
      const tanklarField = fields.tanklar;
      if (!tanklarField || !tanklarField.arrayValue) continue;
      const vals = tanklarField.arrayValue.values || [];
      if (vals.length === 0) continue;
      // Her tank objesinin stok alanını 0 yap
      const zeroed = vals.map(v => {
        if (!v.mapValue) return v;
        const m = { ...v.mapValue.fields };
        m.stok = { doubleValue: 0 };
        return { mapValue: { fields: m } };
      });
      await patchDoc(doc.name, {
        tanklar: { arrayValue: { values: zeroed } }
      }, token);
      updated++;
    }
    pageToken = res.nextPageToken;
  } while (pageToken);
  return updated;
}

async function main() {
  console.log('');
  console.log('🧹 SÜT VERİSİ TEMİZLEME (REST API)');
  console.log('════════════════════════════════════');
  const token = getAccessToken();
  console.log('✓ Firebase token alındı\n');

  process.stdout.write('  [1/5] toplamalar siliniyor... ');
  const n1 = await deleteCollection('toplamalar', token);
  console.log(`${n1} kayıt ✓`);

  process.stdout.write('  [2/5] sut_kabul siliniyor... ');
  const n2 = await deleteCollection('sut_kabul', token);
  console.log(`${n2} kayıt ✓`);

  process.stdout.write('  [3/5] bosaltma_talepleri siliniyor... ');
  const n3 = await deleteCollection('bosaltma_talepleri', token);
  console.log(`${n3} kayıt ✓`);

  process.stdout.write('  [4/5] tanklar.stok → 0... ');
  const n4 = await resetAllTankStoks(token);
  console.log(`${n4} tank ✓`);

  process.stdout.write('  [5/5] araç tank kopyaları → 0... ');
  const n5 = await resetVehicleTankStocks(token);
  console.log(`${n5} araç ✓`);

  console.log('');
  console.log('════════════════════════════════════');
  console.log('✅ TAMAMLANDI!');
  console.log('   Araçlar, tanklar, sürücüler, müşteriler korundu.');
  console.log('   Artık sıfırdan süt girişi yapabilirsiniz.');
  console.log('');
}

main().catch(err => {
  console.error('\n❌ HATA:', err.message);
  if (err.message.includes('401') || err.message.includes('UNAUTHENTICATED')) {
    console.error('   Token süresi dolmuş olabilir. "firebase login" komutunu tekrar çalıştırın.');
  }
  process.exit(1);
});
