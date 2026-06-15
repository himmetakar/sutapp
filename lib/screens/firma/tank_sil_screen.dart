import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class TankSilScreen extends StatefulWidget {
  const TankSilScreen({super.key});

  @override
  State<TankSilScreen> createState() => _TankSilScreenState();
}

class _TankSilScreenState extends State<TankSilScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isDeleting = false;
  String? _selectedTankId;

  Future<void> _deleteTank(QueryDocumentSnapshot tankDoc) async {
    final data = tankDoc.data() as Map<String, dynamic>;
    final tankAd = data['ad'] ?? '';
    final double stok = (data['stok'] as num?)?.toDouble() ?? 0.0;

    // 1 LT eşiği: küçük float hatalarını görmezden gel
    if (stok >= 1.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '"$tankAd" tankında ${stok.toStringAsFixed(0)} LT süt bulunuyor. Önce tankı boşaltın.',
          ),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            const SizedBox(width: 8),
            Text(
              'Tankı Sil',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"$tankAd" tankını silmek istediğinize emin misiniz?',
              style: GoogleFonts.inter(fontSize: 14, color: AppColors.gray700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu işlem geri alınamaz! Tank ve ilgili tüm kayıtlar silinecektir.',
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final batch = _db.batch();

      // 1. Tank dökümanını sil
      batch.delete(tankDoc.reference);

      // 2. Araca bağlıysa araçtaki tanklar dizisinden çıkar
      final arac = data['arac'] as String? ?? '';
      if (arac.isNotEmpty) {
        final vehicleQuery = await _db
            .collection('araclar')
            .where('plaka', isEqualTo: arac)
            .limit(1)
            .get();
        if (vehicleQuery.docs.isNotEmpty) {
          final vDoc = vehicleQuery.docs.first;
          final vData = vDoc.data();
          final currentTanks =
              List<Map<String, dynamic>>.from(vData['tanklar'] ?? []);
          // Ada göre sil — ID yoksa ad karşılaştırması daha güvenli
          currentTanks.removeWhere((t) =>
              (t['ad'] as String? ?? '').trim().toLowerCase() ==
              tankAd.trim().toLowerCase());
          batch.update(vDoc.reference, {'tanklar': currentTanks});
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ "$tankAd" tankı başarıyla silindi.'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[TankSil] HATA: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // Firma adı: displayName ya da mahalleKoy (sürücüler için firma adı burada)
    final tenantFirma = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'Tank Sil',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db
                    .collection('tanklar')
                    .where('firma', isEqualTo: tenantFirma)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.propane_tank_rounded,
                              size: 64, color: AppColors.gray300),
                          const SizedBox(height: 16),
                          Text(
                            'Silinecek tank bulunamadı.',
                            style: GoogleFonts.inter(
                                color: AppColors.gray400, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }

                  // Separate by type
                  final merkezTanks = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return (data['tip'] ?? 'merkez') == 'merkez';
                  }).toList();
                  final aracTanks = docs.where((d) {
                    final data = d.data() as Map<String, dynamic>;
                    return (data['tip'] ?? 'merkez') == 'arac';
                  }).toList();

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Warning banner
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFCA5A5)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Silmek istediğiniz tankın stok miktarı 0 olmalıdır. Dolu tanklar silinemez.',
                                style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),

                      if (merkezTanks.isNotEmpty) ...[
                        _buildSectionHeader('Merkez Tankları', merkezTanks.length),
                        const SizedBox(height: 10),
                        ...merkezTanks.map((doc) => _buildTankCard(doc)),
                        const SizedBox(height: 24),
                      ],

                      if (aracTanks.isNotEmpty) ...[
                        _buildSectionHeader('Araç Tankları', aracTanks.length),
                        const SizedBox(height: 10),
                        ...aracTanks.map((doc) => _buildTankCard(doc)),
                      ],
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Row(
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.gray800,
          ),
        ),
        const SizedBox(width: 8),
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

  Widget _buildTankCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String ad = data['ad'] ?? '';
    final double stok = (data['stok'] as num?)?.toDouble() ?? 0.0;
    final double kap = (data['kap'] as num?)?.toDouble() ?? 2000.0;
    final String tip = data['tip'] ?? 'merkez';
    final String arac = data['arac'] ?? '';
    final double fillPercent = kap > 0 ? (stok / kap) : 0.0;
    final bool isEmpty = stok <= 0;

    Color gaugeColor = const Color(0xFF3B82F6);
    if (fillPercent >= 0.8) {
      gaugeColor = const Color(0xFFEF4444);
    } else if (fillPercent >= 0.5) {
      gaugeColor = const Color(0xFFF59E0B);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEmpty ? AppColors.gray200 : const Color(0xFFFCA5A5),
          width: isEmpty ? 1 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isEmpty
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.propane_tank_rounded,
              color: isEmpty ? const Color(0xFF3B82F6) : Colors.red,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tip == 'merkez'
                      ? 'Merkez Tankı'
                      : (arac.isNotEmpty ? 'Araç: $arac' : 'Araç Tankı'),
                  style: GoogleFonts.inter(
                      fontSize: 10, color: AppColors.gray400),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fillPercent.clamp(0.0, 1.0),
                          minHeight: 6,
                          backgroundColor: AppColors.gray100,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(gaugeColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${stok.toStringAsFixed(0)}/${kap.toStringAsFixed(0)} LT',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isEmpty ? AppColors.gray500 : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: isEmpty ? () => _deleteTank(doc) : null,
            icon: const Icon(Icons.delete_outline_rounded, size: 14),
            label: Text(
              'Sil',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isEmpty ? Colors.red : AppColors.gray200,
              foregroundColor: isEmpty ? Colors.white : AppColors.gray400,
              disabledBackgroundColor: AppColors.gray100,
              disabledForegroundColor: AppColors.gray400,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }
}
