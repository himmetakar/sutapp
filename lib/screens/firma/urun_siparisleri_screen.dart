import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/firma/satislar/ekle'),
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded, size: 22),
        label: Text('Yeni Sipariş', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<QuerySnapshot>(
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
              // Sipariş Yönetimi Header Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: AppColors.gray200)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sipariş Yönetimi',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gray900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Üretici ürün siparişlerini oluşturun ve yönetin',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.gray400,
                      ),
                    ),
                  ],
                ),
              ),
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
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final bool isWeb = constraints.maxWidth > 700;

                          Widget buildOrderCard(QueryDocumentSnapshot doc) {
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
                              margin: isWeb ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: AppColors.gray200),
                              ),
                              color: Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(14.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              const Icon(Icons.person_rounded, size: 18, color: AppColors.gray500),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  uretici,
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.gray800),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: statusColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            durum,
                                            style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: statusColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('Sipariş $orderId • $tarih $saat', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.gray400)),
                                    const Divider(height: 16),
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Column(
                                          children: (() {
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
                                              final double totalItem = (item['toplam'] as num?)?.toDouble() ?? 0.0;

                                              return Padding(
                                                padding: const EdgeInsets.only(bottom: 4.0),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '$uName (${qty.toStringAsFixed(1)} $unit)',
                                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.gray800),
                                                        maxLines: 1,
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    Text(
                                                      '${totalItem.toStringAsFixed(2)} ₺',
                                                      style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.gray700),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }).toList();
                                          })(),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Toplam:',
                                          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.gray700),
                                        ),
                                        Text(
                                          '${toplam.toStringAsFixed(2)} ₺',
                                          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppColors.primary600),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

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
                                              
                                              final isDirectSale = data['isDirectSale'] as bool? ?? false;
                                              if (!isDirectSale) {
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

                                                  // Record payment deduction — siparişin kendi tarihini kullan
                                                  DateTime kesintiTarih = DateTime.now();
                                                  final rawTs = data['timestamp'];
                                                  if (rawTs is Timestamp) {
                                                    kesintiTarih = rawTs.toDate();
                                                  } else if (data['tarih'] != null) {
                                                    try {
                                                      kesintiTarih = DateFormat('dd MMMM yyyy', 'tr_TR').parse(data['tarih'].toString());
                                                    } catch (_) {
                                                      try { kesintiTarih = DateFormat('dd.MM.yyyy').parse(data['tarih'].toString()); } catch (_) {}
                                                    }
                                                  }
                                                  await FirebaseFirestore.instance.collection('kesintiler').add({
                                                    'uretici': uretici,
                                                    'tutar': totalItem,
                                                    'kesintiTuru': '$uName Alımı',
                                                    'durum': 'aktif',
                                                    'tarih': DateFormat('dd.MM.yyyy').format(kesintiTarih),
                                                    'timestamp': Timestamp.fromDate(kesintiTarih),
                                                    'firma': currentFirmaName,
                                                    'miktar': qty,
                                                    'birimFiyat': item['birimFiyat'] ?? (item['fiyat'] ?? (qty > 0 ? totalItem / qty : totalItem)),
                                                  });
                                                }
                                              }
                                            }),
                                          _buildActionButton('Düzenle', Colors.blue, () {
                                              _showEditOrderDialog(context, doc, currentFirmaName);
                                            }),
                                          if (durum != 'Teslim Edildi' && durum != 'İptal')
                                            _buildActionButton('İptal', Colors.orange, () async {
                                              final isDirectSale = data['isDirectSale'] as bool? ?? false;
                                              if (isDirectSale) {
                                                // Delete corresponding satislar record
                                                final satisQuery = await FirebaseFirestore.instance
                                                    .collection('satislar')
                                                    .where('orderId', isEqualTo: orderId)
                                                    .get();
                                                for (var sDoc in satisQuery.docs) {
                                                  await sDoc.reference.delete();
                                                }
                                                
                                                // Increment stock back
                                                final List<Map<String, dynamic>> itemsList = data.containsKey('kalemler') && data['kalemler'] is List
                                                    ? List<Map<String, dynamic>>.from((data['kalemler'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
                                                    : [
                                                        {
                                                          'urun': urun,
                                                          'miktar': miktar,
                                                        }
                                                      ];
                                                for (var item in itemsList) {
                                                  final String uName = item['urun'] ?? '';
                                                  final double qty = (item['miktar'] as num?)?.toDouble() ?? 1.0;
                                                  if (uName.isNotEmpty && qty > 0) {
                                                    final urunSnap = await FirebaseFirestore.instance
                                                        .collection('urunler')
                                                        .where('firma', isEqualTo: currentFirmaName)
                                                        .where('ad', isEqualTo: uName)
                                                        .limit(1)
                                                        .get();
                                                    if (urunSnap.docs.isNotEmpty) {
                                                      await urunSnap.docs.first.reference.update({
                                                        'stok': FieldValue.increment(qty),
                                                      });
                                                    }
                                                  }
                                                }
                                              }

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
                                              final isDirectSale = data['isDirectSale'] as bool? ?? false;
                                              if (isDirectSale) {
                                                // Delete corresponding satislar record
                                                final satisQuery = await FirebaseFirestore.instance
                                                    .collection('satislar')
                                                    .where('orderId', isEqualTo: orderId)
                                                    .get();
                                                for (var sDoc in satisQuery.docs) {
                                                  await sDoc.reference.delete();
                                                }
                                                
                                                // Increment stock back (only if durum wasn't already Teslim Edildi or Iptal which would have handled stock)
                                                if (durum != 'Teslim Edildi' && durum != 'İptal') {
                                                  final List<Map<String, dynamic>> itemsList = data.containsKey('kalemler') && data['kalemler'] is List
                                                      ? List<Map<String, dynamic>>.from((data['kalemler'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
                                                      : [
                                                          {
                                                            'urun': urun,
                                                            'miktar': miktar,
                                                          }
                                                        ];
                                                  for (var item in itemsList) {
                                                    final String uName = item['urun'] ?? '';
                                                    final double qty = (item['miktar'] as num?)?.toDouble() ?? 1.0;
                                                    if (uName.isNotEmpty && qty > 0) {
                                                      final urunSnap = await FirebaseFirestore.instance
                                                          .collection('urunler')
                                                          .where('firma', isEqualTo: currentFirmaName)
                                                          .where('ad', isEqualTo: uName)
                                                          .limit(1)
                                                          .get();
                                                      if (urunSnap.docs.isNotEmpty) {
                                                        await urunSnap.docs.first.reference.update({
                                                          'stok': FieldValue.increment(qty),
                                                        });
                                                      }
                                                    }
                                                  }
                                                }
                                              }
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
                          }

                          if (isWeb) {
                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 260,
                              ),
                              itemCount: docs.length,
                              itemBuilder: (context, idx) {
                                return buildOrderCard(docs[idx]);
                              },
                            );
                          }

                          return ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: docs.length,
                            itemBuilder: (context, idx) {
                              return buildOrderCard(docs[idx]);
                            },
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
          ),
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

  Future<void> _showEditOrderDialog(BuildContext context, DocumentSnapshot doc, String currentFirmaName) async {
    // Show a loading indicator
    BuildContext? dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        dialogContext = ctx;
        return const Center(child: CircularProgressIndicator());
      },
    );

    // Fetch products
    List<Map<String, dynamic>> products = [];
    try {
      final snap = await FirebaseFirestore.instance
          .collection('urunler')
          .where('firma', isEqualTo: currentFirmaName)
          .get();
      for (var d in snap.docs) {
        final pData = d.data();
        products.add({
          'ad': pData['ad'] ?? '',
          'birim': pData['birim'] ?? 'Adet',
          'fiyat': (pData['fiyat'] as num?)?.toDouble() ?? 0.0,
        });
      }
    } catch (e) {
      print('Error fetching products: $e');
    }

    // Dismiss loading indicator
    if (dialogContext != null && dialogContext!.mounted) {
      Navigator.pop(dialogContext!);
    }

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firmaya ait ürün bulunamadı.'), backgroundColor: AppColors.danger),
      );
      return;
    }

    final data = doc.data() as Map<String, dynamic>;
    DateTime selectedOrderDate = DateTime.now();
    if (data['tarih'] != null) {
      try {
        selectedOrderDate = DateFormat('dd MMMM yyyy', 'tr_TR').parse(data['tarih'].toString());
      } catch (_) {
        try {
          selectedOrderDate = DateFormat('dd.MM.yyyy').parse(data['tarih'].toString());
        } catch (_) {}
      }
    } else if (data['timestamp'] != null) {
      selectedOrderDate = (data['timestamp'] as Timestamp).toDate();
    }

    final List<Map<String, dynamic>> initialItems = data.containsKey('kalemler') && data['kalemler'] is List
        ? List<Map<String, dynamic>>.from((data['kalemler'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
        : [
            {
              'urun': data['urun'] ?? '',
              'miktar': (data['miktar'] as num?)?.toDouble() ?? 1.0,
              'birim': data['birim'] ?? 'Adet',
              'birimFiyat': (data['birimFiyat'] as num?)?.toDouble() ?? 0.0,
              'toplam': (data['toplam'] as num?)?.toDouble() ?? 0.0,
            }
          ];

    List<Map<String, dynamic>> orderItems = List.from(initialItems);
    Map<String, dynamic>? selectedProduct = products.first;
    final addQtyCtrl = TextEditingController(text: '1');

    // Create controllers for each item quantity in orderItems
    final List<TextEditingController> qtyControllers = orderItems.map((item) {
      final qty = (item['miktar'] as num?)?.toDouble() ?? 1.0;
      return TextEditingController(text: qty % 1 == 0 ? qty.toInt().toString() : qty.toString());
    }).toList();

    // Create controllers for unit prices to allow editing prices as well
    final List<TextEditingController> priceControllers = orderItems.map((item) {
      final price = (item['birimFiyat'] as num?)?.toDouble() ?? 0.0;
      return TextEditingController(text: price.toStringAsFixed(2));
    }).toList();

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double orderTotal = 0.0;
            for (int i = 0; i < orderItems.length; i++) {
              final double qty = double.tryParse(qtyControllers[i].text) ?? 0.0;
              final double price = double.tryParse(priceControllers[i].text) ?? 0.0;
              orderItems[i]['miktar'] = qty;
              orderItems[i]['birimFiyat'] = price;
              orderItems[i]['toplam'] = qty * price;
              orderTotal += qty * price;
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Siparişi Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () {
                    for (var c in qtyControllers) {
                      c.dispose();
                    }
                    for (var c in priceControllers) {
                      c.dispose();
                    }
                    addQtyCtrl.dispose();
                    Navigator.pop(ctx);
                  }),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sipariş kalemlerini, miktarlarını ve birim fiyatlarını güncelleyebilirsiniz.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),

                      // List of current items
                      Text('Sipariş Kalemleri', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: orderItems.length,
                        itemBuilder: (context, index) {
                          final item = orderItems[index];
                          final String uAd = item['urun'] ?? '';
                          final String unit = item['birim'] ?? 'Adet';
                          final double itemTotal = item['toplam'] ?? 0.0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        uAd,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: AppColors.gray800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 20),
                                      onPressed: () {
                                        setStateDialog(() {
                                          orderItems.removeAt(index);
                                          qtyControllers[index].dispose();
                                          qtyControllers.removeAt(index);
                                          priceControllers[index].dispose();
                                          priceControllers.removeAt(index);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: qtyControllers[index],
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Miktar ($unit)',
                                          labelStyle: GoogleFonts.inter(fontSize: 12),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onChanged: (_) {
                                          setStateDialog(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: priceControllers[index],
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Birim Fiyat (₺)',
                                          labelStyle: GoogleFonts.inter(fontSize: 12),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onChanged: (_) {
                                          setStateDialog(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Tutar',
                                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400),
                                        ),
                                        Text(
                                          '${itemTotal.toStringAsFixed(2)} ₺',
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.gray800,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const Divider(),
                      const SizedBox(height: 8),

                      // Add new item section
                      Text('Yeni Kalem Ekle', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.gray300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Map<String, dynamic>>(
                            value: selectedProduct,
                            isExpanded: true,
                            items: products.map((prod) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: prod,
                                child: Text('${prod['ad']} (${prod['fiyat'].toStringAsFixed(2)} ₺)', style: GoogleFonts.inter(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setStateDialog(() {
                                selectedProduct = val;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: addQtyCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Miktar',
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              final double? qty = double.tryParse(addQtyCtrl.text);
                              if (qty == null || qty <= 0 || selectedProduct == null) return;
                              
                              // Check if product already exists in orderItems
                              final String newUrunName = selectedProduct!['ad'];
                              int existingIdx = -1;
                              for (int i = 0; i < orderItems.length; i++) {
                                if (orderItems[i]['urun'] == newUrunName) {
                                  existingIdx = i;
                                  break;
                                }
                              }

                              setStateDialog(() {
                                if (existingIdx != -1) {
                                  // Update quantity in existing controller
                                  final double currentVal = double.tryParse(qtyControllers[existingIdx].text) ?? 0.0;
                                  final double newVal = currentVal + qty;
                                  qtyControllers[existingIdx].text = newVal % 1 == 0 ? newVal.toInt().toString() : newVal.toString();
                                } else {
                                  final double price = selectedProduct!['fiyat'] as double;
                                  orderItems.add({
                                    'urun': newUrunName,
                                    'miktar': qty,
                                    'birim': selectedProduct!['birim'],
                                    'birimFiyat': price,
                                    'toplam': qty * price,
                                  });
                                  qtyControllers.add(TextEditingController(text: qty % 1 == 0 ? qty.toInt().toString() : qty.toString()));
                                  priceControllers.add(TextEditingController(text: price.toStringAsFixed(2)));
                                }
                                addQtyCtrl.text = '1';
                              });
                            },
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Ekle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      // Tarih Seçici (Zorunlu)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.primary50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary200,
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedOrderDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              locale: const Locale('tr', 'TR'),
                            );
                            if (picked != null) {
                              setStateDialog(() {
                                selectedOrderDate = picked;
                              });
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.calendar_month_rounded,
                                  color: AppColors.primary600,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        'İşlem Tarihi (Zorunlu)',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gray500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        DateFormat('dd MMMM yyyy', 'tr_TR').format(selectedOrderDate),
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gray800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: AppColors.gray400,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const Divider(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Toplam Tutar:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.gray800)),
                          Text('${orderTotal.toStringAsFixed(2)} ₺', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (var c in qtyControllers) {
                      c.dispose();
                    }
                    for (var c in priceControllers) {
                      c.dispose();
                    }
                    addQtyCtrl.dispose();
                    Navigator.pop(ctx);
                  },
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: orderItems.isEmpty
                      ? null
                      : () async {
                          final updates = <String, dynamic>{
                            'kalemler': orderItems,
                            'toplam': orderTotal,
                            'tarih': DateFormat('dd MMMM yyyy', 'tr_TR').format(selectedOrderDate),
                            'timestamp': Timestamp.fromDate(selectedOrderDate),
                          };
                          if (orderItems.isNotEmpty) {
                            final first = orderItems.first;
                            updates['urun'] = first['urun'];
                            updates['miktar'] = first['miktar'];
                            updates['birim'] = first['birim'];
                            updates['birimFiyat'] = first['birimFiyat'];
                          }
                          await doc.reference.update(updates);

                          final orderId = data['id'] ?? '';
                          if (orderId.isNotEmpty) {
                            // Update satislar records to match edited order items
                            final satisQuery = await FirebaseFirestore.instance
                                .collection('satislar')
                                .where('orderId', isEqualTo: orderId)
                                .get();
                            
                            // Delete existing satislar records for this order
                            for (var sDoc in satisQuery.docs) {
                              await sDoc.reference.delete();
                            }
                            
                            // If it's a direct sale, recreate satislar records with updated quantities and prices
                            final isDirectSale = data['isDirectSale'] as bool? ?? false;
                            if (isDirectSale) {
                              final uretici = data['uretici'] ?? '';
                              for (var item in orderItems) {
                                final String product = item['urun'];
                                final double amount = item['miktar'];
                                final double totalVal = item['toplam'];
                                final double priceVal = item['birimFiyat'];
                                
                                await FirebaseFirestore.instance.collection('satislar').add({
                                  'uretici': uretici,
                                  'urun': product,
                                  'miktar': amount,
                                  'fiyat': priceVal,
                                  'tutar': totalVal,
                                  'tarih': DateFormat('dd.MM.yyyy').format(selectedOrderDate),
                                  'firma': currentFirmaName,
                                  'timestamp': Timestamp.fromDate(selectedOrderDate),
                                  'orderId': orderId,
                                });
                              }
                            }
                          }

                          for (var c in qtyControllers) {
                            c.dispose();
                          }
                          for (var c in priceControllers) {
                            c.dispose();
                          }
                          addQtyCtrl.dispose();
                          Navigator.pop(ctx);

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sipariş başarıyla güncellendi!'),
                              backgroundColor: AppColors.success,
                            ),
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
            );
          },
        );
      },
    );
  }

  Future<void> _showCreateOrderDialog(BuildContext context, String currentFirmaName) async {
    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    List<String> producers = [];
    List<Map<String, dynamic>> products = [];

    try {
      final producersSnap = await FirebaseFirestore.instance
          .collection('ureticiler')
          .where('firmalar', arrayContains: currentFirmaName)
          .get();
      producers = producersSnap.docs
          .map((doc) => (doc.data() as Map<String, dynamic>)['name'] as String? ?? '')
          .where((name) => name.isNotEmpty)
          .toList();
      producers.sort();

      final productsSnap = await FirebaseFirestore.instance
          .collection('urunler')
          .where('firma', isEqualTo: currentFirmaName)
          .get();
      products = productsSnap.docs.map((doc) {
        final pData = doc.data();
        return {
          'ad': pData['ad'] ?? '',
          'birim': pData['birim'] ?? 'Adet',
          'fiyat': (pData['fiyat'] as num?)?.toDouble() ?? 0.0,
        };
      }).toList();
    } catch (e) {
      print('Error loading data for order creation: $e');
    }

    // Dismiss loading indicator
    if (context.mounted) {
      Navigator.pop(context);
    }

    if (producers.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sipariş oluşturmak için kayıtlı üreticiniz bulunmalıdır.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (products.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Firmaya ait ürün bulunamadı.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // Map<productName, qty> for cart
    final Map<String, double> cartQty = {};
    String selectedProducer = producers.first;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            double orderTotal = 0.0;
            int totalItems = 0;
            for (var prod in products) {
              final String name = prod['ad'];
              final double qty = cartQty[name] ?? 0.0;
              if (qty > 0) {
                orderTotal += qty * (prod['fiyat'] as double);
                totalItems++;
              }
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.94,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gray300,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.shopping_cart_rounded, color: AppColors.primary600, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Yeni Sipariş Oluştur', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray900)),
                              Text('Ürünleri sepete ekleyin', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AppColors.gray500),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 16),

                  // Producer selector
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.primary200),
                        color: AppColors.primary50,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_rounded, color: AppColors.primary600, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: selectedProducer,
                                isExpanded: true,
                                dropdownColor: Colors.white,
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gray900),
                                items: producers.map((name) => DropdownMenuItem(
                                  value: name,
                                  child: Text(name, style: GoogleFonts.inter(fontSize: 14, color: AppColors.gray800)),
                                )).toList(),
                                onChanged: (val) {
                                  if (val != null) setSheet(() => selectedProducer = val);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Products list
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: products.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, idx) {
                        final prod = products[idx];
                        final String name = prod['ad'];
                        final double price = prod['fiyat'] as double;
                        final String birim = prod['birim'] as String;
                        final double qty = cartQty[name] ?? 0.0;
                        final bool inCart = qty > 0;

                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: inCart ? AppColors.primary50 : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: inCart ? AppColors.primary300 : AppColors.gray200,
                              width: inCart ? 1.5 : 1.0,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          child: Row(
                            children: [
                              Container(
                                width: 42, height: 42,
                                decoration: BoxDecoration(
                                  color: inCart ? AppColors.primary100 : AppColors.gray100,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.inventory_2_rounded,
                                  color: inCart ? AppColors.primary600 : AppColors.gray400,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gray900)),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${price.toStringAsFixed(2)} ₺ / $birim',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                                    ),
                                    if (inCart) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'Toplam: ${(qty * price).toStringAsFixed(2)} ₺',
                                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary600),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (inCart) ...[
                                    GestureDetector(
                                      onTap: () {
                                        setSheet(() {
                                          if (qty <= 1) {
                                            cartQty.remove(name);
                                          } else {
                                            cartQty[name] = qty - 1;
                                          }
                                        });
                                      },
                                      child: Container(
                                        width: 32, height: 32,
                                        decoration: BoxDecoration(
                                          color: qty <= 1 ? const Color(0xFFFFE5E5) : AppColors.primary100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          qty <= 1 ? Icons.delete_outline_rounded : Icons.remove_rounded,
                                          size: 16,
                                          color: qty <= 1 ? AppColors.danger : AppColors.primary700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(1),
                                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray900),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  GestureDetector(
                                    onTap: () {
                                      setSheet(() {
                                        cartQty[name] = qty + 1;
                                      });
                                    },
                                    child: Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary600,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
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

                  // Cart Summary Footer
                  if (totalItems > 0) ...[
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.gray50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Column(
                        children: [
                          ...products.where((p) => (cartQty[p['ad']] ?? 0.0) > 0).map((prod) {
                            final String name = prod['ad'];
                            final double qty = cartQty[name]!;
                            final double price = prod['fiyat'] as double;
                            final String birim = prod['birim'] as String;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '$name  •  ${qty % 1 == 0 ? qty.toInt() : qty.toStringAsFixed(1)} $birim',
                                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray700),
                                    ),
                                  ),
                                  Text(
                                    '${(qty * price).toStringAsFixed(2)} ₺',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('$totalItems kalem • Toplam:', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700)),
                              Text('${orderTotal.toStringAsFixed(2)} ₺', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Checkout button
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: totalItems == 0
                              ? null
                              : () async {
                                  final orderId = 'ORD-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}';
                                  final List<Map<String, dynamic>> orderItems = [];

                                  for (var prod in products) {
                                    final String name = prod['ad'];
                                    final double qty = cartQty[name] ?? 0.0;
                                    if (qty > 0) {
                                      final double price = prod['fiyat'] as double;
                                      orderItems.add({
                                        'urun': name,
                                        'miktar': qty,
                                        'birim': prod['birim'],
                                        'birimFiyat': price,
                                        'toplam': qty * price,
                                      });
                                    }
                                  }

                                  final newOrderData = <String, dynamic>{
                                    'id': orderId,
                                    'uretici': selectedProducer,
                                    'firma': currentFirmaName,
                                    'durum': 'Onaylandı',
                                    'tarih': DateFormat('dd MMMM yyyy', 'tr_TR').format(DateTime.now()),
                                    'saat': DateFormat('HH:mm').format(DateTime.now()),
                                    'toplam': orderTotal,
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'kalemler': orderItems,
                                    'urun': orderItems.first['urun'],
                                    'miktar': orderItems.first['miktar'],
                                    'birim': orderItems.first['birim'],
                                    'birimFiyat': orderItems.first['birimFiyat'],
                                  };

                                  await FirebaseFirestore.instance.collection('urunler_siparisler').add(newOrderData);

                                  await FirestoreService().sendNotification(
                                    recipientName: selectedProducer,
                                    role: 'uretici',
                                    baslik: 'Yeni Sipariş Oluşturuldu',
                                    icerik: '$orderId nolu siparişiniz firma tarafından adınıza oluşturulmuştur.',
                                    type: 'siparis',
                                  );

                                  await _notifyDriversForProducer(currentFirmaName, selectedProducer, orderId);

                                  Navigator.pop(ctx);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('$orderId siparişi başarıyla oluşturuldu! ($totalItems kalem)'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.shopping_cart_checkout_rounded, size: 20),
                          label: Text(
                            totalItems == 0
                                ? 'Sepet Boş — Ürün Ekleyin'
                                : 'Siparişi Tamamla  •  ${orderTotal.toStringAsFixed(2)} ₺',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: totalItems == 0 ? AppColors.gray300 : AppColors.primary600,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}