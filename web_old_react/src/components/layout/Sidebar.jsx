import { NavLink, useNavigate } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import {
  FiHome, FiUsers, FiTruck, FiPackage,
  FiBarChart2, FiLogOut, FiClipboard,
  FiDatabase, FiCreditCard, FiDroplet,
  FiUser, FiBox, FiTrendingUp
} from 'react-icons/fi';

export default function Sidebar() {
  const { user, logout, isAdmin, isFirma, isSurucu, isUretici } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await logout();
    navigate('/login');
  };

  const getInitials = (name) => {
    if (!name) return '?';
    return name.split(' ').map(n => n[0]).join('').toUpperCase().slice(0, 2);
  };

  const getRoleName = (role) => {
    const names = {
      admin: 'Sistem Admini',
      firma: 'Firma Yöneticisi',
      surucu: 'Kamyon Sürücüsü',
      uretici: 'Süt Üreticisi'
    };
    return names[role] || role;
  };

  return (
    <aside className="sidebar">
      {/* Logo */}
      <div className="sidebar-header">
        <div className="sidebar-logo">
          Süt<span>App</span>
        </div>
      </div>

      {/* Navigation */}
      <nav className="sidebar-nav">
        {/* Admin Navigation */}
        {isAdmin && (
          <>
            <div className="sidebar-section-title">Yönetim</div>
            <NavLink to="/admin" end className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiHome /></span>
              Dashboard
            </NavLink>
            <NavLink to="/admin/firmalar" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiDatabase /></span>
              Firmalar
            </NavLink>
            <NavLink to="/admin/abonelikler" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiCreditCard /></span>
              Abonelikler
            </NavLink>
            <NavLink to="/admin/istatistikler" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiBarChart2 /></span>
              İstatistikler
            </NavLink>
          </>
        )}

        {/* Firma Navigation */}
        {isFirma && (
          <>
            <div className="sidebar-section-title">Operasyon</div>
            <NavLink to="/firma" end className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiHome /></span>
              Dashboard
            </NavLink>
            <NavLink to="/firma/ureticiler" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiUsers /></span>
              Üreticiler
            </NavLink>

            <div className="sidebar-section-title">Filo Yönetimi</div>
            <NavLink to="/firma/araclar" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiTruck /></span>
              Araçlar
            </NavLink>
            <NavLink to="/firma/suruculer" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiUser /></span>
              Sürücüler
            </NavLink>
            <NavLink to="/firma/tanklar" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiBox /></span>
              Tanklar
            </NavLink>

            <div className="sidebar-section-title">Süt Operasyonu</div>
            <NavLink to="/firma/toplamalar" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiDroplet /></span>
              Süt Toplamalar
            </NavLink>
            <NavLink to="/firma/teslimatlar" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiPackage /></span>
              Merkez Teslimat
            </NavLink>

            <div className="sidebar-section-title">Analiz</div>
            <NavLink to="/firma/raporlar" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiBarChart2 /></span>
              Raporlar & Grafikler
            </NavLink>
            <NavLink to="/firma/fire-takip" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiClipboard /></span>
              Fire Takibi
            </NavLink>
            <NavLink to="/firma/satis-raporlari" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiTrendingUp /></span>
              Satış Raporları
            </NavLink>
          </>
        )}

        {/* Sürücü Navigation */}
        {isSurucu && (
          <>
            <div className="sidebar-section-title">Süt Toplama</div>
            <NavLink to="/surucu" end className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiHome /></span>
              Ana Sayfa
            </NavLink>
            <NavLink to="/surucu/toplama" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiDroplet /></span>
              Süt Al
            </NavLink>
            <NavLink to="/surucu/tanker" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiTruck /></span>
              Tanker Durumu
            </NavLink>
            <NavLink to="/surucu/gecmis" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiClipboard /></span>
              Geçmiş
            </NavLink>
          </>
        )}

        {/* Üretici Navigation */}
        {isUretici && (
          <>
            <div className="sidebar-section-title">Süt Geçmişim</div>
            <NavLink to="/uretici" end className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiHome /></span>
              Ana Sayfa
            </NavLink>
            <NavLink to="/uretici/gecmis" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
              <span className="nav-icon"><FiClipboard /></span>
              Teslim Geçmişi
            </NavLink>
          </>
        )}
      </nav>

      {/* Footer - User Info & Logout */}
      <div className="sidebar-footer">
        <div className="sidebar-user">
          <div className="sidebar-user-avatar">
            {getInitials(user?.displayName)}
          </div>
          <div className="sidebar-user-info">
            <div className="sidebar-user-name">{user?.displayName}</div>
            <div className="sidebar-user-role">{getRoleName(user?.role)}</div>
          </div>
          <button className="btn btn-ghost btn-sm" onClick={handleLogout} title="Çıkış Yap">
            <FiLogOut />
          </button>
        </div>
      </div>
    </aside>
  );
}
