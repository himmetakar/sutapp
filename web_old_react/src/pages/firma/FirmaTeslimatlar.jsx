import { useState, useEffect } from 'react';
import { FiPlus, FiX, FiCheck } from 'react-icons/fi';
import { db } from '../../firebase/config';
import { useAuth } from '../../contexts/AuthContext';
import { collection, query, where, onSnapshot } from 'firebase/firestore';

const demoTeslimatlar = [
  { id: 1, kamyon: '38 AB 123', surucu: 'Ahmet Kara', toppinan: 520, teslim: 515, fark: 5, tarih: '25.05.2026', saat: '17:30', onaylayan: 'Kemal Bey' },
  { id: 2, kamyon: '38 CD 456', surucu: 'Veli Yıldız', toppinan: 850, teslim: 842, fark: 8, tarih: '25.05.2026', saat: '17:45', onaylayan: 'Kemal Bey' },
  { id: 3, kamyon: '38 GH 012', surucu: 'Hasan Çelik', toppinan: 1200, teslim: 1188, fark: 12, tarih: '24.05.2026', saat: '18:00', onaylayan: 'Kemal Bey' },
  { id: 4, kamyon: '38 IJ 345', surucu: 'Murat Aydın', toppinan: 310, teslim: 308, fark: 2, tarih: '24.05.2026', saat: '17:15', onaylayan: 'Ali Bey' },
];

const kamyonlar = [
  { plaka: '38 AB 123', surucu: 'Ahmet Kara', stok: 420 },
  { plaka: '38 CD 456', surucu: 'Veli Yıldız', stok: 850 },
  { plaka: '38 GH 012', surucu: 'Hasan Çelik', stok: 1200 },
  { plaka: '38 IJ 345', surucu: 'Murat Aydın', stok: 310 },
];

