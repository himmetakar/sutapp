import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';
import '../../widgets/quick_actions_dialogs.dart';
import '../../widgets/notification_dialogs.dart';
import '../../services/firestore_service.dart';

class AppShell extends StatefulWidget {
  final UserRole role;
  final Widget child;
  const AppShell({super.key, required this.role, required this.child});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;
  bool _sidebarExpanded = true;

  List<_TabItem> get _tabs {
    switch (widget.role) {
      case UserRole.admin:
        return [
          _TabItem('/admin', Icons.dashboard_rounded, 'Ana Sayfa'),
          _TabItem('/admin/firmalar', Icons.business_rounded, 'Firmalar'),
          _TabItem('/admin/abonelikler', Icons.credit_card_rounded, 'Abonelik'),
          _TabItem('/admin/istatistikler', Icons.bar_chart_rounded, 'İstatistik'),
        ];
      case UserRole.firma:
        return [
          _TabItem('/firma', Icons.home_rounded, 'Ana Sayfa'),
          _TabItem('/firma/dashboard', Icons.speed_rounded, 'Gösterge Paneli'),
          _TabItem('/firma/profil', Icons.person_rounded, 'Profil'),
        ];
      case UserRole.surucu:
        return [
          _TabItem('/surucu', Icons.dashboard_rounded, 'Ana Sayfa'),
          _TabItem('/surucu/toplama', Icons.water_drop_rounded, 'Süt Al'),
          _TabItem('/surucu/teslimatlar', Icons.local_shipping_rounded, 'Teslimatlar'),
          _TabItem('/surucu/profil', Icons.person_rounded, 'Profil'),
        ];
      case UserRole.uretici:
        return [
          _TabItem('/uretici', Icons.dashboard_rounded, 'Ana Sayfa'),
          _TabItem('/uretici/profil', Icons.person_rounded, 'Profil'),
        ];
    }
  }

  List<_DrawerItem> get _drawerItems {
    switch (widget.role) {
      case UserRole.admin:
        return [
          _DrawerItem('/admin', Icons.dashboard_rounded, 'Dashboard'),
          _DrawerItem('/admin/firmalar', Icons.business_rounded, 'Firmalar'),
          _DrawerItem('/admin/aylik-sut', Icons.calendar_month_rounded, 'Aylık Süt Kayıtları'),
          _DrawerItem('/admin/duyuru-gonder', Icons.campaign_rounded, 'Duyuru Gönder'),
        ];
      case UserRole.firma:
        return [
          _DrawerItem('/firma', Icons.dashboard_rounded, 'Dashboard'),
          _DrawerItem('/firma/ureticiler', Icons.people_rounded, 'Üreticiler'),
          _DrawerItem('/firma/araclar', Icons.local_shipping_rounded, 'Araçlar'),
          _DrawerItem('/firma/suruculer', Icons.badge_rounded, 'Toplayıcılar'),
          _DrawerItem('/firma/tanklar', Icons.propane_tank_rounded, 'Tanklar'),
          _DrawerItem('/firma/tanklar/atama', Icons.link_rounded, 'Tank Atama'),
          _DrawerItem('/firma/toplamalar', Icons.water_drop_rounded, 'Süt Toplamalar'),
          _DrawerItem('/firma/aylik-sut', Icons.calendar_month_rounded, 'Aylık Süt Kayıtları'),
          _DrawerItem('/firma/teslimatlar', Icons.inventory_rounded, 'Merkez Teslimat'),
          _DrawerItem('/firma/raporlar', Icons.bar_chart_rounded, 'Raporlar'),
          _DrawerItem('/firma/fire-takip', Icons.warning_amber_rounded, 'Fire Takibi'),
          _DrawerItem('/firma/duyuru-gonder', Icons.campaign_rounded, 'Duyuru Gönder'),
          _DrawerItem('/firma/finans', Icons.monetization_on_rounded, 'Finans Yönetimi'),
          _DrawerItem('/firma/firmalar', Icons.business_rounded, 'Tedarikçi Firmalar'),
          _DrawerItem('/firma/satis-raporlari', Icons.analytics_rounded, 'Satış Raporları'),
          _DrawerItem('/firma/urunler', Icons.shopping_bag_rounded, 'Ürünler'),
          _DrawerItem('/firma/urunler/siparisler', Icons.shopping_cart_rounded, 'Siparişler'),
        ];
      case UserRole.surucu:
        return [
          _DrawerItem('/surucu', Icons.dashboard_rounded, 'Dashboard'),
          _DrawerItem('/surucu/toplama', Icons.water_drop_rounded, 'Süt Al'),
          _DrawerItem('/surucu/teslimatlar', Icons.local_shipping_rounded, 'Ürün Teslimatları'),
          _DrawerItem('/surucu/profil', Icons.person_rounded, 'Profil'),
        ];
      case UserRole.uretici:
        return [
          _DrawerItem('/uretici', Icons.dashboard_rounded, 'Dashboard'),
          _DrawerItem('/uretici/dijital-kart', Icons.badge_rounded, 'Dijital Süt Kartı'),
          _DrawerItem('/uretici/gecmis', Icons.history_rounded, 'Geçmiş'),
          _DrawerItem('/uretici/faturalar', Icons.description_rounded, 'Faturalarım'),
          _DrawerItem('/uretici/urunler', Icons.shopping_bag_rounded, 'Ürünler'),
          _DrawerItem('/uretici/profil', Icons.person_rounded, 'Profil'),
        ];
    }
  }

