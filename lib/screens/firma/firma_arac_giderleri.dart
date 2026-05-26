import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class FirmaAracGiderleriScreen extends StatefulWidget {
  const FirmaAracGiderleriScreen({super.key});

  @override
  State<FirmaAracGiderleriScreen> createState() => _FirmaAracGiderleriScreenState();
}

class _FirmaAracGiderleriScreenState extends State<FirmaAracGiderleriScreen> {
  String _selectedTab = 'Ay'; // 'Hafta', 'Ay', 'Yıl'
  DateTime _selectedDate = DateTime.now();
  String _selectedPlateFilter = 'Tümü'; // 'Tümü' or plate
  final _searchCtrl = TextEditingController();
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _searchText = _searchCtrl.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }


  String _getMonthName(int month) {
    const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
    return months[month - 1];
  }

  bool _isRecordMatchingDate(String dateStr) {
    try {
      final parts = dateStr.split('.');
      if (parts.length != 3) return false;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final recordDate = DateTime(year, month, day);

      if (_selectedTab == 'Hafta') {
        // Within 7 days
        final diff = recordDate.difference(_selectedDate).inDays.abs();
        return diff <= 3; // rough check for week
      } else if (_selectedTab == 'Ay') {
        return recordDate.year == _selectedDate.year && recordDate.month == _selectedDate.month;
      } else {
        return recordDate.year == _selectedDate.year;
      }
    } catch (_) {
      return false;
    }
  }

  void _showAddExpenseDialog(List<String> plates) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final currentUserEmail = auth.user?.email ?? 'yonetici@sutapp.com';

    String? selectedPlate = plates.isNotEmpty ? plates.first : null;
    String selectedGiderTuru = 'Yakıt';
    final tutarCtrl = TextEditingController();
    final ekAciklamaCtrl = TextEditingController();
    final personelCtrl = TextEditingController(text: currentUserEmail);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Yeni Araç Gideri Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plates.isEmpty)
                  Text('Kayıtlı araç bulunamadı. Önce araç eklemelisiniz.', style: GoogleFonts.inter(color: Colors.red, fontSize: 13))
                else ...[
                  DropdownButtonFormField<String>(
                    value: selectedPlate,
                    decoration: const InputDecoration(labelText: 'Araç Plakası'),
                    items: plates.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (val) {
                      setDialogState(() {
                        selectedPlate = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedGiderTuru,
                    decoration: const InputDecoration(labelText: 'Gider Türü'),
                    items: const [
                      DropdownMenuItem(value: 'Yakıt', child: Text('Yakıt')),
                      DropdownMenuItem(value: 'Bakım', child: Text('Bakım')),
                      DropdownMenuItem(value: 'Lastik', child: Text('Lastik')),
                      DropdownMenuItem(value: 'Sigorta', child: Text('Sigorta')),
                      DropdownMenuItem(value: 'Muayene', child: Text('Muayene')),
                      DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedGiderTuru = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tutarCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Tutar (₺)', suffixText: 'TL'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: personelCtrl,
                    decoration: const InputDecoration(labelText: 'İlgili Personel E-posta'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: ekAciklamaCtrl,
                    decoration: const InputDecoration(labelText: 'Ek Açıklama / Detay (Örn: petrol ofisi)'),
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
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: plates.isEmpty
                  ? null
                  : () async {
                      final double? tutar = double.tryParse(tutarCtrl.text);
                      if (tutar == null || tutar <= 0 || selectedPlate == null) return;

                      await FirebaseFirestore.instance.collection('giderler').add({
                        'kategori': 'arac',
                        'aciklama': selectedGiderTuru,
                        'plaka': selectedPlate,
                        'tutar': tutar,
                        'ekAciklama': ekAciklamaCtrl.text.trim(),
                        'personel': personelCtrl.text.trim(),
                        'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                        'firma': currentFirmaName,
                        'timestamp': FieldValue.serverTimestamp(),
                        'durum': 'aktif',
                      });

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Araç gideri kaydedildi!'), backgroundColor: AppColors.success),
                      );
                    },
              child: const Text('Gideri Ekle'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'Araç Gider Görüntüle',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/personel'),
        ),
      ),
      floatingActionButton: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('araclar')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, snapshot) {
          final plates = (snapshot.data?.docs ?? []).map((d) => d['plaka'] as String).toList();
          return FloatingActionButton(
            backgroundColor: const Color(0xFF8B5CF6),
            foregroundColor: Colors.white,
            shape: const CircleBorder(),
            onPressed: () => _showAddExpenseDialog(plates),
            child: const Icon(Icons.add_rounded, size: 28),
          );
        },
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Period Selector Tabs (Hafta, Ay, Yıl)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(child: _buildTabButton('Hafta')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTabButton('Ay')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTabButton('Yıl')),
                ],
              ),
            ),

            // Year and Month Selectors
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  // Year Selector
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gray300, width: 0.8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFF8B5CF6)),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _selectedDate = DateTime(_selectedDate.year - 1, _selectedDate.month);
                              });
                            },
                          ),
                          Text(
                            '${_selectedDate.year}',
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                          ),
                          IconButton(
                            icon: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF8B5CF6)),
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              setState(() {
                                _selectedDate = DateTime(_selectedDate.year + 1, _selectedDate.month);
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Month Selector
                  if (_selectedTab != 'Yıl')
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gray300, width: 0.8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, size: 18, color: Color(0xFF8B5CF6)),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
                                });
                              },
                            ),
                            Text(
                              _getMonthName(_selectedDate.month),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF8B5CF6)),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                setState(() {
                                  _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Plate Filter Chips
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('araclar')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, snapshot) {
                final plates = (snapshot.data?.docs ?? []).map((d) => d['plaka'] as String).toList();
                return SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip('Tümü'),
                      ...plates.map((p) => _buildFilterChip(p)),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Plaka, gider türü, personel...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400, size: 20),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Main Content Area
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('giderler')
                    .where('firma', isEqualTo: currentFirmaName)
                    .where('kategori', isEqualTo: 'arac')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Apply date, plate & search filters
                  final filteredDocs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // Date Check
                    final tarih = data['tarih'] ?? '';
                    if (!_isRecordMatchingDate(tarih)) return false;

                    // Plate Check
                    final plaka = (data['plaka'] ?? '').toString();
                    if (_selectedPlateFilter != 'Tümü' && plaka != _selectedPlateFilter) return false;

                    // Search check
                    if (_searchText.isNotEmpty) {
                      final aciklama = (data['aciklama'] ?? '').toString().toLowerCase();
                      final ekAciklama = (data['ekAciklama'] ?? '').toString().toLowerCase();
                      final personel = (data['personel'] ?? '').toString().toLowerCase();
                      final matches = plaka.toLowerCase().contains(_searchText) ||
                          aciklama.contains(_searchText) ||
                          ekAciklama.contains(_searchText) ||
                          personel.contains(_searchText);
                      if (!matches) return false;
                    }

                    return true;
                  }).toList();

                  // Calculate summaries per vehicle
                  final vehicleExpensesMap = <String, double>{};
                  final vehicleExpensesCount = <String, int>{};
                  final vehicleLastExpenseDate = <String, String>{};

                  for (var doc in filteredDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final String plaka = data['plaka'] ?? 'Bilinmiyor';
                    final double tutar = (data['tutar'] ?? 0.0).toDouble();
                    final String tarih = data['tarih'] ?? '';

                    vehicleExpensesMap[plaka] = (vehicleExpensesMap[plaka] ?? 0.0) + tutar;
                    vehicleExpensesCount[plaka] = (vehicleExpensesCount[plaka] ?? 0) + 1;

                    // Compute latest date
                    if (tarih.isNotEmpty) {
                      if (!vehicleLastExpenseDate.containsKey(plaka)) {
                        vehicleLastExpenseDate[plaka] = tarih;
                      } else {
                        // Compare simple dates
                        vehicleLastExpenseDate[plaka] = tarih; 
                      }
                    }
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Araç Bazlı Gider Özeti
                      if (vehicleExpensesMap.isNotEmpty) ...[
                        Row(
                          children: [
                            Text(
                              'Araç Bazlı Gider Özeti',
                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...vehicleExpensesMap.entries.map((entry) {
                          final plaka = entry.key;
                          final totalTutar = entry.value;
                          final count = vehicleExpensesCount[plaka] ?? 0;
                          final lastDate = vehicleLastExpenseDate[plaka] ?? '-';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gray200),
                              boxShadow: AppShadows.sm,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      plaka,
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Bilinmiyor',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Son Gider: $lastDate',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                                    ),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${formatNumber.format(totalTutar)} ₺',
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$count gider',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],

                      // Gider Kayıtları (N)
                      Row(
                        children: [
                          Text(
                            'Gider Kayıtları (${filteredDocs.length})',
                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (filteredDocs.isEmpty) ...[
                        const SizedBox(height: 32),
                        Center(
                          child: Text(
                            'Seçilen filtrelere uygun gider kaydı bulunamadı.',
                            style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13),
                          ),
                        ),
                      ] else
                        ...filteredDocs.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final String plaka = data['plaka'] ?? 'Bilinmiyor';
                          final String aciklama = data['aciklama'] ?? 'Diğer';
                          final double tutar = (data['tutar'] ?? 0.0).toDouble();
                          final String tarih = data['tarih'] ?? '';
                          final String ekAciklama = data['ekAciklama'] ?? '';
                          final String personel = data['personel'] ?? '';

                          // Pick matching icon
                          IconData expIcon = Icons.local_shipping_rounded;
                          if (aciklama == 'Yakıt') {
                            expIcon = Icons.water_drop_rounded;
                          } else if (aciklama == 'Bakım') {
                            expIcon = Icons.build_rounded;
                          } else if (aciklama == 'Lastik') {
                            expIcon = Icons.adjust_rounded;
                          } else if (aciklama == 'Sigorta') {
                            expIcon = Icons.shield_rounded;
                          } else if (aciklama == 'Muayene') {
                            expIcon = Icons.analytics_rounded;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(expIcon, color: const Color(0xFF2563EB), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        aciklama,
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        plaka,
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary600),
                                      ),
                                      if (personel.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          'Personel: $personel',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                        ),
                                      ],
                                      if (ekAciklama.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          ekAciklama,
                                          style: GoogleFonts.inter(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.gray400),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${formatNumber.format(tutar)} ₺',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tarih,
                                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400),
                                    ),
                                  ],
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabName) {
    final isSelected = _selectedTab == tabName;
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFFF1F5F9),
          foregroundColor: isSelected ? Colors.white : AppColors.gray500,
          elevation: 0,
          side: BorderSide(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
            width: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {
          setState(() {
            _selectedTab = tabName;
            _selectedDate = DateTime.now();
          });
        },
        child: Text(
          tabName,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedPlateFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? const Color(0xFF8B5CF6) : AppColors.gray600,
          ),
        ),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            _selectedPlateFilter = label;
          });
        },
        selectedColor: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
        checkmarkColor: const Color(0xFF8B5CF6),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? const Color(0xFF8B5CF6) : AppColors.gray300, width: 0.8),
        ),
      ),
    );
  }
}
