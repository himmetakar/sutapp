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

class FirmaSatisEkleScreen extends StatefulWidget {
  const FirmaSatisEkleScreen({super.key});

  @override
  State<FirmaSatisEkleScreen> createState() => _FirmaSatisEkleScreenState();
}

class _FirmaSatisEkleScreenState extends State<FirmaSatisEkleScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? _selectedUretici;
  DocumentSnapshot? _selectedProducerDoc;
  String _producerSearchQuery = '';
  final _searchController = TextEditingController();
  late final Stream<QuerySnapshot> _producersStream;

  // Producer Store Layout & Cart State
  final Map<String, Map<String, dynamic>> _cart = {}; // key: docId, value: cart item map
  String _selectedStoreCategory = 'Tümü';
  String _storeSearchQuery = '';
  final _storeSearchCtrl = TextEditingController();

  bool _isSaving = false;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    _producersStream = FirestoreService().getProducersStream(firma: currentFirmaName);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _storeSearchCtrl.dispose();
    super.dispose();
  }

  double get _cartTotal {
    return _cart.values.fold(0.0, (sum, item) => sum + (item['fiyat'] as double) * (item['quantity'] as int));
  }

  Future<void> _saveSale() async {
    if (_selectedUretici == null || _cart.isEmpty || _isSaving || _selectedDate == null) return;

    setState(() {
      _isSaving = true;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    try {
      final rand = Random();
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final orderId = '#' + List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
      
      final DateTime dateToUse = _selectedDate!;
      final String formattedDate = DateFormat('dd.MM.yyyy').format(dateToUse);
      final DateTime now = DateTime.now();
      final DateTime combinedDateTime = DateTime(
        dateToUse.year,
        dateToUse.month,
        dateToUse.day,
        now.hour,
        now.minute,
        now.second,
      );
      final Timestamp timestampToUse = Timestamp.fromDate(combinedDateTime);

      // Prepare items list for order and collection logs
      final List<Map<String, dynamic>> cartItemsList = _cart.values.map((item) {
        final double price = item['fiyat'] as double;
        final int qty = item['quantity'] as int;
        return {
          'urun': item['ad'],
          'miktar': qty.toDouble(),
          'birim': item['birim'],
          'birimFiyat': price,
          'toplam': qty * price,
        };
      }).toList();

      // Write each item to satislar and decrement stock
      for (var item in cartItemsList) {
        final String product = item['urun'];
        final double amount = item['miktar'];
        final double totalVal = item['toplam'];

        await _db.collection('satislar').add({
          'uretici': _selectedUretici,
          'urun': product,
          'miktar': amount,
          'tutar': totalVal,
          'tarih': formattedDate,
          'firma': currentFirmaName,
          'timestamp': timestampToUse,
          'orderId': orderId,
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
      }

      // Create corresponding order in urunler_siparisler
      await _db.collection('urunler_siparisler').add({
        'id': orderId,
        'uretici': _selectedUretici,
        'firma': currentFirmaName,
        'durum': 'Bekliyor',
        'tarih': DateFormat('dd MMMM yyyy', 'tr_TR').format(dateToUse),
        'saat': DateFormat('HH:mm').format(now),
        'toplam': _cartTotal,
        'isDirectSale': true,
        'timestamp': timestampToUse,
        'kalemler': cartItemsList,
      });

      // Send notification to uretici
      await FirestoreService().sendNotification(
        recipientName: _selectedUretici!,
        role: 'uretici',
        baslik: 'Yeni Sipariş Tanımlandı',
        icerik: '$currentFirmaName firması size yeni bir satış tanımladı. Sipariş kodu: $orderId',
        type: 'siparis',
      );

      // Send notification to drivers
      await _notifyDriversForProducer(currentFirmaName, _selectedUretici!, orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Satışlar başarıyla kaydedildi! Üretici hesabına borç olarak yansıtıldı ve sipariş oluşturuldu.'),
            backgroundColor: AppColors.success,
          ),
        );
        setState(() {
          _cart.clear();
          _selectedDate = null;
        });
        context.go('/firma/urunler/siparisler');
      }
    } catch (e) {
      print('Error saving sales: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Satış kaydedilirken hata oluştu: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _notifyDriversForProducer(String firma, String ureticiName, String orderId) async {
    try {
      final prodSnap = await _db.collection('ureticiler')
          .where('name', isEqualTo: ureticiName)
          .limit(1)
          .get();
      
      if (prodSnap.docs.isEmpty) return;
      final pData = prodSnap.docs.first.data();
      final String group = pData['group'] ?? '';
      final String bolge = pData['bolge'] ?? '';
      final String birlik = pData['birlik'] ?? 'Yok';

      final atamalarSnap = await _db.collection('toplayici_atamalari')
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
          baslik: 'Yeni Dağıtım Talebi (Bekliyor)',
          icerik: '$ureticiName üreticisine ait $orderId nolu yeni bir sipariş girildi, teslimat bekliyor.',
          type: 'siparis',
        );
      }
    } catch (e) {
      print('Error notifying drivers: $e');
    }
  }

  Widget _buildCategoryBox(String name, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.gray200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : AppColors.gray500, size: 20),
            const SizedBox(height: 4),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.gray800 : AppColors.gray600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showCartBottomSheet(String producerName) {
    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double total = 0.0;
            _cart.forEach((k, v) {
              total += (v['fiyat'] as double) * (v['quantity'] as int);
            });

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sepetiniz',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: _cart.isEmpty
                            ? Center(
                                child: Text(
                                  'Sepetiniz boş.',
                                  style: GoogleFonts.inter(color: AppColors.gray400),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: _cart.length,
                                itemBuilder: (context, index) {
                                  final key = _cart.keys.elementAt(index);
                                  final item = _cart[key]!;
                                  final ad = item['ad'] as String;
                                  final double price = item['fiyat'] as double;
                                  final int qty = item['quantity'] as int;
                                  final String unit = item['birim'] as String;
                                  final double stock = item['stock'] as double;

                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(ad, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                                    subtitle: Text('${formatCurrency.format(price)} / $unit'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                          onPressed: () {
                                            setState(() {
                                              if (qty > 1) {
                                                _cart[key]!['quantity'] = qty - 1;
                                              } else {
                                                _cart.remove(key);
                                              }
                                            });
                                            setSheetState(() {});
                                          },
                                        ),
                                        GestureDetector(
                                          onTap: () {
                                            final ctrl = TextEditingController(text: qty.toString());
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => AlertDialog(
                                                title: Text('Miktar Girin', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                                                content: TextField(
                                                  controller: ctrl,
                                                  keyboardType: TextInputType.number,
                                                  autofocus: true,
                                                  decoration: InputDecoration(
                                                    labelText: 'Miktar ($unit)',
                                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                  ),
                                                ),
                                                actions: [
                                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                                                  ElevatedButton(
                                                    onPressed: () {
                                                      final val = int.tryParse(ctrl.text.trim());
                                                      if (val != null && val > 0) {
                                                        setState(() {
                                                          if (val <= stock) {
                                                            _cart[key]!['quantity'] = val;
                                                          } else {
                                                            _cart[key]!['quantity'] = stock.toInt();
                                                          }
                                                        });
                                                        setSheetState(() {});
                                                      } else if (val == 0) {
                                                        setState(() => _cart.remove(key));
                                                        setSheetState(() {});
                                                      }
                                                      Navigator.pop(ctx);
                                                    },
                                                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600, foregroundColor: Colors.white),
                                                    child: const Text('Tamam'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'Adet Gir',
                                                style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                                              ),
                                              const SizedBox(height: 2),
                                              Container(
                                                constraints: const BoxConstraints(minWidth: 72, minHeight: 32),
                                                alignment: Alignment.center,
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.shade100,
                                                  border: Border.all(color: Colors.grey.shade300),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text('$qty', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: const Color(0xFF1E293B))),
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                          onPressed: () {
                                            if (qty < stock) {
                                              setState(() {
                                                _cart[key]!['quantity'] = qty + 1;
                                              });
                                              setSheetState(() {});
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(content: Text('Yetersiz stok!'), backgroundColor: AppColors.danger),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                      const Divider(),
                      // Tarih Seçici (Zorunlu)
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: _selectedDate == null ? Colors.red.shade50 : AppColors.primary50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedDate == null ? Colors.red.shade200 : AppColors.primary200,
                            width: 1,
                          ),
                        ),
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              locale: const Locale('tr', 'TR'),
                            );
                            if (picked != null) {
                              setState(() {
                                _selectedDate = picked;
                              });
                              setSheetState(() {});
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_rounded,
                                  color: _selectedDate == null ? Colors.red : AppColors.primary600,
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
                                          color: _selectedDate == null ? Colors.red.shade700 : AppColors.gray500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _selectedDate == null
                                            ? 'Tarih Seçmek İçin Dokunun'
                                            : DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate!),
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: _selectedDate == null ? Colors.red.shade900 : AppColors.gray800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: _selectedDate == null ? Colors.red.shade400 : AppColors.gray400,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Toplam:', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(
                            formatCurrency.format(total),
                            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: (_cart.isEmpty || _selectedDate == null)
                              ? null
                              : () async {
                                  Navigator.pop(ctx);
                                  await _saveSale();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text(
                            _selectedDate == null ? 'Lütfen Tarih Seçin' : 'Satış Yap',
                            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final formatCurrency = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');

    return Scaffold(
      appBar: AppBar(
        title: Text('Satış Yap (Sipariş)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (_cart.isNotEmpty) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Sayfadan Ayrıl'),
                  content: const Text('Sepetinizde ürünler bulunuyor. Ayrılmak istediğinize emin misiniz? Sepetiniz temizlenecektir.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(ctx);
                        context.go('/firma');
                      },
                      child: const Text('Ayrıl'),
                    ),
                  ],
                ),
              );
            } else {
              context.go('/firma');
            }
          },
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: _isSaving
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Satış kaydediliyor, lütfen bekleyiniz...', style: TextStyle(fontWeight: FontWeight.w500)),
                ],
              ),
            )
          : StreamBuilder<QuerySnapshot>(
              stream: _producersStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.hasData ? snapshot.data!.docs : [];
                final filteredProducers = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final group = (data['group'] as String? ?? '').toLowerCase();
                  final bolge = (data['bolge'] as String? ?? '').toLowerCase();
                  final query = _producerSearchQuery.toLowerCase();
                  return name.contains(query) || group.contains(query) || bolge.contains(query);
                }).toList();

                return Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // 1. SELECT PRODUCER SECTION
                      if (_selectedUretici == null) ...[
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.person_search_rounded, color: AppColors.primary600, size: 32),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Üretici Seçin',
                                  style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Satış tanımlamak için önce alıcı üreticiyi seçiniz.',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                TextField(
                                  controller: _searchController,
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray800),
                                  decoration: InputDecoration(
                                    hintText: 'Üretici adı, grup veya bölge yazın...',
                                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400, size: 20),
                                    suffixIcon: _searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear, size: 16),
                                            onPressed: () {
                                              _searchController.clear();
                                              setState(() {
                                                _producerSearchQuery = '';
                                              });
                                            },
                                          )
                                        : null,
                                    border: const OutlineInputBorder(
                                      borderRadius: BorderRadius.all(Radius.circular(12)),
                                      borderSide: BorderSide(color: AppColors.gray300),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _producerSearchQuery = val.trim();
                                    });
                                  },
                                ),
                                const SizedBox(height: 12),
                                Expanded(
                                  child: filteredProducers.isEmpty
                                      ? Center(
                                          child: Text(
                                            _producerSearchQuery.isEmpty
                                                ? 'Aramaya başlamak için yukarıya yazın.'
                                                : 'Üretici bulunamadı.',
                                            style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13),
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: filteredProducers.length,
                                          itemBuilder: (context, index) {
                                            final doc = filteredProducers[index];
                                            final data = doc.data() as Map<String, dynamic>;
                                            final name = data['name'] ?? '';
                                            final group = data['group'] ?? 'Yok';
                                            final bolge = data['bolge'] ?? 'Yok';

                                            return Card(
                                              margin: const EdgeInsets.only(bottom: 8),
                                              elevation: 0,
                                              shape: RoundedRectangleBorder(
                                                side: const BorderSide(color: AppColors.gray200),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: ListTile(
                                                title: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                                subtitle: Text('Grup: $group • Bölge: $bolge', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                                                trailing: const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.gray400),
                                                onTap: () {
                                                  setState(() {
                                                    _selectedUretici = name;
                                                    _selectedProducerDoc = doc;
                                                    _producerSearchQuery = '';
                                                    _searchController.clear();
                                                  });
                                                },
                                              ),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else ...[
                        // Selected Producer Header Banner
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.primary200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded, color: AppColors.primary600, size: 24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _selectedUretici!,
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                    ),
                                    if (_selectedProducerDoc != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        'Grup: ${(_selectedProducerDoc!.data() as Map)['group'] ?? 'Yok'} • Bölge: ${(_selectedProducerDoc!.data() as Map)['bolge'] ?? 'Yok'}',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  if (_cart.isNotEmpty) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Müşteriyi Değiştir'),
                                        content: const Text('Alıcı müşteriyi değiştirmek sepetinizdeki ürünleri temizleyecektir. Emin misiniz?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
                                            onPressed: () {
                                              Navigator.pop(ctx);
                                              setState(() {
                                                _selectedUretici = null;
                                                _selectedProducerDoc = null;
                                                _cart.clear();
                                                _selectedDate = null;
                                              });
                                            },
                                            child: const Text('Değiştir'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    setState(() {
                                      _selectedUretici = null;
                                      _selectedProducerDoc = null;
                                    });
                                  }
                                },
                                child: Text('Değiştir', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.danger)),
                              ),
                            ],
                          ),
                        ),

                        // Store Search Box
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: TextField(
                            controller: _storeSearchCtrl,
                            decoration: InputDecoration(
                              hintText: 'Ürün ara...',
                              prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400),
                              suffixIcon: _storeSearchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        setState(() {
                                          _storeSearchQuery = '';
                                          _storeSearchCtrl.clear();
                                        });
                                      },
                                    )
                                  : null,
                              filled: true,
                              fillColor: AppColors.gray50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _storeSearchQuery = val.trim();
                              });
                            },
                          ),
                        ),

                        // Category icons horizontal list
                        StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('urunler_kategoriler')
                              .where('firma', isEqualTo: currentFirmaName)
                              .snapshots(),
                          builder: (context, catSnap) {
                            IconData _catIcon(String cat) {
                              if (cat.contains('Araç') || cat.contains('Gereç')) return Icons.build_rounded;
                              if (cat.contains('Vitamin')) return Icons.science_rounded;
                              if (cat.contains('Yem')) return Icons.eco_rounded;
                              if (cat.contains('İlaç') || cat.contains('ilac')) return Icons.medical_services_rounded;
                              return Icons.folder_rounded;
                            }
                            Color _catColor(String cat) {
                              if (cat.contains('Araç') || cat.contains('Gereç')) return const Color(0xFF009688);
                              if (cat.contains('Vitamin')) return const Color(0xFF9C27B0);
                              if (cat.contains('Yem')) return const Color(0xFF4CAF50);
                              if (cat.contains('İlaç') || cat.contains('ilac')) return const Color(0xFFEF4444);
                              return const Color(0xFF2196F3);
                            }
                            final List<String> storeCats = [];
                            if (catSnap.hasData) {
                              for (var doc in catSnap.data!.docs) {
                                final name = (doc.data() as Map<String, dynamic>)['ad'] as String? ?? '';
                                if (name.isNotEmpty && !storeCats.contains(name)) storeCats.add(name);
                              }
                            }
                            return Container(
                              color: Colors.white,
                              height: 74,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildCategoryBox('Tümü', Icons.grid_view_rounded, AppColors.primary600, _selectedStoreCategory == 'Tümü', () {
                                    setState(() => _selectedStoreCategory = 'Tümü');
                                  }),
                                  ...storeCats.map((cat) => _buildCategoryBox(
                                    cat, _catIcon(cat), _catColor(cat), _selectedStoreCategory == cat,
                                    () => setState(() => _selectedStoreCategory = cat),
                                  )),
                                ],
                              ),
                            );
                          },
                        ),

                        const Divider(height: 1),

                        // Catalog List
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('urunler')
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
                              
                              var docs = (snapshot.data?.docs ?? []).toList();

                              // Apply store category filter
                              if (_selectedStoreCategory != 'Tümü') {
                                docs = docs.where((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final cat = data['kategori'] ?? 'Diğer';
                                  return cat == _selectedStoreCategory;
                                }).toList();
                              }

                              // Apply store search query
                              if (_storeSearchQuery.isNotEmpty) {
                                docs = docs.where((doc) {
                                  final data = doc.data() as Map<String, dynamic>;
                                  final ad = (data['ad'] ?? '').toString().toLowerCase();
                                  return ad.contains(_storeSearchQuery.toLowerCase());
                                }).toList();
                              }

                              if (docs.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40.0),
                                    child: Text('Aradığınız kriterlere uygun ürün bulunmamaktadır.', style: GoogleFonts.inter(color: AppColors.gray400)),
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.all(16),
                                itemCount: docs.length,
                                itemBuilder: (context, idx) {
                                  final doc = docs[idx];
                                  final data = doc.data() as Map<String, dynamic>;
                                  final docId = doc.id;
                                  final ad = data['ad'] ?? '';
                                  final kat = data['kategori'] ?? 'Diğer';
                                  final birim = data['birim'] ?? 'Adet';
                                  final fiyat = (data['fiyat'] as num?)?.toDouble() ?? 0.0;
                                  final stok = (data['stok'] as num?)?.toDouble() ?? 0.0;
                                  final productFirma = data['firma'] ?? currentFirmaName;

                                  final inCart = _cart.containsKey(docId);
                                  final qty = inCart ? _cart[docId]!['quantity'] as int : 0;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.gray200),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.015),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        )
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary500, size: 20),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                                textBaseline: TextBaseline.alphabetic,
                                                children: [
                                                  Expanded(
                                                    child: Text(ad, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gray800), overflow: TextOverflow.ellipsis),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(kat, style: GoogleFonts.inter(fontSize: 9.5, color: AppColors.gray400, fontWeight: FontWeight.w500)),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Text('${formatCurrency.format(fiyat)} / $birim', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.primary600)),
                                                  const SizedBox(width: 8),
                                                  Text('•', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray300)),
                                                  const SizedBox(width: 8),
                                                  Text('Stok: ${stok.toStringAsFixed(0)} $birim', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: stok <= 0 ? Colors.red : AppColors.gray500)),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (inCart)
                                          Container(
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: AppColors.gray50,
                                              border: Border.all(color: AppColors.gray200),
                                              borderRadius: BorderRadius.circular(14),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                IconButton(
                                                  icon: const Icon(Icons.remove_rounded, size: 12, color: AppColors.gray600),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                  onPressed: () {
                                                    setState(() {
                                                      if (qty > 1) {
                                                        _cart[docId]!['quantity'] = qty - 1;
                                                      } else {
                                                        _cart.remove(docId);
                                                      }
                                                    });
                                                  },
                                                ),
                                                GestureDetector(
                                                  onTap: () {
                                                    final ctrl = TextEditingController(text: qty.toString());
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: Text('Miktar Girin', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                                                        content: TextField(
                                                          controller: ctrl,
                                                          keyboardType: TextInputType.number,
                                                          autofocus: true,
                                                          decoration: InputDecoration(
                                                            labelText: 'Miktar ($birim)',
                                                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                                          ),
                                                        ),
                                                        actions: [
                                                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                                                          ElevatedButton(
                                                            onPressed: () {
                                                              final val = int.tryParse(ctrl.text.trim());
                                                              if (val != null && val > 0) {
                                                                setState(() {
                                                                  if (val <= stok) {
                                                                    _cart[docId]!['quantity'] = val;
                                                                  } else {
                                                                    _cart[docId]!['quantity'] = stok.toInt();
                                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                                      SnackBar(content: Text('Stok yetersiz! Max: ${stok.toInt()}'), backgroundColor: AppColors.danger),
                                                                    );
                                                                  }
                                                                });
                                                              } else if (val == 0) {
                                                                setState(() => _cart.remove(docId));
                                                              }
                                                              Navigator.pop(ctx);
                                                            },
                                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600, foregroundColor: Colors.white),
                                                            child: const Text('Tamam'),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    alignment: Alignment.center,
                                                    padding: const EdgeInsets.symmetric(horizontal: 6),
                                                    child: Text(qty.toString(), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray800)),
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(Icons.add_rounded, size: 12, color: AppColors.gray600),
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                                  onPressed: () {
                                                    if (qty < stok) {
                                                      setState(() {
                                                        _cart[docId]!['quantity'] = qty + 1;
                                                      });
                                                    } else {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        const SnackBar(content: Text('Yetersiz stok!'), backgroundColor: AppColors.danger),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          ElevatedButton(
                                            onPressed: (stok <= 0)
                                                ? null
                                                : () {
                                                    setState(() {
                                                      _cart[docId] = {
                                                        'id': docId,
                                                        'ad': ad,
                                                        'birim': birim,
                                                        'fiyat': fiyat,
                                                        'stock': stok,
                                                        'firma': productFirma,
                                                        'quantity': 1,
                                                      };
                                                    });
                                                  },
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF2563EB),
                                              foregroundColor: Colors.white,
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            child: Text('Ekle', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: (_selectedUretici != null && _cart.isNotEmpty && !_isSaving)
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Preview list removed as per user request to clean up the bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_cart.length} Ürün Seçildi',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formatCurrency.format(_cartTotal),
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary600),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => _showCartBottomSheet(_selectedUretici!),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Sepeti Gör',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
