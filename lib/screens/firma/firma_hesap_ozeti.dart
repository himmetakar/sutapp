import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class FirmaHesapOzetiScreen extends StatefulWidget {
  final String? producerName;
  final bool isUreticiView;

  const FirmaHesapOzetiScreen({
    super.key,
    this.producerName,
    this.isUreticiView = false,
  });

  @override
  State<FirmaHesapOzetiScreen> createState() => _FirmaHesapOzetiScreenState();
}

class _FirmaHesapOzetiScreenState extends State<FirmaHesapOzetiScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _selectedProducer;
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  void initState() {
    super.initState();
    _selectedProducer = widget.producerName;
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  void _showMonthPicker() {
    showDialog(
      context: context,
      builder: (ctx) {
        int tempYear = _selectedMonth.year;
        final List<String> monthNames = [
          'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
        ];

        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Row(
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
              content: SizedBox(
                width: 300,
                height: 200,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    final isCurrent = _selectedMonth.month == (index + 1) && _selectedMonth.year == tempYear;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedMonth = DateTime(tempYear, index + 1);
                        });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isCurrent ? AppColors.primary600 : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          monthNames[index],
                          style: GoogleFonts.inter(
                            color: isCurrent ? Colors.white : AppColors.gray800,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    );
                  },
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

    if (widget.isUreticiView) {
      return FutureBuilder<QuerySnapshot>(
        future: _db.collection('ureticiler')
            .where('name', isEqualTo: widget.producerName)
            .limit(1)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              appBar: AppBar(title: Text(widget.producerName ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16))),
              body: const Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Scaffold(
              appBar: AppBar(title: Text(widget.producerName ?? '', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16))),
              body: const Center(child: Text('Üretici bilgileri yüklenemedi.')),
            );
          }

          final pDoc = snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final List<dynamic> firms = pDoc['firmalar'] ?? [];
          final currentFirmaName = firms.isNotEmpty ? firms.first.toString() : '';

          return _buildLedgerDetails(currentFirmaName, widget.producerName!);
        },
      );
    }

    final currentFirmaName = auth.user?.displayName ?? '';

    if (_selectedProducer == null) {
      return _buildProducerList(currentFirmaName);
    }

    return _buildLedgerDetails(currentFirmaName, _selectedProducer!);
  }

  Widget _buildProducerList(String firmaName) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hesap Görüntüleme', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/ureticiler'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getProducersStream(firma: firmaName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text('Kayıtlı üretici bulunamadı.', style: GoogleFonts.inter(color: AppColors.gray500)));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? '';
              final group = data['group'] ?? '';

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedProducer = name;
                  });
                },
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
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name[0] : 'Ü',
                            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Text(group, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.gray400),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  DateTime _getDocDate(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? date;
    final rawDate = data['tarih'] ?? data['verildigiTarih'] ?? data['tahsilEdilecegiTarih'] ?? data['vereseTarih'] ?? data['tarihStr'];
    if (rawDate != null) {
      try {
        date = DateFormat('dd.MM.yyyy').parse(rawDate.toString());
      } catch (_) {
        try {
          date = DateFormat('dd MMMM yyyy', 'tr_TR').parse(rawDate.toString());
        } catch (_) {}
      }
    }
    if (date == null && data['timestamp'] != null) {
      date = (data['timestamp'] as Timestamp).toDate();
    }
    return date ?? DateTime.now();
  }

  DateTime _getAvansDate(DocumentSnapshot doc) {
    return _getDocDate(doc);
  }

  Widget _buildLedgerDetails(String firmaName, String ureticiName) {
    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');
    final String monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth);

    // Calculate dates
    final startOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final endOfMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 1).subtract(const Duration(microseconds: 1));

    return StreamBuilder<Map<String, dynamic>>(
      stream: _streamProducerLedgerData(firmaName, ureticiName),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(ureticiName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16))),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(ureticiName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16))),
            body: Center(child: Text('Yükleme hatası: ${snapshot.error}')),
          );
        }

        final data = snapshot.data ?? {};
        final allCollections = data['collections'] as List<QueryDocumentSnapshot>;
        final prices = data['prices'] as List<QueryDocumentSnapshot>;
        final tahsilatlar = data['tahsilatlar'] as List<QueryDocumentSnapshot>;
        final avanslar = data['avanslar'] as List<QueryDocumentSnapshot>;
        final kesintiler = data['kesintiler'] as List<QueryDocumentSnapshot>;
        final cezalar = data['cezalar'] as List<QueryDocumentSnapshot>;
        final satislar = data['satislar'] as List<QueryDocumentSnapshot>;
        final devirler = data['devirler'] as List<QueryDocumentSnapshot>;
        final producerDoc = data['producerDoc'] as DocumentSnapshot?;
        final settingsDoc = data['finansAyarlari'] as DocumentSnapshot?;

        double bagkurOran = 2.10;
        double stopajOran = 1.00;
        double borsaOran = 0.20;
        final List<String> dynamicColumns = [];
        if (settingsDoc != null && settingsDoc.exists) {
          final sData = settingsDoc.data() as Map<String, dynamic>;
          bagkurOran = (sData['bagkurOran'] as num?)?.toDouble() ?? 2.10;
          stopajOran = (sData['stopajOran'] as num?)?.toDouble() ?? 1.00;
          borsaOran = (sData['borsaOran'] as num?)?.toDouble() ?? 0.20;
          final dynamicCols = sData['kesintiTurleri'] as List?;
          if (dynamicCols != null) {
            dynamicColumns.addAll(dynamicCols.map((e) => e.toString()));
          }
        }
        if (dynamicColumns.isEmpty) {
          dynamicColumns.addAll(['Bağkur', 'Stopaj', 'Borsa']);
        }

        Map<String, dynamic>? kesintiAyarlari;
        if (producerDoc != null && producerDoc.exists) {
          final pData = producerDoc.data() as Map<String, dynamic>;
          if (pData.containsKey('kesintiAyarlari')) {
            kesintiAyarlari = pData['kesintiAyarlari'] as Map<String, dynamic>?;
          }
        }

        String group = '';
        String bolge = '';
        if (producerDoc != null && producerDoc.exists) {
          final pData = producerDoc.data() as Map<String, dynamic>;
          group = pData['group'] ?? '';
          bolge = pData['bolge'] ?? '';
        }

        final priceList = prices.map((d) => d.data() as Map<String, dynamic>).toList();

        // 1. Calculate devir (before selected month)
        double devirSum = 0.0;

        // Past milk value
        double pastMilkVal = 0.0;
        for (var doc in allCollections) {
          final date = _getDocDate(doc);
          if (date.isBefore(startOfMonth)) {
            final double m = (doc['m'] as num?)?.toDouble() ?? 0.0;
            final String rawType = doc['tip'] ?? 'Soğuk süt';
            final String priceKey = FirestoreService().mapMilkTypeToPriceKey(rawType);
            final double price = FirestoreService().resolveMilkPrice(
              prices: priceList,
              producerName: ureticiName,
              bolge: bolge,
              group: group,
              type: priceKey,
            );
            pastMilkVal += m * price;
          }
        }
        devirSum += pastMilkVal;

        // Past tahsilatlar & odemeler
        for (var doc in tahsilatlar) {
          final date = _getDocDate(doc);
          if (date.isBefore(startOfMonth)) {
            final data = doc.data() as Map<String, dynamic>;
            final type = FirestoreService().getTahsilatType(data);
            final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            if (type == 'tahsilat') {
              devirSum += tutar;
            } else {
              devirSum -= tutar;
            }
          }
        }

        // Past sales (purchased products by producer)
        for (var doc in satislar) {
          final date = _getDocDate(doc);
          if (date.isBefore(startOfMonth)) {
            devirSum -= (doc['tutar'] as num?)?.toDouble() ?? 0.0;
          }
        }

        // Past advances (durum == 'aktif')
        for (var doc in avanslar) {
          final state = doc['durum'] ?? 'aktif';
          if (state != 'aktif') continue;
          final avansDate = _getDocDate(doc);
          if (avansDate.isBefore(startOfMonth)) {
            devirSum -= (doc['tutar'] as num?)?.toDouble() ?? 0.0;
          }
        }



        // Past dynamic kesintiler (Bağkur, Stopaj, Borsa dynamically calculated for past Süt Geliri)
        double pastDynamicKesinti = 0.0;
        for (var doc in allCollections) {
          final date = _getDocDate(doc);
          if (date.isBefore(startOfMonth)) {
            final double m = (doc['m'] as num?)?.toDouble() ?? 0.0;
            final String rawType = doc['tip'] ?? 'Soğuk süt';
            final String priceKey = FirestoreService().mapMilkTypeToPriceKey(rawType);
            final double price = FirestoreService().resolveMilkPrice(
              prices: priceList,
              producerName: ureticiName,
              bolge: bolge,
              group: group,
              type: priceKey,
            );
            final double colVal = m * price;
            
            for (var type in dynamicColumns) {
              double rate = 0.0;
              bool active = true;
              String? start;
              String? end;
              
              if (kesintiAyarlari != null && kesintiAyarlari.containsKey(type)) {
                final s = kesintiAyarlari[type];
                if (s is Map) {
                  rate = (s['oran'] as num?)?.toDouble() ?? 0.0;
                  active = s['aktif'] == true;
                  start = s['baslangic'] as String?;
                  end = s['bitis'] as String?;
                }
              } else {
                if (type == 'Bağkur') rate = bagkurOran;
                else if (type == 'Stopaj') rate = stopajOran;
                else if (type == 'Borsa') rate = borsaOran;
                else rate = 0.0;
                active = true;
              }
              
              if (active) {
                bool isInRange = true;
                DateTime parseDate(String s) {
                  if (s.contains('-')) {
                    return DateTime.parse(s);
                  } else {
                    final parts = s.split('.');
                    return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                  }
                }
                if (start != null && start.isNotEmpty) {
                  try {
                    final sDate = parseDate(start);
                    final cOnly = DateTime(date.year, date.month, date.day);
                    final sOnly = DateTime(sDate.year, sDate.month, sDate.day);
                    if (cOnly.isBefore(sOnly)) isInRange = false;
                  } catch (_) {}
                }
                if (end != null && end.isNotEmpty) {
                  try {
                    final eDate = parseDate(end);
                    final cOnly = DateTime(date.year, date.month, date.day);
                    final eOnly = DateTime(eDate.year, eDate.month, eDate.day);
                    if (cOnly.isAfter(eOnly)) isInRange = false;
                  } catch (_) {}
                }
                if (isInRange) {
                  pastDynamicKesinti += colVal * (rate / 100.0);
                }
              }
            }
          }
        }
        devirSum -= pastDynamicKesinti;

        // Past active penalties (durum == 'aktif')
        for (var doc in cezalar) {
          final date = _getDocDate(doc);
          final state = doc['durum'] ?? 'aktif';
          if (state != 'aktif') continue;
          if (date.isBefore(startOfMonth)) {
            double tutar = 0.0;
            if (doc['tip'] == 'oransal') {
              final double oran = (doc['oran'] as num?)?.toDouble() ?? 0.0;
              // Milk value for the month of this past penalty
              double penaltyMonthMilkVal = 0.0;
              for (var col in allCollections) {
                final colDate = _getDocDate(col);
                if (colDate.year == date.year && colDate.month == date.month) {
                  final double m = (col['m'] as num?)?.toDouble() ?? 0.0;
                  final String rawType = col['tip'] ?? 'Soğuk süt';
                  final String priceKey = FirestoreService().mapMilkTypeToPriceKey(rawType);
                  final double price = FirestoreService().resolveMilkPrice(
                    prices: priceList,
                    producerName: ureticiName,
                    bolge: bolge,
                    group: group,
                    type: priceKey,
                  );
                  penaltyMonthMilkVal += m * price;
                }
              }
              tutar = penaltyMonthMilkVal * (oran / 100.0);
            } else {
              tutar = (doc['tutar'] as num?)?.toDouble() ?? 0.0;
            }
            devirSum -= tutar;
          }
        }

        // Past devirler/corrections
        for (var doc in devirler) {
          final ts = doc['timestamp'] as Timestamp?;
          if (ts == null) continue;
          if (ts.toDate().isBefore(startOfMonth)) {
            devirSum += (doc['tutar'] as num?)?.toDouble() ?? 0.0;
          }
        }

        // 2. Filter current month transactions
        bool isInSelectedMonth(DocumentSnapshot doc) {
          final date = _getDocDate(doc);
          return date.isAfter(startOfMonth.subtract(const Duration(microseconds: 1))) && date.isBefore(endOfMonth.add(const Duration(microseconds: 1)));
        }

        final currentCols = allCollections.where((c) => isInSelectedMonth(c)).toList();
        final currentTah = tahsilatlar.where((t) => isInSelectedMonth(t)).toList();
        final currentAv = avanslar.where((a) => isInSelectedMonth(a)).toList();
        final currentKes = kesintiler.where((k) => isInSelectedMonth(k)).toList();
        final currentCez = cezalar.where((cz) => isInSelectedMonth(cz)).toList();
        final currentSat = satislar.where((s) => isInSelectedMonth(s)).toList();
        final currentDev = devirler.where((d) => isInSelectedMonth(d)).toList();

        // 3. Compute Current Month Calculations
        double toplamLitre = 0.0;
        double milkVal = 0.0;
        final Map<String, Map<String, dynamic>> milkGrouped = {};

        for (var doc in currentCols) {
          final data = doc.data() as Map<String, dynamic>;
          final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
          toplamLitre += m;

          final String rawType = data['tip'] ?? 'Soğuk süt';
          final String priceKey = FirestoreService().mapMilkTypeToPriceKey(rawType);
          final double price = FirestoreService().resolveMilkPrice(
            prices: priceList,
            producerName: ureticiName,
            bolge: bolge,
            group: group,
            type: priceKey,
          );
          milkVal += m * price;

          if (milkGrouped.containsKey(rawType)) {
            milkGrouped[rawType]!['m'] = (milkGrouped[rawType]!['m'] as double) + m;
          } else {
            milkGrouped[rawType] = {
              'tip': rawType,
              'price': price,
              'm': m,
            };
          }
        }

        double totalSales = currentSat.fold(0.0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + ((data['tutar'] as num?)?.toDouble() ?? 0.0);
        });

        double totalAvans = currentAv.where((a) => (a['durum'] ?? 'aktif') == 'aktif').fold(0.0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + ((data['tutar'] as num?)?.toDouble() ?? 0.0);
        });

        final currentCollectionsList = currentTah.where((t) {
          final data = t.data() as Map<String, dynamic>;
          return FirestoreService().getTahsilatType(data) == 'tahsilat';
        }).toList();

        final currentPaymentsList = currentTah.where((t) {
          final data = t.data() as Map<String, dynamic>;
          return FirestoreService().getTahsilatType(data) == 'odeme';
        }).toList();

        double totalCollections = currentCollectionsList.fold(0.0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + ((data['tutar'] as num?)?.toDouble() ?? 0.0);
        });

        double totalOdemeler = currentPaymentsList.fold(0.0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + ((data['tutar'] as num?)?.toDouble() ?? 0.0);
        });

        double totalCeza = 0.0;
        for (var doc in currentCez) {
          final data = doc.data() as Map<String, dynamic>;
          if ((data['durum'] ?? 'aktif') == 'aktif') {
            if (data['tip'] == 'oransal') {
              final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
              totalCeza += milkVal * (oran / 100.0);
            } else {
              totalCeza += (data['tutar'] as num?)?.toDouble() ?? 0.0;
            }
          }
        }

        double totalManualKesinti = 0.0;



        final Map<String, double> computedDynamicDeductions = {};
        final Map<String, double> computedRates = {};
        double totalDynamicKesinti = 0.0;

        for (var colDoc in currentCols) {
          final colData = colDoc.data() as Map<String, dynamic>;
          final mVal = colData['m'];
          final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);
          
          final String rawType = colData['tip'] ?? 'Soğuk süt';
          final String priceKey = FirestoreService().mapMilkTypeToPriceKey(rawType);
          final double price = FirestoreService().resolveMilkPrice(
            prices: priceList,
            producerName: ureticiName,
            bolge: bolge,
            group: group,
            type: priceKey,
          );
          final double colVal = m * price;
          
          // Resolve collection date
          DateTime colDate = DateTime.now();
          final ts = colData['timestamp'] as Timestamp?;
          if (ts != null) {
            colDate = ts.toDate();
          } else {
            final dateStr = colData['tarih'] as String?;
            if (dateStr != null && dateStr.isNotEmpty) {
              try {
                final parts = dateStr.split('.');
                colDate = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
              } catch (_) {}
            }
          }
          
          for (var type in dynamicColumns) {
            double rate = 0.0;
            bool active = true;
            String? start;
            String? end;
            
            if (kesintiAyarlari != null && kesintiAyarlari.containsKey(type)) {
              final s = kesintiAyarlari[type];
              if (s is Map) {
                rate = (s['oran'] as num?)?.toDouble() ?? 0.0;
                active = s['aktif'] == true;
                start = s['baslangic'] as String?;
                end = s['bitis'] as String?;
              }
            } else {
              if (type == 'Bağkur') rate = bagkurOran;
              else if (type == 'Stopaj') rate = stopajOran;
              else if (type == 'Borsa') rate = borsaOran;
              else rate = 0.0;
              active = true;
            }
            
            computedRates[type] = rate;
            
            if (active) {
              bool isInRange = true;
              DateTime parseDate(String s) {
                if (s.contains('-')) {
                  return DateTime.parse(s);
                } else {
                  final parts = s.split('.');
                  return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
                }
              }
              if (start != null && start.isNotEmpty) {
                try {
                  final sDate = parseDate(start);
                  final cOnly = DateTime(colDate.year, colDate.month, colDate.day);
                  final sOnly = DateTime(sDate.year, sDate.month, sDate.day);
                  if (cOnly.isBefore(sOnly)) isInRange = false;
                } catch (_) {}
              }
              if (end != null && end.isNotEmpty) {
                try {
                  final eDate = parseDate(end);
                  final cOnly = DateTime(colDate.year, colDate.month, colDate.day);
                  final eOnly = DateTime(eDate.year, eDate.month, eDate.day);
                  if (cOnly.isAfter(eOnly)) isInRange = false;
                } catch (_) {}
              }
              if (isInRange) {
                final double currentVal = computedDynamicDeductions[type] ?? 0.0;
                computedDynamicDeductions[type] = currentVal + colVal * (rate / 100.0);
                totalDynamicKesinti += colVal * (rate / 100.0);
              }
            }
          }
        }
        double totalKesinti = totalDynamicKesinti;

        double totalCorrections = currentDev.fold(0.0, (sum, doc) {
          final data = doc.data() as Map<String, dynamic>;
          return sum + ((data['tutar'] as num?)?.toDouble() ?? 0.0);
        });

        // 4. Net values
        final double donemSonuBakiye = milkVal + totalCollections - totalOdemeler - totalSales - totalAvans - totalCeza - totalKesinti + totalCorrections;
        final double mevcutBakiye = donemSonuBakiye + devirSum;
        final double netOdenecek = mevcutBakiye;

        // Build list of widgets
        final List<Widget> sections = [];

        // Month Selector Card
        sections.add(
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: AppShadows.sm,
              border: Border.all(color: AppColors.gray200),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.gray600),
                  onPressed: () => _changeMonth(-1),
                ),
                InkWell(
                  onTap: _showMonthPicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppColors.primary600, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        monthStr,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.gray400, size: 18),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.gray600),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
        );

        // Section 1: Süt Üretimi
        if (toplamLitre > 0) {
          final List<Widget> rows = [];
          milkGrouped.forEach((type, item) {
            final double m = item['m'];
            final double p = item['price'];
            rows.add(_buildSectionRow(
              leftText: '$type: ${p.toStringAsFixed(2)}₺/L',
              rightText: '${formatNumber.format(m)} L',
              isBoldRight: true,
            ));
          });
          rows.add(_buildSectionSummaryRow('Toplam Süt Üretimi', '${formatNumber.format(toplamLitre)} L', AppColors.primary600));
          rows.add(_buildSectionSummaryRow('Toplam Süt Geliri', '+ ${formatCurrency.format(milkVal)}', AppColors.success));

          sections.add(_buildSectionCard(
            title: 'Süt Üretimi',
            icon: Icons.water_drop_rounded,
            children: rows,
          ));
        }

        // Section 2: Alınan Ürünler
        if (currentSat.isNotEmpty) {
          final List<Widget> rows = [];
          for (var doc in currentSat) {
            final data = doc.data() as Map<String, dynamic>;
            final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            final tarihStr = data['tarih'] ?? '';
            rows.add(_buildSectionRow(
              leftText: '${data['urun'] ?? 'Yem'}',
              leftSubtitle: '${data['miktar'] ?? 1} adet x ${formatNumber.format((data['fiyat'] as num?)?.toDouble() ?? 0.0)} ₺',
              rightText: '${formatCurrency.format(tutar)}',
              rightColor: Colors.red[850],
              rightSubtitle: tarihStr,
            ));
          }
          rows.add(_buildSectionSummaryRow('Toplam Ürün', '+ ${formatCurrency.format(totalSales)}', AppColors.success));

          sections.add(_buildSectionCard(
            title: 'Alınan Ürünler',
            icon: Icons.shopping_basket_rounded,
            children: rows,
          ));
        }

        // Section 3: Alınan Avanslar
        if (currentAv.isNotEmpty) {
          final List<Widget> rows = [];
          for (var doc in currentAv) {
            final data = doc.data() as Map<String, dynamic>;
            final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            final tarihStr = data['tarih'] ?? '';
            rows.add(_buildSectionRow(
              leftText: data['aciklama'] ?? 'Avans',
              rightText: '${formatCurrency.format(tutar)}',
              rightColor: Colors.red[850],
              rightSubtitle: tarihStr,
            ));
          }
          rows.add(_buildSectionSummaryRow('Toplam Alınan Avans', '+ ${formatCurrency.format(totalAvans)}', AppColors.success));

          sections.add(_buildSectionCard(
            title: 'Alınan Avanslar',
            icon: Icons.monetization_on_rounded,
            children: rows,
          ));
        }

        // Section 4: Tahsilatlar
        if (currentCollectionsList.isNotEmpty) {
          final List<Widget> rows = [];
          for (var doc in currentCollectionsList) {
            final data = doc.data() as Map<String, dynamic>;
            final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            final tarihStr = data['tarih'] ?? '';
            rows.add(_buildSectionRow(
              leftText: data['aciklama']?.toString().isNotEmpty == true ? data['aciklama'] : 'Tahsilat',
              rightText: '+ ${formatCurrency.format(tutar)}',
              rightColor: AppColors.success,
              rightSubtitle: tarihStr,
            ));
          }
          rows.add(_buildSectionSummaryRow('Toplam Tahsilat', '+ ${formatCurrency.format(totalCollections)}', AppColors.success));

          sections.add(_buildSectionCard(
            title: 'Tahsilatlar',
            icon: Icons.move_to_inbox_rounded,
            children: rows,
          ));
        }

        // Section 4b: Yapılan Ödemeler
        if (currentPaymentsList.isNotEmpty) {
          final List<Widget> rows = [];
          for (var doc in currentPaymentsList) {
            final data = doc.data() as Map<String, dynamic>;
            final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            final tarihStr = data['tarih'] ?? '';
            rows.add(_buildSectionRow(
              leftText: data['aciklama']?.toString().isNotEmpty == true ? data['aciklama'] : 'Ödeme Yapıldı',
              rightText: '- ${formatCurrency.format(tutar)}',
              rightColor: Colors.red[800],
              rightSubtitle: tarihStr,
            ));
          }
          rows.add(_buildSectionSummaryRow('Toplam Ödeme', '- ${formatCurrency.format(totalOdemeler)}', Colors.red[800]!));

          sections.add(_buildSectionCard(
            title: 'Yapılan Ödemeler',
            icon: Icons.payments_rounded,
            children: rows,
          ));
        }

        // Section 5: Cezalar
        if (currentCez.isNotEmpty) {
          final List<Widget> rows = [];
          for (var doc in currentCez) {
            final data = doc.data() as Map<String, dynamic>;
            double tutar = 0.0;
            String detailStr = '';
            if (data['tip'] == 'oransal') {
              final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
              tutar = milkVal * (oran / 100.0);
              detailStr = 'Süt bedelinin %${oran.toStringAsFixed(2)} oranında';
            } else {
              tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            }
            final tarihStr = data['tarih'] ?? '';
            rows.add(_buildSectionRow(
              leftText: data['aciklama'] ?? 'Ceza Kesildi',
              leftSubtitle: detailStr.isNotEmpty ? detailStr : null,
              rightText: '- ${formatCurrency.format(tutar)}',
              rightColor: Colors.red[800],
              rightSubtitle: tarihStr,
            ));
          }
          rows.add(_buildSectionSummaryRow('Toplam Ceza', '- ${formatCurrency.format(totalCeza)}', Colors.red[800]!));

          sections.add(_buildSectionCard(
            title: 'Cezalar',
            icon: Icons.gavel_rounded,
            children: rows,
          ));
        }

        // Section 6: Kesintiler
        final List<Widget> kesintiRows = [];

        if (milkVal > 0) {
          for (var type in dynamicColumns) {
            final val = computedDynamicDeductions[type] ?? 0.0;
            final rate = computedRates[type] ?? 0.0;
            if (val > 0) {
              kesintiRows.add(_buildSectionRow(
                leftText: type,
                leftSubtitle: '%${rate.toStringAsFixed(2)} oranında',
                rightText: '- ${formatCurrency.format(val)}',
                rightColor: Colors.red[850],
              ));
            }
          }
        }



        if (kesintiRows.isNotEmpty) {
          sections.add(_buildSectionCard(
            title: 'Kesintiler',
            icon: Icons.bar_chart_rounded,
            children: [
              ...kesintiRows,
              _buildSectionSummaryRow('Toplam Kesinti', '- ${formatCurrency.format(totalKesinti)}', Colors.red[800]!),
            ],
          ));
        }

        // Section 7: Net Ödeme Card (at the bottom)
        sections.add(
          _buildNetPayableCard(
            sutGeliri: milkVal,
            tahsilatlar: totalCollections,
            odemeler: totalOdemeler,
            alinanUrunler: totalSales,
            alinanAvanslar: totalAvans,
            cezalar: totalCeza,
            kesintiler: totalKesinti,
            devir: devirSum,
          ),
        );

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ureticiName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                Text('Hesap Özeti', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
              ],
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (widget.isUreticiView) {
                  context.go('/uretici');
                } else if (widget.producerName != null) {
                  context.go('/firma/ureticiler');
                } else {
                  setState(() {
                    _selectedProducer = null;
                  });
                }
              },
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded, color: AppColors.primary600),
                tooltip: 'İşlem Geçmişi',
                onPressed: () => _showAllTransactionsDialog(
                  collections: allCollections,
                  satislar: satislar,
                  avanslar: avanslar,
                  tahsilatlar: tahsilatlar,
                  cezalar: cezalar,
                  kesintiler: kesintiler,
                  devirler: devirler,
                  priceList: priceList,
                  bolge: bolge,
                  group: group,
                  ureticiName: ureticiName,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.print_rounded, color: AppColors.primary600),
                tooltip: 'PDF Yazdır / Paylaş',
                onPressed: () => _exportPdfReport(
                  ureticiName: ureticiName,
                  bolge: bolge,
                  group: group,
                  collections: currentCols,
                  sales: currentSat,
                  advances: currentAv,
                  tahsilatlar: currentTah,
                  cezalar: currentCez,
                  kesintiler: currentKes,
                  devirler: currentDev,
                  priceList: priceList,
                  milkVal: milkVal,
                  totalLitre: toplamLitre,
                  totalSales: totalSales,
                  totalAvans: totalAvans,
                  totalCollections: totalCollections,
                  totalOdemeler: totalOdemeler,
                  totalCeza: totalCeza,
                  totalKesinti: totalKesinti,
                  devir: devirSum,
                  selectedMonth: _selectedMonth,
                  currentFirmaName: firmaName,
                  milkGrouped: milkGrouped,
                  bagkurOran: bagkurOran,
                  stopajOran: stopajOran,
                  borsaOran: borsaOran,
                  dynamicColumns: dynamicColumns,
                  computedDynamicDeductions: computedDynamicDeductions,
                  computedRates: computedRates,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.gray50,
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: sections,
          ),
        );
      },
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary600),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.gray800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSectionRow({
    required String leftText,
    String? leftSubtitle,
    required String rightText,
    bool isBoldRight = false,
    Color? rightColor,
    String? rightSubtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  leftText,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray700, fontWeight: FontWeight.w500),
                ),
                if (leftSubtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    leftSubtitle,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                rightText,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: isBoldRight ? FontWeight.bold : FontWeight.normal,
                  color: rightColor ?? AppColors.gray800,
                ),
              ),
              if (rightSubtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  rightSubtitle,
                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionSummaryRow(String label, String value, Color color) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.gray100, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.gray800,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSubHeader(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: AppColors.gray500,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            height: 1.5,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.primary300,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildNetPayableCard({
    required double sutGeliri,
    required double tahsilatlar,
    required double odemeler,
    required double alinanUrunler,
    required double alinanAvanslar,
    required double cezalar,
    required double kesintiler,
    required double devir,
  }) {
    final double donemSonuBakiye = sutGeliri + tahsilatlar - alinanUrunler - alinanAvanslar - cezalar - kesintiler;
    final double mevcutBakiye = donemSonuBakiye + devir;
    
    // Eğer mevcut bakiye eksi ise net ödenecek 0 olmalıdır.
    final double netOdenecek = mevcutBakiye >= 0 ? mevcutBakiye : 0.0;
    final double odenen = odemeler;
    final double digerAyaDevir = mevcutBakiye - odenen;

    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green[200]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.credit_card_rounded, size: 20, color: Colors.green[800]),
              const SizedBox(width: 8),
              Text(
                'Net Ödeme',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildNetRow('Süt Geliri Toplamı', '+ ${formatCurrency.format(sutGeliri)}', Colors.green[800]!),
          _buildNetRow('Alınan Ürünler', '- ${formatCurrency.format(alinanUrunler)}', Colors.red[800]!),
          _buildNetRow('Alınan Avanslar', '- ${formatCurrency.format(alinanAvanslar)}', Colors.red[800]!),
          _buildNetRow('Tahsilat', '+ ${formatCurrency.format(tahsilatlar)}', Colors.green[800]!),
          if (cezalar > 0)
            _buildNetRow('Cezalar Toplamı', '- ${formatCurrency.format(cezalar)}', Colors.red[800]!),
          _buildNetRow('Kesintiler Toplamı', '- ${formatCurrency.format(kesintiler)}', Colors.red[800]!),

          const Divider(color: Colors.green, height: 24),

          _buildNetSummaryRow(
            'Dönem Sonu Bakiye',
            '${donemSonuBakiye >= 0 ? '+' : ''} ${formatCurrency.format(donemSonuBakiye)}',
            donemSonuBakiye >= 0 ? Colors.green[800]! : Colors.red[800]!,
          ),
          const SizedBox(height: 8),
          _buildNetRow(
            'Önceki Aydan Devir',
            '${devir >= 0 ? '+' : ''} ${formatCurrency.format(devir)}',
            devir >= 0 ? Colors.green[800]! : Colors.red[800]!,
          ),
          const SizedBox(height: 8),
          _buildNetSummaryRow(
            'Mevcut Bakiye',
            '${mevcutBakiye >= 0 ? '+' : ''} ${formatCurrency.format(mevcutBakiye)}',
            mevcutBakiye >= 0 ? Colors.green[800]! : Colors.red[800]!,
          ),
          const SizedBox(height: 8),
          _buildNetSummaryRow(
            'Net Ödenecek',
            '${netOdenecek >= 0 ? '+' : ''} ${formatCurrency.format(netOdenecek)}',
            netOdenecek >= 0 ? Colors.green[800]! : Colors.red[800]!,
          ),
          const SizedBox(height: 8),
          _buildNetSummaryRow(
            'Ödenen',
            '${odenen >= 0 ? '+' : ''} ${formatCurrency.format(odenen)}',
            odenen >= 0 ? Colors.green[800]! : Colors.red[800]!,
          ),
          const SizedBox(height: 8),
          _buildNetSummaryRow(
            'Diğer Aya Devir',
            '${digerAyaDevir >= 0 ? '+' : ''} ${formatCurrency.format(digerAyaDevir)}',
            digerAyaDevir >= 0 ? Colors.green[800]! : Colors.red[800]!,
          ),
        ],
      ),
    );
  }

  Widget _buildNetRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 13, color: Colors.green[900], fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildNetSummaryRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: Colors.green[900], fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 13, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showAllTransactionsDialog({
    required List<QueryDocumentSnapshot> collections,
    required List<QueryDocumentSnapshot> satislar,
    required List<QueryDocumentSnapshot> avanslar,
    required List<QueryDocumentSnapshot> tahsilatlar,
    required List<QueryDocumentSnapshot> cezalar,
    required List<QueryDocumentSnapshot> kesintiler,
    required List<QueryDocumentSnapshot> devirler,
    required List<Map<String, dynamic>> priceList,
    required String bolge,
    required String group,
    required String ureticiName,
  }) {
    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final List<Map<String, dynamic>> allTx = [];
    for (var doc in collections) {
      final data = doc.data() as Map<String, dynamic>;
      final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
      final String rawType = data['tip'] ?? 'Soğuk süt';
      final String priceKey = FirestoreService().mapMilkTypeToPriceKey(rawType);
      final double price = FirestoreService().resolveMilkPrice(
        prices: priceList,
        producerName: ureticiName,
        bolge: bolge,
        group: group,
        type: priceKey,
      );
      final date = _getDocDate(doc);
      allTx.add({
        'ts': date,
        'title': 'Süt Teslimi ($rawType)',
        'subtitle': '${m.toStringAsFixed(1)} LT x ${price.toStringAsFixed(2)} ₺',
        'amount': m * price,
        'isPositive': true,
        'icon': Icons.water_drop_rounded,
        'color': AppColors.primary600,
      });
    }

    for (var doc in tahsilatlar) {
      final data = doc.data() as Map<String, dynamic>;
      final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
      final date = _getDocDate(doc);
      final type = FirestoreService().getTahsilatType(data);
      final isOdeme = type == 'odeme';
      allTx.add({
        'ts': date,
        'title': isOdeme
            ? 'Yapılan Ödeme (${data['odemeYontemi'] ?? 'Nakit'})'
            : 'Tahsilat Alındı (${data['odemeYontemi'] ?? 'Nakit'})',
        'subtitle': data['aciklama'] ?? '',
        'amount': tutar,
        'isPositive': !isOdeme,
        'icon': isOdeme ? Icons.payments_rounded : Icons.move_to_inbox_rounded,
        'color': isOdeme ? Colors.red : AppColors.success,
      });
    }

    for (var doc in satislar) {
      final data = doc.data() as Map<String, dynamic>;
      final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
      final date = _getDocDate(doc);
      allTx.add({
        'ts': date,
        'title': 'Ürün Alımı (${data['urun']})',
        'subtitle': '${data['miktar']} adet x ${(data['fiyat'] as num?)?.toDouble() ?? 0.0} ₺',
        'amount': tutar,
        'isPositive': false,
        'icon': Icons.shopping_basket_rounded,
        'color': Colors.red,
      });
    }

    for (var doc in avanslar) {
      final data = doc.data() as Map<String, dynamic>;
      if ((data['durum'] ?? 'aktif') == 'aktif') {
        final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
        final avansDate = _getDocDate(doc);
        allTx.add({
          'ts': avansDate,
          'title': 'Avans Ödemesi',
          'subtitle': data['aciklama'] ?? '',
          'amount': tutar,
          'isPositive': false,
          'icon': Icons.monetization_on_rounded,
          'color': Colors.red,
        });
      }
    }

    for (var doc in cezalar) {
      final data = doc.data() as Map<String, dynamic>;
      if ((data['durum'] ?? 'aktif') == 'aktif') {
        double tutar = 0.0;
        if (data['tip'] == 'oransal') {
          tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
        } else {
          tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
        }
        final date = _getDocDate(doc);
        allTx.add({
          'ts': date,
          'title': 'Ceza Kesildi',
          'subtitle': data['aciklama'] ?? '',
          'amount': tutar,
          'isPositive': false,
          'icon': Icons.gavel_rounded,
          'color': Colors.red,
        });
      }
    }

    for (var doc in devirler) {
      final data = doc.data() as Map<String, dynamic>;
      final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
      final date = _getDocDate(doc);
      allTx.add({
        'ts': date,
        'title': 'Devir / Düzeltme',
        'subtitle': data['aciklama'] ?? '',
        'amount': tutar.abs(),
        'isPositive': tutar >= 0,
        'icon': Icons.sync_alt_rounded,
        'color': tutar >= 0 ? AppColors.success : Colors.red,
      });
    }

    allTx.sort((a, b) => b['ts'].compareTo(a['ts']));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('İşlem Geçmişi (Tümü)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 450,
          height: 400,
          child: allTx.isEmpty
              ? Center(child: Text('Kayıtlı işlem bulunamadı.', style: GoogleFonts.inter(color: AppColors.gray500)))
              : ListView.builder(
                  itemCount: allTx.length,
                  itemBuilder: (context, index) {
                    final tx = allTx[index];
                    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(tx['ts']);

                    return ListTile(
                      leading: Icon(tx['icon'], color: tx['color']),
                      title: Text(tx['title'], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (tx['subtitle'].toString().isNotEmpty)
                            Text(tx['subtitle'], style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                          Text(dateStr, style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400)),
                        ],
                      ),
                      trailing: Text(
                        '${tx['isPositive'] ? '+' : '-'}${formatCurrency.format(tx['amount'])}',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: tx['isPositive'] ? AppColors.success : Colors.red[800],
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdfReport({
    required String ureticiName,
    required String bolge,
    required String group,
    required List<QueryDocumentSnapshot> collections,
    required List<QueryDocumentSnapshot> sales,
    required List<QueryDocumentSnapshot> advances,
    required List<QueryDocumentSnapshot> tahsilatlar,
    required List<QueryDocumentSnapshot> cezalar,
    required List<QueryDocumentSnapshot> kesintiler,
    required List<QueryDocumentSnapshot> devirler,
    required List<Map<String, dynamic>> priceList,
    required double milkVal,
    required double totalLitre,
    required double totalSales,
    required double totalAvans,
    required double totalCollections,
    required double totalOdemeler,
    required double totalCeza,
    required double totalKesinti,
    required double devir,
    required DateTime selectedMonth,
    required String currentFirmaName,
    required Map<String, Map<String, dynamic>> milkGrouped,
    required double bagkurOran,
    required double stopajOran,
    required double borsaOran,
    required List<String> dynamicColumns,
    required Map<String, double> computedDynamicDeductions,
    required Map<String, double> computedRates,
  }) async {
    try {
      final pdf = pw.Document();
      pw.Font fontRegular;
      pw.Font fontBold;
      bool useSanitized = false;

      try {
        fontRegular = await PdfGoogleFonts.robotoRegular();
        fontBold = await PdfGoogleFonts.robotoBold();
      } catch (e) {
        fontRegular = pw.Font.helvetica();
        fontBold = pw.Font.helveticaBold();
        useSanitized = true;
      }

      String sanitize(String text) {
        if (!useSanitized) return text;
        final translation = {
          'ı': 'i', 'İ': 'I', 'ğ': 'g', 'Ğ': 'G',
          'ü': 'u', 'Ü': 'U', 'ş': 's', 'Ş': 'S',
          'ö': 'o', 'Ö': 'O', 'ç': 'c', 'Ç': 'C',
        };
        String res = text;
        translation.forEach((k, v) => res = res.replaceAll(k, v));
        return res;
      }



      final double donemSonuBakiye = milkVal + totalCollections - totalSales - totalAvans - totalCeza - totalKesinti;
      final double mevcutBakiye = donemSonuBakiye + devir;
      final double netOdenecek = mevcutBakiye >= 0 ? mevcutBakiye : 0.0;
      final double odenen = totalOdemeler;
      final double digerAyaDevir = mevcutBakiye - odenen;

      final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: ' TL');
      final formatNumber = NumberFormat('#,##0.00', 'tr_TR');
      final monthName = DateFormat('MMMM yyyy', 'tr_TR').format(selectedMonth);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(sanitize(currentFirmaName.toUpperCase()), style: pw.TextStyle(font: fontBold, fontSize: 16, color: PdfColors.teal)),
                      pw.Text(sanitize('HESAP ONDENI RAPORU'), style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.grey700)),
                      pw.Text(sanitize('Uretici: $ureticiName'), style: pw.TextStyle(font: fontRegular, fontSize: 11)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(sanitize('Donem: $monthName'), style: pw.TextStyle(font: fontBold, fontSize: 11)),
                      pw.Text(sanitize('Tarih: ${DateFormat('dd.MM.yyyy').format(DateTime.now())}'), style: pw.TextStyle(font: fontRegular, fontSize: 9)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1.5, color: PdfColors.teal),
              pw.SizedBox(height: 15),

              // Süt Üretimi Table
              if (totalLitre > 0) ...[
                pw.Text(sanitize('SUT URETIMI'), style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.teal800)),
                pw.SizedBox(height: 5),
                pw.TableHelper.fromTextArray(
                  headers: [sanitize('Sut Turu'), sanitize('Fiyat'), sanitize('Miktar'), sanitize('Toplam Gelir')],
                  data: milkGrouped.values.map((v) {
                    final double m = v['m'];
                    final double p = v['price'];
                    return [
                      sanitize(v['tip']),
                      '${formatNumber.format(p)} TL',
                      '${formatNumber.format(m)} L',
                      formatCurrency.format(m * p)
                    ];
                  }).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                  cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
                ),
                pw.SizedBox(height: 15),
              ],

              // Alınan Ürünler Table
              if (sales.isNotEmpty) ...[
                pw.Text(sanitize('ALINAN URUNLER'), style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.teal800)),
                pw.SizedBox(height: 5),
                pw.TableHelper.fromTextArray(
                  headers: [sanitize('Urun Adi'), sanitize('Tarih'), sanitize('Miktar x Fiyat'), sanitize('Tutar')],
                  data: sales.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                    return [
                      sanitize(data['urun'] ?? 'Yem'),
                      sanitize(data['tarih'] ?? ''),
                      '${data['miktar']} adet x ${formatNumber.format((data['fiyat'] as num?)?.toDouble() ?? 0.0)} TL',
                      formatCurrency.format(tutar)
                    ];
                  }).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.teal),
                  cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
                ),
                pw.SizedBox(height: 15),
              ],

              // Cezalar Table
              if (cezalar.isNotEmpty) ...[
                pw.Text(sanitize('CEZALAR'), style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.red800)),
                pw.SizedBox(height: 5),
                pw.TableHelper.fromTextArray(
                  headers: [sanitize('Aciklama'), sanitize('Tarih'), sanitize('Detay'), sanitize('Tutar')],
                  data: cezalar.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    double tutar = 0.0;
                    String detailStr = '';
                    if (data['tip'] == 'oransal') {
                      final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
                      tutar = milkVal * (oran / 100.0);
                      detailStr = '%${oran.toStringAsFixed(2)} oraninda';
                    } else {
                      tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                    }
                    return [
                      sanitize(data['aciklama'] ?? 'Ceza'),
                      sanitize(data['tarih'] ?? ''),
                      sanitize(detailStr),
                      '- ${formatCurrency.format(tutar)}'
                    ];
                  }).toList(),
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.red),
                  cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
                ),
                pw.SizedBox(height: 15),
              ],

              // Kesintiler Table
              if (milkVal > 0) ...[
                pw.Text(sanitize('KESINTILER'), style: pw.TextStyle(font: fontBold, fontSize: 12, color: PdfColors.red800)),
                pw.SizedBox(height: 5),
                pw.TableHelper.fromTextArray(
                  headers: [sanitize('Kesinti Turu'), sanitize('Aciklama / Oran / Detay'), sanitize('Tutar')],
                  data: [
                    ...dynamicColumns.map((type) {
                      final val = computedDynamicDeductions[type] ?? 0.0;
                      final rate = computedRates[type] ?? 0.0;
                      if (val > 0) {
                        return [
                          sanitize(type),
                          '%${rate.toStringAsFixed(2)} oraninda',
                          '- ${formatCurrency.format(val)}'
                        ];
                      }
                      return null;
                    }).where((row) => row != null).cast<List<String>>(),
                  ],
                  border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                  headerStyle: pw.TextStyle(font: fontBold, fontSize: 10, color: PdfColors.white),
                  headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
                  cellStyle: pw.TextStyle(font: fontRegular, fontSize: 9),
                ),
                pw.SizedBox(height: 15),
              ],
 
              // Net Ödeme summary
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.grey300, width: 1),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(sanitize('NET ODEME HESAP TABLOSU'), style: pw.TextStyle(font: fontBold, fontSize: 11, color: PdfColors.teal800)),
                    pw.SizedBox(height: 6),
                    _buildPdfNetRow('Sut Geliri Toplami:', '+ ${formatCurrency.format(milkVal)}', fontRegular),
                    _buildPdfNetRow('Alinan Urunler:', '- ${formatCurrency.format(totalSales)}', fontRegular),
                    _buildPdfNetRow('Alinan Avanslar:', '- ${formatCurrency.format(totalAvans)}', fontRegular),
                    _buildPdfNetRow('Tahsilat:', '+ ${formatCurrency.format(totalCollections)}', fontRegular),
                    _buildPdfNetRow('Kesintiler Toplami:', '- ${formatCurrency.format(totalKesinti + totalCeza)}', fontRegular),
                    pw.Divider(thickness: 1, color: PdfColors.grey400),

                    _buildPdfNetRow('Donem Sonu Bakiye:', '${donemSonuBakiye >= 0 ? '+' : ''} ${formatCurrency.format(donemSonuBakiye)}', fontBold),
                    _buildPdfNetRow('Onceki Aydan Devir:', '${devir >= 0 ? '+' : ''} ${formatCurrency.format(devir)}', fontRegular),
                    _buildPdfNetRow('Mevcut Bakiye:', '${mevcutBakiye >= 0 ? '+' : ''} ${formatCurrency.format(mevcutBakiye)}', fontBold),
                    _buildPdfNetRow('Net Odenecek:', '${netOdenecek >= 0 ? '+' : ''} ${formatCurrency.format(netOdenecek)}', fontBold),
                    _buildPdfNetRow('Odenen:', '${odenen >= 0 ? '+' : ''} ${formatCurrency.format(odenen)}', fontBold),
                    _buildPdfNetRow('Diger Aya Devir:', '${digerAyaDevir >= 0 ? '+' : ''} ${formatCurrency.format(digerAyaDevir)}', fontBold),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'hesap_ozeti_${sanitize(ureticiName)}_${DateFormat('yyyyMM').format(selectedMonth)}.pdf',
      );
    } catch (e, stackTrace) {
      debugPrint('PDF layout error: $e\n$stackTrace');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF oluşturulurken hata oluştu: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  pw.Widget _buildPdfNetRow(String label, String value, pw.Font font, {double size = 10}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: size)),
          pw.Text(value, style: pw.TextStyle(font: font, fontSize: size)),
        ],
      ),
    );
  }

  Stream<Map<String, dynamic>> _streamProducerLedgerData(String firmaName, String ureticiName) {
    final controller = StreamController<Map<String, dynamic>>();

    QuerySnapshot? collections;
    QuerySnapshot? prices;
    QuerySnapshot? tahsilatlar;
    QuerySnapshot? avanslar;
    QuerySnapshot? kesintiler;
    QuerySnapshot? cezalar;
    QuerySnapshot? satislar;
    QuerySnapshot? ureticiler;
    QuerySnapshot? devirler;
    DocumentSnapshot? settings;

    void emitLatest() {
      if (collections != null &&
          prices != null &&
          tahsilatlar != null &&
          avanslar != null &&
          kesintiler != null &&
          cezalar != null &&
          satislar != null &&
          ureticiler != null &&
          devirler != null &&
          settings != null) {
        if (!controller.isClosed) {
          controller.add({
            'collections': collections!.docs,
            'prices': prices!.docs,
            'tahsilatlar': tahsilatlar!.docs,
            'avanslar': avanslar!.docs,
            'kesintiler': kesintiler!.docs,
            'cezalar': cezalar!.docs,
            'satislar': satislar!.docs,
            'producerDoc': ureticiler!.docs.isNotEmpty ? ureticiler!.docs.first : null,
            'devirler': devirler!.docs,
            'finansAyarlari': settings,
          });
        }
      }
    }

    final s1 = _db.collection('toplamalar').where('firma', isEqualTo: firmaName).where('u', isEqualTo: ureticiName).snapshots().listen((event) {
      collections = event;
      emitLatest();
    }, onError: (e) => controller.addError(e));

    final s2 = _db.collection('sut_fiyatlari').where('firma', isEqualTo: firmaName).snapshots().listen((event) {
      prices = event;
      emitLatest();
    }, onError: (e) => controller.addError(e));

    final s3 = _db.collection('tahsilatlar').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).snapshots().listen((event) {
      tahsilatlar = event;
      emitLatest();
    }, onError: (e) => controller.addError(e));

    final s4 = _db.collection('avanslar').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).snapshots().listen((event) {
      avanslar = event;
      emitLatest();
    }, onError: (e) => controller.addError(e));

    final s5 = _db.collection('kesintiler').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).snapshots().listen((event) {
      kesintiler = event;
      emitLatest();
    }, onError: (e) => controller.addError(e));

    final s6 = _db.collection('cezalar').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).snapshots().listen((event) {
      cezalar = event;
      emitLatest();
    }, onError: (e) => controller.addError(e));

    final s7 = _db.collection('satislar').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).snapshots().listen((event) {
      satislar = event;
      emitLatest();
    }, onError: (e) => controller.addError(e));

    final s8 = _db.collection('ureticiler').where('firmalar', arrayContains: firmaName).where('name', isEqualTo: ureticiName).limit(1).snapshots().listen((event) {
      ureticiler = event;
      emitLatest();
    }, onError: (e) => controller.addError(e));

    final s9 = _db.collection('devirler').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).snapshots().listen((event) {
      devirler = event;
      emitLatest();
    }, onError: (e) => controller.addError(e));

    final s10 = _db.collection('finans_ayarlari').doc(firmaName).snapshots().listen((event) {
      settings = event;
      emitLatest();
    }, onError: (e) => controller.addError(e));

    controller.onCancel = () {
      s1.cancel();
      s2.cancel();
      s3.cancel();
      s4.cancel();
      s5.cancel();
      s6.cancel();
      s7.cancel();
      s8.cancel();
      s9.cancel();
      s10.cancel();
    };

    return controller.stream;
  }
}
