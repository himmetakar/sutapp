/**
 * clear_data.js
 * Firestore'daki sayısal/işlemsel verileri temizler.
 * Kullanıcı, firma, üretici, ürün, fiyat, atama kayıtlarına DOKUNMAZ.
 *
 * Çalıştırma:
 *   node scripts/clear_data.js <PROJE_ID>
 *
 * Önemli: firebase login ile önceden giriş yapılmış olmalı
 * veya GOOGLE_APPLICATION_CREDENTIALS env var set edilmiş olmalı.
 */

const { initializeApp, cert, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = process.argv[2] || 'sutapp93';

// Silinecek koleksiyonlar (işlemsel / sayısal veriler)
const COLLECTIONS_TO_CLEAR = [
  'toplamalar',       // Süt toplamaları
  'tahsilatlar',      // Tahsilat & ödeme kayıtları
  'avanslar',         // Avans kayıtları
  'kesintiler',       // Kesinti kayıtları
  'cezalar',          // Ceza kayıtları
  'satislar',         // Satış kayıtları (üreticiye yapılan)
  'devirler',         // Devir/düzeltme kayıtları
  'urunler_siparisler', // Ürün sipariş kayıtları
  'giderler',         // Gider kayıtları
  'cari_islemler',    // Cari işlem kayıtları
  'bildirimler',      // Bildirimler
  'tank_kayitlari',   // Tank kayıtları (varsa)
];

// DOKUNULMAYACAK koleksiyonlar (konfigürasyon / yapısal veriler):
// users, firmalar, ureticiler, urunler, urunler_kategoriler,
// sut_fiyatlari, toplayici_atamalari, surucu_atamalari,
// finans_ayarlari, tank_durumu, popuplar

async function deleteCollection(db, collectionName) {
  const col = db.collection(collectionName);
  let deletedTotal = 0;

  // Batch ile 500'lü gruplar halinde sil
  while (true) {
    const snapshot = await col.limit(500).get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach(doc => batch.delete(doc.ref));
    await batch.commit();
    deletedTotal += snapshot.docs.length;
    process.stdout.write(`  ${collectionName}: ${deletedTotal} belge silindi...\r`);
  }

  console.log(`  ✅ ${collectionName}: toplam ${deletedTotal} belge silindi.`);
  return deletedTotal;
}

async function main() {
  console.log(`\n🗑️  Firestore Veri Temizleme — Proje: ${PROJECT_ID}`);
  console.log('================================================');
  console.log('⚠️  Aşağıdaki koleksiyonlar temizlenecek:');
  COLLECTIONS_TO_CLEAR.forEach(c => console.log(`     - ${c}`));
  console.log('');
  console.log('🔒 Korunan koleksiyonlar: users, ureticiler, firmalar, urunler,');
  console.log('   sut_fiyatlari, toplayici_atamalari, surucu_atamalari, vb.');
  console.log('================================================\n');

  // 5 saniye bekle (iptal fırsatı)
  console.log('⏳ 5 saniye içinde başlıyor... (durdurmak için Ctrl+C)');
  await new Promise(r => setTimeout(r, 5000));

  let app;
  try {
    // Önce Application Default Credentials dene (firebase login yapmışsa çalışır)
    app = initializeApp({
      credential: applicationDefault(),
      projectId: PROJECT_ID,
    });
  } catch (e) {
    console.error('❌ Firebase başlatılamadı:', e.message);
    console.error('   "firebase login" ile giriş yapın veya service account kullanın.');
    process.exit(1);
  }

  const db = getFirestore(app);

  let grandTotal = 0;
  for (const colName of COLLECTIONS_TO_CLEAR) {
    try {
      const count = await deleteCollection(db, colName);
      grandTotal += count;
    } catch (err) {
      console.error(`  ❌ ${colName} silerken hata: ${err.message}`);
    }
  }

  console.log(`\n================================================`);
  console.log(`✅ Temizleme tamamlandı. Toplam ${grandTotal} belge silindi.`);
  console.log(`   Uygulama artık sıfırdan veri girişine hazır.\n`);
  process.exit(0);
}

main().catch(err => {
  console.error('Beklenmeyen hata:', err);
  process.exit(1);
});
