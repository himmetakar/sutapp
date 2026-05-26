import { useState } from 'react';
import { FiPlus, FiX, FiBox, FiTruck, FiEdit2, FiTrash2, FiSearch, FiEye, FiChevronDown } from 'react-icons/fi';

const demoAraclar = [
  { id: 'a1', plaka: '38 AB 123' },
  { id: 'a2', plaka: '38 CD 456' },
  { id: 'a3', plaka: '38 EF 789' },
  { id: 'a4', plaka: '38 GH 012' },
  { id: 'a5', plaka: '38 IJ 345' },
];

const demoTanklar = [
  // Araç tankları
  { id: 't1', tankAdi: 'Tank-A1', kapasite: 2000, tip: 'arac', aracId: 'a1', currentStock: 420, status: 'active' },
  { id: 't2', tankAdi: 'Tank-A2', kapasite: 1500, tip: 'arac', aracId: 'a1', currentStock: 180, status: 'active' },
  { id: 't3', tankAdi: 'Tank-B1', kapasite: 2500, tip: 'arac', aracId: 'a2', currentStock: 850, status: 'active' },
  { id: 't4', tankAdi: 'Tank-C1', kapasite: 1500, tip: 'arac', aracId: 'a3', currentStock: 0, status: 'active' },
  { id: 't5', tankAdi: 'Tank-D1', kapasite: 3000, tip: 'arac', aracId: 'a4', currentStock: 1200, status: 'active' },
  { id: 't6', tankAdi: 'Tank-D2', kapasite: 2000, tip: 'arac', aracId: 'a4', currentStock: 600, status: 'active' },
  { id: 't7', tankAdi: 'Tank-E1', kapasite: 1500, tip: 'arac', aracId: 'a5', currentStock: 310, status: 'active' },
  // Merkez tankları
  { id: 't8', tankAdi: 'Merkez Tank #1', kapasite: 10000, tip: 'merkez', aracId: null, currentStock: 4850, status: 'active' },
  { id: 't9', tankAdi: 'Merkez Tank #2', kapasite: 8000, tip: 'merkez', aracId: null, currentStock: 2200, status: 'active' },
  { id: 't10', tankAdi: 'Merkez Tank #3', kapasite: 5000, tip: 'merkez', aracId: null, currentStock: 0, status: 'inactive' },
];

// Demo: tankın son 1 haftalık içeriği
const demoTankIcerigi = {
  't1': [
    { uretici: 'Mehmet Yılmaz', miktar: 45, tarih: '25.05.2026', saat: '07:15' },
    { uretici: 'Fatma Korkmaz', miktar: 32, tarih: '25.05.2026', saat: '07:32' },
    { uretici: 'Zeynep Demir', miktar: 22, tarih: '25.05.2026', saat: '08:40' },
    { uretici: 'Mehmet Yılmaz', miktar: 48, tarih: '24.05.2026', saat: '07:10' },
    { uretici: 'Fatma Korkmaz', miktar: 35, tarih: '24.05.2026', saat: '07:30' },
  ],
  't8': [
    { uretici: '38 AB 123 teslimat', miktar: 515, tarih: '25.05.2026', saat: '17:30' },
    { uretici: '38 CD 456 teslimat', miktar: 842, tarih: '25.05.2026', saat: '17:45' },
    { uretici: '38 GH 012 teslimat', miktar: 1188, tarih: '24.05.2026', saat: '18:00' },
    { uretici: '38 AB 123 teslimat', miktar: 490, tarih: '23.05.2026', saat: '17:20' },
  ],
};

