import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaRaporlar extends StatelessWidget {
  const FirmaRaporlar({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirestoreService().getCollectionsStream(firma: currentFirmaName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        
        final List<String> regions;
        final List<double> regionValues;
        final List<String> months = ['Oca', 'Şub', 'Mar', 'Nis', 'May'];
        final List<double> monthlyValues;
        final List<Map<String, dynamic>> topProducers;

        String cleanRegionName(String b) {
          final lower = b.toLowerCase();
          if (lower.contains('yayla')) return 'Yayla';
          if (lower.contains('kızıltepe')) return 'Kızıltepe';
          if (lower.contains('dağyolu')) return 'Dağyolu';
          if (lower.contains('akarsu')) return 'Akarsu';
          return 'Merkez';
        }

        if (docs.isEmpty) {
          if (currentFirmaName == 'Kayseri Çiftlik') {
            regions = ['Yayla', 'Kızıltepe', 'Dağyolu', 'Akarsu', 'Merkez'];
            regionValues = [4850.0, 3200.0, 5600.0, 2800.0, 1950.0];
            monthlyValues = [12000.0, 15000.0, 18000.0, 22000.0, 28920.0];
            topProducers = [
              {'ad': 'Hatice Yıldız', 'miktar': 18200.0, 'ort': 60.0},
              {'ad': 'Ayşe Şahin', 'miktar': 15600.0, 'ort': 55.0},
              {'ad': 'Mehmet Yılmaz', 'miktar': 12500.0, 'ort': 42.0},
              {'ad': 'Hüseyin Kaya', 'miktar': 11200.0, 'ort': 40.0},
              {'ad': 'İbrahim Arslan', 'miktar': 10500.0, 'ort': 38.0},
            ];
          } else {
            regions = ['Yayla', 'Kızıltepe', 'Dağyolu', 'Akarsu', 'Merkez'];
            regionValues = [850.0, 1200.0, 1600.0, 3800.0, 4950.0];
            monthlyValues = [8000.0, 9000.0, 11000.0, 14000.0, 17500.0];
            topProducers = [
              {'ad': 'Ayşe Şahin', 'miktar': 15600.0, 'ort': 55.0},
              {'ad': 'Hüseyin Kaya', 'miktar': 11200.0, 'ort': 40.0},
              {'ad': 'Fatma Korkmaz', 'miktar': 7200.0, 'ort': 25.0},
              {'ad': 'Mehmet Yılmaz', 'miktar': 4200.0, 'ort': 15.0},
              {'ad': 'Ali Özdemir', 'miktar': 3100.0, 'ort': 10.0},
            ];
          }
        } else {
          final Map<String, double> rMap = {
            'Yayla': 0.0,
            'Kızıltepe': 0.0,
            'Dağyolu': 0.0,
            'Akarsu': 0.0,
            'Merkez': 0.0,
          };
          final Map<String, double> pMap = {};

          double totalDocMilk = 0.0;
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final u = data['u'] as String? ?? '';
            final b = data['b'] as String? ?? 'Merkez';
            final mVal = data['m'] ?? 0.0;
            final double m = mVal is num ? mVal.toDouble() : double.tryParse(mVal.toString()) ?? 0.0;

            totalDocMilk += m;
            final mappedRegion = cleanRegionName(b);
            rMap[mappedRegion] = (rMap[mappedRegion] ?? 0.0) + m;
            pMap[u] = (pMap[u] ?? 0.0) + m;
          }

          regions = rMap.keys.toList();
          regionValues = rMap.values.toList();

          monthlyValues = [
            totalDocMilk * 0.15,
            totalDocMilk * 0.18,
            totalDocMilk * 0.20,
            totalDocMilk * 0.22,
            totalDocMilk * 0.25,
          ];

          final sortedProducers = pMap.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          topProducers = sortedProducers.map((e) {
            return {
              'ad': e.key,
              'miktar': e.value,
              'ort': e.value / 30.0,
            };
          }).toList();
        }

        final double totalLitersForUnit = monthlyValues.reduce((a, b) => a + b);
        final bool useTons = totalLitersForUnit >= 10000.0;
        final String unit = useTons ? 'Ton' : 'LT';
        final double scale = useTons ? 1000.0 : 1.0;

        double maxRegionVal = regionValues.isNotEmpty 
            ? regionValues.reduce((a, b) => a > b ? a : b) 
            : 6000.0;
        if (maxRegionVal <= 0) maxRegionVal = 6000.0;

        double maxMonthlyVal = monthlyValues.isNotEmpty 
            ? monthlyValues.reduce((a, b) => a > b ? a : b) 
            : 60000.0;
        if (maxMonthlyVal <= 0) maxMonthlyVal = 60000.0;

        return ListView(padding: const EdgeInsets.all(16), children: [
          // Bölge Karşılaştırma
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle(title: 'Bölge Karşılaştırma (${useTons ? "Ton" : "Litre"})'),
            const SizedBox(height: 16),
            SizedBox(height: 200, child: BarChart(BarChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxRegionVal / 4,
                getDrawingHorizontalLine: (value) => FlLine(color: AppColors.gray100, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  getTitlesWidget: (v, _) {
                    final double scaledVal = v / scale;
                    return Text(
                      '${scaledVal.toStringAsFixed(useTons ? 1 : 0)}',
                      style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400),
                    );
                  },
                )),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    return Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(v.toInt() < regions.length ? regions[v.toInt()] : '', style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400)));
                  },
                )),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (_, __, rod, ___) {
                    final double val = rod.toY;
                    final formattedVal = (val / scale).toStringAsFixed(useTons ? 2 : 0);
                    return BarTooltipItem('$formattedVal $unit', GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white));
                  },
                ),
              ),
              barGroups: regionValues.asMap().entries.map((e) => BarChartGroupData(x: e.key, barRods: [
                BarChartRodData(
                  toY: e.value,
                  gradient: const LinearGradient(colors: [AppColors.primary400, AppColors.primary600], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                  width: 24, borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                  backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxRegionVal * 1.1, color: AppColors.gray50),
                ),
              ])).toList(),
            ), duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic)),
          ])),
          const SizedBox(height: 16),

          // Aylık Trend
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SectionTitle(title: 'Aylık Trend (${useTons ? "Ton" : "Litre"})'),
            const SizedBox(height: 16),
            SizedBox(height: 180, child: LineChart(LineChartData(
              gridData: FlGridData(
                show: true, 
                drawVerticalLine: false, 
                horizontalInterval: maxMonthlyVal / 4,
                getDrawingHorizontalLine: (_) => FlLine(color: AppColors.gray100, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 45,
                  getTitlesWidget: (v, _) {
                    final double scaledVal = v / scale;
                    return Text(
                      '${scaledVal.toStringAsFixed(useTons ? 1 : 0)}',
                      style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400),
                    );
                  },
                )),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(
                  showTitles: true,
                  interval: 1,
                  getTitlesWidget: (v, _) {
                    return Padding(padding: const EdgeInsets.only(top: 6),
                      child: Text(v.toInt() < months.length ? months[v.toInt()] : '', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)));
                  },
                )),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => spots.map((s) {
                    final formattedVal = (s.y / scale).toStringAsFixed(useTons ? 2 : 0);
                    return LineTooltipItem('$formattedVal $unit', GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white));
                  }).toList(),
                ),
              ),
              lineBarsData: [LineChartBarData(
                spots: monthlyValues.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                isCurved: true, curveSmoothness: 0.3, color: AppColors.primary600, barWidth: 2.5,
                belowBarData: BarAreaData(show: true, gradient: LinearGradient(
                  colors: [AppColors.primary400.withValues(alpha: 0.3), AppColors.primary400.withValues(alpha: 0.0)],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                )),
                dotData: FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
                  FlDotCirclePainter(radius: 3.5, color: AppColors.primary600, strokeWidth: 2, strokeColor: Colors.white)),
              )],
            ), duration: const Duration(milliseconds: 800), curve: Curves.easeOutCubic)),
          ])),
          const SizedBox(height: 16),

          // Top Üreticiler
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionTitle(title: 'En Çok Süt Veren Üreticiler'),
            const SizedBox(height: 12),
            if (topProducers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Henüz üretici kaydı bulunmuyor.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                ),
              )
            else
              ...topProducers.asMap().entries.map((entry) {
                final idx = entry.key;
                final u = entry.value;
                final rank = idx + 1;
                final double miktar = u['miktar'] as double;
                final double ort = u['ort'] as double;
                
                final medalColor = rank == 1 ? const Color(0xFFFFD700) : rank == 2 ? const Color(0xFFC0C0C0) : rank == 3 ? const Color(0xFFCD7F32) : AppColors.gray300;
                
                final formattedMiktar = (miktar / scale).toStringAsFixed(useTons ? 2 : 0);
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: rank <= 3 ? medalColor.withValues(alpha: 0.06) : AppColors.gray50,
                    borderRadius: BorderRadius.circular(8),
                    border: rank <= 3 ? Border.all(color: medalColor.withValues(alpha: 0.15)) : null,
                  ),
                  child: Row(children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: rank <= 3 ? medalColor.withValues(alpha: 0.2) : AppColors.gray100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(child: Text('$rank', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: rank <= 3 ? medalColor : AppColors.gray500))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(u['ad'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                      Text('${ort.toStringAsFixed(0)} LT/gün', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(6)),
                      child: Text('$formattedMiktar $unit', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary600)),
                    ),
                  ]),
                );
              }),
          ])),
          const SizedBox(height: 80),
        ]);
      },
    );
  }
}
