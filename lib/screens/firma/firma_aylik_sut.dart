import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../services/firestore_service.dart';
import '../../models/user_model.dart';

class FirmaAylikSutScreen extends StatefulWidget {
  const FirmaAylikSutScreen({super.key});

  @override
  State<FirmaAylikSutScreen> createState() => _FirmaAylikSutScreenState();
}

class _FirmaAylikSutScreenState extends State<FirmaAylikSutScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DateTime _selectedMonth = DateTime.now();
  List<String> _tanks = [];

  @override
  void initState() {
    super.initState();
    _loadTanks();
  }

  Future<void> _loadTanks() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final isAdmin = auth.user?.role == UserRole.admin;

    final query = isAdmin
        ? FirebaseFirestore.instance.collection('tanklar')
        : FirebaseFirestore.instance
            .collection('tanklar')
            .where('firma', isEqualTo: currentFirmaName);

    final snapshot = await query.get();
    
    if (mounted) {
      setState(() {
        _tanks = snapshot.docs.map((doc) => doc['ad'] as String).toList();
      });
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  int _daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  Future<void> _generateAylikSutPdf() async {
    // Show a loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentFirmaName = auth.user?.displayName ?? '';
      final isAdmin = auth.user?.role == UserRole.admin;
      final daysCount = _daysInMonth(_selectedMonth);

      // 1. Fetch producers
      final ureticiQuery = isAdmin
          ? await _db.collection('ureticiler').get()
          : await _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).get();

      final List<String> sortedProducers = ureticiQuery.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList()
        ..sort();

      if (sortedProducers.isEmpty) {
        if (mounted) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sistemde kayıtlı üretici bulunamadı.'), backgroundColor: AppColors.danger),
        );
        return;
      }

      // 2. Fetch collections
      final colQuery = isAdmin
          ? await _db.collection('toplamalar').get()
          : await _db.collection('toplamalar').where('firma', isEqualTo: currentFirmaName).get();

      final monthDocs = colQuery.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['timestamp'] as Timestamp?;
        if (ts == null) return false;
        final date = ts.toDate();
        return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
      }).toList();

      final Map<String, Map<int, Map<String, double>>> producerData = {};
      final Map<String, String> producerType = {};

      for (var producer in sortedProducers) {
        producerData[producer] = {};
      }

      for (var doc in monthDocs) {
        final data = doc.data() as Map<String, dynamic>;
        final producer = data['u'] as String? ?? '';
        if (producer.isEmpty || !producerData.containsKey(producer)) continue;

        final ts = data['timestamp'] as Timestamp?;
        if (ts == null) continue;
        final date = ts.toDate();
        final day = date.day;

        final mVal = data['m'] ?? 0;
        final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);

        String vakit = data['vakit'] ?? '';
        if (vakit.isEmpty) {
          vakit = date.hour < 14 ? 'S' : 'A';
        } else {
          vakit = vakit.toLowerCase().contains('sabah') ? 'S' : 'A';
        }

        final tip = data['tip'] as String? ?? 'Soğuk süt';
        producerType[producer] = tip;

        if (!producerData[producer]!.containsKey(day)) {
          producerData[producer]![day] = {'S': 0.0, 'A': 0.0};
        }
        producerData[producer]![day]![vakit] = (producerData[producer]![day]![vakit] ?? 0.0) + m;
      }

      final Map<String, double> producerTotals = {};
      for (var producer in sortedProducers) {
        double total = 0;
        producerData[producer]!.forEach((day, vakitMap) {
          total += (vakitMap['S'] ?? 0) + (vakitMap['A'] ?? 0);
        });
        producerTotals[producer] = total;
      }

      if (mounted) Navigator.pop(context); // Close loading dialog

      // 3. Generate PDF and display layout print/download dialog
      await _buildPdfFile(sortedProducers, producerData, producerType, producerTotals, daysCount, currentFirmaName);

    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF oluşturulurken hata oluştu: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  Future<void> _buildPdfFile(
    List<String> producers,
    Map<String, Map<int, Map<String, double>>> producerData,
    Map<String, String> producerType,
    Map<String, double> producerTotals,
    int daysCount,
    String currentFirmaName,
  ) async {
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

    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth);

    // Explicit PDF Colors
    final cBlue800 = PdfColor.fromInt(0xFF0284C7);
    final cBlue900 = PdfColor.fromInt(0xFF0369A1);
    final cBlue50 = PdfColor.fromInt(0xFFEFF6FF);
    final cBlue100 = PdfColor.fromInt(0xFFDBEAFE);
    final cRed800 = PdfColor.fromInt(0xFFDC2626);
    final cRed100 = PdfColor.fromInt(0xFFFEE2E2);
    final cGrey50 = PdfColor.fromInt(0xFFF9FAFB);
    final cGrey100 = PdfColor.fromInt(0xFFF3F4F6);
    final cGrey200 = PdfColor.fromInt(0xFFE5E7EB);
    final cGrey300 = PdfColor.fromInt(0xFFD1D5DB);
    final cGrey600 = PdfColor.fromInt(0xFF4B5563);
    final cGrey700 = PdfColor.fromInt(0xFF374151);

    // Let's create table headers
    final List<String> headers = [
      'No',
      sanitize('Müşteri Adı'),
      'S/A',
      ...List.generate(daysCount, (i) => '${i + 1}'),
      'Top.',
    ];

    final Map<int, pw.TableColumnWidth> colWidths = {
      0: const pw.FixedColumnWidth(15), // No
      1: const pw.FixedColumnWidth(75), // Müşteri Adı
      2: const pw.FixedColumnWidth(12), // S/A
    };
    for (int i = 0; i < daysCount; i++) {
      colWidths[i + 3] = const pw.FixedColumnWidth(16); // Day cols
    }
    colWidths[daysCount + 3] = const pw.FixedColumnWidth(22); // Total col

    // Build Table Rows manually
    final List<pw.TableRow> tableRows = [];

    // Header Row
    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: cBlue800),
        children: headers.asMap().entries.map((entry) {
          final idx = entry.key;
          final text = entry.value;
          final align = (idx == 1) ? pw.Alignment.centerLeft : pw.Alignment.center;
          final padding = (idx == 1) ? const pw.EdgeInsets.only(left: 4) : pw.EdgeInsets.zero;
          return pw.Container(
            height: 18,
            alignment: align,
            padding: padding,
            child: pw.Text(
              text,
              style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: PdfColors.white),
            ),
          );
        }).toList(),
      ),
    );

    // Producer Rows
    for (int idx = 0; idx < producers.length; idx++) {
      final producer = producers[idx];
      final data = producerData[producer]!;
      final type = producerType[producer] ?? 'Soğuk süt';
      final isHot = type.toLowerCase().contains('sıcak');
      final rowBgColor = idx % 2 == 0 ? PdfColors.white : cGrey50;

      // Calculate S and A totals
      double sTotal = 0, aTotal = 0;
      data.forEach((day, vakitMap) {
        sTotal += vakitMap['S'] ?? 0;
        aTotal += vakitMap['A'] ?? 0;
      });

      // 1. Sabah Row
      final List<pw.Widget> sCells = [
        // No
        pw.Container(
          height: 14,
          alignment: pw.Alignment.center,
          child: pw.Text('${idx + 1}', style: pw.TextStyle(font: fontBold, fontSize: 6, color: cGrey700)),
        ),
        // Müşteri Adı
        pw.Container(
          height: 14,
          alignment: pw.Alignment.centerLeft,
          padding: const pw.EdgeInsets.only(left: 4),
          child: pw.Text(sanitize(producer), style: pw.TextStyle(font: fontBold, fontSize: 6, color: cBlue900)),
        ),
        // S
        pw.Container(
          height: 14,
          alignment: pw.Alignment.center,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: pw.BoxDecoration(
              color: isHot ? cRed100 : cBlue100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            child: pw.Text(
              'S',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 5.5,
                color: isHot ? cRed800 : cBlue800,
              ),
            ),
          ),
        ),
        // Days
        ...List.generate(daysCount, (i) {
          final day = i + 1;
          final val = data[day]?['S'] ?? 0.0;
          return pw.Container(
            height: 14,
            alignment: pw.Alignment.center,
            child: pw.Text(
              val > 0 ? val.toStringAsFixed(0) : '-',
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 6,
                color: val > 0 ? PdfColors.grey900 : cGrey300,
              ),
            ),
          );
        }),
        // Total
        pw.Container(
          height: 14,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(color: cBlue50),
          child: pw.Text(
            sTotal > 0 ? sTotal.toStringAsFixed(0) : '-',
            style: pw.TextStyle(font: fontBold, fontSize: 6, color: cBlue800),
          ),
        ),
      ];

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: rowBgColor),
          children: sCells,
        ),
      );

      // 2. Akşam Row
      final List<pw.Widget> aCells = [
        // No (empty)
        pw.Container(height: 14),
        // Müşteri Adı (empty)
        pw.Container(height: 14),
        // A
        pw.Container(
          height: 14,
          alignment: pw.Alignment.center,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: pw.BoxDecoration(
              color: cGrey100,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
            ),
            child: pw.Text(
              'A',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: 5.5,
                color: cGrey700,
              ),
            ),
          ),
        ),
        // Days
        ...List.generate(daysCount, (i) {
          final day = i + 1;
          final val = data[day]?['A'] ?? 0.0;
          return pw.Container(
            height: 14,
            alignment: pw.Alignment.center,
            child: pw.Text(
              val > 0 ? val.toStringAsFixed(0) : '-',
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 6,
                color: val > 0 ? PdfColors.grey900 : cGrey300,
              ),
            ),
          );
        }),
        // Total
        pw.Container(
          height: 14,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(color: cBlue50),
          child: pw.Text(
            aTotal > 0 ? aTotal.toStringAsFixed(0) : '-',
            style: pw.TextStyle(font: fontBold, fontSize: 6, color: cBlue800),
          ),
        ),
      ];

      tableRows.add(
        pw.TableRow(
          decoration: pw.BoxDecoration(color: rowBgColor),
          children: aCells,
        ),
      );
    }

    // 3. Genel Toplam Row
    final List<pw.Widget> totalCells = [
      // No & Name & S/A merged visually
      pw.Container(
        height: 16,
        alignment: pw.Alignment.centerRight,
        padding: const pw.EdgeInsets.only(right: 6),
        child: pw.Text(
          'GENEL TOPLAM',
          style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: PdfColors.white),
        ),
      ),
      pw.Container(height: 16), // name column spacer
      pw.Container(height: 16), // S/A column spacer
      // Days totals
      ...List.generate(daysCount, (i) {
        final day = i + 1;
        double dayTotal = 0;
        for (var producer in producers) {
          dayTotal += (producerData[producer]![day]?['S'] ?? 0);
          dayTotal += (producerData[producer]![day]?['A'] ?? 0);
        }
        return pw.Container(
          height: 16,
          alignment: pw.Alignment.center,
          child: pw.Text(
            dayTotal > 0 ? dayTotal.toStringAsFixed(0) : '-',
            style: pw.TextStyle(font: fontBold, fontSize: 6.5, color: PdfColors.white),
          ),
        );
      }),
      // Grand Total
      pw.Container(
        height: 16,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(color: cBlue900),
        child: pw.Text(
          producerTotals.values.fold(0.0, (sum, v) => sum + v).toStringAsFixed(0),
          style: pw.TextStyle(font: fontBold, fontSize: 7, color: PdfColors.white),
        ),
      ),
    ];

    tableRows.add(
      pw.TableRow(
        decoration: pw.BoxDecoration(color: cBlue800),
        children: totalCells,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  sanitize('$currentFirmaName - $monthStr AYLIK SUT KAYITLARI').toUpperCase(),
                  style: pw.TextStyle(font: fontBold, fontSize: 11, color: cBlue800),
                ),
                pw.Text(
                  sanitize('Rapor Tarihi: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}'),
                  style: pw.TextStyle(font: fontRegular, fontSize: 7, color: cGrey600),
                ),
              ],
            ),
            pw.SizedBox(height: 6),
            pw.Divider(thickness: 1, color: cBlue800),
            pw.SizedBox(height: 8),
            pw.Table(
              columnWidths: colWidths,
              border: pw.TableBorder.all(color: cGrey300, width: 0.3),
              children: tableRows,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'aylik_sut_kayitlari_${monthStr.replaceAll(' ', '_')}.pdf',
    );
  }

  void _onCellTapped({
    required String producerName,
    required int day,
    required String vakit, // 'S' or 'A'
    required double currentMiktar,
    required String? docId,
  }) {
    final miktarCtrl = TextEditingController(
      text: currentMiktar > 0 ? currentMiktar.toStringAsFixed(1) : '',
    );
    String selectedTank = 'Tank seçimi (zorunlu değil)';
    String selectedMilkType = 'Soğuk Süt';
    const List<String> milkTypes = ['Soğuk Süt', 'Sıcak Süt', 'C kalite', 'D kalite'];

    showDialog(
      context: context,
      builder: (ctx) {
        final isEdit = docId != null;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                isEdit ? 'Süt Kaydı Düzenle' : 'Süt Kaydı Ekle',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Üretici: $producerName',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tarih: $day ${DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth)} (${vakit == 'S' ? 'Sabah' : 'Akşam'})',
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray600),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: miktarCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Miktar (Litre)',
                        hintText: 'Örn: 150',
                        suffixText: 'LT',
                      ),
                    ),
                    if (!isEdit) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedTank,
                        decoration: const InputDecoration(labelText: 'Tank'),
                        items: ['Tank seçimi (zorunlu değil)', ..._tanks].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedTank = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedMilkType,
                        decoration: const InputDecoration(labelText: 'Süt Tipi'),
                        items: milkTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedMilkType = val);
                          }
                        },
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (isEdit)
                  TextButton(
                    onPressed: () async {
                      // Confirm deletion
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Kayıt Silinecek'),
                          content: const Text('Bu süt alım kaydını silmek istediğinize emin misiniz?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                            TextButton(
                              onPressed: () => Navigator.pop(c, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Sil'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await FirestoreService().deleteMilkCollection(docId);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Süt alım kaydı başarıyla silindi.'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Sil'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final double? miktar = double.tryParse(miktarCtrl.text.replaceAll(',', '.'));
                    if (miktar == null || miktar <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Lütfen geçerli bir miktar girin.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    if (isEdit) {
                      await FirestoreService().updateMilkCollection(docId, miktar);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Süt kaydı güncellendi.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    } else {
                      final customDate = DateTime(
                        _selectedMonth.year,
                        _selectedMonth.month,
                        day,
                        vakit == 'S' ? 9 : 17,
                        0,
                      );

                      final auth = Provider.of<AuthProvider>(context, listen: false);
                      final currentFirmaName = auth.user?.displayName ?? '';
                      final isAdmin = auth.user?.role == UserRole.admin;

                      String? targetFirma;
                      if (!isAdmin) {
                        targetFirma = currentFirmaName;
                      } else {
                        final prodQuery = await _db.collection('ureticiler').where('name', isEqualTo: producerName).limit(1).get();
                        if (prodQuery.docs.isNotEmpty) {
                          final List<dynamic> prodFirms = prodQuery.docs.first['firmalar'] ?? [];
                          if (prodFirms.isNotEmpty) {
                            targetFirma = prodFirms.first.toString();
                          }
                        }
                      }

                      final String resolvedTank = selectedTank == 'Tank seçimi (zorunlu değil)' ? 'Merkez Tank' : selectedTank;

                      await FirestoreService().recordMilkCollection(
                        producerName: producerName,
                        tankName: resolvedTank,
                        miktar: miktar,
                        sutTipi: selectedMilkType,
                        firma: targetFirma ?? '',
                        vakit: vakit == 'S' ? 'Sabah' : 'Akşam',
                        customDate: customDate,
                        notifyProducer: false,
                      );

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Yeni süt kaydı eklendi.'),
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
                  child: Text(isEdit ? 'Güncelle' : 'Kaydet'),
                ),
              ],
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
    final isAdmin = auth.user?.role == UserRole.admin;
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth);
    final daysCount = _daysInMonth(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text('Aylık Süt Kayıtları', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Color(0xFF0F8B5A)),
            onPressed: _generateAylikSutPdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: AppColors.gray50,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary600),
                  onPressed: () => _changeMonth(-1),
                ),
                const SizedBox(width: 8),
                Text(
                  monthStr[0].toUpperCase() + monthStr.substring(1),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary600),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: isAdmin
                  ? _db.collection('ureticiler').snapshots()
                  : _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).snapshots(),
              builder: (context, ureticiSnapshot) {
                if (ureticiSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final uDocs = ureticiSnapshot.data?.docs ?? [];
                final List<String> sortedProducers = uDocs
                    .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String? ?? '')
                    .where((name) => name.isNotEmpty)
                    .toList()
                  ..sort();

                if (sortedProducers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline_rounded, size: 48, color: AppColors.gray300),
                        const SizedBox(height: 12),
                        Text(
                          'Sistemde kayıtlı üretici bulunamadı.',
                          style: GoogleFonts.inter(color: AppColors.gray500),
                        ),
                      ],
                    ),
                  );
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: isAdmin
                      ? _db.collection('toplamalar').snapshots()
                      : _db.collection('toplamalar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final rawDocs = snapshot.data?.docs ?? [];

                    final monthDocs = rawDocs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final ts = data['timestamp'] as Timestamp?;
                      if (ts == null) return false;
                      final date = ts.toDate();
                      return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
                    }).toList();

                    final Map<String, Map<int, Map<String, double>>> producerData = {};
                    final Map<String, String> producerType = {};
                    final Map<String, Map<int, Map<String, String>>> producerDocIds = {};

                    for (var producer in sortedProducers) {
                      producerData[producer] = {};
                      producerDocIds[producer] = {};
                    }

                    for (var doc in monthDocs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final producer = data['u'] as String? ?? '';
                      if (producer.isEmpty || !producerData.containsKey(producer)) continue;

                      final ts = data['timestamp'] as Timestamp?;
                      if (ts == null) continue;
                      final date = ts.toDate();
                      final day = date.day;

                      final mVal = data['m'] ?? 0;
                      final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);

                      String vakit = data['vakit'] ?? '';
                      if (vakit.isEmpty) {
                        vakit = date.hour < 14 ? 'S' : 'A';
                      } else {
                        vakit = vakit.toLowerCase().contains('sabah') ? 'S' : 'A';
                      }

                      final tip = data['tip'] as String? ?? 'Soğuk süt';
                      producerType[producer] = tip;

                      if (!producerData[producer]!.containsKey(day)) {
                        producerData[producer]![day] = {'S': 0.0, 'A': 0.0};
                      }
                      producerData[producer]![day]![vakit] = (producerData[producer]![day]![vakit] ?? 0.0) + m;

                      if (!producerDocIds[producer]!.containsKey(day)) {
                        producerDocIds[producer]![day] = {};
                      }
                      producerDocIds[producer]![day]![vakit] = doc.id;
                    }

                    final Map<String, double> producerTotals = {};
                    for (var producer in sortedProducers) {
                      double total = 0;
                      producerData[producer]!.forEach((day, vakitMap) {
                        total += (vakitMap['S'] ?? 0) + (vakitMap['A'] ?? 0);
                      });
                      producerTotals[producer] = total;
                    }

                    return _buildMilkTable(
                      sortedProducers,
                      producerData,
                      producerType,
                      producerTotals,
                      producerDocIds,
                      daysCount,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilkTable(
    List<String> producers,
    Map<String, Map<int, Map<String, double>>> producerData,
    Map<String, String> producerType,
    Map<String, double> producerTotals,
    Map<String, Map<int, Map<String, String>>> producerDocIds,
    int daysCount,
  ) {
    // Fixed column width for days
    const double dayColWidth = 42.0;
    const double noColWidth = 32.0;
    const double nameColWidth = 100.0;
    const double vakitColWidth = 28.0;
    const double totalColWidth = 52.0;
    const double rowHeight = 28.0;

    final headerStyle = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    final cellStyle = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.gray700,
    );
    final emptyStyle = GoogleFonts.inter(
      fontSize: 10,
      color: AppColors.gray300,
    );

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7),
              ),
              child: Row(
                children: [
                  // No column
                  Container(
                    width: noColWidth,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                    ),
                    child: Text('No', style: headerStyle),
                  ),
                  // Name column
                  Container(
                    width: nameColWidth,
                    height: 36,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                    ),
                    child: Text('Müşteri Adı', style: headerStyle),
                  ),
                  // S/A column
                  Container(
                    width: vakitColWidth,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                    ),
                    child: Text('S/A', style: headerStyle),
                  ),
                  // Day columns
                  ...List.generate(daysCount, (i) {
                    final day = i + 1;
                    return Container(
                      width: dayColWidth,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                      ),
                      child: Text('$day', style: headerStyle),
                    );
                  }),
                  // Total column
                  Container(
                    width: totalColWidth,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                      color: const Color(0xFF0369A1),
                    ),
                    child: Text('Top.', style: headerStyle),
                  ),
                ],
              ),
            ),

            // Producer rows
            ...producers.asMap().entries.map((entry) {
              final idx = entry.key;
              final producer = entry.value;
              final data = producerData[producer]!;
              final type = producerType[producer] ?? 'Soğuk süt';
              final isHot = type.toLowerCase().contains('sıcak');
              final bgColor = idx % 2 == 0 ? Colors.white : AppColors.gray50;
              final total = producerTotals[producer] ?? 0.0;

              // Calculate S and A totals
              double sTotal = 0, aTotal = 0;
              data.forEach((day, vakitMap) {
                sTotal += vakitMap['S'] ?? 0;
                aTotal += vakitMap['A'] ?? 0;
              });

              return Column(
                children: [
                  // Sabah row
                  Container(
                    color: bgColor,
                    child: Row(
                      children: [
                        // No - merged over 2 rows visually by showing only on S row
                        Container(
                          width: noColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: Colors.transparent, width: 0.5),
                            ),
                          ),
                          child: Text(
                            '${idx + 1}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gray600),
                          ),
                        ),
                        // Name - merged
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            final auth = Provider.of<AuthProvider>(context, listen: false);
                            final isAdmin = auth.user?.role == UserRole.admin;
                            final routePrefix = isAdmin ? 'admin' : 'firma';
                            context.push('/$routePrefix/dijital-kart?name=$producer');
                          },
                          child: Container(
                            width: nameColWidth,
                            height: rowHeight,
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 6),
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: AppColors.gray200, width: 0.5),
                                bottom: BorderSide(color: Colors.transparent, width: 0.5),
                              ),
                            ),
                            child: Text(
                              producer,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary600,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        // S indicator
                        Container(
                          width: vakitColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: AppColors.gray200, width: 0.5),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: isHot ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'S',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isHot ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                        // Day values for Sabah
                        ...List.generate(daysCount, (i) {
                          final day = i + 1;
                          final val = data[day]?['S'] ?? 0.0;
                          final hasValue = val > 0;
                          final docId = producerDocIds[producer]?[day]?['S'];
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _onCellTapped(
                                producerName: producer,
                                day: day,
                                vakit: 'S',
                                currentMiktar: val,
                                docId: docId,
                              );
                            },
                            child: Container(
                              width: dayColWidth,
                              height: rowHeight,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: AppColors.gray100, width: 0.5),
                                  bottom: BorderSide(color: AppColors.gray200, width: 0.5),
                                ),
                              ),
                              child: Text(
                                hasValue ? val.toStringAsFixed(0) : '-',
                                style: hasValue ? cellStyle : emptyStyle,
                              ),
                            ),
                          );
                        }),
                        // S total
                        Container(
                          width: totalColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            border: Border.all(color: AppColors.gray200, width: 0.5),
                          ),
                          child: Text(
                            sTotal > 0 ? sTotal.toStringAsFixed(0) : '-',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: sTotal > 0 ? const Color(0xFF1D4ED8) : AppColors.gray300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Akşam row
                  Container(
                    color: bgColor,
                    child: Row(
                      children: [
                        // No - empty for merged look
                        Container(
                          width: noColWidth,
                          height: rowHeight,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: AppColors.gray300, width: 1),
                            ),
                          ),
                        ),
                        // Name - empty for merged look
                        Container(
                          width: nameColWidth,
                          height: rowHeight,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: AppColors.gray300, width: 1),
                            ),
                          ),
                        ),
                        // A indicator
                        Container(
                          width: vakitColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: AppColors.gray300, width: 1),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'A',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gray500,
                              ),
                            ),
                          ),
                        ),
                        // Day values for Akşam
                        ...List.generate(daysCount, (i) {
                          final day = i + 1;
                          final val = data[day]?['A'] ?? 0.0;
                          final hasValue = val > 0;
                          final docId = producerDocIds[producer]?[day]?['A'];
                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              _onCellTapped(
                                producerName: producer,
                                day: day,
                                vakit: 'A',
                                currentMiktar: val,
                                docId: docId,
                              );
                            },
                            child: Container(
                              width: dayColWidth,
                              height: rowHeight,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: AppColors.gray100, width: 0.5),
                                  bottom: BorderSide(color: AppColors.gray300, width: 1),
                                ),
                              ),
                              child: Text(
                                hasValue ? val.toStringAsFixed(0) : '-',
                                style: hasValue ? cellStyle : emptyStyle,
                              ),
                            ),
                          );
                        }),
                        // A total
                        Container(
                          width: totalColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            border: Border.all(color: AppColors.gray200, width: 0.5),
                          ),
                          child: Text(
                            aTotal > 0 ? aTotal.toStringAsFixed(0) : '-',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: aTotal > 0 ? const Color(0xFF1D4ED8) : AppColors.gray300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),

            // Grand total row
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7),
              ),
              child: Row(
                children: [
                  Container(
                    width: noColWidth + nameColWidth + vakitColWidth,
                    height: 32,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'GENEL TOPLAM',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  ...List.generate(daysCount, (i) {
                    final day = i + 1;
                    double dayTotal = 0;
                    for (var producer in producers) {
                      dayTotal += (producerData[producer]![day]?['S'] ?? 0);
                      dayTotal += (producerData[producer]![day]?['A'] ?? 0);
                    }
                    return Container(
                      width: dayColWidth,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                      ),
                      child: Text(
                        dayTotal > 0 ? dayTotal.toStringAsFixed(0) : '-',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: dayTotal > 0 ? Colors.white : Colors.white54,
                        ),
                      ),
                    );
                  }),
                  Container(
                    width: totalColWidth,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0369A1),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                    ),
                    child: Text(
                      producerTotals.values.fold(0.0, (sum, v) => sum + v).toStringAsFixed(0),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
