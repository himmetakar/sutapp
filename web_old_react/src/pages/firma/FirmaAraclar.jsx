import { useState } from 'react';
import { FiPlus, FiX, FiTruck, FiEdit2, FiTrash2, FiUser, FiBox } from 'react-icons/fi';

// Demo sürücüler (atama için)
const demoSuruculer = [
  { id: 's1', ad: 'Ahmet', soyad: 'Kara', telefon: '0532 100 0001' },
  { id: 's2', ad: 'Veli', soyad: 'Yıldız', telefon: '0532 100 0002' },
  { id: 's3', ad: 'Ali', soyad: 'Demir', telefon: '0532 100 0003' },
  { id: 's4', ad: 'Hasan', soyad: 'Çelik', telefon: '0532 100 0004' },
  { id: 's5', ad: 'Murat', soyad: 'Aydın', telefon: '0532 100 0005' },
];

// Demo araç tankları
const demoTanklar = [
  { id: 't1', tankAdi: 'Tank-A1', kapasite: 2000, aracId: 'a1', currentStock: 420 },
  { id: 't2', tankAdi: 'Tank-A2', kapasite: 1500, aracId: 'a1', currentStock: 180 },
  { id: 't3', tankAdi: 'Tank-B1', kapasite: 2500, aracId: 'a2', currentStock: 850 },
  { id: 't4', tankAdi: 'Tank-C1', kapasite: 1500, aracId: 'a3', currentStock: 0 },
  { id: 't5', tankAdi: 'Tank-D1', kapasite: 3000, aracId: 'a4', currentStock: 1200 },
  { id: 't6', tankAdi: 'Tank-D2', kapasite: 2000, aracId: 'a4', currentStock: 600 },
  { id: 't7', tankAdi: 'Tank-E1', kapasite: 1500, aracId: 'a5', currentStock: 310 },
];

const demoAraclar = [
  { id: 'a1', plaka: '38 AB 123', surucuIds: ['s1', 's2'], status: 'active' },
  { id: 'a2', plaka: '38 CD 456', surucuIds: ['s2'], status: 'active' },
  { id: 'a3', plaka: '38 EF 789', surucuIds: ['s3'], status: 'active' },
  { id: 'a4', plaka: '38 GH 012', surucuIds: ['s4', 's5'], status: 'active' },
  { id: 'a5', plaka: '38 IJ 345', surucuIds: ['s5'], status: 'inactive' },
];

