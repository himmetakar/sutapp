import { Outlet, useLocation, NavLink } from 'react-router-dom';
import { useAuth } from '../../contexts/AuthContext';
import {
  FiHome, FiUsers, FiTruck, FiDroplet, FiPackage,
  FiBarChart2, FiClipboard, FiUser, FiBox, FiLogOut,
  FiMenu, FiX, FiTrendingUp, FiGauge
} from 'react-icons/fi';
import { useState } from 'react';

const pageTitles = {
  '/admin': 'Dashboard',
  '/admin/firmalar': 'Firmalar',
  '/admin/abonelikler': 'Abonelikler',
  '/admin/istatistikler': 'İstatistikler',
  '/firma': 'Ana Sayfa',
  '/firma/dashboard': 'Gösterge Paneli',
  '/firma/profil': 'Profil',
  '/firma/ureticiler': 'Üreticiler',
  '/firma/araclar': 'Araçlar',
  '/firma/suruculer': 'Sürücüler',
  '/firma/tanklar': 'Tanklar',
  '/firma/toplamalar': 'Süt Toplamalar',
  '/firma/teslimatlar': 'Merkez Teslimat',
  '/firma/raporlar': 'Raporlar',
  '/firma/fire-takip': 'Fire Takibi',
  '/firma/satis-raporlari': 'Satış Raporları',
  '/surucu': 'Ana Sayfa',
  '/surucu/toplama': 'Süt Toplama',
  '/surucu/tanker': 'Tanker Durumu',
  '/surucu/gecmis': 'Geçmiş',
  '/uretici': 'Ana Sayfa',
  '/uretici/gecmis': 'Teslim Geçmişi'
};

// Bottom tab config per role
const TAB_CONFIG = {
  admin: [
    { path: '/admin', icon: FiHome, label: 'Ana Sayfa' },
    { path: '/admin/firmalar', icon: FiUsers, label: 'Firmalar' },
    { path: '/admin/abonelikler', icon: FiBarChart2, label: 'Abonelik' },
    { path: '/admin/istatistikler', icon: FiClipboard, label: 'İstatistik' },
  ],
  firma: [
    { path: '/firma', icon: FiHome, label: 'Ana Sayfa' },
    { path: '/firma/dashboard', icon: FiGauge, label: 'Gösterge Paneli' },
    { path: '/firma/profil', icon: FiUser, label: 'Profil' },
  ],
  surucu: [
    { path: '/surucu', icon: FiHome, label: 'Ana Sayfa' },
    { path: '/surucu/toplama', icon: FiDroplet, label: 'Süt Al' },
    { path: '/surucu/tanker', icon: FiTruck, label: 'Tanker' },
    { path: '/surucu/gecmis', icon: FiClipboard, label: 'Geçmiş' },
  ],
  uretici: [
    { path: '/uretici', icon: FiHome, label: 'Ana Sayfa' },
    { path: '/uretici/gecmis', icon: FiClipboard, label: 'Geçmiş' },
  ]
};

// Extra menu items (accessed via hamburger for firma)
const EXTRA_MENU = {
  firma: [
    { path: '/firma/ureticiler', icon: FiUsers, label: 'Üreticiler' },
    { path: '/firma/araclar', icon: FiTruck, label: 'Araçlar' },
    { path: '/firma/suruculer', icon: FiUser, label: 'Sürücüler' },
    { path: '/firma/tanklar', icon: FiBox, label: 'Tanklar' },
    { path: '/firma/toplamalar', icon: FiDroplet, label: 'Süt Toplamalar' },
    { path: '/firma/teslimatlar', icon: FiPackage, label: 'Merkez Teslimat' },
    { path: '/firma/raporlar', icon: FiBarChart2, label: 'Raporlar' },
    { path: '/firma/fire-takip', icon: FiClipboard, label: 'Fire Takibi' },
    { path: '/firma/satis-raporlari', icon: FiTrendingUp, label: 'Satış Raporları' },
  ]
};

export default function MobileLayout() {
  const { user, logout } = useAuth();
  const location = useLocation();
  const [menuOpen, setMenuOpen] = useState(false);

  const role = user?.role || 'firma';
  const tabs = TAB_CONFIG[role] || [];
  const extraItems = EXTRA_MENU[role] || [];
  const pageTitle = pageTitles[location.pathname] || 'SütApp';

  const handleLogout = async () => {
    setMenuOpen(false);
    await logout();
  };

  return (
    <div className="mobile-layout">
      {/* Mobile Header */}
      <header className="mobile-header">
        <div className="mobile-header-left">
          {extraItems.length > 0 && (
            <button className="mobile-menu-btn" onClick={() => setMenuOpen(!menuOpen)}>
              {menuOpen ? <FiX size={22} /> : <FiMenu size={22} />}
            </button>
          )}
          <h1 className="mobile-header-title">{pageTitle}</h1>
        </div>
        <div className="mobile-header-logo">
          Süt<span>App</span>
        </div>
      </header>

      {/* Slide-over Menu (for extra items like Firma management pages) */}
      {menuOpen && (
        <>
          <div className="mobile-overlay" onClick={() => setMenuOpen(false)} />
          <div className="mobile-drawer">
            <div className="mobile-drawer-header">
              <div className="mobile-drawer-user">
                <div className="mobile-drawer-avatar">
                  {user?.displayName?.charAt(0) || '?'}
                </div>
                <div>
                  <div className="mobile-drawer-name">{user?.displayName}</div>
                  <div className="mobile-drawer-role">
                    {role === 'admin' ? 'Sistem Admini' : role === 'firma' ? 'Firma Yöneticisi' : role === 'surucu' ? 'Sürücü' : 'Üretici'}
                  </div>
                </div>
              </div>
            </div>

            <nav className="mobile-drawer-nav">
              {extraItems.map(item => (
                <NavLink
                  key={item.path}
                  to={item.path}
                  className={({ isActive }) => `mobile-drawer-item ${isActive ? 'active' : ''}`}
                  onClick={() => setMenuOpen(false)}
                >
                  <item.icon size={20} />
                  <span>{item.label}</span>
                </NavLink>
              ))}
            </nav>

            <div className="mobile-drawer-footer">
              <button className="mobile-drawer-item logout" onClick={handleLogout}>
                <FiLogOut size={20} />
                <span>Çıkış Yap</span>
              </button>
            </div>
          </div>
        </>
      )}

      {/* Page Content */}
      <main className="mobile-content">
        <Outlet />
      </main>

      {/* Bottom Tab Bar */}
      <nav className="mobile-tabs">
        {tabs.map(tab => (
          <NavLink
            key={tab.path}
            to={tab.path}
            end={tab.path === `/${role}` || tab.path === '/admin'}
            className={({ isActive }) => `mobile-tab ${isActive ? 'active' : ''}`}
          >
            <tab.icon size={20} />
            <span>{tab.label}</span>
          </NavLink>
        ))}
      </nav>
    </div>
  );
}
