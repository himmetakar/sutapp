import { useState } from 'react';
import { FiPlus, FiSearch, FiEdit2, FiTrash2, FiX } from 'react-icons/fi';

const demoFirmalar = [
  { id: '1', name: 'Anadolu Süt A.Ş.', owner: 'Ahmet Yılmaz', address: 'Ankara, Çankaya', phone: '0312 555 0001', surucu: 12, uretici: 89, plan: 'Endüstriyel', status: 'active', subscription: { endDate: '2026-07-15' } },
  { id: '2', name: 'Kayseri Çiftlik', owner: 'Fatma Demir', address: 'Kayseri, Merkez', phone: '0352 555 0002', surucu: 5, uretici: 42, plan: 'Orta', status: 'active', subscription: { endDate: '2026-06-20' } },
  { id: '3', name: 'Güneydoğu Süt', owner: 'Murat Kaya', address: 'Gaziantep, Şehitkamil', phone: '0342 555 0003', surucu: 8, uretici: 67, plan: 'Orta', status: 'active', subscription: { endDate: '2026-08-01' } },
  { id: '4', name: 'Trakya Mandıra', owner: 'Elif Şahin', address: 'Edirne, Merkez', phone: '0284 555 0004', surucu: 3, uretici: 28, plan: 'Küçük', status: 'warning', subscription: { endDate: '2026-05-28' } },
  { id: '5', name: 'Ege Süt Birliği', owner: 'Hasan Öz', address: 'İzmir, Bornova', phone: '0232 555 0005', surucu: 15, uretici: 112, plan: 'Endüstriyel', status: 'active', subscription: { endDate: '2026-09-10' } },
  { id: '6', name: 'Karadeniz Yaylası', owner: 'Ayşe Korkmaz', address: 'Trabzon, Ortahisar', phone: '0462 555 0006', surucu: 6, uretici: 55, plan: 'Orta', status: 'active', subscription: { endDate: '2026-07-30' } },
];

export default function AdminFirmalar() {
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);

  const filtered = demoFirmalar.filter(f =>
    f.name.toLowerCase().includes(search.toLowerCase()) ||
    f.owner.toLowerCase().includes(search.toLowerCase())
  );

  return (
    <div className="fade-in">
      <div className="card">
        <div className="card-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <h3 className="card-title">Tüm Firmalar</h3>
            <span className="badge badge-info">{demoFirmalar.length} firma</span>
          </div>
          <div style={{ display: 'flex', gap: '10px' }}>
            <div style={{ position: 'relative' }}>
              <FiSearch style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
              <input
                type="text"
                placeholder="Firma ara..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                style={{
                  padding: '8px 12px 8px 36px',
                  border: '1.5px solid #e2e8f0',
                  borderRadius: '8px',
                  fontSize: '13px',
                  outline: 'none',
                  width: '220px',
                  fontFamily: 'inherit'
                }}
              />
            </div>
            <button className="btn btn-primary btn-sm" onClick={() => setShowModal(true)}>
              <FiPlus /> Yeni Firma
            </button>
          </div>
        </div>

        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Firma Adı</th>
                <th>Sahibi</th>
                <th>Adres</th>
                <th>Telefon</th>
                <th>Sürücü</th>
                <th>Üretici</th>
                <th>Paket</th>
                <th>Abonelik Bitiş</th>
                <th>Durum</th>
                <th>İşlem</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(firma => (
                <tr key={firma.id}>
                  <td style={{ fontWeight: 500 }}>{firma.name}</td>
                  <td>{firma.owner}</td>
                  <td style={{ fontSize: '13px', color: '#64748b' }}>{firma.address}</td>
                  <td style={{ fontSize: '13px' }}>{firma.phone}</td>
                  <td>{firma.surucu}</td>
                  <td>{firma.uretici}</td>
                  <td><span className="badge badge-info">{firma.plan}</span></td>
                  <td style={{ fontSize: '13px' }}>{firma.subscription.endDate}</td>
                  <td>
                    <span className={`badge ${firma.status === 'active' ? 'badge-active' : 'badge-warning'}`}>
                      {firma.status === 'active' ? 'Aktif' : 'Yakında Bitiyor'}
                    </span>
                  </td>
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

      {/* Add Firma Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()}>
            <div className="modal-header">
              <h3>Yeni Firma Ekle</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}><FiX /></button>
            </div>
            <div className="modal-body">
              <div className="form-group">
                <label>Firma Adı</label>
                <input type="text" placeholder="Firma adını girin" />
              </div>
              <div className="form-group">
                <label>Firma Sahibi</label>
                <input type="text" placeholder="Yetkili kişi adı" />
              </div>
              <div className="form-group">
                <label>Adres</label>
                <input type="text" placeholder="Firma adresi" />
              </div>
              <div className="form-group">
                <label>Telefon</label>
                <input type="text" placeholder="0XXX XXX XXXX" />
              </div>
              <div className="form-group">
                <label>Abonelik Paketi</label>
                <select>
                  <option value="kucuk">Küçük Ölçekli</option>
                  <option value="orta">Orta Ölçekli</option>
                  <option value="endustriyel">Endüstriyel</option>
                </select>
              </div>
            </div>
            <div className="modal-footer">
              <button className="btn btn-secondary" onClick={() => setShowModal(false)}>İptal</button>
              <button className="btn btn-primary" onClick={() => setShowModal(false)}>Firma Ekle</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
