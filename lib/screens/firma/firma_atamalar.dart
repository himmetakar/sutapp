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
  List<DocumentSnapshot> _currentDocs = [];

  List<String> _getExistingTargets(String driver, String targetType) {
    final typeVal = targetType == 'Üretici' ? 'uretici' : 'grup';
    return _currentDocs
        .where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['toplayici'] == driver && data['hedefTip'] == typeVal;
        })
        .map((doc) => (doc.data() as Map<String, dynamic>)['hedefAd'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  void _showAddAssignmentDialog({
    String? initialDriver,
    String? initialTargetType,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Fetch lists
    final driversQuery = await _db.collection('suruculer').where('firma', isEqualTo: currentFirmaName).get();
    final drivers = driversQuery.docs.map((d) {
      final data = d.data();
      return '${data['ad'] ?? ''} ${data['soyad'] ?? ''}'.trim();
    }).where((d) => d.isNotEmpty).toList();

    final vehiclesQuery = await _db.collection('araclar').where('firma', isEqualTo: currentFirmaName).get();
    final Map<String, String> driverPlates = {};
    for (var doc in vehiclesQuery.docs) {
      final data = doc.data();
      final plate = data['plaka'] as String? ?? '';
      final List<String> suruculer = List<String>.from(data['suruculer'] ?? []);
      for (var driver in suruculer) {
        driverPlates[driver.trim().toLowerCase()] = plate;
      }
    }

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

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedDriver = (initialDriver != null && drivers.contains(initialDriver))
            ? initialDriver
            : (drivers.isNotEmpty ? drivers.first : null);
        String selectedTargetType = initialTargetType ?? 'Üretici'; // Üretici, Grup
        List<String> selectedTargets = selectedDriver != null ? _getExistingTargets(selectedDriver, selectedTargetType) : [];
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

            final targetItems = selectedTargetType == 'Üretici' ? producers : groups;

            return AlertDialog(
              title: Text(initialDriver != null ? 'Atama Düzenle' : 'Yeni Atama Yap', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
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
                      items: drivers.map((d) {
                        final dLower = d.trim().toLowerCase();
                        final p = driverPlates[dLower];
                        final displayLabel = p != null ? '$d ($p)' : d;
                        return DropdownMenuItem(value: d, child: Text(displayLabel));
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedDriver = val;
                          if (selectedDriver != null) {
                            selectedTargets = _getExistingTargets(selectedDriver!, selectedTargetType);
                          } else {
                            selectedTargets.clear();
                          }
                        });
                      },
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(height: 12),
                    Text('Atama Türü', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: RadioListTile<String>(
                            title: const Text('Üretici'),
                            value: 'Üretici',
                            groupValue: selectedTargetType,
                            contentPadding: EdgeInsets.zero,
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  selectedTargetType = val;
                                  if (selectedDriver != null) {
                                    selectedTargets = _getExistingTargets(selectedDriver!, selectedTargetType);
                                  } else {
                                    selectedTargets.clear();
                                  }
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
                                  if (selectedDriver != null) {
                                    selectedTargets = _getExistingTargets(selectedDriver!, selectedTargetType);
                                  } else {
                                    selectedTargets.clear();
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      selectedTargetType == 'Üretici' ? 'Üreticileri Seçin' : 'Üretici Gruplarını Seçin',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500),
                    ),
                    const SizedBox(height: 6),
                    if (targetItems.isEmpty)
                      Text(
                        selectedTargetType == 'Üretici' ? 'Kayıtlı üretici bulunamadı.' : 'Kayıtlı grup bulunamadı.',
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
                            
                            final typeVal = selectedTargetType == 'Üretici' ? 'uretici' : 'grup';
                            final docsToDelete = _currentDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              return data['toplayici'] == selectedDriver && data['hedefTip'] == typeVal;
                            });

                            for (final doc in docsToDelete) {
                              batch.delete(doc.reference);
                            }

                            for (final target in selectedTargets) {
                              final docRef = _db.collection('toplayici_atamalari').doc();
                              batch.set(docRef, {
                                'toplayici': selectedDriver,
                                'hedefTip': typeVal,
                                'hedefAd': target,
                                'firma': currentFirmaName,
                                'timestamp': FieldValue.serverTimestamp(),
                              });
                            }
                            await batch.commit();

                            if (mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Atama işlemleri başarıyla tamamlandı!'), backgroundColor: AppColors.success),
                              );
                            }
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

    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('araclar')
          .where('firma', isEqualTo: currentFirmaName)
          .snapshots(),
      builder: (context, araclarSnapshot) {
        final vehicleDocs = araclarSnapshot.data?.docs ?? [];
        final Map<String, String> driverPlates = {};
        for (var doc in vehicleDocs) {
          final data = doc.data() as Map<String, dynamic>;
          final plate = data['plaka'] as String? ?? '';
          final List<String> suruculer = List<String>.from(data['suruculer'] ?? []);
          for (var driver in suruculer) {
            driverPlates[driver.trim().toLowerCase()] = plate;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('toplayici_atamalari')
              .where('firma', isEqualTo: currentFirmaName)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting ||
                araclarSnapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(
                  title: Text(
                    'Atama İşlemleri',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.go('/firma/ureticiler'),
                  ),
                ),
                backgroundColor: AppColors.gray50,
                body: const Center(child: CircularProgressIndicator()),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            _currentDocs = docs;

            // Group assignments by driver name
            final Map<String, List<DocumentSnapshot>> grouped = {};
            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final toplayici = data['toplayici'] as String? ?? 'Belirsiz';
              grouped.putIfAbsent(toplayici, () => []).add(doc);
            }

            final driversList = grouped.keys.toList()..sort();

            return Scaffold(
              appBar: AppBar(
                title: Text(
                  'Atama İşlemleri',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => context.go('/firma/ureticiler'),
                ),
              ),
              backgroundColor: AppColors.gray50,
              floatingActionButton: AppFab(
                icon: Icons.person_add_alt_1_rounded,
                label: 'Yeni Atama',
                onTap: () => _showAddAssignmentDialog(),
              ),
              body: docs.isEmpty
                  ? Center(
                      child: Text(
                        'Sistemde tanımlı atama bulunmuyor.',
                        style: GoogleFonts.inter(color: AppColors.gray500),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: driversList.length,
                      itemBuilder: (context, index) {
                        final driverName = driversList[index];
                        final driverDocs = grouped[driverName]!;
                        final ureticiDocs = driverDocs.where((d) => d['hedefTip'] == 'uretici').toList();
                        final grupDocs = driverDocs.where((d) => d['hedefTip'] == 'grup').toList();

                        final driverNameLower = driverName.trim().toLowerCase();
                        final plate = driverPlates[driverNameLower];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: AppShadows.sm,
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              shape: const Border(),
                              collapsedShape: const Border(),
                              tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Center(
                                  child: Icon(Icons.local_shipping_rounded, color: AppColors.primary600, size: 20),
                                ),
                              ),
                              title: Text(
                                "Toplayıcı: $driverName${plate != null ? ' ($plate)' : ''}",
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.gray800),
                              ),
                              subtitle: Text(
                                "${ureticiDocs.length} Üretici, ${grupDocs.length} Grup",
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                              ),
                              children: [
                                const Divider(height: 1, color: AppColors.gray200),
                                const SizedBox(height: 8),
                                ...driverDocs.map((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final hedefTip = data['hedefTip'] == 'uretici' ? 'Üretici' : 'Grup';
                                  final hedefAd = data['hedefAd'] ?? '';

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.gray50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.gray100),
                                    ),
                                    child: Row(
                                      children: [
                                        StatusBadge.info(hedefTip),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            hedefAd,
                                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                          onPressed: () => _deleteAssignment(doc),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          splashRadius: 20,
                                          tooltip: 'Atamayı Kaldır',
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                                const SizedBox(height: 8),
                                const Divider(height: 1, color: AppColors.gray200),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: () => _showAddAssignmentDialog(
                                        initialDriver: driverName,
                                        initialTargetType: 'Üretici',
                                      ),
                                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                      label: const Text('Üretici Ekle/Çıkar'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        side: const BorderSide(color: AppColors.primary300),
                                        foregroundColor: AppColors.primary700,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => _showAddAssignmentDialog(
                                        initialDriver: driverName,
                                        initialTargetType: 'Grup',
                                      ),
                                      icon: const Icon(Icons.group_add_rounded, size: 16),
                                      label: const Text('Grup Ekle/Çıkar'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        side: const BorderSide(color: AppColors.primary300),
                                        foregroundColor: AppColors.primary700,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                        textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }
}
