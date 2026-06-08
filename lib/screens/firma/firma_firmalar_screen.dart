import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaFirmalarScreen extends StatefulWidget {
  const FirmaFirmalarScreen({super.key});

  @override
  State<FirmaFirmalarScreen> createState() => _FirmaFirmalarScreenState();
}

class _FirmaFirmalarScreenState extends State<FirmaFirmalarScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _selectedCariFirmaName;
  DateTimeRange? _selectedDateRange;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  String _selectedListTab = 'tumu'; // 'tumu' | 'alici' | 'tedarikci'
  String _paymentPeriod = 'ay'; // 'hafta' | 'ay' | 'tumzaman'
  String _paymentFilter = 'tumu'; // 'tumu' | 'tahsilat' | 'odeme'
  // Stream'i sabit tutarak her rebuild'de yeniden abonelik olmayı önle
  Stream<QuerySnapshot>? _cariIslemlerStream;
  String? _lastTenantFirma;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Helper method to resolve details stream for Tab 2 details
  Stream<List<QuerySnapshot>> _combineDetailsStreams(String tenantFirma, String companyName) {
    final s1 = _db.collection('cari_firmalar').where('firma', isEqualTo: tenantFirma).where('ad', isEqualTo: companyName).snapshots();
    final s2 = _db.collection('faturalar').where('firma', isEqualTo: tenantFirma).where('tedarikci', isEqualTo: companyName).snapshots();
    final s3 = _db.collection('sut_satislari').where('firma', isEqualTo: tenantFirma).where('aliciFirma', isEqualTo: companyName).snapshots();
    final s4 = _db.collection('cari_islemler').where('firma', isEqualTo: tenantFirma).where('cariFirmaName', isEqualTo: companyName).snapshots();

    final controller = StreamController<List<QuerySnapshot>>();
    final latestResults = List<QuerySnapshot?>.filled(4, null);
    final subscriptions = <StreamSubscription>[];

    final streams = [s1, s2, s3, s4];
    for (int i = 0; i < streams.length; i++) {
      final sub = streams[i].listen(
        (data) {
          latestResults[i] = data;
          if (latestResults.every((res) => res != null)) {
            if (!controller.isClosed) {
              controller.add(latestResults.cast<QuerySnapshot>());
            }
          }
        },
        onError: (err) {
          if (!controller.isClosed) {
            controller.addError(err);
          }
        },
      );
      subscriptions.add(sub);
    }

    controller.onCancel = () {
      for (var sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  void _showAddEditCompanyDialog({DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;
    final adCtrl = TextEditingController(text: data?['ad'] ?? '');
    final telCtrl = TextEditingController(text: data?['tel'] ?? '');
    final emailCtrl = TextEditingController(text: data?['eposta'] ?? '');
    final adresCtrl = TextEditingController(text: data?['adres'] ?? '');
    const String tip = 'tedarikci';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(doc == null ? 'Yeni Tedarikçi Tanımla' : 'Tedarikçi Kartı Düzenle',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: adCtrl,
                      decoration: const InputDecoration(labelText: 'Firma Unvanı / Adı *'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'Telefon Numarası',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-posta Adresi'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: adresCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Adres'),
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
                    final ad = adCtrl.text.trim();
                    if (ad.isEmpty) return;

                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final tenantFirma = auth.user?.displayName ?? '';

                    final docData = {
                      'ad': ad,
                      'tip': tip,
                      'tel': telCtrl.text.trim(),
                      'eposta': emailCtrl.text.trim(),
                      'adres': adresCtrl.text.trim(),
                      'firma': tenantFirma,
                      'timestamp': FieldValue.serverTimestamp(),
                    };

                    if (doc == null) {
                      await _db.collection('cari_firmalar').add(docData);
                    } else {
                      await doc.reference.update(docData);
                    }

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(doc == null ? 'Tedarikçi başarıyla eklendi!' : 'Tedarikçi güncellendi!'),
                        backgroundColor: AppColors.success,
                      ),
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

  void _deleteCompany(DocumentSnapshot doc) {
    final name = (doc.data() as Map<String, dynamic>)['ad'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tedarikçi Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('"$name" firmasını silmek istediğinize emin misiniz? Bu işlem şirkete bağlı fatura ve ödeme kayıtlarını silmez ancak tedarikçi listesinden kaldırır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tedarikçi silindi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(String companyName, String type) {
    final tutarCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();
    String odemeYontemi = 'Nakit';
    DateTime secilenTarih = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(type == 'odeme' ? 'Ödeme Yap ($companyName)' : 'Tahsilat Girişi ($companyName)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tutarCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tutar (₺) *', suffixText: '₺'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: odemeYontemi,
                      decoration: const InputDecoration(labelText: 'Ödeme/Tahsilat Yöntemi'),
                      items: const [
                        DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
                        DropdownMenuItem(value: 'Banka Transferi', child: Text('Banka Transferi / Havale')),
                        DropdownMenuItem(value: 'Çek', child: Text('Çek')),
                        DropdownMenuItem(value: 'Kredi Kartı', child: Text('Kredi Kartı')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => odemeYontemi = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: secilenTarih,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => secilenTarih = picked);
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Tarih',
                            suffixIcon: const Icon(Icons.calendar_month_rounded),
                            hintText: DateFormat('dd.MM.yyyy').format(secilenTarih),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: aciklamaCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Açıklama (Opsiyonel)'),
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
                    final double? tutar = double.tryParse(tutarCtrl.text.replaceAll(',', '.'));
                    if (tutar == null || tutar <= 0) return;

                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final tenantFirma = auth.user?.displayName ?? '';

                    await _db.collection('cari_islemler').add({
                      'cariFirmaName': companyName,
                      'tutar': tutar,
                      'tip': type,
                      'odemeYontemi': odemeYontemi,
                      'aciklama': aciklamaCtrl.text.trim(),
                      'tarih': DateFormat('dd.MM.yyyy').format(secilenTarih),
                      'firma': tenantFirma,
                      'timestamp': Timestamp.fromDate(secilenTarih),
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(type == 'odeme' ? 'Ödeme başarıyla kaydedildi!' : 'Tahsilat başarıyla kaydedildi!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: type == 'odeme' ? Colors.red[600] : Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(type == 'odeme' ? 'Ödemeyi Kaydet' : 'Tahsilatı Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAllTxTransactionDialog(BuildContext context, String txnType) {
    final formKey = GlobalKey<FormState>();
    final tutarCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();
    String? selectedFirma;
    String selectedYontem = 'Nakit';

    showDialog(
      context: context,
      builder: (ctx) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final tenantFirma = auth.user?.displayName ?? '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                '$txnType Ekle',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: txnType == 'Tahsilat' ? AppColors.successDark : AppColors.dangerDark),
              ),
              content: Form(
                key: formKey,
                child: StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('cari_firmalar').where('firma', isEqualTo: tenantFirma).where('tip', isEqualTo: 'tedarikci').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final companies = snapshot.data!.docs.map((doc) => doc['ad'] as String).toList();
                    if (companies.isEmpty) {
                      return const Center(child: Text('Lütfen önce bir tedarikçi firma ekleyin.'));
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedFirma,
                          hint: const Text('Firma Seçin *'),
                          items: companies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedFirma = val;
                            });
                          },
                          validator: (value) => value == null ? 'Lütfen firma seçin' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: tutarCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Tutar (₺) *'),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Lütfen tutar girin';
                            if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Geçerli bir sayı girin';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedYontem,
                          decoration: const InputDecoration(labelText: 'Ödeme Yöntemi'),
                          items: const [
                            DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
                            DropdownMenuItem(value: 'Banka Transferi', child: Text('Banka Transferi')),
                            DropdownMenuItem(value: 'Çek', child: Text('Çek')),
                            DropdownMenuItem(value: 'Kredi Kartı', child: Text('Kredi Kartı')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedYontem = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: aciklamaCtrl,
                          decoration: const InputDecoration(labelText: 'Açıklama'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: txnType == 'Tahsilat' ? AppColors.success : AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate() && selectedFirma != null) {
                      final double tutar = double.parse(tutarCtrl.text.replaceAll(',', '.'));
                      await _db.collection('cari_islemler').add({
                        'cariFirmaName': selectedFirma,
                        'tutar': tutar,
                        'tip': txnType == 'Tahsilat' ? 'tahsilat' : 'odeme',
                        'odemeYontemi': selectedYontem,
                        'aciklama': aciklamaCtrl.text.trim(),
                        'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                        'firma': tenantFirma,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                      Navigator.pop(ctx);
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

  Future<void> _deleteCariIslem(DocumentSnapshot doc) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('İşlemi Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu ödeme/tahsilat işlemini silmek istediğinize emin misiniz? Cari bakiye yeniden hesaplanacaktır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('İşlem silindi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Future<void> _printPdfStatement(
    String partnerName,
    String partnerTip,
    double finalBalance,
    List<Map<String, dynamic>> sortedTransactions,
    String tenantFirmaName,
  ) async {
    final doc = pw.Document();
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(tenantFirmaName.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('Cari Hesap Ekstresi', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Rapor Tarihi: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Müşteri/Tedarikçi: $partnerName', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('Kart Tipi: ${partnerTip == 'alici' ? 'Alıcı (Süt Sattığımız)' : 'Tedarikçi (Yem vb. Aldığımız)'}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Net Bakiye', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${formatNumber.format(finalBalance.abs())} TL',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: finalBalance > 0 ? PdfColors.green900 : finalBalance < 0 ? PdfColors.red900 : PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        finalBalance > 0 ? 'Bize Borçlu' : finalBalance < 0 ? 'Bizden Alacaklı' : 'Dengede',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: finalBalance > 0 ? PdfColors.green800 : finalBalance < 0 ? PdfColors.red800 : PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            pw.TableHelper.fromTextArray(
              headers: ['Tarih', 'İşlem Türü', 'Açıklama', 'Borç / Giriş (TL)', 'Alacak / Çıkış (TL)', 'Bakiye (TL)'],
              data: sortedTransactions.map((tx) {
                final double borc = tx['borc'] as double;
                final double alacak = tx['alacak'] as double;
                final double running = tx['runningBalance'] as double;
                return [
                  tx['tarih'] ?? '',
                  tx['islemTipi'] ?? '',
                  tx['aciklama'] ?? '',
                  borc > 0 ? formatNumber.format(borc) : '-',
                  alacak > 0 ? formatNumber.format(alacak) : '-',
                  formatNumber.format(running),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${partnerName}_ekstre_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenantFirma = auth.user?.displayName ?? '';
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.gray50,
        appBar: AppBar(
          title: Text(
            'Tedarikçi Firmalar',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary600,
            unselectedLabelColor: AppColors.gray500,
            indicatorColor: AppColors.primary600,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.business_rounded, size: 18), text: 'Tedarikçiler'),
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Cari Hesap'),
              Tab(icon: Icon(Icons.payments_rounded, size: 18), text: 'Ödemeler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: FIRMALAR LIST
            StreamBuilder<QuerySnapshot>(
              stream: _db.collection('cari_firmalar').where('firma', isEqualTo: tenantFirma).where('tip', isEqualTo: 'tedarikci').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                
                final List<DocumentSnapshot> filteredCompanies = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['ad'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery.toLowerCase());
                }).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddEditCompanyDialog(),
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        label: Text('Yeni Tedarikçi Tanımla', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val;
                          });
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          hintText: 'Tedarikçi firma ara...',
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: filteredCompanies.isEmpty
                          ? Center(child: Text('Kayıtlı tedarikçi firma bulunmuyor.', style: GoogleFonts.inter(color: AppColors.gray500)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredCompanies.length,
                              itemBuilder: (context, index) {
                                final doc = filteredCompanies[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final String ad = data['ad'] ?? '';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: AppShadows.sm,
                                    border: Border.all(color: AppColors.gray200),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(ad, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gray900)),
                                            const SizedBox(height: 8),
                                            const StatusBadge(
                                              label: 'Tedarikçi (Yem vb.)',
                                              color: Colors.white,
                                              bgColor: Color(0xFFF59E0B),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Row(
                                        children: [
                                          GestureDetector(
                                            onTap: () => _showAddEditCompanyDialog(doc: doc),
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFEFF6FF),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.edit_outlined,
                                                color: Color(0xFF3B82F6),
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          GestureDetector(
                                            onTap: () => _deleteCompany(doc),
                                            child: Container(
                                              width: 36,
                                              height: 36,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.delete_outline_rounded,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),

            // TAB 2: CARI HESAP (LEDGER)
            StreamBuilder<QuerySnapshot>(
              stream: _db.collection('cari_firmalar').where('firma', isEqualTo: tenantFirma).where('tip', isEqualTo: 'tedarikci').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final companies = snapshot.data?.docs ?? [];
                if (companies.isEmpty) {
                  return Center(child: Text('Önce bir tedarikçi firma eklemelisiniz.', style: GoogleFonts.inter(color: AppColors.gray500)));
                }

                if (_selectedCariFirmaName != null) {
                  // Detailed ledger of the selected company
                  return StreamBuilder<List<QuerySnapshot>>(
                    stream: _combineDetailsStreams(tenantFirma, _selectedCariFirmaName!),
                    builder: (context, detailsSnap) {
                      if (!detailsSnap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      
                      final companyDocs = detailsSnap.data![0].docs;
                      if (companyDocs.isEmpty) {
                        return Center(child: Text('Cari kart kaydı bulunamadı!', style: GoogleFonts.inter(color: AppColors.gray500)));
                      }

                      final companyData = companyDocs.first.data() as Map<String, dynamic>;
                      final companyTip = companyData['tip'] ?? 'alici';
                      final companyTel = companyData['tel'] ?? '';
                      final companyEmail = companyData['eposta'] ?? '';
                      final companyAddress = companyData['adres'] ?? '';

                      final invoiceDocs = detailsSnap.data![1].docs;
                      final milkSaleDocs = detailsSnap.data![2].docs;
                      final cariIslemDocs = detailsSnap.data![3].docs;

                      // Dynamic ledger calculation
                      final List<Map<String, dynamic>> transactions = [];

                      // 1. Invoices (Alış Faturaları: decreases our balance / Satış Faturaları: increases balance)
                      for (var inv in invoiceDocs) {
                        final data = inv.data() as Map<String, dynamic>;
                        final double total = (data['toplam'] as num?)?.toDouble() ?? 0.0;
                        final type = data['tip'] as String? ?? 'alis';
                        final status = data['durum'] as String? ?? 'aktif';
                        final faturaNo = data['faturaNo'] ?? '';
                        final dateStr = data['tarih'] ?? '';
                        final Timestamp? ts = data['timestamp'] as Timestamp?;

                        if (status == 'iptal') continue;

                        transactions.add({
                          'docId': inv.id,
                          'collection': 'faturalar',
                          'tarih': dateStr,
                          'timestamp': ts ?? Timestamp.now(),
                          'islemTipi': type == 'alis' ? 'Alış Faturası' : 'Satış Faturası',
                          'aciklama': 'Fatura No: $faturaNo',
                          'borc': type == 'satis' ? total : 0.0,
                          'alacak': type == 'alis' ? total : 0.0,
                          'deletable': false,
                          'docSnapshot': inv,
                        });
                      }

                      // 2. Milk Sales (Süt Satışı: increases balance since client owes us)
                      for (var sale in milkSaleDocs) {
                        final data = sale.data() as Map<String, dynamic>;
                        final double total = (data['toplam'] as num?)?.toDouble() ?? 0.0;
                        final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
                        final double fiyat = (data['fiyat'] as num?)?.toDouble() ?? 0.0;
                        final dateStr = data['tarih'] ?? '';
                        final tank = data['kaynakTank'] ?? '';
                        final Timestamp? ts = data['timestamp'] as Timestamp?;

                        transactions.add({
                          'docId': sale.id,
                          'collection': 'sut_satislari',
                          'tarih': dateStr.split(' ').take(3).join(' '),
                          'timestamp': ts ?? Timestamp.now(),
                          'islemTipi': 'Süt Satışı',
                          'aciklama': '$tank tankından ${miktar.toStringAsFixed(0)} LT süt satıldı (₺${fiyat.toStringAsFixed(2)}/LT)',
                          'borc': total,
                          'alacak': 0.0,
                          'deletable': false,
                          'docSnapshot': sale,
                        });
                      }

                      // 3. Payments & Collections
                      for (var tx in cariIslemDocs) {
                        final data = tx.data() as Map<String, dynamic>;
                        final double total = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                        final type = data['tip'] as String? ?? 'odeme';
                        final method = data['odemeYontemi'] ?? 'Nakit';
                        final dateStr = data['tarih'] ?? '';
                        final note = data['aciklama'] ?? '';
                        final Timestamp? ts = data['timestamp'] as Timestamp?;

                        transactions.add({
                          'docId': tx.id,
                          'collection': 'cari_islemler',
                          'tarih': dateStr,
                          'timestamp': ts ?? Timestamp.now(),
                          'islemTipi': type == 'odeme' ? 'Ödeme' : 'Tahsilat',
                          'aciklama': '$method ${note.isNotEmpty ? '- $note' : ''}',
                          'borc': type == 'odeme' ? total : 0.0,
                          'alacak': type == 'tahsilat' ? total : 0.0,
                          'deletable': true,
                          'docSnapshot': tx,
                        });
                      }

                      // Sort chronologically for running balance
                      transactions.sort((a, b) {
                        final Timestamp tA = a['timestamp'] as Timestamp;
                        final Timestamp tB = b['timestamp'] as Timestamp;
                        return tA.compareTo(tB);
                      });

                      double running = 0.0;
                      for (var tx in transactions) {
                        final double b = tx['borc'] as double;
                        final double al = tx['alacak'] as double;
                        running += (b - al);
                        tx['runningBalance'] = running;
                      }

                      final double overallBakiye = running;

                      // Apply date range filter
                      final List<Map<String, dynamic>> filteredTransactions = [];
                      for (var tx in transactions) {
                        bool isInRange = true;
                        if (_selectedDateRange != null) {
                          final txDate = (tx['timestamp'] as Timestamp).toDate();
                          final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
                          final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
                          isInRange = txDate.isAfter(start.subtract(const Duration(seconds: 1))) && txDate.isBefore(end.add(const Duration(seconds: 1)));
                        }
                        if (isInRange) {
                          filteredTransactions.add(tx);
                        }
                      }

                      // Compute statistics dynamically
                      double totalSutSatis = 0.0;
                      double totalUrunAlim = 0.0;
                      double statsOdeme = 0.0;
                      double statsTahsilat = 0.0;

                      for (var tx in filteredTransactions) {
                        final type = tx['islemTipi'] as String;
                        final double borc = tx['borc'] as double;
                        final double alacak = tx['alacak'] as double;

                        if (type == 'Süt Satışı') {
                          totalSutSatis += borc;
                        } else if (type == 'Alış Faturası') {
                          totalUrunAlim += alacak;
                        } else if (type == 'Ödeme') {
                          statsOdeme += borc;
                        } else if (type == 'Tahsilat') {
                          statsTahsilat += alacak;
                        }
                      }

                      final double filteredNetBakiye = filteredTransactions.isNotEmpty ? filteredTransactions.last['runningBalance'] : 0.0;
                      final displayTransactions = filteredTransactions.reversed.toList();

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              InkWell(
                                onTap: () => setState(() => _selectedCariFirmaName = null),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.primary600),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Firma Seçimine Dön',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: AppColors.primary600,
                                  side: const BorderSide(color: AppColors.primary100),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () => _printPdfStatement(
                                  _selectedCariFirmaName!,
                                  companyTip,
                                  filteredNetBakiye,
                                  filteredTransactions,
                                  tenantFirma,
                                ),
                                icon: const Icon(Icons.print_rounded, size: 15),
                                label: Text('Yazdır (PDF)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Company Header Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.gray200),
                              boxShadow: AppShadows.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedCariFirmaName!,
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                    ),
                                    StatusBadge(
                                      label: companyTip == 'alici' ? 'Alıcı' : 'Tedarikçi',
                                      color: Colors.white,
                                      bgColor: (companyTip == 'alici')
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFFF59E0B),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.gray400),
                                    const SizedBox(width: 6),
                                    Text('Tel: ${companyTel.isNotEmpty ? companyTel : '-'}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                                    const SizedBox(width: 24),
                                    const Icon(Icons.email_outlined, size: 14, color: AppColors.gray400),
                                    const SizedBox(width: 6),
                                    Text('E-posta: ${companyEmail.isNotEmpty ? companyEmail : '-'}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.gray400),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Adres: ${companyAddress.isNotEmpty ? companyAddress : '-'}', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          // Date filter
                          PremiumDateRangeFilter(
                            selectedRange: _selectedDateRange,
                            onRangeChanged: (range) {
                              setState(() {
                                _selectedDateRange = range;
                              });
                            },
                          ),
                          const SizedBox(height: 12),

                          // Dynamic statistics grid
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.gray200),
                              boxShadow: AppShadows.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cari İstatistikler',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                ),
                                const SizedBox(height: 12),
                                GridView.count(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  childAspectRatio: 2.2,
                                  children: [
                                    _buildMetricGridItem('Toplam Süt Satışı', '${formatNumber.format(totalSutSatis)} ₺', Icons.water_drop_rounded, Colors.green),
                                    _buildMetricGridItem('Toplam Ürün Alımı', '${formatNumber.format(totalUrunAlim)} ₺', Icons.shopping_bag_rounded, Colors.blue),
                                    _buildMetricGridItem('Yapılan Ödemeler', '${formatNumber.format(statsOdeme)} ₺', Icons.upload_rounded, Colors.red),
                                    _buildMetricGridItem('Alınan Tahsilatlar', '${formatNumber.format(statsTahsilat)} ₺', Icons.download_rounded, Colors.teal),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Net Balance summaries
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text('Toplam Borç/Giriş', style: GoogleFonts.inter(fontSize: 10, color: Colors.green[800], fontWeight: FontWeight.w600)),
                                      Text('${formatNumber.format(totalSutSatis + statsOdeme)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[900])),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text('Toplam Alacak/Çıkış', style: GoogleFonts.inter(fontSize: 10, color: Colors.red[800], fontWeight: FontWeight.w600)),
                                      Text('${formatNumber.format(totalUrunAlim + statsTahsilat)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red[900])),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: overallBakiye >= 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(overallBakiye >= 0 ? 'Genel Bakiye (Alacaklıyız):' : 'Genel Bakiye (Borçluyuz):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: overallBakiye >= 0 ? Colors.green[800] : Colors.red[800])),
                                Text('${formatNumber.format(overallBakiye.abs())} ₺', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: overallBakiye >= 0 ? Colors.green[800] : Colors.red[800])),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('İşlem Geçmişi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          displayTransactions.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Text(
                                      'Filtrelere uygun işlem bulunmuyor.',
                                      style: GoogleFonts.inter(color: AppColors.gray400),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: displayTransactions.length,
                                  itemBuilder: (context, idx) {
                                    final tx = displayTransactions[idx];
                                    final String islemTipi = tx['islemTipi'] as String;
                                    final String date = tx['tarih'] as String;
                                    final String desc = tx['aciklama'] as String;
                                    final double borc = tx['borc'] as double;
                                    final double alacak = tx['alacak'] as double;
                                    final double runningBal = tx['runningBalance'] as double;
                                    final bool deletable = tx['deletable'] as bool;
                                    final docSnapshot = tx['docSnapshot'] as DocumentSnapshot;

                                    final bool isDebit = borc > 0;
                                    final bool isCredit = alacak > 0;

                                    IconData getIcon() {
                                      if (islemTipi == 'Süt Satışı') return Icons.water_drop_rounded;
                                      if (islemTipi == 'Alış Faturası') return Icons.description_rounded;
                                      if (islemTipi == 'Satış Faturası') return Icons.description_outlined;
                                      if (islemTipi == 'Ödeme') return Icons.upload_rounded;
                                      return Icons.download_rounded;
                                    }

                                    Color getIconColor() {
                                      if (islemTipi == 'Süt Satışı' || islemTipi == 'Tahsilat') return Colors.green;
                                      if (islemTipi == 'Alış Faturası') return Colors.blue;
                                      if (islemTipi == 'Satış Faturası') return Colors.purple;
                                      return Colors.red;
                                    }

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.gray200),
                                        boxShadow: AppShadows.sm,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: getIconColor().withValues(alpha: 0.1),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              getIcon(),
                                              color: getIconColor(),
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      islemTipi,
                                                      style: GoogleFonts.inter(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                        color: AppColors.gray800,
                                                      ),
                                                    ),
                                                    Text(
                                                      date,
                                                      style: GoogleFonts.inter(
                                                        fontSize: 10.5,
                                                        color: AppColors.gray400,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                if (desc.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    desc,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: AppColors.gray500,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 4),
                                                Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Text(
                                                      'Bakiye: ${formatNumber.format(runningBal)} ₺',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 11,
                                                        fontWeight: FontWeight.bold,
                                                        color: runningBal >= 0 ? Colors.green[700] : Colors.red[700],
                                                      ),
                                                    ),
                                                    if (deletable)
                                                      GestureDetector(
                                                        onTap: () => _deleteCariIslem(docSnapshot),
                                                        child: Text(
                                                          'Sil',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.danger,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                isDebit ? '+${formatNumber.format(borc)} ₺' : '-${formatNumber.format(alacak)} ₺',
                                                style: GoogleFonts.inter(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDebit ? Colors.green[700] : Colors.red[700],
                                                ),
                                              ),
                                              Text(
                                                isDebit ? 'Giriş' : 'Çıkış',
                                                style: GoogleFonts.inter(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDebit ? Colors.green[600] : Colors.red[600],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ],
                      );
                    },
                  );
                }

                // Firma selection screen
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    const Icon(Icons.business_rounded, size: 72, color: AppColors.primary500),
                    const SizedBox(height: 12),
                    Text('Tedarikçi Seçin', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gray800)),
                    const SizedBox(height: 4),
                    Text('Hesap ekstresi için önce bir tedarikçi seçin', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: companies.length,
                        itemBuilder: (context, index) {
                          final doc = companies[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String name = data['ad'] ?? '';

                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedCariFirmaName = name;
                              _selectedDateRange = null;
                            }),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                boxShadow: AppShadows.sm,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.gray800,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.gray400,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),

            // TAB 3: ODEMELER (ALL TRANSACTIONS LOG)
            StreamBuilder<QuerySnapshot>(
              stream: () {
                // Stream'i bir kez oluştur — rebuild'lerde aynı kalır, veri titremez
                if (_cariIslemlerStream == null || _lastTenantFirma != tenantFirma) {
                  _lastTenantFirma = tenantFirma;
                  _cariIslemlerStream = _db
                      .collection('cari_islemler')
                      .where('firma', isEqualTo: tenantFirma)
                      .snapshots();
                }
                return _cariIslemlerStream!;
              }(),
              builder: (context, snapshot) {
                // Dart tarafında timestamp'e göre sırala (Firestore index gerektirmez)
                final allDocs = List.from(snapshot.data?.docs ?? []);
                allDocs.sort((a, b) {
                  final aTs = (a.data() as Map)['timestamp'];
                  final bTs = (b.data() as Map)['timestamp'];
                  if (aTs == null && bTs == null) return 0;
                  if (aTs == null) return 1;
                  if (bTs == null) return -1;
                  return (bTs as Timestamp).compareTo(aTs as Timestamp);
                });
                final now = DateTime.now();

                // Dönem filtresi
                DateTime? periodStart;
                if (_paymentPeriod == 'hafta') {
                  periodStart = now.subtract(const Duration(days: 7));
                } else if (_paymentPeriod == 'ay') {
                  periodStart = DateTime(now.year, now.month, 1);
                }

                // Filtre uygula
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final tip = data['tip'] as String? ?? 'odeme';
                  if (_paymentFilter != 'tumu' && tip != _paymentFilter) return false;
                  if (periodStart != null) {
                    DateTime? docDate;
                    final tarihStr = data['tarih'] as String?;
                    if (tarihStr != null && tarihStr.isNotEmpty) {
                      try { docDate = DateFormat('dd.MM.yyyy').parse(tarihStr); } catch (_) {}
                    }
                    if (docDate == null && data['timestamp'] != null) {
                      final ts = data['timestamp'];
                      if (ts is Timestamp) docDate = ts.toDate();
                    }
                    if (docDate == null || docDate.isBefore(periodStart)) return false;
                  }
                  return true;
                }).toList();

                // Toplamlar
                double totalTahsilat = 0.0;
                double totalOdeme = 0.0;
                for (var doc in filteredDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                  if ((data['tip'] as String? ?? '') == 'tahsilat') {
                    totalTahsilat += tutar;
                  } else {
                    totalOdeme += tutar;
                  }
                }

                Widget buildFilterChip(String val, String label, {bool isPeriod = true}) {
                  final isSelected = isPeriod ? _paymentPeriod == val : _paymentFilter == val;
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (isPeriod) _paymentPeriod = val;
                      else _paymentFilter = val;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary600 : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? AppColors.primary600 : AppColors.gray200,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.gray600,
                        ),
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // ACTION BUTTONS
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAllTxTransactionDialog(context, 'Tahsilat'),
                              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                              label: Text('Tahsilat Al', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAllTxTransactionDialog(context, 'Ödeme'),
                              icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 18),
                              label: Text('Ödeme Yap', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 48),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // DÖNEM SELÇECTOR
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            buildFilterChip('hafta', 'Bu Hafta'),
                            const SizedBox(width: 8),
                            buildFilterChip('ay', 'Bu Ay'),
                            const SizedBox(width: 8),
                            buildFilterChip('tumzaman', 'Tüm Zamanlar'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // TÜR FİLTRE TABS
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            buildFilterChip('tumu', 'Tümü', isPeriod: false),
                            const SizedBox(width: 8),
                            buildFilterChip('tahsilat', 'Tahsilatlar', isPeriod: false),
                            const SizedBox(width: 8),
                            buildFilterChip('odeme', 'Ödemeler', isPeriod: false),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ÖZEET KARTLARI
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCFCE7),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF86EFAC)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.arrow_downward_rounded, size: 14, color: Color(0xFF16A34A)),
                                      const SizedBox(width: 4),
                                      Text('Tahsilat', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF166534), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('+${formatNumber.format(totalTahsilat)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF16A34A))),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEE2E2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFFFCA5A5)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.arrow_upward_rounded, size: 14, color: Color(0xFFDC2626)),
                                      const SizedBox(width: 4),
                                      Text('Ödeme', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF7F1D1D), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('-${formatNumber.format(totalOdeme)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFFDC2626))),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // İŞLİM LİSTESİ
                    Expanded(
                      child: (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null)
                          ? const Center(child: CircularProgressIndicator())
                          : filteredDocs.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.receipt_long_rounded, size: 52, color: AppColors.gray300),
                                      const SizedBox(height: 12),
                                      Text('Bu döneme ait işlem bulunamadı', style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500)),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: filteredDocs.length,
                                  itemBuilder: (context, index) {
                                    final doc = filteredDocs[index];
                                    final data = doc.data() as Map<String, dynamic>;
                                    final String name = data['cariFirmaName'] ?? '';
                                    final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                                    final String tip = data['tip'] ?? 'odeme';
                                    final String yontem = data['odemeYontemi'] ?? 'Nakit';
                                    final String tarih = data['tarih'] ?? '';
                                    final String aciklama = data['aciklama'] ?? '';
                                    final isTahsilat = tip == 'tahsilat';

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        boxShadow: AppShadows.sm,
                                        border: Border.all(
                                          color: isTahsilat ? const Color(0xFF86EFAC) : const Color(0xFFFCA5A5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Expanded(
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 32,
                                                      height: 32,
                                                      decoration: BoxDecoration(
                                                        color: isTahsilat ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Icon(
                                                        isTahsilat ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                                        size: 16,
                                                        color: isTahsilat ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            name.isNotEmpty ? name : (isTahsilat ? 'Tahsilat' : 'Ödeme'),
                                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.gray800),
                                                          ),
                                                          const SizedBox(height: 3),
                                                          Container(
                                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                            decoration: BoxDecoration(
                                                              color: isTahsilat ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Text(
                                                              isTahsilat ? 'Tahsilat' : 'Ödeme',
                                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isTahsilat ? const Color(0xFF16A34A) : const Color(0xFFDC2626)),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Text(
                                                '${isTahsilat ? "+" : "-"}${formatNumber.format(tutar)} ₺',
                                                style: GoogleFonts.inter(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.bold,
                                                  color: isTahsilat ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Icon(Icons.calendar_month_outlined, size: 13, color: AppColors.gray400),
                                              const SizedBox(width: 4),
                                              Text(tarih, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                                              const SizedBox(width: 14),
                                              const Icon(Icons.credit_card_outlined, size: 13, color: AppColors.gray400),
                                              const SizedBox(width: 4),
                                              Text(yontem, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                                            ],
                                          ),
                                          if (aciklama.isNotEmpty) ...[
                                            const SizedBox(height: 6),
                                            Text(
                                              aciklama,
                                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400, fontStyle: FontStyle.italic),
                                            ),
                                          ],
                                        ],
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricGridItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.gray800, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
