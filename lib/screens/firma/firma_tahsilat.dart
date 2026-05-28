import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaTahsilatScreen extends StatefulWidget {
  const FirmaTahsilatScreen({super.key});

  @override
  State<FirmaTahsilatScreen> createState() => _FirmaTahsilatScreenState();
}

class _FirmaTahsilatScreenState extends State<FirmaTahsilatScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
    });
  }

  bool _isDocInSelectedMonth(DocumentSnapshot doc, DateTime selectedMonth) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return false;

    if (data['timestamp'] != null) {
      final date = (data['timestamp'] as Timestamp).toDate();
      return date.month == selectedMonth.month && date.year == selectedMonth.year;
    }

    final rawDate = data['tarih'];
    if (rawDate != null) {
      try {
        final parsed = DateFormat('dd.MM.yyyy').parse(rawDate.toString());
        return parsed.month == selectedMonth.month && parsed.year == selectedMonth.year;
      } catch (_) {}
    }
    return false;
  }

  void _showAddTahsilatDialog() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    // Fetch producers associated with this firm
    final producersQuery = await _db
        .collection('ureticiler')
        .where('firmalar', arrayContains: currentFirmaName)
        .get();
    final producers = producersQuery.docs
        .map((p) => p.data()['name'] as String? ?? '')
        .where((p) => p.isNotEmpty)
        .toList();

    if (producers.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tahsilat kaydetmek için önce en az bir üretici bulunmalıdır!'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedProducer = producers.first;
        final amountCtrl = TextEditingController();
        final descCtrl = TextEditingController();
        String selectedMethod = 'Nakit';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Yeni Tahsilat Yap', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Üretici', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedProducer,
                      items: producers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                      onChanged: (val) => setState(() => selectedProducer = val),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tutar (₺)', hintText: 'Örn: 1500'),
                    ),
                    const SizedBox(height: 12),
                    Text('Ödeme Yöntemi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      value: selectedMethod,
                      items: ['Nakit', 'Banka', 'Çek', 'Cari'].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                      onChanged: (val) => setState(() => selectedMethod = val ?? 'Nakit'),
                      decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Açıklama (İsteğe Bağlı)', hintText: 'Örn: Yem borcu ödemesi'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500))),
                ElevatedButton(
                  onPressed: () async {
                    final tutar = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
                    final aciklama = descCtrl.text.trim();

                    if (selectedProducer == null || tutar <= 0) return;

                    await _db.collection('tahsilatlar').add({
                      'uretici': selectedProducer,
                      'tutar': tutar,
                      'odemeYontemi': selectedMethod,
                      'aciklama': aciklama,
                      'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                      'saat': DateFormat('HH:mm').format(DateTime.now()),
                      'timestamp': FieldValue.serverTimestamp(),
                      'firma': currentFirmaName,
                    });

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Tahsilat kaydı başarıyla oluşturuldu!'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Tahsilatı Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteTahsilat(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tahsilatı Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu tahsilat kaydını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              if (ctx.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tahsilat kaydı silindi!'), backgroundColor: AppColors.success),
                );
              }
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
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('Üretici Tahsilatları', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/ureticiler'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      floatingActionButton: AppFab(
        icon: Icons.add_card_rounded,
        label: 'Tahsilat Yap',
        onTap: _showAddTahsilatDialog,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('tahsilatlar')
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
          
          double monthlyTotal = 0.0;
          int monthlyCount = 0;
          final List<QueryDocumentSnapshot> filteredDocs = [];

          for (var doc in rawDocs) {
            if (_isDocInSelectedMonth(doc, _selectedDate)) {
              final data = doc.data() as Map<String, dynamic>;
              final uretici = data['uretici'] as String? ?? '';
              final aciklama = data['aciklama'] as String? ?? '';
              final tutarVal = data['tutar'] ?? 0.0;
              final double tutar = tutarVal is num ? tutarVal.toDouble() : (double.tryParse(tutarVal.toString()) ?? 0.0);

              final matchesSearch = _searchQuery.isEmpty ||
                  uretici.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  aciklama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  tutar.toString().contains(_searchQuery);

              if (matchesSearch) {
                filteredDocs.add(doc);
                monthlyTotal += tutar;
                monthlyCount++;
              }
            }
          }

          // Sort filtered docs by timestamp/date descending
          filteredDocs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = aData['timestamp'] as Timestamp?;
            final bTime = bData['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Month Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month_rounded, color: AppColors.primary600, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        monthStr,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _changeMonth(1),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppShadows.sm,
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Müşteri adı, tutar veya açıklama ile ara...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Total Tahsilat Summary Card
              AppCard(
                padding: const EdgeInsets.all(16),
                shadow: AppShadows.sm,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCFCE7),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.credit_card_rounded, color: Color(0xFF16A34A), size: 22),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$monthStr Toplam Tahsilat', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          formatCurrency.format(monthlyTotal),
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray800),
                        ),
                        Text('$monthlyCount kayıt', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Tahsilat Geçmişi Title
              Text(
                'Tahsilat Geçmişi',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
              ),
              const SizedBox(height: 12),

              // List of Tahsilatlar
              if (filteredDocs.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 64),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off_rounded, size: 48, color: AppColors.gray300),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz uygun tahsilat kaydı bulunmuyor',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Filtreyi değiştirin veya yeni tahsilat ekleyin',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final uretici = data['uretici'] ?? '';
                    final tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                    final odemeYontemi = data['odemeYontemi'] ?? 'Nakit';
                    final aciklama = data['aciklama'] ?? '';
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
                              color: AppColors.warningLight,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.credit_card_rounded, color: AppColors.warning, size: 20),
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
                                  '$odemeYontemi ${aciklama.isNotEmpty ? "- $aciklama" : ""}',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.success),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.gray400, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteTahsilat(doc),
                              ),
                            ],
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
}
