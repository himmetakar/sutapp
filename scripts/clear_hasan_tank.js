/**
 * Hasan Fidan'ın araç tankındaki stoku sıfırlar.
 * Sadece 'araclar' koleksiyonundaki ilgili araç güncellenir.
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

async function patchDoc(name, fields) {
  const url = `https://firestore.googleapis.com/v1/${name}?key=${API_KEY}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  return res.json();
}

async function main() {
  console.log('\n🔍 Hasan Fidan\'ın aracı aranıyor...\n');

  const aracDocs = await listDocs('araclar');

  let found = false;
  for (const doc of aracDocs) {
    const f = doc.fields || {};
    const suruculer = f.suruculer?.arrayValue?.values?.map(v => v.stringValue || '') || [];
    const plaka = f.plaka?.stringValue || '';
    const firma = f.firma?.stringValue || '';

    const hasanVar = suruculer.some(s => s.toLowerCase().includes('hasan fidan'));
    if (!hasanVar) continue;

    found = true;
    console.log(`✓ Araç bulundu: ${plaka} (${firma})`);
    console.log(`  Sürücüler: ${suruculer.join(', ')}`);

    const tanklar = f.tanklar?.arrayValue?.values || [];
    console.log(`\n  Mevcut tanklar:`);
    for (const t of tanklar) {
      const tf = t.mapValue?.fields || {};
      const ad = tf.ad?.stringValue || '?';
      const stok = tf.stok?.doubleValue ?? tf.stok?.integerValue ?? 0;
      console.log(`    - ${ad}: ${stok} LT`);
    }

    // Tüm araç tanklarını 0'a sıfırla
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

    await patchDoc(doc.name, {
      tanklar: { arrayValue: { values: newTanklar } },
    });

    console.log(`\n  ✅ ${plaka} aracının tüm tank stokları 0 LT yapıldı.`);
  }

  // tanklar koleksiyonundaki araç tanklarını da sıfırla
  console.log('\n🔍 tanklar koleksiyonunda araç tankları aranıyor...\n');
  const tankDocs = await listDocs('tanklar');
  let tankCount = 0;
  for (const doc of tankDocs) {
    const f = doc.fields || {};
    const tip = f.tip?.stringValue || '';
    const sr = f.sr?.stringValue || f.surucu?.stringValue || '';
    const firma = f.firma?.stringValue || '';
    const ad = f.ad?.stringValue || '';
    const stok = f.stok?.doubleValue ?? f.stok?.integerValue ?? 0;

    // Fidanım Süt firmasına ait araç tanklarını sıfırla
    if (tip === 'arac' && firma.toLowerCase().includes('fidan') && stok > 0) {
      console.log(`  Sıfırlanıyor: ${ad} (stok: ${stok} LT)`);
      await patchDoc(doc.name, { stok: { doubleValue: 0.0 } });
      tankCount++;
    }
  }
  if (tankCount > 0) {
    console.log(`  ✅ ${tankCount} araç tankı sıfırlandı.`);
  } else {
    console.log('  (tanklar koleksiyonunda sıfırlanacak araç tankı yok)');
  }

  if (!found) {
    console.log('❌ Hasan Fidan\'a ait araç bulunamadı.');
  }

  console.log('\n✅ Tamamlandı.\n');
}

main().catch((e) => {
  console.error('❌ Hata:', e.message);
  process.exit(1);
});
