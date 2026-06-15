const PROJECT_ID = 'sutapp-9d33c';
const API_KEY = 'AIzaSyCSu9hE1TB5TkHUrltsLXZOssPCtN3zEGg';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function listDocs(collection) {
  const url = `${BASE_URL}/${collection}?key=${API_KEY}&pageSize=300`;
  const res = await fetch(url);
  const json = await res.json();
  return json.documents || [];
}

function getField(fields, key) {
  const f = fields?.[key];
  if (!f) return undefined;
  if (f.stringValue !== undefined) return f.stringValue;
  if (f.doubleValue !== undefined) return f.doubleValue;
  if (f.integerValue !== undefined) return Number(f.integerValue);
  if (f.booleanValue !== undefined) return f.booleanValue;
  if (f.arrayValue) return f.arrayValue.values?.map(v => getField(v.mapValue?.fields || v, Object.keys(v.mapValue?.fields || {})[0])) ?? [];
  return JSON.stringify(f);
}

async function main() {
  console.log('\n=== TANKLAR ===');
  const tanks = await listDocs('tanklar');
  for (const t of tanks) {
    const f = t.fields || {};
    console.log({
      id: t.name.split('/').pop(),
      ad: f.ad?.stringValue,
      kap: f.kap?.doubleValue,
      stok: f.stok?.doubleValue,
      tip: f.tip?.stringValue,
      arac: f.arac?.stringValue,
      firma: f.firma?.stringValue,
    });
  }

  console.log('\n=== ARACLAR ===');
  const araclar = await listDocs('araclar');
  for (const a of araclar) {
    const f = a.fields || {};
    const tanklar = f.tanklar?.arrayValue?.values?.map(v => {
      const tf = v.mapValue?.fields || {};
      return { ad: tf.ad?.stringValue, stok: tf.stok?.doubleValue, kap: tf.kap?.doubleValue };
    }) ?? [];
    console.log({
      id: a.name.split('/').pop(),
      plaka: f.plaka?.stringValue,
      firma: f.firma?.stringValue,
      suruculer: f.suruculer?.arrayValue?.values?.map(v => v.stringValue),
      tanklar,
    });
  }
}

main().catch(console.error);
