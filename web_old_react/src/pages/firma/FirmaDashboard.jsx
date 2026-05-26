import {
  FiDroplet, FiTruck, FiUsers, FiAlertTriangle,
  FiTrendingUp, FiCalendar
} from 'react-icons/fi';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, LineChart, Line, PieChart, Pie, Cell,
  AreaChart, Area
} from 'recharts';

const stats = {
  bugunSut: '2.450',
  buHaftaSut: '15.280',
  buAySut: '58.920',
  aktifKamyon: 5,
  toplamUretici: 42,
  fireFark: '1.2%'
};

const dailyData = [
  { gun: 'Pzt', miktar: 2100 },
  { gun: 'Sal', miktar: 2350 },
  { gun: 'Çar', miktar: 1980 },
  { gun: 'Per', miktar: 2450 },
  { gun: 'Cum', miktar: 2200 },
  { gun: 'Cmt', miktar: 1800 },
  { gun: 'Paz', miktar: 1650 },
];

const weeklyData = [
  { hafta: '1. Hafta', miktar: 14200 },
  { hafta: '2. Hafta', miktar: 15600 },
  { hafta: '3. Hafta', miktar: 14800 },
  { hafta: '4. Hafta', miktar: 15280 },
];

const grupData = [
  { name: 'Yeşilova Köyü', value: 12500 },
  { name: 'Kızıltepe Mah.', value: 9800 },
  { name: 'Dağyolu Çiftlikleri', value: 8200 },
  { name: 'Akarsu Bölgesi', value: 6400 },
  { name: 'Merkez', value: 4500 },
];

const COLORS = ['#3b82f6', '#2563eb', '#60a5fa', '#93c5fd', '#bfdbfe'];

const kamyonlar = [
  { plaka: '38 AB 123', surucu: 'Ahmet Kara', stok: 420, kapasite: 2000 },
  { plaka: '38 CD 456', surucu: 'Veli Yıldız', stok: 850, kapasite: 2000 },
  { plaka: '38 EF 789', surucu: 'Ali Demir', stok: 0, kapasite: 1500 },
  { plaka: '38 GH 012', surucu: 'Hasan Çelik', stok: 1200, kapasite: 2500 },
  { plaka: '38 IJ 345', surucu: 'Murat Aydın', stok: 310, kapasite: 1500 },
];

const sonToplamalar = [
  { uretici: 'Mehmet Yılmaz', miktar: 45, saat: '07:15', kamyon: '38 AB 123' },
  { uretici: 'Fatma Korkmaz', miktar: 32, saat: '07:32', kamyon: '38 AB 123' },
  { uretici: 'Ali Özdemir', miktar: 28, saat: '07:45', kamyon: '38 CD 456' },
  { uretici: 'Ayşe Şahin', miktar: 55, saat: '08:10', kamyon: '38 CD 456' },
  { uretici: 'Hüseyin Kaya', miktar: 40, saat: '08:25', kamyon: '38 GH 012' },
  { uretici: 'Zeynep Demir', miktar: 22, saat: '08:40', kamyon: '38 GH 012' },
  { uretici: 'İbrahim Arslan', miktar: 38, saat: '09:00', kamyon: '38 AB 123' },
  { uretici: 'Hatice Yıldız', miktar: 60, saat: '09:15', kamyon: '38 IJ 345' },
];

