import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class SutOdemeleriScreen extends StatefulWidget {
  const SutOdemeleriScreen({super.key});

  @override
  State<SutOdemeleriScreen> createState() => _SutOdemeleriScreenState();
}

class _SutOdemeleriScreenState extends State<SutOdemeleriScreen> {
  final _firestoreService = FirestoreService();
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  DateTime _selectedMonth = DateTime.now();
  String _selectedGroup = 'Tümü';
  String _selectedRegion = 'Tümü';
  
  final Set<String> _selectedProducers = {};
  final Map<String, TextEditingController> _paymentControllers = {};
  final Map<String, double> _producerBalances = {};
  String _bulkPaymentMethod = 'Nakit';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _paymentControllers.forEach((_, ctrl) => ctrl.dispose());
    super.dispose();
  }

  DateTime _getPaymentDate() {
    final now = DateTime.now();
    if (_selectedMonth.year == now.year && _selectedMonth.month == now.month) {
      return now;
    } else {
      return DateTime(_selectedMonth.year, _selectedMonth.month, 1, now.hour, now.minute, now.second);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
      // Clean up inputs on month change
      _paymentControllers.forEach((_, ctrl) => ctrl.dispose());
      _paymentControllers.clear();
      _selectedProducers.clear();
    });
  }

  TextEditingController _getController(String producerName, double defaultValue) {
    if (!_paymentControllers.containsKey(producerName)) {
      _paymentControllers[producerName] = TextEditingController(
        text: defaultValue > 0 ? defaultValue.toStringAsFixed(2) : '',
      );
    } else {
      final ctrl = _paymentControllers[producerName]!;
      if (ctrl.text.isEmpty && defaultValue > 0) {
        ctrl.text = defaultValue.toStringAsFixed(2);
      }
    }
    return _paymentControllers[producerName]!;
  }

  bool _isDocBeforeOrInSelectedMonth(DocumentSnapshot doc, DateTime selectedMonth) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;

    final rawDate = data['tahsilEdilecegiTarih'] ?? data['verildigiTarih'] ?? data['tarih'] ?? data['vereseTarih'];
    if (rawDate != null) {
      try {
        DateTime parsed;
        if (rawDate.toString().contains('.')) {
          parsed = DateFormat('dd.MM.yyyy').parse(rawDate.toString());
        } else {
          parsed = DateFormat('dd MMMM yyyy', 'tr_TR').parse(rawDate.toString());
        }
        return parsed.year < selectedMonth.year || (parsed.year == selectedMonth.year && parsed.month <= selectedMonth.month);
      } catch (_) {}
    }

    if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
      final date = (data['timestamp'] as Timestamp).toDate();
      return date.year < selectedMonth.year || (date.year == selectedMonth.year && date.month <= selectedMonth.month);
    }

    return false;
  }

  bool _isDocInSelectedMonth(DocumentSnapshot doc, DateTime selectedMonth) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;

    final rawDate = data['tahsilEdilecegiTarih'] ?? data['verildigiTarih'] ?? data['tarih'] ?? data['vereseTarih'];
    if (rawDate != null) {
      try {
        DateTime parsed;
        if (rawDate.toString().contains('.')) {
          parsed = DateFormat('dd.MM.yyyy').parse(rawDate.toString());
        } else {
          parsed = DateFormat('dd MMMM yyyy', 'tr_TR').parse(rawDate.toString());
        }
        return parsed.month == selectedMonth.month && parsed.year == selectedMonth.year;
      } catch (_) {}
    }

    if (data['timestamp'] != null && data['timestamp'] is Timestamp) {
      final date = (data['timestamp'] as Timestamp).toDate();
      return date.month == selectedMonth.month && date.year == selectedMonth.year;
    }

    return false;
  }

  void _showOdemeDialog(BuildContext context, String producerName, String currentFirma) {
    final formKey = GlobalKey<FormState>();
    final tutarCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController(text: 'Süt Bedeli Ödemesi');
    String odemeYontemi = 'Nakit';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('$producerName - Ödeme Yap', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: tutarCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Ödeme Tutarı (₺) *', hintText: '0.00'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Lütfen tutar girin';
                        if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Geçerli bir sayı girin';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: odemeYontemi,
                      decoration: const InputDecoration(labelText: 'Ödeme Yöntemi'),
                      items: const [
                        DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
                        DropdownMenuItem(value: 'Banka', child: Text('Banka Havalesi')),
                        DropdownMenuItem(value: 'Çek', child: Text('Çek')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            odemeYontemi = val;
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
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final double tutar = double.parse(tutarCtrl.text.replaceAll(',', '.'));
                      await _firestoreService.recordTahsilat(
                        producerName: producerName,
                        tutar: tutar,
                        odemeYontemi: odemeYontemi,
                        aciklama: aciklamaCtrl.text,
                        firma: currentFirma,
                        tip: 'odeme',
                        date: _getPaymentDate(),
                      );
                      if (mounted) {
                        setState(() {
                          _selectedProducers.remove(producerName);
                          final ctrl = _paymentControllers[producerName];
                          if (ctrl != null) {
                            ctrl.clear();
                          }
                        });
                      }
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$producerName için ${tutar.toStringAsFixed(2)} ₺ ödeme kaydedildi!'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  child: const Text('Ödeme Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showYemSatisDialog(BuildContext context, String producerName, String currentFirma) {
    final formKey = GlobalKey<FormState>();
    final miktarCtrl = TextEditingController(text: '1');
    final torbaFiyatCtrl = TextEditingController(text: '350');
    final aciklamaCtrl = TextEditingController(text: '1 Çuval Yem Satışı');

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final double miktar = double.tryParse(miktarCtrl.text) ?? 0.0;
            final double torbaFiyat = double.tryParse(torbaFiyatCtrl.text) ?? 0.0;
            final double toplamTutar = miktar * torbaFiyat;

            return AlertDialog(
              title: Text('$producerName - Yem Satışı', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: miktarCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Çuval Miktarı *'),
                            onChanged: (val) => setDialogState(() {
                              aciklamaCtrl.text = '$val Çuval Yem Satışı';
                            }),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Boş bırakılamaz';
                              if (int.tryParse(value) == null) return 'Sayı girin';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: torbaFiyatCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Çuval Fiyatı (₺) *'),
                            onChanged: (val) => setDialogState(() {}),
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Boş bırakılamaz';
                              if (double.tryParse(value) == null) return 'Sayı girin';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: aciklamaCtrl,
                      decoration: const InputDecoration(labelText: 'Açıklama'),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Toplam Tutar:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.primary700)),
                          Text('${NumberFormat('#,##0.00', 'tr_TR').format(toplamTutar)} ₺', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primary700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      await _firestoreService.addKesinti({
                        'firma': currentFirma,
                        'uretici': producerName,
                        'kesintiTuru': 'Yem Kesintisi',
                        'tutar': toplamTutar,
                        'aciklama': aciklamaCtrl.text,
                        'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                        'durum': 'aktif',
                      });

                      // Send notification to uretici
                      await FirebaseFirestore.instance.collection('bildirimler').add({
                        'aliciName': producerName,
                        'baslik': 'Yem Satışı Gerçekleşti',
                        'icerik': '$currentFirma tarafından hesabınıza ${miktar.toStringAsFixed(0)} çuval yem satışı kaydedilmiştir. Tutar: ${toplamTutar.toStringAsFixed(2)} ₺',
                        'okundu': false,
                        'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                        'timestamp': FieldValue.serverTimestamp(),
                        'tip': 'kesinti',
                      });

                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$producerName üreticisine yem satışı kaydedildi (Kesinti olarak eklendi)!'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  child: const Text('Satışı Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAvansDialog(BuildContext context, String producerName, String currentFirma) {
    final formKey = GlobalKey<FormState>();
    final tutarCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController(text: 'Avans Ödemesi');
    String odemeYontemi = 'Nakit';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('$producerName - Avans Ver', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: tutarCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Avans Tutarı (₺) *', hintText: '0.00'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Lütfen tutar girin';
                        if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Geçerli bir sayı girin';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: odemeYontemi,
                      decoration: const InputDecoration(labelText: 'Ödeme Yöntemi'),
                      items: const [
                        DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
                        DropdownMenuItem(value: 'Banka', child: Text('Banka Havalesi')),
                        DropdownMenuItem(value: 'Çek', child: Text('Çek')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            odemeYontemi = val;
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
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final double tutar = double.parse(tutarCtrl.text.replaceAll(',', '.'));
                      await _firestoreService.addAvans({
                        'firma': currentFirma,
                        'uretici': producerName,
                        'tutar': tutar,
                        'odemeYontemi': odemeYontemi,
                        'aciklama': aciklamaCtrl.text,
                        'verildigiTarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                        'tahsilEdilecegiTarih': DateFormat('dd.MM.yyyy').format(DateTime.now().add(const Duration(days: 30))),
                        'durum': 'aktif',
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('$producerName üreticisine avans verildi!'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  child: const Text('Avans Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHesapDefteriDialog(
    BuildContext context,
    String producerName,
    String bolge,
    String group,
    Map<String, dynamic> ledger,
    List<QueryDocumentSnapshot> collections,
    List<QueryDocumentSnapshot> tahsilatlar,
    List<QueryDocumentSnapshot> avanslar,
    List<QueryDocumentSnapshot> kesintiler,
    List<QueryDocumentSnapshot> cezalar,
    List<QueryDocumentSnapshot> devirler,
    List<QueryDocumentSnapshot> satislar,
    List<Map<String, dynamic>> pricesList,
  ) {
    final format = NumberFormat('#,##0.00', 'tr_TR');
    final double net = ledger['netBalance'];

    final List<Map<String, dynamic>> items = [];

    // Collections
    for (var doc in collections) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = (data['timestamp'] != null && data['timestamp'] is Timestamp) ? DateFormat('dd.MM.yyyy').format((data['timestamp'] as Timestamp).toDate()) : '-';
      final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
      final String rawType = data['tip'] ?? 'So\u011fuk S\u00fct';
      final String priceKey = _firestoreService.mapMilkTypeToPriceKey(rawType);
      final double price = _firestoreService.resolveMilkPrice(
        prices: pricesList,
        producerName: producerName,
        bolge: bolge,
        group: group,
        type: priceKey,
      );
      items.add({
        'tarih': dateStr,
        'tur': 'Süt Teslimi ($rawType)',
        'aciklama': '${m.toStringAsFixed(0)} LT x ${price.toStringAsFixed(2)} ₺',
        'alacak': m * price,
        'borc': 0.0,
        'color': Colors.green,
      });
    }

    // Tahsilatlar & Odemeler
    for (var doc in tahsilatlar) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['tarih'] ?? '-';
      final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
      final type = _firestoreService.getTahsilatType(data);
      if (type == 'tahsilat') {
        items.add({
          'tarih': dateStr,
          'tur': 'Tahsilat (Ödeme Alındı)',
          'aciklama': '${data['odemeYontemi'] ?? 'Nakit'} - ${data['aciklama'] ?? ''}',
          'alacak': tutar,
          'borc': 0.0,
          'color': Colors.green,
        });
      } else {
        items.add({
          'tarih': dateStr,
          'tur': 'Ödeme (Süt Bedeli)',
          'aciklama': '${data['odemeYontemi'] ?? 'Nakit'} - ${data['aciklama'] ?? ''}',
          'alacak': 0.0,
          'borc': tutar,
          'color': Colors.red,
        });
      }
    }

    // Avanslar
    for (var doc in avanslar) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['verildigiTarih'] ?? '-';
      final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
      final durum = data['durum'] ?? 'aktif';
      items.add({
        'tarih': dateStr,
        'tur': 'Avans Verildi',
        'aciklama': '${data['aciklama'] ?? ''} (${durum == 'aktif' ? 'Aktif' : 'Ödendi'})',
        'alacak': 0.0,
        'borc': durum == 'aktif' ? tutar : 0.0,
        'color': durum == 'aktif' ? Colors.redAccent : AppColors.gray400,
      });
    }

    // Kesintiler (Excluded manual kesintiler as they are double-deductions of satislar)

    // Cezalar
    for (var doc in cezalar) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['tarih'] ?? '-';
      final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
      final durum = data['durum'] ?? 'aktif';
      items.add({
        'tarih': dateStr,
        'tur': 'Kalite Cezası',
        'aciklama': '${data['aciklama'] ?? ''} (${durum == 'aktif' ? 'Aktif' : 'İptal'})',
        'alacak': 0.0,
        'borc': durum == 'aktif' ? tutar : 0.0,
        'color': durum == 'aktif' ? Colors.orange : AppColors.gray400,
      });
    }

    // Devir / Düzeltme
    for (var doc in devirler) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['tarih'] ?? '-';
      final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
      final aciklama = data['aciklama'] ?? 'Devir/Bakiye Düzeltme';
      items.add({
        'tarih': dateStr,
        'tur': 'Bakiye Düzeltme',
        'aciklama': aciklama,
        'alacak': tutar >= 0 ? tutar : 0.0,
        'borc': tutar < 0 ? tutar.abs() : 0.0,
        'color': tutar >= 0 ? Colors.green : Colors.red,
      });
    }

    // Ürün Satışları
    for (var doc in satislar) {
      final data = doc.data() as Map<String, dynamic>;
      final dateStr = data['tarih'] ?? '-';
      final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
      final urun = data['urun'] ?? 'Ürün Satışı';
      final miktar = data['miktar'] ?? 1;
      final fiyat = (data['fiyat'] as num?)?.toDouble() ?? 0.0;
      items.add({
        'tarih': dateStr,
        'tur': 'Ürün Satışı ($urun)',
        'aciklama': '$miktar adet x ${format.format(fiyat)} ₺',
        'alacak': 0.0,
        'borc': tutar,
        'color': Colors.red,
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Hesap Ekstresi / Defteri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 450,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(producerName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              Text('$bolge - $group', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSummaryBox('Süt Alacağı', ledger['toplamAlacak'], Colors.green),
                  _buildSummaryBox('Ödemeler', ledger['totalTahsilat'], Colors.purple),
                  _buildSummaryBox('Kesinti/Avans', ledger['totalKesinti'] + ledger['totalAvans'] + ledger['totalCeza'], Colors.red),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: net >= 0 ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(net >= 0 ? 'Net Üretici Alacağı:' : 'Net Üretici Borcu (Eksi Bakiye):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: net >= 0 ? Colors.green[800] : Colors.red[800])),
                    Text('${format.format(net.abs())} ₺', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: net >= 0 ? Colors.green[800] : Colors.red[800])),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('İşlem Geçmişi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Expanded(
                child: items.isEmpty
                    ? Center(child: Text('İşlem bulunamadı.', style: GoogleFonts.inter(color: AppColors.gray400)))
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(item['tur'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.gray800)),
                                        const Spacer(),
                                        Text(item['tarih'], style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                                      ],
                                    ),
                                    Text(item['aciklama'], style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  if (item['alacak'] > 0)
                                    Text('+ ${format.format(item['alacak'])} ₺', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.green))
                                  else if (item['borc'] > 0)
                                    Text('- ${format.format(item['borc'])} ₺', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.red))
                                  else
                                    Text('0.00 ₺', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryBox(String label, double val, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.1))),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray500)),
            Text('${NumberFormat('#,##0', 'tr_TR').format(val)} ₺', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }

  Future<void> _executeBulkPayments(String currentFirmaName) async {
    if (_selectedProducers.isEmpty) return;

    int paidCount = 0;
    double totalPaidAmount = 0.0;

    for (var producerName in _selectedProducers) {
      final ctrl = _paymentControllers[producerName];
      double? amount;
      if (ctrl != null && ctrl.text.trim().isNotEmpty) {
        final amountText = ctrl.text.trim().replaceAll(',', '.');
        amount = double.tryParse(amountText);
      }
      
      // Fallback to calculated monthKalan if empty or invalid
      if (amount == null || amount <= 0) {
        amount = _producerBalances[producerName] ?? 0.0;
      }

      if (amount > 0) {
        await _firestoreService.recordTahsilat(
          producerName: producerName,
          tutar: amount,
          odemeYontemi: _bulkPaymentMethod,
          aciklama: '${DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth)} Toplu Süt Ödemesi',
          firma: currentFirmaName,
          tip: 'odeme',
          date: _getPaymentDate(),
        );
        paidCount++;
        totalPaidAmount += amount;
      }
    }

    if (paidCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$paidCount üreticiye toplam ${NumberFormat('#,##0.00', 'tr_TR').format(totalPaidAmount)} ₺ ödeme kaydedildi!'),
          backgroundColor: AppColors.success,
        ),
      );
      setState(() {
        _selectedProducers.clear();
        _paymentControllers.forEach((_, ctrl) => ctrl.clear());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text('Süt Hesap Ödemeleri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getProducersStream(firma: currentFirmaName),
        builder: (context, prodSnapshot) {
          if (prodSnapshot.hasError) {
            return Center(child: Text('Üreticiler yüklenirken hata oluştu: ${prodSnapshot.error}', style: GoogleFonts.inter()));
          }
          if (prodSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProducers = prodSnapshot.hasData
              ? prodSnapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList()
              : [];

          if (allProducers.isEmpty) {
            return Center(child: Text('Kayıtlı üretici bulunamadı.', style: GoogleFonts.inter(color: AppColors.gray500)));
          }

          // Extract unique groups and regions for filter chips
          final groups = ['Tümü', ...allProducers.map((p) => p['group']?.toString() ?? '').where((g) => g.isNotEmpty).toSet().toList()];
          final regions = ['Tümü', ...allProducers.map((p) => p['bolge']?.toString() ?? '').where((r) => r.isNotEmpty).toSet().toList()];

          return StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getMilkPricesStream(firma: currentFirmaName),
            builder: (context, pricesSnap) {
              if (pricesSnap.hasError) {
                return Center(child: Text('Fiyatlar yüklenirken hata oluştu: ${pricesSnap.error}', style: GoogleFonts.inter()));
              }
              if (pricesSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final priceDocs = pricesSnap.data?.docs ?? [];
              final pricesList = priceDocs.map((d) => d.data() as Map<String, dynamic>).toList();

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('toplamalar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                builder: (context, collectionsSnap) {
                  if (collectionsSnap.hasError) {
                    return Center(child: Text('Toplamalar yüklenirken hata oluştu: ${collectionsSnap.error}', style: GoogleFonts.inter()));
                  }
                  if (collectionsSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final allCollections = collectionsSnap.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('tahsilatlar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                    builder: (context, tahsilatlarSnap) {
                      if (tahsilatlarSnap.hasError) {
                        return Center(child: Text('Tahsilatlar yüklenirken hata oluştu: ${tahsilatlarSnap.error}', style: GoogleFonts.inter()));
                      }
                      if (tahsilatlarSnap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final allTahsilatlar = tahsilatlarSnap.data?.docs ?? [];

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('avanslar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, avanslarSnap) {
                          if (avanslarSnap.hasError) {
                            return Center(child: Text('Avanslar yüklenirken hata oluştu: ${avanslarSnap.error}', style: GoogleFonts.inter()));
                          }
                          if (avanslarSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final allAvanslar = avanslarSnap.data?.docs ?? [];

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('kesintiler').where('firma', isEqualTo: currentFirmaName).snapshots(),
                            builder: (context, kesintilerSnap) {
                              if (kesintilerSnap.hasError) {
                                return Center(child: Text('Kesintiler yüklenirken hata oluştu: ${kesintilerSnap.error}', style: GoogleFonts.inter()));
                              }
                              if (kesintilerSnap.connectionState == ConnectionState.waiting) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              final allKesintiler = kesintilerSnap.data?.docs ?? [];

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('cezalar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                                builder: (context, cezalarSnap) {
                                  if (cezalarSnap.hasError) {
                                    return Center(child: Text('Cezalar yüklenirken hata oluştu: ${cezalarSnap.error}', style: GoogleFonts.inter()));
                                  }
                                  if (cezalarSnap.connectionState == ConnectionState.waiting) {
                                    return const Center(child: CircularProgressIndicator());
                                  }
                                  final allCezalar = cezalarSnap.data?.docs ?? [];

                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance.collection('devirler').where('firma', isEqualTo: currentFirmaName).snapshots(),
                                    builder: (context, devirlerSnap) {
                                      if (devirlerSnap.hasError) {
                                        return Center(child: Text('Devirler yüklenirken hata oluştu: ${devirlerSnap.error}', style: GoogleFonts.inter()));
                                      }
                                      if (devirlerSnap.connectionState == ConnectionState.waiting) {
                                        return const Center(child: CircularProgressIndicator());
                                      }
                                      final allDevirler = devirlerSnap.data?.docs ?? [];

                                      return StreamBuilder<QuerySnapshot>(
                                        stream: FirebaseFirestore.instance.collection('satislar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                                        builder: (context, satislarSnap) {
                                          if (satislarSnap.hasError) {
                                            return Center(child: Text('Satışlar yüklenirken hata oluştu: ${satislarSnap.error}', style: GoogleFonts.inter()));
                                          }
                                          if (satislarSnap.connectionState == ConnectionState.waiting) {
                                            return const Center(child: CircularProgressIndicator());
                                          }
                                          final allSatislar = satislarSnap.data?.docs ?? [];

                                          return StreamBuilder<DocumentSnapshot>(
                                            stream: FirebaseFirestore.instance.collection('finans_ayarlari').doc(currentFirmaName).snapshots(),
                                            builder: (context, settingsSnap) {
                                              if (settingsSnap.hasError) {
                                                return Center(child: Text('Finans ayarları yüklenirken hata oluştu: ${settingsSnap.error}', style: GoogleFonts.inter()));
                                              }
                                              if (settingsSnap.connectionState == ConnectionState.waiting) {
                                                return const Center(child: CircularProgressIndicator());
                                              }
                                              final sData = settingsSnap.data?.data() as Map<String, dynamic>? ?? {};
                                              final double bagkurOran = (sData['bagkurOran'] as num?)?.toDouble() ?? 2.10;
                                              final double stopajOran = (sData['stopajOran'] as num?)?.toDouble() ?? 1.00;
                                              final double borsaOran = (sData['borsaOran'] as num?)?.toDouble() ?? 0.20;
                                              final dynamicColsList = sData['kesintiTurleri'] as List?;
                                              final List<String> dynamicColumns = [];
                                              if (dynamicColsList != null) {
                                                dynamicColumns.addAll(dynamicColsList.map((e) => e.toString()));
                                              }
                                              if (dynamicColumns.isEmpty) {
                                                dynamicColumns.addAll(['Bağkur', 'Stopaj', 'Borsa']);
                                              }

                                              // Filter producers by: search query, group, region
                                              final filteredProducers = allProducers.where((p) {
                                                final name = (p['name']?.toString() ?? '').toLowerCase();
                                                final phone = (p['phone']?.toString() ?? '').toLowerCase();
                                                final group = p['group']?.toString() ?? '';
                                                final bolge = p['bolge']?.toString() ?? '';

                                                final matchesSearch = name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery.toLowerCase());
                                                final matchesGroup = _selectedGroup == 'Tümü' || group == _selectedGroup;
                                                final matchesRegion = _selectedRegion == 'Tümü' || bolge == _selectedRegion;

                                                return matchesSearch && matchesGroup && matchesRegion;
                                              }).toList();

                                              // Calculate dashboard metrics for the selected month (real-time compile)
                                              double totalOutstandingCompanyDebt = 0.0; // To be Paid (Ödenecek)
                                              double totalPaidThisMonth = 0.0;          // Paid (Ödenen)
                                              double totalKalanThisMonth = 0.0;         // Remaining (Kalan)

                                              final List<Map<String, dynamic>> compiledData = [];

                                              for (var p in filteredProducers) {
                                                final name = p['name']?.toString() ?? '';
                                                if (name.isEmpty) continue;
                                                final bolge = p['bolge']?.toString() ?? '';
                                                final group = p['group']?.toString() ?? '';
                                                final kesintiAyarlari = p['kesintiAyarlari'] as Map<String, dynamic>?;

                                                final pCollections = allCollections.where((doc) {
                                                  final data = doc.data() as Map<String, dynamic>?;
                                                  return data != null && data['u'] == name && _isDocBeforeOrInSelectedMonth(doc, _selectedMonth);
                                                }).toList();
                                                final pTahsilatlar = allTahsilatlar.where((doc) {
                                                  final data = doc.data() as Map<String, dynamic>?;
                                                  return data != null && data['uretici'] == name && _isDocBeforeOrInSelectedMonth(doc, _selectedMonth);
                                                }).toList();
                                                final pAvanslar = allAvanslar.where((doc) {
                                                  final data = doc.data() as Map<String, dynamic>?;
                                                  return data != null && data['uretici'] == name && _isDocBeforeOrInSelectedMonth(doc, _selectedMonth);
                                                }).toList();
                                                final pKesintiler = allKesintiler.where((doc) {
                                                  final data = doc.data() as Map<String, dynamic>?;
                                                  return data != null && data['uretici'] == name && _isDocBeforeOrInSelectedMonth(doc, _selectedMonth);
                                                }).toList();
                                                final pCezalar = allCezalar.where((doc) {
                                                  final data = doc.data() as Map<String, dynamic>?;
                                                  return data != null && data['uretici'] == name && _isDocBeforeOrInSelectedMonth(doc, _selectedMonth);
                                                }).toList();
                                                final pDevirler = allDevirler.where((doc) {
                                                  final data = doc.data() as Map<String, dynamic>?;
                                                  return data != null && data['uretici'] == name && _isDocBeforeOrInSelectedMonth(doc, _selectedMonth);
                                                }).toList();
                                                final pSatislar = allSatislar.where((doc) {
                                                  final data = doc.data() as Map<String, dynamic>?;
                                                  return data != null && data['uretici'] == name && _isDocBeforeOrInSelectedMonth(doc, _selectedMonth);
                                                }).toList();

                                                // 1. Calculate general cumulative ledger
                                                final fullLedger = _firestoreService.calculateLedger(
                                                  collections: pCollections,
                                                  prices: priceDocs,
                                                  tahsilatlar: pTahsilatlar,
                                                  avanslar: pAvanslar,
                                                  kesintiler: pKesintiler,
                                                  cezalar: pCezalar,
                                                  devirler: pDevirler,
                                                  satislar: pSatislar,
                                                  producerName: name,
                                                  bolge: bolge,
                                                  group: group,
                                                  kesintiAyarlari: kesintiAyarlari,
                                                  dynamicColumns: dynamicColumns,
                                                  bagkurOran: bagkurOran,
                                                  stopajOran: stopajOran,
                                                  borsaOran: borsaOran,
                                                );

                                                // 2. Calculate selected month's ledger
                                                final monthCollections = pCollections.where((doc) => _isDocInSelectedMonth(doc, _selectedMonth)).toList();
                                                final monthTahsilatlar = pTahsilatlar.where((doc) => _isDocInSelectedMonth(doc, _selectedMonth)).toList();
                                                final monthAvanslar = pAvanslar.where((doc) => _isDocInSelectedMonth(doc, _selectedMonth)).toList();
                                                final monthKesintiler = pKesintiler.where((doc) => _isDocInSelectedMonth(doc, _selectedMonth)).toList();
                                                final monthCezalar = pCezalar.where((doc) => _isDocInSelectedMonth(doc, _selectedMonth)).toList();
                                                final monthSatislar = pSatislar.where((doc) => _isDocInSelectedMonth(doc, _selectedMonth)).toList();

                                                final monthLedger = _firestoreService.calculateLedger(
                                                  collections: monthCollections,
                                                  prices: priceDocs,
                                                  tahsilatlar: monthTahsilatlar,
                                                  avanslar: monthAvanslar,
                                                  kesintiler: monthKesintiler,
                                                  cezalar: monthCezalar,
                                                  satislar: monthSatislar,
                                                  producerName: name,
                                                  bolge: bolge,
                                                  group: group,
                                                  kesintiAyarlari: kesintiAyarlari,
                                                  dynamicColumns: dynamicColumns,
                                                  bagkurOran: bagkurOran,
                                                  stopajOran: stopajOran,
                                                  borsaOran: borsaOran,
                                                );

                                                final double net = fullLedger['netBalance'];
                                                
                                                // Ödenecek = month ledger alacak
                                                final double monthAlacak = monthLedger['toplamAlacak'];
                                                // Ödenen = month payments
                                                final double monthOdenen = monthLedger['totalTahsilat'];
                                                
                                                // Real net payable this month = net clamped to positive
                                                final double netPayable = net.clamp(0.0, double.infinity);

                                                totalOutstandingCompanyDebt += (netPayable + monthOdenen);
                                                totalPaidThisMonth += monthOdenen;
                                                totalKalanThisMonth += netPayable;
                                                _producerBalances[name] = netPayable;

                                                if (netPayable > 0.01 || monthAlacak > 0.01) {
                                                  compiledData.add({
                                                    'producer': p,
                                                    'fullLedger': fullLedger,
                                                    'monthLedger': monthLedger,
                                                    'monthAlacak': monthAlacak,
                                                    'monthOdenen': monthOdenen,
                                                    'netPayable': netPayable,
                                                    'collections': pCollections,
                                                    'tahsilatlar': pTahsilatlar,
                                                    'avanslar': pAvanslar,
                                                    'kesintiler': pKesintiler,
                                                    'cezalar': pCezalar,
                                                    'devirler': pDevirler,
                                                    'satislar': pSatislar,
                                                  });
                                                }
                                              }

                                  return Column(
                                    children: [
                                      // Search & Filter header
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        color: Colors.white,
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Month Selector
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.chevron_left_rounded),
                                                  onPressed: () => _changeMonth(-1),
                                                ),
                                                Row(
                                                  children: [
                                                    const Icon(Icons.calendar_month_rounded, color: AppColors.primary600, size: 18),
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      monthStr,
                                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                                    ),
                                                  ],
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.chevron_right_rounded),
                                                  onPressed: () => _changeMonth(1),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 12),

                                            // Search Textfield
                                            Container(
                                              decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(10)),
                                              child: TextField(
                                                controller: _searchCtrl,
                                                onChanged: (val) => setState(() => _searchQuery = val),
                                                decoration: InputDecoration(
                                                  hintText: 'Üretici ara...',
                                                  hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                                                  prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400, size: 18),
                                                  border: InputBorder.none,
                                                  enabledBorder: InputBorder.none,
                                                  focusedBorder: InputBorder.none,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),

                                            // Group Filters Row
                                            Text('Gruplar:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                                            const SizedBox(height: 4),
                                            SizedBox(
                                              height: 32,
                                              child: ListView.builder(
                                                scrollDirection: Axis.horizontal,
                                                itemCount: groups.length,
                                                itemBuilder: (context, idx) {
                                                  final isSel = _selectedGroup == groups[idx];
                                                  return Padding(
                                                    padding: const EdgeInsets.only(right: 6.0),
                                                    child: ChoiceChip(
                                                      label: Text(groups[idx]),
                                                      selected: isSel,
                                                      selectedColor: AppColors.primary600,
                                                      backgroundColor: AppColors.gray50,
                                                      labelStyle: GoogleFonts.inter(fontSize: 11, color: isSel ? Colors.white : AppColors.gray700, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                                                      onSelected: (_) => setState(() {
                                                        _selectedGroup = groups[idx];
                                                        _selectedProducers.clear();
                                                      }),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                            const SizedBox(height: 8),

                                            // Region Filters Row
                                            Text('Bölgeler:', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                                            const SizedBox(height: 4),
                                            SizedBox(
                                              height: 32,
                                              child: ListView.builder(
                                                scrollDirection: Axis.horizontal,
                                                itemCount: regions.length,
                                                itemBuilder: (context, idx) {
                                                  final isSel = _selectedRegion == regions[idx];
                                                  return Padding(
                                                    padding: const EdgeInsets.only(right: 6.0),
                                                    child: ChoiceChip(
                                                      label: Text(regions[idx]),
                                                      selected: isSel,
                                                      selectedColor: AppColors.primary600,
                                                      backgroundColor: AppColors.gray50,
                                                      labelStyle: GoogleFonts.inter(fontSize: 11, color: isSel ? Colors.white : AppColors.gray700, fontWeight: isSel ? FontWeight.bold : FontWeight.normal),
                                                      onSelected: (_) => setState(() {
                                                        _selectedRegion = regions[idx];
                                                        _selectedProducers.clear();
                                                      }),
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Metrics Row
                                      Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                                child: Column(
                                                  children: [
                                                    Text('Ödenecek Süt', style: GoogleFonts.inter(fontSize: 9, color: Colors.blue[900], fontWeight: FontWeight.w600)),
                                                    const SizedBox(height: 2),
                                                    Text('${formatNumber.format(totalOutstandingCompanyDebt)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue[900])),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                                child: Column(
                                                  children: [
                                                    Text('Ödenen Süt', style: GoogleFonts.inter(fontSize: 9, color: Colors.green[900], fontWeight: FontWeight.w600)),
                                                    const SizedBox(height: 2),
                                                    Text('${formatNumber.format(totalPaidThisMonth)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[900])),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(10)),
                                                child: Column(
                                                  children: [
                                                    Text('Kalan Ödeme', style: GoogleFonts.inter(fontSize: 9, color: Colors.orange[900], fontWeight: FontWeight.w600)),
                                                    const SizedBox(height: 2),
                                                    Text('${formatNumber.format(totalKalanThisMonth)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange[900])),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Bulk Action Controls
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: filteredProducers.isNotEmpty && _selectedProducers.length == filteredProducers.length,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedProducers.addAll(filteredProducers.map((p) => p['name'] as String));
                                                  } else {
                                                    _selectedProducers.clear();
                                                  }
                                                });
                                              },
                                            ),
                                            Text('Tümünü Seç', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray700)),
                                            const Spacer(),
                                            if (_selectedProducers.isNotEmpty) ...[
                                              DropdownButton<String>(
                                                value: _bulkPaymentMethod,
                                                underline: Container(),
                                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray800, fontWeight: FontWeight.bold),
                                                items: const [
                                                  DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
                                                  DropdownMenuItem(value: 'Banka', child: Text('Banka')),
                                                  DropdownMenuItem(value: 'Çek', child: Text('Çek')),
                                                ],
                                                onChanged: (val) {
                                                  if (val != null) {
                                                    setState(() {
                                                      _bulkPaymentMethod = val;
                                                    });
                                                  }
                                                },
                                              ),
                                              const SizedBox(width: 8),
                                              ElevatedButton(
                                                onPressed: () => _executeBulkPayments(currentFirmaName),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: AppColors.success,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                ),
                                                child: Text('Seçilenleri Öde (${_selectedProducers.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),

                                      // Producer Cards List
                                      Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                                          itemCount: compiledData.length,
                                          itemBuilder: (context, idx) {
                                            final data = compiledData[idx];
                                            final prod = data['producer'] as Map<String, dynamic>;
                                            final fullLedger = data['fullLedger'] as Map<String, dynamic>;
                                            final monthLedger = data['monthLedger'] as Map<String, dynamic>;
                                            
                                            final name = prod['name']?.toString() ?? '';
                                            final phone = prod['phone']?.toString() ?? '';
                                            final bolge = prod['bolge']?.toString() ?? '';
                                            final group = prod['group']?.toString() ?? '';
                                            
                                            final double net = (fullLedger['netBalance'] as num?)?.toDouble() ?? 0.0;
                                            final double monthAlacak = (data['monthAlacak'] as num?)?.toDouble() ?? 0.0;
                                            final double monthOdenen = (data['monthOdenen'] as num?)?.toDouble() ?? 0.0;
                                            final double netPayable = (data['netPayable'] as num?)?.toDouble() ?? 0.0;

                                            final isChecked = _selectedProducers.contains(name);
                                            final ctrl = _getController(name, netPayable);

                                            return Container(
                                              margin: const EdgeInsets.only(bottom: 12),
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                boxShadow: AppShadows.sm,
                                                border: Border.all(color: isChecked ? AppColors.primary300 : AppColors.gray200, width: isChecked ? 1.5 : 1.0),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Title Row
                                                  Row(
                                                    children: [
                                                      Checkbox(
                                                        value: isChecked,
                                                        onChanged: (val) {
                                                          setState(() {
                                                            if (val == true) {
                                                              _selectedProducers.add(name);
                                                            } else {
                                                              _selectedProducers.remove(name);
                                                            }
                                                          });
                                                        },
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(name, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gray800)),
                                                            Text('$bolge - $group • $phone', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                                                          ],
                                                        ),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary600),
                                                        onPressed: () => _showHesapDefteriDialog(
                                                          context,
                                                          name,
                                                          bolge,
                                                          group,
                                                          fullLedger,
                                                          data['collections'] as List<QueryDocumentSnapshot>,
                                                          data['tahsilatlar'] as List<QueryDocumentSnapshot>,
                                                          data['avanslar'] as List<QueryDocumentSnapshot>,
                                                          data['kesintiler'] as List<QueryDocumentSnapshot>,
                                                          data['cezalar'] as List<QueryDocumentSnapshot>,
                                                          data['devirler'] as List<QueryDocumentSnapshot>,
                                                          data['satislar'] as List<QueryDocumentSnapshot>,
                                                          pricesList,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  
                                                  const Divider(height: 12),
 
                                                  // Balance & Input Row
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                    children: [
                                                      Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text('Bu Ay Süt Alacağı:', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
                                                          Text('${formatNumber.format(monthAlacak)} ₺', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                                                          const SizedBox(height: 4),
                                                          Text('Toplam Cari Bakiye:', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
                                                          Text(
                                                            net >= 0 ? '${formatNumber.format(net)} ₺ Alacak' : '${formatNumber.format(net.abs())} ₺ Borç',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 11,
                                                              fontWeight: FontWeight.bold,
                                                              color: net >= 0 ? Colors.green[800] : Colors.red[800],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      // Custom payment input field
                                                      SizedBox(
                                                        width: 140,
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.end,
                                                          children: [
                                                            Text('Ödeme Tutarı (₺):', style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400)),
                                                            const SizedBox(height: 2),
                                                            SizedBox(
                                                              height: 36,
                                                              child: TextField(
                                                                controller: ctrl,
                                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                                                decoration: InputDecoration(
                                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                                                  hintText: '0.00',
                                                                  fillColor: AppColors.gray50,
                                                                  filled: true,
                                                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: AppColors.gray300)),
                                                                  suffixIcon: IconButton(
                                                                    padding: EdgeInsets.zero,
                                                                    icon: const Icon(Icons.flash_on_rounded, size: 14, color: AppColors.primary600),
                                                                    onPressed: () {
                                                                      ctrl.text = netPayable.toStringAsFixed(2);
                                                                      if (!isChecked) {
                                                                        setState(() {
                                                                          _selectedProducers.add(name);
                                                                        });
                                                                      }
                                                                    },
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  
                                                  const SizedBox(height: 12),
                                                  
                                                  // Quick Action Buttons
                                                  Row(
                                                    mainAxisAlignment: MainAxisAlignment.end,
                                                    children: [
                                                      TextButton.icon(
                                                        onPressed: () => _showOdemeDialog(context, name, currentFirmaName),
                                                        icon: const Icon(Icons.payment_rounded, size: 12),
                                                        label: const Text('Tekil Öde', style: TextStyle(fontSize: 10)),
                                                        style: TextButton.styleFrom(
                                                          foregroundColor: AppColors.success,
                                                          padding: const EdgeInsets.symmetric(horizontal: 8),
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
                                          );
                                        },
                                      );
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
