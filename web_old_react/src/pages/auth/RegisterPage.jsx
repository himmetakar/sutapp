import { useState, useEffect } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { FiCheckCircle, FiUser, FiMapPin, FiMail, FiAlertTriangle } from 'react-icons/fi';

export default function RegisterPage() {
  const { registerPhoneUser, verifiedPhone, logout, loading } = useAuth();
  const [displayName, setDisplayName] = useState('');
  const [email, setEmail] = useState('');
  const [addressDetails, setAddressDetails] = useState('');
  const [postalCode, setPostalCode] = useState('');

  // Dropdown states
  const [provinces, setProvinces] = useState([]);
  const [districts, setDistricts] = useState([]);
  const [neighborhoods, setNeighborhoods] = useState([]);

  const [selectedProvince, setSelectedProvince] = useState(null);
  const [selectedDistrict, setSelectedDistrict] = useState(null);
  const [selectedNeighborhood, setSelectedNeighborhood] = useState(null);

  // Manual fallback states
  const [manualMode, setManualMode] = useState(false);
  const [manualIl, setManualIl] = useState('');
  const [manualIlce, setManualIlce] = useState('');
  const [manualMahalle, setManualMahalle] = useState('');

  const [apiLoading, setApiLoading] = useState(false);
  const [error, setError] = useState('');

  // Load Provinces
  useEffect(() => {
    const fetchProvinces = async () => {
      setApiLoading(true);
      setError('');
      try {
        const res = await fetch('https://turkiyeapi.dev/api/v1/provinces?fields=id,name');
        if (!res.ok) throw new Error('API hatası');
        const json = await res.json();
        if (json.status === 'OK' && json.data) {
          const sorted = [...json.data].sort((a, b) => a.name.localeCompare(b.name, 'tr'));
          setProvinces(sorted);
        } else {
          setManualMode(true);
        }
      } catch (err) {
        console.error('Province fetch error:', err);
        setManualMode(true);
      } finally {
        setApiLoading(false);
      }
    };
    fetchProvinces();
  }, []);

  // Load Districts when Province changes
  useEffect(() => {
    if (!selectedProvince) {
      setDistricts([]);
      setSelectedDistrict(null);
      return;
    }

    const fetchDistricts = async () => {
      setApiLoading(true);
      setError('');
      try {
        const res = await fetch(`https://turkiyeapi.dev/api/v1/districts?provinceId=${selectedProvince.id}&fields=id,name`);
        if (!res.ok) throw new Error('API hatası');
        const json = await res.json();
        if (json.status === 'OK' && json.data) {
          const sorted = [...json.data].sort((a, b) => a.name.localeCompare(b.name, 'tr'));
          setDistricts(sorted);
        }
      } catch (err) {
        console.error('District fetch error:', err);
        setError('İlçeler yüklenemedi. Elle giriş moduna geçebilirsiniz.');
      } finally {
        setApiLoading(false);
      }
    };
    fetchDistricts();
  }, [selectedProvince]);

  // Load Neighborhoods when District changes
  useEffect(() => {
    if (!selectedDistrict) {
      setNeighborhoods([]);
      setSelectedNeighborhood(null);
      return;
    }

    const fetchNeighborhoods = async () => {
      setApiLoading(true);
      setError('');
      try {
        const res = await fetch(`https://turkiyeapi.dev/api/v1/neighborhoods?districtId=${selectedDistrict.id}&fields=id,name`);
        if (!res.ok) throw new Error('API hatası');
        const json = await res.json();
        if (json.status === 'OK' && json.data) {
          const sorted = [...json.data].sort((a, b) => a.name.localeCompare(b.name, 'tr'));
          setNeighborhoods(sorted);
        }
      } catch (err) {
        console.error('Neighborhood fetch error:', err);
        setNeighborhoods([]);
      } finally {
        setApiLoading(false);
      }
    };
    fetchNeighborhoods();
  }, [selectedDistrict]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');

    if (!displayName.trim()) {
      setError('Ad Soyad alanı zorunludur.');
      return;
    }

    const il = manualMode ? manualIl.trim() : (selectedProvince?.name || '');
    const ilce = manualMode ? manualIlce.trim() : (selectedDistrict?.name || '');
    const mahalleKoy = manualMode 
      ? manualMahalle.trim() 
      : (selectedNeighborhood?.name || manualMahalle.trim());

    if (!il || !ilce || !mahalleKoy) {
      setError('Lütfen İl, İlçe ve Mahalle/Köy bilgilerini eksiksiz doldurun.');
      return;
    }

    try {
      await registerPhoneUser({
        displayName: displayName.trim(),
        email: email.trim() || '',
        il,
        ilce,
        mahalleKoy,
        adresDetay: addressDetails.trim(),
        postaKodu: postalCode.trim()
      });
    } catch (err) {
      console.error(err);
      setError(err.message || 'Kayıt işlemi başarısız oldu.');
    }
  };

  return (
    <div className="login-page">
      <div className="login-container" style={{ maxWidth: '480px' }}>
        <div className="login-card" style={{ padding: '30px' }}>
          {/* Logo */}
          <div className="login-logo">
            <h1>Süt<span>App</span></h1>
            <p>Hesabınızı Tamamlayın (Üretici Kaydı)</p>
          </div>

          {/* Verified Phone Badge */}
          <div style={{
            display: 'flex',
            alignItems: 'center',
            gap: '8px',
            background: '#ecfdf5',
            border: '1px solid #a7f3d0',
            color: '#065f46',
            padding: '10px 14px',
            borderRadius: '8px',
            fontSize: '13px',
            fontWeight: '600',
            marginBottom: '20px'
          }}>
            <FiCheckCircle style={{ color: '#10b981', flexShrink: 0 }} />
            <span>Doğrulanmış Numara: {verifiedPhone || 'Bilinmiyor'}</span>
          </div>

          <form className="login-form" onSubmit={handleSubmit}>
            {/* Ad Soyad */}
            <div className="form-group">
              <label htmlFor="displayName">Ad Soyad *</label>
              <div style={{ position: 'relative' }}>
                <FiUser style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
                <input
                  id="displayName"
                  type="text"
                  placeholder="Mehmet Yılmaz"
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  style={{ paddingLeft: '36px', width: '100%' }}
                  disabled={loading}
                  required
                />
              </div>
            </div>

            {/* Email */}
            <div className="form-group">
              <label htmlFor="email">E-posta (Opsiyonel)</label>
              <div style={{ position: 'relative' }}>
                <FiMail style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
                <input
                  id="email"
                  type="email"
                  placeholder="ornek@posta.com"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  style={{ paddingLeft: '36px', width: '100%' }}
                  disabled={loading}
                />
              </div>
            </div>

            {/* Address Selection Header */}
            <div style={{
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              marginTop: '20px',
              marginBottom: '10px'
            }}>
              <label style={{ fontWeight: 'bold', fontSize: '14px', margin: 0 }}>Adres Bilgileri *</label>
              <button
                type="button"
                onClick={() => setManualMode(!manualMode)}
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#2563eb',
                  fontSize: '12px',
                  fontWeight: 'bold',
                  cursor: 'pointer',
                  padding: 0
                }}
              >
                {manualMode ? 'Listeden Seç' : 'Elle Yaz'}
              </button>
            </div>

            {apiLoading && (
              <div style={{ textAlign: 'center', padding: '10px', fontSize: '13px', color: '#64748b' }}>
                Adres bilgileri yükleniyor...
              </div>
            )}

            {!manualMode ? (
              <>
                {/* İl Dropdown */}
                <div className="form-group">
                  <div style={{ position: 'relative' }}>
                    <FiMapPin style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8', zIndex: 1 }} />
                    <select
                      value={selectedProvince ? JSON.stringify(selectedProvince) : ''}
                      onChange={(e) => {
                        const val = e.target.value;
                        setSelectedProvince(val ? JSON.parse(val) : null);
                      }}
                      style={{ paddingLeft: '36px', width: '100%', appearance: 'auto', background: '#fff' }}
                      disabled={loading || apiLoading}
                      required
                    >
                      <option value="">İl Seçiniz</option>
                      {provinces.map((p) => (
                        <option key={p.id} value={JSON.stringify(p)}>{p.name}</option>
                      ))}
                    </select>
                  </div>
                </div>

                {/* İlçe Dropdown */}
                <div className="form-group">
                  <div style={{ position: 'relative' }}>
                    <FiMapPin style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8', zIndex: 1 }} />
                    <select
                      value={selectedDistrict ? JSON.stringify(selectedDistrict) : ''}
                      onChange={(e) => {
                        const val = e.target.value;
                        setSelectedDistrict(val ? JSON.parse(val) : null);
                      }}
                      style={{ paddingLeft: '36px', width: '100%', appearance: 'auto', background: '#fff' }}
                      disabled={loading || apiLoading || !selectedProvince}
                      required
                    >
                      <option value="">İlçe Seçiniz</option>
                      {districts.map((d) => (
                        <option key={d.id} value={JSON.stringify(d)}>{d.name}</option>
                      ))}
                    </select>
                  </div>
                </div>

                {/* Mahalle / Köy Dropdown */}
                <div className="form-group">
                  <div style={{ position: 'relative' }}>
                    <FiMapPin style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8', zIndex: 1 }} />
                    {neighborhoods.length > 0 ? (
                      <select
                        value={selectedNeighborhood ? JSON.stringify(selectedNeighborhood) : ''}
                        onChange={(e) => {
                          const val = e.target.value;
                          setSelectedNeighborhood(val ? JSON.parse(val) : null);
                        }}
                        style={{ paddingLeft: '36px', width: '100%', appearance: 'auto', background: '#fff' }}
                        disabled={loading || apiLoading || !selectedDistrict}
                        required
                      >
                        <option value="">Mahalle / Köy Seçiniz</option>
                        {neighborhoods.map((n) => (
                          <option key={n.id} value={JSON.stringify(n)}>{n.name}</option>
                        ))}
                      </select>
                    ) : (
                      <input
                        type="text"
                        placeholder="Mahalle / Köy adını girin *"
                        value={manualMahalle}
                        onChange={(e) => setManualMahalle(e.target.value)}
                        style={{ paddingLeft: '36px', width: '100%' }}
                        disabled={loading || !selectedDistrict}
                        required
                      />
                    )}
                  </div>
                </div>
              </>
            ) : (
              <>
                {/* Manual İl */}
                <div className="form-group">
                  <input
                    type="text"
                    placeholder="İl girin *"
                    value={manualIl}
                    onChange={(e) => setManualIl(e.target.value)}
                    disabled={loading}
                    required
                  />
                </div>
                {/* Manual İlçe */}
                <div className="form-group">
                  <input
                    type="text"
                    placeholder="İlçe girin *"
                    value={manualIlce}
                    onChange={(e) => setManualIlce(e.target.value)}
                    disabled={loading}
                    required
                  />
                </div>
                {/* Manual Mahalle / Köy */}
                <div className="form-group">
                  <input
                    type="text"
                    placeholder="Mahalle / Köy girin *"
                    value={manualMahalle}
                    onChange={(e) => setManualMahalle(e.target.value)}
                    disabled={loading}
                    required
                  />
                </div>
              </>
            )}

            {/* Adres Detayı */}
            <div className="form-group">
              <label htmlFor="addressDetails">Adres Detayı</label>
              <textarea
                id="addressDetails"
                placeholder="Sokak, Bina No, Kapı No, vb."
                value={addressDetails}
                onChange={(e) => setAddressDetails(e.target.value)}
                style={{
                  width: '100%',
                  minHeight: '80px',
                  padding: '10px 12px',
                  border: '1.5px solid #e2e8f0',
                  borderRadius: '8px',
                  fontSize: '14px',
                  fontFamily: 'inherit',
                  outline: 'none',
                  resize: 'vertical'
                }}
                disabled={loading}
              />
            </div>

            {/* Posta Kodu */}
            <div className="form-group">
              <label htmlFor="postalCode">Posta Kodu</label>
              <input
                id="postalCode"
                type="text"
                placeholder="38000"
                value={postalCode}
                onChange={(e) => setPostalCode(e.target.value)}
                disabled={loading}
              />
            </div>

            {error && (
              <div className="error-message" style={{
                display: 'flex',
                alignItems: 'center',
                gap: '8px',
                padding: '10px 14px',
                background: '#fee2e2',
                color: '#991b1b',
                borderRadius: '8px',
                fontSize: '13px',
                marginBottom: '15px'
              }}>
                <FiAlertTriangle style={{ flexShrink: 0 }} />
                <span>{error}</span>
              </div>
            )}

            <button
              type="submit"
              className="btn btn-primary btn-block btn-lg"
              style={{ marginTop: '10px' }}
              disabled={loading}
            >
              {loading ? 'Kayıt Yapılıyor...' : 'Kaydı Tamamla'}
            </button>

            <button
              type="button"
              className="btn btn-ghost btn-block"
              onClick={logout}
              style={{ marginTop: '10px', fontSize: '13px', color: '#ef4444' }}
              disabled={loading}
            >
              Çıkış Yap
            </button>
          </form>
        </div>
      </div>
    </div>
  );
}
