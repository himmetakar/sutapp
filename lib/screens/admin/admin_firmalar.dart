import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class AdminFirmalar extends StatefulWidget {
  const AdminFirmalar({super.key});

  @override
  State<AdminFirmalar> createState() => _AdminFirmalarState();
}

class _AdminFirmalarState extends State<AdminFirmalar> {
  String? _selectedCariFirmaName;

  @override
  void initState() {
    super.initState();
    _initializeDemoData();
  }

  Future<void> _initializeDemoData() async {
    final db = FirebaseFirestore.instance;
    final firmSnap = await db.collection('firmalar').limit(1).get();
    if (firmSnap.docs.isEmpty) {
      await db.collection('firmalar').add({
        'ad': 'Firma 1',
        'tel': '0532 999 8811',
        'adres': 'Organize Sanayi Bölgesi',
        'yetkili': 'Hakan Yılmaz',
        'tip': 'Alıcı',
      });
      await db.collection('firmalar').add({
        'ad': 'Firma 2',
        'tel': '0532 999 8822',
        'adres': 'Yeni Sanayi Sitesi',
        'yetkili': 'Aylin Kaya',
        'tip': 'Her İkisi',
      });
    }

    final txnSnap = await db.collection('firma_islemleri').limit(1).get();
    if (txnSnap.docs.isEmpty) {
      await db.collection('firma_islemleri').add({
        'firmaAd': 'Firma 1',
        'tip': 'Tahsilat',
        'tutar': 1000000.0,
        'tarih': '26.05.2026',
        'yontem': 'Nakit',
        'aciklama': 'İlk Süt Bedeli Tahsilatı',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await db.collection('firma_islemleri').add({
        'firmaAd': 'Firma 1',
        'tip': 'Ödeme',
        'tutar': 500000.0,
        'tarih': '26.05.2026',
        'yontem': 'Nakit',
        'aciklama': 'Yem Alımı Ödemesi',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  void _showFirmaDialog(BuildContext context, {String? docId, Map<String, dynamic>? existingData}) {
    final formKey = GlobalKey<FormState>();
    final adCtrl = TextEditingController(text: existingData?['ad'] ?? '');
    final telCtrl = TextEditingController(text: existingData?['tel'] ?? '');
    final adresCtrl = TextEditingController(text: existingData?['adres'] ?? '');
    final yetkiliCtrl = TextEditingController(text: existingData?['yetkili'] ?? '');
    String selectedTip = existingData?['tip'] ?? 'Her İkisi';

    DateTime? selectedBitisDate = existingData?['abonelikBitis'] != null
        ? (existingData!['abonelikBitis'] as Timestamp).toDate()
        : DateTime.now().add(const Duration(days: 365));

    final maxPersonelCtrl = TextEditingController(text: (existingData?['maxPersonel'] ?? 10).toString());
    final maxUreticiCtrl = TextEditingController(text: (existingData?['maxUretici'] ?? 100).toString());
    final maxAracCtrl = TextEditingController(text: (existingData?['maxArac'] ?? 5).toString());
    final maxMesajCtrl = TextEditingController(text: (existingData?['maxMesaj'] ?? 20).toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                docId == null ? 'Yeni Firma Ekle' : 'Firmayı Düzenle',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: adCtrl,
                        decoration: const InputDecoration(labelText: 'Firma Adı *'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Lütfen firma adı girin' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: telCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        decoration: const InputDecoration(
                          labelText: 'Telefon *',
                          counterText: '',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Lütfen telefon girin';
                          if (value.trim().length != 11) return 'Telefon numarası 11 haneli olmalıdır';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: yetkiliCtrl,
                        decoration: const InputDecoration(labelText: 'Yetkili Kişi *'),
                        validator: (value) => value == null || value.trim().isEmpty ? 'Lütfen yetkili kişi girin' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: selectedTip,
                        decoration: const InputDecoration(labelText: 'Firma Tipi'),
                        items: const [
                          DropdownMenuItem(value: 'Alıcı', child: Text('Alıcı')),
                          DropdownMenuItem(value: 'Satıcı', child: Text('Satıcı')),
                          DropdownMenuItem(value: 'Her İkisi', child: Text('Her İkisi')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedTip = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: adresCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Adres'),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          'Abonelik Bitiş: ${selectedBitisDate != null ? DateFormat('dd.MM.yyyy').format(selectedBitisDate!) : 'Seçilmedi'}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedBitisDate ?? DateTime.now(),
                              firstDate: DateTime.now().subtract(const Duration(days: 365)),
                              lastDate: DateTime.now().add(const Duration(days: 3650)),
                            );
                            if (picked != null) {
                              setDialogState(() {
                                selectedBitisDate = picked;
                              });
                            }
                          },
                          child: const Text('Seç'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: maxPersonelCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Maks. Personel Sayısı *'),
                        validator: (value) => value == null || int.tryParse(value) == null ? 'Geçerli bir sayı girin' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: maxUreticiCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Maks. Üretici Sayısı *'),
                        validator: (value) => value == null || int.tryParse(value) == null ? 'Geçerli bir sayı girin' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: maxAracCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Maks. Araç Sayısı *'),
                        validator: (value) => value == null || int.tryParse(value) == null ? 'Geçerli bir sayı girin' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: maxMesajCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Maks. Mesaj Gönderimi *'),
                        validator: (value) => value == null || int.tryParse(value) == null ? 'Geçerli bir sayı girin' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final data = {
                        'ad': adCtrl.text.trim(),
                        'tel': telCtrl.text.trim(),
                        'yetkili': yetkiliCtrl.text.trim(),
                        'tip': selectedTip,
                        'adres': adresCtrl.text.trim(),
                        'abonelikBitis': selectedBitisDate != null ? Timestamp.fromDate(selectedBitisDate!) : null,
                        'maxPersonel': int.parse(maxPersonelCtrl.text.trim()),
                        'maxUretici': int.parse(maxUreticiCtrl.text.trim()),
                        'maxArac': int.parse(maxAracCtrl.text.trim()),
                        'maxMesaj': int.parse(maxMesajCtrl.text.trim()),
                        if (docId == null) 'createdAt': FieldValue.serverTimestamp(),
                      };

                      if (docId == null) {
                        await FirebaseFirestore.instance.collection('firmalar').add(data);
                      } else {
                        await FirebaseFirestore.instance.collection('firmalar').doc(docId).update(data);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _confirmDeleteFirma(BuildContext context, String docId, String firmaAd) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('Firmayı Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          '"$firmaAd" firmasını silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Vazgeç', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('firmalar').doc(docId).delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$firmaAd silindi.'),
                    backgroundColor: Colors.red[700],
                  ),
                );
              }
            },
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTransaction(BuildContext context, String docId, String tip, double tutar) {
    final fmt = NumberFormat('#,##0.00', 'tr_TR');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text('İşlemi Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          '"$tip — ${fmt.format(tutar)} ₺" kaydını silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz.',
          style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray700),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Vazgeç', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('firma_islemleri').doc(docId).delete();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('İşlem silindi.'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );
  }

  void _showTransactionDialog(
    BuildContext context,
    String txnType, {
    String? docId,
    Map<String, dynamic>? existingTxnData,
  }) {
    final isEditing = docId != null;
    final formKey = GlobalKey<FormState>();
    final tutarCtrl = TextEditingController(
      text: existingTxnData != null
          ? (existingTxnData['tutar'] as num?)?.toString() ?? ''
          : '',
    );
    final aciklamaCtrl = TextEditingController(
      text: existingTxnData?['aciklama'] ?? '',
    );
    String? selectedFirma = existingTxnData?['firmaAd'];
    String selectedYontem = existingTxnData?['yontem'] ?? 'Nakit';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                isEditing ? 'İşlemi Düzenle' : '$txnType Ekle',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: txnType == 'Tahsilat' ? AppColors.successDark : AppColors.dangerDark,
                ),
              ),
              content: Form(
                key: formKey,
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('firmalar').snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final companies = snapshot.data!.docs.map((doc) => doc['ad'] as String).toList();
                    if (companies.isEmpty) {
                      return const Center(child: Text('Lütfen önce bir firma ekleyin.'));
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedFirma,
                          hint: const Text('Firma Seçin *'),
                          items: companies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (val) {
                            setDialogState(() {
                              selectedFirma = val;
                            });
                          },
                          validator: (value) => value == null ? 'Lütfen firma seçin' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: tutarCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Tutar (₺) *'),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Lütfen tutar girin';
                            if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Geçerli bir sayı girin';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedYontem,
                          decoration: const InputDecoration(labelText: 'Ödeme Yöntemi'),
                          items: const [
                            DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
                            DropdownMenuItem(value: 'Banka', child: Text('Banka Transferi')),
                            DropdownMenuItem(value: 'Çek', child: Text('Çek')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedYontem = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: aciklamaCtrl,
                          decoration: const InputDecoration(labelText: 'Açıklama'),
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: txnType == 'Tahsilat' ? AppColors.success : AppColors.danger,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate() && selectedFirma != null) {
                      final double tutar = double.parse(tutarCtrl.text.replaceAll(',', '.'));
                      final data = {
                        'firmaAd': selectedFirma,
                        'tip': txnType,
                        'tutar': tutar,
                        'yontem': selectedYontem,
                        'aciklama': aciklamaCtrl.text.trim(),
                        'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                        if (!isEditing) 'timestamp': FieldValue.serverTimestamp(),
                      };
                      if (isEditing) {
                        await FirebaseFirestore.instance
                            .collection('firma_islemleri')
                            .doc(docId)
                            .update(data);
                      } else {
                        data['timestamp'] = FieldValue.serverTimestamp();
                        await FirebaseFirestore.instance
                            .collection('firma_islemleri')
                            .add(data);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(isEditing ? 'Güncelle' : 'Kaydet'),
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
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.gray50,
        appBar: AppBar(
          title: Text(
            'Firma Yönetimi',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary600,
            unselectedLabelColor: AppColors.gray500,
            indicatorColor: AppColors.primary600,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(Icons.business_rounded, size: 18), text: 'Firmalar'),
              Tab(icon: Icon(Icons.receipt_long_rounded, size: 18), text: 'Cari Hesap'),
              Tab(icon: Icon(Icons.payments_rounded, size: 18), text: 'Ödemeler'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // TAB 1: FIRMALAR
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('firmalar').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton.icon(
                        onPressed: () => _showFirmaDialog(context),
                        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                        label: Text('Yeni Firma Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 44),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: docs.isEmpty
                          ? Center(child: Text('Kayıtlı firma bulunmuyor.', style: GoogleFonts.inter(color: AppColors.gray500)))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: docs.length,
                              itemBuilder: (context, index) {
                                final doc = docs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final String ad = data['ad'] ?? '';
                                final String tip = data['tip'] ?? 'Her İkisi';

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: AppShadows.sm,
                                    border: Border.all(color: AppColors.gray200),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(ad, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gray900)),
                                            const SizedBox(height: 8),
                                            StatusBadge(
                                              label: tip,
                                              color: Colors.white,
                                              bgColor: tip == 'Alıcı'
                                                  ? const Color(0xFF3B82F6)
                                                  : tip == 'Satıcı'
                                                      ? const Color(0xFFF59E0B)
                                                      : const Color(0xFF8B5CF6),
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => _showFirmaDialog(context, docId: doc.id, existingData: data),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.edit_outlined,
                                            color: Color(0xFF3B82F6),
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () => _confirmDeleteFirma(context, doc.id, ad),
                                        child: Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Color(0xFFEF4444),
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),

            // TAB 2: CARI HESAP
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('firmalar').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final companies = snapshot.data?.docs ?? [];
                if (companies.isEmpty) {
                  return Center(child: Text('Önce firma eklemelisiniz.', style: GoogleFonts.inter(color: AppColors.gray500)));
                }

                if (_selectedCariFirmaName != null) {
                  // Detailed statement view
                  QueryDocumentSnapshot? companyDoc;
                  for (var d in companies) {
                    if (d['ad'] == _selectedCariFirmaName) {
                      companyDoc = d;
                      break;
                    }
                  }
                  companyDoc ??= companies.first;
                  final compData = companyDoc.data() as Map<String, dynamic>;
                  final tel = compData['tel'] ?? '-';
                  final yetkili = compData['yetkili'] ?? '-';
                  final adres = compData['adres'] ?? '-';

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('firma_islemleri')
                        .where('firmaAd', isEqualTo: _selectedCariFirmaName)
                        .snapshots(),
                    builder: (context, txSnap) {
                      final txDocs = txSnap.data?.docs ?? [];
                      double totalTahsilat = 0.0;
                      double totalOdeme = 0.0;

                      for (var doc in txDocs) {
                        final data = doc.data() as Map<String, dynamic>;
                        final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                        if (data['tip'] == 'Tahsilat') {
                          totalTahsilat += tutar;
                        } else {
                          totalOdeme += tutar;
                        }
                      }
                      final double net = totalTahsilat - totalOdeme;

                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          Row(
                            children: [
                              InkWell(
                                onTap: () => setState(() => _selectedCariFirmaName = null),
                                borderRadius: BorderRadius.circular(8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.arrow_back_rounded, size: 16, color: AppColors.primary600),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Firma Seçimine Dön',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Company Header Card
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.gray200),
                              boxShadow: AppShadows.sm,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _selectedCariFirmaName!,
                                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                    ),
                                    StatusBadge(
                                      label: compData['tip'] ?? 'Her İkisi',
                                      color: Colors.white,
                                      bgColor: (compData['tip'] == 'Alıcı')
                                          ? const Color(0xFF3B82F6)
                                          : (compData['tip'] == 'Satıcı')
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF8B5CF6),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.phone_outlined, size: 14, color: AppColors.gray400),
                                    const SizedBox(width: 6),
                                    Text('Tel: $tel', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.person_outline_rounded, size: 14, color: AppColors.gray400),
                                    const SizedBox(width: 6),
                                    Text('Yetkili: $yetkili', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 14, color: AppColors.gray400),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text('Adres: $adres', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Detailed Metrics Grid Card
                          FutureBuilder<Map<String, dynamic>>(
                            future: _loadDetailedFirmaMetrics(_selectedCariFirmaName!),
                            builder: (context, metricSnap) {
                              if (!metricSnap.hasData) {
                                return const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              final metrics = metricSnap.data!;
                              final fmtNum = NumberFormat('#,##0', 'tr_TR');
                              final fmtLitre = NumberFormat('#,##0.0', 'tr_TR');

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.gray200),
                                  boxShadow: AppShadows.sm,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Firma İstatistikleri & Performans',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                    ),
                                    const SizedBox(height: 12),
                                    GridView.count(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      childAspectRatio: 2.2,
                                      children: [
                                        _buildMetricGridItem('Kayıtlı Üretici', '${metrics['ureticiCount']} üretici', Icons.people_rounded, Colors.blue),
                                        _buildMetricGridItem('Toplam Personel', '${metrics['personelCount']} çalışan', Icons.badge_rounded, Colors.teal),
                                        _buildMetricGridItem('Araç Sayısı', '${metrics['aracCount']} araç', Icons.local_shipping_rounded, Colors.amber),
                                        _buildMetricGridItem('Tank Sayısı', '${metrics['tankCount']} tank', Icons.speed_rounded, Colors.cyan),
                                        _buildMetricGridItem('Aylık Süt', '${fmtLitre.format(metrics['aylikSut'])} LT', Icons.water_drop_rounded, Colors.indigo),
                                        _buildMetricGridItem('Süt Satış Tutarı', '${fmtNum.format(metrics['sutSatisTutari'])} ₺', Icons.monetization_on_rounded, Colors.green),
                                        _buildMetricGridItem('Ürün Satış Tutarı', '${fmtNum.format(metrics['urunSatisTutari'])} ₺', Icons.category_rounded, Colors.purple),
                                        _buildMetricGridItem('Hesaplanan Net Kar', '${fmtNum.format(metrics['netKar'])} ₺', Icons.analytics_rounded, metrics['netKar'] >= 0 ? Colors.green : Colors.red),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          // Summary metrics box
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text('Toplam Tahsilat', style: GoogleFonts.inter(fontSize: 10, color: Colors.green[800], fontWeight: FontWeight.w600)),
                                      Text('${formatNumber.format(totalTahsilat)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green[900])),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text('Toplam Ödeme', style: GoogleFonts.inter(fontSize: 10, color: Colors.red[800], fontWeight: FontWeight.w600)),
                                      Text('${formatNumber.format(totalOdeme)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red[900])),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: net >= 0 ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(net >= 0 ? 'Net Bakiye (Alacak):' : 'Net Bakiye (Borç):', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: net >= 0 ? Colors.green[800] : Colors.red[800])),
                                Text('${formatNumber.format(net.abs())} ₺', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 14, color: net >= 0 ? Colors.green[800] : Colors.red[800])),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text('İşlem Geçmişi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 8),
                          txDocs.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(24.0),
                                    child: Text(
                                      'Kayıt bulunmuyor.',
                                      style: GoogleFonts.inter(color: AppColors.gray400),
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: txDocs.length,
                                  itemBuilder: (context, idx) {
                                    final tx = txDocs[idx];
                                    final txData = tx.data() as Map<String, dynamic>;
                                    final double tutar = (txData['tutar'] as num?)?.toDouble() ?? 0.0;
                                    final tip = txData['tip'] ?? 'Tahsilat';
                                    final date = txData['tarih'] ?? '';
                                    final yontem = txData['yontem'] ?? 'Nakit';
                                    final desc = txData['aciklama'] ?? '';

                                    final isTahsilat = tip == 'Tahsilat';
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.gray200),
                                        boxShadow: AppShadows.sm,
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: isTahsilat
                                                  ? AppColors.successLight
                                                  : AppColors.dangerLight,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              isTahsilat
                                                  ? Icons.arrow_downward_rounded
                                                  : Icons.arrow_upward_rounded,
                                              color: isTahsilat
                                                  ? AppColors.successDark
                                                  : AppColors.dangerDark,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isTahsilat ? 'Tahsilat ($yontem)' : 'Ödeme ($yontem)',
                                                  style: GoogleFonts.inter(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                    color: AppColors.gray800,
                                                  ),
                                                ),
                                                if (desc.isNotEmpty) ...[
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    desc,
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: AppColors.gray500,
                                                    ),
                                                  ),
                                                ],
                                                const SizedBox(height: 2),
                                                Text(
                                                  date,
                                                  style: GoogleFonts.inter(
                                                    fontSize: 10,
                                                    color: AppColors.gray400,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            '${isTahsilat ? "+" : "-"}${formatNumber.format(tutar)} ₺',
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isTahsilat ? Colors.green[700] : Colors.red[700],
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
                  );
                }

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    const Icon(Icons.business_rounded, size: 72, color: AppColors.primary500),
                    const SizedBox(height: 12),
                    Text('Firma Seçin', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gray800)),
                    const SizedBox(height: 4),
                    Text('Cari hesap için önce bir firma seçin', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: companies.length,
                        itemBuilder: (context, index) {
                          final doc = companies[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String name = data['ad'] ?? '';

                          return GestureDetector(
                            onTap: () => setState(() => _selectedCariFirmaName = name),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                boxShadow: AppShadows.sm,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.gray800,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: AppColors.gray400,
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

            // TAB 3: ODEMELER
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showTransactionDialog(context, 'Tahsilat'),
                          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                          label: Text('Tahsilat', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _showTransactionDialog(context, 'Satış'),
                          icon: const Icon(Icons.remove_rounded, color: Colors.white, size: 18),
                          label: Text('Satış', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('firma_islemleri')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(child: Text('Kayıtlı ödeme/tahsilat bulunmuyor.', style: GoogleFonts.inter(color: AppColors.gray500)));
                      }

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final String name = data['firmaAd'] ?? '';
                          final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                          final String tip = data['tip'] ?? 'Tahsilat';
                          final String yontem = data['yontem'] ?? 'Nakit';
                          final String tarih = data['tarih'] ?? '';
                          final String aciklama = data['aciklama'] ?? '';

                          final isTahsilat = tip == 'Tahsilat';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppShadows.sm,
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: AppColors.gray800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          StatusBadge(
                                            label: tip,
                                            color: Colors.white,
                                            bgColor: isTahsilat ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      '${isTahsilat ? "+" : "-"}${formatNumber.format(tutar)} ₺',
                                      style: GoogleFonts.inter(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: isTahsilat ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    const Icon(Icons.calendar_month_outlined, size: 14, color: AppColors.gray400),
                                    const SizedBox(width: 4),
                                    Text(
                                      tarih,
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                    ),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.credit_card_outlined, size: 14, color: AppColors.gray400),
                                    const SizedBox(width: 4),
                                    Text(
                                      yontem,
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                    ),
                                  ],
                                ),
                                if (aciklama.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    aciklama,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.gray400,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 10),
                                // Action buttons row
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    // Edit button
                                    GestureDetector(
                                      onTap: () => _showTransactionDialog(
                                        context,
                                        tip,
                                        docId: doc.id,
                                        existingTxnData: data,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.edit_outlined, color: Color(0xFF3B82F6), size: 14),
                                            const SizedBox(width: 4),
                                            Text('Düzenle', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6))),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // Delete button
                                    GestureDetector(
                                      onTap: () => _confirmDeleteTransaction(context, doc.id, tip, tutar),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF2F2),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 14),
                                            const SizedBox(width: 4),
                                            Text('Sil', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                                          ],
                                        ),
                                      ),
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
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _loadDetailedFirmaMetrics(String firmaName) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final startOfMonthTs = Timestamp.fromDate(startOfMonth);

    try {
      // 1. Üretici sayısı
      final ureticiSnap = await FirebaseFirestore.instance
          .collection('ureticiler')
          .where('firmalar', arrayContains: firmaName)
          .get();
      final ureticiCount = ureticiSnap.docs.length;

      // 2. Personel sayısı
      final personelSnap = await FirebaseFirestore.instance
          .collection('suruculer')
          .where('firma', isEqualTo: firmaName)
          .get();
      final personelCount = personelSnap.docs.length;

      // 3. Araç sayısı
      final aracSnap = await FirebaseFirestore.instance
          .collection('araclar')
          .where('firma', isEqualTo: firmaName)
          .get();
      final aracCount = aracSnap.docs.length;

      // 4. Tank sayısı
      final tankSnap = await FirebaseFirestore.instance
          .collection('tanklar')
          .where('firma', isEqualTo: firmaName)
          .get();
      final tankCount = tankSnap.docs.length;

      // 5. Aylık süt miktarı (Litre)
      final colSnap = await FirebaseFirestore.instance
          .collection('toplamalar')
          .where('firma', isEqualTo: firmaName)
          .where('timestamp', isGreaterThanOrEqualTo: startOfMonthTs)
          .get();
      double aylikSut = 0.0;
      for (var doc in colSnap.docs) {
        final val = doc.data()['m'];
        if (val is num) aylikSut += val.toDouble();
      }

      // 6. Süt satış tutarı (satislar total)
      final satisSnap = await FirebaseFirestore.instance
          .collection('satislar')
          .where('firma', isEqualTo: firmaName)
          .get();
      double sutSatisTutari = 0.0;
      for (var doc in satisSnap.docs) {
        final val = doc.data()['toplam'] ?? doc.data()['tutar'];
        if (val is num) sutSatisTutari += val.toDouble();
      }

      // 7. Ürün satış tutarı (yem kesintileri total)
      final kesintiSnap = await FirebaseFirestore.instance
          .collection('kesintiler')
          .where('firma', isEqualTo: firmaName)
          .get();
      double urunSatisTutari = 0.0;
      for (var doc in kesintiSnap.docs) {
        final data = doc.data();
        if (data['durum'] == 'iptal') continue;
        final val = data['tutar'];
        final String tur = data['kesintiTuru'] as String? ?? 'Yem Kesintisi';
        if (tur.contains('Yem') && val is num) {
          urunSatisTutari += val.toDouble();
        }
      }

      // 8. Toplam süt alım bedeli (Expenses -> what we owe producers)
      final priceSnap = await FirebaseFirestore.instance
          .collection('sut_fiyatlari')
          .where('firma', isEqualTo: firmaName)
          .get();
      final prices = priceSnap.docs.map((doc) => doc.data()).toList();
      
      final producersMap = {
        for (var doc in ureticiSnap.docs)
          doc['name'] as String: doc.data()
      };

      final firestoreService = FirestoreService();
      double totalMilkCost = 0.0;

      final allToplamalar = await FirebaseFirestore.instance
          .collection('toplamalar')
          .where('firma', isEqualTo: firmaName)
          .get();

      for (var doc in allToplamalar.docs) {
        final data = doc.data();
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
        totalMilkCost += m * price;
      }

      // 9. Diğer giderler (giderler total)
      final expensesSnap = await FirebaseFirestore.instance
          .collection('giderler')
          .where('firma', isEqualTo: firmaName)
          .get();
      double digerGiderler = 0.0;
      for (var doc in expensesSnap.docs) {
        final val = doc.data()['tutar'];
        if (val is num) digerGiderler += val.toDouble();
      }

      // 9b. Add cari_islemler (odeme to suppliers) to digerGiderler
      final cariIslemSnap = await FirebaseFirestore.instance
          .collection('cari_islemler')
          .where('firma', isEqualTo: firmaName)
          .where('tip', isEqualTo: 'odeme')
          .get();
      for (var doc in cariIslemSnap.docs) {
        final val = doc.data()['tutar'];
        if (val is num) digerGiderler += val.toDouble();
      }

      // Net kar
      final double toplamGelir = sutSatisTutari + urunSatisTutari;
      final double toplamGider = totalMilkCost + digerGiderler;
      final double netKar = toplamGelir - toplamGider;

      return {
        'ureticiCount': ureticiCount,
        'personelCount': personelCount,
        'aracCount': aracCount,
        'tankCount': tankCount,
        'aylikSut': aylikSut,
        'sutSatisTutari': sutSatisTutari,
        'urunSatisTutari': urunSatisTutari,
        'netKar': netKar,
      };
    } catch (e) {
      print('Error calculating company metrics: $e');
      return {
        'ureticiCount': 0,
        'personelCount': 0,
        'aracCount': 0,
        'tankCount': 0,
        'aylikSut': 0.0,
        'sutSatisTutari': 0.0,
        'urunSatisTutari': 0.0,
        'netKar': 0.0,
      };
    }
  }

  Widget _buildMetricGridItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.gray800, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
