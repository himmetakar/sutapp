import { useState } from 'react';
import { FiPlus, FiX, FiEdit2, FiTrash2, FiSearch, FiUsers } from 'react-icons/fi';

const demoUreticiler = [
  { id: 'u1', name: 'Mehmet Yılmaz', group: 'Yeşilova Köyü' },
  { id: 'u2', name: 'Fatma Korkmaz', group: 'Yeşilova Köyü' },
  { id: 'u3', name: 'Ali Özdemir', group: 'Kızıltepe Mah.' },
  { id: 'u4', name: 'Ayşe Şahin', group: 'Dağyolu Çiftlikleri' },
  { id: 'u5', name: 'Hüseyin Kaya', group: 'Akarsu Bölgesi' },
  { id: 'u6', name: 'Zeynep Demir', group: 'Yeşilova Köyü' },
  { id: 'u7', name: 'İbrahim Arslan', group: 'Kızıltepe Mah.' },
  { id: 'u8', name: 'Hatice Yıldız', group: 'Dağyolu Çiftlikleri' },
];

const demoSuruculer = [
  { id: 's1', ad: 'Ahmet', soyad: 'Kara', telefon: '0532 100 0001', email: 'ahmet@firma.com', tcKimlik: '12345678901', ureticiIds: ['u1', 'u2', 'u6'], status: 'active' },
  { id: 's2', ad: 'Veli', soyad: 'Yıldız', telefon: '0532 100 0002', email: '', tcKimlik: '23456789012', ureticiIds: ['u3', 'u7'], status: 'active' },
  { id: 's3', ad: 'Ali', soyad: 'Demir', telefon: '0532 100 0003', email: 'ali@firma.com', tcKimlik: '34567890123', ureticiIds: ['u4', 'u8'], status: 'active' },
  { id: 's4', ad: 'Hasan', soyad: 'Çelik', telefon: '0532 100 0004', email: '', tcKimlik: '45678901234', ureticiIds: ['u5'], status: 'active' },
  { id: 's5', ad: 'Murat', soyad: 'Aydın', telefon: '0532 100 0005', email: 'murat@firma.com', tcKimlik: '56789012345', ureticiIds: ['u1', 'u5', 'u8'], status: 'inactive' },
];

