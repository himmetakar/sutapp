import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../widgets/common_widgets.dart';
import '../../widgets/sut_analiz_dialog.dart';
import '../../services/firestore_service.dart';

class SutKabulScreen extends StatefulWidget {
  const SutKabulScreen({super.key});

  @override
  State<SutKabulScreen> createState() => _SutKabulScreenState();
}

class _SutKabulScreenState extends State<SutKabulScreen> {
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    if (!AppConstants.isProduction) {
      _initializeKabulData();
    }
  }

  Future<void> _initializeKabulData() async {
    final db = FirebaseFirestore.instance;
    final snap = await db.collection('sut_kabul').limit(1).get();
    if (snap.docs.isEmpty) {
      // Seed mockup data matching the screenshots
      await db.collection('sut_kabul').add({
        'email': 'cano@cano.com',
        'tarih': '12 May 2026 23:09',
        'kaynak': 'cano1',
        'hedef': 'Merkez Tank #1',
        'miktar': 1870.0,
        'durum': 'Bekliyor',
        'aciklama': '3.göz',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await db.collection('sut_kabul').add({
        'email': 'durmus@demir.com',
        'tarih': '12 May 2026 00:09',
        'kaynak': 'durmus_tank',
        'hedef': 'Firma 1 Merkez Tankı',
        'miktar': 1035.0,
        'durum': 'Bekliyor',
        'aciklama': '2.göz',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _handleAccept(QueryDocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
    final String kaynak = data['kaynak'] ?? '';
    final String hedef = data['hedef'] ?? '';
    final String email = data['email'] ?? '';
    final String plaka = data['plaka'] ?? '';
    final String surucuName = data['surucuName'] ?? email;

    try {
      final fs = FirestoreService();
      await fs.transferTankStock(
        sutKabulId: doc.id,
        sourceTankName: kaynak,
        targetTankName: hedef,
        miktar: miktar,
        vehiclePlate: plaka,
        driverName: surucuName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$surucuName tarafından gönderilen $miktar LT süt kabul edildi!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.pop(),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.primary600),
                  const SizedBox(width: 4),
                  Text(
                    'Geri',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        title: Text(
          'Süt Kabul',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              setState(() => _isRefreshing = true);
              await Future.delayed(const Duration(milliseconds: 600));
              setState(() => _isRefreshing = false);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sut_kabul')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isRefreshing) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          
          // Compute counters dynamically
          int bekleyenCount = 0;
          int kabulEdilenCount = 0;
          int farkVarCount = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final String durum = data['durum'] ?? 'Bekliyor';
            if (durum == 'Bekliyor') {
              bekleyenCount++;
            } else if (durum == 'Kabul Edildi') {
              kabulEdilenCount++;
            } else if (durum == 'Reddedildi' || durum == 'Fark Var') {
              farkVarCount++;
            }
          }

          return Column(
            children: [
              // Metrics Panel
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppShadows.sm,
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.access_time_filled_rounded, color: Color(0xFFF59E0B), size: 20),
                            const SizedBox(height: 6),
                            Text(
                              '$bekleyenCount',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                            ),
                            Text(
                              'Bekleyen',
                              style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppShadows.sm,
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                            const SizedBox(height: 6),
                            Text(
                              '$kabulEdilenCount',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                            ),
                            Text(
                              'Kabul Edilen',
                              style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppShadows.sm,
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.warning_rounded, color: Color(0xFFEF4444), size: 20),
                            const SizedBox(height: 6),
                            Text(
                              '$farkVarCount',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                            ),
                            Text(
                              'Fark Var',
                              style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Acceptance Card List
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Text(
                          'Kabul bekleyen süt kaydı bulunmuyor.',
                          style: GoogleFonts.inter(color: AppColors.gray500),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String email = data['email'] ?? '';
                          final String date = data['tarih'] ?? '';
                          final String src = data['kaynak'] ?? '';
                          final String dest = data['hedef'] ?? '';
                          final double amount = (data['miktar'] as num?)?.toDouble() ?? 0.0;
                          final String status = data['durum'] ?? 'Bekliyor';
                          final String comment = data['aciklama'] ?? '';

                          final isPending = status == 'Bekliyor';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.gray200),
                              boxShadow: AppShadows.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Driver & Time
                                Row(
                                  children: [
                                    const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.gray400),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            email,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13.5,
                                              color: AppColors.gray800,
                                            ),
                                          ),
                                          Text(
                                            date,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: AppColors.gray400,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    StatusBadge(
                                      label: status,
                                      color: Colors.white,
                                      bgColor: isPending ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                
                                // Source -> Target Tank
                                Row(
                                  children: [
                                    const Icon(Icons.storage_rounded, size: 15, color: Color(0xFF3B82F6)),
                                    const SizedBox(width: 4),
                                    Text(
                                      src,
                                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.gray700),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.gray400),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.storage_rounded, size: 15, color: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      dest,
                                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.gray700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Declared amount box
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: AppColors.gray50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Beyan Edilen:',
                                        style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.gray500, fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '${amount.toStringAsFixed(1)} L',
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                      ),
                                    ],
                                  ),
                                ),

                                // Comment box if available
                                if (comment.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.description_outlined, size: 13, color: Color(0xFFD97706)),
                                        const SizedBox(width: 6),
                                        Text(
                                          comment,
                                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFD97706)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],

                                 // Approve/Reject buttons if Pending
                                 if (isPending) ...[
                                   const SizedBox(height: 14),
                                   SizedBox(
                                     width: double.infinity,
                                     child: OutlinedButton.icon(
                                       onPressed: () {
                                         SutAnalizDialog.show(
                                           context,
                                           targetName: dest,
                                           tip: 'Tank',
                                         );
                                       },
                                       icon: const Icon(Icons.science_rounded, size: 16),
                                       label: Text(
                                         'Analiz Ekle',
                                         style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                       ),
                                       style: OutlinedButton.styleFrom(
                                         side: const BorderSide(color: AppColors.primary600),
                                         foregroundColor: AppColors.primary600,
                                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                       ),
                                     ),
                                   ),
                                   const SizedBox(height: 10),
                                   Row(
                                     children: [
                                       Expanded(
                                         child: OutlinedButton(
                                           onPressed: () async {
                                             final String surucuName = data['surucuName'] ?? email;
                                             final String kaynak = data['kaynak'] ?? '';
                                             final String hedef = data['hedef'] ?? '';
                                             try {
                                               final fs = FirestoreService();
                                               await fs.rejectTankUnload(
                                                 doc.id,
                                                 surucuName,
                                                 kaynak,
                                                 hedef,
                                               );
                                               if (context.mounted) {
                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                   const SnackBar(
                                                     content: Text('Talebi reddettiniz.'),
                                                     backgroundColor: AppColors.danger,
                                                   ),
                                                 );
                                               }
                                             } catch (e) {
                                               if (context.mounted) {
                                                 ScaffoldMessenger.of(context).showSnackBar(
                                                   SnackBar(content: Text('Hata: $e')),
                                                 );
                                               }
                                             }
                                           },
                                           style: OutlinedButton.styleFrom(
                                             side: const BorderSide(color: AppColors.gray300),
                                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                           ),
                                           child: Text('Reddet', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger)),
                                         ),
                                       ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => _handleAccept(doc),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF10B981),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            elevation: 0,
                                          ),
                                          child: Text('Kabul Et', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
