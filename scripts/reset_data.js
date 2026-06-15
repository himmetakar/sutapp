/**
 * Firestore sayısal veri sıfırlama scripti
 * Çalıştır: node reset_data.js
 * 
 * Silerler: toplamalar, teslimatlar, satislar, faturalar, avanslar,
 *            tahsilatlar, cezalar, kesintiler, sut_kabul, sut_analiz,
 *            odeme_gecmisi, devirler, urunler_siparisler, bildirimler
 * Sıfırlar: tanklar.stok = 0, araclar[].stok = 0, ureticiler.total = 0
 */

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

// Service account yerine API key ile erişim (client-side benzeri)
// Admin SDK için service account gerekli — alternatif olarak REST API kullanıyoruz

const PROJECT_ID = 'sutapp-9d33c';
const API_KEY = 'AIzaSyCSu9hE1TB5TkHUrltsLXZOssPCtN3zEGg';

const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function listDocs(collection) {
  const url = `${BASE_URL}/${collection}?key=${API_KEY}&pageSize=300`;
  const res = await fetch(url);
  const json = await res.json();
  return json.documents || [];
}

async function deleteDoc(name) {
  const url = `https://firestore.googleapis.com/v1/${name}?key=${API_KEY}`;
  await fetch(url, { method: 'DELETE' });
}

async function patchDoc(name, fields) {
  const url = `https://firestore.googleapis.com/v1/${name}?key=${API_KEY}`;
  await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
}

async function clearCollection(name) {
  console.log(`  Siliniyor: ${name}...`);
  const docs = await listDocs(name);
  for (const doc of docs) {
    await deleteDoc(doc.name);
  }
  console.log(`  ✓ ${name}: ${docs.length} kayıt silindi`);
}

async function main() {
  console.log('\n🗑️  SutApp Firestore Veri Sıfırlama\n');

  // 1. İşlem kayıtlarını sil
  const toDelete = [
    'toplamalar', 'teslimatlar', 'satislar', 'faturalar',
    'avanslar', 'tahsilatlar', 'cezalar', 'kesintiler',
    'sut_kabul', 'sut_analiz', 'odeme_gecmisi', 'devirler',
    'urunler_siparisler', 'bildirimler', 'duyurular',
  ];

  for (const col of toDelete) {
    await clearCollection(col);
  }

  // 2. Tank stoklarını sıfırla
  console.log('\n  Tanklar sıfırlanıyor...');
  const tankDocs = await listDocs('tanklar');
  for (const doc of tankDocs) {
    await patchDoc(doc.name, { stok: { doubleValue: 0.0 } });
  }
  console.log(`  ✓ tanklar: ${tankDocs.length} tank sıfırlandı`);

  // 3. Araç tankı stoklarını sıfırla
  console.log('  Araçlar sıfırlanıyor...');
  const aracDocs = await listDocs('araclar');
  for (const doc of aracDocs) {
    const tanklar = doc.fields?.tanklar?.arrayValue?.values || [];
    const newTanklar = tanklar.map((t) => {
      const mapFields = t.mapValue?.fields || {};
      return {
        mapValue: {
          fields: {
            ...mapFields,
            stok: { doubleValue: 0.0 },
          },
        },
      };
    });
    if (newTanklar.length > 0) {
      await patchDoc(doc.name, {
        tanklar: { arrayValue: { values: newTanklar } },
      });
    }
  }
  console.log(`  ✓ araclar: ${aracDocs.length} araç sıfırlandı`);

  // 4. Üretici toplamlarını sıfırla
  console.log('  Üreticiler sıfırlanıyor...');
  const ureticiDocs = await listDocs('ureticiler');
  for (const doc of ureticiDocs) {
    await patchDoc(doc.name, { total: { doubleValue: 0.0 } });
  }
  console.log(`  ✓ ureticiler: ${ureticiDocs.length} üretici sıfırlandı`);

  console.log('\n✅ Tüm sayısal veriler başarıyla sıfırlandı!\n');
}

main().catch((e) => {
  console.error('❌ Hata:', e.message);
  process.exit(1);
});
