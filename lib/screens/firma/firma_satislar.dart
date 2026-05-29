import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

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

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedProducer = producers.first;
        final productCtrl = TextEditingController(text: 'Yem (Çuval)');
        final amountCtrl = TextEditingController(text: '10');
        final priceCtrl = TextEditingController(text: '5000'); // Toplam Tutar veya adet fiyatı
        
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
                    TextField(
                      controller: productCtrl,
                      decoration: const InputDecoration(labelText: 'Satılan Ürün', hintText: 'Örn: Yem, Küspe, Saman'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Miktar (Adet/Kg)', hintText: 'Örn: 10'),
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
                    final product = productCtrl.text.trim();

                    if (selectedProducer == null || product.isEmpty || price <= 0) return;

                    await _db.collection('satislar').add({
                      'uretici': selectedProducer,
                      'urun': product,
                      'miktar': amount,
                      'tutar': price,
                      'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                      'firma': currentFirmaName,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // Decrement stock in urunler
                    final urunSnap = await _db.collection('urunler')
                        .where('firma', isEqualTo: currentFirmaName)
                        .where('ad', isEqualTo: product)
                        .limit(1)
                        .get();
                    if (urunSnap.docs.isNotEmpty) {
                      await urunSnap.docs.first.reference.update({
                        'stok': FieldValue.increment(-amount),
                      });
                    }

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Satış başarıyla kaydedildi! Üretici hesabına borç olarak yansıtıldı.'), backgroundColor: AppColors.success),
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

              await doc.reference.delete();

              // Increment stock back
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
        onTap: _showAddSaleDialog,
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
}