export default function FirmaSuruculer() {
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [expandedId, setExpandedId] = useState(null);
  const [form, setForm] = useState({ ad: '', soyad: '', telefon: '', email: '', tcKimlik: '', ureticiIds: [] });

  const filtered = demoSuruculer.filter(s =>
    `${s.ad} ${s.soyad}`.toLowerCase().includes(search.toLowerCase()) ||
    s.telefon.includes(search) ||
    s.tcKimlik.includes(search)
  );

  const getUreticiNames = (ids) => {
    return ids.map(id => {
      const u = demoUreticiler.find(d => d.id === id);
      return u ? u.name : id;
    });
  };

  const toggleUretici = (id) => {
    setForm(prev => ({
      ...prev,
      ureticiIds: prev.ureticiIds.includes(id)
        ? prev.ureticiIds.filter(u => u !== id)
        : [...prev.ureticiIds, id]
    }));
  };

  const resetForm = () => setForm({ ad: '', soyad: '', telefon: '', email: '', tcKimlik: '', ureticiIds: [] });

  return (
    <div className="fade-in">
      <div className="card">
        <div className="card-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <h3 className="card-title">Sürücüler</h3>
            <span className="badge badge-info">{filtered.length} kişi</span>
          </div>
          <div style={{ display: 'flex', gap: '10px' }}>
            <div style={{ position: 'relative' }}>
              <FiSearch style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
              <input
                type="text" placeholder="Ad, telefon veya TC ara..."
                value={search} onChange={e => setSearch(e.target.value)}
                style={{
                  padding: '8px 12px 8px 36px', border: '1.5px solid #e2e8f0',
                  borderRadius: '8px', fontSize: '13px', outline: 'none', width: '220px', fontFamily: 'inherit'
                }}
              />
            </div>
            <button className="btn btn-primary btn-sm" onClick={() => { resetForm(); setShowModal(true); }}>
              <FiPlus /> Sürücü Ekle
            </button>
          </div>
        </div>

        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Ad Soyad</th>
                <th>Telefon</th>
                <th>E-posta</th>
                <th>TC Kimlik</th>
                <th>Atanmış Üretici</th>
                <th>Durum</th>
                <th>İşlem</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(s => {
                const isExpanded = expandedId === s.id;
                const ureticiler = getUreticiNames(s.ureticiIds);
                return (
                  <tr key={s.id}>
                    <td style={{ fontWeight: 500 }}>{s.ad} {s.soyad}</td>
                    <td style={{ fontSize: '13px' }}>{s.telefon}</td>
                    <td style={{ fontSize: '13px', color: s.email ? '#334155' : '#94a3b8' }}>
                      {s.email || '—'}
                    </td>
                    <td style={{ fontSize: '13px', fontFamily: 'monospace', color: '#64748b' }}>
                      {s.tcKimlik}
                    </td>
                    <td>
                      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '4px', alignItems: 'center' }}>
                        {ureticiler.slice(0, isExpanded ? ureticiler.length : 2).map((name, i) => (
                          <span key={i} className="badge badge-info" style={{ fontSize: '11px' }}>{name}</span>
                        ))}
                        {!isExpanded && ureticiler.length > 2 && (
                          <button
                            className="btn btn-ghost btn-sm"
                            style={{ fontSize: '11px', padding: '2px 6px' }}
                            onClick={() => setExpandedId(s.id)}
                          >
                            +{ureticiler.length - 2} daha
                          </button>
                        )}
                        {isExpanded && ureticiler.length > 2 && (
                          <button
                            className="btn btn-ghost btn-sm"
                            style={{ fontSize: '11px', padding: '2px 6px' }}
                            onClick={() => setExpandedId(null)}
                          >
                            daralt
                          </button>
                        )}
                      </div>
                    </td>
                    <td>
                      <span className={`badge ${s.status === 'active' ? 'badge-active' : 'badge-inactive'}`}>
                        {s.status === 'active' ? 'Aktif' : 'Pasif'}
                      </span>
                    </td>
                    <td>
                      <div style={{ display: 'flex', gap: '4px' }}>
                        <button className="btn btn-ghost btn-sm"><FiEdit2 /></button>
                        <button className="btn btn-ghost btn-sm" style={{ color: '#ef4444' }}><FiTrash2 /></button>
                      </div>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      </div>

      {/* Sürücü Ekle Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: '560px' }}>
            <div className="modal-header">
              <h3>Yeni Sürücü Ekle</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}><FiX /></button>
            </div>
            <div className="modal-body">
              <div className="grid-2">
                <div className="form-group">
                  <label>Ad *</label>
                  <input type="text" placeholder="Sürücü adı"
                    value={form.ad} onChange={e => setForm({ ...form, ad: e.target.value })} />
                </div>
                <div className="form-group">
                  <label>Soyad *</label>
                  <input type="text" placeholder="Sürücü soyadı"
                    value={form.soyad} onChange={e => setForm({ ...form, soyad: e.target.value })} />
                </div>
              </div>

              <div className="form-group">
                <label>Telefon *</label>
                <input type="text" placeholder="05XX XXX XXXX"
                  value={form.telefon} onChange={e => setForm({ ...form, telefon: e.target.value })} />
              </div>

              <div className="form-group">
                <label>E-posta <span style={{ color: '#94a3b8', fontWeight: 400 }}>(opsiyonel)</span></label>
                <input type="email" placeholder="ornek@mail.com"
                  value={form.email} onChange={e => setForm({ ...form, email: e.target.value })} />
              </div>

              <div className="form-group">
                <label>TC Kimlik No *</label>
                <input type="text" placeholder="XXXXXXXXXXX" maxLength={11}
                  value={form.tcKimlik} onChange={e => setForm({ ...form, tcKimlik: e.target.value })} />
              </div>

              <div className="form-group">
                <label>
                  <FiUsers size={13} style={{ marginRight: '4px', verticalAlign: '-2px' }} />
                  Üretici Ata (Birden fazla seçilebilir)
                </label>
                <div style={{
                  border: '1.5px solid #e2e8f0', borderRadius: '8px',
                  padding: '8px', maxHeight: '200px', overflowY: 'auto',
                  background: '#f8fafc'
                }}>
                  {demoUreticiler.map(u => (
                    <label key={u.id} style={{
                      display: 'flex', alignItems: 'center', gap: '10px',
                      padding: '8px 10px', borderRadius: '6px', cursor: 'pointer',
                      marginBottom: '2px',
                      background: form.ureticiIds.includes(u.id) ? '#dbeafe' : 'transparent',
                      transition: 'background 0.15s'
                    }}>
                      <input
                        type="checkbox"
                        checked={form.ureticiIds.includes(u.id)}
                        onChange={() => toggleUretici(u.id)}
                        style={{ accentColor: '#2563eb' }}
                      />
                      <div>
                        <div style={{ fontSize: '13px', fontWeight: 500, color: '#1e293b' }}>{u.name}</div>
                        <div style={{ fontSize: '11px', color: '#64748b' }}>{u.group}</div>
                      </div>
                    </label>
                  ))}
                </div>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>İptal</button>
              <button className="btn btn-primary" onClick={() => { setShowModal(false); resetForm(); }}>
                Sürücü Ekle
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