export default function FirmaAraclar() {
  const [showModal, setShowModal] = useState(false);
  const [plaka, setPlaka] = useState('');
  const [selectedSuruculer, setSelectedSuruculer] = useState([]);

  const toggleSurucu = (id) => {
    setSelectedSuruculer(prev =>
      prev.includes(id) ? prev.filter(s => s !== id) : [...prev, id]
    );
  };

  const getSurucuNames = (ids) => {
    return ids.map(id => {
      const s = demoSuruculer.find(d => d.id === id);
      return s ? `${s.ad} ${s.soyad}` : id;
    });
  };

  const getAracTanklar = (aracId) => {
    return demoTanklar.filter(t => t.aracId === aracId);
  };

  return (
    <div className="fade-in">
      <div style={{ display: 'flex', justifyContent: 'flex-end', marginBottom: '20px' }}>
        <button className="btn btn-primary" onClick={() => setShowModal(true)}>
          <FiPlus /> Araç Ekle
        </button>
      </div>

      {/* Araç Kartları */}
      <div style={{
        display: 'grid',
        gridTemplateColumns: 'repeat(auto-fill, minmax(380px, 1fr))',
        gap: '20px'
      }}>
        {demoAraclar.map(arac => {
          const tanklar = getAracTanklar(arac.id);
          const toplamStok = tanklar.reduce((s, t) => s + t.currentStock, 0);
          const toplamKapasite = tanklar.reduce((s, t) => s + t.kapasite, 0);
          const suruculer = getSurucuNames(arac.surucuIds);

          return (
            <div key={arac.id} className="card" style={{ padding: '0', overflow: 'hidden' }}>
              {/* Header */}
              <div style={{
                padding: '20px',
                background: arac.status === 'active' ? 'linear-gradient(135deg, #eff6ff, #dbeafe)' : '#f8fafc',
                borderBottom: '1px solid #e2e8f0',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'space-between'
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: '14px' }}>
                  <div style={{
                    width: '48px', height: '48px', borderRadius: '12px',
                    background: '#fff', display: 'flex', alignItems: 'center',
                    justifyContent: 'center', boxShadow: '0 2px 8px rgba(0,0,0,0.06)'
                  }}>
                    <FiTruck size={24} color={arac.status === 'active' ? '#2563eb' : '#94a3b8'} />
                  </div>
                  <div>
                    <div style={{ fontSize: '20px', fontWeight: 700, color: '#0f172a', letterSpacing: '0.02em' }}>
                      {arac.plaka}
                    </div>
                    <span className={`badge ${arac.status === 'active' ? 'badge-active' : 'badge-inactive'}`}>
                      {arac.status === 'active' ? 'Aktif' : 'Pasif'}
                    </span>
                  </div>
                </div>
                <div style={{ display: 'flex', gap: '4px' }}>
                  <button className="btn btn-ghost btn-sm"><FiEdit2 /></button>
                  <button className="btn btn-ghost btn-sm" style={{ color: '#ef4444' }}><FiTrash2 /></button>
                </div>
              </div>

              {/* Atanmış Sürücüler */}
              <div style={{ padding: '16px 20px', borderBottom: '1px solid #f1f5f9' }}>
                <div style={{ fontSize: '12px', fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '8px' }}>
                  <FiUser size={12} style={{ marginRight: '4px', verticalAlign: '-1px' }} />
                  Atanmış Sürücüler ({arac.surucuIds.length})
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: '6px' }}>
                  {suruculer.map((name, i) => (
                    <span key={i} className="badge badge-info">{name}</span>
                  ))}
                </div>
              </div>

              {/* Atanmış Tanklar */}
              <div style={{ padding: '16px 20px' }}>
                <div style={{ fontSize: '12px', fontWeight: 600, color: '#64748b', textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: '10px' }}>
                  <FiBox size={12} style={{ marginRight: '4px', verticalAlign: '-1px' }} />
                  Araç Tankları ({tanklar.length})
                </div>

                {tanklar.length === 0 ? (
                  <div style={{ fontSize: '13px', color: '#94a3b8', fontStyle: 'italic' }}>Tank atanmamış</div>
                ) : (
                  <>
                    {tanklar.map(tank => {
                      const pct = tank.kapasite > 0 ? (tank.currentStock / tank.kapasite) * 100 : 0;
                      return (
                        <div key={tank.id} style={{ marginBottom: '10px' }}>
                          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '4px' }}>
                            <span style={{ fontSize: '13px', fontWeight: 500, color: '#334155' }}>{tank.tankAdi}</span>
                            <span style={{ fontSize: '13px', fontWeight: 600, color: pct > 80 ? '#f59e0b' : '#2563eb' }}>
                              {tank.currentStock.toLocaleString('tr-TR')} / {tank.kapasite.toLocaleString('tr-TR')} LT
                            </span>
                          </div>
                          <div style={{ width: '100%', height: '6px', background: '#f1f5f9', borderRadius: '99px' }}>
                            <div style={{
                              width: `${pct}%`, height: '100%',
                              background: pct > 80 ? 'linear-gradient(90deg, #f59e0b, #ef4444)' : 'linear-gradient(90deg, #93c5fd, #3b82f6)',
                              borderRadius: '99px', transition: 'width 0.5s ease'
                            }} />
                          </div>
                        </div>
                      );
                    })}
                    {/* Toplam */}
                    <div style={{
                      marginTop: '12px', paddingTop: '10px', borderTop: '1px solid #f1f5f9',
                      display: 'flex', justifyContent: 'space-between', fontSize: '13px'
                    }}>
                      <span style={{ color: '#64748b', fontWeight: 500 }}>Toplam Stok</span>
                      <span style={{ fontWeight: 700, color: '#0f172a' }}>
                        {toplamStok.toLocaleString('tr-TR')} / {toplamKapasite.toLocaleString('tr-TR')} LT
                      </span>
                    </div>
                  </>
                )}
              </div>
            </div>
          );
        })}
      </div>

      {/* Add Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Yeni Araç Ekle</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}><FiX /></button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label>Plaka</label>
                <input
                  type="text"
                  placeholder="XX XX XXX"
                  value={plaka}
                  onChange={e => setPlaka(e.target.value)}
                />
              </div>

              <div className="form-group">
                <label>Sürücü Ata (Birden fazla seçilebilir)</label>
                <div style={{
                  border: '1.5px solid #e2e8f0', borderRadius: '8px',
                  padding: '8px', maxHeight: '200px', overflowY: 'auto',
                  background: '#f8fafc'
                }}>
                  {demoSuruculer.map(s => (
                    <label key={s.id} style={{
                      display: 'flex', alignItems: 'center', gap: '10px',
                      padding: '8px 10px', borderRadius: '6px', cursor: 'pointer',
                      marginBottom: '2px',
                      background: selectedSuruculer.includes(s.id) ? '#dbeafe' : 'transparent',
                      transition: 'background 0.15s'
                    }}>
                      <input
                        type="checkbox"
                        checked={selectedSuruculer.includes(s.id)}
                        onChange={() => toggleSurucu(s.id)}
                        style={{ accentColor: '#2563eb' }}
                      />
                      <div>
                        <div style={{ fontSize: '13px', fontWeight: 500, color: '#1e293b' }}>{s.ad} {s.soyad}</div>
                        <div style={{ fontSize: '11px', color: '#64748b' }}>{s.telefon}</div>
                      </div>
                    </label>
                  ))}
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>İptal</button>
              <button className="btn btn-primary" onClick={() => { setShowModal(false); setPlaka(''); setSelectedSuruculer([]); }}>
                Araç Ekle
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
