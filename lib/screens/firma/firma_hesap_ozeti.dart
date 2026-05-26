import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class FirmaHesapOzetiScreen extends StatefulWidget {
  final String? producerName;

  const FirmaHesapOzetiScreen({super.key, this.producerName});

  @override
  State<FirmaHesapOzetiScreen> createState() => _FirmaHesapOzetiScreenState();
}

class _FirmaHesapOzetiScreenState extends State<FirmaHesapOzetiScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  late TabController _tabController;
  String? _selectedProducer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Haftalık, Aylık, Tümü
    _selectedProducer = widget.producerName;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTimeRange _getDateRangeForPeriod(int tabIndex) {
    final now = DateTime.now();
    if (tabIndex == 0) {
      // Haftalık (last 7 days)
      return DateTimeRange(
        start: now.subtract(const Duration(days: 7)),
        end: now,
      );
    } else if (tabIndex == 1) {
      // Aylık (last 30 days)
      return DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      );
    } else {
      // Tümü (all times)
      return DateTimeRange(
        start: DateTime(2020),
        end: now.add(const Duration(days: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
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

  Widget _buildLedgerDetails(String firmaName, String ureticiName) {
    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Scaffold(
      appBar: AppBar(
        title: Text(ureticiName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (widget.producerName != null) {
              // Direct navigation from list -> go back to ureticiler
              context.go('/firma/ureticiler');
            } else {
              // Went through general lists -> reset select state
              setState(() {
                _selectedProducer = null;
              });
            }
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary600,
          labelColor: AppColors.primary600,
          unselectedLabelColor: AppColors.gray500,
          tabs: const [
            Tab(text: 'Haftalık'),
            Tab(text: 'Aylık'),
            Tab(text: 'Tümü'),
          ],
          onTap: (idx) {
            setState(() {});
          },
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadProducerLedgerData(firmaName, ureticiName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Yükleme hatası: ${snapshot.error}'));
          }

          final data = snapshot.data ?? {};
          final allCollections = data['collections'] as List<QueryDocumentSnapshot>;
          final prices = data['prices'] as List<QueryDocumentSnapshot>;
          final tahsilatlar = data['tahsilatlar'] as List<QueryDocumentSnapshot>;
          final avanslar = data['avanslar'] as List<QueryDocumentSnapshot>;
          final kesintiler = data['kesintiler'] as List<QueryDocumentSnapshot>;
          final cezalar = data['cezalar'] as List<QueryDocumentSnapshot>;
          final satislar = data['satislar'] as List<QueryDocumentSnapshot>;
          final producerDoc = data['producerDoc'] as DocumentSnapshot?;

          String group = '';
          String bolge = '';
          if (producerDoc != null && producerDoc.exists) {
            final pData = producerDoc.data() as Map<String, dynamic>;
            group = pData['group'] ?? '';
            bolge = pData['bolge'] ?? '';
          }

          // Calculate overall ledger elements filtered by selected period tab
          final dateRange = _getDateRangeForPeriod(_tabController.index);

          // Filtering helper
          bool isInRange(DocumentSnapshot doc) {
            final data = doc.data() as Map<String, dynamic>?;
            if (data == null) return false;
            final ts = data['timestamp'] as Timestamp?;
            if (ts == null) return false;
            final date = ts.toDate();
            return date.isAfter(dateRange.start) && date.isBefore(dateRange.end);
          }

          final filteredCols = allCollections.where((c) => isInRange(c)).toList();
          final filteredTah = tahsilatlar.where((t) => isInRange(t)).toList();
          final filteredAv = avanslar.where((a) => isInRange(a)).toList();
          final filteredKes = kesintiler.where((k) => isInRange(k)).toList();
          final filteredCez = cezalar.where((cz) => isInRange(cz)).toList();
          final filteredSat = satislar.where((s) => isInRange(s)).toList();

          // Calculate Gross Milk Receivable
          double toplamLitre = 0.0;
          double milkVal = 0.0;
          final priceList = prices.map((d) => d.data() as Map<String, dynamic>).toList();

          for (var doc in filteredCols) {
            final data = doc.data() as Map<String, dynamic>;
            final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
            toplamLitre += m;
            final String rawType = data['tip'] ?? 'Soğuk Süt';
            final String priceKey = FirestoreService().mapMilkTypeToPriceKey(rawType);
            final double price = FirestoreService().resolveMilkPrice(
              prices: priceList,
              producerName: ureticiName,
              bolge: bolge,
              group: group,
              type: priceKey,
            );
            milkVal += m * price;
          }

          // Sum others
          double totalPayments = filteredTah.fold(0.0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + ((data['tutar'] as num?)?.toDouble() ?? 0.0);
          });
          double totalAvans = filteredAv.where((a) {
            final data = a.data() as Map<String, dynamic>;
            return data['durum'] == 'aktif';
          }).fold(0.0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + ((data['tutar'] as num?)?.toDouble() ?? 0.0);
          });
          double totalKesinti = filteredKes.where((k) {
            final data = k.data() as Map<String, dynamic>;
            return data['durum'] == 'aktif';
          }).fold(0.0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + ((data['tutar'] as num?)?.toDouble() ?? 0.0);
          });
          double totalCeza = 0.0;
          for (var doc in filteredCez) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['durum'] == 'aktif') {
              if (data['tip'] == 'oransal') {
                final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
                totalCeza += milkVal * (oran / 100.0);
              } else {
                totalCeza += (data['tutar'] as num?)?.toDouble() ?? 0.0;
              }
            }
          }
          double totalSales = filteredSat.fold(0.0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            return sum + ((data['tutar'] as num?)?.toDouble() ?? 0.0);
          });

          // Net balance
          final double totalDebts = totalSales + totalAvans + totalKesinti + totalCeza + totalPayments;
          final double netReceivable = milkVal - totalDebts;

          // Merge all transactions for sorting and display
          final List<Map<String, dynamic>> txList = [];

          for (var doc in filteredCols) {
            final data = doc.data() as Map<String, dynamic>;
            final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
            final String rawType = data['tip'] ?? 'Soğuk Süt';
            final String priceKey = FirestoreService().mapMilkTypeToPriceKey(rawType);
            final double price = FirestoreService().resolveMilkPrice(
              prices: priceList,
              producerName: ureticiName,
              bolge: bolge,
              group: group,
              type: priceKey,
            );
            final double val = m * price;
            final Timestamp? ts = data['timestamp'] as Timestamp?;
            txList.add({
              'ts': ts?.toDate() ?? DateTime.now(),
              'title': 'Süt Teslimi ($rawType)',
              'subtitle': '${m.toStringAsFixed(1)} LT x ${price.toStringAsFixed(2)} ₺',
              'amount': val,
              'isPositive': true,
              'icon': Icons.water_drop_rounded,
              'color': AppColors.primary600,
            });
          }

          for (var doc in filteredTah) {
            final data = doc.data() as Map<String, dynamic>;
            final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            final Timestamp? ts = data['timestamp'] as Timestamp?;
            txList.add({
              'ts': ts?.toDate() ?? DateTime.now(),
              'title': 'Ödeme Alındı (${data['odemeYontemi'] ?? 'Nakit'})',
              'subtitle': data['aciklama'] ?? 'Hesap kapatma ödemesi',
              'amount': tutar,
              'isPositive': false,
              'icon': Icons.payments_rounded,
              'color': AppColors.success,
            });
          }

          for (var doc in filteredAv) {
            final data = doc.data() as Map<String, dynamic>;
            final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            final Timestamp? ts = data['timestamp'] as Timestamp?;
            final state = data['durum'] ?? 'aktif';
            txList.add({
              'ts': ts?.toDate() ?? DateTime.now(),
              'title': 'Avans Ödemesi ($state)',
              'subtitle': data['aciklama'] ?? '',
              'amount': tutar,
              'isPositive': false,
              'icon': Icons.monetization_on_rounded,
              'color': AppColors.warning,
            });
          }

          for (var doc in filteredSat) {
            final data = doc.data() as Map<String, dynamic>;
            final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            final Timestamp? ts = data['timestamp'] as Timestamp?;
            txList.add({
              'ts': ts?.toDate() ?? DateTime.now(),
              'title': 'Ürün Satışı (${data['urun'] ?? 'Yem'})',
              'subtitle': '${data['miktar'] ?? 1} adet/kg',
              'amount': tutar,
              'isPositive': false,
              'icon': Icons.shopping_basket_rounded,
              'color': AppColors.danger,
            });
          }

          for (var doc in filteredKes) {
            final data = doc.data() as Map<String, dynamic>;
            final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            final Timestamp? ts = data['timestamp'] as Timestamp?;
            txList.add({
              'ts': ts?.toDate() ?? DateTime.now(),
              'title': 'Kesinti Uygulandı',
              'subtitle': data['aciklama'] ?? '',
              'amount': tutar,
              'isPositive': false,
              'icon': Icons.content_cut_rounded,
              'color': AppColors.gray600,
            });
          }

          for (var doc in filteredCez) {
            final data = doc.data() as Map<String, dynamic>;
            double val = 0.0;
            if (data['tip'] == 'oransal') {
              final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
              val = milkVal * (oran / 100.0);
            } else {
              val = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            }
            final Timestamp? ts = data['timestamp'] as Timestamp?;
            txList.add({
              'ts': ts?.toDate() ?? DateTime.now(),
              'title': 'Ceza Kesildi',
              'subtitle': data['aciklama'] ?? '',
              'amount': val,
              'isPositive': false,
              'icon': Icons.gavel_rounded,
              'color': Colors.red,
            });
          }

          // Sort txList by date descending
          txList.sort((a, b) => b['ts'].compareTo(a['ts']));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Cards
              StatsGrid(
                children: [
                  StatCard(
                    icon: Icons.water_drop_rounded,
                    value: '${toplamLitre.toStringAsFixed(0)} LT',
                    label: 'Toplam Süt Alımı',
                    color: AppColors.primary600,
                  ),
                  StatCard(
                    icon: Icons.monetization_on_rounded,
                    value: formatCurrency.format(milkVal),
                    label: 'Süt Bedeli (Alacak)',
                    color: AppColors.success,
                  ),
                  StatCard(
                    icon: Icons.outbox_rounded,
                    value: formatCurrency.format(totalDebts),
                    label: 'Borç / Ödemeler',
                    color: AppColors.danger,
                  ),
                  StatCard(
                    icon: Icons.account_balance_wallet_rounded,
                    value: formatCurrency.format(netReceivable),
                    label: 'Net Kalan Bakiye',
                    color: netReceivable >= 0 ? AppColors.primary600 : AppColors.danger,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              SectionTitle(title: 'Hesap Hareketleri'),

              if (txList.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text('Bu dönemde hesap hareketi bulunmuyor.', style: GoogleFonts.inter(color: AppColors.gray500)),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: txList.length,
                  itemBuilder: (context, index) {
                    final tx = txList[index];
                    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(tx['ts']);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: AppShadows.sm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: tx['color'].withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(tx['icon'], color: tx['color'], size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(tx['title'], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                if (tx['subtitle'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(tx['subtitle'], style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                                ],
                                const SizedBox(height: 2),
                                Text(dateStr, style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400)),
                              ],
                            ),
                          ),
                          Text(
                            '${tx['isPositive'] ? '+' : '-'}${formatCurrency.format(tx['amount'])}',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: tx['isPositive'] ? AppColors.success : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _loadProducerLedgerData(String firmaName, String ureticiName) async {
    final futures = await Future.wait([
      _db.collection('toplamalar').where('firma', isEqualTo: firmaName).where('u', isEqualTo: ureticiName).get(),
      _db.collection('sut_fiyatlari').where('firma', isEqualTo: firmaName).get(),
      _db.collection('tahsilatlar').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).get(),
      _db.collection('avanslar').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).get(),
      _db.collection('kesintiler').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).get(),
      _db.collection('cezalar').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).get(),
      _db.collection('satislar').where('firma', isEqualTo: firmaName).where('uretici', isEqualTo: ureticiName).get(),
      _db.collection('ureticiler').where('firmalar', arrayContains: firmaName).where('name', isEqualTo: ureticiName).limit(1).get(),
    ]);

    return {
      'collections': futures[0].docs,
      'prices': futures[1].docs,
      'tahsilatlar': futures[2].docs,
      'avanslar': futures[3].docs,
      'kesintiler': futures[4].docs,
      'cezalar': futures[5].docs,
      'satislar': futures[6].docs,
      'producerDoc': futures[7].docs.isNotEmpty ? futures[7].docs.first : null,
    };
  }
}
