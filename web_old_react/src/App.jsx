import { HashRouter, Routes, Route, Navigate } from 'react-router-dom';
import { AuthProvider, useAuth } from './contexts/AuthContext';
import { Capacitor } from '@capacitor/core';

// Layouts
import AppLayout from './components/layout/AppLayout';
import MobileLayout from './components/layout/MobileLayout';

// Auth
import LoginPage from './pages/auth/LoginPage';
import RegisterPage from './pages/auth/RegisterPage';

// Admin
import AdminDashboard from './pages/admin/AdminDashboard';
import AdminFirmalar from './pages/admin/AdminFirmalar';

// Firma
import FirmaHome from './pages/firma/FirmaHome';
import FirmaDashboard from './pages/firma/FirmaDashboard';
import FirmaProfil from './pages/firma/FirmaProfil';
import FirmaUreticiler from './pages/firma/FirmaUreticiler';
import FirmaAraclar from './pages/firma/FirmaAraclar';
import FirmaSuruculer from './pages/firma/FirmaSuruculer';
import FirmaTanklar from './pages/firma/FirmaTanklar';
import FirmaToplamalar from './pages/firma/FirmaToplamalar';
import FirmaTeslimatlar from './pages/firma/FirmaTeslimatlar';
import FirmaRaporlar from './pages/firma/FirmaRaporlar';
import FirmaFireTakip from './pages/firma/FirmaFireTakip';
import SatisRaporlari from './pages/firma/SatisRaporlari';

// Sürücü
import SurucuDashboard from './pages/surucu/SurucuDashboard';

// Üretici
import UreticiDashboard from './pages/uretici/UreticiDashboard';

// Detect if running inside Capacitor (native app) or as web
const isNative = Capacitor.isNativePlatform();

function ProtectedRoute({ children, allowedRoles }) {
  const { user, loading, needsRegistration } = useAuth();

  if (loading) {
    return (
      <div className="loading-page">
        <div className="spinner"></div>
        <div className="loading-text">Yükleniyor...</div>
      </div>
    );
  }

  if (needsRegistration) {
    return <Navigate to="/register" replace />;
  }

  if (!user) {
    return <Navigate to="/login" replace />;
  }

  if (allowedRoles && !allowedRoles.includes(user.role)) {
    const roleHome = {
      admin: '/admin',
      firma: '/firma',
      surucu: '/surucu',
      uretici: '/uretici'
    };
    return <Navigate to={roleHome[user.role] || '/login'} replace />;
  }

  return children;
}

function AppRoutes() {
  const { user, loading, needsRegistration } = useAuth();

  if (loading) {
    return (
      <div className="loading-page">
        <div className="spinner"></div>
        <div className="loading-text">SütApp yükleniyor...</div>
      </div>
    );
  }

  const getHomeRoute = () => {
    if (needsRegistration) return '/register';
    if (!user) return '/login';
    const map = { admin: '/admin', firma: '/firma', surucu: '/surucu', uretici: '/uretici' };
    return map[user.role] || '/login';
  };

  // Use MobileLayout when running as native app, AppLayout for web
  const Layout = isNative ? MobileLayout : AppLayout;

  return (
    <Routes>
      {/* Login */}
      <Route path="/login" element={user ? <Navigate to={getHomeRoute()} replace /> : <LoginPage />} />

      {/* Register */}
      <Route path="/register" element={
        needsRegistration 
          ? <RegisterPage /> 
          : (user ? <Navigate to={getHomeRoute()} replace /> : <Navigate to="/login" replace />)
      } />

      {/* Admin Routes */}
      <Route path="/admin" element={
        <ProtectedRoute allowedRoles={['admin']}>
          <Layout />
        </ProtectedRoute>
      }>
        <Route index element={<AdminDashboard />} />
        <Route path="firmalar" element={<AdminFirmalar />} />
        <Route path="abonelikler" element={<AdminFirmalar />} />
        <Route path="istatistikler" element={<AdminDashboard />} />
      </Route>

      {/* Firma Routes */}
      <Route path="/firma" element={
        <ProtectedRoute allowedRoles={['firma']}>
          <Layout />
        </ProtectedRoute>
      }>
        <Route index element={<FirmaHome />} />
        <Route path="dashboard" element={<FirmaDashboard />} />
        <Route path="profil" element={<FirmaProfil />} />
        <Route path="ureticiler" element={<FirmaUreticiler />} />
        <Route path="araclar" element={<FirmaAraclar />} />
        <Route path="suruculer" element={<FirmaSuruculer />} />
        <Route path="tanklar" element={<FirmaTanklar />} />
        <Route path="toplamalar" element={<FirmaToplamalar />} />
        <Route path="teslimatlar" element={<FirmaTeslimatlar />} />
        <Route path="raporlar" element={<FirmaRaporlar />} />
        <Route path="fire-takip" element={<FirmaFireTakip />} />
        <Route path="satis-raporlari" element={<SatisRaporlari />} />
      </Route>

      {/* Sürücü Routes */}
      <Route path="/surucu" element={
        <ProtectedRoute allowedRoles={['surucu']}>
          <Layout />
        </ProtectedRoute>
      }>
        <Route index element={<SurucuDashboard />} />
        <Route path="toplama" element={<SurucuDashboard />} />
        <Route path="tanker" element={<SurucuDashboard />} />
        <Route path="gecmis" element={<SurucuDashboard />} />
      </Route>

      {/* Üretici Routes */}
      <Route path="/uretici" element={
        <ProtectedRoute allowedRoles={['uretici']}>
          <Layout />
        </ProtectedRoute>
      }>
        <Route index element={<UreticiDashboard />} />
        <Route path="gecmis" element={<UreticiDashboard />} />
      </Route>

      {/* Default redirect */}
      <Route path="*" element={<Navigate to={getHomeRoute()} replace />} />
    </Routes>
  );
}

export default function App() {
  return (
    <HashRouter>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </HashRouter>
  );
}
