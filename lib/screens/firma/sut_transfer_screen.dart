import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class SutTransferScreen extends StatefulWidget {
  final String? action;
  const SutTransferScreen({super.key, this.action});

  @override
  State<SutTransferScreen> createState() => _SutTransferScreenState();
}

class _SutTransferScreenState extends State<SutTransferScreen> {
  bool _isRefreshing = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.action == 'addSale') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final currentFirmaName = auth.user?.displayName ?? '';
        if (currentFirmaName.isNotEmpty) {
          _showCreateTransferDialog(currentFirmaName);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.pop(),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.primary600),
                  const SizedBox(width: 4),
                  Text(
                    'Geri',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        title: Text(
          'Süt Transferleri',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              setState(() => _isRefreshing = true);
              await Future.delayed(const Duration(milliseconds: 600));
              setState(() => _isRefreshing = false);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateTransferDialog(currentFirmaName),
        backgroundColor: AppColors.primary600,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'Satış Oluştur',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          // Search & Metrics Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Alıcı firma, tank veya not ara...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.gray400),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gray200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gray200),
                    ),
                    fillColor: AppColors.gray50,
                    filled: true,
                  ),
                ),
              ],
            ),
          ),

          // Summary metrics
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('sut_satislari')
                .where('firma', isEqualTo: currentFirmaName)
                .snapshots(),
            builder: (context, snapshot) {
              double totalSold = 0;
              double totalRevenue = 0;
              int totalCount = 0;

              if (snapshot.hasData) {
                for (var doc in snapshot.data!.docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final miktar = (data['miktar'] as num?)?.toDouble() ?? 0;
                  final fiyat = (data['fiyat'] as num?)?.toDouble() ?? 0;
                  totalSold += miktar;
                  totalRevenue += miktar * fiyat;
                  totalCount++;
                }
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.gray200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMetric('Toplam Satış', '$totalCount', const Color(0xFF3B82F6)),
                    Container(width: 1, height: 32, color: AppColors.gray200),
                    _buildMetric('Satılan Süt', '${totalSold.toStringAsFixed(0)} L', const Color(0xFF10B981)),
                    Container(width: 1, height: 32, color: AppColors.gray200),
                    _buildMetric('Toplam Gelir', '₺${totalRevenue.toStringAsFixed(0)}', const Color(0xFFD97706)),
                  ],
                ),
              );
            },
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sut_satislari')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || _isRefreshing) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                // Sort docs descending by timestamp to avoid requiring composite indexes
                final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
                sortedDocs.sort((a, b) {
                  final tsA = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  final tsB = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  if (tsA == null && tsB == null) return 0;
                  if (tsA == null) return 1;
                  if (tsB == null) return -1;
                  return tsB.compareTo(tsA);
                });

                final filtered = sortedDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final alici = (data['aliciFirma'] ?? '').toString().toLowerCase();
                  final tank = (data['kaynakTank'] ?? '').toString().toLowerCase();
                  final not_ = (data['not'] ?? '').toString().toLowerCase();

                  return alici.contains(_searchQuery) ||
                      tank.contains(_searchQuery) ||
                      not_.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sync_alt_rounded, size: 48, color: AppColors.gray300),
                        const SizedBox(height: 12),
                        Text(
                          'Henüz süt satışı kaydı bulunmuyor.',
                          style: GoogleFonts.inter(color: AppColors.gray500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Yeni satış oluşturmak için + butonuna basın.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index].data() as Map<String, dynamic>;
                    final String aliciFirma = data['aliciFirma'] ?? '';
                    final String kaynakTank = data['kaynakTank'] ?? '';
                    final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
                    final double fiyat = (data['fiyat'] as num?)?.toDouble() ?? 0.0;
                    final double toplam = miktar * fiyat;
                    final String tarih = data['tarih'] ?? '';
                    final String durum = data['durum'] ?? 'Tamamlandı';
                    final String not_ = data['not'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.gray200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header - buyer & status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF059669).withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.business_rounded, size: 18, color: Color(0xFF059669)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        aliciFirma,
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gray800,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      durum,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // Details box
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.gray50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.gray100),
                            ),
                            child: Column(
                              children: [
                                _buildDetailRow(
                                  Icons.propane_tank_rounded,
                                  'Kaynak Tank',
                                  kaynakTank,
                                  const Color(0xFF0284C7),
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  Icons.water_drop_rounded,
                                  'Miktar',
                                  '${miktar.toStringAsFixed(0)} Litre',
                                  const Color(0xFF3B82F6),
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  Icons.attach_money_rounded,
                                  'Birim Fiyat',
                                  '₺${fiyat.toStringAsFixed(2)} / L',
                                  const Color(0xFFD97706),
                                ),
                                const SizedBox(height: 8),
                                const Divider(height: 1),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Toplam Tutar',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.gray700,
                                      ),
                                    ),
                                    Text(
                                      '₺${toplam.toStringAsFixed(2)}',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF059669),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          if (not_.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.notes_rounded, size: 14, color: AppColors.gray400),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    not_,
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontStyle: FontStyle.italic),
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                tarih,
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      _showEditTransferDialog(filtered[index]);
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () {
                                      _deleteTransfer(filtered[index]);
                                    },
                                  ),
                                ],
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
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value, Color iconColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.gray500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
        ),
      ],
    );
  }

  void _showCreateTransferDialog(String firma) {
    final db = FirebaseFirestore.instance;
    final miktarCtrl = TextEditingController();
    final fiyatCtrl = TextEditingController();
    final digerFirmaCtrl = TextEditingController();
    final notCtrl = TextEditingController();
    String? selectedTank;
    String? selectedAliciFirma;



    showDialog(
      context: context,
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('tanklar')
              .where('firma', isEqualTo: firma)
              .where('tip', isEqualTo: 'merkez')
              .snapshots(),
          builder: (context, tankSnapshot) {
            if (!tankSnapshot.hasData) {
              return const AlertDialog(
                content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
              );
            }

            final tanks = tankSnapshot.data!.docs;
            final tankNames = tanks.map((t) => (t.data() as Map<String, dynamic>)['ad'] as String).toList();

            if (selectedTank == null && tankNames.isNotEmpty) {
              selectedTank = tankNames.first;
            }

            return StatefulBuilder(
              builder: (context, setDialogState) {
                // Find selected tank's current stock
                double tankStock = 0;
                try {
                  final selectedDoc = tanks.firstWhere(
                    (t) => (t.data() as Map<String, dynamic>)['ad'] == selectedTank
                  );
                  tankStock = ((selectedDoc.data() as Map<String, dynamic>)['stok'] as num?)?.toDouble() ?? 0;
                } catch (_) {}

                return AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.sell_rounded, color: Color(0xFF059669), size: 22),
                      const SizedBox(width: 8),
                      Text('Süt Satışı Oluştur', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Buyer company dropdown
                          FutureBuilder<QuerySnapshot>(
                            future: db.collection('cari_firmalar')
                                .where('firma', isEqualTo: firma)
                                .where('tip', isEqualTo: 'tedarikci')
                                .get(),
                            builder: (context, companySnapshot) {
                              List<String> combinedFirmalar = [];
                              if (companySnapshot.hasData) {
                                final dbFirms = companySnapshot.data!.docs
                                    .map((doc) => (doc.data() as Map<String, dynamic>)['ad'] as String)
                                    .toList();
                                for (var f in dbFirms) {
                                  if (!combinedFirmalar.contains(f)) {
                                    combinedFirmalar.add(f);
                                  }
                                }
                              }
                              if (!combinedFirmalar.contains('Diğer')) {
                                combinedFirmalar.add('Diğer');
                              }

                              return DropdownButtonFormField<String>(
                                value: selectedAliciFirma,
                                decoration: const InputDecoration(
                                  labelText: 'Alıcı Firma *',
                                  prefixIcon: Icon(Icons.business_rounded, size: 18),
                                ),
                                hint: Text(
                                  'Firma seçin...',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                                ),
                                isExpanded: true,
                                items: combinedFirmalar.map((f) {
                                  final bool isDiger = f == 'Diğer';
                                  return DropdownMenuItem<String>(
                                    value: f,
                                    child: Row(
                                      children: [
                                        if (!isDiger)
                                          Icon(Icons.business_rounded, size: 16, color: AppColors.gray400)
                                        else
                                          const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFD97706)),
                                        const SizedBox(width: 8),
                                        Text(
                                          f,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: isDiger ? FontWeight.w600 : FontWeight.w500,
                                            color: isDiger ? const Color(0xFFD97706) : AppColors.gray700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedAliciFirma = val;
                                    if (val != 'Diğer') {
                                      digerFirmaCtrl.clear();
                                    }
                                  });
                                },
                              );
                            },
                          ),
                          // Custom company name field when 'Diğer' is selected
                          if (selectedAliciFirma == 'Diğer') ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: digerFirmaCtrl,
                              decoration: InputDecoration(
                                labelText: 'Firma Adı *',
                                hintText: 'Alıcı firma adını yazın...',
                                prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
                                filled: true,
                                fillColor: const Color(0xFFFFFBEB),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Source tank
                          DropdownButtonFormField<String>(
                            value: selectedTank,
                            decoration: InputDecoration(
                              labelText: 'Kaynak Tank *',
                              helperText: selectedTank != null ? 'Mevcut stok: ${tankStock.toStringAsFixed(0)} LT' : null,
                              helperStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.primary600),
                            ),
                            items: tankNames
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedTank = val;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Amount
                          TextField(
                            controller: miktarCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Miktar (Litre) *',
                              hintText: '0',
                              suffixText: 'LT',
                              prefixIcon: Icon(Icons.water_drop_rounded, size: 18),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Price
                          TextField(
                            controller: fiyatCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Birim Fiyat (₺/LT) *',
                              hintText: '0.00',
                              suffixText: '₺',
                              prefixIcon: Icon(Icons.attach_money_rounded, size: 18),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Note
                          TextField(
                            controller: notCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Not (Opsiyonel)',
                              hintText: 'Ek bilgi...',
                              prefixIcon: Icon(Icons.notes_rounded, size: 18),
                            ),
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
                    ElevatedButton.icon(
                      onPressed: () async {
                        // Resolve buyer name from dropdown or custom field
                        final String alici = selectedAliciFirma == 'Diğer'
                            ? digerFirmaCtrl.text.trim()
                            : (selectedAliciFirma ?? '');
                        final miktar = double.tryParse(miktarCtrl.text);
                        final fiyat = double.tryParse(fiyatCtrl.text);

                        if (alici.isEmpty || miktar == null || miktar <= 0 || fiyat == null || fiyat <= 0 || selectedTank == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun!'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        // Subtract from tank
                        final tankQuery = await db.collection('tanklar').where('ad', isEqualTo: selectedTank).limit(1).get();
                        if (tankQuery.docs.isNotEmpty) {
                          final tankDoc = tankQuery.docs.first;
                          final currentStock = ((tankDoc.data() as Map<String, dynamic>)['stok'] as num).toDouble();
                          final newStock = (currentStock - miktar).clamp(0.0, double.infinity);
                          await tankDoc.reference.update({'stok': newStock});
                        }

                        // Create sale record
                        final docRef = await db.collection('sut_satislari').add({
                          'aliciFirma': alici,
                          'kaynakTank': selectedTank,
                          'miktar': miktar,
                          'fiyat': fiyat,
                          'toplam': miktar * fiyat,
                          'not': notCtrl.text.trim(),
                          'tarih': DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(DateTime.now()),
                          'durum': 'Tamamlandı',
                          'firma': firma,
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        // Log to satislar collection so sales reports/web dashboard pick it up!
                        await db.collection('satislar').add({
                          'firma': firma,
                          'aliciFirma': alici,
                          'miktar': miktar,
                          'birimFiyat': fiyat,
                          'toplamTutar': miktar * fiyat,
                          'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                          'aciklama': notCtrl.text.trim().isNotEmpty
                              ? notCtrl.text.trim()
                              : '$selectedTank tankından süt satışı',
                          'tankId': '',
                          'sutSatisiId': docRef.id,
                          'timestamp': FieldValue.serverTimestamp(),
                        });

                        Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$alici firmasına ${miktar.toStringAsFixed(0)} LT süt satışı kaydedildi.'),
                              backgroundColor: const Color(0xFF059669),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('Satışı Kaydet', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _deleteTransfer(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final String alici = data['aliciFirma'] ?? '';
    final String kaynakTank = data['kaynakTank'] ?? '';
    final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
    final double fiyat = (data['fiyat'] as num?)?.toDouble() ?? 0.0;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Satışı Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('$alici firmasına yapılan ${miktar.toStringAsFixed(0)} L satışı silmek istediğinize emin misiniz? Satılan süt tanka geri eklenecektir.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final db = FirebaseFirestore.instance;

    try {
      // 1. Add back stock to the tank
      final tankQuery = await db.collection('tanklar').where('ad', isEqualTo: kaynakTank).limit(1).get();
      if (tankQuery.docs.isNotEmpty) {
        final tankDoc = tankQuery.docs.first;
        final currentStock = ((tankDoc.data() as Map<String, dynamic>)['stok'] as num).toDouble();
        await tankDoc.reference.update({'stok': currentStock + miktar});
      }

      // 2. Delete from sut_satislari
      await doc.reference.delete();

      // 3. Delete from satislar
      var salesQuery = await db.collection('satislar').where('sutSatisiId', isEqualTo: doc.id).get();
      if (salesQuery.docs.isEmpty) {
        salesQuery = await db.collection('satislar')
            .where('aliciFirma', isEqualTo: alici)
            .where('miktar', isEqualTo: miktar)
            .where('birimFiyat', isEqualTo: fiyat)
            .get();
      }
      for (var sDoc in salesQuery.docs) {
        await sDoc.reference.delete();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Satış başarıyla silindi ve tank stoğu güncellendi.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showEditTransferDialog(DocumentSnapshot doc) {
    final db = FirebaseFirestore.instance;
    final data = doc.data() as Map<String, dynamic>;
    final String oldAlici = data['aliciFirma'] ?? '';
    final String oldTank = data['kaynakTank'] ?? '';
    final double oldMiktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
    final double oldFiyat = (data['fiyat'] as num?)?.toDouble() ?? 0.0;
    final String oldNot = data['not'] ?? '';

    final miktarCtrl = TextEditingController(text: oldMiktar.toStringAsFixed(0));
    final fiyatCtrl = TextEditingController(text: oldFiyat.toStringAsFixed(2));
    final digerFirmaCtrl = TextEditingController();
    final notCtrl = TextEditingController(text: oldNot);

    String? selectedTank = oldTank;
    String? selectedAliciFirma;

    showDialog(
      context: context,
      builder: (ctx) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final currentFirmaName = auth.user?.displayName ?? '';

        return StreamBuilder<QuerySnapshot>(
          stream: db.collection('tanklar')
              .where('firma', isEqualTo: currentFirmaName)
              .where('tip', isEqualTo: 'merkez')
              .snapshots(),
          builder: (context, tankSnapshot) {
            if (!tankSnapshot.hasData) {
              return const AlertDialog(
                content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
              );
            }

            final tanks = tankSnapshot.data!.docs;
            final tankNames = tanks.map((t) => (t.data() as Map<String, dynamic>)['ad'] as String).toList();

            if (!tankNames.contains(selectedTank) && tankNames.isNotEmpty) {
              selectedTank = tankNames.first;
            }

            return StatefulBuilder(
              builder: (context, setDialogState) {
                // Find selected tank's current stock
                double tankStock = 0;
                try {
                  final selectedDoc = tanks.firstWhere(
                    (t) => (t.data() as Map<String, dynamic>)['ad'] == selectedTank
                  );
                  tankStock = ((selectedDoc.data() as Map<String, dynamic>)['stok'] as num?)?.toDouble() ?? 0;
                } catch (_) {}

                return AlertDialog(
                  title: Row(
                    children: [
                      const Icon(Icons.edit_rounded, color: Colors.blue, size: 22),
                      const SizedBox(width: 8),
                      Text('Satışı Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: SizedBox(
                    width: 400,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Buyer company dropdown
                          FutureBuilder<QuerySnapshot>(
                            future: db.collection('cari_firmalar')
                                .where('firma', isEqualTo: currentFirmaName)
                                .where('tip', isEqualTo: 'tedarikci')
                                .get(),
                            builder: (context, companySnapshot) {
                              List<String> combinedFirmalar = [];
                              if (companySnapshot.hasData) {
                                final dbFirms = companySnapshot.data!.docs
                                    .map((doc) => (doc.data() as Map<String, dynamic>)['ad'] as String)
                                    .toList();
                                for (var f in dbFirms) {
                                  if (!combinedFirmalar.contains(f)) {
                                    combinedFirmalar.add(f);
                                  }
                                }
                              }
                              if (!combinedFirmalar.contains('Diğer')) {
                                combinedFirmalar.add('Diğer');
                              }

                              if (selectedAliciFirma == null) {
                                if (combinedFirmalar.contains(oldAlici)) {
                                  selectedAliciFirma = oldAlici;
                                } else {
                                  selectedAliciFirma = 'Diğer';
                                  digerFirmaCtrl.text = oldAlici;
                                }
                              }

                              return DropdownButtonFormField<String>(
                                value: selectedAliciFirma,
                                decoration: const InputDecoration(
                                  labelText: 'Alıcı Firma *',
                                  prefixIcon: Icon(Icons.business_rounded, size: 18),
                                ),
                                hint: Text(
                                  'Firma seçin...',
                                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                                ),
                                isExpanded: true,
                                items: combinedFirmalar.map((f) {
                                  final bool isDiger = f == 'Diğer';
                                  return DropdownMenuItem<String>(
                                    value: f,
                                    child: Row(
                                      children: [
                                        if (!isDiger)
                                          Icon(Icons.business_rounded, size: 16, color: AppColors.gray400)
                                        else
                                          const Icon(Icons.edit_rounded, size: 16, color: Color(0xFFD97706)),
                                        const SizedBox(width: 8),
                                        Text(
                                          f,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: isDiger ? FontWeight.w600 : FontWeight.w500,
                                            color: isDiger ? const Color(0xFFD97706) : AppColors.gray700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setDialogState(() {
                                    selectedAliciFirma = val;
                                    if (val != 'Diğer') {
                                      digerFirmaCtrl.clear();
                                    }
                                  });
                                },
                              );
                            },
                          ),
                          // Custom company name field when 'Diğer' is selected
                          if (selectedAliciFirma == 'Diğer') ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: digerFirmaCtrl,
                              decoration: InputDecoration(
                                labelText: 'Firma Adı *',
                                hintText: 'Alıcı firma adını yazın...',
                                prefixIcon: const Icon(Icons.edit_note_rounded, size: 18),
                                filled: true,
                                fillColor: const Color(0xFFFFFBEB),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFFDE68A)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: Color(0xFFD97706), width: 2),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),

                          // Source tank
                          DropdownButtonFormField<String>(
                            value: selectedTank,
                            decoration: InputDecoration(
                              labelText: 'Kaynak Tank *',
                              helperText: selectedTank != null 
                                  ? 'Mevcut stok: ${tankStock.toStringAsFixed(0)} LT'
                                  : null,
                              helperStyle: GoogleFonts.inter(fontSize: 11, color: AppColors.primary600),
                            ),
                            items: tankNames
                                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                                .toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedTank = val;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Amount
                          TextField(
                            controller: miktarCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Miktar (Litre) *',
                              hintText: '0',
                              suffixText: 'LT',
                              prefixIcon: Icon(Icons.water_drop_rounded, size: 18),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Price
                          TextField(
                            controller: fiyatCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'Birim Fiyat (₺/LT) *',
                              hintText: '0.00',
                              suffixText: '₺',
                              prefixIcon: Icon(Icons.attach_money_rounded, size: 18),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Note
                          TextField(
                            controller: notCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              labelText: 'Not (Opsiyonel)',
                              hintText: 'Ek bilgi...',
                              prefixIcon: Icon(Icons.notes_rounded, size: 18),
                            ),
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
                    ElevatedButton.icon(
                      onPressed: () async {
                        final String alici = selectedAliciFirma == 'Diğer'
                            ? digerFirmaCtrl.text.trim()
                            : (selectedAliciFirma ?? '');
                        final miktar = double.tryParse(miktarCtrl.text);
                        final fiyat = double.tryParse(fiyatCtrl.text);

                        if (alici.isEmpty || miktar == null || miktar <= 0 || fiyat == null || fiyat <= 0 || selectedTank == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Lütfen tüm zorunlu alanları doldurun!'), backgroundColor: Colors.red),
                          );
                          return;
                        }

                        // Adjust tank stock based on diff
                        if (selectedTank == oldTank) {
                          final diff = miktar - oldMiktar;
                          final tankQuery = await db.collection('tanklar').where('ad', isEqualTo: selectedTank).limit(1).get();
                          if (tankQuery.docs.isNotEmpty) {
                            final tankDoc = tankQuery.docs.first;
                            final currentStock = ((tankDoc.data() as Map<String, dynamic>)['stok'] as num).toDouble();
                            final newStock = (currentStock - diff).clamp(0.0, double.infinity);
                            await tankDoc.reference.update({'stok': newStock});
                          }
                        } else {
                          // Tank changed: return to old tank, subtract from new tank
                          final oldTankQuery = await db.collection('tanklar').where('ad', isEqualTo: oldTank).limit(1).get();
                          if (oldTankQuery.docs.isNotEmpty) {
                            final oldTankDoc = oldTankQuery.docs.first;
                            final currentStock = ((oldTankDoc.data() as Map<String, dynamic>)['stok'] as num).toDouble();
                            await oldTankDoc.reference.update({'stok': currentStock + oldMiktar});
                          }

                          final newTankQuery = await db.collection('tanklar').where('ad', isEqualTo: selectedTank).limit(1).get();
                          if (newTankQuery.docs.isNotEmpty) {
                            final newTankDoc = newTankQuery.docs.first;
                            final currentStock = ((newTankDoc.data() as Map<String, dynamic>)['stok'] as num).toDouble();
                            final newStock = (currentStock - miktar).clamp(0.0, double.infinity);
                            await newTankDoc.reference.update({'stok': newStock});
                          }
                        }

                        // Update sale record
                        await doc.reference.update({
                          'aliciFirma': alici,
                          'kaynakTank': selectedTank,
                          'miktar': miktar,
                          'fiyat': fiyat,
                          'toplam': miktar * fiyat,
                          'not': notCtrl.text.trim(),
                        });

                        // Update satislar collection record
                        var salesQuery = await db.collection('satislar').where('sutSatisiId', isEqualTo: doc.id).get();
                        if (salesQuery.docs.isEmpty) {
                          salesQuery = await db.collection('satislar')
                              .where('aliciFirma', isEqualTo: oldAlici)
                              .where('miktar', isEqualTo: oldMiktar)
                              .where('birimFiyat', isEqualTo: oldFiyat)
                              .get();
                        }
                        for (var sDoc in salesQuery.docs) {
                          await sDoc.reference.update({
                            'aliciFirma': alici,
                            'miktar': miktar,
                            'birimFiyat': fiyat,
                            'toplamTutar': miktar * fiyat,
                            'aciklama': notCtrl.text.trim().isNotEmpty
                                ? notCtrl.text.trim()
                                : '$selectedTank tankından süt satışı',
                          });
                        }

                        Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Satış kaydı başarıyla güncellendi.'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('Değişiklikleri Kaydet', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}