export default function FirmaDashboard() {
  return (
    <div className="fade-in">
      {/* Stat Cards */}
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon blue"><FiDroplet /></div>
          <div className="stat-info">
            <div className="stat-value">{stats.bugunSut}</div>
            <div className="stat-label">Bugün (Litre)</div>
            <div className="stat-change up">↑ %5.2 dünden</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon green"><FiCalendar /></div>
          <div className="stat-info">
            <div className="stat-value">{stats.buHaftaSut}</div>
            <div className="stat-label">Bu Hafta (Litre)</div>
            <div className="stat-change up">↑ %3.8 geçen haftadan</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon orange"><FiTrendingUp /></div>
          <div className="stat-info">
            <div className="stat-value">{stats.buAySut}</div>
            <div className="stat-label">Bu Ay (Litre)</div>
            <div className="stat-change up">↑ %8.1 geçen aydan</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon red"><FiAlertTriangle /></div>
          <div className="stat-info">
            <div className="stat-value">{stats.fireFark}</div>
            <div className="stat-label">Fire Oranı</div>
            <div className="stat-change down">↓ Kontrol altında</div>
          </div>
        </div>
      </div>

      {/* Charts Row */}
      <div className="grid-2" style={{ marginBottom: '20px' }}>
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Günlük Süt Miktarı</h3>
          </div>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <AreaChart data={dailyData}>
                <defs>
                  <linearGradient id="colorMiktar" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#3b82f6" stopOpacity={0.15} />
                    <stop offset="95%" stopColor="#3b82f6" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="gun" stroke="#94a3b8" fontSize={12} />
                <YAxis stroke="#94a3b8" fontSize={12} />
                <Tooltip
                  contentStyle={{
                    background: '#fff',
                    border: '1px solid #e2e8f0',
                    borderRadius: '8px',
                    fontSize: '13px'
                  }}
                  formatter={(v) => [`${v.toLocaleString('tr-TR')} LT`, 'Miktar']}
                />
                <Area type="monotone" dataKey="miktar" stroke="#3b82f6" fillOpacity={1} fill="url(#colorMiktar)" strokeWidth={2} />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Bölge Bazlı Dağılım</h3>
          </div>
          <div className="chart-container" style={{ display: 'flex', alignItems: 'center' }}>
            <ResponsiveContainer width="55%" height="100%">
              <PieChart>
                <Pie
                  data={grupData}
                  cx="50%"
                  cy="50%"
                  innerRadius={55}
                  outerRadius={90}
                  dataKey="value"
                  stroke="none"
                >
                  {grupData.map((entry, index) => (
                    <Cell key={`cell-${index}`} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip
                  contentStyle={{
                    background: '#fff',
                    border: '1px solid #e2e8f0',
                    borderRadius: '8px',
                    fontSize: '13px'
                  }}
                  formatter={(v) => [`${v.toLocaleString('tr-TR')} LT`]}
                />
              </PieChart>
            </ResponsiveContainer>
            <div style={{ flex: 1, fontSize: '13px' }}>
              {grupData.map((item, i) => (
                <div key={i} style={{ display: 'flex', alignItems: 'center', gap: '8px', marginBottom: '10px' }}>
                  <div style={{ width: '10px', height: '10px', borderRadius: '3px', background: COLORS[i], flexShrink: 0 }} />
                  <span style={{ color: '#475569' }}>{item.name}</span>
                  <span style={{ marginLeft: 'auto', fontWeight: 600, color: '#1e293b' }}>{item.value.toLocaleString('tr-TR')}</span>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      {/* Kamyon Stokları + Son Toplamalar */}
      <div className="grid-2">
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Kamyon Anlık Stokları</h3>
            <span className="badge badge-info">{kamyonlar.length} araç</span>
          </div>
          {kamyonlar.map((k, i) => (
            <div key={i} style={{
              display: 'flex',
              alignItems: 'center',
              gap: '14px',
              padding: '12px 0',
              borderBottom: i < kamyonlar.length - 1 ? '1px solid #f1f5f9' : 'none'
            }}>
              <div style={{
                width: '40px',
                height: '40px',
                borderRadius: '10px',
                background: k.stok === 0 ? '#f1f5f9' : '#dbeafe',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '16px'
              }}>
                <FiTruck color={k.stok === 0 ? '#94a3b8' : '#2563eb'} />
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: '14px', fontWeight: 500, color: '#1e293b' }}>{k.plaka}</div>
                <div style={{ fontSize: '12px', color: '#64748b' }}>{k.surucu}</div>
              </div>
              <div style={{ textAlign: 'right' }}>
                <div style={{ fontSize: '15px', fontWeight: 600, color: k.stok === 0 ? '#94a3b8' : '#1e293b' }}>
                  {k.stok.toLocaleString('tr-TR')} LT
                </div>
                <div style={{
                  width: '80px',
                  height: '4px',
                  background: '#f1f5f9',
                  borderRadius: '99px',
                  marginTop: '4px'
                }}>
                  <div style={{
                    width: `${(k.stok / k.kapasite) * 100}%`,
                    height: '100%',
                    background: k.stok / k.kapasite > 0.8 ? '#f59e0b' : '#3b82f6',
                    borderRadius: '99px',
                    transition: 'width 0.5s ease'
                  }} />
                </div>
              </div>
            </div>
          ))}
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Son Süt Toplamalar</h3>
            <span className="badge badge-active">Canlı</span>
          </div>
          <div className="table-container">
            <table className="data-table">
              <thead>
                <tr>
                  <th>Üretici</th>
                  <th>Miktar</th>
                  <th>Saat</th>
                  <th>Kamyon</th>
                </tr>
              </thead>
              <tbody>
                {sonToplamalar.map((t, i) => (
                  <tr key={i}>
                    <td style={{ fontWeight: 500 }}>{t.uretici}</td>
                    <td>
                      <span style={{
                        fontWeight: 600,
                        color: '#2563eb'
                      }}>{t.miktar} LT</span>
                    </td>
                    <td style={{ color: '#64748b', fontSize: '13px' }}>{t.saat}</td>
                    <td style={{ fontSize: '13px' }}>{t.kamyon}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </div>
  );
}
