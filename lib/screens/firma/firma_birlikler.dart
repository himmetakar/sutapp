import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';


import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaBirliklerScreen extends StatefulWidget {
  const FirmaBirliklerScreen({super.key});

  @override
  State<FirmaBirliklerScreen> createState() => _FirmaBirliklerScreenState();
}

class _FirmaBirliklerScreenState extends State<FirmaBirliklerScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _showAddUnionDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Yeni Birlik Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Birlik Adı', hintText: 'Örn: Damızlık Sığır Yetiştiricileri Birliği'),
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

              await _db.collection('birlikler').add({
                'ad': name,
                'firma': currentFirmaName,
                'timestamp': FieldValue.serverTimestamp(),
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Birlik başarıyla eklendi!'), backgroundColor: AppColors.success),
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

  void _showEditUnionDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['ad'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Birliği Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Birlik Adı'),
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
                const SnackBar(content: Text('Birlik başarıyla güncellendi!'), backgroundColor: AppColors.success),
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

  void _deleteUnion(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Birliği Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu birliği silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Birlik silindi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog() async {
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

    if (unions.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Önce en az bir birlik eklemelisiniz.'),
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
        String? selectedBirlik = unions.first;
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
                  title: Text('Birliğe Üye Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Dropdown to select Union
                        DropdownButtonFormField<String>(
                          value: selectedBirlik,
                          decoration: const InputDecoration(labelText: 'Hedef Birlik'),
                          items: unions.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDlgState(() => selectedBirlik = val);
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
                                    final currentBirlik = data['birlik'] ?? 'Yok';
                                    final isChecked = dialogSelectedProducerIds.contains(doc.id);

                                    return CheckboxListTile(
                                      title: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                      subtitle: Text(
                                        'Mevcut Birlik: $currentBirlik',
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
                                batch.update(doc.reference, {'birlik': selectedBirlik});
                              }
                              await batch.commit();

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('${dialogSelectedProducerIds.length} üretici $selectedBirlik birliğine başarıyla eklendi!'),
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



  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required Color bgColor,
    double? width,
  }) {
    final cardContent = Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.sm,
        border: Border.all(color: AppColors.gray100, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.gray500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (width == null) {
      return Expanded(child: cardContent);
    }
    return cardContent;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Birlik Raporları & Kayıtları', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/ureticiler'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppFab(
            icon: Icons.person_add_rounded,
            label: 'Yeni Üye Ekle',
            onTap: _showAddMemberDialog,
          ),
          const SizedBox(width: 12),
          AppFab(
            icon: Icons.add_rounded,
            label: 'Yeni Birlik Ekle',
            onTap: _showAddUnionDialog,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('birlikler').where('firma', isEqualTo: currentFirmaName).snapshots(),
        builder: (context, birlikSnap) {
          if (birlikSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final birlikDocs = birlikSnap.data?.docs ?? [];

          return StreamBuilder<QuerySnapshot>(
            stream: _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).snapshots(),
            builder: (context, ureticiSnap) {
              if (ureticiSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final ureticiDocs = ureticiSnap.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot>(
                stream: _db.collection('toplamalar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                builder: (context, toplamalarSnap) {
                  if (toplamalarSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final toplamalarDocs = toplamalarSnap.data?.docs ?? [];

                  // Map to hold producer union assignments
                  final Map<String, String> producerToUnion = {};
                  for (var doc in ureticiDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['name'] ?? '';
                    final birlik = data['birlik'] ?? 'Yok';
                    if (name.isNotEmpty) {
                      producerToUnion[name] = birlik;
                    }
                  }

                  // Member counts per union
                  final Map<String, int> unionMemberCounts = {};
                  for (var doc in ureticiDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final birlik = data['birlik'] ?? 'Yok';
                    if (birlik != 'Yok') {
                      unionMemberCounts[birlik] = (unionMemberCounts[birlik] ?? 0) + 1;
                    }
                  }

                  // Milk totals per union
                  final Map<String, double> unionMilkTotals = {};
                  for (var doc in toplamalarDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final producerName = data['u'] ?? '';
                    final double miktar = (data['m'] as num?)?.toDouble() ?? 0.0;
                    final birlik = producerToUnion[producerName] ?? 'Yok';
                    if (birlik != 'Yok') {
                      unionMilkTotals[birlik] = (unionMilkTotals[birlik] ?? 0.0) + miktar;
                    }
                  }

                  // Overall statistics
                  final int totalUnions = birlikDocs.length;
                  final int totalMembers = unionMemberCounts.values.fold(0, (sum, val) => sum + val);
                  final double totalMilk = unionMilkTotals.values.fold(0.0, (sum, val) => sum + val);

                  // Create table data list
                  final List<Map<String, dynamic>> tableData = [];
                  for (final doc in birlikDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['ad'] ?? '';
                    tableData.add({
                      'doc': doc,
                      'name': name,
                      'members': unionMemberCounts[name] ?? 0,
                      'milk': unionMilkTotals[name] ?? 0.0,
                    });
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Rapor Özeti Kartları
                      // Rapor Özeti Kartları
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          children: [
                            _buildSummaryCard(
                              icon: Icons.account_balance_rounded,
                              title: 'Toplam Birlik',
                              value: '$totalUnions Birlik',
                              color: AppColors.primary600,
                              bgColor: AppColors.primary50,
                              width: 140,
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                              icon: Icons.people_rounded,
                              title: 'Kayıtlı Üye',
                              value: '$totalMembers Üretici',
                              color: AppColors.success,
                              bgColor: AppColors.successLight,
                              width: 145,
                            ),
                            const SizedBox(width: 8),
                            _buildSummaryCard(
                              icon: Icons.water_drop_rounded,
                              title: 'Toplam Süt',
                              value: '${totalMilk.toStringAsFixed(0)} LT',
                              color: AppColors.warningDark,
                              bgColor: AppColors.warningLight,
                              width: 140,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Tablo Kartı
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.md,
                          border: Border.all(color: AppColors.gray200, width: 1),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Kart Başlığı ve Buton
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Birlik Listesi ve Detayları',
                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.gray800),
                              ),
                            ),
                            const Divider(height: 1, color: AppColors.gray200),

                            if (tableData.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 40),
                                child: Center(
                                  child: Text(
                                    'Tanımlı birlik kaydı bulunmuyor.',
                                    style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13),
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    final isMobile = constraints.maxWidth < 600;
                                    if (isMobile) {
                                      return ListView.separated(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: tableData.length,
                                        separatorBuilder: (context, index) => const Divider(color: AppColors.gray100, height: 1),
                                        itemBuilder: (context, index) {
                                          final item = tableData[index];
                                          final doc = item['doc'] as DocumentSnapshot;
                                          final name = item['name'] as String;
                                          final members = item['members'] as int;
                                          final milk = item['milk'] as double;

                                          return GestureDetector(
                                            onTap: () => context.push('/firma/ureticiler/liste?birlik=${Uri.encodeComponent(name)}'),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          name,
                                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gray800),
                                                        ),
                                                        const SizedBox(height: 6),
                                                        Row(
                                                          children: [
                                                            Container(
                                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                              decoration: BoxDecoration(
                                                                color: AppColors.successLight,
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: Text(
                                                                '$members Üretici',
                                                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.successDark, height: 1.1),
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            Text(
                                                              '${milk.toStringAsFixed(0)} LT',
                                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary600),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_rounded, color: AppColors.gray500, size: 18),
                                                        onPressed: () => _showEditUnionDialog(doc),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        splashRadius: 18,
                                                      ),
                                                      const SizedBox(width: 12),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                                                        onPressed: () => _deleteUnion(doc),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        splashRadius: 18,
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      );
                                    } else {
                                      return Table(
                                        columnWidths: const {
                                          0: FlexColumnWidth(4), // Birlik Adı
                                          1: FlexColumnWidth(2.5), // Üye Sayısı
                                          2: FlexColumnWidth(2.5), // Toplam Süt
                                          3: FlexColumnWidth(2), // İşlemler
                                        },
                                        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                        children: [
                                          TableRow(
                                            decoration: BoxDecoration(
                                              color: AppColors.gray50,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                child: Text('Birlik Adı', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray600)),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                child: Text('Üye Sayısı', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray600)),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                child: Text('Toplam Süt', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray600)),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                                child: Text('İşlemler', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray600)),
                                              ),
                                            ],
                                          ),
                                          const TableRow(
                                            children: [
                                              SizedBox(height: 8),
                                              SizedBox(height: 8),
                                              SizedBox(height: 8),
                                              SizedBox(height: 8),
                                            ]
                                          ),
                                          ...tableData.map((item) {
                                            final doc = item['doc'] as DocumentSnapshot;
                                            final name = item['name'] as String;
                                            final members = item['members'] as int;
                                            final milk = item['milk'] as double;
                                            void navigateToBirlik() {
                                              context.push('/firma/ureticiler/liste?birlik=${Uri.encodeComponent(name)}');
                                            }

                                            return TableRow(
                                              decoration: const BoxDecoration(
                                                border: Border(bottom: BorderSide(color: AppColors.gray100, width: 1)),
                                              ),
                                              children: [
                                                GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: navigateToBirlik,
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                                    child: Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.gray800)),
                                                  ),
                                                ),
                                                GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: navigateToBirlik,
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                          decoration: BoxDecoration(
                                                            color: AppColors.successLight,
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            '$members Üretici',
                                                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.successDark, height: 1.1),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                GestureDetector(
                                                  behavior: HitTestBehavior.opaque,
                                                  onTap: navigateToBirlik,
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                                    child: Text(
                                                      '${milk.toStringAsFixed(0)} LT',
                                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary600),
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                                  child: Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.edit_rounded, color: AppColors.gray500, size: 18),
                                                        onPressed: () => _showEditUnionDialog(doc),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        splashRadius: 18,
                                                      ),
                                                      const SizedBox(width: 10),
                                                      IconButton(
                                                        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 18),
                                                        onPressed: () => _deleteUnion(doc),
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(),
                                                        splashRadius: 18,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                        ],
                                      );
                                    }
                                  }
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 80),
                    ],
                  );
                }
              );
            }
          );
        },
      ),
    );
  }
}
