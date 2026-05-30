import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

class FirmaPersonelYonetimiScreen extends StatelessWidget {
  const FirmaPersonelYonetimiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'Personel & Araç Yönetimi',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma'),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Personel ve araç işlemlerini buradan yönetebilirsiniz',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppColors.gray500,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 24),
            GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              children: [
                _buildMenuCard(
                  context: context,
                  icon: Icons.person_add_rounded,
                  title: 'Personel Ekle',
                  iconColor: Colors.white,
                  bgColor: const Color(0xFF0F8B5A),
                  onTap: () => context.push('/firma/personel/ekle'),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.people_rounded,
                  title: 'Personel Düzenleme',
                  iconColor: Colors.white,
                  bgColor: const Color(0xFF10B981),
                  onTap: () => context.push('/firma/personel/liste'),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.bar_chart_rounded,
                  title: 'Personel Performans Rapor',
                  iconColor: Colors.white,
                  bgColor: const Color(0xFFF59E0B),
                  onTap: () => context.push('/firma/personel/performans'),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.description_rounded,
                  title: 'Personel Açık/Fazla Rapor',
                  iconColor: Colors.white,
                  bgColor: const Color(0xFFE05300),
                  onTap: () => context.push('/firma/personel/acik-fazla'),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.local_shipping_rounded,
                  title: 'Araç Ekle',
                  iconColor: Colors.white,
                  bgColor: const Color(0xFF2563EB),
                  onTap: () => context.push('/firma/araclar/ekle'),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.list_alt_rounded,
                  title: 'Araç Listesi',
                  iconColor: Colors.white,
                  bgColor: const Color(0xFF008AAE),
                  onTap: () => context.push('/firma/araclar/liste'),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.credit_card_rounded,
                  title: 'Araç Gider Görüntüle',
                  iconColor: Colors.white,
                  bgColor: const Color(0xFF8B5CF6),
                  onTap: () => context.push('/firma/araclar/giderler'),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.link_rounded,
                  title: 'Personele Araç Atama',
                  iconColor: Colors.white,
                  bgColor: const Color(0xFFEF4444),
                  onTap: () => context.push('/firma/araclar/atama'),
                ),
                _buildMenuCard(
                  context: context,
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Personele Üretici Atama',
                  iconColor: Colors.white,
                  bgColor: const Color(0xFF009688),
                  onTap: () => context.push('/firma/atamalar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required IconData icon,
    required String title,
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
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 54,
                height: 54,
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
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
