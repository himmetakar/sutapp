import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';
import '../../services/firestore_service.dart';

class UrunSiparisleriScreen extends StatefulWidget {
  const UrunSiparisleriScreen({super.key});

  @override
  State<UrunSiparisleriScreen> createState() => _UrunSiparisleriScreenState();
}

class _UrunSiparisleriScreenState extends State<UrunSiparisleriScreen> {
  String _selectedPeriod = 'all'; // today, week, month, all
  DateTime _currentDate = DateTime.now();

  bool _isToday(DateTime date) {
    final now = _currentDate;
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isThisWeek(DateTime date) {
    final now = _currentDate;
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    
    // Normalize times
    final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    final end = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day, 23, 59, 59);
    return date.isAfter(start.subtract(const Duration(seconds: 1))) && 
           date.isBefore(end.add(const Duration(seconds: 1)));
  }

  bool _isThisMonth(DateTime date) {
    final now = _currentDate;
    return date.year == now.year && date.month == now.month;
  }

  DateTime? _getDocDate(dynamic field) {
    if (field == null) return null;
    if (field is Timestamp) return field.toDate();
    if (field is DateTime) return field;
    if (field is String) return DateTime.tryParse(field);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('urunler_siparisler')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Hata oluştu: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red)),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawDocs = (snapshot.data?.docs ?? []).toList();
          
          // Sort rawDocs by timestamp descending
          rawDocs.sort((a, b) {
            final aTime = _getDocDate((a.data() as Map)['timestamp']);
            final bTime = _getDocDate((b.data() as Map)['timestamp']);
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return -1;
            if (bTime == null) return 1;
            return bTime.compareTo(aTime);
          });

          // Filter docs by period
          final docs = rawDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = _getDocDate(data['timestamp']);
            if (timestamp == null) return _selectedPeriod == 'all'; // fallback

            switch (_selectedPeriod) {
              case 'today':
                return _isToday(timestamp);
              case 'week':
                return _isThisWeek(timestamp);
              case 'month':
                return _isThisMonth(timestamp);
              case 'all':
              default:
                return true;
            }
          }).toList();

          // Calculate period stats
          int totalOrders = docs.length;
          int pendingOrders = docs.where((doc) => doc['durum'] == 'Bekliyor').length;
          int approvedOrders = docs.where((doc) => doc['durum'] == 'Onaylandı' || doc['durum'] == 'Teslimatta').length;
          int deliveredOrders = docs.where((doc) => doc['durum'] == 'Teslim Edildi').length;
          double totalCiro = docs.where((doc) => doc['durum'] == 'Teslim Edildi').fold(0.0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            final double val = (data['toplam'] as num?)?.toDouble() ?? 0.0;
            return sum + val;
          });

          return Column(
            children: [
              // Period Filter Tabs Bar
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    _buildPeriodTab('Tümü', 'all'),
                    const SizedBox(width: 8),
                    _buildPeriodTab('Bugün', 'today'),
                    const SizedBox(width: 8),
                    _buildPeriodTab('Bu Hafta', 'week'),
                    const SizedBox(width: 8),
                    _buildPeriodTab('Bu Ay', 'month'),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Date slider for custom dates if not "all"
              if (_selectedPeriod != 'all') _buildDateNavigatorBar(),

              // Quick Statistics Box
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.gray50,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatBox(totalOrders.toString(), 'Toplam Sipariş', Colors.blue),
                        _buildStatBox(pendingOrders.toString(), 'Bekleyen', Colors.orange),
                        _buildStatBox(approvedOrders.toString(), 'Hazırlanan', Colors.purple),
                        _buildStatBox(deliveredOrders.toString(), 'Teslim Edilen', Colors.green),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Teslim Edilen Toplam Tutar:', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray600)),
                          Text('${NumberFormat('#,##0.00', 'tr_TR').format(totalCiro)} ₺', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.success)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Orders List
              Expanded(
                child: docs.isEmpty
                    ? Center(
                        child: Text(
                          'Filtreye uygun sipariş bulunamadı.',
                          style: GoogleFonts.inter(color: AppColors.gray400),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        itemBuilder: (context, idx) {
                          final doc = docs[idx];
                          final data = doc.data() as Map<String, dynamic>;
                          final uretici = data['uretici'] ?? 'Üretici';
                          final urun = data['urun'] ?? 'Ürün';
                          final miktar = (data['miktar'] as num?)?.toDouble() ?? 1.0;
                          final birim = data['birim'] ?? 'Adet';
                          final birimFiyat = (data['birimFiyat'] as num?)?.toDouble() ?? 0.0;
                          final toplam = (data['toplam'] as num?)?.toDouble() ?? 0.0;
                          final durum = data['durum'] ?? 'Bekliyor';
                          final tarih = data['tarih'] ?? '';
                          final saat = data['saat'] ?? '';
                          final orderId = data['id'] ?? '';

                          Color statusColor = Colors.orange;
                          if (durum == 'Onaylandı') statusColor = Colors.blue;
                          if (durum == 'Teslimatta') statusColor = Colors.purple;
                          if (durum == 'Teslim Edildi') statusColor = Colors.green;
                          if (durum == 'İptal') statusColor = Colors.red;

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppColors.gray200),
                            ),
                            color: Colors.white,
                            child: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(Icons.person_rounded, size: 18, color: AppColors.gray500),
                                          const SizedBox(width: 6),
                                          Text(
                                            uretici,
                                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.gray800),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          durum,
                                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('Sipariş $orderId • $tarih $saat', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                                  const Divider(height: 20),
                                  ...(() {
                                    final List<Map<String, dynamic>> itemsList = data.containsKey('kalemler') && data['kalemler'] is List
                                        ? List<Map<String, dynamic>>.from((data['kalemler'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
                                        : [
                                            {
                                              'urun': urun,
                                              'miktar': miktar,
                                              'birim': birim,
                                              'birimFiyat': birimFiyat,
                                              'toplam': toplam,
                                            }
                                          ];
                                    return itemsList.map((item) {
                                      final String uName = item['urun'] ?? '';
                                      final double qty = (item['miktar'] as num?)?.toDouble() ?? 1.0;
                                      final String unit = item['birim'] ?? 'Adet';
                                      final double price = (item['birimFiyat'] as num?)?.toDouble() ?? 0.0;
                                      final double totalItem = (item['toplam'] as num?)?.toDouble() ?? 0.0;

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 6.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '$uName (${qty.toStringAsFixed(1)} $unit)',
                                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.gray800),
                                              ),
                                            ),
                                            Text(
                                              '${totalItem.toStringAsFixed(2)} ₺',
                                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList();
                                  })(),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Toplam:',
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray700),
                                      ),
                                      Text(
                                        '${toplam.toStringAsFixed(2)} ₺',
                                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),

                                  // Actions row
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        if (durum == 'Bekliyor')
                                          _buildActionButton('Onayla', Colors.green, () async {
                                            await doc.reference.update({'durum': 'Onaylandı'});
                                            await FirestoreService().sendNotification(
                                              recipientName: uretici,
                                              role: 'uretici',
                                              baslik: 'Siparişiniz Hazırlandı',
                                              icerik: '$orderId nolu siparişiniz firma tarafından hazırlandı.',
                                              type: 'siparis',
                                            );
                                            await _notifyDriversForProducer(
                                              currentFirmaName,
                                              uretici,
                                              orderId,
                                            );
                                          }),
                                        if (durum == 'Onaylandı')
                                          _buildActionButton('Teslimatta Yap', Colors.purple, () async {
                                            await doc.reference.update({'durum': 'Teslimatta'});
                                            await FirestoreService().sendNotification(
                                              recipientName: uretici,
                                              role: 'uretici',
                                              baslik: 'Siparişiniz Yola Çıktı',
                                              icerik: '$orderId nolu siparişiniz dağıtıma çıkmıştır.',
                                              type: 'siparis',
                                            );
                                            await _notifyDriversForProducer(
                                              currentFirmaName,
                                              uretici,
                                              orderId,
                                              customBaslik: 'Sipariş Yola Çıktı',
                                              customIcerik: '$uretici üreticisine ait $orderId nolu sipariş yola çıktı.',
                                            );
                                          }),
                                        if (durum == 'Teslimatta')
                                          _buildActionButton('Teslim Et', Colors.green, () async {
                                            await doc.reference.update({'durum': 'Teslim Edildi'});
                                            
                                            await FirestoreService().sendNotification(
                                              recipientName: uretici,
                                              role: 'uretici',
                                              baslik: 'Siparişiniz Teslim Edildi',
                                              icerik: '$orderId nolu siparişiniz başarıyla teslim edilmiştir.',
                                              type: 'siparis',
                                            );

                                            await _notifyDriversForProducer(
                                              currentFirmaName,
                                              uretici,
                                              orderId,
                                              customBaslik: 'Sipariş Teslim Edildi',
                                              customIcerik: '$uretici üreticisine ait $orderId nolu sipariş teslim edildi.',
                                            );
                                            
                                            final List<Map<String, dynamic>> itemsList = data.containsKey('kalemler') && data['kalemler'] is List
                                                ? List<Map<String, dynamic>>.from((data['kalemler'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
                                                : [
                                                    {
                                                      'urun': urun,
                                                      'miktar': miktar,
                                                      'birim': birim,
                                                      'birimFiyat': birimFiyat,
                                                      'toplam': toplam,
                                                    }
                                                  ];

                                            for (var item in itemsList) {
                                              final String uName = item['urun'] ?? '';
                                              final double qty = (item['miktar'] as num?)?.toDouble() ?? 1.0;
                                              final double totalItem = (item['toplam'] as num?)?.toDouble() ?? 0.0;

                                              // Subtract stock
                                              final urunQuery = await FirebaseFirestore.instance
                                                  .collection('urunler')
                                                  .where('ad', isEqualTo: uName)
                                                  .where('firma', isEqualTo: currentFirmaName)
                                                  .limit(1)
                                                  .get();
                                              if (urunQuery.docs.isNotEmpty) {
                                                final uDoc = urunQuery.docs.first;
                                                final double currentStock = (uDoc['stok'] as num?)?.toDouble() ?? 0.0;
                                                final double minStok = (uDoc.data() as Map<String, dynamic>)['minStok']?.toDouble() ?? 10.0;
                                                final String birimVal = (uDoc.data() as Map<String, dynamic>)['birim'] ?? 'Adet';
                                                final double newStock = (currentStock - qty).clamp(0.0, double.infinity);
                                                await uDoc.reference.update({'stok': newStock});
                                                
                                                if (newStock <= minStok) {
                                                  await FirestoreService().sendNotification(
                                                    recipientName: currentFirmaName,
                                                    role: 'firma',
                                                    baslik: 'Kritik Stok Uyarısı',
                                                    icerik: '$uName ürünü kritik stok limitinin altına düştü! Güncel Stok: ${newStock.toStringAsFixed(0)} $birimVal',
                                                    type: 'stok',
                                                  );
                                                }
                                              }

                                              // Record payment deduction
                                              await FirebaseFirestore.instance.collection('kesintiler').add({
                                                'uretici': uretici,
                                                'tutar': totalItem,
                                                'kesintiTuru': '$uName Alımı',
                                                'durum': 'aktif',
                                                'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                                                'timestamp': FieldValue.serverTimestamp(),
                                                'firma': currentFirmaName,
                                              });
                                            }
                                          }),
                                        if (durum != 'Teslim Edildi' && durum != 'İptal')
                                          _buildActionButton('İptal', Colors.orange, () async {
                                            await doc.reference.update({'durum': 'İptal'});
                                            await FirestoreService().sendNotification(
                                              recipientName: uretici,
                                              role: 'uretici',
                                              baslik: 'Siparişiniz İptal Edildi',
                                              icerik: '$orderId nolu siparişiniz firma tarafından iptal edilmiştir.',
                                              type: 'siparis',
                                            );
                                            await _notifyDriversForProducer(
                                              currentFirmaName,
                                              uretici,
                                              orderId,
                                              customBaslik: 'Sipariş İptal Edildi',
                                              customIcerik: '$uretici üreticisine ait $orderId nolu sipariş iptal edildi.',
                                            );
                                          }),
                                        _buildActionButton('Sil', Colors.red, () async {
                                          final confirm = await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              title: const Text('Siparişi Sil'),
                                              content: const Text('Bu sipariş kaydını tamamen silmek istiyor musunuz?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                                                ElevatedButton(
                                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                                  onPressed: () => Navigator.pop(ctx, true),
                                                  child: const Text('Sil'),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true) {
                                            await doc.reference.delete();
                                          }
                                        }),
                                      ],
                                    ),
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
    );
  }

  Widget _buildPeriodTab(String label, String code) {
    final isSelected = _selectedPeriod == code;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPeriod = code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary50 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primary500 : AppColors.gray200),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? AppColors.primary700 : AppColors.gray600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateNavigatorBar() {
    String dateDisplay = '';
    if (_selectedPeriod == 'today') {
      dateDisplay = DateFormat('dd MMMM yyyy', 'tr_TR').format(_currentDate);
    } else if (_selectedPeriod == 'week') {
      final startOfWeek = _currentDate.subtract(Duration(days: _currentDate.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      dateDisplay = '${DateFormat('dd MMM', 'tr_TR').format(startOfWeek)} - ${DateFormat('dd MMM yyyy', 'tr_TR').format(endOfWeek)}';
    } else if (_selectedPeriod == 'month') {
      dateDisplay = DateFormat('MMMM yyyy', 'tr_TR').format(_currentDate);
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded, color: AppColors.gray600),
            onPressed: () {
              setState(() {
                if (_selectedPeriod == 'today') {
                  _currentDate = _currentDate.subtract(const Duration(days: 1));
                } else if (_selectedPeriod == 'week') {
                  _currentDate = _currentDate.subtract(const Duration(days: 7));
                } else if (_selectedPeriod == 'month') {
                  _currentDate = DateTime(_currentDate.year, _currentDate.month - 1, 1);
                }
              });
            },
          ),
          Text(
            dateDisplay,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gray800),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded, color: AppColors.gray600),
            onPressed: () {
              setState(() {
                if (_selectedPeriod == 'today') {
                  _currentDate = _currentDate.add(const Duration(days: 1));
                } else if (_selectedPeriod == 'week') {
                  _currentDate = _currentDate.add(const Duration(days: 7));
                } else if (_selectedPeriod == 'month') {
                  _currentDate = DateTime(_currentDate.year, _currentDate.month + 1, 1);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String count, String label, Color color) {
    return Column(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              count,
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(60, 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _notifyDriversForProducer(String firma, String ureticiName, String orderId, {String? customBaslik, String? customIcerik}) async {
    try {
      final prodSnap = await FirebaseFirestore.instance
          .collection('ureticiler')
          .where('name', isEqualTo: ureticiName)
          .limit(1)
          .get();
      
      if (prodSnap.docs.isEmpty) return;
      final pData = prodSnap.docs.first.data();
      final String group = pData['group'] ?? '';
      final String bolge = pData['bolge'] ?? '';
      final String birlik = pData['birlik'] ?? 'Yok';

      final atamalarSnap = await FirebaseFirestore.instance
          .collection('toplayici_atamalari')
          .where('firma', isEqualTo: firma)
          .get();

      final Set<String> driversToNotify = {};
      for (var doc in atamalarSnap.docs) {
        final data = doc.data();
        final hTip = data['hedefTip'];
        final hAd = data['hedefAd'];
        final driver = data['toplayici'] as String? ?? '';

        if (driver.isEmpty) continue;

        if (hTip == 'uretici' && hAd == ureticiName) {
          driversToNotify.add(driver);
        } else if (hTip == 'grup' && group.isNotEmpty && hAd == group) {
          driversToNotify.add(driver);
        } else if ((hTip == 'birlik' || hTip == 'bolge') &&
            ((bolge.isNotEmpty && hAd == bolge) || (birlik.isNotEmpty && birlik != 'Yok' && hAd == birlik))) {
          driversToNotify.add(driver);
        }
      }

      for (var driverName in driversToNotify) {
        await FirestoreService().sendNotification(
          recipientName: driverName,
          role: 'surucu',
          baslik: customBaslik ?? 'Yeni Dağıtım Görevi',
          icerik: customIcerik ?? '$ureticiName üreticisine ait $orderId nolu sipariş hazırlandı, teslim alabilirsiniz.',
          type: 'siparis',
        );
      }
    } catch (e) {
      print('Error notifying drivers: $e');
    }
  }
}
