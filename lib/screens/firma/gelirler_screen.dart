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

class GelirlerScreen extends StatefulWidget {
  const GelirlerScreen({super.key});

  @override
  State<GelirlerScreen> createState() => _GelirlerScreenState();
}

class _GelirlerScreenState extends State<GelirlerScreen> {
  String _selectedFilter = 'aylik'; // haftalik, aylik, yillik, tum
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  // Financial Metrics
  double _totalSales = 0.0;
  int _salesCount = 0;
  
  double _totalDeductions = 0.0;
  int _deductionsCount = 0;

  double _totalCollected = 0.0;
  int _collectedCount = 0;
  double _totalPaidOut = 0.0;

  double _milkCost = 0.0;
  double _operatingExpenses = 0.0;
  int _expensesCount = 0;

  double _totalAvans = 0.0;
  int _avansCount = 0;

  // Categorized breakdown
  double _sutSalesTotal = 0.0;
  int _sutSalesCount = 0;
  double _sutNetKar = 0.0;

  double _yemSalesTotal = 0.0;
  int _yemSalesCount = 0;

  double _otherRevenuesTotal = 0.0;
  int _otherRevenuesCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchFinancialData();
  }

  // Format Date for Display
  String _getDateDisplayText() {
    if (_selectedFilter == 'haftalik') {
      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      return "${DateFormat('dd MMM', 'tr_TR').format(startOfWeek)} - ${DateFormat('dd MMM yyyy', 'tr_TR').format(endOfWeek)}";
    } else if (_selectedFilter == 'aylik') {
      return DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);
    } else if (_selectedFilter == 'yillik') {
      return DateFormat('yyyy', 'tr_TR').format(_selectedDate);
    } else {
      return 'Tüm Zamanlar';
    }
  }

  void _changeDate(int delta) {
    setState(() {
      if (_selectedFilter == 'haftalik') {
        _selectedDate = _selectedDate.add(Duration(days: delta * 7));
      } else if (_selectedFilter == 'aylik') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
      } else if (_selectedFilter == 'yillik') {
        _selectedDate = DateTime(_selectedDate.year + delta);
      }
    });
    _fetchFinancialData();
  }

  DateTime? _getDocDate(dynamic field) {
    if (field == null) return null;
    if (field is Timestamp) return field.toDate();
    if (field is DateTime) return field;
    if (field is String) {
      try {
        return DateFormat('dd.MM.yyyy').parse(field);
      } catch (_) {
        try {
          return DateFormat('dd MMMM yyyy', 'tr_TR').parse(field);
        } catch (_) {
          return DateTime.tryParse(field);
        }
      }
    }
    return null;
  }

  bool _isWithinFilter(DateTime? date) {
    if (date == null) return false;
    if (_selectedFilter == 'tum') return true;

    if (_selectedFilter == 'haftalik') {
      final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final end = start.add(const Duration(days: 7));
      return date.isAfter(start.subtract(const Duration(seconds: 1))) && date.isBefore(end);
    } else if (_selectedFilter == 'aylik') {
      return date.year == _selectedDate.year && date.month == _selectedDate.month;
    } else if (_selectedFilter == 'yillik') {
      return date.year == _selectedDate.year;
    }
    return false;
  }

  Future<void> _fetchFinancialData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    try {
      // 1. Fetch Satislar (Milk Sales)
      final satisSnap = await FirebaseFirestore.instance
          .collection('satislar')
          .where('firma', isEqualTo: currentFirmaName)
          .get();

      double tempSutSales = 0.0;
      int tempSutSalesCount = 0;

      for (var doc in satisSnap.docs) {
        final data = doc.data();
        final date = _getDocDate(data['tarih'] ?? data['timestamp']);
        if (_isWithinFilter(date)) {
          final double val = (data['toplam'] as num?)?.toDouble() ?? 0.0;
          tempSutSales += val;
          tempSutSalesCount++;
        }
      }

      // 2. Fetch Kesintiler (Producer Deductions e.g. Yem, Aidat)
      final kesintilerSnap = await FirebaseFirestore.instance
          .collection('kesintiler')
          .where('firma', isEqualTo: currentFirmaName)
          .get();

      double tempYemSales = 0.0;
      int tempYemSalesCount = 0;
      double tempOtherRevenues = 0.0;
      int tempOtherRevenuesCount = 0;

      for (var doc in kesintilerSnap.docs) {
        final data = doc.data();
        final durum = data['durum'] as String? ?? 'aktif';
        if (durum == 'iptal') continue;

        final date = _getDocDate(data['tarih'] ?? data['timestamp']);
        if (_isWithinFilter(date)) {
          final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
          final tur = data['kesintiTuru'] as String? ?? 'Yem Kesintisi';

          if (tur.contains('Yem')) {
            tempYemSales += tutar;
            tempYemSalesCount++;
          } else {
            tempOtherRevenues += tutar;
            tempOtherRevenuesCount++;
          }
        }
      }

      // 3. Fetch Tahsilatlar (Collected payments / collections)
      final tahsilatSnap = await FirebaseFirestore.instance
          .collection('tahsilatlar')
          .where('firma', isEqualTo: currentFirmaName)
          .get();

      double tempCollected = 0.0;
      int tempCollectedCount = 0;
      double tempPaidOut = 0.0;

      final firestoreService = FirestoreService();
      for (var doc in tahsilatSnap.docs) {
        final data = doc.data();
        final date = _getDocDate(data['tarih'] ?? data['timestamp']);
        if (_isWithinFilter(date)) {
          final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
          final type = firestoreService.getTahsilatType(data);
          if (type == 'tahsilat') {
            tempCollected += tutar;
            tempCollectedCount++;
          } else {
            tempPaidOut += tutar;
          }
        }
      }

      // 4. Fetch Giderler (Operating expenses)
      final giderSnap = await FirebaseFirestore.instance
          .collection('giderler')
          .where('firma', isEqualTo: currentFirmaName)
          .get();

      double tempExpenses = 0.0;
      int tempExpensesCount = 0;

      for (var doc in giderSnap.docs) {
        final data = doc.data();
        final date = _getDocDate(data['tarih'] ?? data['timestamp']);
        if (_isWithinFilter(date)) {
          final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
          tempExpenses += tutar;
          tempExpensesCount++;
        }
      }

      // 4b. Fetch Cari Islemler payments to suppliers (Firma Ödemeleri)
      final cariIslemSnap = await FirebaseFirestore.instance
          .collection('cari_islemler')
          .where('firma', isEqualTo: currentFirmaName)
          .where('tip', isEqualTo: 'odeme')
          .get();

      for (var doc in cariIslemSnap.docs) {
        final data = doc.data();
        final date = _getDocDate(data['tarih'] ?? data['timestamp']);
        if (_isWithinFilter(date)) {
          final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
          tempExpenses += tutar;
          tempExpensesCount++;
        }
      }

      // 5. Fetch Süt Alım Bedeli (dynamic calculation based on price config)
      final toplamalarSnap = await FirebaseFirestore.instance
          .collection('toplamalar')
          .where('firma', isEqualTo: currentFirmaName)
          .get();

      final priceSnap = await FirebaseFirestore.instance
          .collection('sut_fiyatlari')
          .where('firma', isEqualTo: currentFirmaName)
          .get();
      final prices = priceSnap.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();

      final producersSnap = await FirebaseFirestore.instance
          .collection('ureticiler')
          .where('firmalar', arrayContains: currentFirmaName)
          .get();
      final producersMap = {
        for (var doc in producersSnap.docs)
          doc['name'] as String: doc.data() as Map<String, dynamic>
      };

      double tempMilkCost = 0.0;

      for (var doc in toplamalarSnap.docs) {
        final data = doc.data();
        final date = _getDocDate(data['tarih'] ?? data['timestamp']);
        if (_isWithinFilter(date)) {
          final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
          final String ureticiName = data['u'] ?? '';
          final String rawType = data['tip'] ?? 'So\u011fuk S\u00fct';

          final pData = producersMap[ureticiName] ?? {};
          final bolge = pData['bolge'] ?? '';
          final group = pData['group'] ?? '';

          final String priceKey = firestoreService.mapMilkTypeToPriceKey(rawType);
          final double price = firestoreService.resolveMilkPrice(
            prices: prices,
            producerName: ureticiName,
            bolge: bolge,
            group: group,
            type: priceKey,
          );

          tempMilkCost += m * price;
        }
      }

      // Fetch Avanslar (Producer advances / payments)
      final avansSnap = await FirebaseFirestore.instance
          .collection('avanslar')
          .where('firma', isEqualTo: currentFirmaName)
          .get();

      double tempAvans = 0.0;
      int tempAvansCount = 0;

      for (var doc in avansSnap.docs) {
        final data = doc.data();
        final durum = data['durum'] as String? ?? 'aktif';
        if (durum == 'aktif') {
          final rawDate = data['tahsilEdilecegiTarih'] ?? data['verildigiTarih'] ?? data['tarih'] ?? data['timestamp'];
          final date = _getDocDate(rawDate);
          if (_isWithinFilter(date)) {
            final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            tempAvans += tutar;
            tempAvansCount++;
          }
        }
      }

      setState(() {
        _sutSalesTotal = tempSutSales;
        _sutSalesCount = tempSutSalesCount;
        _sutNetKar = tempSutSales - tempMilkCost;

        _yemSalesTotal = tempYemSales;
        _yemSalesCount = tempYemSalesCount;

        _otherRevenuesTotal = tempOtherRevenues;
        _otherRevenuesCount = tempOtherRevenuesCount;

        _totalSales = tempSutSales;
        _salesCount = tempSutSalesCount;

        _totalDeductions = tempYemSales + tempOtherRevenues;
        _deductionsCount = tempYemSalesCount + tempOtherRevenuesCount;

        _totalCollected = tempCollected;
        _collectedCount = tempCollectedCount;
        _totalPaidOut = tempPaidOut;

        _milkCost = tempMilkCost;
        _operatingExpenses = tempExpenses;
        _expensesCount = tempExpensesCount;

        _totalAvans = tempAvans;
        _avansCount = tempAvansCount;

        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Veri yükleme hatası: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gelirler = Üreticilerden gelen ödemeler (tahsilatlar) + Üreticiye satılan ürünler (kesintiler)
    final double totalRevenue = _totalCollected + _totalDeductions;
    // Giderler = Üretici hesap ödemeleri (avanslar + süt ödemeleri) + Genel giderler / tedarikçi ödemeleri (giderler)
    final double totalExpenses = _totalAvans + _operatingExpenses + _totalPaidOut;
    // Net profit or loss (Gelirler - Giderler)
    final double netProfitLoss = totalRevenue - totalExpenses;
    final bool isProfit = netProfitLoss >= 0;

    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    // Stats calculations for header card
    // Mockup has: 2 Satış, 0 Ödenen, 2 Bekleyen
    // Satış: total count of sales
    // Ödenen: count of collections (tahsilatlar)
    // Bekleyen: sales count - collection count (clamped to >= 0)
    final int pendingCount = (_salesCount - _collectedCount).clamp(0, 999);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        title: Text(
          'Gelir Takibi',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => context.go('/firma/finans'),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs (Haftalık, Aylık, Yıllık, Tüm Zamanlar)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildFilterTab('haftalik', 'Haftalık'),
                _buildFilterTab('aylik', 'Aylık'),
                _buildFilterTab('yillik', 'Yıllık'),
                _buildFilterTab('tum', 'Tüm Zamanlar'),
              ],
            ),
          ),
          const Divider(color: AppColors.gray100, height: 1),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _fetchFinancialData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Card (Mockup Style Header Card)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.gray200, width: 1),
                              boxShadow: AppShadows.sm,
                            ),
                            child: Column(
                              children: [
                                // Date Selector Row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (_selectedFilter != 'tum')
                                      _buildDateArrowButton(Icons.chevron_left_rounded, () => _changeDate(-1)),
                                    const SizedBox(width: 14),
                                    Text(
                                      _getDateDisplayText(),
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.gray800,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    if (_selectedFilter != 'tum')
                                      _buildDateArrowButton(Icons.chevron_right_rounded, () => _changeDate(1)),
                                    const Spacer(),
                                    _buildDateArrowButton(Icons.refresh_rounded, _fetchFinancialData),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Main Income display: 0.00 ₺
                                Text(
                                  '${formatNumber.format(totalRevenue)} ₺',
                                  style: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Dönem Geliri',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: AppColors.gray500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Stats row: Satış, Ödenen, Bekleyen (Counts)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: [
                                    _buildStatsColumn(_salesCount.toString(), 'Satış'),
                                    _buildStatsColumn(_collectedCount.toString(), 'Ödenen'),
                                    _buildStatsColumn(pendingCount.toString(), 'Bekleyen'),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Kar / Zarar Summary Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isProfit ? AppColors.successLight : AppColors.dangerLight,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isProfit ? AppColors.success.withOpacity(0.3) : AppColors.danger.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Toplam Gelirler:',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.gray700),
                                    ),
                                    Text(
                                      '${formatNumber.format(totalRevenue)} ₺',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary700),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Toplam Giderler:',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.gray700),
                                    ),
                                    Text(
                                      '${formatNumber.format(totalExpenses)} ₺',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.dangerDark),
                                    ),
                                  ],
                                ),
                                const Divider(height: 16, thickness: 1),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isProfit ? 'Dönem Net Karı:' : 'Dönem Net Zararı:',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: isProfit ? AppColors.successDark : AppColors.dangerDark,
                                      ),
                                    ),
                                    Text(
                                      '${isProfit ? "+" : ""}${formatNumber.format(netProfitLoss)} ₺',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: isProfit ? AppColors.successDark : AppColors.dangerDark,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Section Header: Kategori Bazlı Kar Analizi
                          Row(
                            children: [
                              Text(
                                '📊 Kategori Bazlı Kar Analizi',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gray800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Categorized breakdown list
                          _buildCategoryCard(
                            categoryName: 'Süt Satışı',
                            salesCountText: '$_sutSalesCount satış',
                            revenueVal: _sutSalesTotal,
                            netProfitVal: _sutNetKar,
                          ),
                          _buildCategoryCard(
                            categoryName: 'Yem Satışı',
                            salesCountText: '$_yemSalesCount satış',
                            revenueVal: _yemSalesTotal,
                            netProfitVal: _yemSalesTotal,
                          ),
                          if (_otherRevenuesTotal > 0)
                            _buildCategoryCard(
                              categoryName: 'Diğer Gelirler',
                              salesCountText: '$_otherRevenuesCount satış',
                              revenueVal: _otherRevenuesTotal,
                              netProfitVal: _otherRevenuesTotal,
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filterKey;
        });
        _fetchFinancialData();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary600 : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary600 : AppColors.gray500,
          ),
        ),
      ),
    );
  }

  Widget _buildDateArrowButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.primary50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppColors.primary600,
          size: 18,
        ),
      ),
    );
  }

  Widget _buildStatsColumn(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.gray800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: AppColors.gray400,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryCard({
    required String categoryName,
    required String salesCountText,
    required double revenueVal,
    required double netProfitVal,
  }) {
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');
    final bool profitPositive = netProfitVal >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200, width: 1),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                categoryName,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.gray800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                salesCountText,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.gray400,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Satış: ${formatNumber.format(revenueVal)} ₺',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.gray600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Net Kar: ${profitPositive ? "+" : ""}${formatNumber.format(netProfitVal)} ₺',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: profitPositive ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
