const PROJECT_ID = 'sutapp93';
const API_KEY = 'AIzaSyDqwXjGuKUdu97Xu8tr0hw6I2d0vlOuKRA';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function listDocs(col) {
  const r = await fetch(`${BASE}/${col}?key=${API_KEY}&pageSize=300`);
  const j = await r.json();
  return j.documents || [];
}

async function deleteDoc(name) {
  await fetch(`https://firestore.googleapis.com/v1/${name}?key=${API_KEY}`, { method: 'DELETE' });
}

// Field mask ile sadece belirtilen alanları güncelle
async function patchField(name, fieldPath, value) {
  const url = `https://firestore.googleapis.com/v1/${name}?key=${API_KEY}&updateMask.fieldPaths=${fieldPath}`;
  await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields: value }),
  });
}

async function main() {
  console.log('\n🧹 Süt Verisi Temizleme (güvenli mod)\n');

  // 1. Sadece toplamalar koleksiyonunu sil
  const toplamalar = await listDocs('toplamalar');
  for (const d of toplamalar.docs ?? toplamalar) await deleteDoc(d.name);
  console.log(`✓ toplamalar: ${toplamalar.length} kayıt silindi`);

  // 2. Tank stoklarını sıfırla — sadece stok alanı (field mask)
  const tanklar = await listDocs('tanklar');
  for (const t of tanklar) {
    await patchField(t.name, 'stok', { stok: { doubleValue: 0.0 } });
  }
  console.log(`✓ tanklar: ${tanklar.length} tankın stoğu → 0`);

  // 3. Araç tankı stoklarını sıfırla — mevcut tanklar array'i oku, sadece stok=0 yap, field mask ile yaz
  const araclar = await listDocs('araclar');
  for (const a of araclar) {
    const f = a.fields || {};
    const mevcut = f.tanklar?.arrayValue?.values || [];
    if (mevcut.length === 0) continue;

    const yeni = mevcut.map(t => {
      const tf = t.mapValue?.fields || {};
      return {
        mapValue: {
          fields: {
            ...tf,                            // tüm alanlar korunur
            stok: { doubleValue: 0.0 },       // sadece stok sıfırlanır
          }
        }
      };
    });

    await patchField(a.name, 'tanklar', {
      tanklar: { arrayValue: { values: yeni } }
    });
  }
  console.log(`✓ araclar: ${araclar.length} aracın tank stokları → 0`);

  // 4. Üretici toplamlarını sıfırla — sadece total alanı (field mask)
  const ureticiler = await listDocs('ureticiler');
  for (const u of ureticiler) {
    await patchField(u.name, 'total', { total: { doubleValue: 0.0 } });
  }
  console.log(`✓ ureticiler: ${ureticiler.length} üreticinin totali → 0`);

  console.log('\n✅ Temizlik tamamlandı! Artık test yapabilirsiniz.\n');
}

main().catch(console.error);
