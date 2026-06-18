import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import 'firma_arac_ekle.dart';

class FirmaAracListesiScreen extends StatefulWidget {
  const FirmaAracListesiScreen({super.key});

  @override
  State<FirmaAracListesiScreen> createState() => _FirmaAracListesiScreenState();
}

class _FirmaAracListesiScreenState extends State<FirmaAracListesiScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'Araç Listesi',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/personel'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () => context.push('/firma/araclar/ekle'),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('araclar')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Hata: ${snapshot.error}'));
            }

            final docs = snapshot.data?.docs ?? [];
            final bool isWeb = MediaQuery.of(context).size.width > 750;

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  'Kayıtlı araç bulunamadı.',
                  style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 14),
                ),
              );
            }

            Widget buildVehicleCard(QueryDocumentSnapshot doc) {
              final v = doc.data() as Map<String, dynamic>;

              final String plaka = v['plaka'] ?? '';
              final String model = v['model'] ?? 'Bilinmiyor';
              final int yil = v['yil'] ?? 0;
              final bool active = v['active'] as bool? ?? true;
              final String label = v['ad'] ?? v['aracAdi'] ?? plaka;

              // Extract capacity
              double capacity = 0.0;
              if (v['kapasite'] != null) {
                capacity = (v['kapasite'] as num).toDouble();
              } else {
                final tankList = v['tanklar'] as List?;
                if (tankList != null && tankList.isNotEmpty) {
                  capacity = (tankList.first['kap'] as num).toDouble();
                }
              }

              return Container(
                margin: isWeb ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.gray200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.gray800,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                plaka,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: active ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                active ? Icons.check : Icons.close,
                                size: 11,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                active ? 'Aktif' : 'Pasif',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: AppColors.gray200, height: 1),
                    const SizedBox(height: 12),

                    // Details
                    _buildDetailRow(Icons.directions_car_filled_rounded, 'Model:', model),
                    const SizedBox(height: 6),
                    _buildDetailRow(Icons.calendar_month_rounded, 'Yıl:', yil > 0 ? '$yil' : '-'),
                    const SizedBox(height: 6),
                    _buildDetailRow(Icons.water_drop_rounded, 'Kapasite:', '${capacity.toStringAsFixed(0)} L'),
                    const SizedBox(height: 14),

                    // Actions (Edit, Delete)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF2563EB),
                                side: const BorderSide(color: Color(0xFF2563EB)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => FirmaAracEkleScreen(
                                      editVehicleData: v,
                                      editVehicleId: doc.id,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.edit_rounded, size: 14),
                              label: Text(
                                'Düzenle',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                                side: const BorderSide(color: Color(0xFFFCA5A5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _deleteVehicle(doc.id, plaka, currentFirmaName),
                              icon: const Icon(Icons.delete_rounded, size: 14),
                              label: Text(
                                'Sil',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            if (isWeb) {
              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  mainAxisExtent: 220,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  return buildVehicleCard(docs[index]);
                },
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                return buildVehicleCard(docs[index]);
              },
            );
          },
        ),
            ),
          ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.gray400),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray800, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Future<void> _deleteVehicle(String docId, String plaka, String firmaName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Aracı Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('$plaka plakalı aracı silmek istediğinize emin misiniz? Bu işlem tank bağlantısını da silecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('araclar').doc(docId).delete();

        // Also delete tank in tanklar collection
        final tankQuery = await FirebaseFirestore.instance
            .collection('tanklar')
            .where('arac', isEqualTo: plaka)
            .where('firma', isEqualTo: firmaName)
            .limit(1)
            .get();

        for (var doc in tankQuery.docs) {
          await doc.reference.delete();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Araç ve ilişkili tank silindi.'), backgroundColor: AppColors.success),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }
}
