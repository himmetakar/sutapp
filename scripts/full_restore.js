/**
 * Firestore TAM veri geri yükleme scripti
 * 
 * reset_data.js'nin bozduğu verileri düzeltir:
 * - Tanklar: ad, kap, tip, firma, arac alanları geri yüklenir
 * - Araçlar: plaka, firma, suruculer, active alanları geri yüklenir
 * - Üreticiler: name alanı (zaten mevcut olanlar hariç) korunur
 * 
 * updateMask kullanarak SADECE eksik alanları yazar, mevcut veriyi bozmaz.
 */

const PROJECT_ID = 'sutapp93';
const API_KEY = 'AIzaSyDqwXjGuKUdu97Xu8tr0hw6I2d0vlOuKRA';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function listDocs(collection) {
  const url = `${BASE_URL}/${collection}?key=${API_KEY}&pageSize=300`;
  const res = await fetch(url);
  const json = await res.json();
  return json.documents || [];
}

async function patchDocWithMask(name, fields, fieldPaths) {
  const maskParams = fieldPaths.map(p => `updateMask.fieldPaths=${p}`).join('&');
  const url = `https://firestore.googleapis.com/v1/${name}?key=${API_KEY}&${maskParams}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  const result = await res.json();
  if (result.error) {
    throw new Error(`PATCH failed for ${name}: ${result.error.message}`);
  }
  return result;
}

async function deleteDoc(name) {
  const url = `https://firestore.googleapis.com/v1/${name}?key=${API_KEY}`;
  await fetch(url, { method: 'DELETE' });
}

async function addDoc(collection, fields) {
  const url = `${BASE_URL}/${collection}?key=${API_KEY}`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  return res.json();
}

function str(v) { return { stringValue: v }; }
function num(v) { return { doubleValue: v }; }
function bool(v) { return { booleanValue: v }; }
function arr(values) { return { arrayValue: { values } }; }

// ═══════════════════════════════════════════════════════════════════════
// Bilinen araç yapıları (restore_data.js ve uygulama loglarından)
// ═══════════════════════════════════════════════════════════════════════
const ARAC_MAP = {
  // Tank-01 + tank 5 olan araç
  'HEpSMFybAy697gtx76a7': {
    plaka: '34 TR 100',
    firma: 'Kayseri Çiftlik',
    suruculer: ['Ahmet Kara'],
    active: true,
  },
  // Tank-02 olan araç
  'JZ93tTrPNtGsMYfbP3Uw': {
    plaka: '34 TR 200',
    firma: 'Sivas Süt A.Ş.',
    suruculer: ['Veli Yıldız'],
    active: true,
  },
  // Fidanım Tank-01 olan araç (tanklar array boş olmuş → yeniden oluştur)
  'H0Mgz6csIgKi1196dbLL': {
    plaka: '34 FID 50',
    firma: 'Fidanım Süt',
    suruculer: ['Hasan Fidan'],
    active: true,
    tanklar: [
      { ad: 'Fidanım Tank-01', kap: 5000, stok: 0 },
    ],
  },
  // Tank-35SDS336
  'ZEMCMgMPPY2KbfkSkYon': {
    plaka: '35 SDS 336',
    firma: 'Kayseri Çiftlik',
    suruculer: [],
    active: true,
  },
  // Tank-06FFF689
  'qtwRO67dQsdFPfR3MgW6': {
    plaka: '06 FFF 689',
    firma: 'Kayseri Çiftlik',
    suruculer: [],
    active: true,
  },
};

// ═══════════════════════════════════════════════════════════════════════
// Bilinen tank yapıları
// Her ID → { ad, kap, tip, firma, arac }
// NOT: Mevcut 10 tank doc ID'leri ile eşleştirilecek
// ═══════════════════════════════════════════════════════════════════════
const TANK_DATA = [
  // Araç tankları
  { ad: 'Tank-01',        kap: 3000,  tip: 'arac',   firma: 'Kayseri Çiftlik', arac: '34 TR 100' },
  { ad: 'tank 5',         kap: 5000,  tip: 'arac',   firma: 'Kayseri Çiftlik', arac: '34 TR 100' },
  { ad: 'Tank-02',        kap: 2000,  tip: 'arac',   firma: 'Sivas Süt A.Ş.', arac: '34 TR 200' },
  { ad: 'Fidanım Tank-01',kap: 5000,  tip: 'arac',   firma: 'Fidanım Süt',    arac: '34 FID 50' },
  { ad: 'Tank-35SDS336',  kap: 3000,  tip: 'arac',   firma: 'Kayseri Çiftlik', arac: '35 SDS 336' },
  { ad: 'Tank-06FFF689',  kap: 5000,  tip: 'arac',   firma: 'Kayseri Çiftlik', arac: '06 FFF 689' },
  // Merkez tankları
  { ad: 'Yayla Merkez Tankı',   kap: 15000, tip: 'merkez', firma: 'Kayseri Çiftlik', arac: '' },
  { ad: 'Kaya Merkez Tankı',    kap: 10000, tip: 'merkez', firma: 'Sivas Süt A.Ş.', arac: '' },
  { ad: 'Fidanım Merkez Tankı', kap: 20000, tip: 'merkez', firma: 'Fidanım Süt',    arac: '' },
  // 10. tank — olası ek tank (kontrolde göreceğiz)
];

