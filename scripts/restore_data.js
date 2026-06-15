/**
 * Firestore veri kurtarma scripti
 * Araclar ve tanklar koleksiyonlarını geri yükler.
 * 
 * Strateji:
 * - araclar: tanklar array'indeki ad bilgisinden plaka/firma/surucu tespiti
 * - tanklar: 11 kayıt var, hangi tank hangi firma/araç → suruculer + arac array'den eşleme
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

async function patchDocWithMask(name, fields, fieldPaths) {
  const maskParams = fieldPaths.map(p => `updateMask.fieldPaths=${p}`).join('&');
  const url = `https://firestore.googleapis.com/v1/${name}?key=${API_KEY}&${maskParams}`;
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  return res.json();
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

function strField(v) { return { stringValue: v }; }
function numField(v) { return { doubleValue: v }; }
function boolField(v) { return { booleanValue: v }; }
function arrField(values) { return { arrayValue: { values } }; }
function mapField(fields) { return { mapValue: { fields } }; }

async function main() {
  console.log('\n🔧 Firestore Veri Kurtarma\n');

  // ── Mevcut suruculer'den sürücü-plaka eşlemesi al ─────────────────────────
  const suruculer = await listDocs('suruculer');
  console.log(`Sürücüler: ${suruculer.length} kayıt`);
  
  // Sürücü adı → firma eşlemesi
  const suruculerMap = {}; // 'Ahmet Kara' → { firma, ad, soyad }
  for (const s of suruculer) {
    const f = s.fields || {};
    const ad = f.ad?.stringValue || '';
    const soyad = f.soyad?.stringValue || '';
    const firma = f.firma?.stringValue || '';
    const fullName = `${ad} ${soyad}`.trim();
    suruculerMap[fullName] = { firma, ad, soyad };
  }
  console.log('Sürücü haritası:', suruculerMap);

  // ── Mevcut araclar durumu ────────────────────────────────────────────────
  const araclar = await listDocs('araclar');
  console.log(`\nAraçlar: ${araclar.length} kayıt`);

  // Araçların tanklar array'indeki tank adlarından firma tespiti
  // Tank ad → hangi firmaya ait olduğu bilgisi:
  const tankToFirma = {
    'Tank-01': 'Kayseri Çiftlik',
    'tank 5': 'Kayseri Çiftlik',
    'Tank-02': 'Sivas Süt A.Ş.',
    'Fidanım Tank-01': 'Fidanım Süt',
    'Tank2': 'Fidanım Süt',
    'Tank-35SDS336': 'Kayseri Çiftlik',   // kullanıcı eklemiş, makul tahmin
    'Tank-06FFF689': 'Kayseri Çiftlik',   // kullanıcı eklemiş, makul tahmin
  };

  // Tank ad → araç plakası (bilinen eşlemeler)
  const tankToPlaka = {
    'Tank-01': '34 TR 100',
    'tank 5': '34 TR 100',
    'Tank-02': '34 TR 200',
    'Fidanım Tank-01': '34 FID 50',
    'Tank2': '34 FID 50',
  };

  // Araç plakası → sürücü(ler) (bilinen eşlemeler)
  const plakaToSurucu = {
    '34 TR 100': ['Ahmet Kara'],
    '34 TR 200': ['Veli Yıldız'],
    '34 FID 50': ['Hasan Fidan'],
  };

  // ── Araclar geri yükle ────────────────────────────────────────────────────
  console.log('\n▶ Araçlar geri yükleniyor...');
  for (const arac of araclar) {
    const f = arac.fields || {};
    
    // Mevcut tanklar array'i koru (sadece stok resetli, diğer alanlar tam)
    const mevcut_tanklar = f.tanklar?.arrayValue?.values || [];
    
    // Bu araç için plakayı bul (tanklar array'deki tank adından)
    let plaka = f.plaka?.stringValue || '';
    let firma = f.firma?.stringValue || '';
    
    if (!plaka && mevcut_tanklar.length > 0) {
      const ilkTankAd = mevcut_tanklar[0].mapValue?.fields?.ad?.stringValue || '';
      plaka = tankToPlaka[ilkTankAd] || '';
      firma = tankToFirma[ilkTankAd] || '';
    }
    
    const suruculer_list = plaka ? (plakaToSurucu[plaka] || []) : [];
    
    if (!plaka) {
      console.log(`  ⚠️ Araç ${arac.name.split('/').pop()} için plaka tespit edilemedi, atlanıyor`);
      continue;
    }

    // Sadece eksik alanları yükle (tanklar zaten tamam)
    const patchFields = {
      plaka: strField(plaka),
      firma: strField(firma),
      active: boolField(true),
      suruculer: arrField(suruculer_list.map(s => strField(s))),
    };

    await patchDocWithMask(arac.name, patchFields, ['plaka', 'firma', 'active', 'suruculer']);
    console.log(`  ✓ Araç ${plaka} → firma: ${firma}, sürücüler: ${suruculer_list.join(', ')}`);
  }

  // ── Tanklar geri yükle ────────────────────────────────────────────────────
  // Tankları silip yeniden oluşturmak yerine, doğru eşleme bularak restore et.
  // Problem: 11 tankın hangisi hangisi bilinmiyor.
  // Çözüm: Tüm tankları sil, araç array'lerinden + bilinen yapıdan yeniden oluştur.
  
  console.log('\n▶ Tanklar yeniden oluşturuluyor...');

  // Önce mevcut bozuk tankları sil
  const bozukTanklar = await listDocs('tanklar');
  for (const t of bozukTanklar) {
    await deleteDoc(t.name);
  }
  console.log(`  ${bozukTanklar.length} bozuk tank silindi`);

  // Araç array'lerinden araç tanklarını yeniden oluştur
  const araclarSonra = await listDocs('araclar');
  const olusturulanTanklar = new Set();

  for (const arac of araclarSonra) {
    const f = arac.fields || {};
    const plaka = f.plaka?.stringValue || '';
    const firma = f.firma?.stringValue || '';
    const mevcut_tanklar = f.tanklar?.arrayValue?.values || [];

    for (const t of mevcut_tanklar) {
      const tf = t.mapValue?.fields || {};
      const tankAd = tf.ad?.stringValue || '';
      const tankKap = tf.kap?.doubleValue || 0;

      if (!tankAd || olusturulanTanklar.has(tankAd)) continue;
      olusturulanTanklar.add(tankAd);

      await addDoc('tanklar', {
        ad: strField(tankAd),
        kap: numField(tankKap),
        stok: numField(0),
        tip: strField('arac'),
        arac: strField(plaka),
        firma: strField(firma),
      });
      console.log(`  ✓ Araç tankı: ${tankAd} (${tankKap}L) → ${plaka} / ${firma}`);
    }
  }

  // Merkez tanklarını yeniden oluştur (kod içindeki bilinen yapıdan)
  const merkezTanklar = [
    { ad: 'Yayla Merkez Tankı', kap: 15000.0, firma: 'Kayseri Çiftlik' },
    { ad: 'Kaya Merkez Tankı',  kap: 10000.0, firma: 'Sivas Süt A.Ş.' },
    { ad: 'Fidanım Merkez Tankı', kap: 20000.0, firma: 'Fidanım Süt' },
  ];

  for (const mt of merkezTanklar) {
    await addDoc('tanklar', {
      ad: strField(mt.ad),
      kap: numField(mt.kap),
      stok: numField(0),
      tip: strField('merkez'),
      arac: strField(''),
      firma: strField(mt.firma),
    });
    console.log(`  ✓ Merkez tankı: ${mt.ad} (${mt.kap}L) → ${mt.firma}`);
  }

  console.log('\n✅ Kurtarma tamamlandı!\n');

  // Sonuç kontrol
  console.log('=== SONUÇ KONTROLÜ ===');
  const tankSon = await listDocs('tanklar');
  console.log(`Tanklar: ${tankSon.length} kayıt`);
  for (const t of tankSon) {
    const f = t.fields || {};
    console.log(`  ${f.ad?.stringValue} | kap:${f.kap?.doubleValue} | tip:${f.tip?.stringValue} | arac:${f.arac?.stringValue} | firma:${f.firma?.stringValue}`);
  }

  const aracSon = await listDocs('araclar');
  console.log(`\nAraçlar: ${aracSon.length} kayıt`);
  for (const a of aracSon) {
    const f = a.fields || {};
    const tl = f.tanklar?.arrayValue?.values?.map(v => v.mapValue?.fields?.ad?.stringValue).join(', ');
    console.log(`  ${f.plaka?.stringValue} | ${f.firma?.stringValue} | ${f.suruculer?.arrayValue?.values?.map(v=>v.stringValue).join(', ')} | tanklar: ${tl}`);
  }
}

main().catch(console.error);
