import {
  collection,
  doc,
  setDoc,
  getDoc,
  getDocs,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  onSnapshot,
  serverTimestamp,
  addDoc,
  Timestamp
} from 'firebase/firestore';
import {
  createUserWithEmailAndPassword,
  signInWithEmailAndPassword,
  signOut,
  updateProfile
} from 'firebase/auth';
import { auth, db } from './config';

// ========================
// AUTH İŞLEMLERİ
// ========================

export const loginUser = async (email, password) => {
  const userCredential = await signInWithEmailAndPassword(auth, email, password);
  const userDoc = await getDoc(doc(db, 'users', userCredential.user.uid));
  return { ...userCredential.user, ...userDoc.data() };
};

export const registerUser = async (email, password, displayName, role, extra = {}) => {
  const userCredential = await createUserWithEmailAndPassword(auth, email, password);
  await updateProfile(userCredential.user, { displayName });

  const userData = {
    email,
    displayName,
    role,
    ...extra,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };

  await setDoc(doc(db, 'users', userCredential.user.uid), userData);
  return { ...userCredential.user, ...userData };
};

export const logoutUser = () => signOut(auth);

export const getUserData = async (uid) => {
  const snap = await getDoc(doc(db, 'users', uid));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
};

export const createUserProfile = async (uid, data) => {
  const userData = {
    ...data,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp()
  };
  await setDoc(doc(db, 'users', uid), userData);

  // If the registered user is a producer (uretici), sync to ureticiler collection
  if (data.role === 'uretici') {
    const phone = data.phone || '';
    const ureticilerRef = collection(db, 'ureticiler');
    const q = query(ureticilerRef, where('phone', '==', phone), limit(1));
    const querySnapshot = await getDocs(q);

    if (querySnapshot.empty) {
      await addDoc(collection(db, 'ureticiler'), {
        name: data.displayName || data.name || '',
        phone: phone,
        group: data.mahalleKoy || '',
        bolge: data.ilce || '',
        total: 0.0,
        avg: 30.0,
        firmalar: []
      });
    } else {
      const docRef = querySnapshot.docs[0].ref;
      await updateDoc(docRef, {
        name: data.displayName || data.name || '',
        group: data.mahalleKoy || '',
        bolge: data.ilce || ''
      });
    }
  }
};


// ========================
// FİRMA İŞLEMLERİ
// ========================

export const addFirma = async (data) => {
  const ref = await addDoc(collection(db, 'firmalar'), {
    ...data,
    subscription: {
      plan: 'kucuk',
      status: 'active',
      startDate: Timestamp.now(),
      endDate: Timestamp.fromDate(new Date(Date.now() + 30 * 24 * 60 * 60 * 1000))
    },
    createdAt: serverTimestamp()
  });
  return ref.id;
};