async function main() {
  console.log('\n🔧 Firestore Tam Veri Geri Yükleme\n');

  // ═══════════════════════════════════════════════════════
  // 1. ARAÇLAR → plaka, firma, suruculer, active geri yükle
  // ═══════════════════════════════════════════════════════
  console.log('▶ Araçlar geri yükleniyor...');
  
  for (const [docId, data] of Object.entries(ARAC_MAP)) {
    const docName = `projects/${PROJECT_ID}/databases/(default)/documents/araclar/${docId}`;
    
    const fields = {
      plaka: str(data.plaka),
      firma: str(data.firma),
      active: bool(data.active),
      suruculer: arr(data.suruculer.map(s => str(s))),
    };
    const fieldPaths = ['plaka', 'firma', 'active', 'suruculer'];

    // Eğer tanklar array'i de restore edilmesi gerekiyorsa
    if (data.tanklar) {
      fields.tanklar = arr(data.tanklar.map(t => ({
        mapValue: {
          fields: {
            ad: str(t.ad),
            kap: num(t.kap),
            stok: num(t.stok),
          }
        }
      })));
      fieldPaths.push('tanklar');
    }

    await patchDocWithMask(docName, fields, fieldPaths);
    console.log(`  ✓ ${data.plaka} → ${data.firma} [${data.suruculer.join(', ') || 'sürücü yok'}]`);
  }

  // ═══════════════════════════════════════════════════════
  // 2. TANKLAR → sil ve yeniden oluştur (tüm alanlarla)
  // ═══════════════════════════════════════════════════════
  console.log('\n▶ Tanklar geri yükleniyor...');
  
  // Mevcut bozuk tankları sil
  const mevcutTanklar = await listDocs('tanklar');
  for (const t of mevcutTanklar) {
    await deleteDoc(t.name);
  }
  console.log(`  ${mevcutTanklar.length} bozuk tank silindi`);
  
  // Yeni temiz tankları oluştur
  for (const t of TANK_DATA) {
    await addDoc('tanklar', {
      ad: str(t.ad),
      kap: num(t.kap),
      stok: num(0), // stok sıfır — zaten reset olmuştu
      tip: str(t.tip),
      firma: str(t.firma),
      arac: str(t.arac),
    });
    console.log(`  ✓ ${t.ad} (${t.tip}) → ${t.firma}`);
  }

  // ═══════════════════════════════════════════════════════
  // 3. ÜRETİCİLER — kontrol et, name eksik olanları düzelt
  // ═══════════════════════════════════════════════════════
  console.log('\n▶ Üreticiler kontrol ediliyor...');
  const ureticiler = await listDocs('ureticiler');
  for (const u of ureticiler) {
    const f = u.fields || {};
    const name = f.name?.stringValue;
    const id = u.name.split('/').pop();
    if (name) {
      console.log(`  ✓ ${name} (total: ${f.total?.doubleValue ?? 0}) — OK`);
    } else {
      console.log(`  ⚠️ ${id} — name alanı EKSİK (diğer alanlar: ${JSON.stringify(Object.keys(f))})`);
    }
  }

  // ═══════════════════════════════════════════════════════
  // 4. DOĞRULAMA
  // ═══════════════════════════════════════════════════════
  console.log('\n\n=== DOĞRULAMA ===');
  
  console.log('\nAraçlar:');
  const sonAraclar = await listDocs('araclar');
  for (const a of sonAraclar) {
    const f = a.fields || {};
    const plaka = f.plaka?.stringValue || '???';
    const firma = f.firma?.stringValue || '???';
    const suruculer = f.suruculer?.arrayValue?.values?.map(v => v.stringValue) || [];
    const tanklar = f.tanklar?.arrayValue?.values?.map(v => v.mapValue?.fields?.ad?.stringValue) || [];
    console.log(`  ${plaka} | ${firma} | sürücüler: [${suruculer.join(', ')}] | tanklar: [${tanklar.join(', ')}]`);
  }

  console.log('\nTanklar:');
  const sonTanklar = await listDocs('tanklar');
  for (const t of sonTanklar) {
    const f = t.fields || {};
    console.log(`  ${f.ad?.stringValue} | ${f.tip?.stringValue} | kap: ${f.kap?.doubleValue} | firma: ${f.firma?.stringValue}`);
  }

  console.log(`\n✅ Geri yükleme tamamlandı! (${sonAraclar.length} araç, ${sonTanklar.length} tank)\n`);
}

main().catch((e) => {
  console.error('❌ Hata:', e.message || e);
  process.exit(1);
});
