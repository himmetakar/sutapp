const PROJECT_ID = 'sutapp-9d33c';
const API_KEY = 'AIzaSyCSu9hE1TB5TkHUrltsLXZOssPCtN3zEGg';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function listDocs(col) {
  const r = await fetch(`${BASE}/${col}?key=${API_KEY}&pageSize=300`);
  const j = await r.json();
  return j.documents || [];
}

async function deleteDoc(name) {
  await fetch(`https://firestore.googleapis.com/v1/${name}?key=${API_KEY}`, { method: 'DELETE' });
}

async function addDoc(col, fields) {
  const r = await fetch(`${BASE}/${col}?key=${API_KEY}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  return r.json();
}

const s = v => ({ stringValue: v });
const n = v => ({ doubleValue: v });
const arr = vs => ({ arrayValue: { values: vs } });

async function main() {
  console.log('\n=== Üretici Atamalarından Veri Çıkarma ===\n');

  // 1. Mevcut ureticiler — sadece total alanı kalmış
  const mevcutUreticiler = await listDocs('ureticiler');
  console.log(`Mevcut bozuk üretici sayısı: ${mevcutUreticiler.length}`);

  // 2. Toplayıcı atamalarından üretici adlarını bul
  const atamalar = await listDocs('toplayici_atamalari');
  const atamaUreticiler = new Set();
  for (const a of atamalar) {
    const f = a.fields || {};
    if (f.hedefTip?.stringValue === 'uretici') {
      const ad = f.hedefAd?.stringValue;
      const firma = f.firma?.stringValue;
      if (ad) atamaUreticiler.add(JSON.stringify({ ad, firma }));
    }
  }
  console.log('\nAtamalardan bulunan üreticiler:');
  for (const u of atamaUreticiler) console.log(' ', JSON.parse(u));

  // 3. Koddan bilinen mock üreticiler (kaynak kodu)
  const mockUreticiler = [
    { name: 'Mehmet Yılmaz', phone: '0532 111 2233', group: 'Yayla Çiftliği',       bolge: 'Kocasinan', avg: 30.0, firmalar: ['Kayseri Çiftlik'], lastMilkType: 'Soğuk Süt', customerType: 'sut' },
    { name: 'Fatma Korkmaz', phone: '0533 222 3344', group: 'Yayla Çiftliği',       bolge: 'Kocasinan', avg: 30.0, firmalar: ['Kayseri Çiftlik'], lastMilkType: 'Soğuk Süt', customerType: 'sut' },
    { name: 'Ali Özdemir',   phone: '0534 333 4455', group: 'Kızıltepe Mah.',       bolge: 'Talas',     avg: 30.0, firmalar: ['Kayseri Çiftlik'], lastMilkType: 'Soğuk Süt', customerType: 'sut' },
    { name: 'Ayşe Şahin',   phone: '0535 444 5566', group: 'Dağyolu Çiftlikleri',  bolge: 'Merkez',    avg: 30.0, firmalar: ['Sivas Süt A.Ş.'], lastMilkType: 'Soğuk Süt', customerType: 'sut' },
    { name: 'Hüseyin Kaya', phone: '0536 555 6677', group: 'Akarsu Bölgesi',       bolge: 'Merkez',    avg: 30.0, firmalar: ['Sivas Süt A.Ş.'], lastMilkType: 'Soğuk Süt', customerType: 'sut' },
    { name: 'Anıl Demir',   phone: '0537 888 7766', group: 'Fidanım Köyü',         bolge: 'Melikgazi', avg: 50.0, firmalar: ['Fidanım Süt'],    lastMilkType: 'Soğuk Süt', customerType: 'sut' },
  ];

  // Atamalardan ek üreticiler tespit et (mock'ta olmayan)
  const mockNames = new Set(mockUreticiler.map(u => u.name));
  const ekUreticiler = [];
  for (const entry of atamaUreticiler) {
    const { ad, firma } = JSON.parse(entry);
    if (!mockNames.has(ad)) {
      ekUreticiler.push({ name: ad, firmalar: [firma] });
    }
  }

  if (ekUreticiler.length > 0) {
    console.log('\nMock dışı ek üreticiler (atamadan):');
    ekUreticiler.forEach(u => console.log(' ', u));
  }

  // 4. Bozuk dokümanları sil
  console.log('\n▶ Bozuk üretici dokümanları siliniyor...');
  for (const d of mevcutUreticiler) await deleteDoc(d.name);
  console.log(`  ${mevcutUreticiler.length} doküman silindi`);

  // 5. Mock üreticileri yeniden ekle
  console.log('\n▶ Üreticiler yeniden oluşturuluyor...');
  for (const u of mockUreticiler) {
    await addDoc('ureticiler', {
      name: s(u.name),
      phone: s(u.phone),
      group: s(u.group),
      bolge: s(u.bolge),
      avg: n(u.avg),
      total: n(0.0),
      firmalar: arr(u.firmalar.map(f => s(f))),
      lastMilkType: s(u.lastMilkType),
      customerType: s(u.customerType),
    });
    console.log(`  ✓ ${u.name} → ${u.firmalar.join(', ')}`);
  }

  // 6. Ek üreticileri de ekle (adı var ama detayı yok)
  for (const u of ekUreticiler) {
    await addDoc('ureticiler', {
      name: s(u.name),
      phone: s(''),
      group: s('Bilinmiyor'),
      bolge: s('Merkez'),
      avg: n(30.0),
      total: n(0.0),
      firmalar: arr(u.firmalar.map(f => s(f))),
      lastMilkType: s('Soğuk Süt'),
      customerType: s('sut'),
    });
    console.log(`  ✓ ${u.name} → ${u.firmalar.join(', ')} (detay eksik)`);
  }

  console.log('\n✅ Üreticiler restore edildi!\n');

  // Kontrol
  const son = await listDocs('ureticiler');
  console.log(`Toplam üretici: ${son.length}`);
  for (const d of son) {
    const f = d.fields || {};
    console.log(`  ${f.name?.stringValue} | ${f.firmalar?.arrayValue?.values?.map(v=>v.stringValue).join(',')} | grup: ${f.group?.stringValue}`);
  }
}

main().catch(console.error);
