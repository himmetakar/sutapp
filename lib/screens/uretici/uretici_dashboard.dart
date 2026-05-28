import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';

class UreticiDashboard extends StatelessWidget {
  const UreticiDashboard({super.key});

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isThisWeek(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;
    return difference >= 0 && difference < 7;
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final producerName = authProvider.user?.displayName ?? 'Mehmet Yılmaz';
    final firestoreService = FirestoreService();
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ureticiler')
          .where('name', isEqualTo: producerName)
          .limit(1)
          .snapshots(),
      builder: (context, producerSnap) {
        String bolge = '';
        String group = '';
        String currentFirma = '';
        if (producerSnap.hasData && producerSnap.data!.docs.isNotEmpty) {
          final pDoc = producerSnap.data!.docs.first.data() as Map<String, dynamic>;
          bolge = pDoc['bolge'] ?? '';
          group = pDoc['group'] ?? '';
          final List<dynamic> firms = pDoc['firmalar'] ?? [];
          if (firms.isNotEmpty) {
            currentFirma = firms.first.toString();
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: firestoreService.getMilkPricesStream(firma: currentFirma),
          builder: (context, pricesSnap) {
            final priceDocs = pricesSnap.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: firestoreService.getProducerCollectionsStream(producerName),
              builder: (context, snapshot) {
                double bugunTotal = 0.0;
                double haftaTotal = 0.0;
                double ayTotal = 0.0;
                double toplamTotal = 0.0;

                final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
                docs.sort((a, b) {
                  final aTime = (a.data() as Map)['timestamp'] as Timestamp?;
                  final bTime = (b.data() as Map)['timestamp'] as Timestamp?;
                  if (aTime == null) return -1;
                  if (bTime == null) return 1;
                  return bTime.compareTo(aTime);
                });
                final now = DateTime.now();
                final last7DaysVal = List<double>.filled(7, 0.0);

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final mVal = data['m'];
                  final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);

                  toplamTotal += m;

                  if (data['timestamp'] != null) {
                    final docDate = (data['timestamp'] as Timestamp).toDate();
                    
                    if (_isToday(docDate)) {
                      bugunTotal += m;
                    }
                    if (_isThisWeek(docDate)) {
                      haftaTotal += m;
                    }
                    if (_isThisMonth(docDate)) {
                      ayTotal += m;
                    }

                    final difference = now.difference(docDate).inDays;
                    if (difference >= 0 && difference < 7) {
                      final index = 6 - difference;
                      if (index >= 0 && index < 7) {
                        last7DaysVal[index] += m;
                      }
                    }
                  } else {
                    // Default to today if timestamp is null (local optimistic UI update)
                    bugunTotal += m;
                    haftaTotal += m;
                    ayTotal += m;
                    last7DaysVal[6] += m;
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tahsilatlar')
                      .where('uretici', isEqualTo: producerName)
                      .snapshots(),
                  builder: (context, tahsilatlarSnap) {
                    final tDocs = tahsilatlarSnap.data?.docs ?? [];

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('avanslar')
                          .where('uretici', isEqualTo: producerName)
                          .snapshots(),
                      builder: (context, avanslarSnap) {
                        final aDocs = avanslarSnap.data?.docs ?? [];

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('kesintiler')
                              .where('uretici', isEqualTo: producerName)
                              .snapshots(),
                          builder: (context, kesintilerSnap) {
                            final kDocs = kesintilerSnap.data?.docs ?? [];

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('cezalar')
                                  .where('uretici', isEqualTo: producerName)
                                  .snapshots(),
                              builder: (context, cezalarSnap) {
                                final cDocs = cezalarSnap.data?.docs ?? [];

                                final ledger = firestoreService.calculateLedger(
                                  collections: docs,
                                  prices: priceDocs,
                                  tahsilatlar: tDocs,
                                  avanslar: aDocs,
                                  kesintiler: kDocs,
                                  cezalar: cDocs,
                                  producerName: producerName,
                                  bolge: bolge,
                                  group: group,
                                  kesintiAyarlari: producerSnap.hasData && producerSnap.data!.docs.isNotEmpty
                                      ? (producerSnap.data!.docs.first.data() as Map<String, dynamic>)['kesintiAyarlari'] as Map<String, dynamic>?
                                      : null,
                                );

                                final double toplamAlacak = ledger['toplamAlacak'];
                                final double totalTahsilat = ledger['totalTahsilat'];
                                final double totalAvans = ledger['totalAvans'];
                                final double totalKesinti = ledger['totalKesinti'];
                                final double totalCeza = ledger['totalCeza'];
                                final double netAlacak = ledger['netBalance'];

                                return LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isDesktop = constraints.maxWidth >= 1024;
                                    final isTablet = constraints.maxWidth >= 640 && constraints.maxWidth < 1024;

                                    return ListView(
                                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                      children: [
                                        // Header
                                        StreamBuilder<QuerySnapshot>(
                                          stream: FirebaseFirestore.instance
                                              .collection('firmalar')
                                              .where('ad', isEqualTo: currentFirma)
                                              .limit(1)
                                              .snapshots(),
                                          builder: (context, companySnap) {
                                            String? logoUrl;
                                            if (companySnap.hasData && companySnap.data!.docs.isNotEmpty) {
                                              final companyData = companySnap.data!.docs.first.data() as Map<String, dynamic>;
                                              logoUrl = companyData['logoUrl'] as String?;
                                            }

                                            return Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                       Row(
                                                         children: [
                                                           Text(
                                                             'Üretici Paneli',
                                                             style: GoogleFonts.inter(
                                                               fontSize: isDesktop ? 22 : 18,
                                                               fontWeight: FontWeight.w700,
                                                               color: AppColors.gray900,
                                                             ),
                                                           ),
                                                           const SizedBox(width: 8),
                                                           ElevatedButton.icon(
                                                             onPressed: () => context.push('/uretici/dijital-kart'),
                                                             icon: const Icon(Icons.badge_rounded, size: 13),
                                                             label: Text(
                                                               'Dijital Süt Kartı',
                                                               style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
                                                             ),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: AppColors.primary600,
                                                               foregroundColor: Colors.white,
                                                               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                               padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                               minimumSize: Size.zero,
                                                               tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                             ),
                                                           ),
                                                         ],
                                                       ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        'Süt teslimatlarınızı ve güncel geçmişinizi buradan inceleyebilirsiniz.',
                                                        style: GoogleFonts.inter(
                                                          fontSize: isDesktop ? 12 : 11,
                                                          color: AppColors.gray500,
                                                          fontWeight: FontWeight.w400,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (logoUrl != null && logoUrl.isNotEmpty)
                                                  Container(
                                                    margin: const EdgeInsets.only(left: 12),
                                                    width: 48,
                                                    height: 48,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      border: Border.all(color: AppColors.gray200, width: 1.5),
                                                      image: DecorationImage(
                                                        image: logoUrl.startsWith('data:image')
                                                            ? MemoryImage(base64Decode(logoUrl.substring(logoUrl.indexOf(',') + 1))) as ImageProvider
                                                            : NetworkImage(logoUrl),
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            );
                                          }
                                        ),
                                        const SizedBox(height: 20),

                                        // Stat Cards Grid
                                        _buildStatCards(isDesktop, isTablet, bugunTotal, haftaTotal, ayTotal, toplamTotal),
                                        const SizedBox(height: 24),

                                        // Mali Özet Section Title
                                        Text(
                                          'Mali Durum Özeti',
                                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                        ),
                                        const SizedBox(height: 12),
                                        _buildMaliCards(isDesktop, isTablet, toplamAlacak, totalTahsilat, totalAvans, totalCeza, totalKesinti, netAlacak),
                                        const SizedBox(height: 24),

                                        // Charts & History
                                        _buildContentLayout(isDesktop, docs, last7DaysVal),
                                        const SizedBox(height: 80),
                                      ],
                                    );
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildStatCards(bool isDesktop, bool isTablet, double bugun, double hafta, double ay, double toplam) {
    final format = NumberFormat('#,##0', 'tr_TR');
    final cards = [
      StatCard(
        icon: Icons.today_rounded,
        value: format.format(bugun),
        label: 'Bugün (LT)',
        color: AppColors.primary600,
        change: '+%12',
        subtext: 'Günlük Alım Miktarı',
        sparklineData: const [42, 45, 38, 48, 40, 35, 45],
        isUp: true,
      ),
      StatCard(
        icon: Icons.date_range_rounded,
        value: format.format(hafta),
        label: 'Bu Hafta (LT)',
        color: AppColors.success,
        change: '+%5',
        subtext: 'Son 7 Günlük Toplam',
        sparklineData: const [250, 260, 270, 265, 275, 280, 285],
        isUp: true,
      ),
      StatCard(
        icon: Icons.calendar_month_rounded,
        value: format.format(ay),
        label: 'Bu Ay (LT)',
        color: AppColors.warning,
        change: '+%8',
        subtext: 'Aylık Toplam Süt',
        sparklineData: const [1100, 1120, 1150, 1180, 1200, 1220, 1240],
        isUp: true,
      ),
      StatCard(
        icon: Icons.all_inclusive_rounded,
        value: format.format(toplam),
        label: 'Toplam Süt (LT)',
        color: AppColors.primary700,
        change: '+%4',
        subtext: 'Genel Toplam Teslimat',
        sparklineData: const [11800, 11900, 12000, 12100, 12300, 12400, 12500],
        isUp: true,
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

  Widget _buildContentLayout(bool isDesktop, List<QueryDocumentSnapshot> docs, List<double> last7DaysVal) {
    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      spots.add(FlSpot(i.toDouble(), last7DaysVal[i]));
    }

    final d = <String>[];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      d.add(DateFormat('E', 'tr_TR').format(date));
    }

    // Determine max y value for proper chart scaling
    double maxY = 50.0;
    for (var val in last7DaysVal) {
      if (val > maxY) maxY = val + 10.0;
    }

    final chartWidget = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Son 7 Gün Grafiği',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gray800),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.gray100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY,
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final index = v.toInt();
                        if (index >= 0 && index < d.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(d[index], style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} LT',
                      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    )).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary600,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppColors.primary400.withValues(alpha: 0.25), AppColors.primary400.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.primary600,
                        strokeWidth: 2.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );

    final historyWidget = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Teslim Geçmişi',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gray800),
            ),
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Henüz teslimat kaydı bulunmuyor.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400),
                ),
              ),
            )
          else
            ...docs.map((t) {
              final data = t.data() as Map<String, dynamic>;
              final timestamp = data['timestamp'] as Timestamp?;
              final dateStr = timestamp != null ? DateFormat('dd.MM.yyyy').format(timestamp.toDate()) : '-';
              final s = data['s'] ?? '';
              final sr = data['sr'] ?? 'Ahmet Kara';
              final mVal = data['m'] ?? 0;
              final mStr = mVal is num ? mVal.toStringAsFixed(0) : mVal.toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary400.withValues(alpha: 0.15), AppColors.primary600.withValues(alpha: 0.08)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.water_drop_rounded, color: AppColors.primary500, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$dateStr • $s', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('Teslim Edilen: $sr', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(6)),
                    child: Text('$mStr LT', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary600)),
                  ),
                ]),
              );
            }),
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: chartWidget),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: historyWidget),
        ],
      );
    }

    return Column(
      children: [
        chartWidget,
        const SizedBox(height: 16),
        historyWidget,
      ],
    );
  }

  Widget _buildMaliCards(bool isDesktop, bool isTablet, double alacak, double tahsilat, double avans, double ceza, double kesinti, double net) {
    final format = NumberFormat('#,##0.00', 'tr_TR');
    final cards = [
      StatCard(
        icon: Icons.payments_rounded,
        value: format.format(alacak),
        label: 'Toplam Süt Alacağı',
        color: AppColors.primary600,
        change: '',
        subtext: 'Dinamik Fiyatlandırma',
        sparklineData: const [],
        isUp: true,
      ),
      StatCard(
        icon: Icons.account_balance_wallet_rounded,
        value: format.format(tahsilat),
        label: 'Tahsil Edilen Tutar',
        color: Colors.purple,
        change: '',
        subtext: 'Ödenen toplam süt bedeli',
        sparklineData: const [],
        isUp: true,
      ),
      StatCard(
        icon: Icons.money_off_rounded,
        value: format.format(avans),
        label: 'Alınan Toplam Avans',
        color: Colors.red,
        change: '',
        subtext: 'Tahsilattan düşülen avanslar',
        sparklineData: const [],
        isUp: false,
      ),
      StatCard(
        icon: Icons.gavel_rounded,
        value: format.format(ceza),
        label: 'Uygulanan Cezalar',
        color: Colors.orange,
        change: '',
        subtext: 'Süt kalite kesintileri',
        sparklineData: const [],
        isUp: false,
      ),
      StatCard(
        icon: Icons.content_cut_rounded,
        value: format.format(kesinti),
        label: 'Uygulanan Kesintiler',
        color: Colors.redAccent,
        change: '',
        subtext: 'Yem, aidat vb. kesintileri',
        sparklineData: const [],
        isUp: false,
      ),
      StatCard(
        icon: Icons.price_check_rounded,
        value: format.format(net.abs()),
        label: net >= 0 ? 'Kalan Net Alacak' : 'Kalan Toplam Borç',
        color: net >= 0 ? Colors.green : Colors.red,
        change: '',
        subtext: net >= 0 ? 'Ödenmesi gereken net bakiye' : 'Firmaya olan eksi bakiye',
        sparklineData: const [],
        isUp: net >= 0,
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
}
