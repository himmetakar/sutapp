import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

// --- MÜŞTERİ KESİNTİLERİ GRID SCREEN ---
class MusteriKesintileriScreen extends StatefulWidget {
  final int initialTab;
  const MusteriKesintileriScreen({super.key, this.initialTab = 0});

  @override
  State<MusteriKesintileriScreen> createState() => _MusteriKesintileriScreenState();
}

class _MusteriKesintileriScreenState extends State<MusteriKesintileriScreen> {
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  String? _selectedFilterGroup;
  String? _selectedFilterRegion;
  DateTimeRange? _selectedDateRange;
  String _quickPeriod = 'Tümü';

  final _oranlarFormKey = GlobalKey<FormState>();
  final _bagkurCtrl = TextEditingController();
  final _stopajCtrl = TextEditingController();
  final _borsaCtrl = TextEditingController();
  bool _oranlarLoading = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _bagkurCtrl.dispose();
    _stopajCtrl.dispose();
    _borsaCtrl.dispose();
    super.dispose();
  }

  // Pick Date Range for Deductions Filter
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now().add(const Duration(days: 30)),
          ),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary600,
              onPrimary: Colors.white,
              onSurface: AppColors.gray800,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        _quickPeriod = 'Özel';
      });
    }
  }

  // Toggles the active status of a deduction for a producer
  Future<void> _toggleDeduction(
    DocumentSnapshot prodDoc,
    String deductionName,
    Map<String, dynamic> currentSettings,
    bool currentActive,
  ) async {
    final updatedSettings = Map<String, dynamic>.from(currentSettings);
    updatedSettings['aktif'] = !currentActive;

    try {
      await prodDoc.reference.update({
        'kesintiAyarlari.$deductionName': updatedSettings,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${prodDoc['name']} için $deductionName kesintisi ${!currentActive ? 'etkinleştirildi' : 'devre dışı bırakıldı'}.'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 1),
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

  // Opens deduction rate & scheduling dialog for a cell
  void _showDeductionSettingsDialog(
    BuildContext context,
    DocumentSnapshot prodDoc,
    String deductionName,
    Map<String, dynamic> settings,
    double defaultRate,
  ) {
    final double rate = (settings['oran'] as num?)?.toDouble() ?? defaultRate;
    final bool active = settings['aktif'] == true;
    final String? startVal = settings['baslangic'] as String?;
    final String? endVal = settings['bitis'] as String?;

    final rateCtrl = TextEditingController(text: rate.toString());
    DateTime? startDate = startVal != null && startVal.isNotEmpty ? _parseDate(startVal) : null;
    DateTime? endDate = endVal != null && endVal.isNotEmpty ? _parseDate(endVal) : null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            final dateFormat = DateFormat('dd.MM.yyyy');
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$deductionName Ayarları',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gray900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    prodDoc['name'] ?? '',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rate Input
                    Text(
                      'Kesinti Oranı (%)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray600),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Start Date Picker
                    Text(
                      'Başlangıç Tarihi',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray600),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: const Locale('tr', 'TR'),
                        );
                        if (picked != null) {
                          setDlgState(() => startDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.gray300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              startDate != null ? dateFormat.format(startDate!) : 'Seçiniz',
                              style: GoogleFonts.inter(fontSize: 13, color: startDate != null ? AppColors.gray800 : AppColors.gray400),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gray400),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // End Date Picker
                    Text(
                      'Bitiş Tarihi (Boş bırakılırsa devamlı)',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray600),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: const Locale('tr', 'TR'),
                        );
                        if (picked != null) {
                          setDlgState(() => endDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.gray300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              endDate != null ? dateFormat.format(endDate!) : 'Devamlı (Ucu Açık)',
                              style: GoogleFonts.inter(fontSize: 13, color: endDate != null ? AppColors.gray800 : AppColors.gray400),
                            ),
                            if (endDate != null)
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.clear, size: 16, color: AppColors.danger),
                                onPressed: () => setDlgState(() => endDate = null),
                              )
                            else
                              const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gray400),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Vazgeç', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                TextButton(
                  onPressed: () async {
                    // Clear schedule
                    try {
                      await prodDoc.reference.update({
                        'kesintiAyarlari.$deductionName': FieldValue.delete(),
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$deductionName kesintisi fabrika ayarlarına sıfırlandı.'), backgroundColor: AppColors.success),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
                      );
                    }
                  },
                  child: Text('Varsayılana Sıfırla', style: GoogleFonts.inter(color: AppColors.danger)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600, foregroundColor: Colors.white),
                  onPressed: () async {
                    final double? newRate = double.tryParse(rateCtrl.text.replaceAll(',', '.'));
                    if (newRate == null || newRate < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Geçerli bir oran giriniz.'), backgroundColor: AppColors.danger),
                      );
                      return;
                    }

                    final updated = {
                      'oran': newRate,
                      'aktif': active,
                      'baslangic': startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : null,
                      'bitis': endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : null,
                    };

                    try {
                      await prodDoc.reference.update({
                        'kesintiAyarlari.$deductionName': updated,
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$deductionName ayarı kaydedildi!'), backgroundColor: AppColors.success),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
                      );
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Dynamic Column Manager (Gear menu dialog)
  void _showColumnManagerDialog(BuildContext context, String currentFirmaName, List<String> currentCols) {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Kesinti Türleri (Sütunlar)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Column list
                    Expanded(
                      child: ListView.builder(
                        itemCount: currentCols.length,
                        itemBuilder: (context, index) {
                          final col = currentCols[index];
                          final isDefault = col == 'Bağkur' || col == 'Stopaj' || col == 'Borsa';
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(col, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                            trailing: isDefault
                                ? Text('Varsayılan', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400))
                                : IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                                    onPressed: () async {
                                      final updatedList = List<String>.from(currentCols)..removeAt(index);
                                      await FirebaseFirestore.instance
                                          .collection('finans_ayarlari')
                                          .doc(currentFirmaName)
                                          .set({'kesintiTurleri': updatedList}, SetOptions(merge: true));
                                      setDlgState(() {
                                        currentCols.removeAt(index);
                                      });
                                    },
                                  ),
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    // Add new column form
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              hintText: 'Yeni Kesinti Adı...',
                              hintStyle: GoogleFonts.inter(fontSize: 12),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600, foregroundColor: Colors.white),
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) return;
                            if (currentCols.contains(name)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Bu sütun zaten mevcut.'), backgroundColor: AppColors.danger),
                              );
                              return;
                            }
                            final updatedList = List<String>.from(currentCols)..add(name);
                            await FirebaseFirestore.instance
                                .collection('finans_ayarlari')
                                .doc(currentFirmaName)
                                .set({'kesintiTurleri': updatedList}, SetOptions(merge: true));
                            nameCtrl.clear();
                            setDlgState(() {
                              currentCols.add(name);
                            });
                          },
                          child: const Text('Ekle'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kapat'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Batch Deduction Apply Dialog
  void _showBatchApplyDialog(BuildContext context, String currentFirmaName, List<String> columns, List<QueryDocumentSnapshot<Object?>> producers) {
    String selectedCol = columns.first;
    final rateCtrl = TextEditingController();
    bool active = true;
    DateTime? startDate = DateTime.now();
    DateTime? endDate;

    // Extract unique regions and groups
    final List<String> regions = ['Tümü'];
    final List<String> groups = ['Tümü'];
    for (var doc in producers) {
      final data = doc.data() as Map<String, dynamic>;
      final r = data['bolge'] as String?;
      final g = data['group'] as String?;
      if (r != null && r.isNotEmpty && !regions.contains(r)) regions.add(r);
      if (g != null && g.isNotEmpty && !groups.contains(g)) groups.add(g);
    }

    String selectedRegion = 'Tümü';
    String selectedGroup = 'Tümü';

    showDialog(
      context: context,
      builder: (ctx) {
        final dateFormat = DateFormat('dd.MM.yyyy');
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Toplu Kesinti Uygula', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Column selection
                    Text('Kesinti Türü', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedCol,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: columns
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.inter(fontSize: 13))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedCol = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    // Rate Input
                    Text('Kesinti Oranı (%)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: rateCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Active Toggle Button
                    Row(
                      children: [
                        Text('Durum: ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                        const SizedBox(width: 8),
                        Switch(
                          value: active,
                          activeColor: AppColors.primary600,
                          onChanged: (val) => setDlgState(() => active = val),
                        ),
                        Text(active ? 'Aktif' : 'Pasif', style: GoogleFonts.inter(fontSize: 13, color: active ? AppColors.successDark : AppColors.dangerDark, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Start date
                    Text('Başlangıç Tarihi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: const Locale('tr', 'TR'),
                        );
                        if (picked != null) {
                          setDlgState(() => startDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.gray300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              startDate != null ? dateFormat.format(startDate!) : 'Seçiniz',
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gray400),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // End date
                    Text('Bitiş Tarihi (Ucu açık bırakılabilir)', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                          locale: const Locale('tr', 'TR'),
                        );
                        if (picked != null) {
                          setDlgState(() => endDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.gray300),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              endDate != null ? dateFormat.format(endDate!) : 'Devamlı (Ucu Açık)',
                              style: GoogleFonts.inter(fontSize: 13),
                            ),
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gray400),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 24),

                    // Target filters
                    Text('Bölge Filtresi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedRegion,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: regions
                          .map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.inter(fontSize: 13))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedRegion = v);
                      },
                    ),
                    const SizedBox(height: 12),

                    Text('Grup / Mahalle Filtresi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedGroup,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      items: groups
                          .map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.inter(fontSize: 13))))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setDlgState(() => selectedGroup = v);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Vazgeç', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600, foregroundColor: Colors.white),
                  onPressed: () async {
                    final double? newRate = double.tryParse(rateCtrl.text.replaceAll(',', '.'));
                    if (newRate == null || newRate < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Geçerli bir oran giriniz.'), backgroundColor: AppColors.danger),
                      );
                      return;
                    }

                    // Collect target docs
                    final targets = producers.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final r = data['bolge'] ?? '';
                      final g = data['group'] ?? '';
                      final matchRegion = selectedRegion == 'Tümü' || r == selectedRegion;
                      final matchGroup = selectedGroup == 'Tümü' || g == selectedGroup;
                      return matchRegion && matchGroup;
                    }).toList();

                    if (targets.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Seçilen kriterlere uyan üretici bulunamadı.'), backgroundColor: AppColors.danger),
                      );
                      return;
                    }

                    final updatedData = {
                      'oran': newRate,
                      'aktif': active,
                      'baslangic': startDate != null ? DateFormat('yyyy-MM-dd').format(startDate!) : null,
                      'bitis': endDate != null ? DateFormat('yyyy-MM-dd').format(endDate!) : null,
                    };

                    final batch = FirebaseFirestore.instance.batch();
                    for (var doc in targets) {
                      batch.update(doc.reference, {
                        'kesintiAyarlari.$selectedCol': updatedData,
                      });
                    }

                    try {
                      await batch.commit();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${targets.length} üreticiye toplu $selectedCol kesintisi başarıyla uygulandı!'), backgroundColor: AppColors.success),
                      );
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
                      );
                    }
                  },
                  child: const Text('Uygula'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  DateTime _parseDate(String s) {
    if (s.contains('-')) {
      return DateTime.parse(s);
    } else {
      final parts = s.split('.');
      return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
    }
  }

  // Checks if a date falls within the scheduled date range
  bool _isDeductionScheduledActive(Map<String, dynamic> settings, DateTime testDate) {
    if (settings['aktif'] != true) return false;
    final String? start = settings['baslangic'] as String?;
    final String? end = settings['bitis'] as String?;

    if (start != null && start.isNotEmpty) {
      try {
        final startDate = _parseDate(start);
        final tOnly = DateTime(testDate.year, testDate.month, testDate.day);
        final sOnly = DateTime(startDate.year, startDate.month, startDate.day);
        if (tOnly.isBefore(sOnly)) return false;
      } catch (_) {}
    }

    if (end != null && end.isNotEmpty) {
      try {
        final endDate = _parseDate(end);
        final tOnly = DateTime(testDate.year, testDate.month, testDate.day);
        final eOnly = DateTime(endDate.year, endDate.month, endDate.day);
        if (tOnly.isAfter(eOnly)) return false;
      } catch (_) {}
    }

    return true;
  }

  Widget _buildPeriodChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary100,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(color: isSelected ? AppColors.primary700 : AppColors.gray600),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? AppColors.primary300 : AppColors.gray200),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('finans_ayarlari').doc(currentFirmaName).snapshots(),
      builder: (context, settingsSnap) {
        double defaultBagkur = 2.10;
        double defaultStopaj = 1.00;
        double defaultBorsa = 0.20;

        final List<String> dynamicColumns = [];
        if (settingsSnap.hasData && settingsSnap.data!.exists) {
          final sData = settingsSnap.data!.data() as Map<String, dynamic>;
          defaultBagkur = (sData['bagkurOran'] as num?)?.toDouble() ?? 2.10;
          defaultStopaj = (sData['stopajOran'] as num?)?.toDouble() ?? 1.00;
          defaultBorsa = (sData['borsaOran'] as num?)?.toDouble() ?? 0.20;

          final dynamicCols = sData['kesintiTurleri'] as List?;
          if (dynamicCols != null) {
            dynamicColumns.addAll(dynamicCols.map((e) => e.toString()));
          }
        }
        if (dynamicColumns.isEmpty) {
          dynamicColumns.addAll(['Bağkur', 'Stopaj', 'Borsa']);
        }

        final Map<String, double> defaultRates = {
          'Bağkur': defaultBagkur,
          'Stopaj': defaultStopaj,
          'Borsa': defaultBorsa,
        };

        return StreamBuilder<QuerySnapshot>(
          stream: FirestoreService().getProducersStream(firma: currentFirmaName),
          builder: (context, producersSnap) {
            if (producersSnap.connectionState == ConnectionState.waiting) {
              return const Scaffold(body: Center(child: CircularProgressIndicator()));
            }

            final producers = producersSnap.hasData ? producersSnap.data!.docs : <QueryDocumentSnapshot<Object?>>[];

            // Extract unique regions and groups for filters
            final List<String> regionsList = ['Tümü'];
            final List<String> groupsList = ['Tümü'];
            for (var doc in producers) {
              final data = doc.data() as Map<String, dynamic>;
              final r = data['bolge'] as String?;
              final g = data['group'] as String?;
              if (r != null && r.isNotEmpty && !regionsList.contains(r)) regionsList.add(r);
              if (g != null && g.isNotEmpty && !groupsList.contains(g)) groupsList.add(g);
            }

            // Filter producers list locally
            final filteredProducers = producers.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] as String? ?? '';
              final r = data['bolge'] as String? ?? '';
              final g = data['group'] as String? ?? '';

              final matchSearch = _searchQuery.isEmpty || name.toLowerCase().contains(_searchQuery.toLowerCase());
              final matchRegion = _selectedFilterRegion == null || _selectedFilterRegion == 'Tümü' || r == _selectedFilterRegion;
              final matchGroup = _selectedFilterGroup == null || _selectedFilterGroup == 'Tümü' || g == _selectedFilterGroup;

              return matchSearch && matchRegion && matchGroup;
            }).toList();

            // Initialize controllers if they are empty
            if (_bagkurCtrl.text.isEmpty && !_oranlarLoading) {
              _bagkurCtrl.text = defaultBagkur.toStringAsFixed(2);
              _stopajCtrl.text = defaultStopaj.toStringAsFixed(2);
              _borsaCtrl.text = defaultBorsa.toStringAsFixed(2);
            }

            return DefaultTabController(
              length: 2,
              initialIndex: widget.initialTab,
              child: Scaffold(
                appBar: AppBar(
                  title: Text('Kesintiler', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.go('/firma/finans'),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.settings_rounded, color: AppColors.gray700),
                      tooltip: 'Sütunları Yönet',
                      onPressed: () => _showColumnManagerDialog(context, currentFirmaName, dynamicColumns),
                    ),
                  ],
                  bottom: const TabBar(
                    tabs: [
                      Tab(text: 'Müşteri Kesintileri'),
                      Tab(text: 'Kesinti Oranları'),
                    ],
                    indicatorColor: AppColors.primary600,
                    labelColor: AppColors.primary600,
                    unselectedLabelColor: AppColors.gray500,
                  ),
                ),
                backgroundColor: AppColors.gray50,
                body: TabBarView(
                  children: [
                    // Tab 1: Müşteri Kesintileri Grid
                    Column(
                      children: [
                  // Filter bar Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: AppColors.gray200)),
                    ),
                    child: Column(
                      children: [
                        // Search + Batch Apply button
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.gray50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.gray200),
                                ),
                                child: TextField(
                                  controller: _searchCtrl,
                                  onChanged: (val) => setState(() => _searchQuery = val),
                                  decoration: InputDecoration(
                                    hintText: 'Müşteri ara...',
                                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400, size: 18),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: () => _showBatchApplyDialog(context, currentFirmaName, dynamicColumns, producers),
                              icon: const Icon(Icons.people_alt_rounded, size: 16),
                              label: const Text('Toplu İşlem'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary600,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                textStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Dropdown Filters
                        Row(
                          children: [
                            // Region filter
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedFilterRegion ?? 'Tümü',
                                decoration: const InputDecoration(
                                  labelText: 'Bölge',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(),
                                ),
                                items: regionsList
                                    .map((r) => DropdownMenuItem(value: r, child: Text(r, style: GoogleFonts.inter(fontSize: 11))))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedFilterRegion = v),
                              ),
                            ),
                            const SizedBox(width: 8),

                            // Group filter
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                value: _selectedFilterGroup ?? 'Tümü',
                                decoration: const InputDecoration(
                                  labelText: 'Grup / Mahalle',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  border: OutlineInputBorder(),
                                ),
                                items: groupsList
                                    .map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.inter(fontSize: 11))))
                                    .toList(),
                                onChanged: (v) => setState(() => _selectedFilterGroup = v),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Quick Period Selectors
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildPeriodChip('Tümü', _quickPeriod == 'Tümü', () {
                                setState(() {
                                  _quickPeriod = 'Tümü';
                                  _selectedDateRange = null;
                                });
                              }),
                              const SizedBox(width: 8),
                              _buildPeriodChip('Bu Hafta', _quickPeriod == 'Bu Hafta', () {
                                setState(() {
                                  _quickPeriod = 'Bu Hafta';
                                  final now = DateTime.now();
                                  _selectedDateRange = DateTimeRange(
                                    start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
                                    end: DateTime(now.year, now.month, now.day),
                                  );
                                });
                              }),
                              const SizedBox(width: 8),
                              _buildPeriodChip('Bu Ay', _quickPeriod == 'Bu Ay', () {
                                setState(() {
                                  _quickPeriod = 'Bu Ay';
                                  final now = DateTime.now();
                                  _selectedDateRange = DateTimeRange(
                                    start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 30)),
                                    end: DateTime(now.year, now.month, now.day),
                                  );
                                });
                              }),
                              const SizedBox(width: 8),
                              _buildPeriodChip('Özel Aralık', _quickPeriod == 'Özel', () {
                                _selectDateRange(context);
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Date range filter
                        PremiumDateRangeFilter(
                          selectedRange: _selectedDateRange,
                          onRangeChanged: (range) {
                            setState(() {
                              _selectedDateRange = range;
                              _quickPeriod = range != null ? 'Özel' : 'Tümü';
                            });
                          },
                          label: 'Tüm Dönemler (Kesinti dönemsellik filtresi uygula)',
                        ),
                      ],
                    ),
                  ),

                  // Scrollable Grid Table
                  Expanded(
                    child: filteredProducers.isEmpty
                        ? Center(
                            child: Text(
                              'Eşleşen müşteri bulunamadı.',
                              style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13),
                            ),
                          )
                        : SingleChildScrollView(
                            scrollDirection: Axis.vertical,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                dataRowMinHeight: 75,
                                dataRowMaxHeight: 85,
                                border: TableBorder.all(color: AppColors.gray200, width: 0.5),
                                columnSpacing: 32,
                                columns: [
                                  DataColumn(
                                    label: Text(
                                      'Müşteri',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.gray700, fontSize: 12),
                                    ),
                                  ),
                                  ...dynamicColumns.map((col) {
                                    return DataColumn(
                                      label: Container(
                                        padding: const EdgeInsets.symmetric(vertical: 4),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Text(
                                              col,
                                              style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.gray700, fontSize: 12),
                                            ),
                                            Text(
                                              '%',
                                              style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                ],
                                rows: filteredProducers.map((prodDoc) {
                                  final pData = prodDoc.data() as Map<String, dynamic>;
                                  final String name = pData['name'] ?? '';
                                  final String email = pData['email'] ?? '';
                                  final Map<String, dynamic> kesintiMap = pData['kesintiAyarlari'] as Map<String, dynamic>? ?? {};

                                  return DataRow(
                                    cells: [
                                      // Customer Info Cell
                                      DataCell(
                                        Container(
                                          constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                name,
                                                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gray900),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                email.isNotEmpty ? email : (pData['group'] ?? 'Grup Yok'),
                                                style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      // Deduction cells
                                      ...dynamicColumns.map((col) {
                                        final colSettings = kesintiMap[col] as Map<String, dynamic>? ?? {};
                                        final double defaultRate = defaultRates[col] ?? 0.00;
                                        final double rate = (colSettings['oran'] as num?)?.toDouble() ?? defaultRate;
                                        
                                        // Determine active status:
                                        // 1. Is checked active?
                                        bool isActive = colSettings['aktif'] == true || (!kesintiMap.containsKey(col));
                                        
                                        // 2. Is range valid for filter?
                                        bool isDateActive = true;
                                        if (_selectedDateRange != null && colSettings.isNotEmpty) {
                                          final rangeStart = _selectedDateRange!.start;
                                          final rangeEnd = _selectedDateRange!.end;
                                          // check start/end overlap
                                          final startActive = _isDeductionScheduledActive(colSettings, rangeStart);
                                          final endActive = _isDeductionScheduledActive(colSettings, rangeEnd);
                                          isDateActive = startActive || endActive;
                                        }

                                        final bool finalActiveState = isActive && isDateActive;
                                        final bool hasScheduledRange = colSettings.containsKey('baslangic') && colSettings['baslangic'] != null;

                                        return DataCell(
                                          Container(
                                            padding: const EdgeInsets.symmetric(vertical: 4),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                // Value indicator box
                                                InkWell(
                                                  onTap: () => _showDeductionSettingsDialog(context, prodDoc, col, colSettings, defaultRate),
                                                  child: Container(
                                                    width: 68,
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      border: Border.all(color: hasScheduledRange ? AppColors.primary300 : AppColors.gray300),
                                                      borderRadius: BorderRadius.circular(8),
                                                      boxShadow: AppShadows.sm,
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.center,
                                                      children: [
                                                        Text(
                                                          rate.toStringAsFixed(1),
                                                          style: GoogleFonts.inter(
                                                            fontSize: 12,
                                                            fontWeight: FontWeight.bold,
                                                            color: hasScheduledRange ? AppColors.primary700 : AppColors.gray800,
                                                          ),
                                                        ),
                                                        if (hasScheduledRange) ...[
                                                          const SizedBox(width: 2),
                                                          const Icon(Icons.calendar_month_rounded, size: 10, color: AppColors.primary500),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 6),

                                                // Checked active status toggle button
                                                InkWell(
                                                  onTap: () => _toggleDeduction(prodDoc, col, colSettings, finalActiveState),
                                                  child: Container(
                                                    width: 26,
                                                    height: 26,
                                                    decoration: BoxDecoration(
                                                      color: finalActiveState ? AppColors.successLight : AppColors.gray200,
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Icon(
                                                      finalActiveState ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                      color: finalActiveState ? AppColors.successDark : AppColors.gray500,
                                                      size: 16,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                    ),
                    ],
                    ),
                    // Tab 2: Kesinti Oranları
                    _buildKesintiOranlariTab(currentFirmaName),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildKesintiOranlariTab(String currentFirmaName) {
    return Form(
      key: _oranlarFormKey,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Yasal Kesinti Yüzdeleri',
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
          ),
          const SizedBox(height: 8),
          Text(
            'Üretici süt hak edişlerinden (süt geliri üzerinden) kesilecek yasal oranları ayarlayın. Boş bırakırsanız veya hatalı değer girilirse varsayılan yasal oranlar geçerli olur.',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
          ),
          const SizedBox(height: 24),
          
          TextFormField(
            controller: _bagkurCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Bağkur Kesinti Oranı (%)',
              suffixText: '%',
              hintText: 'Örn: 2.10',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Oran giriniz';
              if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Geçerli bir sayı giriniz';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _stopajCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Stopaj Kesinti Oranı (%)',
              suffixText: '%',
              hintText: 'Örn: 1.00',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Oran giriniz';
              if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Geçerli bir sayı giriniz';
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _borsaCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Borsa Kesinti Oranı (%)',
              suffixText: '%',
              hintText: 'Örn: 0.20',
            ),
            validator: (val) {
              if (val == null || val.trim().isEmpty) return 'Oran giriniz';
              if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Geçerli bir sayı giriniz';
              return null;
            },
          ),
          const SizedBox(height: 32),
          
          ElevatedButton(
            onPressed: _oranlarLoading ? null : () async {
              if (_oranlarFormKey.currentState!.validate()) {
                setState(() => _oranlarLoading = true);
                final bk = double.parse(_bagkurCtrl.text.replaceAll(',', '.'));
                final st = double.parse(_stopajCtrl.text.replaceAll(',', '.'));
                final bs = double.parse(_borsaCtrl.text.replaceAll(',', '.'));

                await FirebaseFirestore.instance.collection('finans_ayarlari').doc(currentFirmaName).set({
                  'bagkurOran': bk,
                  'stopajOran': st,
                  'borsaOran': bs,
                  'timestamp': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                setState(() => _oranlarLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kesinti oranları başarıyla kaydedildi!'), backgroundColor: AppColors.success),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: _oranlarLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Oranları Kaydet'),
          ),
        ],
      ),
    );
  }
}
