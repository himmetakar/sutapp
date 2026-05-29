import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import 'package:fl_chart/fl_chart.dart';

class SatisRaporlariScreen extends StatefulWidget {
  const SatisRaporlariScreen({super.key});

  @override
  State<SatisRaporlariScreen> createState() => _SatisRaporlariScreenState();
}

class _SatisRaporlariScreenState extends State<SatisRaporlariScreen> {
  String _selectedTab = 'gunluk'; // gunluk, aylik, yillik
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _changeTab(String tab) {
    setState(() {
      _selectedTab = tab;
    });
  }

  Future<void> _selectDatePicker(BuildContext context) async {
    if (_selectedTab == 'gunluk') {
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        locale: const Locale('tr', 'TR'),
      );
      if (picked != null) {
        setState(() => _selectedDate = picked);
      }
    } else if (_selectedTab == 'aylik') {
      // Month selection dialog helper
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        locale: const Locale('tr', 'TR'),
        initialDatePickerMode: DatePickerMode.year,
      );
      if (picked != null) {
        setState(() => _selectedDate = DateTime(picked.year, picked.month));
      }
    } else {
      // Year selection dialog helper
      final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        locale: const Locale('tr', 'TR'),
        initialDatePickerMode: DatePickerMode.year,
      );
      if (picked != null) {
        setState(() => _selectedDate = DateTime(picked.year));
      }
    }
  }

  String _getDateDisplayText() {
    if (_selectedTab == 'gunluk') {
      return DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate);
    } else if (_selectedTab == 'aylik') {
      return DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);
    } else {
      return DateFormat('yyyy', 'tr_TR').format(_selectedDate);
    }
  }

  // Large buyer dairy companies list for auto-complete dropdown
  final List<String> _largeBuyers = [
    'Sütaş',
    'Pınar Süt',
    'Torku Süt',
    'İçim (Ak Gıda)',
    'Sek Süt',
    'Yörükoğlu',
    'Danone Türkiye',
    'Kaanlar Gıda',
    'Süteks',
    'Diğer'
  ];

  void _showAddSaleDialog(String currentFirmaName) {
    final buyerCtrl = TextEditingController();
    final dateCtrl = TextEditingController(text: DateFormat('dd.MM.yyyy').format(DateTime.now()));
    final miktarCtrl = TextEditingController();
    final birimFiyatCtrl = TextEditingController();
    final toplamTutarCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();

    DateTime saleDate = DateTime.now();
    String? selectedBuyer = 'Sütaş';
    buyerCtrl.text = 'Sütaş';
    String? selectedTankId;
    double calculatedTotal = 0.0;

    void updateCalculatedTotal(StateSetter setDialogState) {
      final miktar = double.tryParse(miktarCtrl.text.replaceAll(',', '.')) ?? 0.0;
      final birimFiyat = double.tryParse(birimFiyatCtrl.text.replaceAll(',', '.')) ?? 0.0;
      calculatedTotal = miktar * birimFiyat;
      setDialogState(() {
        toplamTutarCtrl.text = calculatedTotal.toStringAsFixed(2);
      });
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Yeni Süt Satışı Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Buyer Dropdown
                DropdownButtonFormField<String>(
                  value: selectedBuyer,
                  decoration: const InputDecoration(labelText: 'Alıcı Firma *'),
                  items: _largeBuyers.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedBuyer = val;
                        if (val != 'Diğer') {
                          buyerCtrl.text = val;
                        } else {
                          buyerCtrl.clear();
                        }
                      });
                    }
                  },
                ),
                if (selectedBuyer == 'Diğer') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: buyerCtrl,
                    decoration: const InputDecoration(labelText: 'Firma Adını Yazın *'),
                  ),
                ],
                const SizedBox(height: 12),

                // Date Picker field
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: saleDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      saleDate = picked;
                      setDialogState(() {
                        dateCtrl.text = DateFormat('dd.MM.yyyy').format(picked);
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextField(
                      controller: dateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Satış Tarihi *',
                        suffixIcon: Icon(Icons.calendar_month_rounded),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Miktar (LT)
                TextField(
                  controller: miktarCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Miktar (LT) *', suffixText: 'L'),
                  onChanged: (_) => updateCalculatedTotal(setDialogState),
                ),
                const SizedBox(height: 12),

                // Birim Fiyat (TL/LT)
                TextField(
                  controller: birimFiyatCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Birim Fiyat (₺/LT) *', suffixText: 'TL/L'),
                  onChanged: (_) => updateCalculatedTotal(setDialogState),
                ),
                const SizedBox(height: 12),

                // Toplam Tutar (TL)
                TextField(
                  controller: toplamTutarCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Toplam Tutar (₺) *', suffixText: 'TL'),
                ),
                const SizedBox(height: 12),

                // Source Tank Selection (Optional)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tanklar')
                      .where('firma', isEqualTo: currentFirmaName)
                      .where('tip', isEqualTo: 'merkez')
                      .snapshots(),
                  builder: (context, tankSnap) {
                    final tanks = tankSnap.data?.docs ?? [];
                    if (tanks.isEmpty) return const SizedBox();

                    return DropdownButtonFormField<String>(
                      value: selectedTankId,
                      decoration: const InputDecoration(
                        labelText: 'Çıkış Yapılacak Tank (Opsiyonel)',
                        hintText: 'Stok düşümü için tank seçin',
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Seçilmedi (Stok düşme)')),
                        ...tanks.map((t) {
                          final data = t.data() as Map<String, dynamic>;
                          final ad = data['ad'] ?? '';
                          final double stok = (data['stok'] as num?)?.toDouble() ?? 0.0;
                          return DropdownMenuItem(
                            value: t.id,
                            child: Text('$ad (${stok.toStringAsFixed(0)} L)'),
                          );
                        })
                      ],
                      onChanged: (val) {
                        setDialogState(() {
                          selectedTankId = val;
                        });
                      },
                    );
                  },
                ),
                const SizedBox(height: 12),

                // Açıklama
                TextField(
                  controller: aciklamaCtrl,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final double? miktar = double.tryParse(miktarCtrl.text.replaceAll(',', '.'));
                final double? birimFiyat = double.tryParse(birimFiyatCtrl.text.replaceAll(',', '.'));
                final double? toplam = double.tryParse(toplamTutarCtrl.text.replaceAll(',', '.'));
                final String buyer = buyerCtrl.text.trim();

                if (buyer.isEmpty || miktar == null || miktar <= 0 || birimFiyat == null || birimFiyat < 0 || toplam == null || toplam <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen zorunlu alanları geçerli değerlerle doldurun!'), backgroundColor: AppColors.danger),
                  );
                  return;
                }

                // If tank was selected, check stock limit
                if (selectedTankId != null) {
                  final tankDoc = await FirebaseFirestore.instance.collection('tanklar').doc(selectedTankId).get();
                  if (tankDoc.exists) {
                    final double currentStok = (tankDoc.data()?['stok'] as num?)?.toDouble() ?? 0.0;
                    if (currentStok < miktar) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Seçilen tankta yeterli stok yok! Mevcut: ${currentStok.toStringAsFixed(0)} L'), backgroundColor: AppColors.danger),
                      );
                      return;
                    }
                    // Decrement tank stock
                    await tankDoc.reference.update({
                      'stok': FieldValue.increment(-miktar),
                    });
                  }
                }

                // Save sale to Firestore
                await FirebaseFirestore.instance.collection('satislar').add({
                  'firma': currentFirmaName,
                  'aliciFirma': buyer,
                  'miktar': miktar,
                  'birimFiyat': birimFiyat,
                  'toplamTutar': toplam,
                  'tarih': dateCtrl.text,
                  'aciklama': aciklamaCtrl.text,
                  'tankId': selectedTankId ?? '',
                  'timestamp': FieldValue.serverTimestamp(),
                });

                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Süt satışı başarıyla kaydedildi!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('Satışı Ekle'),
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
      appBar: AppBar(
        title: Text('Satış Raporu', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/firma/sut-transferleri?action=addSale'),
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Satış Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('satislar')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, satisSnap) {
          if (satisSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('tanklar')
                .where('firma', isEqualTo: currentFirmaName)
                .where('tip', isEqualTo: 'merkez')
                .snapshots(),
            builder: (context, tankSnap) {
              if (tankSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('teslimatlar')
                    .snapshots(),
                builder: (context, teslimatSnap) {
                  if (teslimatSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allSales = satisSnap.data?.docs ?? [];
                  final allTanks = tankSnap.data?.docs ?? [];
                  final allDeliveries = teslimatSnap.data?.docs ?? [];

                  // Tank names to filter deliveries (backward compatibility)
                  final tankNames = allTanks.map((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    return (d['ad'] ?? d['tankAdi'] ?? '').toString();
                  }).where((name) => name.isNotEmpty).toSet();

                  // Filter company deliveries
                  final companyDeliveries = allDeliveries.where((doc) {
                    final d = doc.data() as Map<String, dynamic>;
                    final f = d['firma'] as String? ?? '';
                    final hedef = d['hedefTank'] as String? ?? '';
                    return f == currentFirmaName || tankNames.contains(hedef);
                  }).toList();

                  // Period filtering for sales
                  final List<QueryDocumentSnapshot> periodSales = [];
                  for (var doc in allSales) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime date;
                    final ts = data['timestamp'] as Timestamp?;
                    if (ts != null) {
                      date = ts.toDate();
                    } else {
                      final dateStr = data['tarih'] as String? ?? '';
                      try {
                        date = DateFormat('dd.MM.yyyy').parse(dateStr);
                      } catch (_) {
                        date = DateTime.now();
                      }
                    }

                    if (_selectedTab == 'gunluk') {
                      if (date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day) {
                        periodSales.add(doc);
                      }
                    } else if (_selectedTab == 'aylik') {
                      if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
                        periodSales.add(doc);
                      }
                    } else {
                      if (date.year == _selectedDate.year) {
                        periodSales.add(doc);
                      }
                    }
                  }

                  // Period filtering for deliveries
                  final List<QueryDocumentSnapshot> periodDeliveries = [];
                  for (var doc in companyDeliveries) {
                    final data = doc.data() as Map<String, dynamic>;
                    DateTime date;
                    final ts = data['timestamp'] as Timestamp?;
                    if (ts != null) {
                      date = ts.toDate();
                    } else {
                      final dateStr = data['tarih'] as String? ?? '';
                      try {
                        date = DateFormat('dd.MM.yyyy').parse(dateStr);
                      } catch (_) {
                        date = DateTime.now();
                      }
                    }

                    if (_selectedTab == 'gunluk') {
                      if (date.year == _selectedDate.year && date.month == _selectedDate.month && date.day == _selectedDate.day) {
                        periodDeliveries.add(doc);
                      }
                    } else if (_selectedTab == 'aylik') {
                      if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
                        periodDeliveries.add(doc);
                      }
                    } else {
                      if (date.year == _selectedDate.year) {
                        periodDeliveries.add(doc);
                      }
                    }
                  }

                  // Group deliveries by Date
                  final Map<String, double> deliveriesByDate = {};
                  for (var doc in companyDeliveries) {
                    final data = doc.data() as Map<String, dynamic>;
                    final tarih = data['tarih'] as String? ?? '';
                    final miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
                    if (tarih.isNotEmpty) {
                      deliveriesByDate[tarih] = (deliveriesByDate[tarih] ?? 0.0) + miktar;
                    }
                  }

                  // Calculate total Giriş for period
                  double totalGiris = 0.0;
                  for (var doc in periodDeliveries) {
                    final data = doc.data() as Map<String, dynamic>;
                    final m = (data['miktar'] as num?)?.toDouble() ?? 0.0;
                    totalGiris += m;
                  }

                  // Search query filtering for sales
                  final filteredSales = periodSales.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final aliciFirma = data['aliciFirma'] as String? ?? '';
                    return _searchQuery.isEmpty || aliciFirma.toLowerCase().contains(_searchQuery.toLowerCase());
                  }).toList();

                  // Metrics calculation
                  double totalMiktar = 0.0;
                  double totalCiro = 0.0;
                  final Set<String> uniqueBuyers = {};

                  for (var doc in filteredSales) {
                    final data = doc.data() as Map<String, dynamic>;
                    final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
                    final double ciro = (data['toplamTutar'] as num?)?.toDouble() ?? 0.0;
                    final buyer = data['aliciFirma'] as String? ?? '';

                    totalMiktar += miktar;
                    totalCiro += ciro;
                    if (buyer.isNotEmpty) uniqueBuyers.add(buyer);
                  }

                  final double avgPrice = totalMiktar > 0 ? (totalCiro / totalMiktar) : 0.0;

                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Segment Selector
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: Colors.white,
                          child: Row(
                            children: [
                              _buildSegmentButton('gunluk', 'Günlük'),
                              _buildSegmentButton('aylik', 'Aylık'),
                              _buildSegmentButton('yillik', 'Yıllık'),
                            ],
                          ),
                        ),

                        // Date Picker Display Card
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          child: GestureDetector(
                            onTap: () => _selectDatePicker(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.gray200),
                                boxShadow: AppShadows.sm,
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_month_rounded, color: AppColors.primary500, size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    _getDateDisplayText(),
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gray800),
                                  ),
                                  const Spacer(),
                                  const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.gray400),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Search Bar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: AppShadows.sm,
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: (val) => setState(() => _searchQuery = val),
                              decoration: InputDecoration(
                                hintText: 'Firma ara...',
                                hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400, size: 20),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                            ),
                          ),
                        ),

                        // Row of 4 Summary Cards
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _buildSummaryCard('Toplam Süt', '${formatNumber.format(totalMiktar)} L', Icons.water_drop_rounded, Colors.blue),
                                const SizedBox(width: 8),
                                _buildSummaryCard('Toplam Ciro', '${formatNumber.format(totalCiro)} ₺', Icons.money_rounded, Colors.green),
                                const SizedBox(width: 8),
                                _buildSummaryCard('Ort. Fiyat', '${avgPrice.toStringAsFixed(2)} ₺/L', Icons.calculate_rounded, Colors.orange),
                                const SizedBox(width: 8),
                                _buildSummaryCard('Firma Sayısı', '${uniqueBuyers.length}', Icons.business_rounded, Colors.purple),
                              ],
                            ),
                          ),
                        ),

                        // Dynamic Doughnut Chart Card showing milk sales distribution & depot comparison
                        Builder(
                          builder: (context) {
                            final Map<String, double> chartDataMap = {};
                            double chartTotal = 0.0;
                            for (var doc in filteredSales) {
                              final data = doc.data() as Map<String, dynamic>;
                              final String buyer = data['aliciFirma'] ?? 'Diğer';
                              final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
                              if (buyer.isNotEmpty && miktar > 0) {
                                chartDataMap[buyer] = (chartDataMap[buyer] ?? 0.0) + miktar;
                                chartTotal += miktar;
                              }
                            }

                            if (chartTotal <= 0 && totalGiris <= 0) return const SizedBox();

                            final colorsList = [
                              Colors.green,
                              Colors.blue,
                              Colors.orange,
                              Colors.red,
                              Colors.purple,
                              Colors.teal,
                              Colors.amber,
                            ];

                            final List<PieChartSectionData> sections = [];
                            int colorIndex = 0;
                            chartDataMap.forEach((buyer, miktar) {
                              final pct = chartTotal > 0 ? (miktar / chartTotal) * 100 : 0.0;
                              sections.add(
                                PieChartSectionData(
                                  color: colorsList[colorIndex % colorsList.length],
                                  value: miktar,
                                  title: '${pct.toStringAsFixed(1)}%',
                                  radius: 20,
                                  showTitle: true,
                                  titleStyle: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                              colorIndex++;
                            });

                            int colIdx = 0;
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.gray200),
                                boxShadow: AppShadows.sm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Firma Satış Oranları & Depo Dengesi',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                  ),
                                  const SizedBox(height: 12),
                                  // Giriş vs Çıkış Dengesi
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.green.shade100),
                                          ),
                                          child: Column(
                                            children: [
                                              Text('Toplam Depo Girişi', style: GoogleFonts.inter(fontSize: 10, color: Colors.green.shade800, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text('${formatNumber.format(totalGiris).replaceAll(',00', '')} L', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.blue.shade100),
                                          ),
                                          child: Column(
                                            children: [
                                              Text('Toplam Satış (Çıkış)', style: GoogleFonts.inter(fontSize: 10, color: Colors.blue.shade800, fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Text('${formatNumber.format(chartTotal).replaceAll(',00', '')} L', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue.shade900)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  if (chartTotal > 0)
                                    Row(
                                      children: [
                                        SizedBox(
                                          width: 100,
                                          height: 100,
                                          child: PieChart(
                                            PieChartData(
                                              sectionsSpace: 2,
                                              centerSpaceRadius: 28,
                                              sections: sections,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 24),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: chartDataMap.entries.map((entry) {
                                              final buyer = entry.key;
                                              final miktar = entry.value;
                                              final pct = chartTotal > 0 ? (miktar / chartTotal) * 100 : 0.0;
                                              final color = colorsList[colIdx++ % colorsList.length];

                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 6.0),
                                                child: Row(
                                                  children: [
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: BoxDecoration(
                                                        color: color,
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: Text(
                                                        buyer,
                                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.gray700),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      '%${pct.toStringAsFixed(1)}',
                                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray900),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Text(
                                          'Seçilen dönemde henüz satış kaydı bulunmamaktadır.',
                                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Section Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Günlük Stok',
                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                            ),
                          ),
                        ),

                        // Horizontal Table of sales (Günlük Stok)
                        (filteredSales.isEmpty && periodDeliveries.isEmpty)
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 40),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: const BoxDecoration(color: AppColors.gray100, shape: BoxShape.circle),
                                        child: const Icon(Icons.inbox_rounded, size: 48, color: AppColors.gray400),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Veri bulunamadı',
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray700),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Seçilen dönemde kayıt yok',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Builder(
                                builder: (context) {
                                  // Extract unique dates and unique buyer companies
                                  final List<String> uniqueDates = [];
                                  final List<String> uniqueBuyers = [];
                                  final Map<String, Map<String, double>> cellData = {};

                                  for (var doc in filteredSales) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final String tarih = data['tarih'] ?? '';
                                    final String buyer = data['aliciFirma'] ?? '';
                                    final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;

                                    if (tarih.isNotEmpty) {
                                      if (!uniqueDates.contains(tarih)) {
                                        uniqueDates.add(tarih);
                                      }
                                      if (buyer.isNotEmpty) {
                                        if (!uniqueBuyers.contains(buyer)) {
                                          uniqueBuyers.add(buyer);
                                        }
                                        if (!cellData.containsKey(tarih)) {
                                          cellData[tarih] = {};
                                        }
                                        cellData[tarih]![buyer] = (cellData[tarih]![buyer] ?? 0.0) + miktar;
                                      }
                                    }
                                  }

                                  // Add dates from periodDeliveries
                                  for (var doc in periodDeliveries) {
                                    final data = doc.data() as Map<String, dynamic>;
                                    final String tarih = data['tarih'] ?? '';
                                    if (tarih.isNotEmpty && !uniqueDates.contains(tarih)) {
                                      uniqueDates.add(tarih);
                                    }
                                  }

                                  // Sort dates descending (newest first)
                                  uniqueDates.sort((a, b) {
                                    try {
                                      final dateA = DateFormat('dd.MM.yyyy').parse(a);
                                      final dateB = DateFormat('dd.MM.yyyy').parse(b);
                                      return dateB.compareTo(dateA);
                                    } catch (_) {
                                      return b.compareTo(a);
                                    }
                                  });

                                  // Sort buyer names alphabetically
                                  uniqueBuyers.sort();

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.gray200),
                                        boxShadow: AppShadows.sm,
                                      ),
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        child: Theme(
                                          data: Theme.of(context).copyWith(
                                            cardColor: Colors.white,
                                            dividerColor: AppColors.gray100,
                                          ),
                                          child: DataTable(
                                            headingRowColor: WidgetStateProperty.all(AppColors.gray50),
                                            headingRowHeight: 44,
                                            dataRowMinHeight: 48,
                                            dataRowMaxHeight: 48,
                                            columnSpacing: 28,
                                            columns: [
                                              DataColumn(label: Text('Tarih', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray800))),
                                              DataColumn(label: Text('Depo Giriş', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade800))),
                                              ...uniqueBuyers.map((buyer) => DataColumn(
                                                label: Text(buyer, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray800)),
                                              )),
                                              DataColumn(label: Text('Toplam Çıkış', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray800))),
                                            ],
                                            rows: uniqueDates.map((tarih) {
                                              double rowTotal = 0.0;
                                              final cells = <DataCell>[];
                                              final double girisMiktar = deliveriesByDate[tarih] ?? 0.0;

                                              // Date cell (display dd.MM if possible, else full)
                                              String formattedDate = tarih;
                                              try {
                                                final parsed = DateFormat('dd.MM.yyyy').parse(tarih);
                                                formattedDate = DateFormat('dd.MM').format(parsed);
                                              } catch (_) {}

                                              cells.add(DataCell(
                                                Text(
                                                  formattedDate,
                                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray700),
                                                ),
                                              ));

                                              // Depo Giriş cell
                                              cells.add(DataCell(
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: girisMiktar > 0 ? Colors.green.shade50 : Colors.transparent,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    girisMiktar > 0 ? '${formatNumber.format(girisMiktar).replaceAll(',00', '')} L' : '0 L',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: girisMiktar > 0 ? Colors.green.shade800 : AppColors.gray400,
                                                      fontWeight: girisMiktar > 0 ? FontWeight.bold : FontWeight.normal,
                                                    ),
                                                  ),
                                                ),
                                              ));

                                              // Buyer cells
                                              for (var buyer in uniqueBuyers) {
                                                final double miktar = cellData[tarih]?[buyer] ?? 0.0;
                                                rowTotal += miktar;
                                                final String text = miktar > 0 ? '${formatNumber.format(miktar).replaceAll(',00', '')} L' : '0 L';
                                                cells.add(DataCell(
                                                  Text(
                                                    text,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      color: miktar > 0 ? AppColors.primary700 : AppColors.gray400,
                                                      fontWeight: miktar > 0 ? FontWeight.w600 : FontWeight.normal,
                                                    ),
                                                  ),
                                                ));
                                              }

                                              // Row total cell (Toplam Çıkış)
                                              cells.add(DataCell(
                                                Text(
                                                  '${formatNumber.format(rowTotal).replaceAll(',00', '')} L',
                                                  style: GoogleFonts.inter(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.gray900,
                                                  ),
                                                ),
                                              ));

                                              return DataRow(cells: cells);
                                            }).toList(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildSegmentButton(String tabKey, String label) {
    final isSelected = _selectedTab == tabKey;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeTab(tabKey),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary500 : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? null : Border.all(color: AppColors.gray200),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : AppColors.gray700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray800), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(title, style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400)),
        ],
      ),
    );
  }
}
