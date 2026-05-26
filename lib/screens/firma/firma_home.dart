import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class FirmaHomeScreen extends StatefulWidget {
  const FirmaHomeScreen({super.key});

  @override
  State<FirmaHomeScreen> createState() => _FirmaHomeScreenState();
}

class _FirmaHomeScreenState extends State<FirmaHomeScreen> {
  String _currentMenu = 'main'; // 'main', 'personel', 'sut_tank'

  void _onCardTap(String target) {
    if (target == 'personel' || target == 'sut_tank' || target == 'firma_yonetimi') {
      setState(() {
        _currentMenu = target;
      });
    } else {
      context.push(target);
    }
  }

  void _onBackTap() {
    setState(() {
      _currentMenu = 'main';
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          children: [
            if (_currentMenu == 'main') ...[
              // Screen Description / Welcome Title
              Row(
                children: [
                  Text(
                    'Hoş geldiniz, ${user?.displayName ?? 'Yönetici'}',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gray900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '👋',
                    style: GoogleFonts.inter(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Yönetmek istediğiniz modülü seçin.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.gray500,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 20),

              // Modular Grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.0,
                children: [
                  // Üretici Yönetimi
                  _buildMenuCard(
                    icon: Icons.people_rounded,
                    title: 'Üretici Yönetimi',
                    subtitle: 'Üretici işlemleri',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF2563EB),
                    onTap: () => _onCardTap('/firma/ureticiler'),
                  ),

                  // Personel & Araç
                  _buildMenuCard(
                    icon: Icons.badge_rounded,
                    title: 'Personel & Araç',
                    subtitle: 'Personel ve araç',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF0F8B5A),
                    onTap: () => context.push('/firma/personel'),
                  ),

                  // Süt ve Tank
                  _buildMenuCard(
                    icon: Icons.water_drop_rounded,
                    title: 'Süt ve Tank',
                    subtitle: 'Süt toplama ve tanklar',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF008AAE),
                    onTap: () => _onCardTap('sut_tank'),
                  ),

                  // Ürün Yönetimi
                  _buildMenuCard(
                    icon: Icons.category_rounded,
                    title: 'Ürün Yönetimi',
                    subtitle: 'Ürün ve stok takibi',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFFD31616),
                    onTap: () => _onCardTap('/firma/urunler'),
                  ),

                  // Finans Yönetimi
                  _buildMenuCard(
                    icon: Icons.monetization_on_rounded,
                    title: 'Finans Yönetimi',
                    subtitle: 'Gelir, gider ve faturalar',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFFE05300),
                    onTap: () => _onCardTap('/firma/finans'),
                  ),

                  // Firma Yönetimi
                  _buildMenuCard(
                    icon: Icons.business_rounded,
                    title: 'Firma Yönetimi',
                    subtitle: 'Firma bilgileri ve duyuru',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF1D9BF0),
                    onTap: () => _onCardTap('firma_yonetimi'),
                  ),
                ],
              ),
            ] else if (_currentMenu == 'personel') ...[
              // Submenu Header
              _buildSubmenuHeader('Personel & Araç'),
              const SizedBox(height: 20),

              // Submenu Grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.0,
                children: [
                  _buildMenuCard(
                    icon: Icons.people_outline_rounded,
                    title: 'Toplayıcı Yönetimi',
                    subtitle: 'Toplayıcı işlemleri',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF0F8B5A),
                    onTap: () => context.push('/firma/suruculer'),
                  ),
                  _buildMenuCard(
                    icon: Icons.local_shipping_rounded,
                    title: 'Araç Yönetimi',
                    subtitle: 'Kamyon ve araçlar',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF0F8B5A),
                    onTap: () => context.push('/firma/araclar'),
                  ),
                ],
              ),
            ] else if (_currentMenu == 'sut_tank') ...[
              // Centered Submenu Header with Water Drop Icon
              _buildCenteredSubmenuHeader('Süt ve Tank Yönetimi'),
              const SizedBox(height: 24),

              // Submenu Grid (3 columns for 9 cards)
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.85,
                children: [
                  _buildSubmenuCard(
                    icon: Icons.speed_rounded,
                    title: 'Tank Durumu',
                    color: const Color(0xFF0284C7),
                    onTap: () => context.push('/firma/tanklar'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.water_drop_rounded,
                    title: 'Tank Süt Girişleri',
                    color: const Color(0xFF0369A1),
                    onTap: () => context.push('/firma/tanklar/detay'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.input_rounded,
                    title: 'Süt Kabul',
                    color: const Color(0xFF0891B2),
                    onTap: () => context.push('/firma/sut-kabul'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.bar_chart_rounded,
                    title: 'Süt Rapor Sayfası',
                    color: const Color(0xFF0F766E),
                    onTap: () => context.push('/firma/raporlar'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Tank Ekle',
                    color: const Color(0xFF2563EB),
                    onTap: () => context.push('/firma/tanklar/ekle'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.assignment_ind_rounded,
                    title: 'Tank Atama',
                    color: const Color(0xFF4F46E5),
                    onTap: () => context.push('/firma/araclar/atama'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.analytics_rounded,
                    title: 'Süt Satış Raporu',
                    color: const Color(0xFF7C3AED),
                    onTap: () => context.push('/firma/satis-raporlari'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.sync_alt_rounded,
                    title: 'Süt Transfer & Takip',
                    color: const Color(0xFF059669),
                    onTap: () => context.push('/firma/sut-transferleri'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.science_rounded,
                    title: 'Süt Analiz',
                    color: const Color(0xFFD97706),
                    onTap: () => context.push('/firma/sut-analiz'),
                  ),
                ],
              ),
            ] else if (_currentMenu == 'firma_yonetimi') ...[
              // Submenu Header
              _buildSubmenuHeader('Firma Yönetimi'),
              const SizedBox(height: 20),

              // Submenu Grid
              GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 1.0,
                children: [
                  _buildMenuCard(
                    icon: Icons.business_rounded,
                    title: 'Firma Profili',
                    subtitle: 'Firma bilgileri ve ayarlar',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF1D9BF0),
                    onTap: () => context.push('/firma/profil'),
                  ),
                  _buildMenuCard(
                    icon: Icons.campaign_rounded,
                    title: 'Duyuru Gönder',
                    subtitle: 'Çalışanlara duyuru yapın',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF1D9BF0),
                    onTap: () => context.push('/firma/duyuru-gonder'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCenteredSubmenuHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: _onBackTap,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.gray100,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.all(10),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: 54,
          height: 54,
          decoration: const BoxDecoration(
            color: Color(0xFFEFF6FF),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Icon(
              Icons.water_drop_rounded,
              color: Color(0xFF3B82F6),
              size: 28,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.gray900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Süt ve tank işlemlerinizi buradan yönetebilirsiniz',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.gray500,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmenuHeader(String title) {
    return Row(
      children: [
        IconButton(
          onPressed: _onBackTap,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          style: IconButton.styleFrom(
            backgroundColor: AppColors.gray100,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(10),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.gray900,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.gray200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray800,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray200, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: bgColor.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
