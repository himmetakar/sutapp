import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/register_screen.dart';
import '../screens/shell/app_shell.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/admin/admin_firmalar.dart';
import '../screens/firma/firma_home.dart';
import '../screens/firma/firma_dashboard.dart';
import '../screens/firma/firma_profil.dart';
import '../screens/firma/firma_ureticiler.dart';
import '../screens/firma/firma_araclar.dart';
import '../screens/firma/firma_suruculer.dart';
import '../screens/firma/firma_personel_yonetimi.dart';
import '../screens/firma/firma_personel_ekle.dart';
import '../screens/firma/firma_personel_listesi.dart';
import '../screens/firma/firma_personel_performans.dart';
import '../screens/firma/firma_personel_acik_fazla.dart';
import '../screens/firma/firma_arac_ekle.dart';
import '../screens/firma/firma_arac_listesi.dart';
import '../screens/firma/firma_arac_giderleri.dart';
import '../screens/firma/firma_arac_atama.dart';
import '../screens/firma/firma_tanklar.dart';
import '../screens/firma/firma_toplamalar.dart';
import '../screens/firma/firma_teslimatlar.dart';
import '../screens/firma/firma_raporlar.dart';
import '../screens/firma/firma_fire_takip.dart';
import '../screens/firma/finans_screens.dart';
import '../screens/firma/sut_fiyat_ekranlari.dart';
import '../screens/firma/avans_ekranlari.dart';
import '../screens/firma/ceza_ekranlari.dart';
import '../screens/firma/kesinti_ekranlari.dart';
import '../screens/firma/satis_raporlari_screen.dart';
import '../screens/firma/gelirler_screen.dart';
import '../screens/firma/urunler_screen.dart';
import '../screens/firma/urun_siparisleri_screen.dart';
import '../screens/surucu/surucu_dashboard.dart';
import '../screens/surucu/surucu_profil.dart';
import '../screens/surucu/surucu_teslimatlar.dart';
import '../screens/uretici/uretici_dashboard.dart';
import '../screens/uretici/uretici_faturalar.dart';
import '../screens/uretici/uretici_profil.dart';
import '../screens/auth/duyuru_gonder_screens.dart';
import '../screens/firma/sut_odemeleri_screen.dart';
import '../screens/firma/firma_gruplar.dart';
import '../screens/firma/firma_birlikler.dart';
import '../screens/firma/firma_atamalar.dart';
import '../screens/firma/firma_satislar.dart';
import '../screens/firma/firma_hesap_ozeti.dart';
import '../screens/firma/firma_aylik_sut.dart';
import '../screens/firma/firma_ureticiler_list.dart';
import '../screens/firma/firma_tahsilat.dart';
import '../screens/firma/tank_listesi_screen.dart';
import '../screens/firma/tank_ekle_screen.dart';
import '../screens/firma/tank_detay_screen.dart';
import '../screens/firma/sut_kabul_screen.dart';
import '../screens/firma/sut_transfer_screen.dart';
import '../screens/firma/sut_analiz_screen.dart';
import '../screens/firma/firma_tank_atama.dart';
import '../screens/firma/firma_yonetimi_screen.dart';
import '../screens/firma/firma_firmalar_screen.dart';
import '../screens/uretici/dijital_sut_karti.dart';



