import { useState } from 'react';
import { FiPlus, FiSearch, FiEdit2, FiTrash2, FiX, FiFilter } from 'react-icons/fi';

const gruplar = ['Tümü', 'Yeşilova Köyü', 'Kızıltepe Mah.', 'Dağyolu Çiftlikleri', 'Akarsu Bölgesi', 'Merkez'];

const demoUreticiler = [
  { id: '1', name: 'Mehmet Yılmaz', phone: '0532 111 2233', group: 'Yeşilova Köyü', groupType: 'köy', totalDelivered: 12500, avgDaily: 42 },
  { id: '2', name: 'Fatma Korkmaz', phone: '0533 222 3344', group: 'Yeşilova Köyü', groupType: 'köy', totalDelivered: 9800, avgDaily: 32 },
  { id: '3', name: 'Ali Özdemir', phone: '0534 333 4455', group: 'Kızıltepe Mah.', groupType: 'mahalle', totalDelivered: 8200, avgDaily: 28 },
  { id: '4', name: 'Ayşe Şahin', phone: '0535 444 5566', group: 'Dağyolu Çiftlikleri', groupType: 'çiftlik', totalDelivered: 15600, avgDaily: 55 },
  { id: '5', name: 'Hüseyin Kaya', phone: '0536 555 6677', group: 'Akarsu Bölgesi', groupType: 'bölge', totalDelivered: 11200, avgDaily: 40 },
  { id: '6', name: 'Zeynep Demir', phone: '0537 666 7788', group: 'Yeşilova Köyü', groupType: 'köy', totalDelivered: 6800, avgDaily: 22 },
  { id: '7', name: 'İbrahim Arslan', phone: '0538 777 8899', group: 'Kızıltepe Mah.', groupType: 'mahalle', totalDelivered: 10500, avgDaily: 38 },
  { id: '8', name: 'Hatice Yıldız', phone: '0539 888 9900', group: 'Dağyolu Çiftlikleri', groupType: 'çiftlik', totalDelivered: 18200, avgDaily: 60 },
  { id: '9', name: 'Mustafa Çelik', phone: '0540 999 0011', group: 'Merkez', groupType: 'bölge', totalDelivered: 7500, avgDaily: 25 },
  { id: '10', name: 'Emine Aydın', phone: '0541 000 1122', group: 'Akarsu Bölgesi', groupType: 'bölge', totalDelivered: 9200, avgDaily: 33 },
];

export default function FirmaUreticiler() {
  const [search, setSearch] = useState('');
  const [selectedGrup, setSelectedGrup] = useState('Tümü');
  const [showModal, setShowModal] = useState(false);

  const filtered = demoUreticiler.filter(u => {
    const matchSearch = u.name.toLowerCase().includes(search.toLowerCase()) ||
      u.phone.includes(search);
    const matchGrup = selectedGrup === 'Tümü' || u.group === selectedGrup;
    return matchSearch && matchGrup;
  });

  return (
    <div className="fade-in">
      <div className="card">
        <div className="card-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <h3 className="card-title">Üretici Listesi</h3>
            <span className="badge badge-info">{filtered.length} üretici</span>
          </div>
          <div style={{ display: 'flex', gap: '10px', alignItems: 'center' }}>
            <div style={{ position: 'relative' }}>
              <FiSearch style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
              <input
                type="text"
                placeholder="İsim veya telefon ara..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                style={{
                  padding: '8px 12px 8px 36px',
                  border: '1.5px solid #e2e8f0',
                  borderRadius: '8px',
                  fontSize: '13px',
                  outline: 'none',
                  width: '200px',
                  fontFamily: 'inherit'
                }}
              />
            </div>

            <select
              value={selectedGrup}
              onChange={(e) => setSelectedGrup(e.target.value)}
              style={{
                padding: '8px 12px',
                border: '1.5px solid #e2e8f0',
                borderRadius: '8px',
                fontSize: '13px',
                outline: 'none',
                fontFamily: 'inherit',
                color: '#334155',
                background: '#fff',
                cursor: 'pointer'
              }}
            >
              {gruplar.map(g => (
                <option key={g} value={g}>{g}</option>
              ))}
            </select>

            <button className="btn btn-primary btn-sm" onClick={() => setShowModal(true)}>
              <FiPlus /> Yeni Üretici
            </button>
          </div>
        </div>

        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Üretici Adı</th>
                <th>Telefon</th>
                <th>Grup / Bölge</th>
                <th>Grup Tipi</th>
                <th>Toplam Teslim (LT)</th>
                <th>Ort. Günlük (LT)</th>
                <th>İşlem</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(u => (
                <tr key={u.id}>
                  <td style={{ fontWeight: 500 }}>{u.name}</td>
                  <td style={{ fontSize: '13px' }}>{u.phone}</td>
                  <td><span className="badge badge-info">{u.group}</span></td>
                  <td style={{ fontSize: '13px', color: '#64748b', textTransform: 'capitalize' }}>{u.groupType}</td>
                  <td style={{ fontWeight: 600, color: '#2563eb' }}>{u.totalDelivered.toLocaleString('tr-TR')}</td>
                  <td>{u.avgDaily}</td>
                  <td>
                    <div style={{ display: 'flex', gap: '4px' }}>
                      <button className="btn btn-ghost btn-sm"><FiEdit2 /></button>
                      <button className="btn btn-ghost btn-sm" style={{ color: '#ef4444' }}><FiTrash2 /></button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Add Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Yeni Üretici Ekle</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}><FiX /></button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label>Ad Soyad</label>
                <input type="text" placeholder="Üretici adı" />
              </div>
              <div className="form-group">
                <label>Telefon</label>
                <input type="text" placeholder="0XXX XXX XXXX" />
              </div>
              <div className="form-group">
                <label>Grup Tipi</label>
                <select>
                  <option value="koy">Köy</option>
                  <option value="mahalle">Mahalle</option>
                  <option value="bolge">Bölge</option>
                  <option value="ciftlik">Çiftlik</option>
                </select>
              </div>
              <div className="form-group">
                <label>Grup Adı</label>
                <input type="text" placeholder="Köy / Mahalle / Bölge adı" />
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>İptal</button>
              <button className="btn btn-primary" onClick={() => setShowModal(false)}>Üretici Ekle</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
