import 'dart:convert';
import 'dart:io';
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

  String _sanitizeTurkish(String text) {
    final Map<String, String> translation = {
      'ı': 'i', 'İ': 'I',
      'ğ': 'g', 'Ğ': 'G',
      'ü': 'u', 'Ü': 'U',
      'ş': 's', 'Ş': 'S',
      'ö': 'o', 'Ö': 'O',
      'ç': 'c', 'Ç': 'C',
    };
    String result = text;
    translation.forEach((tr, eng) {
      result = result.replaceAll(tr, eng);
    });
    return result;
  }

  Future<void> _downloadUnionPdf(List<Map<String, dynamic>> tableData, String currentFirmaName) async {
    try {
      final pdf = pw.Document();
      
      pw.Font fontRegular;
      pw.Font fontBold;
      bool useSanitized = false;

      try {
        fontRegular = await PdfGoogleFonts.robotoRegular();
        fontBold = await PdfGoogleFonts.robotoBold();
      } catch (e) {
        debugPrint('PdfGoogleFonts loading failed, falling back to built-in Helvetica: $e');
        fontRegular = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
        useSanitized = true;
      }

      String processText(String val) {
        return useSanitized ? _sanitizeTurkish(val) : val;
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        processText(currentFirmaName.toUpperCase()),
                        style: pw.TextStyle(font: fontBold, fontSize: 18, color: PdfColors.blue800),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        processText('BİRLİK KAYITLARI VE SÜT ALIM RAPORU'),
                        style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        processText('Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}'),
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                      ),
                      pw.Text(
                        processText('Saat: ${DateFormat('HH:mm').format(DateTime.now())}'),
                        style: pw.TextStyle(font: fontRegular, fontSize: 10),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 1.5, color: PdfColors.blue800),
              pw.SizedBox(height: 20),

              // Rapor Özeti
              pw.Text(
                processText('RAPOR ÖZETİ'),
                style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.blue800),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(processText('Toplam Birlik Sayısı: ${tableData.length}'), style: pw.TextStyle(font: fontRegular, fontSize: 10)),
                  pw.Text(
                    processText('Toplam Üye Sayısı: ${tableData.fold<int>(0, (sum, item) => sum + (item['members'] as int))}'),
                    style: pw.TextStyle(font: fontRegular, fontSize: 10),
                  ),
                  pw.Text(
                    processText('Toplam Toplanan Süt: ${tableData.fold<double>(0.0, (sum, item) => sum + (item['milk'] as double)).toStringAsFixed(1)} LT'),
                    style: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.blue800),
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Tablo
              pw.TableHelper.fromTextArray(
                headers: [processText('Birlik Adı'), processText('Üye Sayısı'), processText('Toplam Süt Miktarı (LT)')],
                data: tableData.map((item) => [
                  processText(item['name'] as String),
                  processText('${item['members']} Üye'),
                  processText('${(item['milk'] as double).toStringAsFixed(1)} LT'),
                ]).toList(),
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
                cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
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
        name: 'birlik_sut_raporu_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
      );
    } catch (e, stackTrace) {
      debugPrint('PDF layout error: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF oluşturulurken hata oluştu: $e'), backgroundColor: AppColors.danger),
      );
    }
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
      floatingActionButton: AppFab(
        icon: Icons.add_rounded,
        label: 'Yeni Birlik Ekle',
        onTap: _showAddUnionDialog,
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
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final showSideBySide = constraints.maxWidth > 400;
                                  if (showSideBySide) {
                                    return Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Birlik Listesi ve Detayları',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.gray800),
                                        ),
                                        if (tableData.isNotEmpty)
                                          ElevatedButton.icon(
                                            onPressed: () => _downloadUnionPdf(tableData, currentFirmaName),
                                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                            label: Text(
                                              'PDF Raporu İndir',
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary600,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            ),
                                          ),
                                      ],
                                    );
                                  } else {
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: [
                                        Text(
                                          'Birlik Listesi ve Detayları',
                                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.gray800),
                                        ),
                                        const SizedBox(height: 10),
                                        if (tableData.isNotEmpty)
                                          ElevatedButton.icon(
                                            onPressed: () => _downloadUnionPdf(tableData, currentFirmaName),
                                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                            label: Text(
                                              'PDF Raporu İndir',
                                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary600,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              padding: const EdgeInsets.symmetric(vertical: 8),
                                            ),
                                          ),
                                      ],
                                    );
                                  }
                                }
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
