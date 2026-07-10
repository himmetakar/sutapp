const PROJECT_ID = 'sutapp93';
const API_KEY = 'AIzaSyDqwXjGuKUdu97Xu8tr0hw6I2d0vlOuKRA';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function listDocs(col) { const r = await fetch(`${BASE}/${col}?key=${API_KEY}&pageSize=300`); return (await r.json()).documents || []; }
async function del(name) { await fetch(`https://firestore.googleapis.com/v1/${name}?key=${API_KEY}`, {method:'DELETE'}); }
async function patchMask(name, fields, paths) {
  const m = paths.map(p => `updateMask.fieldPaths=${p}`).join('&');
  await fetch(`https://firestore.googleapis.com/v1/${name}?key=${API_KEY}&${m}`, {method:'PATCH',headers:{'Content-Type':'application/json'},body:JSON.stringify({fields})});
}

async function main() {
  const top = await listDocs('toplamalar');
  let c = 0;
  for (const d of top) {
    const sr = d.fields?.sr?.stringValue || '';
    if (sr.toLowerCase().includes('hasan fidan')) { await del(d.name); c++; }
  }
  console.log(`toplamalar: ${c} kayıt silindi`);

  const ure = await listDocs('ureticiler');
  for (const d of ure) {
    const name = d.fields?.name?.stringValue || '';
    const t = d.fields?.total?.doubleValue ?? d.fields?.total?.integerValue ?? 0;
    if (name === 'Anıl Demir' && t > 0) {
      await patchMask(d.name, {total:{doubleValue:0}}, ['total']);
      console.log(`Anıl Demir total: ${t} → 0`);
    }
    if (name === 'omer coskun' && t > 0) {
      await patchMask(d.name, {total:{doubleValue:0}}, ['total']);
      console.log(`omer coskun total: ${t} → 0`);
    }
  }
  console.log('✅ Tamamlandı');
}
main().catch(console.error);
