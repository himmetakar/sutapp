import { useEffect, useState } from 'react';
import { db } from '../../firebase/config';
import { useAuth } from '../../contexts/AuthContext';
import { 
  collection, 
  query, 
  where, 
  onSnapshot, 
  addDoc, 
  doc, 
  getDoc, 
  updateDoc, 
  increment, 
  serverTimestamp 
} from 'firebase/firestore';
import { 
  FiPlus, 
  FiSearch, 
  FiX, 
  FiDroplet, 
  FiDollarSign, 
  FiAward, 
  FiInbox, 
  FiCalendar, 
  FiFilter, 
  FiCheckCircle 
} from 'react-icons/fi';
import { PieChart, Pie, Cell, ResponsiveContainer, Tooltip } from 'recharts';

const LARGE_BUYERS = [
  'Sütaş',
  'Pınar Süt',
  'Torku Süt',
  'İçim (Ak Gıda)',
  'Sek Süt',
  'Yörükoğlu',
  'Danone Türkiye',
  'Kaanlar Gıda',
  'Süteks',
  'Diğer'
];

const CHART_COLORS = ['#22c55e', '#3b82f6', '#f59e0b', '#ef4444', '#8b5cf6', '#06b6d4', '#ec4899'];

export default function SatisRaporlari() {
  const { user } = useAuth();
  const currentFirmaName = user?.displayName || '';

  // State
  const [satislar, setSatislar] = useState([]);
  const [tanklar, setTanklar] = useState([]);
  const [teslimatlar, setTeslimatlar] = useState([]);
  const [loading, setLoading] = useState(true);
  const [selectedTab, setSelectedTab] = useState('gunluk'); // gunluk, aylik, yillik
  const [selectedDate, setSelectedDate] = useState(new Date().toISOString().split('T')[0]); // yyyy-MM-dd
  const [searchQuery, setSearchQuery] = useState('');
  const [showModal, setShowModal] = useState(false);

  // Form State
  const [form, setForm] = useState({
    aliciFirma: 'Sütaş',
    customFirma: '',
    tarih: new Date().toISOString().split('T')[0],
    miktar: '',
    birimFiyat: '',
    toplamTutar: '',
    tankId: '',
    aciklama: ''
  });
  const [errorMsg, setErrorMsg] = useState('');
  const [successMsg, setSuccessMsg] = useState('');

  // Firestore Subscriptions
  useEffect(() => {
    if (!currentFirmaName) return;

    // Listen to satislar
    const qSatis = query(
      collection(db, 'satislar'),
      where('firma', '==', currentFirmaName)
    );
    const unsubscribeSatis = onSnapshot(qSatis, (snapshot) => {
      const list = snapshot.docs.map(d => ({
        id: d.id,
        ...d.data()
      }));
      setSatislar(list);
      setLoading(false);
    }, (err) => {
      console.error('Satislar fetch error:', err);
      setLoading(false);
    });

    // Listen to merkez tanklar
    const qTanklar = query(
      collection(db, 'tanklar'),
      where('firma', '==', currentFirmaName),
      where('tip', '==', 'merkez')
    );
    const unsubscribeTanklar = onSnapshot(qTanklar, (snapshot) => {
      const list = snapshot.docs.map(d => ({
        id: d.id,
        ...d.data()
      }));
      setTanklar(list);
    }, (err) => {
      console.error('Tanklar fetch error:', err);
    });

    // Listen to teslimatlar
    const qTeslimat = query(
      collection(db, 'teslimatlar')
    );
    const unsubscribeTeslimat = onSnapshot(qTeslimat, (snapshot) => {
      const list = snapshot.docs.map(d => ({
        id: d.id,
        ...d.data()
      }));
      setTeslimatlar(list);
    }, (err) => {
      console.error('Teslimatlar fetch error:', err);
    });

    return () => {
      unsubscribeSatis();
      unsubscribeTanklar();
      unsubscribeTeslimat();
    };
  }, [currentFirmaName]);

  // Handle miktar and birimFiyat change to auto-calculate total
  useEffect(() => {
    const m = parseFloat(form.miktar) || 0;
    const bf = parseFloat(form.birimFiyat) || 0;
    const calc = m * bf;
    setForm(prev => ({
      ...prev,
      toplamTutar: calc > 0 ? calc.toFixed(2) : ''
    }));
  }, [form.miktar, form.birimFiyat]);

  // Period filtering helper
  const isDateInPeriod = (saleDateStr, saleTimestamp) => {
    let date;
    if (saleTimestamp && saleTimestamp.toDate) {
      date = saleTimestamp.toDate();
    } else if (saleDateStr) {
      // Format: dd.MM.yyyy
      const parts = saleDateStr.split('.');
      if (parts.length === 3) {
        date = new Date(parts[2], parts[1] - 1, parts[0]);
      } else {
        date = new Date(saleDateStr);
      }
    } else {
      date = new Date();
    }

    const filterDate = new Date(selectedDate);

    if (selectedTab === 'gunluk') {
      return (
        date.getFullYear() === filterDate.getFullYear() &&
        date.getMonth() === filterDate.getMonth() &&
        date.getDate() === filterDate.getDate()
      );
    } else if (selectedTab === 'aylik') {
      return (
        date.getFullYear() === filterDate.getFullYear() &&
        date.getMonth() === filterDate.getMonth()
      );
    } else {
      // yillik
      return date.getFullYear() === filterDate.getFullYear();
    }
  };

  // Date parsing to dd.MM.yyyy
  const formatDateToTR = (dateStr) => {
    if (!dateStr) return '';
    const parts = dateStr.split('-');
    if (parts.length === 3) {
      return `${parts[2]}.${parts[1]}.${parts[0]}`;
    }
    return dateStr;
  };

  // Display text for date selector
  const getDateRangeText = () => {
    const filterDate = new Date(selectedDate);
    if (selectedTab === 'gunluk') {
      return filterDate.toLocaleDateString('tr-TR', { day: 'numeric', month: 'long', year: 'numeric' });
    } else if (selectedTab === 'aylik') {
      return filterDate.toLocaleDateString('tr-TR', { month: 'long', year: 'numeric' });
    } else {
      return filterDate.toLocaleDateString('tr-TR', { year: 'numeric' });
    }
  };

  // Filter & Group Sales
  const filteredSales = satislar.filter(sale => {
    const matchPeriod = isDateInPeriod(sale.tarih, sale.timestamp);
    const buyer = (sale.aliciFirma || '').toLowerCase();
    const matchSearch = searchQuery === '' || buyer.includes(searchQuery.toLowerCase());
    return matchPeriod && matchSearch;
  });

  // Calculate Metrics
  const totalMiktar = filteredSales.reduce((sum, s) => sum + (parseFloat(s.miktar) || 0), 0);
  const totalCiro = filteredSales.reduce((sum, s) => sum + (parseFloat(s.toplamTutar) || 0), 0);
  const ortFiyat = totalMiktar > 0 ? (totalCiro / totalMiktar) : 0;
  const uniqueBuyers = new Set(filteredSales.map(s => s.aliciFirma).filter(Boolean));

  // Group by Buyer Company
  const groupedSales = filteredSales.reduce((acc, sale) => {
    const buyer = sale.aliciFirma || 'Diğer';
    if (!acc[buyer]) {
      acc[buyer] = { miktar: 0, ciro: 0 };
    }
    acc[buyer].miktar += parseFloat(sale.miktar) || 0;
    acc[buyer].ciro += parseFloat(sale.toplamTutar) || 0;
    return acc;
  }, {});

  // Dynamic Doughnut Chart calculations
  const chartDataMap = {};
  let chartTotal = 0;
  filteredSales.forEach(sale => {
    const buyer = sale.aliciFirma || 'Diğer';
    const miktar = parseFloat(sale.miktar) || 0;
    if (buyer && miktar > 0) {
      chartDataMap[buyer] = (chartDataMap[buyer] || 0) + miktar;
      chartTotal += miktar;
    }
  });

  const chartData = Object.entries(chartDataMap).map(([name, value]) => ({
    name,
    value,
    percentage: chartTotal > 0 ? ((value / chartTotal) * 100).toFixed(1) : '0.0'
  }));

  // Depot deliveries (Giriş) calculations
  const companyTankNames = tanklar.map(t => t.ad || t.tankAdi).filter(Boolean);
  const companyDeliveries = teslimatlar.filter(d => 
    d.firma === currentFirmaName || companyTankNames.includes(d.hedefTank)
  );

  // Group deliveries by Date
  const deliveriesByDate = companyDeliveries.reduce((acc, d) => {
    const dateStr = d.tarih;
    if (dateStr) {
      acc[dateStr] = (acc[dateStr] || 0) + (parseFloat(d.miktar) || 0);
    }
    return acc;
  }, {});

  // Filter deliveries by selected period
  const filteredDeliveries = companyDeliveries.filter(d => 
    isDateInPeriod(d.tarih, d.timestamp)
  );
  const totalGiris = filteredDeliveries.reduce((sum, d) => sum + (parseFloat(d.miktar) || 0), 0);

  const handleAddSale = async (e) => {
    e.preventDefault();
    setErrorMsg('');
    setSuccessMsg('');

    const buyer = form.aliciFirma === 'Diğer' ? form.customFirma.trim() : form.aliciFirma;
    const m = parseFloat(form.miktar);
    const bf = parseFloat(form.birimFiyat);
    const total = parseFloat(form.toplamTutar);

    if (!buyer) {
      setErrorMsg('Lütfen bir alıcı firma girin.');
      return;
    }
    if (isNaN(m) || m <= 0) {
      setErrorMsg('Miktar sıfırdan büyük bir sayı olmalıdır.');
      return;
    }
    if (isNaN(bf) || bf < 0) {
      setErrorMsg('Birim fiyatı geçersiz.');
      return;
    }
    if (isNaN(total) || total <= 0) {
      setErrorMsg('Toplam tutar sıfırdan büyük olmalıdır.');
      return;
    }

    try {
      // Check tank stock if selected
      if (form.tankId) {
        const tankRef = doc(db, 'tanklar', form.tankId);
        const tankSnap = await getDoc(tankRef);
        if (tankSnap.exists()) {
          const currentStok = parseFloat(tankSnap.data().stok) || 0;
          if (currentStok < m) {
            setErrorMsg(`Seçilen tankta yeterli stok yok! Mevcut: ${currentStok.toLocaleString('tr-TR')} LT`);
            return;
          }
          // Decrement stock
          await updateDoc(tankRef, {
            stok: increment(-m)
          });
        } else {
          setErrorMsg('Seçilen tank bulunamadı.');
          return;
        }
      }

      // Format date
      const trDate = formatDateToTR(form.tarih);

      // Save sale
      await addDoc(collection(db, 'satislar'), {
        firma: currentFirmaName,
        aliciFirma: buyer,
        miktar: m,
        birimFiyat: bf,
        toplamTutar: total,
        tarih: trDate,
        aciklama: form.aciklama,
        tankId: form.tankId || '',
        timestamp: serverTimestamp()
      });

      // Also write to sut_satislari so it appears in "Süt Transferleri" and "Cari Hesap" in mobile app
      let tankName = 'Merkez';
      if (form.tankId) {
        const selectedTankDoc = tanklar.find(t => t.id === form.tankId);
        if (selectedTankDoc) {
          tankName = selectedTankDoc.ad || selectedTankDoc.tankAdi || 'Merkez';
        }
      }
      await addDoc(collection(db, 'sut_satislari'), {
        aliciFirma: buyer,
        kaynakTank: tankName,
        miktar: m,
        fiyat: bf,
        toplam: total,
        not: form.aciklama || '',
        tarih: trDate,
        durum: 'Tamamlandı',
        firma: currentFirmaName,
        timestamp: serverTimestamp()
      });

      // Clear form
      setForm({
        aliciFirma: 'Sütaş',
        customFirma: '',
        tarih: new Date().toISOString().split('T')[0],
        miktar: '',
        birimFiyat: '',
        toplamTutar: '',
        tankId: '',
        aciklama: ''
      });
      setSuccessMsg('Süt satışı başarıyla eklendi!');
      setTimeout(() => {
        setShowModal(false);
        setSuccessMsg('');
      }, 1000);

    } catch (err) {
      console.error('Error adding sale:', err);
      setErrorMsg('Satış kaydedilirken bir hata oluştu: ' + err.message);
    }
  };

  return (
    <div className="fade-in">
      {/* Header and Filter Action */}
      <div className="card" style={{ padding: '16px 20px', marginBottom: '20px' }}>
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: '12px' }}>
          
          {/* Tabs Filter */}
          <div style={{ display: 'flex', gap: '8px' }}>
            {[
              { key: 'gunluk', label: 'Günlük' },
              { key: 'aylik', label: 'Aylık' },
              { key: 'yillik', label: 'Yıllık' },
            ].map(tab => (
              <button
                key={tab.key}
                className={`btn btn-sm ${selectedTab === tab.key ? 'btn-primary' : 'btn-secondary'}`}
                onClick={() => setSelectedTab(tab.key)}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* Date Picker Display */}
          <div style={{ display: 'flex', alignItems: 'center', gap: '10px' }}>
            <div style={{ position: 'relative', display: 'flex', alignItems: 'center', gap: '8px', background: '#f8fafc', padding: '6px 12px', borderRadius: '8px', border: '1px solid #e2e8f0' }}>
              <FiCalendar color="#3b82f6" size={16} />
              <span style={{ fontSize: '13px', fontWeight: 600, color: '#334155' }}>
                {getDateRangeText()}
              </span>
              <input
                type={selectedTab === 'gunluk' ? 'date' : selectedTab === 'aylik' ? 'month' : 'number'}
                min="2020"
                max="2030"
                value={selectedTab === 'yillik' ? selectedDate.split('-')[0] : selectedTab === 'aylik' ? selectedDate.substring(0, 7) : selectedDate}
                onChange={(e) => {
                  let val = e.target.value;
                  if (selectedTab === 'yillik') {
                    setSelectedDate(`${val}-01-01`);
                  } else if (selectedTab === 'aylik') {
                    setSelectedDate(`${val}-01`);
                  } else {
                    setSelectedDate(val);
                  }
                }}
                style={{
                  position: 'absolute',
                  inset: 0,
                  opacity: 0,
                  cursor: 'pointer',
                  width: '100%'
                }}
              />
            </div>

            {/* Search Input */}
            <div style={{ position: 'relative' }}>
              <FiSearch style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
              <input
                type="text"
                placeholder="Firma ara..."
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                style={{
                  padding: '8px 12px 8px 36px',
                  border: '1.5px solid #e2e8f0',
                  borderRadius: '8px',
                  fontSize: '13px',
                  outline: 'none',
                  width: '180px',
                  fontFamily: 'inherit'
                }}
              />
            </div>

            {/* Add Button */}
            <button className="btn btn-primary btn-sm" onClick={() => setShowModal(true)}>
              <FiPlus /> Satış Ekle
            </button>
          </div>

        </div>
      </div>

      {/* Metrics Summary Grid */}
      <div className="stats-grid" style={{ marginBottom: '20px' }}>
        <div className="stat-card">
          <div className="stat-icon blue"><FiDroplet /></div>
          <div className="stat-info">
            <div className="stat-value">{totalMiktar.toLocaleString('tr-TR')} L</div>
            <div className="stat-label">Toplam Süt</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon green"><FiDollarSign /></div>
          <div className="stat-info">
            <div className="stat-value">{totalCiro.toLocaleString('tr-TR')} ₺</div>
            <div className="stat-label">Toplam Ciro</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon orange"><FiAward /></div>
          <div className="stat-info">
            <div className="stat-value">{ortFiyat.toFixed(2)} ₺/L</div>
            <div className="stat-label">Ort. Birim Fiyatı</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-icon red"><FiFilter /></div>
          <div className="stat-info">
            <div className="stat-value">{uniqueBuyers.size}</div>
            <div className="stat-label">Firma Sayısı</div>
          </div>
        </div>
      </div>

      {/* Dynamic Doughnut Chart Card showing milk sales distribution */}
      {(chartTotal > 0 || totalGiris > 0) && (
        <div className="card" style={{ marginBottom: '20px', padding: '20px' }}>
          <div className="card-header" style={{ padding: '0 0 16px 0', borderBottom: '1px solid #f1f5f9' }}>
            <h3 className="card-title" style={{ fontSize: '15px', fontWeight: 700 }}>Firma Satış Oranları & Depo Dengesi</h3>
          </div>

          {/* Giriş vs Çıkış Dengesi Badges */}
          <div style={{ 
            display: 'flex', 
            gap: '16px', 
            margin: '16px 0'
          }}>
            <div style={{ 
              background: '#f0fdf4', 
              border: '1px solid #bbf7d0', 
              padding: '10px 16px', 
              borderRadius: '8px', 
              flex: 1, 
              display: 'flex', 
              flexDirection: 'column', 
              alignItems: 'center' 
            }}>
              <span style={{ fontSize: '11px', color: '#15803d', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Toplam Depo Girişi</span>
              <span style={{ fontSize: '18px', fontWeight: 700, color: '#166534', marginTop: '4px' }}>{totalGiris.toLocaleString('tr-TR')} L</span>
            </div>
            <div style={{ 
              background: '#eff6ff', 
              border: '1px solid #bfdbfe', 
              padding: '10px 16px', 
              borderRadius: '8px', 
              flex: 1, 
              display: 'flex', 
              flexDirection: 'column', 
              alignItems: 'center' 
            }}>
              <span style={{ fontSize: '11px', color: '#1d4ed8', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Toplam Satış (Çıkış)</span>
              <span style={{ fontSize: '18px', fontWeight: 700, color: '#1e40af', marginTop: '4px' }}>{totalMiktar.toLocaleString('tr-TR')} L</span>
            </div>
          </div>
          
          {chartTotal > 0 ? (
            <div style={{ 
              display: 'flex', 
              alignItems: 'center', 
              justifyContent: 'space-around', 
              flexWrap: 'wrap', 
              gap: '24px', 
              marginTop: '8px' 
            }}>
              <div style={{ width: '180px', height: '180px', position: 'relative' }}>
                <ResponsiveContainer width="100%" height="100%">
                  <PieChart>
                    <Pie
                      data={chartData}
                      cx="50%"
                      cy="50%"
                      innerRadius={55}
                      outerRadius={80}
                      paddingAngle={2}
                      dataKey="value"
                      stroke="#fff"
                      strokeWidth={2}
                    >
                      {chartData.map((entry, index) => (
                        <Cell key={`cell-${index}`} fill={CHART_COLORS[index % CHART_COLORS.length]} />
                      ))}
                    </Pie>
                    <Tooltip
                      contentStyle={{
                        background: '#fff',
                        border: '1px solid #e2e8f0',
                        borderRadius: '8px',
                        fontSize: '13px',
                        boxShadow: '0 4px 6px -1px rgb(0 0 0 / 0.1)'
                      }}
                      formatter={(v) => [`${v.toLocaleString('tr-TR')} L`, 'Miktar']}
                    />
                  </PieChart>
                </ResponsiveContainer>
              </div>

              <div style={{ 
                flex: 1, 
                minWidth: '250px', 
                display: 'grid', 
                gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', 
                gap: '12px 24px' 
              }}>
                {chartData.map((item, i) => (
                  <div key={i} style={{ 
                    display: 'flex', 
                    alignItems: 'center', 
                    gap: '10px', 
                    padding: '6px 12px', 
                    background: '#f8fafc', 
                    borderRadius: '8px',
                    border: '1px solid #f1f5f9'
                  }}>
                    <div style={{ 
                      width: '10px', 
                      height: '10px', 
                      borderRadius: '50%', 
                      background: CHART_COLORS[i % CHART_COLORS.length], 
                      flexShrink: 0 
                    }} />
                    <span style={{ 
                      fontSize: '13px', 
                      color: '#475569', 
                      fontWeight: 500, 
                      whiteSpace: 'nowrap', 
                      overflow: 'hidden', 
                      textOverflow: 'ellipsis',
                      maxWidth: '100px'
                    }} title={item.name}>
                      {item.name}
                    </span>
                    <span style={{ 
                      marginLeft: 'auto', 
                      fontSize: '13px', 
                      fontWeight: 700, 
                      color: '#1e293b' 
                    }}>
                      %{item.percentage}
                    </span>
                  </div>
                ))}
              </div>
            </div>
          ) : (
            <div style={{ textAlign: 'center', padding: '24px', color: '#64748b', fontSize: '13px' }}>
              Seçilen dönemde henüz satış kaydı bulunmamaktadır.
            </div>
          )}
        </div>
      )}

      {/* Main List Section */}
      <div className="card">
        <div className="card-header">
          <h3 className="card-title">Günlük Stok</h3>
        </div>
        
        {loading ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '40px 0' }}>
            <div className="spinner" style={{ border: '4px solid #f3f3f3', borderTop: '4px solid #3b82f6', borderRadius: '50%', width: '30px', height: '30px', animation: 'spin 1s linear infinite' }}></div>
            <span style={{ marginTop: '12px', fontSize: '14px', color: '#64748b' }}>Yükleniyor...</span>
          </div>
        ) : (filteredSales.length === 0 && filteredDeliveries.length === 0) ? (
          <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', padding: '60px 20px', textAlign: 'center' }}>
            <div style={{ background: '#f1f5f9', padding: '16px', borderRadius: '50%', marginBottom: '16px', color: '#94a3b8' }}>
              <FiInbox size={48} />
            </div>
            <h3 style={{ fontSize: '16px', fontWeight: 600, color: '#334155', marginBottom: '4px' }}>Veri bulunamadı</h3>
            <p style={{ fontSize: '13px', color: '#64748b' }}>Seçilen dönemde veya arama kriterinde satış ya da kabul kaydı yok.</p>
          </div>
        ) : (
          (() => {
            // Extract unique dates and unique buyer companies
            const uniqueDates = [];
            const uniqueBuyers = [];
            const cellData = {};

            filteredSales.forEach(sale => {
              const tarih = sale.tarih || '';
              const buyer = sale.aliciFirma || '';
              const miktar = parseFloat(sale.miktar) || 0;

              if (tarih) {
                if (!uniqueDates.includes(tarih)) {
                  uniqueDates.push(tarih);
                }
                if (buyer) {
                  if (!uniqueBuyers.includes(buyer)) {
                    uniqueBuyers.push(buyer);
                  }
                  if (!cellData[tarih]) {
                    cellData[tarih] = {};
                  }
                  cellData[tarih][buyer] = (cellData[tarih][buyer] || 0) + miktar;
                }
              }
            });

            // Add dates from filteredDeliveries
            filteredDeliveries.forEach(d => {
              const tarih = d.tarih || '';
              if (tarih) {
                if (!uniqueDates.includes(tarih)) {
                  uniqueDates.push(tarih);
                }
              }
            });

            // Sort dates descending (newest first)
            uniqueDates.sort((a, b) => {
              const partsA = a.split('.');
              const partsB = b.split('.');
              if (partsA.length === 3 && partsB.length === 3) {
                const dateA = new Date(partsA[2], partsA[1] - 1, partsA[0]);
                const dateB = new Date(partsB[2], partsB[1] - 1, partsB[0]);
                return dateB - dateA;
              }
              return b.localeCompare(a);
            });

            // Sort buyer names alphabetically
            uniqueBuyers.sort();

            return (
              <div className="table-container" style={{ overflowX: 'auto' }}>
                <table className="data-table">
                  <thead>
                    <tr>
                      <th style={{ minWidth: '100px' }}>Tarih</th>
                      <th style={{ minWidth: '120px', color: '#15803d' }}>Depo Giriş</th>
                      {uniqueBuyers.map(buyer => (
                        <th key={buyer} style={{ minWidth: '120px' }}>{buyer}</th>
                      ))}
                      <th style={{ minWidth: '120px' }}>Toplam Çıkış</th>
                    </tr>
                  </thead>
                  <tbody>
                    {uniqueDates.map((tarih, idx) => {
                      let rowTotal = 0;
                      const girisMiktar = deliveriesByDate[tarih] || 0;
                      
                      // Format Date to TR (e.g. 01.05.2026 -> 01.05)
                      let displayDate = tarih;
                      const dateParts = tarih.split('.');
                      if (dateParts.length === 3) {
                        displayDate = `${dateParts[0]}.${dateParts[1]}`;
                      }

                      return (
                        <tr key={idx}>
                          <td style={{ fontWeight: 600, color: '#475569' }}>{displayDate}</td>
                          <td style={{ fontWeight: 600, color: '#166534', backgroundColor: '#f0fdf4' }}>
                            {girisMiktar > 0 ? `${girisMiktar.toLocaleString('tr-TR')} L` : '0 L'}
                          </td>
                          {uniqueBuyers.map(buyer => {
                            const miktar = (cellData[tarih] && cellData[tarih][buyer]) || 0;
                            rowTotal += miktar;
                            return (
                              <td 
                                key={buyer} 
                                style={{ 
                                  color: miktar > 0 ? '#1d4ed8' : '#94a3b8', 
                                  fontWeight: miktar > 0 ? 600 : 400 
                                }}
                              >
                                {miktar > 0 ? `${miktar.toLocaleString('tr-TR')} L` : '0 L'}
                              </td>
                            );
                          })}
                          <td style={{ fontWeight: 700, color: '#1e293b' }}>
                            {rowTotal.toLocaleString('tr-TR')} L
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            );
          })()
        )}
      </div>

      {/* Add Sale Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: '500px' }}>
            <div className="modal-header">
              <h3>Yeni Süt Satışı Ekle</h3>
              <button className="modal-close" onClick={() => setShowModal(false)}><FiX /></button>
            </div>
            <form onSubmit={handleAddSale}>
              <div className="modal-body">
                {errorMsg && (
                  <div style={{ background: '#fee2e2', border: '1px solid #fecaca', color: '#b91c1c', padding: '10px 14px', borderRadius: '8px', fontSize: '13px', marginBottom: '16px' }}>
                    {errorMsg}
                  </div>
                )}
                {successMsg && (
                  <div style={{ background: '#d1fae5', border: '1px solid #a7f3d0', color: '#065f46', padding: '10px 14px', borderRadius: '8px', fontSize: '13px', marginBottom: '16px', display: 'flex', alignItems: 'center', gap: '8px' }}>
                    <FiCheckCircle /> {successMsg}
                  </div>
                )}

                {/* Buyer Dropdown */}
                <div className="form-group">
                  <label>Alıcı Firma *</label>
                  <select 
                    value={form.aliciFirma} 
                    onChange={e => setForm({ ...form, aliciFirma: e.target.value, customFirma: '' })}
                  >
                    {LARGE_BUYERS.map(b => (
                      <option key={b} value={b}>{b}</option>
                    ))}
                  </select>
                </div>

                {form.aliciFirma === 'Diğer' && (
                  <div className="form-group">
                    <label>Firma Adı Yazın *</label>
                    <input 
                      type="text" 
                      placeholder="Firma adını girin..." 
                      value={form.customFirma} 
                      onChange={e => setForm({ ...form, customFirma: e.target.value })} 
                      required
                    />
                  </div>
                )}

                {/* Date */}
                <div className="form-group">
                  <label>Satış Tarihi *</label>
                  <input 
                    type="date" 
                    value={form.tarih} 
                    onChange={e => setForm({ ...form, tarih: e.target.value })} 
                    required
                  />
                </div>

                {/* Miktar */}
                <div className="form-group">
                  <label>Miktar (LT) *</label>
                  <input 
                    type="number" 
                    step="any"
                    placeholder="Örn: 5000" 
                    value={form.miktar} 
                    onChange={e => setForm({ ...form, miktar: e.target.value })} 
                    required
                  />
                </div>

                {/* Birim Fiyat */}
                <div className="form-group">
                  <label>Birim Fiyat (₺/LT) *</label>
                  <input 
                    type="number" 
                    step="any"
                    placeholder="Örn: 15.50" 
                    value={form.birimFiyat} 
                    onChange={e => setForm({ ...form, birimFiyat: e.target.value })} 
                    required
                  />
                </div>

                {/* Toplam Tutar */}
                <div className="form-group">
                  <label>Toplam Tutar (₺) *</label>
                  <input 
                    type="number" 
                    step="any"
                    placeholder="Otomatik hesaplanır..." 
                    value={form.toplamTutar} 
                    onChange={e => setForm({ ...form, toplamTutar: e.target.value })} 
                    required
                  />
                </div>

                {/* Central Tank Selection */}
                <div className="form-group">
                  <label>Çıkış Yapılacak Tank (Opsiyonel)</label>
                  <select 
                    value={form.tankId} 
                    onChange={e => setForm({ ...form, tankId: e.target.value })}
                  >
                    <option value="">Seçilmedi (Stok düşümü yapılmaz)</option>
                    {tanklar.map(t => (
                      <option key={t.id} value={t.id}>
                        {t.ad} (Mevcut: {(t.stok || 0).toLocaleString('tr-TR')} L)
                      </option>
                    ))}
                  </select>
                </div>

                {/* Açıklama */}
                <div className="form-group">
                  <label>Açıklama (Opsiyonel)</label>
                  <textarea 
                    placeholder="Satışa dair notlar..." 
                    value={form.aciklama} 
                    onChange={e => setForm({ ...form, aciklama: e.target.value })}
                    rows="2"
                    style={{ resize: 'none' }}
                  />
                </div>

              </div>
              <div className="modal-footer">
                <button type="button" className="btn btn-secondary" onClick={() => setShowModal(false)}>İptal</button>
                <button type="submit" className="btn btn-primary">Satışı Ekle</button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
