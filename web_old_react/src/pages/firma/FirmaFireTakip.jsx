import { FiAlertTriangle } from 'react-icons/fi';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, Cell
} from 'recharts';

const fireData = [
  { kamyon: '38 AB 123', surucu: 'Ahmet Kara', toppinan: 12500, teslim: 12380, fark: 120, oran: 0.96 },
  { kamyon: '38 CD 456', surucu: 'Veli Yıldız', toppinan: 9800, teslim: 9650, fark: 150, oran: 1.53 },
  { kamyon: '38 EF 789', surucu: 'Ali Demir', toppinan: 8200, teslim: 8150, fark: 50, oran: 0.61 },
  { kamyon: '38 GH 012', surucu: 'Hasan Çelik', toppinan: 15600, teslim: 15350, fark: 250, oran: 1.60 },
  { kamyon: '38 IJ 345', surucu: 'Murat Aydın', toppinan: 6400, teslim: 6370, fark: 30, oran: 0.47 },
];

const chartData = fireData.map(f => ({
  name: f.kamyon,
  oran: f.oran
}));

const getBarColor = (oran) => {
  if (oran > 1.5) return '#ef4444';
  if (oran > 1.0) return '#f59e0b';
  return '#10b981';
};

export default function FirmaFireTakip() {
  const toplamFire = fireData.reduce((sum, f) => sum + f.fark, 0);
  const toplamToplanan = fireData.reduce((sum, f) => sum + f.toppinan, 0);
  const avgOran = ((toplamFire / toplamToplanan) * 100).toFixed(2);

  return (
    <div className="fade-in">
      {/* Summary Cards */}
      <div className="stats-grid" style={{ marginBottom: '20px' }}>
        <div className="stat-card">
          <div className="stat-icon red"><FiAlertTriangle /></div>
          <div className="stat-info">
            <div className="stat-value">{toplamFire.toLocaleString('tr-TR')}</div>
            <div className="stat-label">Toplam Fire (LT)</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon orange"><FiAlertTriangle /></div>
          <div className="stat-info">
            <div className="stat-value">%{avgOran}</div>
            <div className="stat-label">Ortalama Fire Oranı</div>
          </div>
        </div>
      </div>

      {/* Chart */}
      <div className="card" style={{ marginBottom: '20px' }}>
        <div className="card-header">
          <h3 className="card-title">Kamyon Bazlı Fire Oranları (%)</h3>
        </div>
        <div className="chart-container">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={chartData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
              <XAxis dataKey="name" stroke="#94a3b8" fontSize={12} />
              <YAxis stroke="#94a3b8" fontSize={12} />
              <Tooltip
                contentStyle={{
                  background: '#fff',
                  border: '1px solid #e2e8f0',
                  borderRadius: '8px',
                  fontSize: '13px'
                }}
                formatter={(v) => [`%${v}`, 'Fire Oranı']}
              />
              <Bar dataKey="oran" radius={[6, 6, 0, 0]}>
                {chartData.map((entry, index) => (
                  <Cell key={index} fill={getBarColor(entry.oran)} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Detail Table */}
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Detaylı Fire Tablosu</h3>
        </div>
        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Kamyon</th>
                <th>Sürücü</th>
                <th>Toplanan (LT)</th>
                <th>Teslim Edilen (LT)</th>
                <th>Fark / Fire (LT)</th>
                <th>Fire Oranı</th>
                <th>Durum</th>
              </tr>
            </thead>
            <tbody>
              {fireData.map((f, i) => (
                <tr key={i}>
                  <td style={{ fontWeight: 500 }}>{f.kamyon}</td>
                  <td>{f.surucu}</td>
                  <td>{f.toppinan.toLocaleString('tr-TR')}</td>
                  <td style={{ fontWeight: 600, color: '#2563eb' }}>{f.teslim.toLocaleString('tr-TR')}</td>
                  <td style={{ fontWeight: 600, color: '#ef4444' }}>-{f.fark}</td>
                  <td>
                    <span style={{
                      fontWeight: 600,
                      color: f.oran > 1.5 ? '#ef4444' : f.oran > 1.0 ? '#f59e0b' : '#10b981'
                    }}>
                      %{f.oran}
                    </span>
                  </td>
                  <td>
                    <span className={`badge ${
                      f.oran > 1.5 ? 'badge-danger' : f.oran > 1.0 ? 'badge-warning' : 'badge-active'
                    }`}>
                      {f.oran > 1.5 ? 'Yüksek' : f.oran > 1.0 ? 'Dikkat' : 'Normal'}
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
