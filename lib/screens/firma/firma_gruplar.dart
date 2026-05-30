import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaGruplarScreen extends StatefulWidget {
  const FirmaGruplarScreen({super.key});

  @override
  State<FirmaGruplarScreen> createState() => _FirmaGruplarScreenState();
}

class _FirmaGruplarScreenState extends State<FirmaGruplarScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController!.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _showAddGroupDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Yeni Grup Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Grup / Köy Adı', hintText: 'Örn: İshaklı Köyü'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final currentFirmaName = auth.user?.displayName ?? '';
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              await _db.collection('musteri_gruplari').add({
                'ad': name,
                'firma': currentFirmaName,
                'timestamp': FieldValue.serverTimestamp(),
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Grup başarıyla eklendi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showEditGroupDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['ad'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Grubu Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Grup / Köy Adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              await doc.reference.update({'ad': name});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Grup başarıyla güncellendi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _deleteGroup(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Grubu Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu grubu silmek istediğinize emin misiniz? Bu gruptaki üreticiler gruptan çıkarılmayacaktır fakat grubun kendisi silinecektir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Grup silindi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddRegionDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Yeni Bölge Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Bölge Adı', hintText: 'Örn: Kocasinan'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final currentFirmaName = auth.user?.displayName ?? '';
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              await _db.collection('musteri_bolgeleri').add({
                'ad': name,
                'firma': currentFirmaName,
                'timestamp': FieldValue.serverTimestamp(),
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bölge başarıyla eklendi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showEditRegionDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['ad'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bölgeyi Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Bölge Adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              await doc.reference.update({'ad': name});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bölge başarıyla güncellendi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _deleteRegion(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Bölgeyi Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu bölgeyi silmek istediğinize emin misiniz? Bu bölgedeki üreticiler bölgeden çıkarılmayacaktır fakat bölgenin kendisi silinecektir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bölge silindi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddGroupMemberDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Fetch unions (birlikler)
    final unionsSnap = await _db.collection('birlikler').where('firma', isEqualTo: currentFirmaName).get();
    final List<String> unions = unionsSnap.docs.map((d) => d['ad'] as String).toList();

    // Fetch groups (gruplar)
    final groupsSnap = await _db.collection('musteri_gruplari').where('firma', isEqualTo: currentFirmaName).get();
    final List<String> groups = groupsSnap.docs.map((d) => d['ad'] as String).toList();

    // Fetch regions (bolgeler)
    final bolgelerSnap = await _db.collection('musteri_bolgeleri').where('firma', isEqualTo: currentFirmaName).get();
    final List<String> bolgeler = bolgelerSnap.docs.map((d) => d['ad'] as String).toList();

    if (groups.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Önce en az bir grup eklemelisiniz.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedGroup = groups.first;
        String dialogSearchQuery = '';
        String selectedFilter = '';
        final Set<String> dialogSelectedProducerIds = {};

        return StatefulBuilder(
          builder: (context, setDlgState) {
            return StreamBuilder<QuerySnapshot>(
              stream: _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).snapshots(),
              builder: (context, ureticiSnap) {
                final docs = ureticiSnap.data?.docs ?? [];
                
                // Build all suggestions list
                final List<String> allSuggestions = [];
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? '';
                  if (name.isNotEmpty && !allSuggestions.contains(name)) {
                    allSuggestions.add(name);
                  }
                }
                for (var g in groups) {
                  allSuggestions.add('$g (Grup)');
                }
                for (var b in bolgeler) {
                  allSuggestions.add('$b (Bölge)');
                }

                // Filter producers based on search query / selectedFilter
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final phone = (data['phone'] as String? ?? '').toLowerCase();
                  final group = (data['group'] as String? ?? '').toLowerCase();
                  final bolge = (data['bolge'] as String? ?? '').toLowerCase();

                  if (selectedFilter.isNotEmpty) {
                    if (selectedFilter.endsWith(' (Grup)')) {
                      final targetGroup = selectedFilter.replaceAll(' (Grup)', '').toLowerCase();
                      return group == targetGroup;
                    } else if (selectedFilter.endsWith(' (Bölge)')) {
                      final targetBolge = selectedFilter.replaceAll(' (Bölge)', '').toLowerCase();
                      return bolge == targetBolge;
                    } else {
                      return name == selectedFilter.toLowerCase();
                    }
                  }

                  // Default search query matching name or phone or group or region
                  return dialogSearchQuery.isEmpty ||
                      name.contains(dialogSearchQuery.toLowerCase()) ||
                      phone.contains(dialogSearchQuery.toLowerCase()) ||
                      group.contains(dialogSearchQuery.toLowerCase()) ||
                      bolge.contains(dialogSearchQuery.toLowerCase());
                }).toList();

                return AlertDialog(
                  title: Text('Gruba Üye Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dropdown to select Group
                        DropdownButtonFormField<String>(
                          value: selectedGroup,
                          decoration: const InputDecoration(labelText: 'Hedef Grup / Köy'),
                          items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() => selectedGroup = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Autocomplete search bar inside dialog
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return allSuggestions.where((String option) {
                              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },
                          onSelected: (String selection) {
                            setDlgState(() {
                              selectedFilter = selection;
                              dialogSearchQuery = selection;
                            });
                          },
                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Üretici, Grup veya Bölge ara...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                suffixIcon: textEditingController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          textEditingController.clear();
                                          setDlgState(() {
                                            selectedFilter = '';
                                            dialogSearchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (val) {
                                setDlgState(() {
                                  dialogSearchQuery = val.trim();
                                  if (selectedFilter.isNotEmpty && val != selectedFilter) {
                                    selectedFilter = '';
                                  }
                                });
                              },
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final dropdownWidth = screenWidth > 600 ? 360.0 : screenWidth - 72;
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white,
                                child: Container(
                                  width: dropdownWidth,
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.gray200),
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final String option = options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: index < options.length - 1
                                              ? const BoxDecoration(
                                                  border: Border(bottom: BorderSide(color: AppColors.gray100)),
                                                )
                                              : null,
                                          child: Text(
                                            option,
                                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray800),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // Select All / Deselect All Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${dialogSelectedProducerIds.length} Üye Seçildi',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray600),
                            ),
                            TextButton(
                              onPressed: () {
                                setDlgState(() {
                                  final allFilteredIds = filteredDocs.map((d) => d.id).toList();
                                  final isAllSelected = allFilteredIds.every((id) => dialogSelectedProducerIds.contains(id));
                                  if (isAllSelected) {
                                    dialogSelectedProducerIds.removeAll(allFilteredIds);
                                  } else {
                                    dialogSelectedProducerIds.addAll(allFilteredIds);
                                  }
                                });
                              },
                              child: Text(
                                filteredDocs.every((d) => dialogSelectedProducerIds.contains(d.id))
                                    ? 'Seçimi Kaldır'
                                    : 'Tümünü Seç',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Scrollable List of producers with checkbox
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.gray200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: filteredDocs.isEmpty
                              ? Center(
                                  child: Text(
                                    'Üretici bulunamadı.',
                                    style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredDocs.length,
                                  itemBuilder: (context, index) {
                                    final doc = filteredDocs[index];
                                    final data = doc.data() as Map<String, dynamic>;
                                    final name = data['name'] ?? '';
                                    final currentGroup = data['group'] ?? 'Yok';
                                    final isChecked = dialogSelectedProducerIds.contains(doc.id);

                                    return CheckboxListTile(
                                      title: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                        'Mevcut Grup: $currentGroup',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                      ),
                                      value: isChecked,
                                      activeColor: AppColors.primary600,
                                      dense: true,
                                      onChanged: (bool? val) {
                                        setDlgState(() {
                                          if (val == true) {
                                            dialogSelectedProducerIds.add(doc.id);
                                          } else {
                                            dialogSelectedProducerIds.remove(doc.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                    ),
                    ElevatedButton(
                      onPressed: dialogSelectedProducerIds.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              final batch = _db.batch();
                              for (var id in dialogSelectedProducerIds) {
                                final doc = docs.firstWhere((d) => d.id == id);
                                batch.update(doc.reference, {'group': selectedGroup});
                              }
                              await batch.commit();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${dialogSelectedProducerIds.length} üretici $selectedGroup grubuna başarıyla eklendi!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Üyeleri Ekle'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  void _showAddRegionMemberDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Fetch unions (birlikler)
    final unionsSnap = await _db.collection('birlikler').where('firma', isEqualTo: currentFirmaName).get();
    final List<String> unions = unionsSnap.docs.map((d) => d['ad'] as String).toList();

    // Fetch groups (gruplar)
    final groupsSnap = await _db.collection('musteri_gruplari').where('firma', isEqualTo: currentFirmaName).get();
    final List<String> groups = groupsSnap.docs.map((d) => d['ad'] as String).toList();

    // Fetch regions (bolgeler)
    final bolgelerSnap = await _db.collection('musteri_bolgeleri').where('firma', isEqualTo: currentFirmaName).get();
    final List<String> bolgeler = bolgelerSnap.docs.map((d) => d['ad'] as String).toList();

    if (bolgeler.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Önce en az bir bölge eklemelisiniz.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedRegion = bolgeler.first;
        String dialogSearchQuery = '';
        String selectedFilter = '';
        final Set<String> dialogSelectedProducerIds = {};

        return StatefulBuilder(
          builder: (context, setDlgState) {
            return StreamBuilder<QuerySnapshot>(
              stream: _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).snapshots(),
              builder: (context, ureticiSnap) {
                final docs = ureticiSnap.data?.docs ?? [];
                
                // Build all suggestions list
                final List<String> allSuggestions = [];
                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = data['name'] as String? ?? '';
                  if (name.isNotEmpty && !allSuggestions.contains(name)) {
                    allSuggestions.add(name);
                  }
                }
                for (var g in groups) {
                  allSuggestions.add('$g (Grup)');
                }
                for (var b in bolgeler) {
                  allSuggestions.add('$b (Bölge)');
                }

                // Filter producers based on search query / selectedFilter
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final phone = (data['phone'] as String? ?? '').toLowerCase();
                  final group = (data['group'] as String? ?? '').toLowerCase();
                  final bolge = (data['bolge'] as String? ?? '').toLowerCase();

                  if (selectedFilter.isNotEmpty) {
                    if (selectedFilter.endsWith(' (Grup)')) {
                      final targetGroup = selectedFilter.replaceAll(' (Grup)', '').toLowerCase();
                      return group == targetGroup;
                    } else if (selectedFilter.endsWith(' (Bölge)')) {
                      final targetBolge = selectedFilter.replaceAll(' (Bölge)', '').toLowerCase();
                      return bolge == targetBolge;
                    } else {
                      return name == selectedFilter.toLowerCase();
                    }
                  }

                  // Default search query matching name or phone or group or region
                  return dialogSearchQuery.isEmpty ||
                      name.contains(dialogSearchQuery.toLowerCase()) ||
                      phone.contains(dialogSearchQuery.toLowerCase()) ||
                      group.contains(dialogSearchQuery.toLowerCase()) ||
                      bolge.contains(dialogSearchQuery.toLowerCase());
                }).toList();

                return AlertDialog(
                  title: Text('Bölgeye Üye Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dropdown to select Region
                        DropdownButtonFormField<String>(
                          value: selectedRegion,
                          decoration: const InputDecoration(labelText: 'Hedef Bölge'),
                          items: bolgeler.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() => selectedRegion = val);
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Autocomplete search bar inside dialog
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return allSuggestions.where((String option) {
                              return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                            });
                          },
                          onSelected: (String selection) {
                            setDlgState(() {
                              selectedFilter = selection;
                              dialogSearchQuery = selection;
                            });
                          },
                          fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                            return TextField(
                              controller: textEditingController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Üretici, Grup veya Bölge ara...',
                                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                suffixIcon: textEditingController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 16),
                                        onPressed: () {
                                          textEditingController.clear();
                                          setDlgState(() {
                                            selectedFilter = '';
                                            dialogSearchQuery = '';
                                          });
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (val) {
                                setDlgState(() {
                                  dialogSearchQuery = val.trim();
                                  if (selectedFilter.isNotEmpty && val != selectedFilter) {
                                    selectedFilter = '';
                                  }
                                });
                              },
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            final screenWidth = MediaQuery.of(context).size.width;
                            final dropdownWidth = screenWidth > 600 ? 360.0 : screenWidth - 72;
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.white,
                                child: Container(
                                  width: dropdownWidth,
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.gray200),
                                  ),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (BuildContext context, int index) {
                                      final String option = options.elementAt(index);
                                      return InkWell(
                                        onTap: () => onSelected(option),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          decoration: index < options.length - 1
                                              ? const BoxDecoration(
                                                  border: Border(bottom: BorderSide(color: AppColors.gray100)),
                                                )
                                              : null,
                                          child: Text(
                                            option,
                                            style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray800),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),

                        // Select All / Deselect All Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${dialogSelectedProducerIds.length} Üye Seçildi',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray600),
                            ),
                            TextButton(
                              onPressed: () {
                                setDlgState(() {
                                  final allFilteredIds = filteredDocs.map((d) => d.id).toList();
                                  final isAllSelected = allFilteredIds.every((id) => dialogSelectedProducerIds.contains(id));
                                  if (isAllSelected) {
                                    dialogSelectedProducerIds.removeAll(allFilteredIds);
                                  } else {
                                    dialogSelectedProducerIds.addAll(allFilteredIds);
                                  }
                                });
                              },
                              child: Text(
                                filteredDocs.every((d) => dialogSelectedProducerIds.contains(d.id))
                                    ? 'Seçimi Kaldır'
                                    : 'Tümünü Seç',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary600),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Scrollable List of producers with checkbox
                        Container(
                          height: 200,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.gray200),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: filteredDocs.isEmpty
                              ? Center(
                                  child: Text(
                                    'Üretici bulunamadı.',
                                    style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: filteredDocs.length,
                                  itemBuilder: (context, index) {
                                    final doc = filteredDocs[index];
                                    final data = doc.data() as Map<String, dynamic>;
                                    final name = data['name'] ?? '';
                                    final currentBolge = data['bolge'] ?? 'Yok';
                                    final isChecked = dialogSelectedProducerIds.contains(doc.id);

                                    return CheckboxListTile(
                                      title: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                        'Mevcut Bölge: $currentBolge',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                      ),
                                      value: isChecked,
                                      activeColor: AppColors.primary600,
                                      dense: true,
                                      onChanged: (bool? val) {
                                        setDlgState(() {
                                          if (val == true) {
                                            dialogSelectedProducerIds.add(doc.id);
                                          } else {
                                            dialogSelectedProducerIds.remove(doc.id);
                                          }
                                        });
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                    ),
                    ElevatedButton(
                      onPressed: dialogSelectedProducerIds.isEmpty
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              final batch = _db.batch();
                              for (var id in dialogSelectedProducerIds) {
                                final doc = docs.firstWhere((d) => d.id == id);
                                batch.update(doc.reference, {'bolge': selectedRegion});
                              }
                              await batch.commit();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${dialogSelectedProducerIds.length} üretici $selectedRegion bölgesine başarıyla eklendi!'),
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Üyeleri Ekle'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupsTab(String currentFirmaName) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('musteri_gruplari')
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
              'Kayıtlı grup bulunamadı.',
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
            final name = data['ad'] ?? '';

            return GestureDetector(
              onTap: () => context.push('/firma/ureticiler/liste?group=${Uri.encodeComponent(name)}'),
              child: Container(
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
                        child: Icon(Icons.folder_shared_rounded, color: AppColors.primary600, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          StreamBuilder<QuerySnapshot>(
                            stream: _db
                                .collection('ureticiler')
                                .where('firmalar', arrayContains: currentFirmaName)
                                .where('group', isEqualTo: name)
                                .snapshots(),
                            builder: (context, prodSnap) {
                              final count = prodSnap.data?.docs.length ?? 0;
                              return Text(
                                '$count Üretici',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.gray500, size: 20),
                      onPressed: () => _showEditGroupDialog(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: AppColors.danger, size: 20),
                      onPressed: () => _deleteGroup(doc),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRegionsTab(String currentFirmaName) {
    return StreamBuilder<QuerySnapshot>(
      stream: _db
          .collection('musteri_bolgeleri')
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
              'Kayıtlı bölge bulunamadı.',
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
            final name = data['ad'] ?? '';

            return GestureDetector(
              onTap: () => context.push('/firma/ureticiler/liste?bolge=${Uri.encodeComponent(name)}'),
              child: Container(
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
                        color: AppColors.successLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.map_rounded, color: AppColors.success, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          StreamBuilder<QuerySnapshot>(
                            stream: _db
                                .collection('ureticiler')
                                .where('firmalar', arrayContains: currentFirmaName)
                                .where('bolge', isEqualTo: name)
                                .snapshots(),
                            builder: (context, prodSnap) {
                              final count = prodSnap.data?.docs.length ?? 0;
                              return Text(
                                '$count Üretici',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.gray500, size: 20),
                      onPressed: () => _showEditRegionDialog(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: AppColors.danger, size: 20),
                      onPressed: () => _deleteRegion(doc),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final isRegionTab = _tabController?.index == 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Üretici Grupları / Bölgeler', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/ureticiler'),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary600,
          labelColor: AppColors.primary600,
          unselectedLabelColor: AppColors.gray500,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Gruplar'),
            Tab(text: 'Bölgeler'),
          ],
        ),
      ),
      backgroundColor: AppColors.gray50,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppFab(
            icon: Icons.person_add_rounded,
            label: 'Üye Ekle',
            onTap: isRegionTab ? _showAddRegionMemberDialog : _showAddGroupMemberDialog,
          ),
          const SizedBox(width: 12),
          AppFab(
            icon: Icons.add_rounded,
            label: isRegionTab ? 'Bölge Ekle' : 'Grup Ekle',
            onTap: isRegionTab ? _showAddRegionDialog : _showAddGroupDialog,
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildGroupsTab(currentFirmaName),
          _buildRegionsTab(currentFirmaName),
        ],
      ),
    );
  }
}
