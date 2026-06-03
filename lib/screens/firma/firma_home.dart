import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class FirmaHomeScreen extends StatefulWidget {
  const FirmaHomeScreen({super.key});

  @override
  State<FirmaHomeScreen> createState() => _FirmaHomeScreenState();
}

class _FirmaHomeScreenState extends State<FirmaHomeScreen> {
  String _currentMenu = 'main'; // 'main', 'personel', 'sut_tank'
  static final Set<String> _shownPopups = {};

  @override
  void initState() {
    super.initState();
    _checkForPopUpAds();
  }

  void _checkForPopUpAds() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final query = await FirebaseFirestore.instance
            .collection('duyurular')
            .where('isGlobal', isEqualTo: true)
            .get();

        final docs = query.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final isPopUp = data['isPopUp'] as bool? ?? false;
          final targetRoles = data['targetRoles'] as List<dynamic>?;
          return isPopUp && (targetRoles != null && targetRoles.contains('firma'));
        }).toList();

        if (docs.isNotEmpty) {
          docs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          final doc = docs.first;
          final docId = doc.id;
          
          if (_shownPopups.contains(docId)) return;
          _shownPopups.add(docId);

          final data = doc.data() as Map<String, dynamic>?;
          final baslik = data?['baslik'] ?? '';
          final icerik = data?['icerik'] ?? '';

          if (!mounted) return;

          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    const Icon(Icons.campaign_rounded, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        baslik,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  icerik,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray700),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Kapat', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        }
      } catch (e) {
        print('Error checking pop-up ads: $e');
      }
    });
  }

  void _onCardTap(String target) {
    if (target == 'personel' || target == 'sut_tank') {
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
    final String currentFirma = user?.displayName ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('firmalar')
          .where('ad', isEqualTo: currentFirma)
          .snapshots(),
      builder: (context, firmSnap) {
        bool isExpired = false;
        bool isNearExpiration = false;
        DateTime? expiryDate;

        String? logoUrl;
        if (firmSnap.hasData && firmSnap.data!.docs.isNotEmpty) {
          final firmData = firmSnap.data!.docs.first.data() as Map<String, dynamic>;
          logoUrl = firmData['logoUrl'] as String?;
          final Timestamp? expiryTs = firmData['abonelikBitis'] as Timestamp?;
          if (expiryTs != null) {
            expiryDate = expiryTs.toDate();
            final now = DateTime.now();
            if (now.isAfter(expiryDate)) {
              isExpired = true;
            } else if (expiryDate.difference(now).inDays <= 30) {
              isNearExpiration = true;
            }
          }
        }

        if (isExpired) {
          return Scaffold(
            backgroundColor: AppColors.gray50,
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Card(
                  margin: const EdgeInsets.all(24),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: Colors.redAccent, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_clock_rounded, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          'Abonelik Süreniz Doldu!',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray900),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sistem kullanımınız askıya alınmıştır. Verileriniz silinmemiştir fakat işlem yapamazsınız. Lütfen sistem yöneticisi ile iletişime geçin.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              auth.logout();
                              context.go('/login');
                            },
                            icon: const Icon(Icons.logout_rounded, size: 16),
                            label: const Text('Çıkış Yap'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: AppColors.gray50,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                if (isNearExpiration && expiryDate != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Abonelik süreniz doluyor! Son tarih: ${DateFormat('dd.MM.yyyy').format(expiryDate)}',
                            style: GoogleFonts.inter(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (_currentMenu == 'main') ...[
              // Screen Description / Welcome Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT: Logo + Firma Adı
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gray200, width: 1.5),
                          color: Colors.white,
                          image: logoUrl != null && logoUrl.isNotEmpty
                              ? DecorationImage(
                                  image: logoUrl.startsWith('data:image')
                                      ? MemoryImage(base64Decode(logoUrl.substring(logoUrl.indexOf(',') + 1))) as ImageProvider
                                      : NetworkImage(logoUrl),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: logoUrl == null || logoUrl.isEmpty
                            ? Center(
                                child: Icon(Icons.business_rounded, color: AppColors.gray400, size: 24),
                              )
                            : null,
                      ),
                      if (currentFirma.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 80,
                          child: Text(
                            currentFirma,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray700,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(width: 14),
                  // RIGHT: 3-line greeting
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Hoş geldiniz',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.gray500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('👋', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          currentFirma.isNotEmpty ? currentFirma : (user?.displayName ?? 'Yönetici'),
                          style: GoogleFonts.inter(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.gray900,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
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
                      ],
                    ),
                  ),
                ],
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

                   // Süt Yönetimi
                  _buildMenuCard(
                    icon: Icons.water_drop_rounded,
                    title: 'Süt Yönetimi',
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

                  // Tedarikçi Firmalar
                  _buildMenuCard(
                    icon: Icons.business_rounded,
                    title: 'Tedarikçi Firmalar',
                    subtitle: 'Tedarikçi firma ve hesap yönetimi',
                    iconColor: Colors.white,
                    bgColor: const Color(0xFF1D9BF0),
                    onTap: () => _onCardTap('/firma/firmalar'),
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
              _buildCenteredSubmenuHeader('Süt Yönetimi'),
              const SizedBox(height: 24),

              // Submenu Grid (3 columns for 11 cards)
              GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: 0.85,
                children: [
                  _buildSubmenuCard(
                    icon: Icons.calendar_month_rounded,
                    title: 'Aylık Süt Kayıtları',
                    color: const Color(0xFF2563EB),
                    onTap: () => context.push('/firma/aylik-sut'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.water_drop_rounded,
                    title: 'Süt Toplamalar',
                    color: const Color(0xFF10B981),
                    onTap: () => context.push('/firma/toplamalar'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.speed_rounded,
                    title: 'Tank Durumu',
                    color: const Color(0xFF0284C7),
                    onTap: () => context.push('/firma/tanklar'),
                  ),
                  _buildSubmenuCard(
                    icon: Icons.water_drop_rounded,
                    title: 'Tank İçerik Detay',
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
                    title: 'Süt Toplama Raporu',
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
                    onTap: () => context.push('/firma/tanklar/atama'),
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
            ],
          ],
        ),
      ),
    );
    },
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
