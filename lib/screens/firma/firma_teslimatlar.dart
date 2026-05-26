import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common_widgets.dart';

class FirmaTeslimatlar extends StatelessWidget {
  const FirmaTeslimatlar({super.key});
  static final _data = [
    {'km': '38 AB 123', 'sr': 'Ahmet Kara', 'toplanan': 520, 'teslim': 515, 'fark': 5, 'tarih': '25.05.2026', 'saat': '17:30'},
    {'km': '38 CD 456', 'sr': 'Veli Yıldız', 'toplanan': 850, 'teslim': 842, 'fark': 8, 'tarih': '25.05.2026', 'saat': '17:45'},
    {'km': '38 GH 012', 'sr': 'Hasan Çelik', 'toplanan': 1200, 'teslim': 1188, 'fark': 12, 'tarih': '25.05.2026', 'saat': '18:00'},
  ];

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      floatingActionButton: AppFab(icon: Icons.add_rounded, label: 'Teslimat Yap', onTap: () {}),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('tanklar')
              .where('firma', isEqualTo: currentFirmaName)
              .where('tip', isEqualTo: 'merkez')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const AppCard(
                child: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final tanks = snapshot.data?.docs ?? [];
            if (tanks.isEmpty) {
              return const AppCard(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Kayıtlı merkez tankı bulunamadı.',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ),
                ),
              );
            }

            return AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(title: 'Merkez Tank Durumu'),
                  const SizedBox(height: 12),
                  ...tanks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final doc = entry.value;
                    final data = doc.data() as Map<String, dynamic>;
                    final String ad = data['ad'] ?? data['tankAdi'] ?? 'Merkez Tankı';
                    final double stok = (data['stok'] ?? data['currentStock'] ?? 0.0).toDouble();
                    final double kapasite = (data['kap'] ?? data['kapasite'] ?? 10000.0).toDouble();

                    return Column(
                      children: [
                        StockGauge(
                          current: stok,
                          capacity: kapasite,
                          label: ad,
                        ),
                        if (index < tanks.length - 1) const SizedBox(height: 12),
                      ],
                    );
                  }),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        const SectionTitle(title: 'Teslimat Geçmişi'),
        ..._data.map((t) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.sm),
          child: Column(children: [
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t['km']} • ${t['sr']}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                Text('${t['tarih']} ${t['saat']}', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
              ])),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              _box('Toplanan', '${t['toplanan']} LT', AppColors.primary600),
              const SizedBox(width: 8),
              _box('Teslim', '${t['teslim']} LT', AppColors.success),
              const SizedBox(width: 8),
              _box('Fire', '${t['fark']} LT', AppColors.danger),
            ]),
          ]),
        )),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _box(String label, String value, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color.withValues(alpha: 0.08), color.withValues(alpha: 0.03)]),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(children: [
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: color.withValues(alpha: 0.7))),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    ));
  }
}