export default function FirmaTeslimatlar() {
  const { user } = useAuth();
  const currentFirmaName = user?.displayName || '';

  const [showModal, setShowModal] = useState(false);
  const [selectedKamyon, setSelectedKamyon] = useState('');
  const [teslimMiktar, setTeslimMiktar] = useState('');
  const [tanklar, setTanklar] = useState([]);
  const [loadingTanks, setLoadingTanks] = useState(true);

  useEffect(() => {
    if (!currentFirmaName) return;

    const qTanklar = query(
      collection(db, 'tanklar'),
      where('firma', '==', currentFirmaName),
      where('tip', '==', 'merkez')
    );

    const unsubscribe = onSnapshot(qTanklar, (snapshot) => {
      const list = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
      }));
      setTanklar(list);
      setLoadingTanks(false);
    }, (err) => {
      console.error('Error fetching tanks:', err);
      setLoadingTanks(false);
    });

    return () => unsubscribe();
  }, [currentFirmaName]);

  const selectedKamyonData = kamyonlar.find(k => k.plaka === selectedKamyon);

  const totalStok = tanklar.reduce((sum, t) => sum + (parseFloat(t.stok || t.currentStock) || 0), 0);
  const totalKapasite = tanklar.reduce((sum, t) => sum + (parseFloat(t.kap || t.kapasite) || 0), 0);
  const pct = totalKapasite > 0 ? Math.round((totalStok / totalKapasite) * 100) : 0;

  return (
    <div className="fade-in">
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '20px' }}>
        <button className="btn btn-primary" onClick={() => setShowModal(true)}>
          <FiPlus /> Yeni Merkez Teslimat
        </button>
      </div>

      {/* Merkez Tanker Durumu */}
      <div className="card" style={{ marginBottom: '20px', padding: '24px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
          <div>
            <div style={{ fontSize: '13px', color: '#64748b' }}>Merkez Tanker Toplam Stok</div>
            <div style={{ fontSize: '36px', fontWeight: 700, color: '#1e293b' }}>
              {loadingTanks ? '...' : totalStok.toLocaleString('tr-TR')} <span style={{ fontSize: '16px', fontWeight: 400, color: '#94a3b8' }}>/ {loadingTanks ? '...' : totalKapasite.toLocaleString('tr-TR')} LT</span>
            </div>
          </div>
          <div style={{
            width: '80px',
            height: '80px',
            borderRadius: '50%',
            border: '6px solid #dbeafe',
            borderTopColor: '#3b82f6',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '18px',
            fontWeight: 700,
            color: '#2563eb',
            transform: 'rotate(45deg)'
          }}>
            <span style={{ transform: 'rotate(-45deg)' }}>%{pct}</span>
          </div>
        </div>

        {/* Individual Tank Breakdown */}
        {!loadingTanks && tanklar.length > 0 && (
          <div style={{ display: 'flex', flexDirection: 'column', gap: '10px', borderTop: '1px solid #f1f5f9', paddingTop: '16px', marginTop: '16px' }}>
            <div style={{ fontSize: '12px', fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.05em', marginBottom: '4px' }}>Tank Detayları</div>
            {tanklar.map(t => {
              const current = parseFloat(t.stok || t.currentStock || 0);
              const capacity = parseFloat(t.kap || t.kapasite || 10000);
              const name = t.ad || t.tankAdi || 'Merkez Tankı';
              const tankPct = capacity > 0 ? (current / capacity) * 100 : 0;
              return (
                <div key={t.id} style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '13px' }}>
                  <span style={{ fontWeight: 500, color: '#334155' }}>🏭 {name}</span>
                  <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
                    <span style={{ fontWeight: 600, color: '#1e293b' }}>{current.toLocaleString('tr-TR')} / {capacity.toLocaleString('tr-TR')} L</span>
                    <span style={{ color: '#2563eb', fontWeight: 600, minWidth: '40px', textAlign: 'right' }}>%{Math.round(tankPct)}</span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>

      {/* Teslimat Table */}
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Merkez Teslimat Geçmişi</h3>
        </div>
        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Kamyon</th>
                <th>Sürücü</th>
                <th>Toplanan (Kamyon)</th>
                <th>Teslim Edilen (Merkez)</th>
                <th>Fark (Fire)</th>
                <th>Tarih</th>
                <th>Saat</th>
                <th>Onaylayan</th>
              </tr>
            </thead>
            <tbody>
              {demoTeslimatlar.map(t => (
                <tr key={t.id}>
                  <td style={{ fontWeight: 500 }}>{t.kamyon}</td>
                  <td>{t.surucu}</td>
                  <td style={{ fontWeight: 600 }}>{t.toppinan} LT</td>
                  <td style={{ fontWeight: 600, color: '#2563eb' }}>{t.teslim} LT</td>
                  <td>
                    <span className={`badge ${t.fark > 10 ? 'badge-danger' : 'badge-warning'}`}>
                      -{t.fark} LT
                    </span>
                  </td>
                  <td style={{ fontSize: '13px' }}>{t.tarih}</td>
                  <td style={{ fontSize: '13px', color: '#64748b' }}>{t.saat}</td>
                  <td style={{ fontSize: '13px' }}>{t.onaylayan}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Teslimat Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Merkez Tanker Teslimatı</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}><FiX /></button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label>Kamyon Seçin</label>
                <select value={selectedKamyon} onChange={e => setSelectedKamyon(e.target.value)}>
                  <option value="">Kamyon seçin...</option>
                  {kamyonlar.map(k => (
                    <option key={k.plaka} value={k.plaka}>{k.plaka} — {k.surucu} ({k.stok} LT)</option>
                  ))}
                </select>
              </div>
              {selectedKamyonData && (
                <div style={{
                  padding: '14px',
                  background: '#eff6ff',
                  borderRadius: '10px',
                  marginBottom: '16px',
                  fontSize: '13px',
                  color: '#1e40af'
                }}>
                  <strong>{selectedKamyonData.plaka}</strong> kamyonunda şu an <strong>{selectedKamyonData.stok} LT</strong> süt bulunmaktadır.
                </div>
              )}
              <div className="form-group">
                <label>Ölçülen Miktar (Litre)</label>
                <input
                  type="number"
                  placeholder="Merkez tartı sonucu"
                  value={teslimMiktar}
                  onChange={e => setTeslimMiktar(e.target.value)}
                />
              </div>
              {selectedKamyonData && teslimMiktar && (
                <div style={{
                  padding: '14px',
                  background: Number(teslimMiktar) < selectedKamyonData.stok ? '#fef3c7' : '#d1fae5',
                  borderRadius: '10px',
                  fontSize: '13px',
                  color: Number(teslimMiktar) < selectedKamyonData.stok ? '#92400e' : '#065f46'
                }}>
                  Fark (Fire): <strong>{Math.abs(selectedKamyonData.stok - Number(teslimMiktar))} LT</strong>
                  {Number(teslimMiktar) < selectedKamyonData.stok ? ' (kayıp)' : ' (tam teslim)'}
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>İptal</button>
              <button className="btn btn-success" onClick={() => setShowModal(false)}>
                <FiCheck /> Teslimatı Onayla
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
