/**
 * Hasan Fidan'ın sadece SAYISAL süt verilerini sıfırlar.
 * Tank yapısı, araç bilgileri vs. KORUNUR.
 * 
 * Sıfırlanan: araç tank stoku, tanklar koleksiyonu stoku, toplamalar, teslimatlar, sut_kabul
 */

const PROJECT_ID = 'sutapp-9d33c';
const API_KEY = 'AIzaSyCSu9hE1TB5TkHUrltsLXZOssPCtN3zEGg';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function listDocs(collection) {
  const url = `${BASE_URL}/${collection}?key=${API_KEY}&pageSize=300`;
  const res = await fetch(url);
  const json = await res.json();
  return json.documents || [];
}

async function patchWithMask(name, fields, fieldPaths) {
  const maskParams = fieldPaths.map(p => `updateMask.fieldPaths=${p}`).join('&');
  const url = `https://firestore.googleapis.com/v1/${name}?key=${API_KEY}&${maskParams}`;
  await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
}

async function deleteDoc(name) {
  await fetch(`https://firestore.googleapis.com/v1/${name}?key=${API_KEY}`, { method: 'DELETE' });
}

async function main() {
  console.log('\n🔧 Hasan Fidan — Sayısal Süt Verileri Sıfırlama\n');

  // 1. Araç tankı stoklarını sıfırla (updateMask ile sadece stok alanı)
  console.log('▶ Araç tankı stokları sıfırlanıyor...');
  const araclar = await listDocs('araclar');
  for (const arac of araclar) {
    const f = arac.fields || {};
    const suruculer = f.suruculer?.arrayValue?.values?.map(v => v.stringValue) || [];
    if (!suruculer.some(s => s.toLowerCase().includes('hasan fidan'))) continue;

    const plaka = f.plaka?.stringValue || '?';
    const tanklar = f.tanklar?.arrayValue?.values || [];
    
    console.log(`  Araç: ${plaka}`);
    
    // Tank stokları sıfırla ama diğer alanları (ad, kap) koru
    const newTanklar = tanklar.map(t => {
      const tf = t.mapValue?.fields || {};
      const ad = tf.ad?.stringValue || '?';
      const eskiStok = tf.stok?.doubleValue ?? tf.stok?.integerValue ?? 0;
      console.log(`    ${ad}: ${eskiStok} LT → 0 LT`);
      return {
        mapValue: {
          fields: {
            ...tf,
            stok: { doubleValue: 0.0 },
          },
        },
      };
    });

    // updateMask ile SADECE tanklar alanını güncelle
    await patchWithMask(arac.name, {
      tanklar: { arrayValue: { values: newTanklar } },
    }, ['tanklar']);
    console.log(`  ✓ Araç tank stokları sıfırlandı (yapı korundu)`);
  }

  // 2. tanklar koleksiyonundaki ilgili tankları sıfırla
  console.log('\n▶ Tanklar koleksiyonu stokları sıfırlanıyor...');
  const tankDocs = await listDocs('tanklar');
  for (const t of tankDocs) {
    const f = t.fields || {};
    const firma = f.firma?.stringValue || '';
    const tip = f.tip?.stringValue || '';
    const ad = f.ad?.stringValue || '';
    const stok = f.stok?.doubleValue ?? f.stok?.integerValue ?? 0;

    if (firma.includes('Fidan') && tip === 'arac' && stok > 0) {
      await patchWithMask(t.name, { stok: { doubleValue: 0.0 } }, ['stok']);
      console.log(`  ✓ ${ad}: ${stok} LT → 0 LT`);
    }
  }

  // 3. Hasan Fidan'ın toplamalar kayıtlarını sil
  console.log('\n▶ Toplamalar kayıtları siliniyor...');
  const toplamalar = await listDocs('toplamalar');
  let topCount = 0;
  for (const doc of toplamalar) {
    const f = doc.fields || {};
    const sr = f.sr?.stringValue || '';
    if (sr.toLowerCase().includes('hasan fidan')) {
      await deleteDoc(doc.name);
      topCount++;
    }
  }
  console.log(`  ✓ ${topCount} toplama kaydı silindi`);

  // 4. Hasan Fidan'ın teslimat kayıtlarını sil
  console.log('\n▶ Teslimat kayıtları siliniyor...');
  const teslimatlar = await listDocs('teslimatlar');
  let tesCount = 0;
  for (const doc of teslimatlar) {
    const f = doc.fields || {};
    const plaka = f.plaka?.stringValue || '';
    if (plaka === '34 FID 50') {
      await deleteDoc(doc.name);
      tesCount++;
    }
  }
  console.log(`  ✓ ${tesCount} teslimat kaydı silindi`);

  // 5. sut_kabul kayıtlarını sil
  console.log('\n▶ Süt kabul kayıtları siliniyor...');
  const sutKabul = await listDocs('sut_kabul');
  let skCount = 0;
  for (const doc of sutKabul) {
    const f = doc.fields || {};
    const sr = f.sr?.stringValue || '';
    if (sr.toLowerCase().includes('hasan fidan')) {
      await deleteDoc(doc.name);
      skCount++;
    }
  }
  console.log(`  ✓ ${skCount} süt kabul kaydı silindi`);

  // 6. Üretici toplamlarını sıfırla (Fidanım Süt)
  console.log('\n▶ Üretici toplamları sıfırlanıyor...');
  const ureticiler = await listDocs('ureticiler');
  let ureCount = 0;
  for (const doc of ureticiler) {
    const f = doc.fields || {};
    const firmalar = f.firmalar?.arrayValue?.values?.map(v => v.stringValue) || [];
    const total = f.total?.doubleValue ?? f.total?.integerValue ?? 0;
    if (firmalar.includes('Fidanım Süt') && total > 0) {
      await patchWithMask(doc.name, { total: { doubleValue: 0.0 } }, ['total']);
      console.log(`  ✓ ${f.name?.stringValue}: ${total} → 0`);
      ureCount++;
    }
  }
  if (ureCount === 0) console.log('  (zaten sıfır)');

  console.log('\n✅ Tamamlandı — sadece sayısal veriler sıfırlandı, yapısal veriler korundu.\n');
}

main().catch(e => { console.error('❌ Hata:', e.message); process.exit(1); });
