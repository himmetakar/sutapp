import { FiSearch } from 'react-icons/fi';
import { useState } from 'react';

const demoToplamalar = [
  { id: 1, uretici: 'Mehmet Yılmaz', surucu: 'Ahmet Kara', kamyon: '38 AB 123', miktar: 45, tarih: '25.05.2026', saat: '07:15', bolge: 'Yeşilova Köyü', synced: true },
  { id: 2, uretici: 'Fatma Korkmaz', surucu: 'Ahmet Kara', kamyon: '38 AB 123', miktar: 32, tarih: '25.05.2026', saat: '07:32', bolge: 'Yeşilova Köyü', synced: true },
  { id: 3, uretici: 'Ali Özdemir', surucu: 'Veli Yıldız', kamyon: '38 CD 456', miktar: 28, tarih: '25.05.2026', saat: '07:45', bolge: 'Kızıltepe Mah.', synced: true },
  { id: 4, uretici: 'Ayşe Şahin', surucu: 'Veli Yıldız', kamyon: '38 CD 456', miktar: 55, tarih: '25.05.2026', saat: '08:10', bolge: 'Dağyolu', synced: true },
  { id: 5, uretici: 'Hüseyin Kaya', surucu: 'Hasan Çelik', kamyon: '38 GH 012', miktar: 40, tarih: '25.05.2026', saat: '08:25', bolge: 'Akarsu', synced: true },
  { id: 6, uretici: 'Zeynep Demir', surucu: 'Hasan Çelik', kamyon: '38 GH 012', miktar: 22, tarih: '25.05.2026', saat: '08:40', bolge: 'Yeşilova Köyü', synced: false },
  { id: 7, uretici: 'İbrahim Arslan', surucu: 'Ahmet Kara', kamyon: '38 AB 123', miktar: 38, tarih: '24.05.2026', saat: '09:00', bolge: 'Kızıltepe Mah.', synced: true },
  { id: 8, uretici: 'Hatice Yıldız', surucu: 'Murat Aydın', kamyon: '38 IJ 345', miktar: 60, tarih: '24.05.2026', saat: '09:15', bolge: 'Dağyolu', synced: true },
];

export default function FirmaToplamalar() {
  const [search, setSearch] = useState('');

  const filtered = demoToplamalar.filter(t =>
    t.uretici.toLowerCase().includes(search.toLowerCase()) ||
    t.surucu.toLowerCase().includes(search.toLowerCase()) ||
    t.kamyon.includes(search)
  );

  const toplamMiktar = filtered.reduce((sum, t) => sum + t.miktar, 0);

  return (
    <div className="fade-in">
      <div className="card">
        <div className="card-header">
          <div style={{ display: 'flex', alignItems: 'center', gap: '12px' }}>
            <h3 className="card-title">Süt Toplama Kayıtları</h3>
            <span className="badge badge-info">{filtered.length} kayıt</span>
            <span className="badge badge-active">{toplamMiktar} LT toplam</span>
          </div>
          <div style={{ position: 'relative' }}>
            <FiSearch style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
            <input
              type="text"
              placeholder="Üretici, sürücü veya plaka ara..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              style={{
                padding: '8px 12px 8px 36px',
                border: '1.5px solid #e2e8f0',
                borderRadius: '8px',
                fontSize: '13px',
                outline: 'none',
                width: '260px',
                fontFamily: 'inherit'
              }}
            />
          </div>
        </div>
        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>#</th>
                <th>Üretici</th>
                <th>Sürücü</th>
                <th>Kamyon</th>
                <th>Miktar</th>
                <th>Tarih</th>
                <th>Saat</th>
                <th>Bölge</th>
                <th>Durum</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map(t => (
                <tr key={t.id}>
                  <td style={{ color: '#94a3b8' }}>{t.id}</td>
                  <td style={{ fontWeight: 500 }}>{t.uretici}</td>
                  <td>{t.surucu}</td>
                  <td style={{ fontSize: '13px' }}>{t.kamyon}</td>
                  <td><span style={{ fontWeight: 600, color: '#2563eb' }}>{t.miktar} LT</span></td>
                  <td style={{ fontSize: '13px' }}>{t.tarih}</td>
                  <td style={{ fontSize: '13px', color: '#64748b' }}>{t.saat}</td>
                  <td><span className="badge badge-info">{t.bolge}</span></td>
                  <td>
                    <span className={`badge ${t.synced ? 'badge-active' : 'badge-warning'}`}>
                      {t.synced ? '✓ Senkronize' : '⏳ Bekliyor'}
                    </span>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