  String get _title {
    final loc = GoRouterState.of(context).matchedLocation;
    final titles = {
      '/admin': 'Dashboard',
      '/admin/firmalar': 'Firmalar',
      '/admin/abonelikler': 'Abonelikler',
      '/admin/istatistikler': 'İstatistikler',
      '/admin/aylik-sut': 'Aylık Süt Kayıtları',
      '/admin/dijital-kart': 'Dijital Süt Kartı',
      '/firma': 'Ana Sayfa',
      '/firma/dashboard': 'Gösterge Paneli',
      '/firma/profil': 'Profil',
      '/firma/ureticiler': 'Üreticiler',
      '/firma/araclar': 'Araçlar',
      '/firma/suruculer': 'Toplayıcılar',
      '/firma/tanklar': 'Tanklar',
      '/firma/tanklar/liste': 'Tank Listesi',
      '/firma/tanklar/ekle': 'Yeni Tank Ekle',
      '/firma/tanklar/detay': 'Tank İçerik Detayı',
      '/firma/tanklar/atama': 'Tank Atama',
      '/firma/sut-kabul': 'Süt Kabul',
      '/firma/sut-transferleri': 'Süt Transferleri',
      '/firma/sut-analiz': 'Analiz Raporları',
      '/firma/toplamalar': 'Süt Toplamalar',
      '/firma/aylik-sut': 'Aylık Süt Kayıtları',
      '/firma/dijital-kart': 'Dijital Süt Kartı',
      '/firma/teslimatlar': 'Merkez Teslimat',
      '/firma/raporlar': 'Raporlar',
      '/firma/fire-takip': 'Fire Takibi',
      '/firma/duyuru-gonder': 'Duyuru Gönder',
      '/admin/duyuru-gonder': 'Duyuru Gönder',
      '/firma/finans': 'Finans Yönetimi',
      '/firma/yonetimi': 'Firma Yönetimi',
      '/firma/firmalar': 'Tedarikçi Firmalar',
      '/firma/yonetimi/ekstre': 'Cari Hesap Ekstresi',
      '/firma/finans/genel-bakis': 'Finansal Genel Bakış',
      '/firma/finans/faturalar': 'Faturalar',
      '/firma/finans/faturalar/ekle': 'Fatura Ekle',
      '/firma/finans/giderler': 'Gider Yönetimi',
      '/firma/finans/gelirler': 'Gelirler',
      '/firma/finans/avanslar': 'Üretici Avansları',
      '/firma/finans/avanslar/ekle': 'Avans Ver',
      '/firma/finans/devir': 'Devir İşlemleri',
      '/firma/finans/sut-odemeleri': 'Süt Ödemeleri',
      '/firma/finans/odeme-gecmisi': 'Ödeme Geçmişi',
      '/firma/finans/cezalar': 'Üretici Cezaları',
      '/firma/finans/cezalar/ekle': 'Ceza Kes',
      '/firma/finans/kesintiler': 'Kesintiler',
      '/firma/finans/sut-fiyatlari': 'Süt Fiyat Ayarları',
      '/firma/finans/sut-fiyatlari/toplu': 'Toplu Fiyat İşlemleri',
      '/surucu': 'Ana Sayfa',
      '/surucu/toplama': 'Süt Toplama',
      '/surucu/teslimatlar': 'Sipariş Teslimatları',
      '/surucu/profil': 'Profil',
      '/uretici': 'Ana Sayfa',
      '/uretici/gecmis': 'Teslim Geçmişi',
      '/uretici/faturalar': 'Faturalarım',
      '/uretici/profil': 'Profil',
      '/firma/urunler': 'Ürünler',
      '/firma/urunler/siparisler': 'Siparişler',
      '/uretici/urunler': 'Ürünler',
      '/uretici/dijital-kart': 'Dijital Süt Kartı',
    };
    return titles[loc] ?? 'SütApp';
  }

