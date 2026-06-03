import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:excel/excel.dart' hide Border, TextSpan;
import 'package:file_picker/file_picker.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';
import '../../utils/file_download_helper.dart';
import '../../widgets/location_picker_field.dart';

class FirmaUreticiListesiScreen extends StatefulWidget {
  final String? groupFilter;
  final String? birlikFilter;
  final String? bolgeFilter;
  const FirmaUreticiListesiScreen({super.key, this.groupFilter, this.birlikFilter, this.bolgeFilter});

  @override
  State<FirmaUreticiListesiScreen> createState() => _FirmaUreticiListesiScreenState();
}

class _FirmaUreticiListesiScreenState extends State<FirmaUreticiListesiScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  final Set<String> _selectedProducerIds = {};
  String? _groupFilterState;
  String? _birlikFilterState;
  String? _bolgeFilterState;

  @override
  void initState() {
    super.initState();
    _groupFilterState = widget.groupFilter;
    _birlikFilterState = widget.birlikFilter;
    _bolgeFilterState = widget.bolgeFilter;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _deleteSelectedProducers(List<DocumentSnapshot> filteredDocs) {
    final selectedCount = _selectedProducerIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Seçilileri Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Seçili $selectedCount üreticiyi tamamen silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final batch = _db.batch();
              for (var id in _selectedProducerIds) {
                final doc = filteredDocs.firstWhere((d) => d.id == id);
                batch.delete(doc.reference);
              }
              await batch.commit();
              setState(() {
                _selectedProducerIds.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Seçili üreticiler başarıyla silindi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );
  }

  void _assignSelectedProducers(List<DocumentSnapshot> filteredDocs) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Fetch groups and birlikler
    final groupsSnap = await _db.collection('musteri_gruplari').where('firma', isEqualTo: currentFirmaName).get();
    final List<String> groups = groupsSnap.docs.map((d) => d['ad'] as String).toList();

    final birliklerSnap = await _db.collection('birlikler').where('firma', isEqualTo: currentFirmaName).get();
    final List<String> birlikler = birliklerSnap.docs.map((d) => d['ad'] as String).toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String selectedGroup = 'Değiştirme';
        String selectedBirlik = 'Değiştirme';

        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              title: Text('Toplu Atama Yap', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedGroup,
                    decoration: const InputDecoration(labelText: 'Grup / Köy Ataması'),
                    items: ['Değiştirme', 'Genel', ...groups].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedGroup = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedBirlik,
                    decoration: const InputDecoration(labelText: 'Birlik Ataması'),
                    items: ['Değiştirme', 'Yok', ...birlikler].map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (val) {
                      if (val != null) setDlgState(() => selectedBirlik = val);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final batch = _db.batch();
                    final Map<String, dynamic> updates = {};
                    if (selectedGroup != 'Değiştirme') {
                      updates['group'] = selectedGroup;
                    }
                    if (selectedBirlik != 'Değiştirme') {
                      updates['birlik'] = selectedBirlik;
                    }

                    if (updates.isNotEmpty) {
                      for (var id in _selectedProducerIds) {
                        final doc = filteredDocs.firstWhere((d) => d.id == id);
                        batch.update(doc.reference, updates);
                      }
                      await batch.commit();
                    }

                    setState(() {
                      _selectedProducerIds.clear();
                    });

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Atama başarıyla güncellendi!'), backgroundColor: AppColors.success),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
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

  void _setSiparisIzniForSelected(List<DocumentSnapshot> filteredDocs, bool enable) async {
    final selectedCount = _selectedProducerIds.length;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(enable ? 'Sipariş İzni Ver' : 'Sipariş İznini Kaldır', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('Seçili $selectedCount üretici için sipariş verme iznini ${enable ? "etkinleştirmek" : "kaldırmak"} istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final batch = _db.batch();
              for (var id in _selectedProducerIds) {
                final doc = filteredDocs.firstWhere((d) => d.id == id);
                batch.update(doc.reference, {'siparisIzni': enable});
              }
              await batch.commit();
              setState(() {
                _selectedProducerIds.clear();
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Seçili üreticilerin sipariş izinleri ${enable ? "etkinleştirildi" : "kaldırıldı"}!'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: enable ? AppColors.primary600 : AppColors.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Evet'),
          ),
        ],
      ),
    );
  }

  void _downloadBirlikPdfReport() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Show dialog to choose Month/Year
    showDialog(
      context: context,
      builder: (ctx) {
        DateTime tempMonth = DateTime.now();
        final List<String> monthNames = [
          'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
        ];
        int tempYear = tempMonth.year;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text('Dönem Seçimi (PDF Raporu)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: 300,
                height: 250,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded),
                          onPressed: () {
                            setModalState(() {
                              tempYear--;
                            });
                          },
                        ),
                        Text('$tempYear', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded),
                          onPressed: () {
                            setModalState(() {
                              tempYear++;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          childAspectRatio: 1.5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: 12,
                        itemBuilder: (context, index) {
                          final isSelected = tempMonth.month == (index + 1);
                          return InkWell(
                            onTap: () {
                              setModalState(() {
                                tempMonth = DateTime(tempYear, index + 1);
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary600 : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                monthNames[index],
                                style: GoogleFonts.inter(
                                  color: isSelected ? Colors.white : AppColors.gray800,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
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
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _generateBirlikPdf(tempMonth);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Rapor Oluştur'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateBirlikPdf(DateTime selectedMonth) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Fetch Birlik producers
    final prodQuery = await _db.collection('ureticiler')
        .where('firmalar', arrayContains: currentFirmaName)
        .where('birlik', isEqualTo: _birlikFilterState)
        .get();

    if (prodQuery.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu birliğe kayıtlı üretici bulunamadı.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    // Fetch prices
    final pricesQuery = await _db.collection('sut_fiyatlari')
        .where('firma', isEqualTo: currentFirmaName)
        .get();
    final priceList = pricesQuery.docs.map((d) => d.data() as Map<String, dynamic>).toList();

    // Fetch default settings
    final settingsDoc = await _db.collection('finans_ayarlari').doc(currentFirmaName).get();
    double bagkurOran = 2.10;
    double stopajOran = 1.00;
    double borsaOran = 0.20;
    if (settingsDoc.exists) {
      final sData = settingsDoc.data() as Map<String, dynamic>;
      bagkurOran = (sData['bagkurOran'] as num?)?.toDouble() ?? 2.10;
      stopajOran = (sData['stopajOran'] as num?)?.toDouble() ?? 1.00;
      borsaOran = (sData['borsaOran'] as num?)?.toDouble() ?? 0.20;
    }

    // Fetch all collections in selected period
    final startOfMonth = DateTime(selectedMonth.year, selectedMonth.month, 1);
    final endOfMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 1).subtract(const Duration(microseconds: 1));

    final colQuery = await _db.collection('toplamalar')
        .where('firma', isEqualTo: currentFirmaName)
        .get();

    final List<Map<String, dynamic>> pdfRows = [];

    for (var doc in prodQuery.docs) {
      final pData = doc.data() as Map<String, dynamic>;
      final name = pData['name'] as String? ?? '';
      final phone = pData['phone'] as String? ?? '';
      final group = pData['group'] as String? ?? 'Genel';
      final bolge = pData['bolge'] as String? ?? 'Merkez';
      final tcNo = pData['tcNo'] as String? ?? '';
      final kesintiAyarlari = pData['kesintiAyarlari'] as Map<String, dynamic>?;

      // Filter collections for this producer
      final pCols = colQuery.docs.where((c) {
        final cData = c.data() as Map<String, dynamic>;
        if (cData['u'] != name) return false;
        final ts = cData['timestamp'] as Timestamp?;
        if (ts == null) return false;
        final date = ts.toDate();
        return date.isAfter(startOfMonth.subtract(const Duration(microseconds: 1))) && date.isBefore(endOfMonth.add(const Duration(microseconds: 1)));
      }).toList();

      double totalLitres = 0.0;
      double grossTutari = 0.0;

      for (var col in pCols) {
        final cData = col.data() as Map<String, dynamic>;
        final double m = (cData['m'] as num?)?.toDouble() ?? 0.0;
        totalLitres += m;

        final String rawType = cData['tip'] ?? 'Soğuk süt';
        final String priceKey = FirestoreService().mapMilkTypeToPriceKey(rawType);
        final double price = FirestoreService().resolveMilkPrice(
          prices: priceList,
          producerName: name,
          bolge: bolge,
          group: group,
          type: priceKey,
        );
        grossTutari += m * price;
      }

      if (totalLitres == 0) continue; // Only include active producers in report

      // Determine active deduction rates
      double pBagkur = 0.0;
      double pStopaj = 0.0;
      double pBorsa = 0.0;

      void checkDeduction(String type, double defaultRate, ValueChanged<double> onResult) {
        double rate = defaultRate;
        bool active = true;
        if (kesintiAyarlari != null && kesintiAyarlari.containsKey(type)) {
          final s = kesintiAyarlari[type];
          if (s is Map) {
            rate = (s['oran'] as num?)?.toDouble() ?? 0.0;
            active = s['aktif'] == true;
          }
        }
        if (active) {
          onResult(grossTutari * (rate / 100.0));
        }
      }

      checkDeduction('Bağkur', bagkurOran, (val) => pBagkur = val);
      checkDeduction('Stopaj', stopajOran, (val) => pStopaj = val);
      checkDeduction('Borsa', borsaOran, (val) => pBorsa = val);

      final double netTutari = grossTutari - pBagkur - pStopaj - pBorsa;

      pdfRows.add({
        'name': name,
        'tc': tcNo,
        'litres': totalLitres,
        'gross': grossTutari,
        'bagkur': pBagkur,
        'stopaj': pStopaj,
        'borsa': pBorsa,
        'net': netTutari,
      });
    }

    if (pdfRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seçili dönemde süt teslimatı yapan üye bulunamadı.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    // Generate PDF document
    try {
      final pdf = pw.Document();
      pw.Font fontRegular = pw.Font.helvetica();
      pw.Font fontBold = pw.Font.helveticaBold();
      bool useSanitized = false;

      try {
        fontRegular = await PdfGoogleFonts.robotoRegular();
        fontBold = await PdfGoogleFonts.robotoBold();
      } catch (e) {
        useSanitized = true;
      }

      String sanitize(String text) {
        if (!useSanitized) return text;
        final Map<String, String> translation = {
          'ı': 'i', 'İ': 'I', 'ğ': 'g', 'Ğ': 'G', 'ü': 'u', 'Ü': 'U',
          'ş': 's', 'Ş': 'S', 'ö': 'o', 'Ö': 'O', 'ç': 'c', 'Ç': 'C',
        };
        String result = text;
        translation.forEach((tr, eng) {
          result = result.replaceAll(tr, eng);
        });
        return result;
      }

      final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(selectedMonth);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(sanitize(currentFirmaName.toUpperCase()), style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.blue800)),
                      pw.SizedBox(height: 4),
                      pw.Text(sanitize('${_birlikFilterState!.toUpperCase()} - $monthStr RAPORU'), style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Text(sanitize('Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}'), style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1.5, color: PdfColors.blue800),
              pw.SizedBox(height: 12),

              pw.TableHelper.fromTextArray(
                headers: [
                  sanitize('Üye Adı Soyadı'),
                  sanitize('TC / Vergi No'),
                  sanitize('Süt (LT)'),
                  sanitize('Brüt (₺)'),
                  sanitize('Bağkur (₺)'),
                  sanitize('Stopaj (₺)'),
                  sanitize('Borsa (₺)'),
                  sanitize('Net Tutar (₺)'),
                  sanitize('İmza'),
                ],
                data: pdfRows.map((row) => [
                  sanitize(row['name']),
                  sanitize(row['tc'].toString().isEmpty ? '-' : row['tc']),
                  row['litres'].toStringAsFixed(1),
                  row['gross'].toStringAsFixed(2),
                  row['bagkur'].toStringAsFixed(2),
                  row['stopaj'].toStringAsFixed(2),
                  row['borsa'].toStringAsFixed(2),
                  row['net'].toStringAsFixed(2),
                  '',
                ]).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 8, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: pw.TextStyle(font: fontRegular, fontSize: 8),
                cellAlignment: pw.Alignment.centerLeft,
                rowDecoration: const pw.BoxDecoration(
                  border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
                ),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'birlik_raporu_${_birlikFilterState}_${DateFormat('yyyyMM').format(selectedMonth)}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF Raporu oluşturulamadı: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _showAddProducerDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Check limits
    try {
      final firmSnap = await _db.collection('firmalar').where('ad', isEqualTo: currentFirmaName).limit(1).get();
      if (firmSnap.docs.isNotEmpty) {
        final firmData = firmSnap.docs.first.data();
        final int maxUretici = (firmData['maxUretici'] as num?)?.toInt() ?? 100;
        final ureticiSnap = await _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).get();
        if (ureticiSnap.docs.length >= maxUretici) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Maksimum üretici limitine ulaşıldı ($maxUretici). Daha fazla üretici ekleyemezsiniz.'),
                backgroundColor: AppColors.danger,
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      print('Limit check error: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final bolgeCtrl = TextEditingController();
        final tcNoCtrl = TextEditingController();
        final latCtrl = TextEditingController();
        final lngCtrl = TextEditingController();

        String? selectedGroup;
        String? selectedBirlik;

        String selectedMilkType = 'Soğuk Süt';
        bool isYem = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Yeni Üretici Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Bulk Add Banner/Button
                      InkWell(
                        onTap: () {
                          Navigator.pop(ctx); // Close individual add dialog
                          _showBulkAddProducerDialog(); // Open bulk add dialog
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.grid_on_rounded, color: Colors.white, size: 22),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Toplu Üretici Ekle (Excel)',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Excel dosyası ile hızlıca yükleyin',
                                      style: GoogleFonts.inter(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: Colors.white),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Row(
                        children: [
                          Expanded(child: Divider()),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('veya tek tek ekleyin', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ),
                          Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Ad Soyad', hintText: 'Örn: Mustafa Yılmaz'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: tcNoCtrl,
                        decoration: const InputDecoration(labelText: 'TC / Vergi No (İsteğe Bağlı)', hintText: 'Örn: 12345678901'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                          hintText: 'Örn: 0532 999 8877',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('musteri_bolgeleri').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final List<String> bolgeler = docs.map((d) => d['ad'] as String).toList();
                          
                          String? currentSelected;
                          if (bolgeCtrl.text.isNotEmpty && bolgeler.contains(bolgeCtrl.text)) {
                            currentSelected = bolgeCtrl.text;
                          } else {
                            currentSelected = null;
                          }
                          
                          if (bolgeler.isEmpty) {
                            return TextField(
                              controller: bolgeCtrl,
                              decoration: const InputDecoration(labelText: 'Bölge / İlçe', hintText: 'Örn: Kocasinan'),
                            );
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: currentSelected,
                            hint: const Text('Bölge Seçin'),
                            decoration: const InputDecoration(labelText: 'Bölge / İlçe'),
                            items: bolgeler.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  bolgeCtrl.text = val;
                                });
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Group dropdown (loaded dynamically)
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('musteri_gruplari').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final List<String> groups = docs.map((d) => d['ad'] as String).toList();
                          
                          return DropdownButtonFormField<String>(
                            value: selectedGroup,
                            hint: const Text('Üretici Grubu Seçin'),
                            decoration: const InputDecoration(labelText: 'Grup'),
                            items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) => setState(() => selectedGroup = val),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Birlik dropdown (loaded dynamically)
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('birlikler').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final List<String> birlikler = docs.map((d) => d['ad'] as String).toList();
                          
                          return DropdownButtonFormField<String>(
                            value: selectedBirlik,
                            hint: const Text('Birlik Seçin (İsteğe Bağlı)'),
                            decoration: const InputDecoration(labelText: 'Birlik Kaydı'),
                            items: birlikler.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (val) => setState(() => selectedBirlik = val),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Location picker
                      LocationPickerField(
                        latController: latCtrl,
                        lngController: lngCtrl,
                        setDialogState: setState,
                      ),
                      const SizedBox(height: 24),

                      // Custom selector
                      _buildMilkTypeSelector(
                        selectedType: selectedMilkType,
                        onChanged: (val) => setState(() => selectedMilkType = val),
                        enabled: !isYem,
                      ),
                      const SizedBox(height: 16),
                      _buildCustomerTypeToggle(
                        isYem,
                        (val) => setState(() => isYem = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final bolge = bolgeCtrl.text.trim();
                    final tcNo = tcNoCtrl.text.trim();
                    final saveMilkType = isYem ? 'Yok' : selectedMilkType;

                    if (name.isEmpty || phone.isEmpty || bolge.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lütfen Ad Soyad, Telefon ve Bölge alanlarını doldurun.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    // Check if producer with this phone number already exists in the system
                    final query = await _db.collection('ureticiler').where('phone', isEqualTo: phone).limit(1).get();
                    if (query.docs.isNotEmpty) {
                      final doc = query.docs.first;
                      final List<String> existingFirmalar = List<String>.from(doc['firmalar'] ?? []);
                      if (existingFirmalar.contains(currentFirmaName)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bu telefon numarasına sahip bir üretici zaten firmanıza kayıtlı!'), backgroundColor: AppColors.danger),
                          );
                        }
                        return;
                      } else {
                        existingFirmalar.add(currentFirmaName);
                        await doc.reference.update({
                          'name': name,
                          'bolge': bolge,
                          'tcNo': tcNo,
                          'group': selectedGroup ?? 'Genel',
                          'birlik': selectedBirlik ?? 'Yok',
                          'firmalar': existingFirmalar,
                          'lastMilkType': saveMilkType,
                          'customerType': isYem ? 'yem' : 'sut',
                        });
                        if (context.mounted) {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Üretici sisteme kayıtlıydı, firmanıza başarıyla eklendi!'), backgroundColor: AppColors.success),
                          );
                        }
                        return;
                      }
                    }

                    final Map<String, dynamic> newData = {
                      'name': name,
                      'phone': phone,
                      'bolge': bolge,
                      'tcNo': tcNo,
                      'group': selectedGroup ?? 'Genel',
                      'birlik': selectedBirlik ?? 'Yok',
                      'avg': 30.0,
                      'total': 0.0,
                      'firmalar': [currentFirmaName],
                      'lastMilkType': saveMilkType,
                      'customerType': isYem ? 'yem' : 'sut',
                    };
                    final latVal = double.tryParse(latCtrl.text.trim());
                    final lngVal = double.tryParse(lngCtrl.text.trim());
                    if (latVal != null && lngVal != null) {
                      newData['latitude'] = latVal;
                      newData['longitude'] = lngVal;
                    } else if (latCtrl.text.trim().isNotEmpty) {
                      newData['mapsLink'] = latCtrl.text.trim();
                    }
                    await _db.collection('ureticiler').add(newData);

                    if (context.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Yeni üretici başarıyla eklendi!'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<int>? _generateExcelTemplate() {
    final excelObj = Excel.createExcel();
    final sheet = excelObj['Sheet1'];
    
    // Set headers
    sheet.appendRow([
      TextCellValue('Ad'),
      TextCellValue('Soyad'),
      TextCellValue('Telefon'),
      TextCellValue('Bölge'),
      TextCellValue('TC No'),
      TextCellValue('Grup'),
      TextCellValue('Birlik'),
      TextCellValue('Müşteri Türü (sut/yem)'),
      TextCellValue('Süt Türü')
    ]);
    
    // Add sample row
    sheet.appendRow([
      TextCellValue('Mehmet'),
      TextCellValue('Kaya'),
      TextCellValue('05334445566'),
      TextCellValue('Kocasinan'),
      TextCellValue('12345678901'),
      TextCellValue('Genel'),
      TextCellValue('Yok'),
      TextCellValue('sut'),
      TextCellValue('Soğuk Süt')
    ]);

    return excelObj.save();
  }

  Future<int> _processExcelUpload(List<int> bytes, String currentFirmaName) async {
    final decoded = Excel.decodeBytes(bytes);
    int addedCount = 0;
    
    for (var table in decoded.tables.keys) {
      final t = decoded.tables[table]!;
      if (t.rows.isEmpty) continue;
      
      // The first row is headers
      final headers = t.rows.first.map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '').toList();
      
      // Let's find column indexes
      int adIdx = headers.indexOf('ad');
      int soyadIdx = headers.indexOf('soyad');
      int telIdx = headers.indexOf('telefon');
      int bolgeIdx = headers.indexOf('bölge');
      int tcIdx = headers.indexOf('tc no');
      int grupIdx = headers.indexOf('grup');
      int birlikIdx = headers.indexOf('birlik');
      int tipIdx = headers.indexOf('müşteri türü (sut/yem)');
      int sutTurIdx = headers.indexOf('süt türü');
      
      // Fallback index search by name if headers not matched exactly
      if (adIdx == -1) adIdx = 0;
      if (soyadIdx == -1) soyadIdx = 1;
      if (telIdx == -1) telIdx = 2;
      if (bolgeIdx == -1) bolgeIdx = 3;
      if (tcIdx == -1) tcIdx = 4;
      if (grupIdx == -1) grupIdx = 5;
      if (birlikIdx == -1) birlikIdx = 6;
      if (tipIdx == -1) tipIdx = 7;
      if (sutTurIdx == -1) sutTurIdx = 8;
      
      // Iterate through data rows
      for (int i = 1; i < t.rows.length; i++) {
        final row = t.rows[i];
        if (row.isEmpty) continue;
        
        String getValue(int idx) {
          if (idx >= 0 && idx < row.length) {
            return row[idx]?.value?.toString().trim() ?? '';
          }
          return '';
        }
        
        final String adVal = getValue(adIdx);
        final String soyadVal = getValue(soyadIdx);
        final String telVal = getValue(telIdx);
        final String bolgeVal = getValue(bolgeIdx);
        final String tcVal = getValue(tcIdx);
        final String grupVal = getValue(grupIdx);
        final String birlikVal = getValue(birlikIdx);
        final String customerTypeVal = getValue(tipIdx).toLowerCase();
        final String lastMilkTypeVal = getValue(sutTurIdx);
        
        if (adVal.isEmpty || telVal.isEmpty) continue; // Ad and Telefon are mandatory
        
        final String name = '$adVal $soyadVal'.trim();
        final String phone = telVal;
        final String bolge = bolgeVal.isEmpty ? 'Merkez' : bolgeVal;
        final String group = grupVal.isEmpty ? 'Genel' : grupVal;
        final String birlik = birlikVal.isEmpty ? 'Yok' : birlikVal;
        final String customerType = (customerTypeVal == 'yem') ? 'yem' : 'sut';
        final String lastMilkType = lastMilkTypeVal.isEmpty ? 'Soğuk Süt' : lastMilkTypeVal;
        
        // Check if producer with this phone number already exists
        final query = await _db.collection('ureticiler').where('phone', isEqualTo: phone).limit(1).get();
        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          final List<String> existingFirmalar = List<String>.from(doc['firmalar'] ?? []);
          if (!existingFirmalar.contains(currentFirmaName)) {
            existingFirmalar.add(currentFirmaName);
          }
          await doc.reference.update({
            'name': name,
            'bolge': bolge,
            'tcNo': tcVal,
            'group': group,
            'birlik': birlik,
            'firmalar': existingFirmalar,
            'lastMilkType': lastMilkType,
            'customerType': customerType,
          });
        } else {
          // Add new
          await _db.collection('ureticiler').add({
            'name': name,
            'phone': phone,
            'bolge': bolge,
            'tcNo': tcVal,
            'group': group,
            'birlik': birlik,
            'avg': 30.0,
            'total': 0.0,
            'firmalar': [currentFirmaName],
            'lastMilkType': lastMilkType,
            'customerType': customerType,
          });
        }
        
        addedCount++;
      }
    }
    
    return addedCount;
  }

  void _showBulkAddProducerDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    
    showDialog(
      context: context,
      builder: (ctx) {
        bool isUploading = false;
        String? statusMessage;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('Toplu Üretici Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SizedBox(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Üreticilerinizi toplu olarak eklemek için şablon Excel dosyasını indirin, bilgileri doldurun ve tekrar yükleyin.',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray600),
                    ),
                    const SizedBox(height: 20),
                    
                    // Download template button
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          final templateBytes = _generateExcelTemplate();
                          if (templateBytes != null) {
                            final savedPath = await FileDownloadHelper.downloadBinaryFile(
                              fileName: 'toplu_uretici_sablon.xlsx',
                              bytes: templateBytes,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(savedPath != null
                                      ? 'Şablon indirildi: $savedPath'
                                      : 'Şablon Excel indirildi!'),
                                  backgroundColor: AppColors.success,
                                  duration: const Duration(seconds: 5),
                                ),
                              );
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text('Şablon Excel İndir', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary600),
                        foregroundColor: AppColors.primary600,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Upload Excel button
                    if (isUploading) ...[
                      const Center(child: CircularProgressIndicator()),
                      const SizedBox(height: 8),
                      if (statusMessage != null)
                        Text(
                          statusMessage!,
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                          textAlign: TextAlign.center,
                        ),
                    ] else ...[
                      ElevatedButton.icon(
                        onPressed: () async {
                          setDialogState(() {
                            isUploading = true;
                            statusMessage = 'Dosya seçiliyor...';
                          });
                          
                          try {
                            final result = await FilePicker.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['xlsx'],
                            );
                            
                            if (result != null) {
                              setDialogState(() {
                                statusMessage = 'Dosya okunuyor ve işleniyor...';
                              });
                              
                              List<int>? bytes;
                              if (result.files.single.bytes != null) {
                                bytes = result.files.single.bytes;
                              } else if (!kIsWeb && result.files.single.path != null) {
                                final file = File(result.files.single.path!);
                                bytes = await file.readAsBytes();
                              }
                              
                              if (bytes != null) {
                                final int addedCount = await _processExcelUpload(bytes, currentFirmaName);
                                
                                if (context.mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('$addedCount yeni üretici başarıyla eklendi!'), backgroundColor: AppColors.success),
                                  );
                                }
                              } else {
                                setDialogState(() {
                                  isUploading = false;
                                  statusMessage = 'Hata: Dosya içeriği okunamadı.';
                                });
                              }
                            } else {
                              setDialogState(() {
                                isUploading = false;
                                statusMessage = null;
                              });
                            }
                          } catch (e) {
                            setDialogState(() {
                              isUploading = false;
                              statusMessage = 'Hata: $e';
                            });
                          }
                        },
                        icon: const Icon(Icons.upload_file_rounded, size: 18),
                        label: Text('Doldurulan Excel Dosyasını Yükle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Kapat', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditProducerDialog(DocumentSnapshot doc) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final data = doc.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController(text: data['name'] ?? '');
        final phoneCtrl = TextEditingController(text: data['phone'] ?? '');
        final bolgeCtrl = TextEditingController(text: data['bolge'] ?? '');
        final tcNoCtrl = TextEditingController(text: data['tcNo'] ?? '');
        final mapsLinkVal = data['mapsLink'] as String? ?? '';
        final latCtrl = TextEditingController(
          text: (data['latitude'] as num?)?.toString() ?? mapsLinkVal,
        );
        final lngCtrl = TextEditingController(
          text: (data['longitude'] as num?)?.toString() ?? '',
        );

        String? selectedGroup = data['group'];
        String? selectedBirlik = data['birlik'];

        String rawMilkType = data['lastMilkType'] ?? 'Soğuk Süt';
        String selectedMilkType = 'Soğuk Süt';
        final normType = rawMilkType.trim().toLowerCase();
        if (normType.contains('soğuk') || normType.contains('a kalite')) {
          selectedMilkType = 'Soğuk Süt';
        } else if (normType.contains('sıcak') || normType.contains('b kalite')) {
          selectedMilkType = 'Sıcak Süt';
        } else if (normType.contains('c kalite')) {
          selectedMilkType = 'C kalite';
        } else if (normType.contains('d kalite')) {
          selectedMilkType = 'D kalite';
        } else {
          selectedMilkType = 'Soğuk Süt';
        }
        bool isYem = data['customerType'] == 'yem';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Üreticiyi Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Ad Soyad'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: tcNoCtrl,
                        decoration: const InputDecoration(labelText: 'TC / Vergi No (İsteğe Bağlı)'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('musteri_bolgeleri').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final List<String> bolgeler = docs.map((d) => d['ad'] as String).toList();
                          
                          String? currentSelected;
                          if (bolgeCtrl.text.isNotEmpty && bolgeler.contains(bolgeCtrl.text)) {
                            currentSelected = bolgeCtrl.text;
                          } else {
                            currentSelected = null;
                          }
                          
                          if (bolgeler.isEmpty) {
                            return TextField(
                              controller: bolgeCtrl,
                              decoration: const InputDecoration(labelText: 'Bölge / İlçe'),
                            );
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: currentSelected,
                            hint: const Text('Bölge Seçin'),
                            decoration: const InputDecoration(labelText: 'Bölge / İlçe'),
                            items: bolgeler.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  bolgeCtrl.text = val;
                                });
                              }
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Group dropdown
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('musteri_gruplari').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final List<String> groups = docs.map((d) => d['ad'] as String).toList();
                          if (selectedGroup != null && !groups.contains(selectedGroup)) {
                            groups.add(selectedGroup!);
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: selectedGroup,
                            hint: const Text('Üretici Grubu Seçin'),
                            decoration: const InputDecoration(labelText: 'Grup'),
                            items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) => setState(() => selectedGroup = val),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Birlik dropdown
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('birlikler').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final List<String> birlikler = docs.map((d) => d['ad'] as String).toList();
                          if (selectedBirlik != null && !birlikler.contains(selectedBirlik)) {
                            birlikler.add(selectedBirlik!);
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: selectedBirlik,
                            hint: const Text('Birlik Seçin (İsteğe Bağlı)'),
                            decoration: const InputDecoration(labelText: 'Birlik Kaydı'),
                            items: birlikler.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (val) => setState(() => selectedBirlik = val),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      // Location picker
                      LocationPickerField(
                        latController: latCtrl,
                        lngController: lngCtrl,
                        setDialogState: setState,
                      ),
                      const SizedBox(height: 24),

                      // Custom selector
                      _buildMilkTypeSelector(
                        selectedType: selectedMilkType,
                        onChanged: (val) => setState(() => selectedMilkType = val),
                        enabled: !isYem,
                      ),
                      const SizedBox(height: 16),
                      _buildCustomerTypeToggle(
                        isYem,
                        (val) => setState(() => isYem = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final bolge = bolgeCtrl.text.trim();
                    final tcNo = tcNoCtrl.text.trim();
                    final saveMilkType = isYem ? 'Yok' : selectedMilkType;

                    if (name.isEmpty || phone.isEmpty || bolge.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lütfen Ad Soyad, Telefon ve Bölge alanlarını doldurun.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    final Map<String, dynamic> updateData = {
                      'name': name,
                      'phone': phone,
                      'bolge': bolge,
                      'tcNo': tcNo,
                      'group': selectedGroup ?? 'Genel',
                      'birlik': selectedBirlik ?? 'Yok',
                      'lastMilkType': saveMilkType,
                      'customerType': isYem ? 'yem' : 'sut',
                    };
                    final latVal = double.tryParse(latCtrl.text.trim());
                    final lngVal = double.tryParse(lngCtrl.text.trim());
                    if (latVal != null && lngVal != null) {
                      updateData['latitude'] = latVal;
                      updateData['longitude'] = lngVal;
                      updateData['mapsLink'] = FieldValue.delete();
                    } else {
                      updateData['mapsLink'] = latCtrl.text.trim();
                      updateData['latitude'] = FieldValue.delete();
                      updateData['longitude'] = FieldValue.delete();
                    }
                    await doc.reference.update(updateData);

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Üretici bilgileri başarıyla güncellendi!'), backgroundColor: AppColors.success),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showProducerDetailsDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? '';
    final phone = data['phone'] ?? '';
    final group = data['group'] ?? '';
    final bolge = data['bolge'] ?? '';
    final birlik = data['birlik'] ?? 'Yok';
    final tcNo = data['tcNo'] ?? '';
    final avg = (data['avg'] as num?)?.toDouble() ?? 0.0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    String rawMilkType = data['lastMilkType'] ?? 'Soğuk Süt';
    String lastMilkType = 'Soğuk Süt';
    final normType = rawMilkType.trim().toLowerCase();
    if (normType.contains('soğuk') || normType.contains('a kalite')) {
      lastMilkType = 'Soğuk Süt';
    } else if (normType.contains('sıcak') || normType.contains('b kalite')) {
      lastMilkType = 'Sıcak Süt';
    } else if (normType.contains('c kalite')) {
      lastMilkType = 'C kalite';
    } else if (normType.contains('d kalite')) {
      lastMilkType = 'D kalite';
    } else {
      lastMilkType = 'Soğuk Süt';
    }
    String customerType = data['customerType'] ?? 'sut';

    const List<String> milkTypes = ['Soğuk Süt', 'Sıcak Süt', 'C kalite', 'D kalite'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Üretici Bilgileri',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(Icons.person_rounded, 'Ad Soyad', name),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.badge_rounded, 'TC / Vergi No', tcNo.isEmpty ? 'Girilmemiş' : tcNo),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.phone_rounded, 'Telefon', phone),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: _buildDetailRow(Icons.location_on_rounded, 'Bölge / Mahalle', '$bolge - $group'),
                    ),
                    MapLinkIcon(
                      latitude: (data['latitude'] as num?)?.toDouble(),
                      longitude: (data['longitude'] as num?)?.toDouble(),
                      mapsLink: data['mapsLink'] as String?,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.account_balance_rounded, 'Birlik Kaydı', birlik),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.bar_chart_rounded, 'Günlük Ort. Süt', '${avg.toStringAsFixed(0)} LT'),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.water_drop_rounded, 'Toplam Alınan Süt', '${total.toStringAsFixed(0)} LT'),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.category_rounded,
                  'Üretici Türü',
                  customerType == 'yem' ? 'Yem Müşterisi' : 'Süt Üreticisi',
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: lastMilkType,
                  decoration: const InputDecoration(
                    labelText: 'Varsayılan Süt Türü',
                    border: OutlineInputBorder(),
                  ),
                  items: milkTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      setDialogState(() {
                        lastMilkType = val;
                      });
                      await doc.reference.update({'lastMilkType': val});
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: customerType,
                  decoration: const InputDecoration(
                    labelText: 'Varsayılan Üretici Türü',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'sut', child: Text('Süt Üreticisi')),
                    DropdownMenuItem(value: 'yem', child: Text('Yem Müşterisi')),
                  ],
                  onChanged: (val) async {
                    if (val != null) {
                      setDialogState(() {
                        customerType = val;
                      });
                      await doc.reference.update({'customerType': val});
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Kapat',
                style: GoogleFonts.inter(color: AppColors.primary600, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary500),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray800, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMilkTypeSelector({
    required String selectedType,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    final norm = selectedType.trim().toLowerCase();
    bool isSicak = norm.contains('sıcak') || norm.contains('b kalite') || norm.contains('b quality');
    bool isSoguk = norm.contains('soğuk') || norm.contains('a kalite') || norm.contains('a quality');
    bool isC = norm.contains('c kalite');
    bool isD = norm.contains('d kalite');
    bool isToggleActive = isSicak || isSoguk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Varsayılan Süt Sıcaklığı / Kalitesi',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                if (isToggleActive)
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: isSicak ? Alignment.centerLeft : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSicak ? Colors.red[600] : Colors.blue[600],
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (isSicak ? Colors.red : Colors.blue).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isSicak ? Icons.whatshot : Icons.ac_unit,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isSicak ? 'Sıcak Süt' : 'Soğuk Süt',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: enabled ? () => onChanged('Sıcak Süt') : null,
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            'Sıcak Süt',
                            style: GoogleFonts.inter(
                              color: isSicak ? Colors.transparent : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: enabled ? () => onChanged('Soğuk Süt') : null,
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            'Soğuk Süt',
                            style: GoogleFonts.inter(
                              color: isSoguk ? Colors.transparent : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: InkWell(
                  onTap: enabled ? () => onChanged(isC ? 'Soğuk Süt' : 'C kalite') : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isC ? Colors.teal[50] : Colors.transparent,
                      border: Border.all(
                        color: isC ? Colors.teal[600]! : Colors.grey[300]!,
                        width: isC ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isC ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isC ? Colors.teal[600] : Colors.grey[500],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'C Kalite',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isC ? Colors.teal[800] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: InkWell(
                  onTap: enabled ? () => onChanged(isD ? 'Soğuk Süt' : 'D kalite') : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isD ? Colors.orange[50] : Colors.transparent,
                      border: Border.all(
                        color: isD ? Colors.orange[600]! : Colors.grey[300]!,
                        width: isD ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isD ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isD ? Colors.orange[600] : Colors.grey[500],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'D Kalite',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isD ? Colors.orange[800] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerTypeToggle(bool isYem, ValueChanged<bool> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Üretici Türü',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            onChanged(!isYem);
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: isYem ? Alignment.centerRight : Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isYem ? Colors.amber[600] : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isYem ? Colors.amber : Colors.grey).withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                          border: isYem ? null : Border.all(color: Colors.grey[300]!, width: 0.5),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isYem ? Icons.grass_rounded : Icons.water_drop_rounded,
                                color: isYem ? Colors.white : AppColors.primary600,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isYem ? 'Yem Müşterisi' : 'Süt Üreticisi',
                                style: GoogleFonts.inter(
                                  color: isYem ? Colors.white : AppColors.primary800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'Süt Üreticisi',
                          style: GoogleFonts.inter(
                            color: !isYem ? Colors.transparent : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Yem Müşterisi',
                          style: GoogleFonts.inter(
                            color: isYem ? Colors.transparent : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasError) {
          return Scaffold(body: Center(child: Text('Hata: ${snapshot.error}')));
        }

        final docs = snapshot.data?.docs ?? [];
        
        // Filter docs based on search, group, and union filters
        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['name'] as String? ?? '').toLowerCase();
          final phone = (data['phone'] as String? ?? '').toLowerCase();
          final group = data['group'] as String? ?? '';
          final birlik = data['birlik'] ?? 'Yok';

          final matchesSearch = _searchQuery.isEmpty ||
              name.contains(_searchQuery.toLowerCase()) ||
              phone.contains(_searchQuery.toLowerCase());

          final matchesGroup = _groupFilterState == null || group == _groupFilterState;
          final matchesBirlik = _birlikFilterState == null || birlik == _birlikFilterState;

          return matchesSearch && matchesGroup && matchesBirlik;
        }).toList();

        final bool isSelecting = _selectedProducerIds.isNotEmpty;

        return Scaffold(
          backgroundColor: AppColors.gray50,
          appBar: AppBar(
            title: Text(
              isSelecting ? '${_selectedProducerIds.length} Seçildi' : 'Üretici Listesi',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            leading: isSelecting
                ? IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _selectedProducerIds.clear()),
                  )
                : IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.go('/firma/ureticiler'),
                  ),
            actions: isSelecting
                ? [
                    IconButton(
                      icon: const Icon(Icons.shopping_cart_checkout_rounded, color: AppColors.primary600),
                      tooltip: 'Sipariş İzni Ver',
                      onPressed: () => _setSiparisIzniForSelected(filteredDocs, true),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_shopping_cart_rounded, color: Colors.orange),
                      tooltip: 'Sipariş İznini Kaldır',
                      onPressed: () => _setSiparisIzniForSelected(filteredDocs, false),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: AppColors.danger),
                      tooltip: 'Seçilenleri Sil',
                      onPressed: () => _deleteSelectedProducers(filteredDocs),
                    ),
                    IconButton(
                      icon: const Icon(Icons.send_rounded),
                      tooltip: 'Grup/Birlik Ata',
                      onPressed: () => _assignSelectedProducers(filteredDocs),
                    ),
                    const SizedBox(width: 8),
                  ]
                : [
                    if (_birlikFilterState != null)
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf_rounded, color: AppColors.primary600),
                        tooltip: 'Birlik Raporu PDF İndir',
                        onPressed: _downloadBirlikPdfReport,
                      ),
                    const SizedBox(width: 8),
                  ],
          ),
          floatingActionButton: AppFab(
            icon: Icons.person_add_rounded,
            label: 'Üretici Ekle',
            onTap: _showAddProducerDialog,
          ),
          body: Column(
            children: [
              // Search & Bulk Add Row
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Üretici adı veya telefon ara...',
                          prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _showBulkAddProducerDialog,
                      icon: const Icon(Icons.grid_on_rounded, size: 16),
                      label: Text('Toplu Üretici Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B5CF6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Chips
              if (_groupFilterState != null || _birlikFilterState != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Row(
                    children: [
                      if (_groupFilterState != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text('Grup: $_groupFilterState', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                            onDeleted: () => setState(() => _groupFilterState = null),
                            deleteIconColor: AppColors.danger,
                          ),
                        ),
                      if (_birlikFilterState != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InputChip(
                            label: Text('Birlik: $_birlikFilterState', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
                            onDeleted: () => setState(() => _birlikFilterState = null),
                            deleteIconColor: AppColors.danger,
                          ),
                        ),
                    ],
                  ),
                ),

              // Producers list
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Text(
                          'Sistemde kayıtlı üretici bulunmuyor.',
                          style: GoogleFonts.inter(color: AppColors.gray500),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredDocs.length,
                        itemBuilder: (_, i) {
                          final doc = filteredDocs[i];
                          final u = doc.data() as Map<String, dynamic>;
                          final name = u['name'] ?? '';
                          final phone = u['phone'] ?? '';
                          final group = u['group'] ?? 'Genel';
                          final birlik = u['birlik'] ?? 'Yok';
                          final bolge = u['bolge'] ?? '';

                          final isYem = u['customerType'] == 'yem';
                          final isSelected = _selectedProducerIds.contains(doc.id);
                          final hasLocation = u['latitude'] != null && u['longitude'] != null ||
                              (u['mapsLink'] as String? ?? '').trim().isNotEmpty;

                          return GestureDetector(
                            onTap: () {
                              if (isSelecting) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedProducerIds.remove(doc.id);
                                  } else {
                                    _selectedProducerIds.add(doc.id);
                                  }
                                });
                              } else {
                                _showProducerDetailsDialog(doc);
                              }
                            },
                            onLongPress: () {
                              setState(() {
                                if (isSelected) {
                                    _selectedProducerIds.remove(doc.id);
                                  } else {
                                    _selectedProducerIds.add(doc.id);
                                  }
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary50
                                    : (isYem ? Colors.amber[50]!.withValues(alpha: 0.7) : Colors.white),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: AppShadows.sm,
                                border: isSelected
                                    ? Border.all(color: AppColors.primary400, width: 1.5)
                                    : (isYem
                                        ? Border.all(color: Colors.amber[200]!, width: 1)
                                        : null),
                              ),
                              child: Row(children: [
                                if (isSelecting)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: Checkbox(
                                      value: isSelected,
                                      activeColor: AppColors.primary600,
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedProducerIds.add(doc.id);
                                          } else {
                                            _selectedProducerIds.remove(doc.id);
                                          }
                                        });
                                      },
                                    ),
                                  )
                                else
                                  Container(
                                    width: 38, height: 38,
                                    decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                                    child: Center(child: Text(name.isNotEmpty ? name[0] : 'Ü', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
                                  ),
                                const SizedBox(width: 12),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    const Icon(Icons.phone_rounded, size: 11, color: AppColors.gray400),
                                    const SizedBox(width: 4),
                                    Text(phone, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                                  ]),
                                  const SizedBox(height: 5),
                                  Row(children: [
                                    StatusBadge.info(group),
                                    if (birlik != 'Yok') ...[
                                      const SizedBox(width: 6),
                                      StatusBadge.active(birlik),
                                    ],
                                  ]),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      const Icon(Icons.location_on_rounded, size: 11, color: AppColors.gray400),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          (bolge.isNotEmpty || group.isNotEmpty)
                                              ? '$bolge${group.isNotEmpty ? " / $group" : ""}'
                                              : (hasLocation ? 'Konum Kayıtlı' : 'Konum Girilmemiş'),
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      MapLinkIcon(
                                        latitude: (u['latitude'] as num?)?.toDouble(),
                                        longitude: (u['longitude'] as num?)?.toDouble(),
                                        mapsLink: u['mapsLink'] as String?,
                                        fallbackAddress: (bolge.isNotEmpty || group.isNotEmpty) ? '$bolge $group' : name,
                                      ),
                                    ],
                                  ),
                                ])),
                                const SizedBox(width: 8),
                                if (!isSelecting)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Sipariş İzni',
                                            style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.gray500),
                                          ),
                                          SizedBox(
                                            height: 28,
                                            child: Transform.scale(
                                              scale: 0.7,
                                              child: Switch(
                                                value: u['siparisIzni'] ?? true,
                                                activeColor: AppColors.primary600,
                                                onChanged: (val) async {
                                                  await doc.reference.update({'siparisIzni': val});
                                                },
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.badge_rounded, color: Colors.orange, size: 20),
                                        onPressed: () {
                                          context.push('/firma/dijital-kart?name=$name');
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.description_rounded, color: AppColors.primary600, size: 20),
                                        onPressed: () {
                                          context.push('/firma/hesap-ozeti?name=$name');
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: const Icon(Icons.edit_rounded, color: AppColors.gray500, size: 20),
                                        onPressed: () {
                                          _showEditProducerDialog(doc);
                                        },
                                      ),
                                    ],
                                  ),
                              ]),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class BarcodePainter extends CustomPainter {
  final String data;
  BarcodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0;

    double x = 10.0;
    final double step = (size.width - 20) / 40;
    for (int i = 0; i < 40; i++) {
      final double width = (i % 3 == 0 || i % 7 == 0) ? 3.5 : 1.5;
      paint.strokeWidth = width;
      if (i % 4 != 0) {
        canvas.drawLine(Offset(x, 2.0), Offset(x, size.height - 15.0), paint);
      }
      x += step;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: data,
        style: GoogleFonts.spaceMono(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold),
      ),
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, size.height - 12.0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
