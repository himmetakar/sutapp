import { FiDroplet, FiCalendar, FiTrendingUp } from 'react-icons/fi';
import {
  AreaChart, Area, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer
} from 'recharts';

const stats = {
  bugunSut: 45,
  buHaftaSut: 285,
  buAySut: 1240,
  toplamSut: 12500
};

const dailyHistory = [
  { gun: '19 May', miktar: 42 },
  { gun: '20 May', miktar: 45 },
  { gun: '21 May', miktar: 38 },
  { gun: '22 May', miktar: 50 },
  { gun: '23 May', miktar: 44 },
  { gun: '24 May', miktar: 48 },
  { gun: '25 May', miktar: 45 },
];

const gecmis = [
  { tarih: '25 Mayıs 2026', miktar: 45, saat: '07:15', surucu: 'Ahmet Kara', kamyon: '38 AB 123' },
  { tarih: '24 Mayıs 2026', miktar: 48, saat: '07:20', surucu: 'Ahmet Kara', kamyon: '38 AB 123' },
  { tarih: '23 Mayıs 2026', miktar: 44, saat: '07:10', surucu: 'Veli Yıldız', kamyon: '38 CD 456' },
  { tarih: '22 Mayıs 2026', miktar: 50, saat: '07:30', surucu: 'Ahmet Kara', kamyon: '38 AB 123' },
  { tarih: '21 Mayıs 2026', miktar: 38, saat: '07:25', surucu: 'Ahmet Kara', kamyon: '38 AB 123' },
  { tarih: '20 Mayıs 2026', miktar: 45, saat: '07:15', surucu: 'Veli Yıldız', kamyon: '38 CD 456' },
  { tarih: '19 Mayıs 2026', miktar: 42, saat: '07:20', surucu: 'Ahmet Kara', kamyon: '38 AB 123' },
];

export default function UreticiDashboard() {
  return (
    <div className="fade-in">
      {/* Stats */}
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon blue"><FiDroplet /></div>
          <div className="stat-info">
            <div className="stat-value">{stats.bugunSut}</div>
            <div className="stat-label">Bugün (Litre)</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon green"><FiCalendar /></div>
          <div className="stat-info">
            <div className="stat-value">{stats.buHaftaSut}</div>
            <div className="stat-label">Bu Hafta (Litre)</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon orange"><FiTrendingUp /></div>
          <div className="stat-info">
            <div className="stat-value">{stats.buAySut.toLocaleString('tr-TR')}</div>
            <div className="stat-label">Bu Ay (Litre)</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon blue"><FiDroplet /></div>
          <div className="stat-info">
            <div className="stat-value">{stats.toplamSut.toLocaleString('tr-TR')}</div>
            <div className="stat-label">Toplam (Litre)</div>
          </div>
        </div>
      </div>

      {/* Chart */}
      <div className="card" style={{ marginBottom: '20px' }}>
        <div className="card-header">
          <h3 className="card-title">Son 7 Gün Süt Teslimatım</h3>
        </div>
        <div className="chart-container">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={dailyHistory}>
              <defs>
                <linearGradient id="colorSut" x1="0" y1="0" x2="0" y2="1">
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
                formatter={(v) => [`${v} LT`, 'Miktar']}
              />
              <Area type="monotone" dataKey="miktar" stroke="#3b82f6" fillOpacity={1} fill="url(#colorSut)" strokeWidth={2} />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* History Table */}
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Teslim Geçmişi</h3>
        </div>
        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Tarih</th>
                <th>Miktar</th>
                <th>Saat</th>
                <th>Teslim Alan Sürücü</th>
                <th>Kamyon</th>
              </tr>
            </thead>
            <tbody>
              {gecmis.map((g, i) => (
                <tr key={i}>
                  <td style={{ fontWeight: 500 }}>{g.tarih}</td>
                  <td><span style={{ fontWeight: 600, color: '#2563eb' }}>{g.miktar} LT</span></td>
                  <td style={{ color: '#64748b', fontSize: '13px' }}>{g.saat}</td>
                  <td style={{ fontSize: '13px' }}>{g.surucu}</td>
                  <td style={{ fontSize: '13px' }}>{g.kamyon}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
