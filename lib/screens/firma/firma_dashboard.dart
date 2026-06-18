import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../widgets/quick_actions_dialogs.dart';

class FirmaDashboard extends StatefulWidget {
  const FirmaDashboard({super.key});

  @override
  State<FirmaDashboard> createState() => _FirmaDashboardState();
}

class _FirmaDashboardState extends State<FirmaDashboard> {
  int _selectedTab = 0; // 0: Günlük, 1: Aylık, 2: Tank Durumu, 3: Mali Özet
  DateTime _maliOzetMonth = DateTime.now();

  final _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final todayStr = DateFormat('dd MMMM yyyy EEEE', 'tr_TR').format(DateTime.now());
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getCollectionsStream(firma: currentFirmaName),
      builder: (context, snapshot) {
        double totalMilk = 0.0;
        int collectionCount = 0;

        if (snapshot.hasData) {
          final docs = snapshot.data!.docs;
          collectionCount = docs.length;
          for (var doc in docs) {
            final m = doc['m'];
            if (m is num) {
              totalMilk += m.toDouble();
            } else if (m is String) {
              totalMilk += double.tryParse(m) ?? 0.0;
            }
          }
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = MediaQuery.of(context).size.width >= 1024;
            final isTablet = MediaQuery.of(context).size.width >= 640 && MediaQuery.of(context).size.width < 1024;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                // Screen Title
                Text(
                  'Üretim & Operasyon Özetleri',
                  style: GoogleFonts.inter(
                    fontSize: isDesktop ? 22 : 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bugünkü üretim ve operasyon özetinizi aşağıda görebilirsiniz.',
                  style: GoogleFonts.inter(
                    fontSize: isDesktop ? 12 : 11,
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 20),

                // Tab Navigation
                _buildTabSelector(isDesktop),
                const SizedBox(height: 20),

                // Quick Actions for Mobile/Tablet
                // Quick Actions removed

                // Dynamic tab content
                _buildTabContent(isDesktop, isTablet, snapshot.data?.docs ?? [], collectionCount, currentFirmaName),
                const SizedBox(height: 80),
              ],
            );
          },
        );
      },
    );
  }

  // Tab Selector
  Widget _buildTabSelector(bool isDesktop) {
    final tabs = ['Günlük İşlemler', 'Aylık İşlemler', 'Tank Durumu', 'Mali Özet'];
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: tabs.asMap().entries.map((e) {
              final idx = e.key;
              final label = e.value;
              final isSelected = _selectedTab == idx;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.primary600 : AppColors.gray600,
                    ),
                  ),
                  selected: isSelected,
                  onSelected: (val) {
                    if (val) setState(() => _selectedTab = idx);
                  },
                  selectedColor: Colors.white,
                  backgroundColor: Colors.transparent,
                  checkmarkColor: AppColors.primary600,
                  showCheckmark: false,
                  elevation: 0,
                  pressElevation: 0,
                  shadowColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary100 : Colors.transparent,
                      width: 1,
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

  // Stat Cards
  Widget _buildStatCards(bool isDesktop, bool isTablet, double totalMilk, int collectionCount, double avansTotal, double tahsilatTotal) {
    final formatNumber = NumberFormat('#,##0', 'tr_TR');
    final cards = [
      StatCard(
        icon: Icons.water_drop_rounded,
        label: 'Toplanan Süt (Litre)',
        value: formatNumber.format(totalMilk),
        color: AppColors.primary600,
        subtext: 'İşlem: $collectionCount kayıt',
        isUp: true,
      ),
      StatCard(
        icon: Icons.payment_rounded,
        label: 'Süt Bedeli (₺)',
        value: formatNumber.format(totalMilk * 23.0),
        color: AppColors.success,
        subtext: 'Fiyat: 23 ₺/LT',
        isUp: true,
      ),
      StatCard(
        icon: Icons.sell_rounded,
        label: 'Satış Tutarı (₺)',
        value: formatNumber.format(totalMilk * 25.2),
        color: AppColors.warning,
        subtext: 'Fiyat: 25.2 ₺/LT',
        isUp: true,
      ),
      StatCard(
        icon: Icons.account_balance_wallet_rounded,
        label: 'Tahsilat (₺)',
        value: formatNumber.format(tahsilatTotal),
        color: Colors.purple,
        subtext: 'Sistem Toplamı',
        isUp: true,
      ),
      StatCard(
        icon: Icons.credit_card_rounded,
        label: 'Verilen Avanslar (₺)',
        value: formatNumber.format(avansTotal),
        color: Colors.teal,
        subtext: 'Sistem Toplamı',
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
        crossAxisCount: 3,
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

  Widget _buildDonutLegend(String name, String pct, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.gray700),
            ),
          ),
          Text(
            pct,
            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(bool isDesktop, bool isTablet, List<QueryDocumentSnapshot> collections, int collectionCount, String currentFirmaName) {
    double totalMilk = 0.0;
    for (var doc in collections) {
      final m = doc['m'];
      if (m is num) {
        totalMilk += m.toDouble();
      } else if (m is String) {
        totalMilk += double.tryParse(m) ?? 0.0;
      }
    }

    switch (_selectedTab) {
      case 0:
        return _buildDailyOperationsTab(isDesktop, isTablet, collections, totalMilk, collectionCount, currentFirmaName);
      case 1:
        return _buildMonthlyOperationsTab(isDesktop, isTablet, collections, totalMilk, collectionCount, currentFirmaName);
      case 2:
        return _buildTankStatusTab(isDesktop, isTablet, currentFirmaName);
      case 3:
        return _buildFinancialSummaryTab(isDesktop, isTablet, collections, currentFirmaName);
      default:
        return const SizedBox();
    }
  }

  Widget _buildDailyOperationsTab(bool isDesktop, bool isTablet, List<QueryDocumentSnapshot> collections, double totalMilk, int collectionCount, String currentFirmaName) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _loadProducerTrends(currentFirmaName, false),
        _getProducersNoMilkToday(currentFirmaName),
        _loadStaffPerformance(currentFirmaName, false),
        FirebaseFirestore.instance.collection('avanslar').where('firma', isEqualTo: currentFirmaName).get(),
        FirebaseFirestore.instance.collection('tahsilatlar').where('firma', isEqualTo: currentFirmaName).get(),
      ]),
      builder: (context, snap) {
        final Map<String, List<Map<String, dynamic>>> trends = (snap.data != null && snap.data!.isNotEmpty && snap.data![0] is Map)
            ? snap.data![0] as Map<String, List<Map<String, dynamic>>>
            : {'up': [], 'down': []};
        final List<String> noMilkToday = (snap.data != null && snap.data!.length > 1 && snap.data![1] is List<String>)
            ? snap.data![1] as List<String>
            : [];
        final List<Map<String, dynamic>> staffPerf = (snap.data != null && snap.data!.length > 2 && snap.data![2] is List<Map<String, dynamic>>)
            ? snap.data![2] as List<Map<String, dynamic>>
            : [];
        final avansSnap = snap.data != null && snap.data!.length > 3 ? snap.data![3] as QuerySnapshot : null;
        final tahsilatSnap = snap.data != null && snap.data!.length > 4 ? snap.data![4] as QuerySnapshot : null;

        double avansTotal = 0.0;
        if (avansSnap != null) {
          for (var doc in avansSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final durum = data['durum'] as String? ?? 'aktif';
            if (durum == 'iptal') continue;
            final tVal = data['tutar'];
            final val = tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
            avansTotal += val;
          }
        }

        double tahsilatTotal = 0.0;
        if (tahsilatSnap != null) {
          final fs = FirestoreService();
          for (var doc in tahsilatSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final tVal = data['tutar'];
            final val = tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
            final type = fs.getTahsilatType(data);
            if (type == 'tahsilat') {
              tahsilatTotal += val;
            }
          }
        }

        final formatNumber = NumberFormat('#,##0', 'tr_TR');
        final cards = [
          StatCard(
            icon: Icons.payment_rounded,
            label: 'Süt Bedeli (₺)',
            value: formatNumber.format(totalMilk * 23.0),
            color: AppColors.success,
            change: '',
            subtext: 'Fiyat: 23 ₺/LT',
            sparklineData: const [],
            isUp: true,
          ),
          StatCard(
            icon: Icons.sell_rounded,
            label: 'Satış Tutarı (₺)',
            value: formatNumber.format(totalMilk * 25.2),
            color: AppColors.warning,
            change: '',
            subtext: 'Fiyat: 25.2 ₺/LT',
            sparklineData: const [],
            isUp: true,
          ),
          StatCard(
            icon: Icons.credit_card_rounded,
            label: 'Verilen Avanslar (₺)',
            value: formatNumber.format(avansTotal),
            color: Colors.teal,
            change: '',
            subtext: 'Sistem Toplamı',
            sparklineData: const [],
            isUp: true,
          ),
          StatCard(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Tahsilat (₺)',
            value: formatNumber.format(tahsilatTotal),
            color: Colors.purple,
            change: '',
            subtext: 'Sistem Toplamı',
            sparklineData: const [],
            isUp: true,
          ),
        ];



        final bool showSideBySide = isDesktop || (kIsWeb && MediaQuery.of(context).size.width >= 600);

        Widget statsGrid = showSideBySide
            ? Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList())
            : StatsGrid(crossAxisCount: isTablet ? 4 : 2, spacing: isTablet ? 12 : 10, children: cards);

        final donutChartWidget = _buildDonutChartWidget(collections, isDesktop);
        final barChartWidget = _buildBarChartWidget(collections, isDesktop);
        final listProducersUp = _buildProducersTrendCard('Sütü En Çok Artanlar (Son 5 Gün)', trends['up'] ?? [], AppColors.success);
        final listProducersDown = _buildProducersTrendCard('Sütü En Çok Azalanlar (Son 5 Gün)', trends['down'] ?? [], AppColors.danger);
        final listNoMilkToday = _buildNoMilkTodayCard(noMilkToday);
        final listStaffDailyPerformance = _buildStaffPerformanceCard('Personel Günlük Performans', staffPerf);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isDesktop) ...[
              _buildStatCards(isDesktop, isTablet, totalMilk, collectionCount, avansTotal, tahsilatTotal),
              const SizedBox(height: 24),
            ],
            if (showSideBySide) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: donutChartWidget),
                    const SizedBox(width: 24),
                    Expanded(child: barChartWidget),
                  ],
                ),
              ),
            ] else ...[
              donutChartWidget,
              const SizedBox(height: 24),
              barChartWidget,
            ],
            if (!isDesktop) ...[
              const SizedBox(height: 24),
              statsGrid,
            ],
            const SizedBox(height: 24),
            if (showSideBySide) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: listProducersUp),
                  const SizedBox(width: 16),
                  Expanded(child: listProducersDown),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: listNoMilkToday),
                  const SizedBox(width: 16),
                  Expanded(child: listStaffDailyPerformance),
                ],
              ),
            ] else ...[
              listProducersUp,
              const SizedBox(height: 16),
              listProducersDown,
              const SizedBox(height: 16),
              listNoMilkToday,
              const SizedBox(height: 16),
              listStaffDailyPerformance,
            ]
          ],
        );
      },
    );
  }

  Widget _buildMonthlyOperationsTab(bool isDesktop, bool isTablet, List<QueryDocumentSnapshot> collections, double totalMilk, int collectionCount, String currentFirmaName) {
    final now = DateTime.now();
    double currentMonthMilk = 0.0;
    for (var doc in collections) {
      final data = doc.data() as Map<String, dynamic>;
      final date = _parseDocDate(data);
      if (date != null && date.year == now.year && date.month == now.month) {
        final m = data['m'];
        if (m is num) {
          currentMonthMilk += m.toDouble();
        } else if (m is String) {
          currentMonthMilk += double.tryParse(m) ?? 0.0;
        }
      }
    }
    final monthlyMilk = currentMonthMilk;

    return FutureBuilder<List<dynamic>>(
      future: Future.wait([
        _loadProducerTrends(currentFirmaName, true),
        _loadStaffPerformance(currentFirmaName, true),
        FirebaseFirestore.instance.collection('avanslar').where('firma', isEqualTo: currentFirmaName).get(),
        FirebaseFirestore.instance.collection('tahsilatlar').where('firma', isEqualTo: currentFirmaName).get(),
      ]),
      builder: (context, snap) {
        final Map<String, List<Map<String, dynamic>>> trends = (snap.data != null && snap.data!.isNotEmpty && snap.data![0] is Map)
            ? snap.data![0] as Map<String, List<Map<String, dynamic>>>
            : {'up': [], 'down': []};
        final List<Map<String, dynamic>> staffPerf = (snap.data != null && snap.data!.length > 1 && snap.data![1] is List<Map<String, dynamic>>)
            ? snap.data![1] as List<Map<String, dynamic>>
            : [];
        final avansSnap = snap.data != null && snap.data!.length > 2 ? snap.data![2] as QuerySnapshot : null;
        final tahsilatSnap = snap.data != null && snap.data!.length > 3 ? snap.data![3] as QuerySnapshot : null;

        double monthlyAvansTotal = 0.0;
        if (avansSnap != null) {
          for (var doc in avansSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final durum = data['durum'] as String? ?? 'aktif';
            if (durum == 'iptal') continue;
            final date = _parseDocDate(data);
            if (date != null && date.year == now.year && date.month == now.month) {
              final tVal = data['tutar'];
              final val = tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
              monthlyAvansTotal += val;
            }
          }
        }

        double monthlyTahsilatTotal = 0.0;
        if (tahsilatSnap != null) {
          final fs = FirestoreService();
          for (var doc in tahsilatSnap.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final date = _parseDocDate(data);
            if (date != null && date.year == now.year && date.month == now.month) {
              final tVal = data['tutar'];
              final val = tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
              final type = fs.getTahsilatType(data);
              if (type == 'tahsilat') {
                monthlyTahsilatTotal += val;
              }
            }
          }
        }

        final formatNumber = NumberFormat('#,##0', 'tr_TR');
        final cards = [
          StatCard(
            icon: Icons.payments_rounded,
            label: 'Aylık Süt Bedeli (₺)',
            value: formatNumber.format(monthlyMilk * 23.0),
            color: AppColors.success,
            change: '',
            subtext: 'Birim Fiyat: 23 ₺/LT',
            sparklineData: const [],
            isUp: true,
          ),
          StatCard(
            icon: Icons.shopping_bag_rounded,
            label: 'Aylık Satış Tutarı (₺)',
            value: formatNumber.format(monthlyMilk * 25.2),
            color: AppColors.warning,
            change: '',
            subtext: 'Birim Satış: 25.2 ₺/LT',
            sparklineData: const [],
            isUp: true,
          ),
          StatCard(
            icon: Icons.credit_card_rounded,
            label: 'Aylık Avans (₺)',
            value: formatNumber.format(monthlyAvansTotal),
            color: Colors.teal,
            change: '',
            subtext: 'Sistem Toplamı',
            sparklineData: const [],
            isUp: true,
          ),
          StatCard(
            icon: Icons.account_balance_wallet_rounded,
            label: 'Aylık Tahsilat (₺)',
            value: formatNumber.format(monthlyTahsilatTotal),
            color: Colors.purple,
            change: '',
            subtext: 'Sistem Toplamı',
            sparklineData: const [],
            isUp: true,
          ),
        ];

        final bool showSideBySide = isDesktop || (kIsWeb && MediaQuery.of(context).size.width >= 600);

        Widget statsGrid = showSideBySide
            ? Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: c))).toList())
            : StatsGrid(crossAxisCount: isTablet ? 4 : 2, spacing: isTablet ? 12 : 10, children: cards);

        final donutChartWidget = _buildDonutChartWidget(collections, isDesktop);
        final barChartWidget = _buildMonthlyBarChartWidget(collections, isDesktop);
        final listProducersUp = _buildProducersTrendCard('Aylık Sütü En Çok Artanlar (Önceki Ayın Ort.)', trends['up'] ?? [], AppColors.success);
        final listProducersDown = _buildProducersTrendCard('Aylık Sütü En Çok Azalanlar (Önceki Ayın Ort.)', trends['down'] ?? [], AppColors.danger);
        final listStaffMonthlyPerformance = _buildStaffPerformanceCard('Personel Aylık Performans', staffPerf);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showSideBySide) ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: donutChartWidget),
                    const SizedBox(width: 24),
                    Expanded(child: barChartWidget),
                  ],
                ),
              ),
            ] else ...[
              donutChartWidget,
              const SizedBox(height: 24),
              barChartWidget,
            ],
            const SizedBox(height: 24),
            statsGrid,
            const SizedBox(height: 24),
            if (showSideBySide) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: listProducersUp),
                  const SizedBox(width: 16),
                  Expanded(child: listProducersDown),
                ],
              ),
              const SizedBox(height: 24),
              listStaffMonthlyPerformance,
            ] else ...[
              listProducersUp,
              const SizedBox(height: 16),
              listProducersDown,
              const SizedBox(height: 16),
              listStaffMonthlyPerformance,
            ]
          ],
        );
      },
    );
  }

  Widget _buildTankStatusTab(bool isDesktop, bool isTablet, String currentFirmaName) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getTanksStream(firma: currentFirmaName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(),
          ));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text(
                'Bu firmaya ait tank kaydı bulunamadı.',
                style: GoogleFonts.inter(color: AppColors.gray500),
              ),
            ),
          );
        }

        List<QueryDocumentSnapshot> merkezTanks = [];
        List<QueryDocumentSnapshot> aracTanks = [];

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final String tip = data['tip'] ?? 'merkez';
          if (tip == 'merkez') {
            merkezTanks.add(doc);
          } else {
            aracTanks.add(doc);
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Merkez Tankları Section
            _buildSectionTitle('Merkez Tankları', merkezTanks.length),
            const SizedBox(height: 12),
            merkezTanks.isEmpty
                ? _buildEmptyState('Kayıtlı merkez tankı bulunmamaktadır.')
                : _buildVerticalDashboardTankList(merkezTanks),

            const SizedBox(height: 28),

            // Araç Tankları Section
            _buildSectionTitle('Araç Tankları', aracTanks.length),
            const SizedBox(height: 12),
            aracTanks.isEmpty
                ? _buildEmptyState('Kayıtlı araç tankı bulunmamaktadır.')
                : _buildVerticalDashboardTankList(aracTanks),
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.gray800,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count Adet',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.gray600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(color: AppColors.gray400, fontSize: 12.5),
        ),
      ),
    );
  }

  Widget _buildVerticalDashboardTankList(List<QueryDocumentSnapshot> tanks) {
    final double cardHeight = 88.0;
    final double spacing = 8.0;
    final double totalItemHeight = cardHeight + spacing;
    final double containerHeight = tanks.length <= 4 
        ? (tanks.length * totalItemHeight) 
        : (4 * totalItemHeight);

    return SizedBox(
      height: containerHeight,
      child: ListView.builder(
        scrollDirection: Axis.vertical,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tanks.length,
        itemBuilder: (context, index) {
          final data = tanks[index].data() as Map<String, dynamic>;
          final String ad = data['ad'] ?? '';
          final double stok = (data['stok'] as num?)?.toDouble() ?? 0.0;
          final double kap = (data['kap'] as num?)?.toDouble() ?? 2000.0;
          final double fillPercent = kap > 0 ? (stok / kap) : 0.0;
          final String tip = data['tip'] ?? 'merkez';
          final String arac = data['arac'] ?? '';

          Color gaugeColor = const Color(0xFF3B82F6);
          final bool isOverflow = stok > kap;
          if (isOverflow || fillPercent >= 0.8) {
            gaugeColor = const Color(0xFFEF4444);
          } else if (fillPercent >= 0.5) {
            gaugeColor = const Color(0xFFF59E0B);
          }

          return Container(
            height: cardHeight,
            margin: EdgeInsets.only(bottom: spacing),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isOverflow ? Colors.red : AppColors.gray200, width: isOverflow ? 1.5 : 1.0),
              boxShadow: AppShadows.sm,
            ),
            child: Row(
              children: [
                // Left: Storage Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.storage_rounded,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Middle: Name & Vehicle Info
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ad,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tip == 'merkez' ? 'Merkez Tankı' : (arac.isNotEmpty ? arac : 'Araç Tankı'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.gray400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stok.toStringAsFixed(0)} / ${kap.toStringAsFixed(0)} LT',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isOverflow ? Colors.red : AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Right: Horizontal Progress Bar & Details
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Doluluk',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.gray400),
                          ),
                          Text(
                            '%${(fillPercent * 100).toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isOverflow ? Colors.red : AppColors.gray800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fillPercent.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: AppColors.gray100,
                          valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Action Button: Detay
                GestureDetector(
                  onTap: () => _showTankIcerik(context, ad),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_rounded, size: 12, color: AppColors.gray600),
                        const SizedBox(width: 4),
                        Text(
                          'Detay',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showTankIcerik(BuildContext context, String tankAdi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '$tankAdi Giriş Kayıtları',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu tanka son giren süt toplama kayıtları listelenmektedir.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF1D4ED8), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<QueryDocumentSnapshot>>(
                future: () async {
                  final db = FirebaseFirestore.instance;
                  // Find the last time this (arac) tank was emptied
                  DateTime? lastEmptyTime;
                  try {
                    final emptySnap = await db
                        .collection('teslimatlar')
                        .where('kaynakTank', isEqualTo: tankAdi)
                        .orderBy('timestamp', descending: true)
                        .limit(1)
                        .get();
                    if (emptySnap.docs.isNotEmpty) {
                      final ts = emptySnap.docs.first.data()['timestamp'];
                      if (ts is Timestamp) lastEmptyTime = ts.toDate();
                    }
                  } catch (_) {}

                  Query q = db.collection('toplamalar').where('tank', isEqualTo: tankAdi);
                  if (lastEmptyTime != null) {
                    q = q.where('timestamp', isGreaterThan: Timestamp.fromDate(lastEmptyTime));
                  }
                  final snap = await q.get();
                  return snap.docs;
                }(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rawDocs = snapshot.data ?? [];
                  if (rawDocs.isEmpty) {
                    return Center(
                      child: Text(
                        'Kayıt bulunamadı.',
                        style: GoogleFonts.inter(color: AppColors.gray400),
                      ),
                    );
                  }

                  // Sort in memory by timestamp descending
                  final docs = List<QueryDocumentSnapshot>.from(rawDocs);
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aTs = aData['timestamp'];
                    final bTs = bData['timestamp'];

                    DateTime aDate = DateTime(1970);
                    DateTime bDate = DateTime(1970);

                    if (aTs is Timestamp) {
                      aDate = aTs.toDate();
                    } else if (aData['tarih'] is String) {
                      aDate = parseDateStr(aData['tarih']);
                    }

                    if (bTs is Timestamp) {
                      bDate = bTs.toDate();
                    } else if (bData['tarih'] is String) {
                      bDate = parseDateStr(bData['tarih']);
                    }

                    return bDate.compareTo(aDate);
                  });

                  final displayDocs = docs.take(15).toList();

                  return ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayDocs.length,
                    itemBuilder: (_, i) {
                      final doc = displayDocs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final u = data['u'] ?? 'Bilinmeyen Üretici';
                      final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
                      final s = data['s'] ?? '';
                      
                      final ts = data['timestamp'];
                      String t = '';
                      if (ts is Timestamp) {
                        t = DateFormat('dd.MM.yyyy').format(ts.toDate());
                      } else {
                        t = data['tarih'] ?? '';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: ListTile(
                          title: Text(
                            u,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gray800),
                          ),
                          subtitle: Text(
                            '$t $s',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                          ),
                          trailing: Text(
                            '${m.toStringAsFixed(1)} LT',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6), fontSize: 14),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime? _parseDocDate(Map<String, dynamic> data) {
    final rawDate = data['tarih'] ?? data['verildigiTarih'] ?? data['vereseTarih'] ?? data['tarihStr'];
    if (rawDate != null) {
      final str = rawDate.toString();
      try {
        return DateFormat('dd.MM.yyyy').parse(str);
      } catch (_) {
        try {
          return DateFormat('dd MMMM yyyy', 'tr_TR').parse(str);
        } catch (_) {}
      }
    }
    if (data['timestamp'] != null) {
      return (data['timestamp'] as Timestamp).toDate();
    }
    return null;
  }

  bool _isDocInSelectedMonth(DocumentSnapshot doc, DateTime selectedMonth) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;

    final date = _parseDocDate(data);
    if (date != null) {
      return date.month == selectedMonth.month && date.year == selectedMonth.year;
    }
    return false;
  }

  bool _isDocBeforeSelectedMonth(DocumentSnapshot doc, DateTime selectedMonth) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;

    final date = _parseDocDate(data);
    if (date != null) {
      if (date.year < selectedMonth.year) return true;
      if (date.year == selectedMonth.year && date.month < selectedMonth.month) return true;
    }
    return false;
  }

  bool _isDocUpToSelectedMonth(DocumentSnapshot doc, DateTime selectedMonth) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;

    final date = _parseDocDate(data);
    if (date != null) {
      if (date.year < selectedMonth.year) return true;
      if (date.year == selectedMonth.year && date.month <= selectedMonth.month) return true;
    }
    return false;
  }

  Widget _buildFinancialSummaryTab(bool isDesktop, bool isTablet, List<QueryDocumentSnapshot> collections, String currentFirmaName) {
    final formatNumber = NumberFormat('#,##0', 'tr_TR');
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_maliOzetMonth);

    // 1. Calculate Monthly Milk Stats
    final monthCollections = collections.where((doc) => _isDocInSelectedMonth(doc, _maliOzetMonth)).toList();
    // 2. Calculate Prior Milk Stats (Carryover)
    final prevCollections = collections.where((doc) => _isDocBeforeSelectedMonth(doc, _maliOzetMonth)).toList();

    // 3. Calculate Cumulative Milk Stats (Next Month Carryover)
    final upToCollections = collections.where((doc) => _isDocUpToSelectedMonth(doc, _maliOzetMonth)).toList();

    // Gerçek süt fiyatlarını Firestore'dan çek — hardcode 23.0 TL yerine
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sut_fiyatlari')
          .where('firma', isEqualTo: currentFirmaName)
          .snapshots(),
      builder: (context, fiyatSnap) {
        final priceList = (fiyatSnap.data?.docs ?? [])
            .map((d) => d.data() as Map<String, dynamic>)
            .toList();

        // Bu aya ait gerçek süt geliri (süt tipine göre fiyatlandırılmış)
        double grossMilkPrice = 0.0;
        for (var doc in monthCollections) {
          final m = (doc['m'] as num?)?.toDouble() ?? 0.0;
          final tip = (doc.data() as Map<String, dynamic>)['tip'] as String? ?? 'So\u011fuk S\u00fct';
          final priceKey = _firestoreService.mapMilkTypeToPriceKey(tip);
          final price = _firestoreService.resolveMilkPrice(
              prices: priceList, producerName: '', bolge: '', group: '', type: priceKey);
          grossMilkPrice += m * price;
        }

        // Önceki ayların biriken süt alacağı (gerçek fiyatlarla)
        double prevAlacak = 0.0;
        for (var doc in prevCollections) {
          final m = (doc['m'] as num?)?.toDouble() ?? 0.0;
          final tip = (doc.data() as Map<String, dynamic>)['tip'] as String? ?? 'So\u011fuk S\u00fct';
          final priceKey = _firestoreService.mapMilkTypeToPriceKey(tip);
          final price = _firestoreService.resolveMilkPrice(
              prices: priceList, producerName: '', bolge: '', group: '', type: priceKey);
          prevAlacak += m * price;
        }

        // Bu ay dahil birikimli alacak (sonraki aya devredecek)
        double upToAlacak = 0.0;
        for (var doc in upToCollections) {
          final m = (doc['m'] as num?)?.toDouble() ?? 0.0;
          final tip = (doc.data() as Map<String, dynamic>)['tip'] as String? ?? 'So\u011fuk S\u00fct';
          final priceKey = _firestoreService.mapMilkTypeToPriceKey(tip);
          final price = _firestoreService.resolveMilkPrice(
              prices: priceList, producerName: '', bolge: '', group: '', type: priceKey);
          upToAlacak += m * price;
        }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ureticiler')
          .where('firmalar', arrayContains: currentFirmaName)
          .snapshots(),
      builder: (context, ureticiSnap) {
        final producers = ureticiSnap.hasData
            ? ureticiSnap.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList()
            : [];

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('devirler')
              .where('firma', isEqualTo: currentFirmaName)
              .snapshots(),
          builder: (context, devirlerSnap) {
            final devirDocs = devirlerSnap.data?.docs ?? [];
            final prevDevirler = devirDocs.where((doc) => _isDocBeforeSelectedMonth(doc, _maliOzetMonth)).toList();
            final upToDevirler = devirDocs.where((doc) => _isDocUpToSelectedMonth(doc, _maliOzetMonth)).toList();

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tahsilatlar')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, tahsilatSnap) {
        if (tahsilatSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(40.0),
            child: CircularProgressIndicator(),
          ));
        }

        final tDocs = tahsilatSnap.data?.docs ?? [];
        
        // Month
        final thisMonthTahsilatlar = tDocs.where((doc) => _isDocInSelectedMonth(doc, _maliOzetMonth)).toList();
        double totalOdeme = 0.0;
        double totalProducerTahsilat = 0.0;
        final fs = FirestoreService();
        for (var doc in thisMonthTahsilatlar) {
          final data = doc.data() as Map<String, dynamic>;
          final tVal = data['tutar'];
          final val = tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
          final type = fs.getTahsilatType(data);
          if (type == 'tahsilat') {
            totalProducerTahsilat += val;
          } else {
            totalOdeme += val;
          }
        }

        // Previous
        final prevTahsilatlar = tDocs.where((doc) => _isDocBeforeSelectedMonth(doc, _maliOzetMonth)).toList();
        double prevOdemeVal = 0.0;
        double prevProducerTahsilatVal = 0.0;
        for (var doc in prevTahsilatlar) {
          final data = doc.data() as Map<String, dynamic>;
          final tVal = data['tutar'];
          final val = tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
          final type = fs.getTahsilatType(data);
          if (type == 'tahsilat') {
            prevProducerTahsilatVal += val;
          } else {
            prevOdemeVal += val;
          }
        }

        // Up to
        final upToTahsilatlar = tDocs.where((doc) => _isDocUpToSelectedMonth(doc, _maliOzetMonth)).toList();
        double upToOdemeVal = 0.0;
        double upToProducerTahsilatVal = 0.0;
        for (var doc in upToTahsilatlar) {
          final data = doc.data() as Map<String, dynamic>;
          final tVal = data['tutar'];
          final val = tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
          final type = fs.getTahsilatType(data);
          if (type == 'tahsilat') {
            upToProducerTahsilatVal += val;
          } else {
            upToOdemeVal += val;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('avanslar')
              .where('firma', isEqualTo: currentFirmaName)
              .snapshots(),
          builder: (context, avansSnap) {
            if (avansSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final aDocs = avansSnap.data?.docs ?? [];

            // Month
            final thisMonthAvanslar = aDocs.where((doc) => _isDocInSelectedMonth(doc, _maliOzetMonth)).toList();
            double totalAvans = 0.0;
            for (var doc in thisMonthAvanslar) {
              final durum = doc['durum'] as String? ?? 'aktif';
              if (durum == 'iptal') continue;
              final aVal = doc['tutar'];
              if (aVal is num) totalAvans += aVal.toDouble();
              else if (aVal is String) totalAvans += double.tryParse(aVal) ?? 0.0;
            }

            // Previous
            final prevAvanslar = aDocs.where((doc) => _isDocBeforeSelectedMonth(doc, _maliOzetMonth)).toList();
            double prevAvansVal = 0.0;
            for (var doc in prevAvanslar) {
              final durum = doc['durum'] as String? ?? 'aktif';
              if (durum == 'iptal') continue;
              final aVal = doc['tutar'];
              if (aVal is num) prevAvansVal += aVal.toDouble();
              else if (aVal is String) prevAvansVal += double.tryParse(aVal) ?? 0.0;
            }

            // Up to
            final upToAvanslar = aDocs.where((doc) => _isDocUpToSelectedMonth(doc, _maliOzetMonth)).toList();
            double upToAvansVal = 0.0;
            for (var doc in upToAvanslar) {
              final durum = doc['durum'] as String? ?? 'aktif';
              if (durum == 'iptal') continue;
              final aVal = doc['tutar'];
              if (aVal is num) upToAvansVal += aVal.toDouble();
              else if (aVal is String) upToAvansVal += double.tryParse(aVal) ?? 0.0;
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('kesintiler')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, kesintilerSnap) {
                if (kesintilerSnap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final kDocs = kesintilerSnap.data?.docs ?? [];

                // Month
                final thisMonthKesintiler = kDocs.where((doc) => _isDocInSelectedMonth(doc, _maliOzetMonth)).toList();
                double totalKesinti = 0.0;
                for (var doc in thisMonthKesintiler) {
                  final durum = doc['durum'] as String? ?? 'aktif';
                  if (durum == 'iptal') continue;
                  final kVal = doc['tutar'];
                  if (kVal is num) totalKesinti += kVal.toDouble();
                  else if (kVal is String) totalKesinti += double.tryParse(kVal) ?? 0.0;
                }

                // Previous
                final prevKesintiler = kDocs.where((doc) => _isDocBeforeSelectedMonth(doc, _maliOzetMonth)).toList();
                double prevKesintiVal = 0.0;
                for (var doc in prevKesintiler) {
                  final durum = doc['durum'] as String? ?? 'aktif';
                  if (durum == 'iptal') continue;
                  final kVal = doc['tutar'];
                  if (kVal is num) prevKesintiVal += kVal.toDouble();
                  else if (kVal is String) prevKesintiVal += double.tryParse(kVal) ?? 0.0;
                }

                // Up to
                final upToKesintiler = kDocs.where((doc) => _isDocUpToSelectedMonth(doc, _maliOzetMonth)).toList();
                double upToKesintiVal = 0.0;
                for (var doc in upToKesintiler) {
                  final durum = doc['durum'] as String? ?? 'aktif';
                  if (durum == 'iptal') continue;
                  final kVal = doc['tutar'];
                  if (kVal is num) upToKesintiVal += kVal.toDouble();
                  else if (kVal is String) upToKesintiVal += double.tryParse(kVal) ?? 0.0;
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('cezalar')
                      .where('firma', isEqualTo: currentFirmaName)
                      .snapshots(),
                  builder: (context, cezalarSnap) {
                    if (cezalarSnap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final cDocs = cezalarSnap.data?.docs ?? [];

                    // Month
                    final thisMonthCezalar = cDocs.where((doc) => _isDocInSelectedMonth(doc, _maliOzetMonth)).toList();
                    double totalCeza = 0.0;
                    for (var doc in thisMonthCezalar) {
                      final data = doc.data() as Map<String, dynamic>;
                      final durum = data['durum'] as String? ?? 'aktif';
                      if (durum == 'iptal') continue;
                      final tip = data['tip'] as String? ?? 'miktarsal';
                      if (tip == 'oransal') {
                        final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
                        totalCeza += grossMilkPrice * (oran / 100.0);
                      } else {
                        final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                        totalCeza += tutar;
                      }
                    }

                    // Previous
                    final prevCezalar = cDocs.where((doc) => _isDocBeforeSelectedMonth(doc, _maliOzetMonth)).toList();
                    double prevCezaVal = 0.0;
                    for (var doc in prevCezalar) {
                      final data = doc.data() as Map<String, dynamic>;
                      final durum = data['durum'] as String? ?? 'aktif';
                      if (durum == 'iptal') continue;
                      final tip = data['tip'] as String? ?? 'miktarsal';
                      if (tip == 'oransal') {
                        final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
                        prevCezaVal += prevAlacak * (oran / 100.0);
                      } else {
                        final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                        prevCezaVal += tutar;
                      }
                    }

                    // Up to
                    final upToCezalar = cDocs.where((doc) => _isDocUpToSelectedMonth(doc, _maliOzetMonth)).toList();
                    double upToCezaVal = 0.0;
                    for (var doc in upToCezalar) {
                      final data = doc.data() as Map<String, dynamic>;
                      final durum = data['durum'] as String? ?? 'aktif';
                      if (durum == 'iptal') continue;
                      final tip = data['tip'] as String? ?? 'miktarsal';
                      if (tip == 'oransal') {
                        final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
                        upToCezaVal += upToAlacak * (oran / 100.0);
                      } else {
                        final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                        upToCezaVal += tutar;
                      }
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('urunler')
                          .where('firma', isEqualTo: currentFirmaName)
                          .snapshots(),
                      builder: (context, urunlerSnap) {
                        final Map<String, String> productToCategory = {};
                        if (urunlerSnap.hasData) {
                          for (var doc in urunlerSnap.data!.docs) {
                            final uData = doc.data() as Map<String, dynamic>;
                            final String ad = uData['ad'] ?? '';
                            final String kat = uData['kategori'] ?? 'Diğer';
                            if (ad.isNotEmpty) {
                              productToCategory[ad.toLowerCase().trim()] = kat;
                            }
                          }
                        }

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('urunler_kategoriler')
                              .where('firma', isEqualTo: currentFirmaName)
                              .snapshots(),
                          builder: (context, categoriesSnap) {
                            final List<String> categories = [];
                            if (categoriesSnap.hasData) {
                              for (var doc in categoriesSnap.data!.docs) {
                                final name = (doc.data() as Map<String, dynamic>)['ad'] as String? ?? '';
                                if (name.isNotEmpty && !categories.contains(name)) {
                                  categories.add(name);
                                }
                              }
                            }
                            if (categories.isEmpty) {
                              categories.addAll(['Araç Gereç', 'Vitamin', 'Yem', 'İlaç']);
                            }

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('urunler_siparisler')
                                  .where('firma', isEqualTo: currentFirmaName)
                                  .snapshots(),
                              builder: (context, siparisSnap) {
                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('giderler')
                                      .where('firma', isEqualTo: currentFirmaName)
                                      .snapshots(),
                                  builder: (context, giderSnap) {
                                    return StreamBuilder<QuerySnapshot>(
                                      stream: FirebaseFirestore.instance
                                          .collection('cari_islemler')
                                          .where('firma', isEqualTo: currentFirmaName)
                                          .where('tip', isEqualTo: 'odeme')
                                          .snapshots(),
                                      builder: (context, cariIslemSnap) {
                                        final sDocs = siparisSnap.data?.docs ?? [];
                                        final thisMonthSiparisler = sDocs.where((doc) {
                                          final sData = doc.data() as Map<String, dynamic>;
                                          final durum = sData['durum'] ?? 'Bekliyor';
                                          return durum == 'Teslim Edildi' && _isDocInSelectedMonth(doc, _maliOzetMonth);
                                        }).toList();

                                        final Map<String, double> categoryRevenues = {
                                          for (var cat in categories) cat: 0.0
                                        };
                                        double digerGelir = 0.0;

                                        for (var doc in thisMonthSiparisler) {
                                          final sData = doc.data() as Map<String, dynamic>;
                                          final List<dynamic> items = sData['kalemler'] ?? [];
                                          for (var item in items) {
                                            if (item is Map) {
                                              final String urunName = item['urun'] ?? '';
                                              final double totalItem = (item['toplam'] as num?)?.toDouble() ?? 0.0;
                                              final String category = productToCategory[urunName.toLowerCase().trim()] ?? '';

                                              String? matchedCategory;
                                              if (category.isNotEmpty) {
                                                for (var cat in categories) {
                                                  if (cat.toLowerCase().trim() == category.toLowerCase().trim()) {
                                                    matchedCategory = cat;
                                                    break;
                                                  }
                                                }
                                              }
                                              if (matchedCategory == null) {
                                                final lowerUrun = urunName.toLowerCase().trim();
                                                for (var cat in categories) {
                                                  final lowerCat = cat.toLowerCase().trim();
                                                  if (lowerCat.isNotEmpty && lowerUrun.contains(lowerCat)) {
                                                    matchedCategory = cat;
                                                    break;
                                                  }
                                                }
                                              }

                                              if (matchedCategory != null) {
                                                categoryRevenues[matchedCategory] = (categoryRevenues[matchedCategory] ?? 0.0) + totalItem;
                                              } else {
                                                digerGelir += totalItem;
                                              }
                                            }
                                          }
                                        }
                                        final double totalProductGelir = categoryRevenues.values.fold(0.0, (sum, val) => sum + val) + digerGelir;

                                        double operatingExpenses = 0.0;
                                        if (giderSnap.hasData) {
                                          for (var doc in giderSnap.data!.docs) {
                                            final data = doc.data() as Map<String, dynamic>;
                                            final t = _parseDocDate(data);
                                            if (t != null && t.year == _maliOzetMonth.year && t.month == _maliOzetMonth.month) {
                                              final durum = data['durum'] as String? ?? 'aktif';
                                              if (durum == 'iptal') continue;
                                              final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                                              operatingExpenses += tutar;
                                            }
                                          }
                                        }
                                        if (cariIslemSnap.hasData) {
                                          for (var doc in cariIslemSnap.data!.docs) {
                                            final data = doc.data() as Map<String, dynamic>;
                                            final t = _parseDocDate(data);
                                            if (t != null && t.year == _maliOzetMonth.year && t.month == _maliOzetMonth.month) {
                                              final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                                              operatingExpenses += tutar;
                                            }
                                          }
                                        }

                                IconData getCategoryIcon(String cat) {
                                  final lower = cat.toLowerCase();
                                  if (lower.contains('araç') || lower.contains('gereç') || lower.contains('ekipman') || lower.contains('makine')) return Icons.build_rounded;
                                  if (lower.contains('vitamin')) return Icons.science_rounded;
                                  if (lower.contains('yem')) return Icons.eco_rounded;
                                  if (lower.contains('ilaç') || lower.contains('ilac')) return Icons.medical_services_rounded;
                                  if (lower.contains('hijyen') || lower.contains('temizlik') || lower.contains('deterjan') || lower.contains('dezenfektan') || lower.contains('sabun')) return Icons.cleaning_services_rounded;
                                  if (lower.contains('tohum') || lower.contains('bitki') || lower.contains('tarım')) return Icons.grain_rounded;
                                  return Icons.folder_rounded;
                                }

                            // 4. Financial Calculations based on selected month
                            final double netOdeyecek = (grossMilkPrice - totalAvans - totalCeza - totalKesinti).clamp(0.0, double.infinity);
                            final double odenen = totalOdeme;
                            final double kalan = (netOdeyecek - odenen).clamp(0.0, double.infinity);

                            // devir balances calculations (Summing per producer to prevent netting out different producers)
                            double devirBorc = 0.0;
                            double devirAlacak = 0.0;
                            double devirBorcNext = 0.0;
                            double devirAlacakNext = 0.0;

                            for (var producer in producers) {
                              final String name = (producer['name'] as String? ?? '').trim();
                              if (name.isEmpty) continue;

                              // 1. PREVIOUS ( Önceki Aydan Devreden )
                              final String pBolge = (producer['bolge'] as String? ?? '').trim();
                              final String pGroup = (producer['group'] as String? ?? '').trim();
                              double pPrevAlacak = 0.0;
                              for (var doc in prevCollections) {
                                if ((doc['u'] as String? ?? '').trim() != name) continue;
                                final m = (doc['m'] as num?)?.toDouble() ?? 0.0;
                                final tip = (doc.data() as Map<String, dynamic>)['tip'] as String? ?? 'So\u011fuk S\u00fct';
                                final priceKey = _firestoreService.mapMilkTypeToPriceKey(tip);
                                final price = _firestoreService.resolveMilkPrice(
                                    prices: priceList, producerName: name, bolge: pBolge, group: pGroup, type: priceKey);
                                pPrevAlacak += m * price;
                              }

                              double pPrevOdeme = 0.0;
                              double pPrevProducerTahsilat = 0.0;
                              for (var doc in prevTahsilatlar) {
                                if ((doc['uretici'] as String? ?? '').trim() == name) {
                                  final tVal = doc['tutar'];
                                  final val = tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
                                  final type = fs.getTahsilatType(doc.data() as Map<String, dynamic>);
                                  if (type == 'tahsilat') {
                                    pPrevProducerTahsilat += val;
                                  } else {
                                    pPrevOdeme += val;
                                  }
                                }
                              }

                              double pPrevAvans = 0.0;
                              for (var doc in prevAvanslar) {
                                if ((doc['uretici'] as String? ?? '').trim() == name) {
                                  final aVal = doc['tutar'];
                                  pPrevAvans += aVal is num ? aVal.toDouble() : (double.tryParse(aVal.toString()) ?? 0.0);
                                }
                              }

                              double pPrevKesinti = 0.0;
                              for (var doc in prevKesintiler) {
                                if ((doc['uretici'] as String? ?? '').trim() == name) {
                                  final kVal = doc['tutar'];
                                  pPrevKesinti += kVal is num ? kVal.toDouble() : (double.tryParse(kVal.toString()) ?? 0.0);
                                }
                              }

                              double pPrevCeza = 0.0;
                              for (var doc in prevCezalar) {
                                if ((doc['uretici'] as String? ?? '').trim() == name) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final tip = data['tip'] as String? ?? 'miktarsal';
                                  if (tip == 'oransal') {
                                    final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
                                    pPrevCeza += pPrevAlacak * (oran / 100.0);
                                  } else {
                                    pPrevCeza += (data['tutar'] as num?)?.toDouble() ?? 0.0;
                                  }
                                }
                              }

                              double pPrevDevir = 0.0;
                              for (var doc in prevDevirler) {
                                if ((doc['uretici'] as String? ?? '').trim() == name) {
                                  final dVal = doc['tutar'];
                                  pPrevDevir += dVal is num ? dVal.toDouble() : (double.tryParse(dVal.toString()) ?? 0.0);
                                }
                              }

                              final double pPrevNetOwed = pPrevAlacak - pPrevOdeme + pPrevProducerTahsilat - pPrevAvans - pPrevKesinti - pPrevCeza + pPrevDevir;
                              if (pPrevNetOwed > 0) {
                                devirAlacak += pPrevNetOwed;
                              } else if (pPrevNetOwed < 0) {
                                devirBorc += pPrevNetOwed; // Sum negative values
                              }

                              // 2. NEXT ( Diğer Aya Devreden )
                              double pUpToAlacak = 0.0;
                              for (var doc in upToCollections) {
                                if ((doc['u'] as String? ?? '').trim() != name) continue;
                                final m = (doc['m'] as num?)?.toDouble() ?? 0.0;
                                final tip = (doc.data() as Map<String, dynamic>)['tip'] as String? ?? 'So\u011fuk S\u00fct';
                                final priceKey = _firestoreService.mapMilkTypeToPriceKey(tip);
                                final price = _firestoreService.resolveMilkPrice(
                                    prices: priceList, producerName: name, bolge: pBolge, group: pGroup, type: priceKey);
                                pUpToAlacak += m * price;
                              }

                              double pUpToOdeme = 0.0;
                              double pUpToProducerTahsilat = 0.0;
                              for (var doc in upToTahsilatlar) {
                                if ((doc['uretici'] as String? ?? '').trim() == name) {
                                  final tVal = doc['tutar'];
                                  final val = tVal is num ? tVal.toDouble() : (double.tryParse(tVal.toString()) ?? 0.0);
                                  final type = fs.getTahsilatType(doc.data() as Map<String, dynamic>);
                                  if (type == 'tahsilat') {
                                    pUpToProducerTahsilat += val;
                                  } else {
                                    pUpToOdeme += val;
                                  }
                                }
                              }

                              double pUpToAvans = 0.0;
                              for (var doc in upToAvanslar) {
                                if ((doc['uretici'] as String? ?? '').trim() == name) {
                                  final aVal = doc['tutar'];
                                  pUpToAvans += aVal is num ? aVal.toDouble() : (double.tryParse(aVal.toString()) ?? 0.0);
                                }
                              }

                              double pUpToKesinti = 0.0;
                              for (var doc in upToKesintiler) {
                                if ((doc['uretici'] as String? ?? '').trim() == name) {
                                  final kVal = doc['tutar'];
                                  pUpToKesinti += kVal is num ? kVal.toDouble() : (double.tryParse(kVal.toString()) ?? 0.0);
                                }
                              }

                              double pUpToCeza = 0.0;
                              for (var doc in upToCezalar) {
                                if ((doc['uretici'] as String? ?? '').trim() == name) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final tip = data['tip'] as String? ?? 'miktarsal';
                                  if (tip == 'oransal') {
                                    final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
                                    pUpToCeza += pUpToAlacak * (oran / 100.0);
                                  } else {
                                    pUpToCeza += (data['tutar'] as num?)?.toDouble() ?? 0.0;
                                  }
                                }
                              }

                              double pUpToDevir = 0.0;
                              for (var doc in upToDevirler) {
                                if ((doc['uretici'] as String? ?? '').trim() == name) {
                                  final dVal = doc['tutar'];
                                  pUpToDevir += dVal is num ? dVal.toDouble() : (double.tryParse(dVal.toString()) ?? 0.0);
                                }
                              }

                              final double pNextNetOwed = pUpToAlacak - pUpToOdeme + pUpToProducerTahsilat - pUpToAvans - pUpToKesinti - pUpToCeza + pUpToDevir;
                              if (pNextNetOwed > 0) {
                                devirAlacakNext += pNextNetOwed;
                              } else if (pNextNetOwed < 0) {
                                devirBorcNext += pNextNetOwed; // Sum negative values
                              }
                            }

                            final double totalIncomes = totalProducerTahsilat + totalKesinti;
                            final double totalExpenses = totalAvans + totalOdeme + operatingExpenses;
                            final double netProfit = totalIncomes - totalExpenses;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Month Selector Banner (Gradient / Pill Style matching Mockup)
                                Container(
                                  margin: const EdgeInsets.symmetric(vertical: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    borderRadius: BorderRadius.circular(30),
                                    border: Border.all(color: AppColors.primary100),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary600),
                                        onPressed: () {
                                          setState(() {
                                            _maliOzetMonth = DateTime(_maliOzetMonth.year, _maliOzetMonth.month - 1, 1);
                                          });
                                        },
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.calendar_month_rounded, color: AppColors.primary600, size: 20),
                                          const SizedBox(width: 8),
                                          Text(
                                            monthStr,
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary700),
                                          ),
                                        ],
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary600),
                                        onPressed: () {
                                          setState(() {
                                            _maliOzetMonth = DateTime(_maliOzetMonth.year, _maliOzetMonth.month + 1, 1);
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // 2x2 Primary Financial Metrics Grid (Mockup Layout)
                                GridView.count(
                                  crossAxisCount: (isDesktop || (kIsWeb && MediaQuery.of(context).size.width >= 600)) ? 4 : 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: (isDesktop || (kIsWeb && MediaQuery.of(context).size.width >= 600)) ? 1.5 : (isTablet ? 1.4 : 1.3),
                                  children: [
                                    _buildMockupCard('Toplam Süt Tutarı', formatNumber.format(grossMilkPrice), Icons.water_drop_rounded, AppColors.primary600),
                                    _buildMockupCard('Ödenecek Tutar', formatNumber.format(netOdeyecek), Icons.query_builder_rounded, AppColors.warning, valueColor: AppColors.warning),
                                    _buildMockupCard('Yapılan Ödeme', formatNumber.format(odenen), Icons.check_circle_rounded, AppColors.success),
                                    _buildMockupCard('Kalan Ödeme', formatNumber.format(kalan), Icons.arrow_upward_rounded, const Color(0xFF6366F1)),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Carryover Balances (Borç / Alacak Details Card)
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMockupCarryoverCard(
                                        'Önceki Aydan Devreden',
                                        devirBorc,
                                        devirAlacak,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildMockupCarryoverCard(
                                        'Diğer Aya Devreden',
                                        devirBorcNext,
                                        devirAlacakNext,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Expenses & Incomes Summary Cards
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMockupFinanceDetailsCard(
                                        'Giderler Tutar',
                                        formatNumber.format(totalExpenses),
                                        Icons.arrow_downward_rounded,
                                        AppColors.danger,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildMockupFinanceDetailsCard(
                                        'Gelirler tutar',
                                        formatNumber.format(totalIncomes),
                                        Icons.people_alt_rounded,
                                        AppColors.success,
                                        valueColor: AppColors.gray800,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Net profit highlight banner
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: netProfit >= 0 
                                          ? [const Color(0xFF10B981), const Color(0xFF059669)] 
                                          : [const Color(0xFFEF4444), const Color(0xFFDC2626)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: AppShadows.md,
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Center(
                                          child: Icon(Icons.analytics_rounded, color: Colors.white, size: 24),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Net Kar / Zarar',
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                                            ),
                                            Text(
                                              'Süt Satış ve Ürün Karının Toplamı',
                                              style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.85)),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        (netProfit >= 0 ? '+' : '') + formatNumber.format(netProfit) + ' ₺',
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.white),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // AVANS VE TAHSİLAT Section
                                Center(
                                  child: Text(
                                    'AVANS VE TAHSİLAT',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray400, letterSpacing: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildMockupAvansTahsilatCard(
                                        'Bu Ay Verilen Avans',
                                        formatNumber.format(totalAvans) + '₺',
                                        Icons.payments_outlined,
                                        AppColors.primary600,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _buildMockupAvansTahsilatCard(
                                        'Tahsilat',
                                        formatNumber.format(totalProducerTahsilat) + '₺',
                                        Icons.account_balance_wallet_outlined,
                                        AppColors.success,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // ÜRÜN GELİRLERİ Section
                                Center(
                                  child: Text(
                                    'ÜRÜN GELİRLERİ',
                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray400, letterSpacing: 0.8),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Column(
                                  children: [
                                    ...categories.asMap().entries.map((entry) {
                                      final idx = entry.key + 1;
                                      final catName = entry.value;
                                      final revenue = categoryRevenues[catName] ?? 0.0;
                                      return _buildMockupProductRevenueRow(
                                        '$idx. ${catName.toUpperCase()}',
                                        formatNumber.format(revenue) + ' ₺',
                                        getCategoryIcon(catName),
                                      );
                                    }),
                                    _buildMockupProductRevenueRow(
                                      '${categories.length + 1}. DİĞER',
                                      formatNumber.format(digerGelir) + ' ₺',
                                      Icons.widgets_rounded,
                                    ),
                                  ],
                                ),
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
},
);
},
);
},
);
      }, // sut_fiyatlari StreamBuilder builder sonu
    ); // sut_fiyatlari StreamBuilder sonu
  }

  Widget _buildMockupCard(String label, String value, IconData icon, Color color, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray500,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valueColor ?? AppColors.gray800,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMockupCarryoverCard(String title, double borc, double alacak) {
    final formatNumber = NumberFormat('#,##0', 'tr_TR');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.gray700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Borçlu :',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFEF4444),
                ),
              ),
              Text(
                formatNumber.format(borc),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFEF4444),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alacaklı :',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF10B981),
                ),
              ),
              Text(
                formatNumber.format(alacak),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMockupFinanceDetailsCard(String label, String value, IconData icon, Color color, {Color? valueColor}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: color, size: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: valueColor ?? color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockupAvansTahsilatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: color, size: 16),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.gray500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMockupProductRevenueRow(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary50,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Icon(icon, color: AppColors.primary600, size: 14),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.gray700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primary600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListItemRow(int index, String name, String value, String change, Color trendColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            '$index',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray400),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.gray700),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600),
          ),
          const SizedBox(width: 12),
          Text(
            change,
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: trendColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String title, String body, String time, Color color, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gray800),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  DateTime parseDateStr(String dateStr) {
    try {
      final parts = dateStr.split('.');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime(1970);
  }

  DateTime getDocDate(Map<String, dynamic> data) {
    final ts = data['timestamp'];
    if (ts is Timestamp) {
      return ts.toDate();
    }
    final tarih = data['tarih'];
    if (tarih is String) {
      return parseDateStr(tarih);
    }
    return DateTime(1970);
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadProducerTrends(String currentFirmaName, bool isMonthly) async {
    try {
      final collectionsSnap = await FirebaseFirestore.instance
          .collection('toplamalar')
          .where('firma', isEqualTo: currentFirmaName)
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final Map<String, List<Map<String, dynamic>>> collectionsByProducer = {};
      for (var doc in collectionsSnap.docs) {
        final data = doc.data();
        final String uretici = data['u'] ?? '';
        if (uretici.isEmpty) continue;

        final double litres = (data['m'] as num?)?.toDouble() ?? 0.0;
        final DateTime date = getDocDate(data);

        collectionsByProducer.putIfAbsent(uretici, () => []).add({
          'litres': litres,
          'date': date,
        });
      }

      final List<Map<String, dynamic>> computedTrends = [];

      if (!isMonthly) {
        final fiveDaysAgo = today.subtract(const Duration(days: 5));

        collectionsByProducer.forEach((uretici, list) {
          double todayVol = 0.0;
          double prev5DaysVol = 0.0;

          for (var col in list) {
            final DateTime colDate = col['date'];
            final double litres = col['litres'];
            final DateTime colDay = DateTime(colDate.year, colDate.month, colDate.day);

            if (colDay.isAtSameMomentAs(today)) {
              todayVol += litres;
            } else if (colDay.isAfter(fiveDaysAgo.subtract(const Duration(microseconds: 1))) &&
                       colDay.isBefore(today)) {
              prev5DaysVol += litres;
            }
          }

          final double avg5Days = prev5DaysVol / 5.0;

          double percentChange = 0.0;
          if (avg5Days > 0) {
            percentChange = ((todayVol - avg5Days) / avg5Days) * 100.0;
          } else if (todayVol > 0) {
            percentChange = 100.0;
          }

          if (todayVol != 0.0 || avg5Days != 0.0) {
            computedTrends.add({
              'name': uretici,
              'value': '${todayVol.toStringAsFixed(1)} L',
              'change': percentChange,
            });
          }
        });
      } else {
        final thisMonthStart = DateTime(today.year, today.month, 1);
        final prevMonthStart = DateTime(today.year, today.month - 1, 1);

        collectionsByProducer.forEach((uretici, list) {
          double thisMonthVol = 0.0;
          double prevMonthVol = 0.0;

          for (var col in list) {
            final DateTime colDate = col['date'];
            final double litres = col['litres'];

            if (colDate.isAfter(thisMonthStart.subtract(const Duration(microseconds: 1)))) {
              thisMonthVol += litres;
            } else if (colDate.isAfter(prevMonthStart.subtract(const Duration(microseconds: 1))) &&
                       colDate.isBefore(thisMonthStart)) {
              prevMonthVol += litres;
            }
          }

          double percentChange = 0.0;
          if (prevMonthVol > 0) {
            percentChange = ((thisMonthVol - prevMonthVol) / prevMonthVol) * 100.0;
          } else if (thisMonthVol > 0) {
            percentChange = 100.0;
          }

          if (thisMonthVol != 0.0 || prevMonthVol != 0.0) {
            computedTrends.add({
              'name': uretici,
              'value': '${thisMonthVol.toStringAsFixed(1)} L',
              'change': percentChange,
            });
          }
        });
      }

      final List<Map<String, dynamic>> up = [];
      final List<Map<String, dynamic>> down = [];

      for (var t in computedTrends) {
        final double change = t['change'];
        final String changeStr = '${change >= 0 ? "+" : ""}${change.toStringAsFixed(1)}%';
        final Map<String, dynamic> item = {
          'n': t['name'],
          'v': t['value'],
          'c': changeStr,
          'changeVal': change,
        };

        if (change > 0) {
          up.add(item);
        } else if (change < 0) {
          down.add(item);
        }
      }

      up.sort((a, b) => b['changeVal'].compareTo(a['changeVal']));
      down.sort((a, b) => a['changeVal'].compareTo(b['changeVal']));

      return {
        'up': up.take(5).toList(),
        'down': down.take(5).toList(),
      };
    } catch (e) {
      print("Error loading trends: $e");
      return {'up': [], 'down': []};
    }
  }

  Future<List<String>> _getProducersNoMilkToday(String currentFirmaName) async {
    try {
      final ureticiSnap = await FirebaseFirestore.instance
          .collection('ureticiler')
          .where('firmalar', arrayContains: currentFirmaName)
          .get();

      final List<String> allProducers = ureticiSnap.docs
          .map((d) => (d.data()['name'] as String? ?? '').trim())
          .where((name) => name.isNotEmpty)
          .toList();

      final collectionsSnap = await FirebaseFirestore.instance
          .collection('toplamalar')
          .where('firma', isEqualTo: currentFirmaName)
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final Set<String> activeToday = {};
      for (var doc in collectionsSnap.docs) {
        final data = doc.data();
        final DateTime date = getDocDate(data);
        final DateTime colDay = DateTime(date.year, date.month, date.day);
        if (colDay.isAtSameMomentAs(today)) {
          final String uretici = (data['u'] as String? ?? '').trim();
          if (uretici.isNotEmpty) {
            activeToday.add(uretici);
          }
        }
      }

      final List<String> noMilk = allProducers
          .where((p) => !activeToday.contains(p))
          .toList();

      return noMilk;
    } catch (e) {
      print("Error in no milk today: $e");
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadStaffPerformance(String currentFirmaName, bool isMonthly) async {
    try {
      final driversSnap = await FirebaseFirestore.instance
          .collection('suruculer')
          .where('firma', isEqualTo: currentFirmaName)
          .get();

      final collectionsSnap = await FirebaseFirestore.instance
          .collection('toplamalar')
          .where('firma', isEqualTo: currentFirmaName)
          .get();

      final deliveriesSnap = await FirebaseFirestore.instance
          .collection('sut_kabul')
          .where('firma', isEqualTo: currentFirmaName)
          .where('durum', isEqualTo: 'Kabul Edildi')
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final thisMonthStart = DateTime(today.year, today.month, 1);

      final List<Map<String, dynamic>> results = [];

      for (var doc in driversSnap.docs) {
        final data = doc.data();
        final String name = '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'.trim();
        if (name.isEmpty) continue;

        double totalMilk = 0.0;
        for (var col in collectionsSnap.docs) {
          final cData = col.data();
          final String sr = cData['sr'] ?? '';
          if (sr != name) continue;

          final DateTime date = getDocDate(cData);
          if (!isMonthly) {
            final DateTime colDay = DateTime(date.year, date.month, date.day);
            if (colDay.isAtSameMomentAs(today)) {
              totalMilk += (cData['m'] as num?)?.toDouble() ?? 0.0;
            }
          } else {
            if (date.isAfter(thisMonthStart.subtract(const Duration(microseconds: 1)))) {
              totalMilk += (cData['m'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }

        double shortage = 0.0;
        for (var del in deliveriesSnap.docs) {
          final dData = del.data();
          final String sr = dData['sr'] ?? dData['surucuName'] ?? dData['email'] ?? '';
          if (sr != name) continue;

          final DateTime date = getDocDate(dData);
          bool inPeriod = false;
          if (!isMonthly) {
            final DateTime colDay = DateTime(date.year, date.month, date.day);
            if (colDay.isAtSameMomentAs(today)) {
              inPeriod = true;
            }
          } else {
            if (date.isAfter(thisMonthStart.subtract(const Duration(microseconds: 1)))) {
              inPeriod = true;
            }
          }

          if (inPeriod) {
            final double toplanan = (dData['miktar'] ?? 0.0).toDouble();
            final double teslim = (dData['kabulEdilenMiktar'] ?? dData['miktar'] ?? 0.0).toDouble();
            final double fark = toplanan - teslim;
            shortage += fark;
          }
        }

        results.add({
          'n': name,
          'p': name.isNotEmpty ? name[0].toUpperCase() : '',
          'milk': totalMilk,
          'shortage': shortage,
        });
      }

      return results;
    } catch (e) {
      print("Error in staff performance: $e");
      return [];
    }
  }

  Widget _buildProducersTrendCard(String title, List<Map<String, dynamic>> list, Color trendColor) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gray800),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Veri bulunamadı.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                ),
              ),
            )
          else
            ...list.asMap().entries.map((e) {
              final idx = e.key + 1;
              final map = e.value;
              return _buildListItemRow(idx, map['n']!, map['v']!, map['c']!, trendColor);
            }),
        ],
      ),
    );
  }

  Widget _buildNoMilkTodayCard(List<String> list) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bugün Süt Vermeyenler',
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gray800),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Bugün tüm üreticiler süt verdi.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w500),
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: list.length,
                itemBuilder: (context, idx) {
                  final name = list[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(Icons.remove_circle_outline_rounded, color: AppColors.danger, size: 14),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.gray700),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStaffPerformanceCard(String title, List<Map<String, dynamic>> list) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gray800),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Veri bulunamadı.',
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                ),
              ),
            )
          else
            ...list.asMap().entries.map((e) {
              final idx = e.key + 1;
              final map = e.value;
              final double milk = map['milk'];
              final double shortage = map['shortage'];
              final String shortStr = shortage == 0 ? '0 L' : '${shortage > 0 ? "+" : ""}${shortage.toStringAsFixed(1)} L';
              final Color shortColor = shortage > 0 ? AppColors.danger : (shortage < 0 ? AppColors.success : AppColors.gray600);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Text(
                      '$idx',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray400),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.primary100,
                      child: Text(
                        map['p']!,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        map['n']!,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.gray700),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${milk.toStringAsFixed(0)} L',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray800),
                        ),
                        Text(
                          'Fark: $shortStr',
                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w500, color: shortColor),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDonutChartWidget(List<QueryDocumentSnapshot> collections, bool isDesktop) {
    double soguk = 0;
    double sicak = 0;
    double cQuality = 0;
    double dQuality = 0;
    double other = 0;

    for (var doc in collections) {
      final m = doc['m'];
      double val = 0;
      if (m is num) {
        val = m.toDouble();
      } else if (m is String) {
        val = double.tryParse(m) ?? 0.0;
      }

      final tip = (doc.data() as Map<String, dynamic>)['tip'] as String? ?? '';
      final normalized = tip.toLowerCase().trim();
      if (normalized.contains('soğuk') || normalized.contains('soguk') || normalized.contains('so\u011fuk')) {
        soguk += val;
      } else if (normalized.contains('sıcak') || normalized.contains('sicak') || normalized.contains('s\u0131cak')) {
        sicak += val;
      } else if (normalized.contains('c kalite') || normalized == 'c') {
        cQuality += val;
      } else if (normalized.contains('d kalite') || normalized == 'd') {
        dQuality += val;
      } else {
        other += val;
      }
    }

    final double total = soguk + sicak + cQuality + dQuality + other;
    final finalSoguk = soguk + other;

    double pctSoguk = total > 0 ? (finalSoguk / total) * 100 : 0.0;
    double pctSicak = total > 0 ? (sicak / total) * 100 : 0.0;
    double pctC = total > 0 ? (cQuality / total) * 100 : 0.0;
    double pctD = total > 0 ? (dQuality / total) * 100 : 0.0;

    final formatNumber = NumberFormat('#,##0', 'tr_TR');
    String sogukValStr = '${formatNumber.format(finalSoguk)} L';
    String sicakValStr = '${formatNumber.format(sicak)} L';
    String cValStr = '${formatNumber.format(cQuality)} L';
    String dValStr = '${formatNumber.format(dQuality)} L';

    final List<PieChartSectionData> sections = [];
    if (total == 0) {
      sections.add(PieChartSectionData(color: AppColors.gray200, value: 100, showTitle: false, radius: 18));
    } else {
      if (pctSoguk > 0) sections.add(PieChartSectionData(color: AppColors.success, value: pctSoguk, showTitle: false, radius: 18));
      if (pctSicak > 0) sections.add(PieChartSectionData(color: AppColors.primary600, value: pctSicak, showTitle: false, radius: 18));
      if (pctC > 0) sections.add(PieChartSectionData(color: AppColors.warning, value: pctC, showTitle: false, radius: 18));
      if (pctD > 0) sections.add(PieChartSectionData(color: AppColors.danger, value: pctD, showTitle: false, radius: 18));
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Süt Kalite Dağılımı',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gray800),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 36,
                        startDegreeOffset: -90,
                        sections: sections,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDonutLegend('A Kalite', '%${pctSoguk.toStringAsFixed(0)}', sogukValStr, AppColors.success),
                        _buildDonutLegend('B Kalite', '%${pctSicak.toStringAsFixed(0)}', sicakValStr, AppColors.primary600),
                        _buildDonutLegend('C Kalite', '%${pctC.toStringAsFixed(0)}', cValStr, AppColors.warning),
                        _buildDonutLegend('D Kalite', '%${pctD.toStringAsFixed(0)}', dValStr, AppColors.danger),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartWidget(List<QueryDocumentSnapshot> collections, bool isDesktop) {
    final formatNumber = NumberFormat('#,##0', 'tr_TR');
    final now = DateTime.now();
    final List<DateTime> last7Days = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));

    final Map<DateTime, double> dailyTotals = {for (var day in last7Days) day: 0.0};
    
    for (var doc in collections) {
      final data = doc.data() as Map<String, dynamic>;
      final DateTime docDate = getDocDate(data);
      final DateTime docDay = DateTime(docDate.year, docDate.month, docDate.day);
      if (dailyTotals.containsKey(docDay)) {
        final m = data['m'];
        double val = 0;
        if (m is num) {
          val = m.toDouble();
        } else if (m is String) {
          val = double.tryParse(m) ?? 0.0;
        }
        dailyTotals[docDay] = dailyTotals[docDay]! + val;
      }
    }

    double weeklyTotal = dailyTotals.values.fold(0.0, (sum, val) => sum + val);

    final prev7DaysStart = last7Days.first.subtract(const Duration(days: 7));
    final prev7DaysEnd = last7Days.first.subtract(const Duration(days: 1));
    
    double prevWeeklyTotal = 0.0;
    for (var doc in collections) {
      final data = doc.data() as Map<String, dynamic>;
      final DateTime docDate = getDocDate(data);
      final DateTime docDay = DateTime(docDate.year, docDate.month, docDate.day);
      if (docDay.isAfter(prev7DaysStart.subtract(const Duration(microseconds: 1))) &&
          docDay.isBefore(prev7DaysEnd.add(const Duration(days: 1)))) {
        final m = data['m'];
        double val = 0;
        if (m is num) {
          val = m.toDouble();
        } else if (m is String) {
          val = double.tryParse(m) ?? 0.0;
        }
        prevWeeklyTotal += val;
      }
    }
    
    double pctChange = 0.0;
    if (prevWeeklyTotal > 0) {
      pctChange = ((weeklyTotal - prevWeeklyTotal) / prevWeeklyTotal) * 100.0;
    } else if (weeklyTotal > 0) {
      pctChange = 100.0;
    }

    String pctStr = (pctChange >= 0 ? '+' : '') + pctChange.toStringAsFixed(2).replaceAll('.', ',') + '%';
    Color pctColor = pctChange >= 0 ? AppColors.success : AppColors.danger;

    List<String> weekdays = last7Days.map((day) {
      final format = DateFormat('E', 'tr_TR');
      return format.format(day);
    }).toList();

    double maxVal = dailyTotals.values.fold(0.0, (max, val) => val > max ? val : max);
    List<double> barValues = last7Days.map((day) => dailyTotals[day] ?? 0.0).toList();



    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Toplanan Süt Miktarı (Litre)',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gray800),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Toplam ${formatNumber.format(weeklyTotal)} Litre',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        pctStr,
                        style: GoogleFonts.inter(fontSize: 11, color: pctColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              DropdownButton<String>(
                value: '7 Günlük',
                items: const [
                  DropdownMenuItem(value: '7 Günlük', child: Text('7 Günlük')),
                  DropdownMenuItem(value: '30 Günlük', child: Text('30 Günlük')),
                ],
                onChanged: (_) {},
                underline: const SizedBox(),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gray600),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= 0 && idx < weekdays.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(weekdays[idx], style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                      '${rod.toY.toInt()} LT',
                      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
                barGroups: barValues.asMap().entries.map((e) {
                  final idx = e.key;
                  final val = e.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary400, AppColors.primary600],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxVal > 0 ? maxVal * 1.2 : 20000.0,
                          color: AppColors.gray50,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyBarChartWidget(List<QueryDocumentSnapshot> collections, bool isDesktop) {
    final formatNumber = NumberFormat('#,##0', 'tr_TR');
    final now = DateTime.now();
    final List<DateTime> last7Months = List.generate(7, (i) {
      return DateTime(now.year, now.month - (6 - i), 1);
    });

    final Map<String, double> monthlyTotals = {
      for (var m in last7Months) '${m.year}-${m.month}': 0.0
    };
    
    for (var doc in collections) {
      final data = doc.data() as Map<String, dynamic>;
      final DateTime docDate = getDocDate(data);
      final key = '${docDate.year}-${docDate.month}';
      if (monthlyTotals.containsKey(key)) {
        final m = data['m'];
        double val = 0;
        if (m is num) {
          val = m.toDouble();
        } else if (m is String) {
          val = double.tryParse(m) ?? 0.0;
        }
        monthlyTotals[key] = monthlyTotals[key]! + val;
      }
    }

    double monthlyTotalSum = monthlyTotals.values.fold(0.0, (sum, val) => sum + val);

    final prev7Months = List.generate(7, (i) {
      return DateTime(now.year, now.month - (13 - i), 1);
    });
    final Set<String> prevKeys = prev7Months.map((m) => '${m.year}-${m.month}').toSet();
    
    double prevMonthlyTotal = 0.0;
    for (var doc in collections) {
      final data = doc.data() as Map<String, dynamic>;
      final DateTime docDate = getDocDate(data);
      final key = '${docDate.year}-${docDate.month}';
      if (prevKeys.contains(key)) {
        final m = data['m'];
        double val = 0;
        if (m is num) {
          val = m.toDouble();
        } else if (m is String) {
          val = double.tryParse(m) ?? 0.0;
        }
        prevMonthlyTotal += val;
      }
    }
    
    double monthlyPctChange = 0.0;
    if (prevMonthlyTotal > 0) {
      monthlyPctChange = ((monthlyTotalSum - prevMonthlyTotal) / prevMonthlyTotal) * 100.0;
    } else if (monthlyTotalSum > 0) {
      monthlyPctChange = 100.0;
    }

    String monthlyPctStr = (monthlyPctChange >= 0 ? '+' : '') + monthlyPctChange.toStringAsFixed(2).replaceAll('.', ',') + '%';
    Color monthlyPctColor = monthlyPctChange >= 0 ? AppColors.success : AppColors.danger;

    List<String> monthNames = last7Months.map((m) {
      final str = DateFormat('MMM', 'tr_TR').format(m);
      if (str.isEmpty) return '';
      return str[0].toUpperCase() + str.substring(1);
    }).toList();

    double maxMonthlyVal = monthlyTotals.values.fold(0.0, (max, val) => val > max ? val : max);
    List<double> barValues = last7Months.map((m) => monthlyTotals['${m.year}-${m.month}'] ?? 0.0).toList();



    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Toplanan Süt Miktarı (Litre)',
                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gray800),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Toplam ${formatNumber.format(monthlyTotalSum)} Litre',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        monthlyPctStr,
                        style: GoogleFonts.inter(fontSize: 11, color: monthlyPctColor, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              DropdownButton<String>(
                value: '7 Günlük',
                items: const [
                  DropdownMenuItem(value: '7 Günlük', child: Text('7 Günlük')),
                  DropdownMenuItem(value: '30 Günlük', child: Text('30 Günlük')),
                ],
                onChanged: (_) {},
                underline: const SizedBox(),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gray600),
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 180,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final idx = v.toInt();
                        if (idx >= 0 && idx < monthNames.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(monthNames[idx], style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (_, __, rod, ___) => BarTooltipItem(
                      '${rod.toY.toInt()} LT',
                      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
                barGroups: barValues.asMap().entries.map((e) {
                  final idx = e.key;
                  final val = e.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary400, AppColors.primary600],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        width: 20,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxMonthlyVal > 0 ? maxMonthlyVal * 1.2 : 20000.0,
                          color: AppColors.gray50,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );
  }
}
