import { useNavigate } from 'react-router-dom';
import { useState } from 'react';
import {
  FiUsers, FiUserCheck, FiDroplet, FiPackage,
  FiTrendingUp, FiBriefcase, FiArrowLeft, FiTruck,
  FiBox, FiAlertTriangle
} from 'react-icons/fi';

export default function FirmaHome() {
  const navigate = useNavigate();
  const [currentMenu, setCurrentMenu] = useState('main'); // 'main', 'personel', 'sut_tank'

  // Submenu navigation handlers
  const handleMainCardClick = (target) => {
    if (target === 'personel' || target === 'sut_tank') {
      setCurrentMenu(target);
    } else {
      navigate(target);
    }
  };

  const handleBackClick = () => {
    setCurrentMenu('main');
  };

  return (
    <div className="fade-in">
      {currentMenu === 'main' && (
        <div className="modular-grid">
          {/* Müşteri Yönetimi */}
          <div className="modular-card" onClick={() => handleMainCardClick('/firma/ureticiler')}>
            <div className="modular-icon-wrapper blue">
              <FiUsers />
            </div>
            <h3 className="modular-card-title">Müşteri Yönetimi</h3>
            <p className="modular-card-subtitle">Müşteri işlemleri</p>
          </div>

          {/* Personel & Araç */}
          <div className="modular-card" onClick={() => handleMainCardClick('personel')}>
            <div className="modular-icon-wrapper green">
              <FiUserCheck />
            </div>
            <h3 className="modular-card-title">Personel & Araç</h3>
            <p className="modular-card-subtitle">Personel ve araç yönetimi</p>
          </div>

          {/* Süt ve Tank */}
          <div className="modular-card" onClick={() => handleMainCardClick('sut_tank')}>
            <div className="modular-icon-wrapper teal">
              <FiDroplet />
            </div>
            <h3 className="modular-card-title">Süt ve Tank</h3>
            <p className="modular-card-subtitle">Süt toplama ve tanklar</p>
          </div>

          {/* Ürün Yönetimi */}
          <div className="modular-card" onClick={() => handleMainCardClick('/firma/satis-raporlari')}>
            <div className="modular-icon-wrapper red">
              <FiPackage />
            </div>
            <h3 className="modular-card-title">Ürün Yönetimi</h3>
            <p className="modular-card-subtitle">Ürün ve stok takibi</p>
          </div>

          {/* Finans Yönetimi */}
          <div className="modular-card" onClick={() => handleMainCardClick('/firma/satis-raporlari')}>
            <div className="modular-icon-wrapper orange">
              <FiTrendingUp />
            </div>
            <h3 className="modular-card-title">Finans Yönetimi</h3>
            <p className="modular-card-subtitle">Gelir, gider ve faturalar</p>
          </div>

          {/* Firma Yönetimi */}
          <div className="modular-card" onClick={() => handleMainCardClick('/firma/profil')}>
            <div className="modular-icon-wrapper lightblue">
              <FiBriefcase />
            </div>
            <h3 className="modular-card-title">Firma Yönetimi</h3>
            <p className="modular-card-subtitle">Firma bilgileri</p>
          </div>
        </div>
      )}

      {currentMenu === 'personel' && (
        <div>
          <div className="submenu-header">
            <button className="submenu-back-btn" onClick={handleBackClick}>
              <FiArrowLeft />
            </button>
            <span className="submenu-title">Personel & Araç</span>
          </div>

          <div className="modular-grid">
            {/* Sürücü Yönetimi */}
            <div className="modular-card" onClick={() => navigate('/firma/suruculer')}>
              <div className="modular-icon-wrapper green">
                <FiUsers />
              </div>
              <h3 className="modular-card-title">Sürücü Yönetimi</h3>
              <p className="modular-card-subtitle">Sürücü işlemleri</p>
            </div>

            {/* Araç Yönetimi */}
            <div className="modular-card" onClick={() => navigate('/firma/araclar')}>
              <div className="modular-icon-wrapper green">
                <FiTruck />
              </div>
              <h3 className="modular-card-title">Araç Yönetimi</h3>
              <p className="modular-card-subtitle">Kamyon ve araçlar</p>
            </div>
          </div>
        </div>
      )}

      {currentMenu === 'sut_tank' && (
        <div>
          <div className="submenu-header">
            <button className="submenu-back-btn" onClick={handleBackClick}>
              <FiArrowLeft />
            </button>
            <span className="submenu-title">Süt ve Tank</span>
          </div>

          <div className="modular-grid">
            {/* Süt Toplamaları */}
            <div className="modular-card" onClick={() => navigate('/firma/toplamalar')}>
              <div className="modular-icon-wrapper teal">
                <FiDroplet />
              </div>
              <h3 className="modular-card-title">Süt Toplamaları</h3>
              <p className="modular-card-subtitle">Süt toplama geçmişi</p>
            </div>

            {/* Tank Yönetimi */}
            <div className="modular-card" onClick={() => navigate('/firma/tanklar')}>
              <div className="modular-icon-wrapper teal">
                <FiBox />
              </div>
              <h3 className="modular-card-title">Tank Yönetimi</h3>
              <p className="modular-card-subtitle">Tank durumları ve stok</p>
            </div>

            {/* Merkez Teslimat */}
            <div className="modular-card" onClick={() => navigate('/firma/teslimatlar')}>
              <div className="modular-icon-wrapper teal">
                <FiPackage />
              </div>
              <h3 className="modular-card-title">Merkez Teslimat</h3>
              <p className="modular-card-subtitle">Fabrikaya teslimatlar</p>
            </div>

            {/* Fire Takibi */}
            <div className="modular-card" onClick={() => navigate('/firma/fire-takip')}>
              <div className="modular-icon-wrapper teal">
                <FiAlertTriangle />
              </div>
              <h3 className="modular-card-title">Fire Takibi</h3>
              <p className="modular-card-subtitle">Fire oranları ve takibi</p>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
