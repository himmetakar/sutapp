/**
 * reset_milk_data.js — Firebase CLI token ile çalışır
 * 
 * SADECE SÜT VERİLERİNİ TEMİZLER:
 *   ✓ toplamalar (süt toplama kayıtları) → SİLİNİR
 *   ✓ sut_kabul (fabrikaya gelen süt) → SİLİNİR
 *   ✓ bosaltma_talepleri (boşaltma talepleri) → SİLİNİR
 *   ✓ tanklar.stok → 0 (tank belgesi KORUNUR)
 *   ✓ araclar[].tanklar[].stok → 0 (araç belgesi KORUNUR)
 *
 * DOKUNULMAYAN (korunan):
 *   ✗ suruculer, araclar, tanklar, ureticiler, users, firmalar
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const os = require('os');
const path = require('path');

// Firebase CLI token'ı configstore'dan oku
function getFirebaseToken() {
  const configPath = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  if (!fs.existsSync(configPath)) throw new Error('Firebase CLI token bulunamadı. firebase login yapın.');
  const data = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const token = data?.tokens?.access_token || data?.user?.tokens?.access_token;
  if (!token) throw new Error('access_token bulunamadı.');
  return token;
}

const accessToken = getFirebaseToken();

// Admin SDK'yı token ile başlat
const firebaseApp = initializeApp({
  credential: {
    getAccessToken: () => Promise.resolve({ access_token: accessToken, expires_in: 3600 }),
  },
  projectId: 'sutapp-9d33c',
});

const db = getFirestore(firebaseApp);

async function deleteAllDocs(collectionName) {
  const snap = await db.collection(collectionName).get();
  if (snap.empty) return 0;
  let deleted = 0;
  let batch = db.batch();
  let count = 0;
  for (const doc of snap.docs) {
    batch.delete(doc.ref);
    count++;
    deleted++;
    if (count >= 499) {
      await batch.commit();
      batch = db.batch();
      count = 0;
    }
  }
  if (count > 0) await batch.commit();
  return deleted;
}

async function resetTankStocks() {
  const snap = await db.collection('tanklar').get();
  if (snap.empty) return 0;
  let batch = db.batch();
  let count = 0;
  for (const doc of snap.docs) {
    batch.update(doc.ref, { stok: 0 });
    count++;
    if (count >= 499) { await batch.commit(); batch = db.batch(); count = 0; }
  }
  if (count > 0) await batch.commit();
  return snap.docs.length;
}

async function resetVehicleTankStocks() {
  const snap = await db.collection('araclar').get();
  let updated = 0;
  for (const doc of snap.docs) {
    const data = doc.data();
    const tanks = data.tanklar;
    if (!Array.isArray(tanks) || tanks.length === 0) continue;
    const zeroed = tanks.map(t => ({ ...t, stok: 0 }));
    await doc.ref.update({ tanklar: zeroed });
    updated++;
  }
  return updated;
}

async function main() {
  console.log('');
  console.log('🧹 SÜT VERİSİ TEMİZLEME BAŞLIYOR');
  console.log('════════════════════════════════════');
  console.log('Proje: sutapp-9d33c');
  console.log('');

  process.stdout.write('  [1/5] toplamalar siliniyor... ');
  const n1 = await deleteAllDocs('toplamalar');
  console.log(`${n1} kayıt ✓`);

  process.stdout.write('  [2/5] sut_kabul siliniyor... ');
  const n2 = await deleteAllDocs('sut_kabul');
  console.log(`${n2} kayıt ✓`);

  process.stdout.write('  [3/5] bosaltma_talepleri siliniyor... ');
  const n3 = await deleteAllDocs('bosaltma_talepleri');
  console.log(`${n3} kayıt ✓`);

  process.stdout.write('  [4/5] tanklar.stok → 0... ');
  const n4 = await resetTankStocks();
  console.log(`${n4} tank ✓`);

  process.stdout.write('  [5/5] araç tank kopyaları → 0... ');
  const n5 = await resetVehicleTankStocks();
  console.log(`${n5} araç ✓`);

  console.log('');
  console.log('════════════════════════════════════');
  console.log('✅ TAMAMLANDI!');
  console.log('   Araçlar, tanklar, sürücüler, müşteriler korundu.');
  console.log('   Artık sıfırdan süt girişi yapabilirsiniz.');
  console.log('');
  process.exit(0);
}

main().catch(err => {
  console.error('\n❌ HATA:', err.message || err);
  process.exit(1);
});
