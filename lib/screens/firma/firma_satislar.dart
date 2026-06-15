import 'dart:math';
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

class FirmaSatislarScreen extends StatefulWidget {
  const FirmaSatislarScreen({super.key});

  @override
  State<FirmaSatislarScreen> createState() => _FirmaSatislarScreenState();
}

class _FirmaSatislarScreenState extends State<FirmaSatislarScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _showAddSaleDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Fetch producers
    final producersQuery = await _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).get();
    final producers = producersQuery.docs.map((p) => p.data()['name'] as String? ?? '').where((p) => p.isNotEmpty).toList();

    if (producers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Satış yapmak için önce en az bir üretici bulunmalıdır!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    // Fetch products in stock
    final productsQuery = await _db.collection('urunler')
        .where('firma', isEqualTo: currentFirmaName)
        .get();
    final products = productsQuery.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'ad': data['ad'] as String? ?? '',
        'stok': (data['stok'] as num?)?.toDouble() ?? 0.0,
        'birim': data['birim'] as String? ?? 'Adet',
        'fiyat': (data['fiyat'] as num?)?.toDouble() ?? 0.0,
      };
    }).where((p) => (p['ad'] as String).isNotEmpty && (p['stok'] as double) > 0).toList();

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Satış yapmak için stokta en az bir ürün bulunmalıdır! Lütfen önce fatura ekleyin veya stok girişi yapın.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedProducer = producers.first;
        
        // Product variables
        String? selectedProductAd = products.first['ad'] as String;
        double selectedProductPrice = products.first['fiyat'] as double;
        double selectedProductStock = products.first['stok'] as double;
        String selectedProductUnit = products.first['birim'] as String;

        final amountCtrl = TextEditingController(text: '1');
        final priceCtrl = TextEditingController(text: selectedProductPrice.toStringAsFixed(0));
        
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Yeni Satış Yap', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Alıcı Üretici', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedProducer,
                      items: producers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => setState(() => selectedProducer = val),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(height: 12),
                    Text('Satılan Ürün', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedProductAd,
                      items: products.map((p) {
                        final String ad = p['ad'] as String;
                        final double stock = p['stok'] as double;
                        final String birim = p['birim'] as String;
                        return DropdownMenuItem(
                          value: ad,
                          child: Text('$ad (Stok: ${stock.toStringAsFixed(0)} $birim)'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedProductAd = val;
                          final matched = products.firstWhere((p) => p['ad'] == val);
                          selectedProductPrice = matched['fiyat'] as double;
                          selectedProductStock = matched['stok'] as double;
                          selectedProductUnit = matched['birim'] as String;
                          
                          // Recalculate price when product changes
                          final qty = double.tryParse(amountCtrl.text) ?? 1.0;
                          priceCtrl.text = (qty * selectedProductPrice).toStringAsFixed(0);
                        });
                      },
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Miktar ($selectedProductUnit)',
                        hintText: 'Örn: 10',
                      ),
                      onChanged: (val) {
                        final qty = double.tryParse(val) ?? 0.0;
                        setState(() {
                          priceCtrl.text = (qty * selectedProductPrice).toStringAsFixed(0);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Toplam Tutar (₺)', hintText: 'Örn: 5000'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500))),
                ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(amountCtrl.text) ?? 1.0;
                    final price = double.tryParse(priceCtrl.text) ?? 0.0;
                    final product = selectedProductAd ?? '';
 
                    if (selectedProducer == null || product.isEmpty || price <= 0) return;
 
                    // Check if requested amount exceeds stock
                    if (amount > selectedProductStock) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Yetersiz stok! En fazla ${selectedProductStock.toStringAsFixed(0)} $selectedProductUnit satabilirsiniz.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    final rand = Random();
                    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
                    final orderId = '#' + List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();

                    await _db.collection('satislar').add({
                      'uretici': selectedProducer,
                      'urun': product,
                      'miktar': amount,
                      'fiyat': amount > 0 ? price / amount : 0.0, // birim fiyat
                      'tutar': price,
                      'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                      'firma': currentFirmaName,
                      'timestamp': FieldValue.serverTimestamp(),
                      'orderId': orderId,
                    });

                    // Create corresponding order in urunler_siparisler
                    await _db.collection('urunler_siparisler').add({
                      'id': orderId,
                      'uretici': selectedProducer,
                      'firma': currentFirmaName,
                      'durum': 'Bekliyor',
                      'tarih': DateFormat('dd MMMM yyyy', 'tr_TR').format(DateTime.now()),
                      'saat': DateFormat('HH:mm').format(DateTime.now()),
                      'toplam': price,
                      'isDirectSale': true,
                      'timestamp': FieldValue.serverTimestamp(),
                      'kalemler': [
                        {
                          'urun': product,
                          'miktar': amount,
                          'birim': selectedProductUnit,
                          'birimFiyat': price / amount,
                          'toplam': price,
                        }
                      ],
                    });

                    // Decrement stock in urunler
                    final urunSnap = await _db.collection('urunler')
                        .where('firma', isEqualTo: currentFirmaName)
                        .where('ad', isEqualTo: product)
                        .limit(1)
                        .get();
                    if (urunSnap.docs.isNotEmpty) {
                      final uDoc = urunSnap.docs.first;
                      final double currentStock = (uDoc['stok'] as num?)?.toDouble() ?? 0.0;
                      final double minStok = (uDoc.data() as Map<String, dynamic>)['minStok']?.toDouble() ?? 10.0;
                      final String birim = (uDoc.data() as Map<String, dynamic>)['birim'] ?? 'Adet';
                      final double newStock = (currentStock - amount).clamp(0.0, double.infinity);
                      await uDoc.reference.update({
                        'stok': newStock,
                      });
                      
                      if (newStock <= minStok) {
                        await FirestoreService().sendNotification(
                          recipientName: currentFirmaName,
                          role: 'firma',
                          baslik: 'Kritik Stok Uyarısı',
                          icerik: '$product ürünü kritik stok limitinin altına düştü! Güncel Stok: ${newStock.toStringAsFixed(0)} $birim',
                          type: 'stok',
                        );
                      }
                    }

                    // Send notifications
                    await FirestoreService().sendNotification(
                      recipientName: selectedProducer!,
                      role: 'uretici',
                      baslik: 'Yeni Sipariş Tanımlandı',
                      icerik: '$currentFirmaName firması size $product satışı tanımladı. Sipariş durumu: Bekliyor.',
                      type: 'siparis',
                    );

                    await _notifyDriversForProducer(
                      currentFirmaName,
                      selectedProducer!,
                      orderId,
                      customBaslik: 'Yeni Dağıtım Talebi (Bekliyor)',
                      customIcerik: '$selectedProducer üreticisine ait $orderId nolu yeni bir sipariş girildi, teslimat bekliyor.',
                    );

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Satış başarıyla kaydedildi! Üretici hesabına borç olarak yansıtıldı ve sipariş oluşturuldu.'), backgroundColor: AppColors.success),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Satışı Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteSale(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Satışı Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu satış kaydını silmek istediğinize emin misiniz? Bu işlem üreticinin borcunu düşürecektir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              final data = doc.data() as Map<String, dynamic>;
              final product = data['urun'] as String? ?? '';
              final amount = (data['miktar'] as num?)?.toDouble() ?? 0.0;
              final currentFirmaName = data['firma'] as String? ?? '';
              final orderId = data['orderId'] as String?;

              if (orderId != null && orderId.isNotEmpty) {
                // Fetch all sales sharing the same orderId to delete them and restore stock
                final salesQuery = await _db.collection('satislar')
                    .where('orderId', isEqualTo: orderId)
                    .where('firma', isEqualTo: currentFirmaName)
                    .get();

                for (var sDoc in salesQuery.docs) {
                  final sData = sDoc.data();
                  final String pName = sData['urun'] as String? ?? '';
                  final double qty = (sData['miktar'] as num?)?.toDouble() ?? 0.0;

                  // Increment stock back
                  if (pName.isNotEmpty && qty > 0) {
                    final urunSnap = await _db.collection('urunler')
                        .where('firma', isEqualTo: currentFirmaName)
                        .where('ad', isEqualTo: pName)
                        .limit(1)
                        .get();
                    if (urunSnap.docs.isNotEmpty) {
                      await urunSnap.docs.first.reference.update({
                        'stok': FieldValue.increment(qty),
                      });
                    }
                  }

                  // Delete this item document
                  await sDoc.reference.delete();
                }

                // Delete corresponding order in urunler_siparisler
                final orderQuery = await _db.collection('urunler_siparisler')
                    .where('id', isEqualTo: orderId)
                    .where('firma', isEqualTo: currentFirmaName)
                    .get();
                for (var oDoc in orderQuery.docs) {
                  await oDoc.reference.delete();
                }
              } else {
                // Fallback for legacy single-item sales
                await doc.reference.delete();
                if (product.isNotEmpty && amount > 0) {
                  final urunSnap = await _db.collection('urunler')
                      .where('firma', isEqualTo: currentFirmaName)
                      .where('ad', isEqualTo: product)
                      .limit(1)
                      .get();
                  if (urunSnap.docs.isNotEmpty) {
                    await urunSnap.docs.first.reference.update({
                      'stok': FieldValue.increment(amount),
                    });
                  }
                }
              }

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Satış kaydı silindi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Scaffold(
      appBar: AppBar(
        title: Text('Üretici Satışları (Yem vb.)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/urunler'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      floatingActionButton: AppFab(
        icon: Icons.shopping_basket_rounded,
        label: 'Satış Yap',
        onTap: () => context.go('/firma/satislar/ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('satislar')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final rawDocs = snapshot.data?.docs ?? [];
          
          // Sort in memory to avoid index requirements
          final docs = List<QueryDocumentSnapshot>.from(rawDocs);
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['timestamp'] as Timestamp?;
            final bTime = bData['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Kayıtlı satış bulunmuyor.',
                style: GoogleFonts.inter(color: AppColors.gray500),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final uretici = data['uretici'] ?? '';
              final urun = data['urun'] ?? '';
              final miktar = data['miktar'] ?? 1.0;
              final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
              final tarih = data['tarih'] ?? '';

              return Container(
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
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.outbox_rounded, color: AppColors.danger, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(uretici, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text(
                            '$urun - $miktar Adet/Kg',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tarih,
                            style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatCurrency.format(tutar),
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.danger),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: AppColors.gray400, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () => _deleteSale(doc),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _notifyDriversForProducer(String firma, String ureticiName, String orderId, {String? customBaslik, String? customIcerik}) async {
    try {
      final prodSnap = await _db
          .collection('ureticiler')
          .where('name', isEqualTo: ureticiName)
          .limit(1)
          .get();
      
      if (prodSnap.docs.isEmpty) return;
      final pData = prodSnap.docs.first.data();
      final String group = pData['group'] ?? '';
      final String bolge = pData['bolge'] ?? '';
      final String birlik = pData['birlik'] ?? 'Yok';

      final atamalarSnap = await _db
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
