import { createContext, useContext, useState, useEffect } from 'react';
import { onAuthStateChanged, signInWithPhoneNumber, RecaptchaVerifier } from 'firebase/auth';
import { auth } from '../firebase/config';
import { getUserData, loginUser, logoutUser, createUserProfile } from '../firebase/firestore';

const AuthContext = createContext(null);

// Demo kullanıcıları (Firebase Auth olmadan test için)
const DEMO_USERS = {
  admin: {
    uid: 'demo-admin-001',
    email: 'admin@sutapp.com',
    displayName: 'Sistem Admin',
    role: 'admin',
    firmaId: null
  },
  firma: {
    uid: 'demo-firma-001',
    email: 'firma@sutapp.com',
    displayName: 'Demo Süt A.Ş.',
    role: 'firma',
    firmaId: 'demo-firma-id'
  },
  surucu: {
    uid: 'demo-surucu-001',
    email: 'surucu@sutapp.com',
    displayName: 'Ahmet Sürücü',
    role: 'surucu',
    firmaId: 'demo-firma-id'
  },
  uretici: {
    uid: 'demo-uretici-001',
    email: 'uretici@sutapp.com',
    displayName: 'Mehmet Üretici',
    role: 'uretici',
    firmaId: 'demo-firma-id'
  }
};

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);
  const [needsRegistration, setNeedsRegistration] = useState(false);
  const [verifiedPhone, setVerifiedPhone] = useState(null);

  useEffect(() => {
    // Sayfa yüklendiğinde localStorage'dan demo user kontrol et
    const savedDemo = localStorage.getItem('sutapp_demo_user');
    if (savedDemo) {
      try {
        setUser(JSON.parse(savedDemo));
      } catch (e) {
        localStorage.removeItem('sutapp_demo_user');
      }
      setLoading(false);
      return;
    }

    // Firebase Auth listener
    const unsubscribe = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        try {
          const userData = await getUserData(firebaseUser.uid);
          if (userData) {
            setUser(userData);
            setNeedsRegistration(false);
            setVerifiedPhone(null);
          } else {
            setUser(null);
            setNeedsRegistration(true);
            setVerifiedPhone(firebaseUser.phoneNumber || null);
          }
        } catch (err) {
          console.error('User data fetch error:', err);
          setUser(null);
          setNeedsRegistration(false);
        }
      } else {
        setUser(null);
        setNeedsRegistration(false);
        setVerifiedPhone(null);
      }
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const login = async (email, password) => {
    setLoading(true);
    try {
      const userData = await loginUser(email, password);
      setUser(userData);
    } finally {
      setLoading(false);
    }
  };

  const verifyPhone = async (phoneNumber, recaptchaContainerId) => {
    setLoading(true);
    try {
      if (window.recaptchaVerifier) {
        window.recaptchaVerifier.clear();
      }
      window.recaptchaVerifier = new RecaptchaVerifier(auth, recaptchaContainerId, {
        size: 'invisible',
        callback: () => {
          // reCAPTCHA solved
        },
        'expired-callback': () => {
          // reCAPTCHA expired
        }
      });

      const confirmationResult = await signInWithPhoneNumber(auth, phoneNumber, window.recaptchaVerifier);
      window.confirmationResult = confirmationResult;
      return confirmationResult;
    } finally {
      setLoading(false);
    }
  };

  const confirmCode = async (code) => {
    setLoading(true);
    try {
      if (!window.confirmationResult) {
        throw new Error('Doğrulama işlemi başlatılmadı.');
      }
      const result = await window.confirmationResult.confirm(code);
      return result.user;
    } finally {
      setLoading(false);
    }
  };

  const registerPhoneUser = async (registrationData) => {
    const firebaseUser = auth.currentUser;
    if (!firebaseUser) {
      throw new Error('Kullanıcı oturumu bulunamadı.');
    }

    setLoading(true);
    try {
      const fullData = {
        ...registrationData,
        phone: firebaseUser.phoneNumber || verifiedPhone || '',
        role: 'uretici', // Default role is uretici
      };

      await createUserProfile(firebaseUser.uid, fullData);

      setUser({
        uid: firebaseUser.uid,
        ...fullData
      });
      setNeedsRegistration(false);
      setVerifiedPhone(null);
    } finally {
      setLoading(false);
    }
  };

  const demoLogin = (role) => {
    const demoUser = DEMO_USERS[role];
    if (demoUser) {
      localStorage.setItem('sutapp_demo_user', JSON.stringify(demoUser));
      setUser(demoUser);
    }
  };

  const logout = async () => {
    localStorage.removeItem('sutapp_demo_user');
    try {
      await logoutUser();
    } catch (e) {
      // Demo user, firebase'de değilse hata vermesini engelle
    }
    setUser(null);
    setNeedsRegistration(false);
    setVerifiedPhone(null);
  };

  const value = {
    user,
    loading,
    needsRegistration,
    verifiedPhone,
    login,
    verifyPhone,
    confirmCode,
    registerPhoneUser,
    demoLogin,
    logout,
    isAdmin: user?.role === 'admin',
    isFirma: user?.role === 'firma',
    isSurucu: user?.role === 'surucu',
    isUretici: user?.role === 'uretici'
  };

  return (
    <AuthContext.Provider value={value}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
