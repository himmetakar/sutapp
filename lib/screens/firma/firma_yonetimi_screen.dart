import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

// --- MAIN FIRMA YONETIMI SCREEN ---
class FirmaYonetimiScreen extends StatefulWidget {
  const FirmaYonetimiScreen({super.key});

  @override
  State<FirmaYonetimiScreen> createState() => _FirmaYonetimiScreenState();
}

class _FirmaYonetimiScreenState extends State<FirmaYonetimiScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  String _selectedTab = 'tumu'; // 'tumu' | 'alici' | 'tedarikci'

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // Combines the four required streams reactively
  Stream<List<QuerySnapshot>> _combineStreams(String tenantFirma) {
    final s1 = _db.collection('cari_firmalar').where('firma', isEqualTo: tenantFirma).snapshots();
    final s2 = _db.collection('faturalar').where('firma', isEqualTo: tenantFirma).snapshots();
    final s3 = _db.collection('sut_satislari').where('firma', isEqualTo: tenantFirma).snapshots();
    final s4 = _db.collection('cari_islemler').where('firma', isEqualTo: tenantFirma).snapshots();

    final controller = StreamController<List<QuerySnapshot>>();
    final latestResults = List<QuerySnapshot?>.filled(4, null);
    final subscriptions = <StreamSubscription>[];

    final streams = [s1, s2, s3, s4];
    for (int i = 0; i < streams.length; i++) {
      final sub = streams[i].listen(
        (data) {
          latestResults[i] = data;
          if (latestResults.every((res) => res != null)) {
            if (!controller.isClosed) {
              controller.add(latestResults.cast<QuerySnapshot>());
            }
          }
        },
        onError: (err) {
          if (!controller.isClosed) {
            controller.addError(err);
          }
        },
      );
      subscriptions.add(sub);
    }

    controller.onCancel = () {
      for (var sub in subscriptions) {
        sub.cancel();
      }
    };

    return controller.stream;
  }

  void _showAddEditCompanyDialog({DocumentSnapshot? doc}) {
    final data = doc?.data() as Map<String, dynamic>?;
    final adCtrl = TextEditingController(text: data?['ad'] ?? '');
    final telCtrl = TextEditingController(text: data?['tel'] ?? '');
    final emailCtrl = TextEditingController(text: data?['eposta'] ?? '');
    final adresCtrl = TextEditingController(text: data?['adres'] ?? '');
    String tip = data?['tip'] ?? 'alici';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(doc == null ? 'Yeni Cari Tanımla' : 'Cari Kartı Düzenle',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: adCtrl,
                      decoration: const InputDecoration(labelText: 'Firma Unvanı / Adı *'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: tip,
                      decoration: const InputDecoration(labelText: 'Cari Tipi'),
                      items: const [
                        DropdownMenuItem(value: 'alici', child: Text('Alıcı (Süt Müşterisi)')),
                        DropdownMenuItem(value: 'tedarikci', child: Text('Tedarikçi (Yem vb.)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => tip = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: telCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 11,
                      decoration: const InputDecoration(
                        labelText: 'Telefon Numarası',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'E-posta Adresi'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: adresCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Adres'),
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
                  onPressed: () async {
                    final ad = adCtrl.text.trim();
                    if (ad.isEmpty) return;

                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final tenantFirma = auth.user?.displayName ?? '';

                    final docData = {
                      'ad': ad,
                      'tip': tip,
                      'tel': telCtrl.text.trim(),
                      'eposta': emailCtrl.text.trim(),
                      'adres': adresCtrl.text.trim(),
                      'firma': tenantFirma,
                      'timestamp': FieldValue.serverTimestamp(),
                    };

                    if (doc == null) {
                      await _db.collection('cari_firmalar').add(docData);
                    } else {
                      await doc.reference.update(docData);
                    }

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(doc == null ? 'Cari başarıyla eklendi!' : 'Cari güncellendi!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteCompany(DocumentSnapshot doc) {
    final name = (doc.data() as Map<String, dynamic>)['ad'] ?? '';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cari Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('"$name" firmasını silmek istediğinize emin misiniz? Bu işlem şirkete bağlı fatura ve ödeme kayıtlarını silmez ancak cari listesinden kaldırır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cari silindi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  void _showAddTransactionDialog(String companyName, String type) {
    final tutarCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController();
    String odemeYontemi = 'Nakit';
    DateTime secilenTarih = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(type == 'odeme' ? 'Ödeme Yap ($companyName)' : 'Tahsilat Girişi ($companyName)',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: tutarCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tutar (₺) *', suffixText: '₺'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: odemeYontemi,
                      decoration: const InputDecoration(labelText: 'Ödeme/Tahsilat Yöntemi'),
                      items: const [
                        DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
                        DropdownMenuItem(value: 'Banka Transferi', child: Text('Banka Transferi / Havale')),
                        DropdownMenuItem(value: 'Çek', child: Text('Çek')),
                        DropdownMenuItem(value: 'Kredi Kartı', child: Text('Kredi Kartı')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => odemeYontemi = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: secilenTarih,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(() => secilenTarih = picked);
                        }
                      },
                      child: AbsorbPointer(
                        child: TextField(
                          decoration: InputDecoration(
                            labelText: 'Tarih',
                            suffixIcon: const Icon(Icons.calendar_month_rounded),
                            hintText: DateFormat('dd.MM.yyyy').format(secilenTarih),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: aciklamaCtrl,
                      maxLines: 2,
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
                  onPressed: () async {
                    final double? tutar = double.tryParse(tutarCtrl.text.replaceAll(',', '.'));
                    if (tutar == null || tutar <= 0) return;

                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final tenantFirma = auth.user?.displayName ?? '';

                    await _db.collection('cari_islemler').add({
                      'cariFirmaName': companyName,
                      'tutar': tutar,
                      'tip': type,
                      'odemeYontemi': odemeYontemi,
                      'aciklama': aciklamaCtrl.text.trim(),
                      'tarih': DateFormat('dd.MM.yyyy').format(secilenTarih),
                      'firma': tenantFirma,
                      'timestamp': Timestamp.fromDate(secilenTarih),
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(type == 'odeme' ? 'Ödeme başarıyla kaydedildi!' : 'Tahsilat başarıyla kaydedildi!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: type == 'odeme' ? Colors.red[600] : Colors.green[600],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(type == 'odeme' ? 'Ödemeyi Kaydet' : 'Tahsilatı Kaydet'),
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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenantFirma = auth.user?.displayName ?? '';
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return Scaffold(
      backgroundColor: AppColors.gray50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditCompanyDialog(),
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Yeni Cari Kaydı'),
      ),
      body: StreamBuilder<List<QuerySnapshot>>(
        stream: _combineStreams(tenantFirma),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Bir hata oluştu: ${snapshot.error}'));
          }

          final companiesDocs = snapshot.data?[0].docs ?? [];
          final invoicesDocs = snapshot.data?[1].docs ?? [];
          final milkSalesDocs = snapshot.data?[2].docs ?? [];
          final cariIslemlerDocs = snapshot.data?[3].docs ?? [];

          // Compute balances dynamically in-memory
          final Map<String, double> companyBalances = {};
          for (var doc in companiesDocs) {
            final name = (doc.data() as Map<String, dynamic>)['ad'] as String;
            companyBalances[name] = 0.0;
          }

          // 1. Process Invoices
          for (var inv in invoicesDocs) {
            final data = inv.data() as Map<String, dynamic>;
            final companyName = data['tedarikci'] as String? ?? '';
            final double total = (data['toplam'] as num?)?.toDouble() ?? 0.0;
            final type = data['tip'] as String? ?? 'alis';
            final status = data['durum'] as String? ?? 'aktif';

            if (status == 'iptal') continue;

            if (companyBalances.containsKey(companyName)) {
              if (type == 'alis') {
                companyBalances[companyName] = companyBalances[companyName]! - total;
              } else {
                companyBalances[companyName] = companyBalances[companyName]! + total;
              }
            }
          }

          // 2. Process Milk Sales
          for (var sale in milkSalesDocs) {
            final data = sale.data() as Map<String, dynamic>;
            final companyName = data['aliciFirma'] as String? ?? '';
            final double total = (data['toplam'] as num?)?.toDouble() ?? 0.0;

            if (companyBalances.containsKey(companyName)) {
              companyBalances[companyName] = companyBalances[companyName]! + total;
            }
          }

          // 3. Process Payments & Collections
          for (var tx in cariIslemlerDocs) {
            final data = tx.data() as Map<String, dynamic>;
            final companyName = data['cariFirmaName'] as String? ?? '';
            final double total = (data['tutar'] as num?)?.toDouble() ?? 0.0;
            final type = data['tip'] as String? ?? 'odeme';

            if (companyBalances.containsKey(companyName)) {
              if (type == 'odeme') {
                companyBalances[companyName] = companyBalances[companyName]! + total;
              } else {
                companyBalances[companyName] = companyBalances[companyName]! - total;
              }
            }
          }

          // Calculate summary stats
          double totalAlacak = 0.0; // What we are owed (positive balances)
          double totalBorc = 0.0;   // What we owe (negative balances)

          companyBalances.forEach((name, bal) {
            if (bal > 0) {
              totalAlacak += bal;
            } else if (bal < 0) {
              totalBorc += bal.abs();
            }
          });

          double netDenge = totalAlacak - totalBorc;

          // Filter companies
          final List<DocumentSnapshot> filteredCompanies = companiesDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['ad'] as String? ?? '').toLowerCase();
            final type = data['tip'] as String? ?? 'alici';

            final matchesSearch = name.contains(_searchQuery);
            final matchesTab = _selectedTab == 'tumu' || type == _selectedTab;

            return matchesSearch && matchesTab;
          }).toList();

          return Column(
            children: [
              // Summary Banner
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shadow: AppShadows.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Alacaklarımız', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('${formatNumber.format(totalAlacak)} ₺',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green[700])),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shadow: AppShadows.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Borçlarımız', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('${formatNumber.format(totalBorc)} ₺',
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red[700])),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppCard(
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                        shadow: AppShadows.sm,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Cari Denge', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500, fontWeight: FontWeight.w500)),
                            const SizedBox(height: 4),
                            Text('${formatNumber.format(netDenge)} ₺',
                                style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: netDenge >= 0 ? AppColors.primary600 : Colors.deepOrange)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Filter Tabs & Search
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.toLowerCase().trim();
                          });
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded, size: 20),
                          hintText: 'Cari firma ara...',
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                child: Row(
                  children: [
                    _buildTabButton('tumu', 'Tümü'),
                    const SizedBox(width: 8),
                    _buildTabButton('alici', 'Alıcılar'),
                    const SizedBox(width: 8),
                    _buildTabButton('tedarikci', 'Tedarikçiler'),
                  ],
                ),
              ),

              // List View
              Expanded(
                child: filteredCompanies.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.business_rounded, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Kayıtlı cari firma bulunamadı.',
                                style: GoogleFonts.inter(color: AppColors.gray400, fontSize: 13)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 80),
                        itemCount: filteredCompanies.length,
                        itemBuilder: (context, index) {
                          final doc = filteredCompanies[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = data['ad'] ?? '';
                          final type = data['tip'] ?? 'alici';
                          final phone = data['tel'] ?? '';
                          final address = data['adres'] ?? '';

                          final balance = companyBalances[name] ?? 0.0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: AppShadows.sm,
                              border: Border.all(color: AppColors.gray100, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header: Title & Badges
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: GoogleFonts.inter(
                                            fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray900),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: type == 'alici' ? Colors.blue[50] : Colors.orange[50],
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        type == 'alici' ? 'Alıcı' : 'Tedarikçi',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: type == 'alici' ? Colors.blue[700] : Colors.orange[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Phone & Address Info
                                if (phone.isNotEmpty || address.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      if (phone.isNotEmpty) ...[
                                        Icon(Icons.phone_rounded, size: 13, color: AppColors.gray400),
                                        const SizedBox(width: 4),
                                        Text(phone, style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                                        const SizedBox(width: 16),
                                      ],
                                      if (address.isNotEmpty) ...[
                                        Icon(Icons.location_on_rounded, size: 13, color: AppColors.gray400),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            address,
                                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                ],

                                // Divider
                                const Divider(),
                                const SizedBox(height: 12),

                                // Balance Row & Actions
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Balance info
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Cari Bakiye',
                                            style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400, fontWeight: FontWeight.w500)),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${formatNumber.format(balance.abs())} ₺',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                            color: balance > 0
                                                ? Colors.green[700]
                                                : balance < 0
                                                    ? Colors.red[700]
                                                    : AppColors.gray700,
                                          ),
                                        ),
                                        Text(
                                          balance > 0
                                              ? 'Bize Borçlu'
                                              : balance < 0
                                                  ? 'Bizden Alacaklı'
                                                  : 'Hesap Dengede',
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            color: balance > 0
                                                ? Colors.green[600]
                                                : balance < 0
                                                    ? Colors.red[600]
                                                    : AppColors.gray400,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Quick action buttons
                                    Row(
                                      children: [
                                        if (type == 'alici')
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.green[50],
                                              foregroundColor: Colors.green[700],
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _showAddTransactionDialog(name, 'tahsilat'),
                                            icon: const Icon(Icons.download_rounded, size: 14),
                                            label: Text('Tahsilat Gir', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                                          ),
                                        if (type == 'tedarikci')
                                          ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.red[50],
                                              foregroundColor: Colors.red[700],
                                              elevation: 0,
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => _showAddTransactionDialog(name, 'odeme'),
                                            icon: const Icon(Icons.upload_rounded, size: 14),
                                            label: Text('Ödeme Yap', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                                          ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          icon: const Icon(Icons.receipt_long_rounded, color: AppColors.primary600, size: 20),
                                          style: IconButton.styleFrom(
                                            backgroundColor: AppColors.primary50,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          onPressed: () => context.push('/firma/yonetimi/ekstre?name=${Uri.encodeComponent(name)}'),
                                        ),
                                        PopupMenuButton<String>(
                                          icon: Icon(Icons.more_vert_rounded, color: AppColors.gray500, size: 18),
                                          onSelected: (action) {
                                            if (action == 'edit') {
                                              _showAddEditCompanyDialog(doc: doc);
                                            } else if (action == 'delete') {
                                              _deleteCompany(doc);
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_rounded, size: 16), SizedBox(width: 8), Text('Düzenle')])),
                                            PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline_rounded, color: Colors.red[700], size: 16), const SizedBox(width: 8), Text('Sil', style: TextStyle(color: Colors.red))])),
                                          ],
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
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTabButton(String tab, String title) {
    final bool isSelected = _selectedTab == tab;
    return ChoiceChip(
      label: Text(title),
      selected: isSelected,
      onSelected: (val) {
        if (val) setState(() => _selectedTab = tab);
      },
      selectedColor: AppColors.primary600,
      backgroundColor: Colors.white,
      labelStyle: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: isSelected ? Colors.white : AppColors.gray600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: isSelected ? Colors.transparent : AppColors.gray200),
      ),
      showCheckmark: false,
    );
  }
}

// --- DETAILED CARI EKSTRE SCREEN ---
class FirmaCariEkstreScreen extends StatefulWidget {
  final String? companyName;
  const FirmaCariEkstreScreen({super.key, this.companyName});

  @override
  State<FirmaCariEkstreScreen> createState() => _FirmaCariEkstreScreenState();
}

class _FirmaCariEkstreScreenState extends State<FirmaCariEkstreScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DateTimeRange? _selectedDateRange;

  Future<void> _deleteCariIslem(DocumentSnapshot doc) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('İşlemi Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu ödeme/tahsilat işlemini silmek istediğinize emin misiniz? Cari bakiye yeniden hesaplanacaktır.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('İşlem silindi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  // Generates and layouts PDF document for printing
  Future<void> _printPdfStatement(
    String partnerName,
    String partnerTip,
    double finalBalance,
    List<Map<String, dynamic>> sortedTransactions,
    String tenantFirmaName,
  ) async {
    final doc = pw.Document();
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (pw.Context context) {
          return [
            // Company Header Logo/Name
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(tenantFirmaName.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text('Cari Hesap Hesap Ekstresi', style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Rapor Tarihi: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 10),

            // Partner details box
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Müşteri/Tedarikçi: $partnerName', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 2),
                      pw.Text('Kart Tipi: ${partnerTip == 'alici' ? 'Alıcı (Süt Sattığımız)' : 'Tedarikçi (Yem vb. Aldığımız)'}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Net Bakiye', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        '${formatNumber.format(finalBalance.abs())} TL',
                        style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold,
                          color: finalBalance > 0 ? PdfColors.green900 : finalBalance < 0 ? PdfColors.red900 : PdfColors.black,
                        ),
                      ),
                      pw.Text(
                        finalBalance > 0 ? 'Bize Borçlu' : finalBalance < 0 ? 'Bizden Alacaklı' : 'Dengede',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: finalBalance > 0 ? PdfColors.green800 : finalBalance < 0 ? PdfColors.red800 : PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Transactions Table
            pw.TableHelper.fromTextArray(
              headers: ['Tarih', 'İşlem Türü', 'Açıklama', 'Borç / Giriş (TL)', 'Alacak / Çıkış (TL)', 'Bakiye (TL)'],
              data: sortedTransactions.map((tx) {
                final double borc = tx['borc'] as double;
                final double alacak = tx['alacak'] as double;
                final double running = tx['runningBalance'] as double;
                return [
                  tx['tarih'] ?? '',
                  tx['islemTipi'] ?? '',
                  tx['aciklama'] ?? '',
                  borc > 0 ? formatNumber.format(borc) : '-',
                  alacak > 0 ? formatNumber.format(alacak) : '-',
                  formatNumber.format(running),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8.5, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignment: pw.Alignment.centerLeft,
              cellAlignments: {
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.centerRight,
              },
              border: pw.TableBorder.all(color: PdfColors.grey200, width: 0.5),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: '${partnerName}_ekstre_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final companyName = widget.companyName ?? '';
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenantFirma = auth.user?.displayName ?? '';
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    if (companyName.isEmpty) {
      return const Scaffold(body: Center(child: Text('Geçersiz Şirket Adı')));
    }

    final cariFirmalarStream = _db
        .collection('cari_firmalar')
        .where('firma', isEqualTo: tenantFirma)
        .where('ad', isEqualTo: companyName)
        .snapshots();

    final invoicesStream = _db
        .collection('faturalar')
        .where('firma', isEqualTo: tenantFirma)
        .where('tedarikci', isEqualTo: companyName)
        .snapshots();

    final milkSalesStream = _db
        .collection('sut_satislari')
        .where('firma', isEqualTo: tenantFirma)
        .where('aliciFirma', isEqualTo: companyName)
        .snapshots();

    final cariIslemlerStream = _db
        .collection('cari_islemler')
        .where('firma', isEqualTo: tenantFirma)
        .where('cariFirmaName', isEqualTo: companyName)
        .snapshots();

    // Stream Combiner for the details view
    Stream<List<QuerySnapshot>> combineDetailsStreams() {
      final controller = StreamController<List<QuerySnapshot>>();
      final latestResults = List<QuerySnapshot?>.filled(4, null);
      final subscriptions = <StreamSubscription>[];

      final streams = [cariFirmalarStream, invoicesStream, milkSalesStream, cariIslemlerStream];
      for (int i = 0; i < streams.length; i++) {
        final sub = streams[i].listen(
          (data) {
            latestResults[i] = data;
            if (latestResults.every((res) => res != null)) {
              if (!controller.isClosed) {
                controller.add(latestResults.cast<QuerySnapshot>());
              }
            }
          },
          onError: (err) {
            if (!controller.isClosed) {
              controller.addError(err);
            }
          },
        );
        subscriptions.add(sub);
      }

      controller.onCancel = () {
        for (var sub in subscriptions) {
          sub.cancel();
        }
      };

      return controller.stream;
    }

    return StreamBuilder<List<QuerySnapshot>>(
      stream: combineDetailsStreams(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(companyName)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(companyName)),
            body: Center(child: Text('Hata: ${snapshot.error}')),
          );
        }

        final companyDocs = snapshot.data?[0].docs ?? [];
        if (companyDocs.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: Text(companyName)),
            body: const Center(child: Text('Cari kart kaydı bulunamadı!')),
          );
        }

        final companyDoc = companyDocs.first;
        final companyData = companyDoc.data() as Map<String, dynamic>;
        final companyTip = companyData['tip'] ?? 'alici';
        final companyTel = companyData['tel'] ?? '';
        final companyEmail = companyData['eposta'] ?? '';
        final companyAddress = companyData['adres'] ?? '';

        final invoiceDocs = snapshot.data?[1].docs ?? [];
        final milkSaleDocs = snapshot.data?[2].docs ?? [];
        final cariIslemDocs = snapshot.data?[3].docs ?? [];

        // Build consolidated ledger transaction list
        final List<Map<String, dynamic>> transactions = [];

        // 1. Invoices
        for (var inv in invoiceDocs) {
          final data = inv.data() as Map<String, dynamic>;
          final double total = (data['toplam'] as num?)?.toDouble() ?? 0.0;
          final type = data['tip'] as String? ?? 'alis';
          final status = data['durum'] as String? ?? 'aktif';
          final faturaNo = data['faturaNo'] ?? '';
          final dateStr = data['tarih'] ?? '';
          final Timestamp? ts = data['timestamp'] as Timestamp?;

          if (status == 'iptal') continue;

          transactions.add({
            'docId': inv.id,
            'collection': 'faturalar',
            'tarih': dateStr,
            'timestamp': ts ?? Timestamp.now(),
            'islemTipi': type == 'alis' ? 'Alış Faturası' : 'Satış Faturası',
            'aciklama': 'Fatura No: $faturaNo',
            'borc': type == 'satis' ? total : 0.0,
            'alacak': type == 'alis' ? total : 0.0,
            'deletable': false,
            'docSnapshot': inv,
          });
        }

        // 2. Milk Sales
        for (var sale in milkSaleDocs) {
          final data = sale.data() as Map<String, dynamic>;
          final double total = (data['toplam'] as num?)?.toDouble() ?? 0.0;
          final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
          final double fiyat = (data['fiyat'] as num?)?.toDouble() ?? 0.0;
          final dateStr = data['tarih'] ?? '';
          final tank = data['kaynakTank'] ?? '';
          final Timestamp? ts = data['timestamp'] as Timestamp?;

          transactions.add({
            'docId': sale.id,
            'collection': 'sut_satislari',
            'tarih': dateStr.split(' ').take(3).join(' '), // strip hours if any
            'timestamp': ts ?? Timestamp.now(),
            'islemTipi': 'Süt Satışı',
            'aciklama': '$tank tankından ${miktar.toStringAsFixed(0)} LT süt satıldı (₺${fiyat.toStringAsFixed(2)}/LT)',
            'borc': total,
            'alacak': 0.0,
            'deletable': false,
            'docSnapshot': sale,
          });
        }

        // 3. Payments / Collections
        for (var tx in cariIslemDocs) {
          final data = tx.data() as Map<String, dynamic>;
          final double total = (data['tutar'] as num?)?.toDouble() ?? 0.0;
          final type = data['tip'] as String? ?? 'odeme';
          final method = data['odemeYontemi'] ?? 'Nakit';
          final dateStr = data['tarih'] ?? '';
          final note = data['aciklama'] ?? '';
          final Timestamp? ts = data['timestamp'] as Timestamp?;

          transactions.add({
            'docId': tx.id,
            'collection': 'cari_islemler',
            'tarih': dateStr,
            'timestamp': ts ?? Timestamp.now(),
            'islemTipi': type == 'odeme' ? 'Ödeme' : 'Tahsilat',
            'aciklama': '$method ${note.isNotEmpty ? '- $note' : ''}',
            'borc': type == 'odeme' ? total : 0.0,
            'alacak': type == 'tahsilat' ? total : 0.0,
            'deletable': true,
            'docSnapshot': tx,
          });
        }

        // Sort chronologically to calculate running balance
        transactions.sort((a, b) {
          final Timestamp tA = a['timestamp'] as Timestamp;
          final Timestamp tB = b['timestamp'] as Timestamp;
          return tA.compareTo(tB);
        });

        double running = 0.0;
        for (var tx in transactions) {
          final double b = tx['borc'] as double;
          final double al = tx['alacak'] as double;
          running += (b - al);
          tx['runningBalance'] = running;
        }

        final double overallBakiye = running;

        // Apply date filter
        final List<Map<String, dynamic>> filteredTransactions = [];
        for (var tx in transactions) {
          bool isInRange = true;
          if (_selectedDateRange != null) {
            final txDate = (tx['timestamp'] as Timestamp).toDate();
            final start = DateTime(_selectedDateRange!.start.year, _selectedDateRange!.start.month, _selectedDateRange!.start.day);
            final end = DateTime(_selectedDateRange!.end.year, _selectedDateRange!.end.month, _selectedDateRange!.end.day, 23, 59, 59);
            isInRange = txDate.isAfter(start.subtract(const Duration(seconds: 1))) && txDate.isBefore(end.add(const Duration(seconds: 1)));
          }
          if (isInRange) {
            filteredTransactions.add(tx);
          }
        }

        final double netBakiye = filteredTransactions.isNotEmpty ? filteredTransactions.last['runningBalance'] : 0.0;

        // Reverse to display newest first
        final displayTransactions = filteredTransactions.reversed.toList();

        return Scaffold(
          backgroundColor: AppColors.gray50,
          appBar: AppBar(
            title: Text(companyName, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.go('/firma/yonetimi'),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.print_rounded, color: AppColors.primary600),
                onPressed: () => _printPdfStatement(
                  companyName,
                  companyTip,
                  netBakiye,
                  filteredTransactions, // chronological filtered for printing table
                  tenantFirma,
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Column(
            children: [
              // Company details card on top
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.sm,
                    border: Border.all(color: AppColors.gray100),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(companyName,
                                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                              const SizedBox(height: 2),
                              Text(companyTip == 'alici' ? 'Alıcı (Süt Müşterisi)' : 'Tedarikçi (Yem vb.)',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.w500)),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text('Cari Hesap Bakiye',
                                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400, fontWeight: FontWeight.w500)),
                              const SizedBox(height: 2),
                              Text(
                                '${formatNumber.format(overallBakiye.abs())} ₺',
                                style: GoogleFonts.inter(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: overallBakiye > 0
                                      ? Colors.green[700]
                                      : overallBakiye < 0
                                          ? Colors.red[700]
                                          : AppColors.gray800,
                                ),
                              ),
                              Text(
                                overallBakiye > 0
                                    ? 'Bize Borçlu'
                                    : overallBakiye < 0
                                        ? 'Bizden Alacaklı'
                                        : 'Hesap Dengede',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: overallBakiye > 0
                                      ? Colors.green[600]
                                      : overallBakiye < 0
                                          ? Colors.red[600]
                                          : AppColors.gray400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (companyTel.isNotEmpty || companyAddress.isNotEmpty) ...[
                        const Divider(height: 24),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (companyTel.isNotEmpty) ...[
                              const Icon(Icons.phone_rounded, size: 14, color: AppColors.gray400),
                              const SizedBox(width: 6),
                              Text(companyTel, style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                              const SizedBox(width: 24),
                            ],
                            if (companyAddress.isNotEmpty) ...[
                              const Icon(Icons.location_on_rounded, size: 14, color: AppColors.gray400),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  companyAddress,
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: PremiumDateRangeFilter(
                  selectedRange: _selectedDateRange,
                  onRangeChanged: (range) {
                    setState(() {
                      _selectedDateRange = range;
                    });
                  },
                ),
              ),

              // Ledger Transactions Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'İşlem Ekstresi',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gray800),
                    ),
                    Text(
                      'Son ${displayTransactions.length} İşlem',
                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                    ),
                  ],
                ),
              ),

              // Ledger List
              Expanded(
                child: displayTransactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_rounded, size: 40, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Henüz cari hareket kaydedilmemiş.',
                                style: GoogleFonts.inter(color: AppColors.gray400, fontSize: 12)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        itemCount: displayTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = displayTransactions[index];
                          final islemTipi = tx['islemTipi'] as String;
                          final tarih = tx['tarih'] as String;
                          final aciklama = tx['aciklama'] as String;
                          final double borc = tx['borc'] as double;
                          final double alacak = tx['alacak'] as double;
                          final double runningBal = tx['runningBalance'] as double;
                          final bool deletable = tx['deletable'] as bool;
                          final docSnapshot = tx['docSnapshot'] as DocumentSnapshot;

                          final bool isDebit = borc > 0;
                          final bool isCredit = alacak > 0;

                          IconData getIcon() {
                            if (islemTipi == 'Süt Satışı') return Icons.water_drop_rounded;
                            if (islemTipi == 'Alış Faturası') return Icons.description_rounded;
                            if (islemTipi == 'Satış Faturası') return Icons.description_outlined;
                            if (islemTipi == 'Ödeme') return Icons.upload_rounded;
                            return Icons.download_rounded; // Tahsilat
                          }

                          Color getIconColor() {
                            if (islemTipi == 'Süt Satışı' || islemTipi == 'Tahsilat') return Colors.green;
                            if (islemTipi == 'Alış Faturası') return Colors.blue;
                            if (islemTipi == 'Satış Faturası') return Colors.purple;
                            return Colors.red; // Ödeme
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppShadows.sm,
                              border: Border.all(color: AppColors.gray100),
                            ),
                            child: Row(
                              children: [
                                // Icon box
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: getIconColor().withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Icon(getIcon(), color: getIconColor(), size: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Details info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(islemTipi,
                                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                          Text(tarih,
                                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(aciklama,
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Bakiye: ${formatNumber.format(runningBal)} ₺',
                                            style: GoogleFonts.inter(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.bold,
                                                color: runningBal > 0
                                                    ? Colors.green[700]
                                                    : runningBal < 0
                                                        ? Colors.red[700]
                                                        : AppColors.gray600),
                                          ),
                                          if (deletable)
                                            GestureDetector(
                                              onTap: () => _deleteCariIslem(docSnapshot),
                                              child: Text('İşlemi Sil',
                                                  style: GoogleFonts.inter(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: AppColors.danger)),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Amount column
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (isDebit)
                                      Text(
                                        '+${formatNumber.format(borc)} ₺',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green[700]),
                                      ),
                                    if (isCredit)
                                      Text(
                                        '-${formatNumber.format(alacak)} ₺',
                                        style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red[700]),
                                      ),
                                    Text(
                                      isDebit ? 'Borç / Giriş' : 'Alacak / Çıkış',
                                      style: GoogleFonts.inter(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: isDebit ? Colors.green[600] : Colors.red[600]),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
