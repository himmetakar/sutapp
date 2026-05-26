import { useState } from 'react';
import { useAuth } from '../../contexts/AuthContext';
import { FiPhone, FiLock } from 'react-icons/fi';

export default function LoginPage() {
  const { verifyPhone, confirmCode, demoLogin, loading } = useAuth();
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [codeSent, setCodeSent] = useState(false);
  const [error, setError] = useState('');
  const [statusMessage, setStatusMessage] = useState('');

  const formatPhoneNumber = (input) => {
    const cleaned = input.trim();
    if (!cleaned) return '';
    if (cleaned.startsWith('+')) return cleaned;
    if (cleaned.startsWith('0')) {
      return `+90${cleaned.substring(1)}`;
    }
    return `+90${cleaned}`;
  };

  const handleSendCode = async (e) => {
    e.preventDefault();
    setError('');
    setStatusMessage('');
    const formatted = formatPhoneNumber(phone);
    if (!formatted || formatted.length < 10) {
      setError('Lütfen geçerli bir telefon numarası girin.');
      return;
    }

    try {
      setStatusMessage('reCAPTCHA doğrulanıyor ve kod gönderiliyor...');
      await verifyPhone(formatted, 'recaptcha-container');
      setCodeSent(true);
      setStatusMessage('Doğrulama kodu SMS olarak gönderildi.');
    } catch (err) {
      console.error(err);
      setError(err.message || 'SMS gönderme başarısız. Lütfen numarayı kontrol edin.');
      setStatusMessage('');
    }
  };

  const handleVerifyCode = async (e) => {
    e.preventDefault();
    setError('');
    setStatusMessage('');
    if (!code || code.length !== 6) {
      setError('Lütfen 6 haneli doğrulama kodunu girin.');
      return;
    }

    try {
      setStatusMessage('Kod doğrulanıyor...');
      await confirmCode(code);
    } catch (err) {
      console.error(err);
      setError('Kod doğrulanamadı. Lütfen kodu kontrol edin.');
      setStatusMessage('');
    }
  };

  const handleDemoLogin = (role) => {
    demoLogin(role);
  };

  return (
    <div className="login-page">
      <div className="login-container">
        <div className="login-card">
          {/* Logo */}
          <div className="login-logo">
            <h1>Süt<span>App</span></h1>
            <p>Dijital Süt Toplama ve Yönetim Sistemi</p>
          </div>

          {/* Recaptcha container target */}
          <div id="recaptcha-container"></div>

          {/* Login Form */}
          {!codeSent ? (
            <form className="login-form" onSubmit={handleSendCode}>
              <div className="form-group">
                <label htmlFor="phone">Telefon Numarası</label>
                <div style={{ position: 'relative' }}>
                  <FiPhone style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
                  <input
                    id="phone"
                    type="tel"
                    placeholder="555 123 4567"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value)}
                    style={{ paddingLeft: '36px', width: '100%' }}
                    disabled={loading}
                    required
                  />
                </div>
              </div>

              {error && (
                <div className="error-message" style={{
                  padding: '10px 14px',
                  background: '#fee2e2',
                  color: '#991b1b',
                  borderRadius: '8px',
                  fontSize: '13px',
                  marginBottom: '15px'
                }}>
                  {error}
                </div>
              )}

              {statusMessage && (
                <div className="status-message" style={{
                  padding: '10px 14px',
                  background: '#e0f2fe',
                  color: '#0369a1',
                  borderRadius: '8px',
                  fontSize: '13px',
                  marginBottom: '15px'
                }}>
                  {statusMessage}
                </div>
              )}

              <button
                type="submit"
                className="btn btn-primary btn-block btn-lg"
                disabled={loading}
              >
                {loading ? 'Lütfen bekleyin...' : 'Doğrulama Kodu Gönder'}
              </button>
            </form>
          ) : (
            <form className="login-form" onSubmit={handleVerifyCode}>
              <div className="form-group">
                <label htmlFor="code">Doğrulama Kodu (SMS)</label>
                <div style={{ position: 'relative' }}>
                  <FiLock style={{ position: 'absolute', left: '12px', top: '50%', transform: 'translateY(-50%)', color: '#94a3b8' }} />
                  <input
                    id="code"
                    type="text"
                    placeholder="######"
                    maxLength={6}
                    value={code}
                    onChange={(e) => setCode(e.target.value)}
                    style={{ paddingLeft: '36px', width: '100%' }}
                    disabled={loading}
                    required
                  />
                </div>
              </div>

              {error && (
                <div className="error-message" style={{
                  padding: '10px 14px',
                  background: '#fee2e2',
                  color: '#991b1b',
                  borderRadius: '8px',
                  fontSize: '13px',
                  marginBottom: '15px'
                }}>
                  {error}
                </div>
              )}

              {statusMessage && (
                <div className="status-message" style={{
                  padding: '10px 14px',
                  background: '#e0f2fe',
                  color: '#0369a1',
                  borderRadius: '8px',
                  fontSize: '13px',
                  marginBottom: '15px'
                }}>
                  {statusMessage}
                </div>
              )}

              <button
                type="submit"
                className="btn btn-primary btn-block btn-lg"
                disabled={loading}
              >
                {loading ? 'Doğrulanıyor...' : 'Giriş Yap'}
              </button>

              <button
                type="button"
                className="btn btn-ghost btn-block"
                onClick={() => {
                  setCodeSent(false);
                  setCode('');
                  setError('');
                  setStatusMessage('');
                }}
                style={{ marginTop: '10px', fontSize: '13px', color: '#64748b' }}
                disabled={loading}
              >
                Numarayı Değiştir
              </button>
            </form>
          )}

          {/* Demo Buttons */}
          <div className="demo-divider">
            <span>Hızlı Demo Giriş</span>
          </div>

          <div className="demo-buttons">
            <button className="demo-btn" onClick={() => handleDemoLogin('admin')}>
              <div className="demo-icon admin">🛡️</div>
              <div className="demo-info">
                <div className="demo-role">Sistem Admin</div>
                <div className="demo-desc">Tüm sistem yönetimi</div>
              </div>
            </button>

            <button className="demo-btn" onClick={() => handleDemoLogin('firma')}>
              <div className="demo-icon firma">🏢</div>
              <div className="demo-info">
                <div className="demo-role">Firma Paneli</div>
                <div className="demo-desc">Toplama yönetimi</div>
              </div>
            </button>

            <button className="demo-btn" onClick={() => handleDemoLogin('surucu')}>
              <div className="demo-icon surucu">🚛</div>
              <div className="demo-info">
                <div className="demo-role">Sürücü</div>
                <div className="demo-desc">Süt toplama</div>
              </div>
            </button>

            <button className="demo-btn" onClick={() => handleDemoLogin('uretici')}>
              <div className="demo-icon uretici">🐄</div>
              <div className="demo-info">
                <div className="demo-role">Üretici</div>
                <div className="demo-desc">Süt geçmişi</div>
              </div>
            </button>
          </div>
        </div>

        <p style={{
          textAlign: 'center',
          fontSize: '12px',
          color: '#94a3b8',
          marginTop: '20px'
        }}>
          © 2026 SütApp Teknolojileri — Tüm hakları saklıdır.
        </p>
      </div>
    </div>
  );
}
