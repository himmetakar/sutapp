import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class SurucuTeslimatlarScreen extends StatefulWidget {
  const SurucuTeslimatlarScreen({super.key});

  @override
  State<SurucuTeslimatlarScreen> createState() => _SurucuTeslimatlarScreenState();
}

class _SurucuTeslimatlarScreenState extends State<SurucuTeslimatlarScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingProducers = true;
  List<String> _assignedProducers = [];
  List<Map<String, dynamic>> _firmaProducts = [];
  String _driverName = '';
  String _firmaName = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDriverAndProducers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDriverAndProducers() async {
    setState(() {
      _isLoadingProducers = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _driverName = authProvider.user?.displayName ?? 'Ahmet Kara';
      
      // Load driver profile to get company
      final allDriversQuery = await FirebaseFirestore.instance
          .collection('suruculer')
          .get();

      DocumentSnapshot? matchedDriverDoc;
      for (var doc in allDriversQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final ad = data['ad'] ?? '';
        final soyad = data['soyad'] ?? '';
        final fullName = '$ad $soyad'.trim();
        final email = data['email'] ?? '';
        
        if (fullName.toLowerCase() == _driverName.toLowerCase() ||
            (email.isNotEmpty && email == authProvider.user?.email)) {
          matchedDriverDoc = doc;
          break;
        }
      }

      if (matchedDriverDoc != null) {
        final pData = matchedDriverDoc.data() as Map<String, dynamic>;
        _driverName = '${pData['ad'] ?? ''} ${pData['soyad'] ?? ''}'.trim();
        _firmaName = pData['firma'] ?? '';
      }

      if (_firmaName.isEmpty) {
        // Fallback search in vehicles
        final vehicleQuery = await FirebaseFirestore.instance
            .collection('araclar')
            .where('suruculer', arrayContains: _driverName)
            .limit(1)
            .get();
        if (vehicleQuery.docs.isNotEmpty) {
          _firmaName = vehicleQuery.docs.first['firma'] ?? '';
        }
      }

      if (_firmaName.isEmpty) {
        _firmaName = 'Kayseri Çiftlik'; // absolute fallback
      }

      // Load assignments for this driver
      final atamalarQuery = await FirebaseFirestore.instance
          .collection('toplayici_atamalari')
          .where('firma', isEqualTo: _firmaName)
          .where('toplayici', isEqualTo: _driverName)
          .get();

      final List<String> assignedProducers = [];
      final List<String> assignedGroups = [];
      final List<String> assignedBirlikler = [];

      for (var doc in atamalarQuery.docs) {
        final data = doc.data();
        final hTip = data['hedefTip'];
        final hAd = data['hedefAd'];
        if (hTip == 'uretici') {
          assignedProducers.add(hAd);
        } else if (hTip == 'grup') {
          assignedGroups.add(hAd);
        } else if (hTip == 'birlik' || hTip == 'bolge') {
          assignedBirlikler.add(hAd);
        }
      }

      // Fetch all producers of this firma and match
      final prodQuery = await FirebaseFirestore.instance
          .collection('ureticiler')
          .where('firmalar', arrayContains: _firmaName)
          .get();

      final List<String> matchedProducers = [];
      for (var doc in prodQuery.docs) {
        final data = doc.data();
        final name = data['name'] ?? '';
        final group = data['group'] ?? '';
        final bolge = data['bolge'] ?? '';
        final birlik = data['birlik'] ?? 'Yok';

        if (assignedProducers.contains(name) ||
            (group.isNotEmpty && assignedGroups.contains(group)) ||
            (bolge.isNotEmpty && assignedBirlikler.contains(bolge)) ||
            (birlik.isNotEmpty && birlik != 'Yok' && assignedBirlikler.contains(birlik))) {
          matchedProducers.add(name);
        }
      }

      // Fetch all products of this company
      final productsQuery = await FirebaseFirestore.instance
          .collection('urunler')
          .where('firma', isEqualTo: _firmaName)
          .get();
      
      final List<Map<String, dynamic>> loadedProducts = [];
      for (var doc in productsQuery.docs) {
        final data = doc.data();
        loadedProducts.add({
          'ad': data['ad'] ?? '',
          'fiyat': (data['fiyat'] as num?)?.toDouble() ?? 0.0,
          'birim': data['birim'] ?? 'Adet',
        });
      }

      setState(() {
        _assignedProducers = matchedProducers;
        _firmaProducts = loadedProducts;
        _isLoadingProducers = false;
      });
    } catch (e) {
      print('Error loading assigned producers: $e');
      setState(() {
        _isLoadingProducers = false;
      });
    }
  }

  List<Map<String, dynamic>> _getOrderItems(Map<String, dynamic> data) {
    if (data.containsKey('kalemler') && data['kalemler'] is List) {
      return List<Map<String, dynamic>>.from(
        (data['kalemler'] as List).map((e) => Map<String, dynamic>.from(e as Map))
      );
    } else {
      return [
        {
          'urun': data['urun'] ?? 'Bilinmeyen Ürün',
          'miktar': (data['miktar'] as num?)?.toDouble() ?? 1.0,
          'birim': data['birim'] ?? 'Adet',
          'birimFiyat': (data['birimFiyat'] as num?)?.toDouble() ?? 0.0,
          'toplam': (data['toplam'] as num?)?.toDouble() ?? 0.0,
        }
      ];
    }
  }

  Future<void> _updateOrderStatus(DocumentSnapshot doc, String newStatus, {List<Map<String, dynamic>>? finalItems, double? finalTotal}) async {
    final data = doc.data() as Map<String, dynamic>;
    final items = finalItems ?? _getOrderItems(data);
    final double total = finalTotal ?? (data['toplam'] as num?)?.toDouble() ?? 0.0;
    final uretici = data['uretici'] ?? '';

    await doc.reference.update({
      'durum': newStatus,
      if (finalItems != null) 'kalemler': finalItems,
      if (finalTotal != null) 'toplam': finalTotal,
    });

    // If marked Delivered, perform stock deduction & record payment kesinti
    if (newStatus == 'Teslim Edildi') {
      for (var item in items) {
        final String urunName = item['urun'];
        final double miktar = (item['miktar'] as num).toDouble();
        final double totalCost = (item['toplam'] as num).toDouble();

        // 1. Subtract product stock
        final urunQuery = await FirebaseFirestore.instance
            .collection('urunler')
            .where('ad', isEqualTo: urunName)
            .where('firma', isEqualTo: _firmaName)
            .limit(1)
            .get();

        if (urunQuery.docs.isNotEmpty) {
          final uDoc = urunQuery.docs.first;
          final double currentStock = (uDoc['stok'] as num?)?.toDouble() ?? 0.0;
          final double minStok = (uDoc.data() as Map<String, dynamic>)['minStok']?.toDouble() ?? 10.0;
          final String birim = (uDoc.data() as Map<String, dynamic>)['birim'] ?? 'Adet';
          final double newStock = (currentStock - miktar).clamp(0.0, double.infinity);
          await uDoc.reference.update({'stok': newStock});

          // Send critical stock notification to managers if stock falls below limit
          if (newStock <= minStok) {
            await FirestoreService().sendNotification(
              recipientName: _firmaName,
              role: 'firma',
              baslik: 'Kritik Stok Uyarısı',
              icerik: '$urunName ürünü kritik stok limitinin altına düştü! Güncel Stok: ${newStock.toStringAsFixed(0)} $birim',
              type: 'stok',
            );
          }
        }

        // 2. Add deduction to kesintiler (milk payment subtraction)
        await FirebaseFirestore.instance.collection('kesintiler').add({
          'uretici': uretici,
          'tutar': totalCost,
          'kesintiTuru': '$urunName Alımı',
          'durum': 'aktif',
          'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
          'timestamp': FieldValue.serverTimestamp(),
          'firma': _firmaName,
        });
      }

      // Send notification to the producer
      try {
        await FirestoreService().sendNotification(
          recipientName: uretici,
          role: 'uretici',
          baslik: 'Siparişiniz Teslim Edildi',
          icerik: '${data['id'] ?? ''} nolu siparişiniz ${_driverName} tarafından teslim edilmiştir. Toplam Tutar: ${total.toStringAsFixed(2)} ₺.',
          type: 'siparis',
        );
      } catch (_) {}

      // Send notification to the company
      try {
        await FirestoreService().sendNotification(
          recipientName: _firmaName,
          role: 'firma',
          baslik: 'Sipariş Teslim Edildi',
          icerik: '$uretici üreticisine ait ${data['id'] ?? ''} nolu sipariş $_driverName tarafından teslim edilmiştir. Toplam Tutar: ${total.toStringAsFixed(2)} ₺.',
          type: 'siparis',
        );
      } catch (_) {}
    } else if (newStatus == 'Teslimatta') {
      // Send transit notification to the producer
      try {
        await FirestoreService().sendNotification(
          recipientName: uretici,
          role: 'uretici',
          baslik: 'Siparişiniz Yola Çıktı',
          icerik: '${data['id'] ?? ''} nolu siparişiniz dağıtıma çıkmıştır.',
          type: 'siparis',
        );
      } catch (_) {}

      // Send transit notification to the company
      try {
        await FirestoreService().sendNotification(
          recipientName: _firmaName,
          role: 'firma',
          baslik: 'Sipariş Yola Çıktı',
          icerik: '$uretici üreticisine ait ${data['id'] ?? ''} nolu sipariş $_driverName tarafından yola çıkarıldı.',
          type: 'siparis',
        );
      } catch (_) {}
    }
  }

  void _showDeliverOrderDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final items = _getOrderItems(data);
    
    // Create controllers for each item quantity
    final List<TextEditingController> controllers = items.map((item) {
      final double qty = (item['miktar'] as num?)?.toDouble() ?? 1.0;
      final String initialVal = qty % 1 == 0 ? qty.toInt().toString() : qty.toString();
      return TextEditingController(text: initialVal);
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double newOrderTotal = 0.0;
            List<Map<String, dynamic>> updatedItems = [];

            for (int i = 0; i < items.length; i++) {
              final item = items[i];
              final double unitPrice = (item['birimFiyat'] as num?)?.toDouble() ?? 0.0;
              final double qty = double.tryParse(controllers[i].text) ?? 0.0;
              final double itemTotal = qty * unitPrice;
              newOrderTotal += itemTotal;

              updatedItems.add({
                'urun': item['urun'],
                'miktar': qty,
                'birim': item['birim'],
                'birimFiyat': unitPrice,
                'toplam': itemTotal,
              });
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Siparişi Teslim Et',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      for (var controller in controllers) {
                        controller.dispose();
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gerçekten teslim edilen ürün miktarlarını girin ve onaylayın. Eksik teslimat varsa miktarını azaltabilirsiniz.',
                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          final String uAd = item['urun'] ?? '';
                          final String unit = item['birim'] ?? 'Adet';
                          final double price = (item['birimFiyat'] as num?)?.toDouble() ?? 0.0;
                          final double currentQty = (item['miktar'] as num?)?.toDouble() ?? 1.0;
                          final double updatedQty = double.tryParse(controllers[index].text) ?? 0.0;
                          final double totalItem = updatedQty * price;

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
                                      ),
                                    ),
                                    Text(
                                      'İstenen: ${currentQty.toStringAsFixed(0)} $unit',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: controllers[index],
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: InputDecoration(
                                          labelText: 'Teslim Edilen Miktar ($unit)',
                                          labelStyle: GoogleFonts.inter(fontSize: 12),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                        ),
                                        onChanged: (_) {
                                          setStateDialog(() {});
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Birim: ${price.toStringAsFixed(2)} ₺',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                        ),
                                        Text(
                                          'Tutar: ${totalItem.toStringAsFixed(2)} ₺',
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Teslim Edilen Toplam Tutar:',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray700,
                            ),
                          ),
                          Text(
                            '${newOrderTotal.toStringAsFixed(2)} ₺',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    for (var controller in controllers) {
                      controller.dispose();
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await _updateOrderStatus(
                      doc,
                      'Teslim Edildi',
                      finalItems: updatedItems,
                      finalTotal: newOrderTotal,
                    );

                    for (var controller in controllers) {
                      controller.dispose();
                    }
                    Navigator.pop(ctx);
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Sipariş başarıyla teslim edildi!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Teslim Et'),
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
    if (_isLoadingProducers) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text('Sipariş Teslimatları', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary600,
          labelColor: AppColors.primary700,
          unselectedLabelColor: AppColors.gray500,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Aktif Siparişler'),
            Tab(text: 'Geçmiş Teslimatlar'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateOrderDialog(),
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
        label: Text('Yeni Sipariş', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('urunler_siparisler')
            .where('firma', isEqualTo: _firmaName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata oluştu: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red)));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = (snapshot.data?.docs ?? []).toList();

          // Filter locally by assigned producers
          final driverDocs = allDocs.where((doc) {
            final uretici = doc['uretici'] as String? ?? '';
            return _assignedProducers.contains(uretici);
          }).toList();

          // Sort by timestamp descending
          driverDocs.sort((a, b) {
            final aTime = (a.data() as Map)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map)['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          // Separate active (Onaylandı, Teslimatta) and history (Teslim Edildi, İptal)
          final activeOrders = driverDocs.where((doc) {
            final durum = doc['durum'] ?? 'Bekliyor';
            return durum == 'Onaylandı' || durum == 'Teslimatta';
          }).toList();

          final historyOrders = driverDocs.where((doc) {
            final durum = doc['durum'] ?? 'Bekliyor';
            return durum == 'Teslim Edildi' || durum == 'İptal';
          }).toList();

          return TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersList(activeOrders, isActive: true),
              _buildOrdersList(historyOrders, isActive: false),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOrdersList(List<QueryDocumentSnapshot> orders, {required bool isActive}) {
    if (orders.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(isActive ? Icons.local_shipping_outlined : Icons.history_rounded, size: 48, color: AppColors.gray300),
              const SizedBox(height: 12),
              Text(
                isActive ? 'Aktif dağıtım siparişiniz bulunmamaktadır.' : 'Geçmiş teslimatınız bulunmamaktadır.',
                style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      itemBuilder: (context, idx) {
        final doc = orders[idx];
        final data = doc.data() as Map<String, dynamic>;
        final uretici = data['uretici'] ?? '';
        final orderId = data['id'] ?? '';
        final tarih = data['tarih'] ?? '';
        final saat = data['saat'] ?? '';
        final durum = data['durum'] ?? 'Bekliyor';
        final toplam = (data['toplam'] as num?)?.toDouble() ?? 0.0;
        final items = _getOrderItems(data);

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
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        durum == 'Onaylandı' ? 'Hazırlandı' : durum,
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Sipariş $orderId • $tarih $saat', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                const Divider(height: 20),
                
                // Render products
                ...items.map((item) {
                  final String uAd = item['urun'] ?? '';
                  final double qty = (item['miktar'] as num?)?.toDouble() ?? 1.0;
                  final String unit = item['birim'] ?? 'Adet';
                  final double price = (item['birimFiyat'] as num?)?.toDouble() ?? 0.0;
                  final double total = (item['toplam'] as num?)?.toDouble() ?? 0.0;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            uAd,
                            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
                          ),
                        ),
                        Text(
                          '${qty.toStringAsFixed(0)} $unit x ${price.toStringAsFixed(2)} ₺',
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${total.toStringAsFixed(2)} ₺',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray700),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Toplam Tutar:', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.bold)),
                    Text(
                      '${toplam.toStringAsFixed(2)} ₺',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary600),
                    ),
                  ],
                ),

                if (isActive) ...[
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (durum == 'Onaylandı')
                        ElevatedButton.icon(
                          onPressed: () async {
                            await _updateOrderStatus(doc, 'Teslimatta');
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sipariş yola çıktı!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                          icon: const Icon(Icons.delivery_dining_rounded, size: 16),
                          label: const Text('Teslimata Çıktı'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            elevation: 0,
                          ),
                        ),
                      if (durum == 'Teslimatta')
                        ElevatedButton.icon(
                          onPressed: () => _showDeliverOrderDialog(doc),
                          icon: const Icon(Icons.done_all_rounded, size: 16),
                          label: const Text('Teslim Edildi'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            elevation: 0,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateOrderDialog() {
    if (_assignedProducers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sipariş oluşturmak için atanmış üreticiniz bulunmalıdır.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_firmaProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Firmaya ait ürün bulunamadı.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    String? selectedProducer = _assignedProducers.first;
    Map<String, dynamic>? selectedProduct = _firmaProducts.first;
    final quantityCtrl = TextEditingController(text: '1');
    List<Map<String, dynamic>> orderItems = [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double orderTotal = orderItems.fold(0.0, (sum, item) => sum + (item['toplam'] as double));

            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Yeni Sipariş Oluştur', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Üretici Seçin
                      Text('Üretici Seçin', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.gray300),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedProducer,
                            isExpanded: true,
                            items: _assignedProducers.map((name) {
                              return DropdownMenuItem<String>(
                                value: name,
                                child: Text(name, style: GoogleFonts.inter(fontSize: 14)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setStateDialog(() {
                                selectedProducer = val;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // 2. Ürün Ekle Bölümü
                      Text('Kalem Ekle', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray700)),
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
                            items: _firmaProducts.map((prod) {
                              return DropdownMenuItem<Map<String, dynamic>>(
                                value: prod,
                                child: Text('${prod['ad']} (${prod['fiyat'].toStringAsFixed(2)} ₺)', style: GoogleFonts.inter(fontSize: 14)),
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: quantityCtrl,
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
                              final double? qty = double.tryParse(quantityCtrl.text);
                              if (qty == null || qty <= 0 || selectedProduct == null) {
                                return;
                              }
                              final double price = selectedProduct!['fiyat'] as double;
                              setStateDialog(() {
                                orderItems.add({
                                  'urun': selectedProduct!['ad'],
                                  'miktar': qty,
                                  'birim': selectedProduct!['birim'],
                                  'birimFiyat': price,
                                  'toplam': qty * price,
                                });
                                quantityCtrl.text = '1';
                              });
                            },
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Ekle'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary600,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),

                      // 3. Eklenen Ürünler Listesi
                      Text('Sipariş Kalemleri (${orderItems.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      const SizedBox(height: 8),
                      if (orderItems.isEmpty)
                        Text('Henüz ürün eklenmedi.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400))
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: orderItems.length,
                            itemBuilder: (context, idx) {
                              final item = orderItems[idx];
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                title: Text(item['urun'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                subtitle: Text('${item['miktar'].toStringAsFixed(0)} ${item['birim']} x ${item['birimFiyat'].toStringAsFixed(2)} ₺', style: GoogleFonts.inter(fontSize: 11)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('${item['toplam'].toStringAsFixed(2)} ₺', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                                    IconButton(
                                      icon: const Icon(Icons.remove_circle_outline, color: Colors.red, size: 18),
                                      onPressed: () {
                                        setStateDialog(() {
                                          orderItems.removeAt(idx);
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      const SizedBox(height: 16),
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
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: orderItems.isEmpty || selectedProducer == null
                      ? null
                      : () async {
                          final orderId = 'ORD-${DateFormat('yyyyMMdd-HHmmss').format(DateTime.now())}';
                          
                          // Save order to Firebase
                          await FirebaseFirestore.instance.collection('urunler_siparisler').add({
                            'id': orderId,
                            'uretici': selectedProducer,
                            'firma': _firmaName,
                            'durum': 'Bekliyor',
                            'tarih': DateFormat('dd MMMM yyyy', 'tr_TR').format(DateTime.now()),
                            'saat': DateFormat('HH:mm').format(DateTime.now()),
                            'toplam': orderTotal,
                            'timestamp': FieldValue.serverTimestamp(),
                            'kalemler': orderItems,
                          });

                          // Send notification to the producer
                          await FirestoreService().sendNotification(
                            recipientName: selectedProducer!,
                            role: 'uretici',
                            baslik: 'Yeni Sipariş Oluşturuldu',
                            icerik: '$orderId nolu siparişiniz ${_driverName} tarafından adınıza oluşturulmuştur.',
                            type: 'siparis',
                          );

                          // Send notification to the driver
                          await FirestoreService().sendNotification(
                            recipientName: _driverName,
                            role: 'surucu',
                            baslik: 'Sipariş Oluşturuldu',
                            icerik: '$selectedProducer adına $orderId nolu siparişi başarıyla oluşturdunuz.',
                            type: 'siparis',
                          );

                          // Send notification to the company
                          await FirestoreService().sendNotification(
                            recipientName: _firmaName,
                            role: 'firma',
                            baslik: 'Yeni Sipariş Talebi',
                            icerik: '$selectedProducer adına $_driverName tarafından yeni sipariş oluşturuldu. Hazırlanması bekleniyor.',
                            type: 'siparis',
                          );

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sipariş başarıyla oluşturuldu!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Siparişi Oluştur'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
