import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaFireTakip extends StatelessWidget {
  const FirmaFireTakip({super.key});
  static final _data = [
    {'km': '38 AB 123', 'sr': 'Ahmet Kara', 'toplanan': 12500, 'teslim': 12350, 'fark': 150, 'oran': 1.2},
    {'km': '38 CD 456', 'sr': 'Veli Yıldız', 'toplanan': 9800, 'teslim': 9720, 'fark': 80, 'oran': 0.8},
    {'km': '38 EF 789', 'sr': 'Ali Demir', 'toplanan': 7200, 'teslim': 7050, 'fark': 150, 'oran': 2.1},
    {'km': '38 GH 012', 'sr': 'Hasan Çelik', 'toplanan': 15800, 'teslim': 15600, 'fark': 200, 'oran': 1.3},
    {'km': '38 IJ 345', 'sr': 'Murat Aydın', 'toplanan': 5600, 'teslim': 5420, 'fark': 180, 'oran': 3.2},
  ];

  @override
  Widget build(BuildContext context) {
    final toplamFire = _data.fold<int>(0, (sum, e) => sum + (e['fark'] as int));
    final ortFire = _data.fold<double>(0, (sum, e) => sum + (e['oran'] as double)) / _data.length;
    return ListView(padding: const EdgeInsets.all(16), children: [
      StatsGrid(children: [
        StatCard(icon: Icons.warning_amber_rounded, value: '$toplamFire LT', label: 'Toplam Fire', color: AppColors.danger),
        StatCard(icon: Icons.percent_rounded, value: '%${ortFire.toStringAsFixed(1)}', label: 'Ortalama', color: AppColors.warning),
      ]),
      const SizedBox(height: 16),
      const SectionTitle(title: 'Araç Bazlı Fire'),
      ..._data.map((f) {
        final oran = f['oran'] as double;
        final status = oran <= 1.0 ? 'ok' : oran <= 2.0 ? 'warn' : 'bad';
        final Color sColor = status == 'bad' ? AppColors.danger : status == 'warn' ? AppColors.warning : AppColors.success;
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.sm,
            border: status == 'bad' ? Border.all(color: AppColors.danger.withValues(alpha: 0.2)) : null,
          ),
          child: Column(children: [
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [sColor.withValues(alpha: 0.15), sColor.withValues(alpha: 0.08)]),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.local_shipping_rounded, color: sColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${f['km']}', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                Text('${f['sr']}', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: sColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text('% ${f['oran']}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: sColor)),
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Text('Toplanan: ${f['toplanan']} LT', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
              const Spacer(),
              Text('Fire: ${f['fark']} LT', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: sColor)),
            ]),
          ]),
        );
      }),
      const SizedBox(height: 80),
    ]);
  }
}