export const getFirmalar = async () => {
  const snap = await getDocs(collection(db, 'firmalar'));
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const getFirma = async (firmaId) => {
  const snap = await getDoc(doc(db, 'firmalar', firmaId));
  return snap.exists() ? { id: snap.id, ...snap.data() } : null;
};

export const updateFirma = async (firmaId, data) => {
  await updateDoc(doc(db, 'firmalar', firmaId), { ...data, updatedAt: serverTimestamp() });
};

export const deleteFirma = async (firmaId) => {
  await deleteDoc(doc(db, 'firmalar', firmaId));
};

// ========================
// ARAÇ İŞLEMLERİ
// Araç: plaka bazlı, birden fazla sürücü atanabilir, birden fazla tank atanabilir
// ========================

export const addArac = async (data) => {
  const ref = await addDoc(collection(db, 'araclar'), {
    firmaId: data.firmaId,
    plaka: data.plaka,
    surucuIds: data.surucuIds || [],   // çoktan çoğa: birden fazla sürücü
    status: 'active',
    createdAt: serverTimestamp()
  });
  return ref.id;
};

export const getAraclar = async (firmaId) => {
  const q = query(collection(db, 'araclar'), where('firmaId', '==', firmaId));
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const updateArac = async (aracId, data) => {
  await updateDoc(doc(db, 'araclar', aracId), { ...data, updatedAt: serverTimestamp() });
};

export const deleteArac = async (aracId) => {
  await deleteDoc(doc(db, 'araclar', aracId));
};

// ========================
// SÜRÜCÜ İŞLEMLERİ
// Sürücü: ad, soyad, telefon, email (opsiyonel), tcKimlik
// Bir sürücüye birden fazla üretici (müşteri) atanabilir
// ========================

export const addSurucu = async (data) => {
  const ref = await addDoc(collection(db, 'suruculer'), {
    firmaId: data.firmaId,
    ad: data.ad,
    soyad: data.soyad,
    telefon: data.telefon,
    email: data.email || '',
    tcKimlik: data.tcKimlik,
    ureticiIds: data.ureticiIds || [],  // çoktan çoğa: birden fazla üretici
    status: 'active',
    createdAt: serverTimestamp()
  });
  return ref.id;
};

export const getSuruculer = async (firmaId) => {
  const q = query(collection(db, 'suruculer'), where('firmaId', '==', firmaId));
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const updateSurucu = async (surucuId, data) => {
  await updateDoc(doc(db, 'suruculer', surucuId), { ...data, updatedAt: serverTimestamp() });
};

export const deleteSurucu = async (surucuId) => {
  await deleteDoc(doc(db, 'suruculer', surucuId));
};

// ========================
// TANK İŞLEMLERİ
// İki tip: 'arac' (araç tankı) ve 'merkez' (merkez tankı)
// Araç tankı bir araca bağlıdır (aracId), merkez tankı bağımsız
// Bir araca birden fazla tank atanabilir
// ========================

export const addTank = async (data) => {
  const ref = await addDoc(collection(db, 'tanklar'), {
    firmaId: data.firmaId,
    tankAdi: data.tankAdi,
    kapasite: data.kapasite,
    tip: data.tip,              // 'arac' | 'merkez'
    aracId: data.aracId || null, // araç tankı ise ilgili aracId
    currentStock: 0,
    status: 'active',
    createdAt: serverTimestamp()
  });
  return ref.id;
};

export const getTanklar = async (firmaId) => {
  const q = query(collection(db, 'tanklar'), where('firmaId', '==', firmaId));
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const getAracTanklari = async (firmaId, aracId) => {
  const q = query(
    collection(db, 'tanklar'),
    where('firmaId', '==', firmaId),
    where('aracId', '==', aracId)
  );
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const getMerkezTanklari = async (firmaId) => {
  const q = query(
    collection(db, 'tanklar'),
    where('firmaId', '==', firmaId),
    where('tip', '==', 'merkez')
  );
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const updateTank = async (tankId, data) => {
  await updateDoc(doc(db, 'tanklar', tankId), { ...data, updatedAt: serverTimestamp() });
};

export const deleteTank = async (tankId) => {
  await deleteDoc(doc(db, 'tanklar', tankId));
};

// ========================
// ÜRETİCİ İŞLEMLERİ
// ========================

export const addUretici = async (data) => {
  const ref = await addDoc(collection(db, 'ureticiler'), {
    ...data,
    totalDelivered: 0,
    createdAt: serverTimestamp()
  });
  return ref.id;
};

export const getUreticiler = async (firmaId) => {
  const q = query(collection(db, 'ureticiler'), where('firmaId', '==', firmaId));
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

export const updateUretici = async (ureticiId, data) => {
  await updateDoc(doc(db, 'ureticiler', ureticiId), data);
};

export const deleteUretici = async (ureticiId) => {
  await deleteDoc(doc(db, 'ureticiler', ureticiId));
};

// ========================
// SÜT TOPLAMA İŞLEMLERİ
// Her toplama kaydı hangi tank'a konulduğu bilgisini tutar.
// Bu sayede "X tankına son 1 haftada hangi üreticilerden süt alınmış?" sorgulanabilir.
// ========================

export const addToplama = async (data) => {
  const ref = await addDoc(collection(db, 'toplamalar'), {
    firmaId: data.firmaId,
    surucuId: data.surucuId,
    aracId: data.aracId,
    tankId: data.tankId,         // hangi tanka konuldu
    ureticiId: data.ureticiId,
    miktar: data.miktar,
    synced: true,
    createdAt: serverTimestamp()
  });

  // Tank stoğunu güncelle
  const tankSnap = await getDoc(doc(db, 'tanklar', data.tankId));
  if (tankSnap.exists()) {
    const currentStock = tankSnap.data().currentStock || 0;
    await updateDoc(doc(db, 'tanklar', data.tankId), {
      currentStock: currentStock + data.miktar
    });
  }

  // Üretici toplam teslimini güncelle
  if (data.ureticiId) {
    const ureticiSnap = await getDoc(doc(db, 'ureticiler', data.ureticiId));
    if (ureticiSnap.exists()) {
      const total = ureticiSnap.data().totalDelivered || 0;
      await updateDoc(doc(db, 'ureticiler', data.ureticiId), {
        totalDelivered: total + data.miktar
      });
    }
  }

  return ref.id;
};

export const getToplamalar = async (firmaId, filters = {}) => {
  let q = query(
    collection(db, 'toplamalar'),
    where('firmaId', '==', firmaId),
    orderBy('createdAt', 'desc')
  );

  if (filters.limit) {
    q = query(q, limit(filters.limit));
  }

  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

// Tank içeriğini sorgula: Belirli bir tank'a hangi üreticilerden ne zaman süt konmuş?
export const getTankIcerigi = async (tankId, startDate, endDate) => {
  let q = query(
    collection(db, 'toplamalar'),
    where('tankId', '==', tankId),
    orderBy('createdAt', 'desc')
  );

  // Not: Firestore'da composite where ile tarih aralığı filtrelemek için index gerekir.
  // Client-side filtering de yapılabilir.
  const snap = await getDocs(q);
  let results = snap.docs.map(d => ({ id: d.id, ...d.data() }));

  if (startDate) {
    results = results.filter(r => r.createdAt?.toDate?.() >= startDate);
  }
  if (endDate) {
    results = results.filter(r => r.createdAt?.toDate?.() <= endDate);
  }

  return results;
};

// ========================
// MERKEZ TESLİMAT İŞLEMLERİ
// Araç tankından merkez tankına transfer
// ========================

export const addMerkezTeslimat = async (data) => {
  const ref = await addDoc(collection(db, 'merkezTeslimat'), {
    firmaId: data.firmaId,
    aracId: data.aracId,
    kaynakTankId: data.kaynakTankId,     // araç tankı (kaynak)
    hedefTankId: data.hedefTankId,       // merkez tankı (hedef)
    surucuId: data.surucuId,
    toppinanMiktar: data.toppinanMiktar, // araç tankındaki miktar
    teslimMiktar: data.teslimMiktar,     // merkez tartısı
    fark: data.toppinanMiktar - data.teslimMiktar,
    onaylayan: data.onaylayan,
    createdAt: serverTimestamp()
  });

  // Kaynak (araç) tankını sıfırla
  await updateDoc(doc(db, 'tanklar', data.kaynakTankId), {
    currentStock: 0
  });

  // Hedef (merkez) tankına ekle
  const merkezSnap = await getDoc(doc(db, 'tanklar', data.hedefTankId));
  if (merkezSnap.exists()) {
    const currentStock = merkezSnap.data().currentStock || 0;
    await updateDoc(doc(db, 'tanklar', data.hedefTankId), {
      currentStock: currentStock + data.teslimMiktar,
      lastUpdated: serverTimestamp()
    });
  }

  return ref.id;
};

export const getMerkezTeslimatlar = async (firmaId) => {
  const q = query(
    collection(db, 'merkezTeslimat'),
    where('firmaId', '==', firmaId),
    orderBy('createdAt', 'desc')
  );
  const snap = await getDocs(q);
  return snap.docs.map(d => ({ id: d.id, ...d.data() }));
};

// ========================
// REALTIME LISTENERS
// ========================

export const onTanklarChange = (firmaId, callback) => {
  const q = query(collection(db, 'tanklar'), where('firmaId', '==', firmaId));
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
};

export const onToplamalarChange = (firmaId, callback) => {
  const q = query(
    collection(db, 'toplamalar'),
    where('firmaId', '==', firmaId),
    orderBy('createdAt', 'desc'),
    limit(50)
  );
  return onSnapshot(q, (snap) => {
    callback(snap.docs.map(d => ({ id: d.id, ...d.data() })));
  });
};
