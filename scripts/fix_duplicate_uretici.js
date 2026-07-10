/**
 * fix_duplicate_uretici.js
 * "Anıl Demir" üreticisinin mükerrer kaydını siler.
 * Daha yeni timestamp'li kaydı korur, eskisini siler.
 */

const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

const PROJECT_ID = 'sutapp93';

async function main() {
  const app = initializeApp({
    credential: applicationDefault(),
    projectId: PROJECT_ID,
  });

  const db = getFirestore(app);

  console.log('\n🔍 "Anıl Demir" üreticisi aranıyor...\n');

  // name alanına göre sorgula
  const snap = await db.collection('ureticiler')
    .where('name', '==', 'Anıl Demir')
    .get();

  if (snap.empty) {
    // Büyük/küçük harf farkı olabilir, tümünü çek ve filtrele
    console.log('Direkt sorgu bulunamadı, tüm ureticiler taranıyor...');
    const allSnap = await db.collection('ureticiler').get();
    const matches = allSnap.docs.filter(d => {
      const name = (d.data()['name'] ?? '').toLowerCase().replace(/\s+/g, ' ').trim();
      return name.includes('anıl') || name.includes('anil') || name.includes('demir');
    });

    if (matches.length === 0) {
      console.log('❌ "Anıl Demir" bulunamadı!');
      console.log('\nTüm üreticiler:');
      allSnap.docs.forEach(d => console.log(' -', d.id, '|', d.data()['name']));
      process.exit(0);
    }

    console.log(`Bulunan eşleşmeler (${matches.length} adet):`);
    matches.forEach(d => {
      const data = d.data();
      console.log(`  ID: ${d.id}`);
      console.log(`  name: ${data['name']}`);
      console.log(`  firmalar: ${JSON.stringify(data['firmalar'])}`);
      console.log(`  timestamp: ${data['timestamp']?.toDate?.() ?? 'yok'}`);
      console.log('');
    });

    if (matches.length < 2) {
      console.log('ℹ️  Sadece 1 kayıt var, silme gerekmez.');
      process.exit(0);
    }

    await deleteOlderDuplicate(db, matches);
  } else {
    console.log(`Bulunan kayıt sayısı: ${snap.docs.length}`);
    snap.docs.forEach(d => {
      const data = d.data();
      console.log(`  ID: ${d.id}`);
      console.log(`  name: ${data['name']}`);
      console.log(`  firmalar: ${JSON.stringify(data['firmalar'])}`);
      console.log(`  timestamp: ${data['timestamp']?.toDate?.() ?? 'yok'}`);
      console.log('');
    });

    if (snap.docs.length < 2) {
      console.log('ℹ️  Sadece 1 kayıt var, mükerrer yok.');
      process.exit(0);
    }

    await deleteOlderDuplicate(db, snap.docs);
  }

  process.exit(0);
}

async function deleteOlderDuplicate(db, docs) {
  // timestamp'e göre sırala, en yeniyi koru, eskisini sil
  const sorted = [...docs].sort((a, b) => {
    const aTs = a.data()['timestamp']?.toMillis?.() ?? 0;
    const bTs = b.data()['timestamp']?.toMillis?.() ?? 0;
    return bTs - aTs; // yeniden eskiye
  });

  const toKeep = sorted[0];
  const toDelete = sorted.slice(1);

  console.log(`\n✅ Korunacak: ${toKeep.id} (${toKeep.data()['name']})`);

  for (const doc of toDelete) {
    console.log(`🗑️  Siliniyor: ${doc.id} (${doc.data()['name']})`);
    await db.collection('ureticiler').doc(doc.id).delete();
    console.log(`   ✅ Silindi.`);
  }

  console.log('\n✅ Mükerrer kayıt temizlendi!\n');
}

main().catch(err => {
  console.error('Hata:', err.message);
  process.exit(1);
});