export default function FirmaTanklar() {
  const [search, setSearch] = useState('');
  const [filterTip, setFilterTip] = useState('tumu');
  const [showModal, setShowModal] = useState(false);
  const [showIcerikModal, setShowIcerikModal] = useState(null); // tankId
  const [form, setForm] = useState({ tankAdi: '', kapasite: '', tip: 'arac', aracId: '' });

  const filtered = demoTanklar.filter(t => {
    const matchSearch = t.tankAdi.toLowerCase().includes(search.toLowerCase());
    const matchTip = filterTip === 'tumu' || t.tip === filterTip;
    return matchSearch && matchTip;
  });

  const merkezTanklar = filtered.filter(t => t.tip === 'merkez');
  const aracTanklar = filtered.filter(t => t.tip === 'arac');

  const getPlaka = (aracId) => {
    const a = demoAraclar.find(d => d.id === aracId);
    return a ? a.plaka : '—';
  };

  const renderTankCard = (tank) => {
    const pct = tank.kapasite > 0 ? (tank.currentStock / tank.kapasite) * 100 : 0;
    const isMerkez = tank.tip === 'merkez';
    const icerik = demoTankIcerigi[tank.id] || [];

    return (
      <div key={tank.id} className="card" style={{ padding: '20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '16px' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <div style={{
              width: '44px', height: '44px', borderRadius: '10px',
              background: isMerkez ? 'linear-gradient(135deg, #dbeafe, #bfdbfe)' : '#eff6ff',
              display: 'flex', alignItems: 'center', justifyContent: 'center'
            }}>
              <FiBox size={20} color={isMerkez ? '#1d4ed8' : '#3b82f6'} />
            </div>
            <div>
              <div style={{ fontSize: '16px', fontWeight: 600, color: '#0f172a' }}>{tank.tankAdi}</div>
              <div style={{ fontSize: '12px', color: '#64748b' }}>
                {isMerkez ? '🏭 Merkez Tankı' : `🚛 ${getPlaka(tank.aracId)}`}
              </div>
            </div>
          </div>
          <div style={{ display: 'flex', gap: '4px', alignItems: 'center' }}>
            <span className={`badge ${tank.status === 'active' ? 'badge-active' : 'badge-inactive'}`}>
              {tank.status === 'active' ? 'Aktif' : 'Pasif'}
            </span>
            <button className="btn btn-ghost btn-sm"><FiEdit2 /></button>
            <button className="btn btn-ghost btn-sm" style={{ color: '#ef4444' }}><FiTrash2 /></button>
          </div>
        </div>

        {/* Gauge */}
        <div style={{ marginBottom: '6px', display: 'flex', justifyContent: 'space-between' }}>
          <span style={{ fontSize: '12px', color: '#64748b' }}>Doluluk</span>
          <span style={{ fontSize: '14px', fontWeight: 700, color: pct > 80 ? '#f59e0b' : '#2563eb' }}>
            {tank.currentStock.toLocaleString('tr-TR')} / {tank.kapasite.toLocaleString('tr-TR')} LT
          </span>
        </div>
        <div style={{ width: '100%', height: '10px', background: '#f1f5f9', borderRadius: '99px', marginBottom: '16px' }}>
          <div style={{
            width: `${pct}%`, height: '100%',
            background: pct === 0 ? '#e2e8f0' : pct > 80 ? 'linear-gradient(90deg, #f59e0b, #ef4444)' : 'linear-gradient(90deg, #93c5fd, #3b82f6)',
            borderRadius: '99px', transition: 'width 0.5s ease'
          }} />
        </div>

        {/* Tank İçeriği Butonu */}
        <button
          className="btn btn-outline btn-sm btn-block"
          onClick={() => setShowIcerikModal(tank.id)}
        >
          <FiEye /> Tank İçeriğini Görüntüle
        </button>
      </div>
    );
  };

  return (
    <div className="fade-in">
      {/* Filter bar */}
      <div className="card" style={{ padding: '14px 20px', marginBottom: '20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flexWrap: 'wrap', justifyContent: 'space-between' }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <span style={{ fontSize: '13px', color: '#64748b', fontWeight: 500 }}>Tip:</span>
            {[
              { key: 'tumu', label: 'Tümü' },
              { key: 'merkez', label: '🏭 Merkez Tankları' },
              { key: 'arac', label: '🚛 Araç Tankları' },
            ].map(f => (
              <button
                key={f.key}
                className={`btn btn-sm ${filterTip === f.key ? 'btn-primary' : 'btn-secondary'}`}
                onClick={() => setFilterTip(f.key)}
              >
                {f.label}
              </button>
            ))}
          </div>
          <div style={{ display: 'flex', gap: '10px' }}>
            <div style={{ position: 'relative' }}>
              <FiSearch style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
              <input
                type="text" placeholder="Tank ara..."
                value={search} onChange={e => setSearch(e.target.value)}
                style={{
                  padding: '8px 12px 8px 36px', border: '1.5px solid #e2e8f0',
                  borderRadius: '8px', fontSize: '13px', outline: 'none', width: '180px', fontFamily: 'inherit'
                }}
              />
            </div>
            <button className="btn btn-primary btn-sm" onClick={() => setShowModal(true)}>
              <FiPlus /> Tank Ekle
            </button>
          </div>
        </div>
      </div>

      {/* Merkez Tankları */}
      {(filterTip === 'tumu' || filterTip === 'merkez') && merkezTanklar.length > 0 && (
        <>
          <h3 style={{ fontSize: '15px', fontWeight: 600, color: '#334155', marginBottom: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            🏭 Merkez Tankları
            <span className="badge badge-info">{merkezTanklar.length}</span>
          </h3>
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))',
            gap: '16px',
            marginBottom: '28px'
          }}>
            {merkezTanklar.map(renderTankCard)}
          </div>
        </>
      )}

      {/* Araç Tankları */}
      {(filterTip === 'tumu' || filterTip === 'arac') && aracTanklar.length > 0 && (
        <>
          <h3 style={{ fontSize: '15px', fontWeight: 600, color: '#334155', marginBottom: '14px', display: 'flex', alignItems: 'center', gap: '8px' }}>
            🚛 Araç Tankları
            <span className="badge badge-info">{aracTanklar.length}</span>
          </h3>
          <div style={{
            display: 'grid',
            gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))',
            gap: '16px',
            marginBottom: '20px'
          }}>
            {aracTanklar.map(renderTankCard)}
          </div>
        </>
      )}

      {/* Tank Ekle Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Yeni Tank Ekle</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}><FiX /></button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label>Tank Adı *</label>
                <input type="text" placeholder="Örn: Merkez Tank #1, Tank-A1"
                  value={form.tankAdi} onChange={e => setForm({ ...form, tankAdi: e.target.value })} />
              </div>
              <div className="form-group">
                <label>Kapasite (Litre) *</label>
                <input type="number" placeholder="Örn: 2000"
                  value={form.kapasite} onChange={e => setForm({ ...form, kapasite: e.target.value })} />
              </div>
              <div className="form-group">
                <label>Tank Tipi *</label>
                <select value={form.tip} onChange={e => setForm({ ...form, tip: e.target.value, aracId: '' })}>
                  <option value="arac">🚛 Araç Tankı</option>
                  <option value="merkez">🏭 Merkez Tankı</option>
                </select>
              </div>
              {form.tip === 'arac' && (
                <div className="form-group">
                  <label>Bağlı Araç *</label>
                  <select value={form.aracId} onChange={e => setForm({ ...form, aracId: e.target.value })}>
                    <option value="">Araç seçin...</option>
                    {demoAraclar.map(a => (
                      <option key={a.id} value={a.id}>{a.plaka}</option>
                    ))}
                  </select>
                </div>
              )}
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>İptal</button>
              <button className="btn btn-primary" onClick={() => {
                setShowModal(false);
                setForm({ tankAdi: '', kapasite: '', tip: 'arac', aracId: '' });
              }}>
                Tank Ekle
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Tank İçeriği Modal */}
      {showIcerikModal && (
        <div className="modal-overlay" onClick={() => setShowIcerikModal(null)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: '600px' }}>
            <div className="modal-header">
              <h3>
                Tank İçeriği — {demoTanklar.find(t => t.id === showIcerikModal)?.tankAdi}
              </h3>
              <button className="modal-close" onClick={() => setShowIcerikModal(null)}><FiX /></button>
            </div>
            <div className="modal-body">
              <div style={{
                padding: '12px 16px', background: '#eff6ff', borderRadius: '10px',
                marginBottom: '16px', fontSize: '13px', color: '#1e40af'
              }}>
                Son 7 günde bu tanka giren süt kayıtları aşağıda listelenmiştir.
              </div>

              {(demoTankIcerigi[showIcerikModal] || []).length === 0 ? (
                <div className="empty-state">
                  <div className="empty-state-icon">🪣</div>
                  <h3>Kayıt Bulunamadı</h3>
                  <p>Bu tanka son 7 günde süt girişi yapılmamış.</p>
                </div>
              ) : (
                <table className="data-table">
                  <thead>
                    <tr>
                      <th>Kaynak</th>
                      <th>Miktar</th>
                      <th>Tarih</th>
                      <th>Saat</th>
                    </tr>
                  </thead>
                  <tbody>
                    {(demoTankIcerigi[showIcerikModal] || []).map((item, i) => (
                      <tr key={i}>
                        <td style={{ fontWeight: 500 }}>{item.uretici}</td>
                        <td><span style={{ fontWeight: 600, color: '#2563eb' }}>{item.miktar} LT</span></td>
                        <td style={{ fontSize: '13px' }}>{item.tarih}</td>
                        <td style={{ fontSize: '13px', color: '#64748b' }}>{item.saat}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowIcerikModal(null)}>Kapat</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
