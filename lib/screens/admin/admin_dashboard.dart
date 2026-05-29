import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;
  int _totalFirms = 0;
  int _expiredFirms = 0;
  int _under30DaysFirms = 0;
  int _under7DaysFirms = 0;

  double _totalMilkThisMonth = 0.0;
  int _totalStaff = 0;
  int _totalProducers = 0;
  int _activeAppProducers = 0;
  List<Map<String, dynamic>> _recentFirms = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final startOfMonthTs = Timestamp.fromDate(startOfMonth);

      // 1. Query firmalar
      final firmsSnap = await FirebaseFirestore.instance.collection('firmalar').get();
      final firms = firmsSnap.docs;

      int expired = 0;
      int under30 = 0;
      int under7 = 0;
      List<Map<String, dynamic>> loadedRecent = [];

      for (var doc in firms) {
        final data = doc.data();
        final Timestamp? expiryTs = data['abonelikBitis'] as Timestamp?;
        if (expiryTs != null) {
          final expiryDate = expiryTs.toDate();
          if (now.isAfter(expiryDate)) {
            expired++;
          } else {
            final diffDays = expiryDate.difference(now).inDays;
            if (diffDays <= 7) {
              under7++;
              under30++;
            } else if (diffDays <= 30) {
              under30++;
            }
          }
        }
        loadedRecent.add({
          'name': data['ad'] ?? '',
          'plan': 'Abonelik Bitiş: ${expiryTs != null ? DateFormat('dd.MM.yyyy').format(expiryTs.toDate()) : 'Belirtilmemiş'}',
          'status': expiryTs != null && now.isAfter(expiryTs.toDate()) ? 'expired' : 'active',
          'createdAt': data['createdAt'] as Timestamp?,
        });
      }

      // Sort recent firms by createdAt desc, take top 4
      loadedRecent.sort((a, b) {
        final tsA = a['createdAt'] as Timestamp?;
        final tsB = b['createdAt'] as Timestamp?;
        if (tsA == null && tsB == null) return 0;
        if (tsA == null) return 1;
        if (tsB == null) return -1;
        return tsB.compareTo(tsA);
      });
      if (loadedRecent.length > 4) {
        loadedRecent = loadedRecent.sublist(0, 4);
      }

      // 2. Query toplamalar for current month
      final milkSnap = await FirebaseFirestore.instance
          .collection('toplamalar')
          .where('timestamp', isGreaterThanOrEqualTo: startOfMonthTs)
          .get();
      double milkSum = 0.0;
      for (var doc in milkSnap.docs) {
        final mVal = doc.data()['m'];
        if (mVal is num) {
          milkSum += mVal.toDouble();
        }
      }

      // 3. Query all staff (suruculer)
      final staffSnap = await FirebaseFirestore.instance.collection('suruculer').get();
      final totalStaffCount = staffSnap.docs.length;

      // 4. Query all producers (ureticiler)
      final producersSnap = await FirebaseFirestore.instance.collection('ureticiler').get();
      final totalProducersCount = producersSnap.docs.length;

      // 5. Query active app producers (users with role 'uretici')
      final activeUsersSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'uretici')
          .get();
      final activeAppProducersCount = activeUsersSnap.docs.length;

      if (mounted) {
        setState(() {
          _totalFirms = firms.length;
          _expiredFirms = expired;
          _under30DaysFirms = under30;
          _under7DaysFirms = under7;
          _totalMilkThisMonth = milkSum;
          _totalStaff = totalStaffCount;
          _totalProducers = totalProducersCount;
          _activeAppProducers = activeAppProducersCount;
          _recentFirms = loadedRecent;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading admin dashboard stats: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
            _buildStatCards(isDesktop, isTablet),
            const SizedBox(height: 24),

            // Content Rows
            _buildContentLayout(isDesktop),
            const SizedBox(height: 80),
          ],
        );
      },
    );
  }

  Widget _buildStatCards(bool isDesktop, bool isTablet) {
    final cards = [
      StatCard(
        icon: Icons.business_rounded,
        value: '$_totalFirms',
        label: 'Toplam Firma',
        color: AppColors.primary600,
        change: '',
        subtext: 'Kayıtlı toplam firma',
        sparklineData: const [],
        isUp: true,
      ),
      StatCard(
        icon: Icons.lock_clock_rounded,
        value: '$_expiredFirms',
        label: 'Süresi Dolan Firma',
        color: AppColors.danger,
        change: '',
        subtext: 'Kullanımı askıda',
        sparklineData: const [],
        isUp: false,
      ),
      StatCard(
        icon: Icons.warning_amber_rounded,
        value: '$_under30DaysFirms',
        label: '<30 Gün Kalan',
        color: AppColors.warning,
        change: '',
        subtext: 'Bitişe 1 ay kalan',
        sparklineData: const [],
        isUp: false,
      ),
      StatCard(
        icon: Icons.running_with_errors_rounded,
        value: '$_under7DaysFirms',
        label: '<7 Gün Kalan',
        color: Colors.redAccent,
        change: '',
        subtext: 'Bitişe 7 gün kalan',
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
    } else {
      return StatsGrid(
        crossAxisCount: isTablet ? 2 : 2,
        spacing: isTablet ? 12 : 10,
        children: cards,
      );
    }
  }

  Widget _buildContentLayout(bool isDesktop) {
    final formatNumber = NumberFormat('#,##0', 'tr_TR');
    
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
                onPressed: () => context.push('/admin/firmalar'),
                child: Text(
                  'Tümünü Gör',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_recentFirms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  'Kayıtlı firma bulunmuyor.',
                  style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.gray500),
                ),
              ),
            )
          else
            ..._recentFirms.map((f) => Container(
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
                      f['name']!.isNotEmpty ? f['name']![0].toUpperCase() : 'F',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f['name']!, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800)),
                  Text(f['plan']!, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                ])),
                f['status'] == 'active' ? StatusBadge.active() : StatusBadge.danger('Süresi Doldu'),
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
          _row('Toplam Süt', '${formatNumber.format(_totalMilkThisMonth)} LT', Icons.water_drop_rounded, AppColors.primary600),
          _divider(),
          _row('Toplam Personel', '$_totalStaff personel', Icons.badge_rounded, AppColors.success),
          _divider(),
          _row('Toplam Üretici', '$_totalProducers üretici', Icons.people_rounded, AppColors.warning),
          _divider(),
          _row('Aktif Sütapp Üreticiler', '$_activeAppProducers üretici', Icons.check_circle_outline_rounded, AppColors.primary600),
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
