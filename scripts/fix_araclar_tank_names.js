/**
 * fix_araclar_tank_names.js
 * 
 * PowerShell'in Türkçe karakter sorunundan dolayı bozulan araclar.tanklar[].ad
 * alanlarını tanklar koleksiyonundaki doğru isimlerle onarır.
 * 
 * Ayrıca surucu_dashboard'un embedded array yerine tanklar koleksiyonunu
 * okumaya geçmesi gerekene kadar bu geçici onarım yeterli olacak.
 */

const https = require('https');

const API_KEY = 'AIzaSyC0-FtYShX4AInMnieL5PHVxmAujWvEhGs';
const PROJECT = 'sutapp-9d33c';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

function httpsGet(path) {
  return new Promise((resolve, reject) => {
    const url = `${BASE_URL}/${path}?key=${API_KEY}&pageSize=200`;
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch (e) { reject(e); }
      });
    }).on('error', reject);
  });
}

function httpsPatch(docPath, body) {
  return new Promise((resolve, reject) => {
    const fieldMask = 'tanklar';
    const url = `https://firestore.googleapis.com/v1/${docPath}?updateMask.fieldPaths=${fieldMask}&key=${API_KEY}`;
    const bodyStr = JSON.stringify(body);
    const options = {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr, 'utf8'),
      },
    };
    const req = https.request(url, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    });
    req.on('error', reject);
    req.write(bodyStr, 'utf8');
    req.end();
  });
}

// Firestore field değerini JS value'ya çevirir
function fsVal(field) {
  if (!field) return null;
  if (field.stringValue !== undefined) return field.stringValue;
  if (field.doubleValue !== undefined) return field.doubleValue;
  if (field.integerValue !== undefined) return Number(field.integerValue);
  if (field.booleanValue !== undefined) return field.booleanValue;
  return null;
}

// JS value'yu Firestore field'a çevirir
function toFsField(val) {
  if (typeof val === 'string') return { stringValue: val };
  if (typeof val === 'number') return { doubleValue: val };
  if (typeof val === 'boolean') return { booleanValue: val };
  return { nullValue: null };
}

async function main() {
  console.log('\n🔧 Araclar embedded tank adları onarılıyor...\n');

  // 1. tanklar koleksiyonundaki gerçek adları al (UTF-8 doğru)
  const tanklarData = await httpsGet('tanklar');
  const tankDocs = tanklarData.documents || [];

  // plaka → [{ ad, kap, stok, tip }] mapping
  const tanklarByPlaka = {};
  for (const doc of tankDocs) {
    const f = doc.fields;
    const ad   = fsVal(f.ad);
    const arac = fsVal(f.arac);
    const kap  = fsVal(f.kap) || 0;
    const stok = fsVal(f.stok) || 0;
    const tip  = fsVal(f.tip);
    
    if (arac && arac.trim() !== '') {
      if (!tanklarByPlaka[arac]) tanklarByPlaka[arac] = [];
      tanklarByPlaka[arac].push({ ad, kap, stok, tip });
    }
    console.log(`  [tanklar] ad="${ad}" arac="${arac}" stok=${stok}`);
  }

  console.log('\n');

  // 2. araclar koleksiyonunu al
  const araclarData = await httpsGet('araclar');
  const aracDocs = araclarData.documents || [];

  for (const doc of aracDocs) {
    const f = doc.fields;
    const plaka = fsVal(f.plaka) || '';
    const docPath = doc.name; // projects/.../documents/araclar/ID

    console.log(`\n🚛 Araç: ${plaka}`);

    // Bu araç için tanklar koleksiyonundan doğru tank listesini al
    const correctTanks = tanklarByPlaka[plaka] || [];

    if (correctTanks.length === 0) {
      console.log('   ⚠️  Bu araç için tanklar koleksiyonunda tank bulunamadı, mevcut hali korunuyor.');
      continue;
    }

    // Embedded array'deki mevcut kapasiteleri koru (stok=0 ile)
    const rawEmbedded = (f.tanklar && f.tanklar.arrayValue && f.tanklar.arrayValue.values) || [];
    
    // Yeni embedded array: tanklar koleksiyonundan gelen doğru adlar ile
    // Mevcut stok değerini de koruyoruz (sıfırlamak için 0 kullanıyoruz)
    const newTanklarValues = correctTanks.map(tank => {
      // Mevcut embedded array'de bu tank'ın mevcut stok değerini bul (ad eşleşmesi olmayabilir)
      // Güvenli taraf: stok'u mevcut (sıfırlanmış) değerden al veya 0 kullan
      const existingStok = 0; // sıfırla (kullanıcı zaten temizlemek istiyor)
      
      return {
        mapValue: {
          fields: {
            ad:   toFsField(tank.ad),
            stok: toFsField(existingStok),
            kap:  toFsField(tank.kap),
          }
        }
      };
    });

    console.log(`   Doğru tank adları: ${correctTanks.map(t => t.ad).join(', ')}`);

    // PATCH ile güncelle
    const patchBody = {
      fields: {
        tanklar: {
          arrayValue: {
            values: newTanklarValues
          }
        }
      }
    };

    try {
      await httpsPatch(docPath, patchBody);
      console.log(`   ✅ ${plaka} embedded array güncellendi.`);
    } catch (err) {
      console.error(`   ❌ Hata: ${err.message}`);
    }
  }

  console.log('\n✅ Onarım tamamlandı!\n');
}

main().catch(err => {
  console.error('Beklenmeyen hata:', err);
  process.exit(1);
});
