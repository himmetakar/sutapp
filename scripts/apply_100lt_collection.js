const PROJECT_ID = 'sutapp93';
const API_KEY = 'AIzaSyDqwXjGuKUdu97Xu8tr0hw6I2d0vlOuKRA';
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
  const res = await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
  if (!res.ok) {
    const txt = await res.text();
    console.error(`Failed to patch ${name}:`, txt);
  }
}

async function main() {
  console.log('Applying 100 LT to Fidanım Tank-01, vehicle 34 FID 50, and Anıl Demir producer...');

  // 1. Update Tank
  const tankDocs = await listDocs('tanklar');
  for (const t of tankDocs) {
    const f = t.fields || {};
    const ad = f.ad?.stringValue || '';
    if (ad === 'Fidanım Tank-01') {
      console.log(`Found tank ${ad}, updating stock to 100.0`);
      await patchWithMask(t.name, { stok: { doubleValue: 100.0 } }, ['stok']);
    }
  }

  // 2. Update Vehicle
  const araclar = await listDocs('araclar');
  for (const arac of araclar) {
    const f = arac.fields || {};
    const plaka = f.plaka?.stringValue || '';
    if (plaka === '34 FID 50') {
      console.log(`Found vehicle ${plaka}, updating embedded tank Fidanım Tank-01 stock to 100.0`);
      const tanklar = f.tanklar?.arrayValue?.values || [];
      const newTanklar = tanklar.map(t => {
        const tf = t.mapValue?.fields || {};
        const ad = tf.ad?.stringValue || '';
        if (ad === 'Fidanım Tank-01') {
          return {
            mapValue: {
              fields: {
                ...tf,
                stok: { doubleValue: 100.0 }
              }
            }
          };
        }
        return t;
      });

      await patchWithMask(arac.name, {
        tanklar: { arrayValue: { values: newTanklar } }
      }, ['tanklar']);
    }
  }

  // 3. Update Producer Anıl Demir
  const ureticiler = await listDocs('ureticiler');
  for (const doc of ureticiler) {
    const f = doc.fields || {};
    const name = f.name?.stringValue || '';
    if (name === 'Anıl Demir') {
      console.log(`Found producer ${name}, updating total to 100.0`);
      await patchWithMask(doc.name, { total: { doubleValue: 100.0 } }, ['total']);
    }
  }

  console.log('Successfully completed applying 100 LT collection!');
}

main().catch(err => console.error(err));
