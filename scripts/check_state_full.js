/**
 * Firestore durum detaylı kontrol — tüm alanları göster
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

async function main() {
  // Araçlar - tüm field'ları göster
  console.log('\n=== ARACLAR (RAW) ===');
  const araclar = await listDocs('araclar');
  for (const a of araclar) {
    console.log(`\nDoc ID: ${a.name.split('/').pop()}`);
    console.log(JSON.stringify(a.fields, null, 2));
  }

  // Tanklar - tüm field'ları göster
  console.log('\n\n=== TANKLAR (RAW) ===');
  const tanklar = await listDocs('tanklar');
  for (const t of tanklar) {
    console.log(`\nDoc ID: ${t.name.split('/').pop()}`);
    console.log(JSON.stringify(t.fields, null, 2));
  }

  // Üreticiler
  console.log('\n\n=== URETICILER ===');
  const ureticiler = await listDocs('ureticiler');
  for (const u of ureticiler) {
    const f = u.fields || {};
    console.log({
      id: u.name.split('/').pop(),
      name: f.name?.stringValue,
      total: f.total?.doubleValue ?? f.total?.integerValue,
      firma: f.firmalar?.arrayValue?.values?.map(v => v.stringValue),
    });
  }

  // Sürücüler
  console.log('\n\n=== SURUCULER ===');
  const suruculer = await listDocs('suruculer');
  for (const s of suruculer) {
    const f = s.fields || {};
    console.log({
      id: s.name.split('/').pop(),
      ad: f.ad?.stringValue,
      soyad: f.soyad?.stringValue,
      firma: f.firma?.stringValue,
      email: f.email?.stringValue,
    });
  }
}

main().catch(console.error);
