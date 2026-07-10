const PROJECT_ID = 'sutapp93';
const API_KEY = 'AIzaSyDqwXjGuKUdu97Xu8tr0hw6I2d0vlOuKRA';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function listDocs(col) {
  const r = await fetch(`${BASE}/${col}?key=${API_KEY}&pageSize=100`);
  return (await r.json()).documents || [];
}

async function main() {
  console.log('=== TOPLAMALAR ===');
  const docs = await listDocs('toplamalar');
  console.log(`Toplam kayıt: ${docs.length}`);
  for (const d of docs) {
    const f = d.fields || {};
    console.log({
      id: d.name.split('/').pop(),
      u: f.u?.stringValue,
      m: f.m?.doubleValue ?? f.m?.integerValue,
      sr: f.sr?.stringValue,
      tank: f.tank?.stringValue,
      tarih: f.tarih?.stringValue,
      s: f.s?.stringValue,
      firma: f.firma?.stringValue,
      km: f.km?.stringValue,
    });
  }
}
main().catch(console.error);
