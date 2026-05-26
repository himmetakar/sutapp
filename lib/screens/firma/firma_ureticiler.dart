import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

class FirmaUreticiler extends StatelessWidget {
  const FirmaUreticiler({super.key});

  Widget _buildMenuCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required String route,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
      ),
      child: InkWell(
        onTap: () => context.push(route),
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Üretici Yönetimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma'),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.25,
          children: [
            _buildMenuCard(
              context: context,
              title: 'Üreticiler',
              icon: Icons.people_rounded,
              color: const Color(0xFF9333EA), // Purple
              route: '/firma/ureticiler/liste',
            ),
            _buildMenuCard(
              context: context,
              title: 'Üretici Grupları',
              icon: Icons.grid_view_rounded,
              color: const Color(0xFF9333EA), // Purple
              route: '/firma/gruplar',
            ),
            _buildMenuCard(
              context: context,
              title: 'Yeni Üretici Onayları',
              icon: Icons.how_to_reg_rounded,
              color: const Color(0xFFF97316), // Orange
              route: '/firma/ureticiler/onaylar',
            ),
            _buildMenuCard(
              context: context,
              title: 'Atama İşlemleri',
              icon: Icons.person_add_alt_1_rounded,
              color: const Color(0xFFEF4444), // Red
              route: '/firma/atamalar',
            ),
            _buildMenuCard(
              context: context,
              title: 'Birlik Kaydı ve Listesi',
              icon: Icons.groups_rounded,
              color: const Color(0xFF22C55E), // Green
              route: '/firma/birlikler',
            ),
            _buildMenuCard(
              context: context,
              title: 'Satışlar',
              icon: Icons.list_alt_rounded,
              color: const Color(0xFF22C55E), // Green
              route: '/firma/satislar',
            ),
            _buildMenuCard(
              context: context,
              title: 'Tahsilat Yap',
              icon: Icons.credit_card_rounded,
              color: const Color(0xFFF97316), // Orange
              route: '/firma/tahsilat',
            ),
            _buildMenuCard(
              context: context,
              title: 'Avans Ver',
              icon: Icons.payments_rounded,
              color: const Color(0xFFF97316), // Orange
              route: '/firma/finans/avanslar',
            ),
            _buildMenuCard(
              context: context,
              title: 'Hesap Görüntüleme',
              icon: Icons.description_rounded,
              color: const Color(0xFF3B82F6), // Blue
              route: '/firma/hesap-ozeti',
            ),
            _buildMenuCard(
              context: context,
              title: 'Üretici Süt Fiyatları',
              icon: Icons.local_offer_rounded,
              color: const Color(0xFFEF4444), // Red
              route: '/firma/finans/sut-fiyatlari',
            ),
            _buildMenuCard(
              context: context,
              title: 'Aylık Süt Kayıtları',
              icon: Icons.grid_on_rounded,
              color: const Color(0xFF06B6D4), // Cyan
              route: '/firma/aylik-sut',
            ),
          ],
        ),
      ),
    );
  }
}
