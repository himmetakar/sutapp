import { useState } from 'react';
import {
  FiDatabase, FiTruck, FiUsers, FiDroplet,
  FiPlus, FiMoreVertical, FiSearch
} from 'react-icons/fi';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid,
  Tooltip, ResponsiveContainer, LineChart, Line
} from 'recharts';

// Demo data
const demoStats = {
  totalFirmalar: 24,
  activeFirmalar: 18,
  totalSuruculer: 156,
  toplamSut: '1.245.600',
  totalUreticiler: 892
};

const monthlyData = [
  { ay: 'Oca', miktar: 98500 },
  { ay: 'Şub', miktar: 102300 },
  { ay: 'Mar', miktar: 115200 },
  { ay: 'Nis', miktar: 108700 },
  { ay: 'May', miktar: 125400 },
  { ay: 'Haz', miktar: 132800 },
];

const demoFirmalar = [
  { id: 1, name: 'Anadolu Süt A.Ş.', owner: 'Ahmet Yılmaz', surucu: 12, uretici: 89, plan: 'Endüstriyel', status: 'active' },
  { id: 2, name: 'Kayseri Çiftlik', owner: 'Fatma Demir', surucu: 5, uretici: 42, plan: 'Orta', status: 'active' },
  { id: 3, name: 'Güneydoğu Süt', owner: 'Murat Kaya', surucu: 8, uretici: 67, plan: 'Orta', status: 'active' },
  { id: 4, name: 'Trakya Mandıra', owner: 'Elif Şahin', surucu: 3, uretici: 28, plan: 'Küçük', status: 'warning' },
  { id: 5, name: 'Ege Süt Birliği', owner: 'Hasan Öz', surucu: 15, uretici: 112, plan: 'Endüstriyel', status: 'active' },
];

export default function AdminDashboard() {
  return (
    <div className="fade-in">
      {/* Stat Cards */}
      <div className="stats-grid">
        <div className="stat-card">
          <div className="stat-icon blue"><FiDatabase /></div>
          <div className="stat-info">
            <div className="stat-value">{demoStats.totalFirmalar}</div>
            <div className="stat-label">Toplam Firma</div>
            <div className="stat-change up">↑ {demoStats.activeFirmalar} aktif</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon green"><FiTruck /></div>
          <div className="stat-info">
            <div className="stat-value">{demoStats.totalSuruculer}</div>
            <div className="stat-label">Aktif Sürücü</div>
            <div className="stat-change up">↑ 12 bu ay</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon orange"><FiUsers /></div>
          <div className="stat-info">
            <div className="stat-value">{demoStats.totalUreticiler}</div>
            <div className="stat-label">Toplam Üretici</div>
            <div className="stat-change up">↑ 45 yeni</div>
          </div>
        </div>

        <div className="stat-card">
          <div className="stat-icon blue"><FiDroplet /></div>
          <div className="stat-info">
            <div className="stat-value">{demoStats.toplamSut}</div>
            <div className="stat-label">Toplam Süt (LT)</div>
            <div className="stat-change up">↑ %8.2 artış</div>
          </div>
        </div>
      </div>

      {/* Charts */}
      <div className="grid-2" style={{ marginBottom: '28px' }}>
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Aylık Toplam Süt Hacmi</h3>
          </div>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={monthlyData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="ay" stroke="#94a3b8" fontSize={12} />
                <YAxis stroke="#94a3b8" fontSize={12} />
                <Tooltip
                  contentStyle={{
                    background: '#fff',
                    border: '1px solid #e2e8f0',
                    borderRadius: '8px',
                    fontSize: '13px'
                  }}
                  formatter={(value) => [`${value.toLocaleString('tr-TR')} LT`, 'Miktar']}
                />
                <Bar dataKey="miktar" fill="#3b82f6" radius={[6, 6, 0, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Firma Büyüme Trendi</h3>
          </div>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={monthlyData}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="ay" stroke="#94a3b8" fontSize={12} />
                <YAxis stroke="#94a3b8" fontSize={12} />
                <Tooltip
                  contentStyle={{
                    background: '#fff',
                    border: '1px solid #e2e8f0',
                    borderRadius: '8px',
                    fontSize: '13px'
                  }}
                />
                <Line type="monotone" dataKey="miktar" stroke="#2563eb" strokeWidth={2} dot={{ r: 4 }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Firma List */}
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Son Eklenen Firmalar</h3>
          <button className="btn btn-primary btn-sm">
            <FiPlus /> Firma Ekle
          </button>
        </div>
        <div className="table-container">
          <table className="data-table">
            <thead>
              <tr>
                <th>Firma Adı</th>
                <th>Sahibi</th>
                <th>Sürücü</th>
                <th>Üretici</th>
                <th>Paket</th>
                <th>Durum</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {demoFirmalar.map(firma => (
                <tr key={firma.id}>
                  <td style={{ fontWeight: 500 }}>{firma.name}</td>
                  <td>{firma.owner}</td>
                  <td>{firma.surucu}</td>
                  <td>{firma.uretici}</td>
                  <td><span className="badge badge-info">{firma.plan}</span></td>
                  <td>
                    <span className={`badge ${firma.status === 'active' ? 'badge-active' : 'badge-warning'}`}>
                      {firma.status === 'active' ? 'Aktif' : 'Uyarı'}
                    </span>
                  </td>
                  <td>
                    <button className="btn btn-ghost btn-sm"><FiMoreVertical /></button>
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
