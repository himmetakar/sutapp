import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import 'firma_personel_ekle.dart';

class FirmaPersonelListesiScreen extends StatefulWidget {
  const FirmaPersonelListesiScreen({super.key});

  @override
  State<FirmaPersonelListesiScreen> createState() => _FirmaPersonelListesiScreenState();
}

class _FirmaPersonelListesiScreenState extends State<FirmaPersonelListesiScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'Personel Listesi',
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
              onTap: () => context.push('/firma/personel/ekle'),
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Personeller ve İzinler',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray800,
                    ),
                  ),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF2563EB),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      onPressed: () => context.push('/firma/atamalar'),
                      icon: const Icon(Icons.sync_alt_rounded, size: 14),
                      label: Text(
                        'Müşteri Atama',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('suruculer')
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
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Kayıtlı personel bulunamadı.',
                        style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 14),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final id = doc.id;

                      final ad = data['ad'] ?? '';
                      final soyad = data['soyad'] ?? '';
                      final name = '$ad $soyad'.trim();
                      final email = data['email'] ?? '';
                      final tel = data['tel'] ?? '';
                      final active = data['active'] as bool? ?? true;

                      final canAddCustomer = data['canAddCustomer'] as bool? ?? true;
                      final canEditCustomer = data['canEditCustomer'] as bool? ?? true;
                      final canCreateOrder = data['canCreateOrder'] as bool? ?? false;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.015),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Avatar circle
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFF6FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.person_rounded,
                                      color: Color(0xFF2563EB),
                                      size: 20,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),

                                // Driver Info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              name,
                                              style: GoogleFonts.inter(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.gray800,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: active ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              active ? 'Aktif' : 'Pasif',
                                              style: GoogleFonts.inter(
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.bold,
                                                color: active ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      // Compact single-line contact info
                                      Row(
                                        children: [
                                          if (tel.isNotEmpty) ...[
                                            const Icon(Icons.phone_android_rounded, size: 10, color: AppColors.gray400),
                                            const SizedBox(width: 3),
                                            Text(tel, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
                                          ],
                                          if (tel.isNotEmpty && email.isNotEmpty) ...[
                                            const SizedBox(width: 8),
                                            Container(width: 3, height: 3, decoration: const BoxDecoration(color: AppColors.gray300, shape: BoxShape.circle)),
                                            const SizedBox(width: 8),
                                          ],
                                          if (email.isNotEmpty) ...[
                                            const Icon(Icons.alternate_email_rounded, size: 10, color: AppColors.gray400),
                                            const SizedBox(width: 3),
                                            Flexible(
                                              child: Text(
                                                email,
                                                style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ]
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),

                                // Actions (Pause, Edit, Delete)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Pause/Suspend Button
                                    GestureDetector(
                                      onTap: () => _toggleActive(id, active),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFEFF6FF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          active ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                          color: const Color(0xFF2563EB),
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Edit Button
                                    GestureDetector(
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FirmaPersonelEkleScreen(
                                              editDriverData: data,
                                              editDriverId: id,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFFF7ED),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.edit_rounded,
                                          color: Color(0xFFF59E0B),
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),

                                    // Delete Button
                                    GestureDetector(
                                      onTap: () => _deleteDriver(id, name),
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFEF2F2),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.delete_rounded,
                                          color: Color(0xFFEF4444),
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            const Divider(color: Color(0xFFF1F5F9), height: 1),
                            const SizedBox(height: 8),

                            // Permission Switches
                            _buildPermissionSwitch(
                              label: 'Müşteri ekleyebilir',
                              value: canAddCustomer,
                              icon: Icons.person_add_rounded,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                FirebaseFirestore.instance.collection('suruculer').doc(id).update({'canAddCustomer': val});
                              },
                            ),
                            _buildPermissionSwitch(
                              label: 'Müşteri düzenleyebilir',
                              value: canEditCustomer,
                              icon: Icons.edit_rounded,
                              activeColor: const Color(0xFF10B981),
                              onChanged: (val) {
                                FirebaseFirestore.instance.collection('suruculer').doc(id).update({'canEditCustomer': val});
                              },
                            ),
                            _buildPermissionSwitch(
                              label: canCreateOrder ? 'Sipariş oluşturabilir' : 'Sipariş oluşturma izni yok',
                              value: canCreateOrder,
                              icon: Icons.shopping_cart_rounded,
                              activeColor: const Color(0xFF10B981),
                              labelColor: canCreateOrder ? AppColors.gray700 : const Color(0xFFEF4444),
                              onChanged: (val) {
                                FirebaseFirestore.instance.collection('suruculer').doc(id).update({'canCreateOrder': val});
                              },
                            ),
                          ],
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

  Widget _buildPermissionSwitch({
    required String label,
    required bool value,
    required IconData icon,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
    Color? labelColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 15,
            color: value ? activeColor : (labelColor ?? AppColors.gray400),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: labelColor ?? AppColors.gray700,
              ),
            ),
          ),
          SizedBox(
            height: 28,
            child: Transform.scale(
              scale: 0.75,
              child: Switch(
                value: value,
                activeColor: activeColor,
                activeTrackColor: activeColor.withValues(alpha: 0.2),
                inactiveThumbColor: AppColors.gray400,
                inactiveTrackColor: AppColors.gray200,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(String docId, bool currentStatus) async {
    try {
      await FirebaseFirestore.instance.collection('suruculer').doc(docId).update({'active': !currentStatus});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentStatus ? 'Personel pasif duruma getirildi.' : 'Personel aktif duruma getirildi.'),
            backgroundColor: AppColors.success,
          ),
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

  Future<void> _deleteDriver(String docId, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Personel Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('$name isimli personeli silmek istediğinize emin misiniz?'),
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
        await FirebaseFirestore.instance.collection('suruculer').doc(docId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Personel başarıyla silindi.'), backgroundColor: AppColors.success),
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
