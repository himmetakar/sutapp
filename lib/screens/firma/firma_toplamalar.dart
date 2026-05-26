import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class FirmaToplamalar extends StatelessWidget {
  const FirmaToplamalar({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: firestoreService.getCollectionsStream(firma: currentFirmaName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
          docs.sort((a, b) {
            final aTime = (a.data() as Map)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map)['timestamp'] as Timestamp?;
            if (aTime == null) return -1;
            if (bTime == null) return 1;
            return bTime.compareTo(aTime);
          });
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.water_drop_outlined, size: 64, color: AppColors.gray400),
                  const SizedBox(height: 16),
                  Text(
                    'Henüz süt toplama kaydı bulunmuyor.',
                    style: GoogleFonts.inter(fontSize: 16, color: AppColors.gray500, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            );
          }

          // Calculate total milk
          double toplam = 0.0;
          for (var doc in docs) {
            final m = doc['m'];
            if (m is num) {
              toplam += m.toDouble();
            } else if (m is String) {
              toplam += double.tryParse(m) ?? 0.0;
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Bugün toplam
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.blue,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.water_drop_rounded, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bugün Toplam', style: GoogleFonts.inter(fontSize: 12, color: Colors.white70)),
                        Text('${toplam.toStringAsFixed(0)} LT', style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white)),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${docs.length} kayıt', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              ...docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final u = data['u'] ?? '-';
                final sr = data['sr'] ?? 'Yönetici';
                final km = data['km'] ?? '-';
                final mVal = data['m'] ?? 0;
                final mStr = mVal is num ? mVal.toStringAsFixed(0) : mVal.toString();
                final s = data['s'] ?? '';
                final b = data['b'] ?? 'Merkez';
                final sync = data['sync'] ?? true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            u.isNotEmpty ? u[0] : 'U',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(u, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                            Row(
                              children: [
                                Text('$sr • $km', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
                                const SizedBox(width: 6),
                                Icon(
                                  sync ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                  size: 11,
                                  color: sync ? AppColors.success : AppColors.warning,
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                StatusBadge.info(b),
                                const SizedBox(width: 6),
                                Text(s, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$mStr LT',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }
}
