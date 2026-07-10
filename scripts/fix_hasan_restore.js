/**
 * Hasan Fidan'ın aracını ve tankını geri yükle + sayısal verileri sıfırla
 */
const PROJECT_ID = 'sutapp93';
const API_KEY = 'AIzaSyDqwXjGuKUdu97Xu8tr0hw6I2d0vlOuKRA';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

async function patchWithMask(name, fields, fieldPaths) {
  const maskParams = fieldPaths.map(p => `updateMask.fieldPaths=${p}`).join('&');
  const url = `https://firestore.googleapis.com/v1/${name}?key=${API_KEY}&${maskParams}`;
  await fetch(url, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
}

async function deleteDoc(name) {
  await fetch(`https://firestore.googleapis.com/v1/${name}?key=${API_KEY}`, { method: 'DELETE' });
}

async function addDoc(collection, fields) {
  const url = `${BASE_URL}/${collection}?key=${API_KEY}`;
  await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ fields }),
  });
}

function str(v) { return { stringValue: v }; }
function num(v) { return { doubleValue: v }; }
function bool(v) { return { booleanValue: v }; }
function arr(vs) { return { arrayValue: { values: vs } }; }

async function main() {
  console.log('\n🔧 Hasan Fidan Araç & Tank Restore + Sıfırlama\n');

  // 1. Araç belgesini updateMask ile düzelt
  const aracDocName = `projects/${PROJECT_ID}/databases/(default)/documents/araclar/H0Mgz6csIgKi1196dbLL`;
  
  await patchWithMask(aracDocName, {
    plaka: str('34 FID 50'),
    firma: str('Fidanım Süt'),
    active: bool(true),
    suruculer: arr([str('Hasan Fidan')]),
    tanklar: arr([{
      mapValue: {
        fields: {
          ad: str('Fidanım Tank-01'),
          kap: num(5000),
          stok: num(0),
        }
      }
    }]),
  }, ['plaka', 'firma', 'active', 'suruculer', 'tanklar']);
  
  console.log('✓ Araç geri yüklendi: 34 FID 50 → Fidanım Süt [Hasan Fidan]');
  console.log('  Tank: Fidanım Tank-01 (5000L kap, 0 stok)');

  // 2. Bozuk tank kaydını sil ve yenisini oluştur
  const bozukTankName = `projects/${PROJECT_ID}/databases/(default)/documents/tanklar/0HArJFth94yynbAAIE3j`;
  await deleteDoc(bozukTankName);
  console.log('\n✓ Bozuk tank kaydı silindi');

  await addDoc('tanklar', {
    ad: str('Fidanım Tank-01'),
    kap: num(5000),
    stok: num(0),
    tip: str('arac'),
    arac: str('34 FID 50'),
    firma: str('Fidanım Süt'),
  });
  console.log('✓ Fidanım Tank-01 yeniden oluşturuldu (stok: 0)');

  console.log('\n✅ Tamamlandı — araç ve tank yapısı korundu, stoklar sıfır.\n');
}

main().catch(e => { console.error('❌ Hata:', e.message); process.exit(1); });
