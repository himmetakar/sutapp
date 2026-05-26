import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().getAllAvanslarStream(),
      builder: (context, avansSnap) {
        double totalAvans = 0.0;
        final aDocs = avansSnap.data?.docs ?? [];
        for (var doc in aDocs) {
          final aVal = doc['tutar'];
          if (aVal is num) {
            totalAvans += aVal.toDouble();
          } else if (aVal is String) {
            totalAvans += double.tryParse(aVal) ?? 0.0;
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            final isTablet = constraints.maxWidth >= 640 && constraints.maxWidth < 1024;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sistem Yönetim Paneli',
                            style: GoogleFonts.inter(
                              fontSize: isDesktop ? 22 : 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gray900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tüm platform genelindeki firmaları ve sistemi buradan yönetebilirsiniz.',
                            style: GoogleFonts.inter(
                              fontSize: isDesktop ? 12 : 11,
                              color: AppColors.gray500,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => context.push('/admin/duyuru-gonder'),
                      icon: const Icon(Icons.campaign_rounded, size: 18),
                      label: Text(
                        'Duyuru Gönder',
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Stat Cards Grid
                _buildStatCards(isDesktop, isTablet, totalAvans, aDocs.length),
                const SizedBox(height: 24),

                // Content Rows
                _buildContentLayout(isDesktop),
                const SizedBox(height: 80),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildStatCards(bool isDesktop, bool isTablet, double totalAvans, int avansCount) {
    final formatNumber = NumberFormat('#,##0', 'tr_TR');
    final cards = [
      StatCard(
        icon: Icons.business_rounded,
        value: '12',
        label: 'Toplam Firma',
        color: AppColors.primary600,
        change: '+2 yeni',
        subtext: 'Geçen ay: 10',
        sparklineData: const [8, 9, 9, 10, 11, 11, 12],
        isUp: true,
      ),
      StatCard(
        icon: Icons.people_rounded,
        value: '156',
        label: 'Toplam Üretici',
        color: AppColors.success,
        change: '+%12',
        subtext: 'Geçen ay: 139',
        sparklineData: const [120, 130, 135, 142, 148, 150, 156],
        isUp: true,
      ),
      StatCard(
        icon: Icons.local_shipping_rounded,
        value: '48',
        label: 'Aktif Kamyon',
        color: AppColors.warning,
        change: '+%5',
        subtext: 'Geçen ay: 45',
        sparklineData: const [40, 42, 45, 43, 44, 46, 48],
        isUp: true,
      ),
      StatCard(
        icon: Icons.water_drop_rounded,
        value: '245K',
        label: 'Aylık Süt (LT)',
        color: AppColors.primary700,
        change: '+%18',
        subtext: 'Geçen ay: 207K',
        sparklineData: const [190, 210, 220, 215, 230, 240, 245],
        isUp: true,
      ),
      StatCard(
        icon: Icons.money_off_rounded,
        value: formatNumber.format(totalAvans),
        label: 'Sistem Avansları (₺)',
        color: Colors.orange,
        change: '$avansCount adet',
        subtext: 'Platform genelindeki toplam',
        sparklineData: const [],
        isUp: false,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: c,
        ))).toList(),
      );
    } else if (isTablet) {
      return StatsGrid(
        crossAxisCount: 2,
        spacing: 12,
        children: cards,
      );
    } else {
      return StatsGrid(
        crossAxisCount: 2,
        spacing: 10,
        children: cards,
      );
    }
  }

  Widget _buildContentLayout(bool isDesktop) {
    final listFirmas = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Son Eklenen Firmalar',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gray800),
              ),
              TextButton(
                onPressed: () {},
                child: Text(
                  'Tümünü Gör',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            {'name': 'Anadolu Süt A.Ş.', 'plan': 'Endüstriyel', 'status': 'active'},
            {'name': 'Kayseri Çiftlik', 'plan': 'Orta', 'status': 'active'},
            {'name': 'Güneydoğu Süt', 'plan': 'Orta', 'status': 'active'},
            {'name': 'Ege Süt Birliği', 'plan': 'Endüstriyel', 'status': 'warning'},
          ].map((f) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    f['name']![0],
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f['name']!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800)),
                Text(f['plan']!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
              ])),
              f['status'] == 'active' ? StatusBadge.active() : StatusBadge.warning('Yakında Bitiyor'),
            ]),
          )),
        ],
      ),
    );

    final summaryMonth = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Bu Ay Özet',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gray800),
            ),
          ),
          const SizedBox(height: 12),
          _row('Toplam Süt', '245.000 LT', Icons.water_drop_rounded, AppColors.primary600),
          _divider(),
          _row('Aktif Firma', '12 firma', Icons.business_rounded, AppColors.success),
          _divider(),
          _row('Ortalama Fire', '%1.4', Icons.warning_amber_rounded, AppColors.warning),
          _divider(),
          _row('Yeni Kayıt', '3 firma', Icons.add_circle_outline_rounded, AppColors.primary600),
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: listFirmas),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: summaryMonth),
        ],
      );
    }

    return Column(
      children: [
        listFirmas,
        const SizedBox(height: 16),
        summaryMonth,
      ],
    );
  }

  Widget _divider() => const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider());

  Widget _row(String label, String value, IconData icon, Color color) {
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.08)]),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray600))),
      Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
    ]);
  }
}