  void _onTabTapped(int index) {
    setState(() => _currentIndex = index);
    context.go(_tabs[index].path);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final loc = GoRouterState.of(context).matchedLocation;
    final idx = _tabs.indexWhere((t) => t.path == loc);
    if (idx != -1 && idx != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currentIndex = idx);
      });
    }

    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 1024;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.gray50,
        body: Row(
          children: [
            _buildWebSidebar(auth, loc),
            Expanded(
              child: Column(
                children: [
                  _buildWebAppBar(auth),
                  Expanded(
                    child: SelectionArea(
                      child: widget.child,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(_title),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                children: const [
                  TextSpan(text: 'Süt', style: TextStyle(color: AppColors.primary600)),
                  TextSpan(text: 'App', style: TextStyle(color: AppColors.gray800)),
                ],
              ),
            ),
          ),
          _buildNotificationsBellButton(auth, context),
          _buildUserMenuButton(auth),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _drawerItems.isNotEmpty ? _buildDrawer(auth, loc) : null,
      body: widget.child,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // Web Sidebar
  Widget _buildWebSidebar(AuthProvider auth, String loc) {
    final panelName = widget.role == UserRole.admin
        ? 'Yönetici Paneli'
        : widget.role == UserRole.firma
            ? 'Firma Paneli'
            : widget.role == UserRole.surucu
                ? 'Toplayıcı Paneli'
                : 'Üretici Paneli';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: _sidebarExpanded ? 260 : 70,
      color: const Color(0xFF0B192C), // Premium deep dark slate/navy
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo Area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary500,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.water_drop_rounded, color: Colors.white, size: 20),
                ),
                if (_sidebarExpanded) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'SütApp',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          panelName,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.gray400,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Menu Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              children: [
                ..._drawerItems.map((item) {
                  final isActive = loc == item.path;
                  return Tooltip(
                    message: _sidebarExpanded ? '' : item.label,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      child: Material(
                        color: isActive ? const Color(0xFF1E293B) : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => context.go(item.path),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: _sidebarExpanded ? 12 : 10,
                              vertical: 10,
                            ),
                            child: Row(
                              mainAxisAlignment: _sidebarExpanded
                                  ? MainAxisAlignment.start
                                  : MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item.icon,
                                  color: isActive ? Colors.white : AppColors.gray400,
                                  size: 18,
                                ),
                                if (_sidebarExpanded) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.label,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                        color: isActive ? Colors.white : AppColors.gray300,
                                      ),
                                    ),
                                  ),
                                  if (isActive)
                                    Container(
                                      width: 4,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary500,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (_sidebarExpanded && widget.role == UserRole.firma) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Hızlı İşlemler',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildQuickActionButton('+ Süt Girişi Yap', Icons.add_rounded, () {
                    QuickActionsDialogs.showSutGirisiDialog(context);
                  }),
                  _buildQuickActionButton('+ Süt Kabul', Icons.input_rounded, () {
                    QuickActionsDialogs.showSutKabulDialog(context);
                  }),
                  _buildQuickActionButton('+ Tahsilat Yap', Icons.monetization_on_rounded, () {
                    QuickActionsDialogs.showTahsilatDialog(context);
                  }),
                ],
              ],
            ),
          ),

          // Sidebar Toggle & Version
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Color(0xFF1E293B), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: _sidebarExpanded
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                if (_sidebarExpanded)
                  Text(
                    'Sürüm 1.0.0',
                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                  ),
                IconButton(
                  onPressed: () => setState(() => _sidebarExpanded = !_sidebarExpanded),
                  icon: Icon(
                    _sidebarExpanded ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
                    color: AppColors.gray400,
                    size: 18,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton(String label, IconData icon, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(icon, color: AppColors.primary400, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray300),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Web AppBar
  Widget _buildWebAppBar(AuthProvider auth) {
    final today = DateFormat('dd MMMM yyyy EEEE', 'tr_TR').format(DateTime.now());

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.gray200, width: 1)),
      ),
      child: Row(
        children: [
          // Collapsible/Breadcrumb Placeholder / Search Box
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 320,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gray200),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.gray400, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Modül, üretici veya işlem ara...',
                        style: GoogleFonts.inter(color: AppColors.gray400, fontSize: 12),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Text(
                        'Ctrl + K',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Date Picker/Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.gray50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.gray500),
                const SizedBox(width: 8),
                Text(
                  today,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.gray700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),

          // Notifications
          _buildNotificationsBellButton(auth, context),
          const SizedBox(width: 16),

          // Profile Info & Avatar
          _buildUserWebProfile(auth),
        ],
      ),
    );
  }

  Widget _buildUserWebProfile(AuthProvider auth) {
    return PopupMenuButton<String>(
      offset: const Offset(0, 45),
      onSelected: (val) {
        if (val == 'logout') {
          auth.logout();
          context.go('/login');
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                auth.user?.displayName ?? '',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gray800),
              ),
              Text(
                auth.user?.roleName ?? '',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
              ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
              const SizedBox(width: 8),
              Text('Çıkış Yap', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.danger)),
            ],
          ),
        ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CompanyLogoAvatar(
            companyName: auth.user?.displayName,
            size: 36,
            borderRadius: 18,
            fallbackText: auth.user?.displayName.isNotEmpty == true 
                ? auth.user!.displayName.substring(0, 1).toUpperCase() 
                : '?',
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                auth.user?.displayName ?? '',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray800),
              ),
              Text(
                auth.user?.roleName ?? '',
                style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
              ),
            ],
          ),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.gray500),
        ],
      ),
    );
  }

  // Mobile Drawer
  Widget _buildDrawer(AuthProvider auth, String loc) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(0))),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [AppColors.primary50, Color(0xFFF0F4FF)]),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CompanyLogoAvatar(
                    companyName: auth.user?.displayName,
                    size: 48,
                    borderRadius: 12,
                    fallbackText: auth.user?.displayName.isNotEmpty == true 
                        ? auth.user!.displayName.substring(0, 1).toUpperCase() 
                        : '?',
                  ),
                  const SizedBox(height: 12),
                  Text(auth.user?.displayName ?? '', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.gray800)),
                  const SizedBox(height: 2),
                  Text(auth.user?.roleName ?? '', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                ],
              ),
            ),
            // Nav Items
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                children: [
                  ..._drawerItems.map((item) {
                    final isActive = loc == item.path;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      child: Material(
                        color: isActive ? AppColors.primary50 : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.pop(context);
                            context.go(item.path);
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(children: [
                              Icon(item.icon, color: isActive ? AppColors.primary600 : AppColors.gray400, size: 20),
                              const SizedBox(width: 12),
                              Text(item.label, style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                                color: isActive ? AppColors.primary700 : AppColors.gray700,
                              )),
                              if (isActive) ...[
                                const Spacer(),
                                Container(width: 4, height: 16, decoration: BoxDecoration(color: AppColors.primary600, borderRadius: BorderRadius.circular(2))),
                              ],
                            ]),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  if (widget.role == UserRole.firma) ...[
                    const Divider(height: 24, thickness: 1, color: AppColors.gray100),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Text(
                        'Hızlı İşlemler',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildDrawerQuickActionBtn(
                      context,
                      label: 'Süt Girişi Yap',
                      icon: Icons.add_rounded,
                      color: AppColors.primary600,
                      bgColor: AppColors.primary50,
                      onTap: () {
                        Navigator.pop(context);
                        QuickActionsDialogs.showSutGirisiDialog(context);
                      },
                    ),
                    _buildDrawerQuickActionBtn(
                      context,
                      label: 'Süt Kabul',
                      icon: Icons.input_rounded,
                      color: const Color(0xFF7C3AED),
                      bgColor: const Color(0xFFEDE9FE),
                      onTap: () {
                        Navigator.pop(context);
                        QuickActionsDialogs.showSutKabulDialog(context);
                      },
                    ),
                    _buildDrawerQuickActionBtn(
                      context,
                      label: 'Tahsilat Yap',
                      icon: Icons.monetization_on_rounded,
                      color: Colors.teal,
                      bgColor: const Color(0xFFE6F4EA),
                      onTap: () {
                        Navigator.pop(context);
                        QuickActionsDialogs.showTahsilatDialog(context);
                      },
                    ),
                  ],
                ],
              ),
            ),
            // Logout
            Container(
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.gray100))),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    auth.logout();
                    context.go('/login');
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(color: AppColors.dangerLight, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.logout_rounded, size: 16, color: AppColors.danger),
                      ),
                      const SizedBox(width: 12),
                      Text('Çıkış Yap', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.danger)),
                    ]),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserMenuButton(AuthProvider auth) {
    final avatarChar = auth.user?.displayName.isNotEmpty == true 
        ? auth.user!.displayName.substring(0, 1).toUpperCase() 
        : 'F';

    if (widget.role == UserRole.firma) {
      return GestureDetector(
        onTap: () => context.go('/firma/profil'),
        child: CompanyLogoAvatar(
          companyName: auth.user?.displayName,
          size: 32,
          borderRadius: 8,
          fallbackText: avatarChar,
        ),
      );
    }

    return PopupMenuButton<String>(
      icon: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: AppColors.primary50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            avatarChar,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary600),
          ),
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      offset: const Offset(0, 45),
      onSelected: (val) {
        if (val == 'logout') {
          auth.logout();
          context.go('/login');
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<String>>[
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(auth.user?.displayName ?? '', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gray800)),
              Text(auth.user?.roleName ?? '', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(children: [
            const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            Text('Çıkış Yap', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.danger)),
          ]),
        ),
      ],
    );
  }

  // Mobile Bottom Navigation Bar
  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -2))],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _tabs.asMap().entries.map((e) {
              final i = e.key;
              final tab = e.value;
              final isActive = i == _currentIndex.clamp(0, _tabs.length - 1);
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabTapped(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: isActive ? 48 : 36,
                          height: isActive ? 30 : 28,
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.primary50 : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(tab.icon, size: isActive ? 20 : 19, color: isActive ? AppColors.primary600 : AppColors.gray400),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                            color: isActive ? AppColors.primary600 : AppColors.gray400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerQuickActionBtn(
    BuildContext context, {
    required String label,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsBellButton(AuthProvider auth, BuildContext context) {
    final uid = auth.user?.uid ?? '';
    final role = auth.user?.role ?? UserRole.uretici;
    if (uid.isEmpty) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().getNotificationsStream(uid),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final unreadCount = docs.where((doc) => (doc.data() as Map<String, dynamic>)['read'] == false).length;

        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: AppColors.gray600),
              onPressed: () => NotificationDrawerDialog.show(context, uid, role),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 14,
                    minHeight: 14,
                  ),
                  child: Center(
                    child: Text(
                      '$unreadCount',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _TabItem {
  final String path;
  final IconData icon;
  final String label;
  _TabItem(this.path, this.icon, this.label);
}

class _DrawerItem {
  final String path;
  final IconData icon;
  final String label;
  _DrawerItem(this.path, this.icon, this.label);
}

class CompanyLogoAvatar extends StatelessWidget {
  final String? companyName;
  final double size;
  final double borderRadius;
  final String fallbackText;

  const CompanyLogoAvatar({
    super.key,
    required this.companyName,
    required this.size,
    required this.borderRadius,
    required this.fallbackText,
  });

  @override
  Widget build(BuildContext context) {
    if (companyName == null || companyName!.isEmpty) {
      return _buildFallback();
    }
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('firmalar')
          .where('ad', isEqualTo: companyName)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        String? logoUrl;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final doc = snapshot.data!.docs.first;
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('logoUrl')) {
            logoUrl = data['logoUrl'] as String?;
          }
        }

        if (logoUrl != null && logoUrl.isNotEmpty) {
          ImageProvider provider;
          if (logoUrl.startsWith('data:image')) {
            final commaIndex = logoUrl.indexOf(',');
            if (commaIndex != -1) {
              final base64Part = logoUrl.substring(commaIndex + 1);
              try {
                provider = MemoryImage(base64Decode(base64Part));
              } catch (e) {
                provider = NetworkImage(logoUrl);
              }
            } else {
              provider = NetworkImage(logoUrl);
            }
          } else {
            provider = NetworkImage(logoUrl);
          }

          return Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              image: DecorationImage(
                image: provider,
                fit: BoxFit.cover,
              ),
            ),
          );
        }

        return _buildFallback();
      },
    );
  }

  Widget _buildFallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: Text(
          fallbackText,
          style: GoogleFonts.inter(
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
