import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaAtamalarScreen extends StatefulWidget {
  const FirmaAtamalarScreen({super.key});

  @override
  State<FirmaAtamalarScreen> createState() => _FirmaAtamalarScreenState();
}

class _FirmaAtamalarScreenState extends State<FirmaAtamalarScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _showAddAssignmentDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Fetch lists
    final driversQuery = await _db.collection('suruculer').where('firma', isEqualTo: currentFirmaName).get();
    final drivers = driversQuery.docs.map((d) {
      final data = d.data();
      return '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'.trim();
    }).where((d) => d.isNotEmpty).toList();

    final producersQuery = await _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).get();
    final producers = producersQuery.docs.map((p) => p.data()['name'] as String? ?? '').where((p) => p.isNotEmpty).toList();

    final groupsQuery = await _db.collection('musteri_gruplari').where('firma', isEqualTo: currentFirmaName).get();
    final groups = groupsQuery.docs.map((g) => g.data()['ad'] as String? ?? '').where((g) => g.isNotEmpty).toList();

    if (drivers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Atama yapmak için önce en az bir Toplayıcı/Sürücü eklemelisiniz!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedDriver = drivers.first;
        String selectedTargetType = 'Müşteri'; // Müşteri, Grup
        List<String> selectedTargets = [];
        bool isLoading = false;

        return StatefulBuilder(
          builder: (context, setState) {
            if (isLoading) {
              return const AlertDialog(
                content: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            final targetItems = selectedTargetType == 'Müşteri' ? producers : groups;

            return AlertDialog(
              title: Text('Yeni Atama Yap', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Toplayıcı / Sürücü', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedDriver,
                      items: drivers.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) => setState(() => selectedDriver = val),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(height: 12),
                    Text('Atama Türü', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Müşteri'),
                            value: 'Müşteri',
                            groupValue: selectedTargetType,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  selectedTargetType = val;
                                  selectedTargets.clear();
                                });
                              }
                            },
                          ),
                        ),
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Grup'),
                            value: 'Grup',
                            groupValue: selectedTargetType,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  selectedTargetType = val;
                                  selectedTargets.clear();
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      selectedTargetType == 'Müşteri' ? 'Müşterileri Seçin' : 'Müşteri Gruplarını Seçin',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500),
                    ),
                    const SizedBox(height: 6),
                    if (targetItems.isEmpty)
                      Text(
                        selectedTargetType == 'Müşteri' ? 'Kayıtlı müşteri bulunamadı.' : 'Kayıtlı grup bulunamadı.',
                        style: GoogleFonts.inter(color: AppColors.danger, fontSize: 12),
                      )
                    else ...[
                      CheckboxListTile(
                        title: Text('Tümünü Seç', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                        value: targetItems.isNotEmpty && selectedTargets.length == targetItems.length,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              selectedTargets = List.from(targetItems);
                            } else {
                              selectedTargets.clear();
                            }
                          });
                        },
                      ),
                      const Divider(height: 1),
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.35,
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: targetItems.length,
                            itemBuilder: (ctx, idx) {
                              final item = targetItems[idx];
                              final isSelected = selectedTargets.contains(item);
                              return CheckboxListTile(
                                title: Text(item, style: GoogleFonts.inter(fontSize: 13)),
                                value: isSelected,
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity: ListTileControlAffinity.leading,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      selectedTargets.add(item);
                                    } else {
                                      selectedTargets.remove(item);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: selectedTargets.isEmpty
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          try {
                            final batch = _db.batch();
                            for (final target in selectedTargets) {
                              final docRef = _db.collection('toplayici_atamalari').doc();
                              batch.set(docRef, {
                                'toplayici': selectedDriver,
                                'hedefTip': selectedTargetType == 'Müşteri' ? 'uretici' : 'grup',
                                'hedefAd': target,
                                'firma': currentFirmaName,
                                'timestamp': FieldValue.serverTimestamp(),
                              });
                            }
                            await batch.commit();

                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Atama işlemleri başarıyla tamamlandı!'), backgroundColor: AppColors.success),
                            );
                          } catch (e) {
                            setState(() => isLoading = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: AppColors.danger),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Ata'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteAssignment(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Atamayı Kaldır', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu atama işlemini iptal etmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Atama kaldırıldı!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Kaldır'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Atama İşlemleri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/ureticiler'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      floatingActionButton: AppFab(
        icon: Icons.person_add_alt_1_rounded,
        label: 'Yeni Atama',
        onTap: _showAddAssignmentDialog,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('toplayici_atamalari')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Sistemde tanımlı atama bulunmuyor.',
                style: GoogleFonts.inter(color: AppColors.gray500),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final toplayici = data['toplayici'] ?? '';
              final hedefTip = data['hedefTip'] == 'uretici' ? 'Müşteri' : 'Grup';
              final hedefAd = data['hedefAd'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.connect_without_contact_rounded, color: AppColors.primary600, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(toplayici, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              StatusBadge.info(hedefTip),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  hedefAd,
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray700, fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: AppColors.danger, size: 22),
                      onPressed: () => _deleteAssignment(doc),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
