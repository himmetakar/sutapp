import { useState } from 'react';
import { FiCalendar, FiFilter } from 'react-icons/fi';
import {
  BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip,
  ResponsiveContainer, LineChart, Line, PieChart, Pie, Cell, Legend
} from 'recharts';

const bolgeData = [
  { name: 'Yeşilova Köyü', buAy: 12500, gecenAy: 11200 },
  { name: 'Kızıltepe Mah.', buAy: 9800, gecenAy: 10100 },
  { name: 'Dağyolu Çiftlikleri', buAy: 8200, gecenAy: 7500 },
  { name: 'Akarsu Bölgesi', buAy: 6400, gecenAy: 5800 },
  { name: 'Merkez', buAy: 4500, gecenAy: 4200 },
];

const trendData = [
  { ay: 'Oca', sut: 38200, uretici: 38 },
  { ay: 'Şub', sut: 42100, uretici: 39 },
  { ay: 'Mar', sut: 45600, uretici: 40 },
  { ay: 'Nis', sut: 48900, uretici: 41 },
  { ay: 'May', sut: 52300, uretici: 42 },
  { ay: 'Haz', sut: 58900, uretici: 42 },
];

const topUreticiler = [
  { name: 'Hatice Yıldız', total: 18200 },
  { name: 'Ayşe Şahin', total: 15600 },
  { name: 'Mehmet Yılmaz', total: 12500 },
  { name: 'Hüseyin Kaya', total: 11200 },
  { name: 'İbrahim Arslan', total: 10500 },
];

const COLORS = ['#3b82f6', '#2563eb', '#60a5fa', '#93c5fd', '#bfdbfe'];

export default function FirmaRaporlar() {
  const [period, setPeriod] = useState('buAy');

  return (
    <div className="fade-in">
      {/* Filter Bar */}
      <div className="card" style={{ padding: '16px 20px', marginBottom: '20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '12px', flexWrap: 'wrap' }}>
          <FiFilter size={16} color="#64748b" />
          <span style={{ fontSize: '13px', color: '#64748b', fontWeight: 500 }}>Dönem:</span>
          {[
            { key: 'bugun', label: 'Bugün' },
            { key: 'buHafta', label: 'Bu Hafta' },
            { key: 'buAy', label: 'Bu Ay' },
            { key: 'buYil', label: 'Bu Yıl' },
          ].map(p => (
            <button
              key={p.key}
              className={`btn btn-sm ${period === p.key ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => setPeriod(p.key)}
            >
              {p.label}
            </button>
          ))}
        </div>
      </div>

      {/* Comparison Charts */}
      <div className="grid-2" style={{ marginBottom: '20px' }}>
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Bölge Karşılaştırma (Bu Ay / Geçen Ay)</h3>
          </div>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={bolgeData} layout="vertical">
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis type="number" stroke="#94a3b8" fontSize={11} />
                <YAxis dataKey="name" type="category" stroke="#94a3b8" fontSize={11} width={120} />
                <Tooltip
                  contentStyle={{
                    background: '#fff',
                    border: '1px solid #e2e8f0',
                    borderRadius: '8px',
                    fontSize: '13px'
                  }}
                  formatter={(v) => [`${v.toLocaleString('tr-TR')} LT`]}
                />
                <Legend />
                <Bar dataKey="buAy" name="Bu Ay" fill="#3b82f6" radius={[0, 4, 4, 0]} />
                <Bar dataKey="gecenAy" name="Geçen Ay" fill="#bfdbfe" radius={[0, 4, 4, 0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Aylık Süt Üretim Trendi</h3>
          </div>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={trendData}>
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
                  formatter={(v) => [`${v.toLocaleString('tr-TR')} LT`]}
                />
                <Line type="monotone" dataKey="sut" name="Süt (LT)" stroke="#2563eb" strokeWidth={2.5} dot={{ r: 4, fill: '#2563eb' }} />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>

      {/* Top Producers & Pie */}
      <div className="grid-2">
        <div className="card">
          <div className="card-header">
            <h3 className="card-title">En Çok Süt Veren Üreticiler</h3>
          </div>
          {topUreticiler.map((u, i) => (
            <div key={i} style={{
              display: 'flex',
              alignItems: 'center',
              gap: '14px',
              padding: '12px 0',
              borderBottom: i < topUreticiler.length - 1 ? '1px solid #f1f5f9' : 'none'
            }}>
              <div style={{
                width: '32px',
                height: '32px',
                borderRadius: '50%',
                background: i === 0 ? '#fef3c7' : i === 1 ? '#f1f5f9' : i === 2 ? '#fef3c7' : '#f8fafc',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '14px',
                fontWeight: 700,
                color: i < 3 ? '#92400e' : '#64748b'
              }}>
                {i + 1}
              </div>
              <div style={{ flex: 1 }}>
                <div style={{ fontWeight: 500, fontSize: '14px', color: '#1e293b' }}>{u.name}</div>
              </div>
              <div style={{ fontWeight: 700, color: '#2563eb', fontSize: '15px' }}>
                {u.total.toLocaleString('tr-TR')} LT
              </div>
            </div>
          ))}
        </div>

        <div className="card">
          <div className="card-header">
            <h3 className="card-title">Bölge Dağılımı</h3>
          </div>
          <div className="chart-container">
            <ResponsiveContainer width="100%" height="100%">
              <PieChart>
                <Pie
                  data={bolgeData}
                  cx="50%"
                  cy="50%"
                  innerRadius={60}
                  outerRadius={100}
                  dataKey="buAy"
                  nameKey="name"
                  stroke="none"
                  label={({ name, percent }) => `${name} (${(percent * 100).toFixed(0)}%)`}
                  labelLine={false}
                >
                  {bolgeData.map((_, index) => (
                    <Cell key={index} fill={COLORS[index % COLORS.length]} />
                  ))}
                </Pie>
                <Tooltip formatter={(v) => [`${v.toLocaleString('tr-TR')} LT`]} />
              </PieChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  );
}