GoRouter createRouter(AuthProvider auth) {
  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth.isLoggedIn;
      final needsRegistration = auth.needsRegistration;
      final loggingIn = state.matchedLocation == '/login';
      final registering = state.matchedLocation == '/register';

      if (needsRegistration) {
        if (registering) return null;
        return '/register';
      }

      if (!loggedIn && !loggingIn) {
        if (registering) return '/login';
        return '/login';
      }

      if (loggedIn && (loggingIn || registering)) {
        switch (auth.user!.role) {
          case UserRole.admin: return '/admin';
          case UserRole.firma: return '/firma';
          case UserRole.surucu: return '/surucu';
          case UserRole.uretici: return '/uretici';
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

      // Admin
      ShellRoute(
        builder: (_, state, child) => AppShell(role: UserRole.admin, child: child),
        routes: [
          GoRoute(path: '/admin', builder: (_, __) => const AdminDashboard()),
          GoRoute(path: '/admin/duyuru-gonder', builder: (_, __) => const AdminDuyuruGonderScreen()),
          GoRoute(path: '/admin/firmalar', builder: (_, __) => const AdminFirmalar()),
          GoRoute(path: '/admin/abonelikler', builder: (_, __) => const AdminFirmalar()),
          GoRoute(path: '/admin/istatistikler', builder: (_, __) => const AdminDashboard()),
          GoRoute(path: '/admin/aylik-sut', builder: (_, __) => const FirmaAylikSutScreen()),
          GoRoute(
            path: '/admin/dijital-kart',
            builder: (context, state) {
              final name = state.uri.queryParameters['name'];
              return DijitalSutKartiScreen(producerName: name);
            },
          ),
        ],
      ),

      // Firma
      ShellRoute(
        builder: (_, state, child) => AppShell(role: UserRole.firma, child: child),
        routes: [
          GoRoute(path: '/firma', builder: (_, __) => const FirmaHomeScreen()),
          GoRoute(path: '/firma/duyuru-gonder', builder: (_, __) => const FirmaDuyuruGonderScreen()),
          GoRoute(path: '/firma/dashboard', builder: (_, __) => const FirmaDashboard()),
          GoRoute(path: '/firma/profil', builder: (_, __) => const FirmaProfilScreen()),
          GoRoute(path: '/firma/ureticiler', builder: (_, __) => const FirmaUreticiler()),
          GoRoute(
            path: '/firma/ureticiler/liste',
            builder: (context, state) {
              final group = state.uri.queryParameters['group'];
              final birlik = state.uri.queryParameters['birlik'];
              final bolge = state.uri.queryParameters['bolge'];
              return FirmaUreticiListesiScreen(groupFilter: group, birlikFilter: birlik, bolgeFilter: bolge);
            },
          ),
          GoRoute(path: '/firma/tahsilat', builder: (_, __) => const FirmaTahsilatScreen()),
          GoRoute(path: '/firma/gruplar', builder: (_, __) => const FirmaGruplarScreen()),
          GoRoute(path: '/firma/birlikler', builder: (_, __) => const FirmaBirliklerScreen()),
          GoRoute(path: '/firma/atamalar', builder: (_, __) => const FirmaAtamalarScreen()),
          GoRoute(path: '/firma/satislar', builder: (_, __) => const FirmaSatislarScreen()),
          GoRoute(
            path: '/firma/hesap-ozeti',
            builder: (context, state) {
              final name = state.uri.queryParameters['name'];
              return FirmaHesapOzetiScreen(producerName: name);
            },
          ),
          GoRoute(path: '/firma/aylik-sut', builder: (_, __) => const FirmaAylikSutScreen()),
          GoRoute(
            path: '/firma/dijital-kart',
            builder: (context, state) {
              final name = state.uri.queryParameters['name'];
              return DijitalSutKartiScreen(producerName: name);
            },
          ),
          GoRoute(path: '/firma/yonetimi', builder: (_, __) => const FirmaYonetimiScreen()),
          GoRoute(path: '/firma/firmalar', builder: (_, __) => const FirmaFirmalarScreen()),
          GoRoute(
            path: '/firma/yonetimi/ekstre',
            builder: (context, state) {
              final name = state.uri.queryParameters['name'];
              return FirmaCariEkstreScreen(companyName: name);
            },
          ),
          GoRoute(path: '/firma/araclar', builder: (_, __) => const FirmaAraclar()),
          GoRoute(path: '/firma/suruculer', builder: (_, __) => const FirmaSuruculer()),
          GoRoute(path: '/firma/personel', builder: (_, __) => const FirmaPersonelYonetimiScreen()),
          GoRoute(path: '/firma/personel/ekle', builder: (_, __) => const FirmaPersonelEkleScreen()),
          GoRoute(path: '/firma/personel/liste', builder: (_, __) => const FirmaPersonelListesiScreen()),
          GoRoute(path: '/firma/personel/performans', builder: (_, __) => const FirmaPersonelPerformansScreen()),
          GoRoute(path: '/firma/personel/acik-fazla', builder: (_, __) => const FirmaPersonelAcikFazlaScreen()),
          GoRoute(path: '/firma/araclar/ekle', builder: (_, __) => const FirmaAracEkleScreen()),
          GoRoute(path: '/firma/araclar/liste', builder: (_, __) => const FirmaAracListesiScreen()),
          GoRoute(path: '/firma/araclar/giderler', builder: (_, __) => const FirmaAracGiderleriScreen()),
          GoRoute(path: '/firma/araclar/atama', builder: (_, __) => const FirmaAracAtamaScreen()),
          GoRoute(path: '/firma/tanklar', builder: (_, __) => const FirmaTanklar()),
          GoRoute(path: '/firma/tanklar/liste', builder: (_, __) => const TankListesiScreen()),
          GoRoute(path: '/firma/tanklar/ekle', builder: (_, __) => const TankEkleScreen()),
          GoRoute(path: '/firma/tanklar/detay', builder: (_, __) => const TankDetayScreen()),
          GoRoute(path: '/firma/tanklar/atama', builder: (_, __) => const FirmaTankAtamaScreen()),
          GoRoute(path: '/firma/sut-kabul', builder: (_, __) => const SutKabulScreen()),
          GoRoute(
            path: '/firma/sut-transferleri',
            builder: (context, state) {
              final action = state.uri.queryParameters['action'];
              return SutTransferScreen(action: action);
            },
          ),
          GoRoute(path: '/firma/sut-analiz', builder: (_, __) => const SutAnalizScreen()),
          GoRoute(path: '/firma/toplamalar', builder: (_, __) => const FirmaToplamalar()),
          GoRoute(path: '/firma/teslimatlar', builder: (_, __) => const FirmaTeslimatlar()),
          GoRoute(path: '/firma/raporlar', builder: (_, __) => const FirmaRaporlar()),
          GoRoute(path: '/firma/fire-takip', builder: (_, __) => const FirmaFireTakip()),
          GoRoute(path: '/firma/satis-raporlari', builder: (_, __) => const SatisRaporlariScreen()),
          GoRoute(path: '/firma/urunler', builder: (_, __) => const UrunlerScreen()),
          GoRoute(path: '/firma/urunler/siparisler', builder: (_, __) => const UrunSiparisleriScreen()),
          GoRoute(path: '/firma/finans', builder: (_, __) => const FinansYonetimiScreen()),
          GoRoute(path: '/firma/finans/genel-bakis', builder: (_, __) => const FinansalGenelBakisScreen()),
          GoRoute(path: '/firma/finans/faturalar', builder: (_, __) => const FaturalarScreen()),
          GoRoute(path: '/firma/finans/faturalar/ekle', builder: (_, __) => const FaturaEkleScreen()),
          GoRoute(path: '/firma/finans/giderler', builder: (_, __) => const GiderYonetimiScreen()),
          GoRoute(
            path: '/firma/finans/giderler/detay/:kategori',
            builder: (context, state) {
              final kategori = state.pathParameters['kategori'] ?? 'genel';
              return GiderKategoriDetayScreen(kategori: kategori);
            },
          ),
          GoRoute(path: '/firma/finans/sut-fiyatlari', builder: (_, __) => const MusteriFiyatAyarlariScreen()),
          GoRoute(path: '/firma/finans/sut-fiyatlari/toplu', builder: (_, __) => const TopluIslemlerScreen()),
          GoRoute(path: '/firma/finans/gelirler', builder: (_, __) => const GelirlerScreen()),
          GoRoute(path: '/firma/finans/avanslar', builder: (_, __) => const MusteriAvanslariScreen()),
          GoRoute(path: '/firma/finans/avanslar/ekle', builder: (_, __) => const AvansVerScreen()),
          GoRoute(path: '/firma/finans/devir', builder: (_, __) => const DevirYonetimiScreen()),
          GoRoute(path: '/firma/finans/sut-odemeleri', builder: (_, __) => const SutOdemeleriScreen()),
          GoRoute(path: '/firma/finans/odeme-gecmisi', builder: (_, __) => const OdemeGecmisiScreen()),
          GoRoute(path: '/firma/finans/cezalar', builder: (_, __) => const MusteriCezalariScreen()),
          GoRoute(path: '/firma/finans/cezalar/ekle', builder: (_, __) => const CezaKesScreen()),
          GoRoute(path: '/firma/finans/kesintiler', builder: (_, __) => const MusteriKesintileriScreen(initialTab: 0)),
          GoRoute(path: '/firma/finans/oranlar', builder: (_, __) => const MusteriKesintileriScreen(initialTab: 1)),
        ],
      ),

      // Toplayıcı
      ShellRoute(
        builder: (_, state, child) => AppShell(role: UserRole.surucu, child: child),
        routes: [
          GoRoute(path: '/surucu', builder: (_, __) => const SurucuDashboard()),
          GoRoute(path: '/surucu/toplama', builder: (_, __) => const SurucuDashboard(showSutAlDirectly: true)),
          GoRoute(path: '/surucu/teslimatlar', builder: (_, __) => const SurucuTeslimatlarScreen()),
          GoRoute(path: '/surucu/profil', builder: (_, __) => const SurucuProfilScreen()),
        ],
      ),

      // Üretici
      ShellRoute(
        builder: (_, state, child) => AppShell(role: UserRole.uretici, child: child),
        routes: [
          GoRoute(path: '/uretici', builder: (_, __) => const UreticiDashboard()),
          GoRoute(path: '/uretici/gecmis', builder: (_, __) => const UreticiDashboard()),
          GoRoute(path: '/uretici/faturalar', builder: (_, __) => const UreticiFaturalarScreen()),
          GoRoute(path: '/uretici/urunler', builder: (_, __) => const UrunlerScreen()),
          GoRoute(
            path: '/uretici/dijital-kart',
            builder: (context, state) {
              final name = state.uri.queryParameters['name'];
              return DijitalSutKartiScreen(producerName: name);
            },
          ),
          GoRoute(
            path: '/uretici/hesap-ozeti',
            builder: (context, state) {
              final producerName = auth.user?.displayName;
              return FirmaHesapOzetiScreen(
                producerName: producerName,
                isUreticiView: true,
              );
            },
          ),
          GoRoute(path: '/uretici/profil', builder: (_, __) => const UreticiProfilScreen()),
        ],
      ),
    ],
  );
}
