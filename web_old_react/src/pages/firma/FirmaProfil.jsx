import { useAuth } from '../../contexts/AuthContext';
import { FiUser, FiMail, FiPhone, FiInfo, FiLogOut } from 'react-icons/fi';

export default function FirmaProfil() {
  const { user, logout } = useAuth();

  const handleLogout = async () => {
    await logout();
  };

  const getRoleName = (role) => {
    switch (role) {
      case 'admin': return 'Sistem Admini';
      case 'firma': return 'Firma Yöneticisi';
      case 'surucu': return 'Sürücü';
      case 'uretici': return 'Üretici';
      default: return role;
    }
  };

  return (
    <div className="fade-in">
      <div className="profile-card">
        <div className="profile-avatar">
          {user?.displayName?.charAt(0) || 'U'}
        </div>
        <h2 className="profile-name">{user?.displayName || 'Kullanıcı'}</h2>
        <span className="profile-role">{getRoleName(user?.role)}</span>

        <div className="profile-details">
          <div className="profile-detail-item">
            <span className="profile-detail-label">
              <FiUser style={{ marginRight: '8px', verticalAlign: 'middle' }} />
              Ad Soyad
            </span>
            <span className="profile-detail-value">{user?.displayName || '-'}</span>
          </div>

          <div className="profile-detail-item">
            <span className="profile-detail-label">
              <FiMail style={{ marginRight: '8px', verticalAlign: 'middle' }} />
              E-posta
            </span>
            <span className="profile-detail-value">{user?.email || '-'}</span>
          </div>

          {user?.phone && (
            <div className="profile-detail-item">
              <span className="profile-detail-label">
                <FiPhone style={{ marginRight: '8px', verticalAlign: 'middle' }} />
                Telefon
              </span>
              <span className="profile-detail-value">{user?.phone}</span>
            </div>
          )}

          <div className="profile-detail-item">
            <span className="profile-detail-label">
              <FiInfo style={{ marginRight: '8px', verticalAlign: 'middle' }} />
              Firma ID
            </span>
            <span className="profile-detail-value" style={{ fontFamily: 'monospace', fontSize: '12px' }}>
              {user?.firmaId || 'Demo Firma'}
            </span>
          </div>
        </div>

        <button className="btn btn-danger btn-block" onClick={handleLogout} style={{ marginTop: '12px' }}>
          <FiLogOut size={16} />
          <span>Çıkış Yap</span>
        </button>
      </div>
    </div>
  );
}
