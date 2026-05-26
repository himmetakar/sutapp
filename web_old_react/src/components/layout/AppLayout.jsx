import { Outlet, useLocation } from 'react-router-dom';
import Sidebar from './Sidebar';

const pageTitles = {
  '/admin': 'Dashboard',
  '/admin/firmalar': 'Firmalar',
  '/admin/abonelikler': 'Abonelik Yönetimi',
  '/admin/istatistikler': 'Sistem İstatistikleri',
  '/firma': 'Dashboard',
  '/firma/ureticiler': 'Üretici Yönetimi',
  '/firma/araclar': 'Araç Yönetimi',
  '/firma/suruculer': 'Sürücü Yönetimi',
  '/firma/tanklar': 'Tank Yönetimi',
  '/firma/toplamalar': 'Süt Toplama Kayıtları',
  '/firma/teslimatlar': 'Merkez Tanker Teslimatları',
  '/firma/raporlar': 'Raporlar & Grafikler',
  '/firma/fire-takip': 'Fire Takibi',
  '/surucu': 'Ana Sayfa',
  '/surucu/toplama': 'Süt Toplama',
  '/surucu/tanker': 'Tanker Durumu',
  '/surucu/gecmis': 'Toplama Geçmişi',
  '/uretici': 'Ana Sayfa',
  '/uretici/gecmis': 'Teslim Geçmişi'
};

export default function AppLayout() {
  const location = useLocation();
  const pageTitle = pageTitles[location.pathname] || 'SütApp';

  return (
    <div className="app-layout">
      <Sidebar />
      <main className="main-content">
        <header className="main-header">
          <h2>{pageTitle}</h2>
          <div className="main-header-actions">
            <span style={{ fontSize: '12px', color: 'var(--gray-400)' }}>
              {new Date().toLocaleDateString('tr-TR', {
                weekday: 'long',
                year: 'numeric',
                month: 'long',
                day: 'numeric'
              })}
            </span>
          </div>
        </header>
        <div className="page-content fade-in">
          <Outlet />
        </div>
      </main>
    </div>
  );
}
