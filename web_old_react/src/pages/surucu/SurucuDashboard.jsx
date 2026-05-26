import { FiDroplet, FiTruck, FiClock, FiCheckCircle } from 'react-icons/fi';

const stats = {
  bugunToplam: 320,
  toplamUretici: 8,
  tankerStok: 420,
  tankerKapasite: 2000
};

const bugunToplamalar = [
  { uretici: 'Mehmet Yılmaz', miktar: 45, saat: '07:15', konum: 'Yeşilova Köyü' },
  { uretici: 'Fatma Korkmaz', miktar: 32, saat: '07:32', konum: 'Yeşilova Köyü' },
  { uretici: 'Ali Özdemir', miktar: 28, saat: '07:45', konum: 'Kızıltepe Mah.' },
  { uretici: 'Ayşe Şahin', miktar: 55, saat: '08:10', konum: 'Dağyolu Çiftlikleri' },
  { uretici: 'Hüseyin Kaya', miktar: 40, saat: '08:25', konum: 'Akarsu Bölgesi' },
  { uretici: 'Zeynep Demir', miktar: 22, saat: '08:40', konum: 'Yeşilova Köyü' },
  { uretici: 'İbrahim Arslan', miktar: 38, saat: '09:00', konum: 'Kızıltepe Mah.' },
  { uretici: 'Hatice Yıldız', miktar: 60, saat: '09:15', konum: 'Dağyolu Çiftlikleri' },
];

export default function SurucuDashboard() {
  const stockPercent = (stats.tankerStok / stats.tankerKapasite) * 100;

  return (
    <div className="fade-in">
      {/* Tanker Gauge */}
      <div className="card" style={{ marginBottom: '20px', padding: '28px' }}>
        <div style={{ textAlign: 'center', marginBottom: '20px' }}>
          <div style={{ fontSize: '14px', color: '#64748b', marginBottom: '4px' }}>Tanker Doluluk Durumu</div>
          <div style={{
            fontSize: '42px',
            fontWeight: 700,
            color: stockPercent > 80 ? '#f59e0b' : '#2563eb'
          }}>
            {stats.tankerStok.toLocaleString('tr-TR')}
            <span style={{ fontSize: '18px', fontWeight: 400, color: '#94a3b8' }}> / {stats.tankerKapasite.toLocaleString('tr-TR')} LT</span>
          </div>
        </div>
        <div style={{
          width: '100%',
          height: '16px',
          background: '#f1f5f9',
          borderRadius: '99px',
          overflow: 'hidden'
        }}>
          <div style={{
            width: `${stockPercent}%`,
            height: '100%',
            background: stockPercent > 80
              ? 'linear-gradient(90deg, #f59e0b, #ef4444)'
              : 'linear-gradient(90deg, #93c5fd, #3b82f6)',
            borderRadius: '99px',
            transition: 'width 0.8s ease'
          }} />
        </div>
        <div style={{
          display: 'flex',
          justifyContent: 'space-between',
          marginTop: '8px',
          fontSize: '12px',
          color: '#94a3b8'
        }}>
          <span>Boş</span>
          <span>%{stockPercent.toFixed(0)}</span>
          <span>Dolu</span>
        </div>
      </div>

      {/* Quick Stats */}
      <div className="stats-grid" style={{ marginBottom: '20px' }}>
        <div className="stat-card">
          <div className="stat-icon blue"><FiDroplet /></div>
          <div className="stat-info">
            <div className="stat-value">{stats.bugunToplam}</div>
            <div className="stat-label">Bugün Toplanan (LT)</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon green"><FiCheckCircle /></div>
          <div className="stat-info">
            <div className="stat-value">{stats.toplamUretici}</div>
            <div className="stat-label">Ziyaret Edilen Üretici</div>
          </div>
        </div>
      </div>

      {/* Today's Collections */}
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Bugünkü Toplamalar</h3>
          <span className="badge badge-info">{bugunToplamalar.length} kayıt</span>
        </div>
        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Üretici</th>
                <th>Miktar</th>
                <th>Saat</th>
                <th>Konum</th>
                <th>Durum</th>
              </tr>
            </thead>
            <tbody>
              {bugunToplamalar.map((t, i) => (
                <tr key={i}>
                  <td style={{ fontWeight: 500 }}>{t.uretici}</td>
                  <td><span style={{ fontWeight: 600, color: '#2563eb' }}>{t.miktar} LT</span></td>
                  <td style={{ color: '#64748b', fontSize: '13px' }}>{t.saat}</td>
                  <td style={{ fontSize: '13px' }}>{t.konum}</td>
                  <td><span className="badge badge-active">✓ Senkronize</span></td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
