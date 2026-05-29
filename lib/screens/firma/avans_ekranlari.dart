import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

// --- MÜŞTERİ AVANSLARI LIST SCREEN ---
class MusteriAvanslariScreen extends StatefulWidget {
  const MusteriAvanslariScreen({super.key});

  @override
  State<MusteriAvanslariScreen> createState() => _MusteriAvanslariScreenState();
}

class _MusteriAvanslariScreenState extends State<MusteriAvanslariScreen> {
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

  void _showAvansIslemleriDialog(BuildContext context, String docId, String uretici, double tutar, String currentDurum) {
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Avans İşlemleri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('$uretici adına tanımlanan ${formatNumber.format(tutar)} ₺ tutarındaki avans kaydı üzerinde yapılacak işlemi seçin:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          if (currentDurum != 'iptal')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('avanslar').doc(docId).update({'durum': 'iptal'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Avans iptal edildi!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('İptal Et'),
            ),
          if (currentDurum != 'aktif')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('avanslar').doc(docId).update({'durum': 'aktif'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Avans aktif yapıldı!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('Aktif Yap'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              await FirestoreService().deleteAvans(docId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Avans kaydı başarıyla silindi!'), backgroundColor: AppColors.success),
              );
            },
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
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return Scaffold(
      appBar: AppBar(
        title: Text('Müşteri Avansları', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getAvanslarStream(firma: currentFirmaName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.hasData ? snapshot.data!.docs : [];
          
          double monthlyTotal = 0.0;
          int monthlyCount = 0;
          final List<QueryDocumentSnapshot> filteredAvanslar = [];

          for (var doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final date = timestamp?.toDate() ?? DateTime.now();

            if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
              final uretici = data['uretici'] as String? ?? '';
              final aciklama = data['aciklama'] as String? ?? '';
              final tutarVal = data['tutar'] ?? 0.0;
              final double tutar = tutarVal is num ? tutarVal.toDouble() : (double.tryParse(tutarVal.toString()) ?? 0.0);

              final matchesSearch = _searchQuery.isEmpty ||
                  uretici.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  aciklama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  tutar.toString().contains(_searchQuery);

              if (matchesSearch) {
                filteredAvanslar.add(doc);
                monthlyTotal += tutar;
                monthlyCount++;
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // + Avans Ver Button
              ElevatedButton.icon(
                onPressed: () => context.go('/firma/finans/avanslar/ekle'),
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                label: const Text('Avans Ver'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 16),

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
                    hintText: 'Müşteri adı, tutar veya açıklama ile ar...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Total Avans Summary Card
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
                      child: const Icon(Icons.money_rounded, color: Color(0xFF16A34A), size: 22),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$monthStr Toplam Avans', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          '${formatNumber.format(monthlyTotal)} ₺',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray800),
                        ),
                        Text('$monthlyCount kayıt', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Avans Geçmişi Title
              Text(
                'Avans Geçmişi',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
              ),
              const SizedBox(height: 12),

              // List of Avanslar
              if (filteredAvanslar.isEmpty)
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
                        'Henüz uygun avans kaydı bulunmuyor',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Filtreyi değiştirin veya yeni avans ekleyin',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredAvanslar.length,
                  itemBuilder: (context, idx) {
                    final doc = filteredAvanslar[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final uretici = data['uretici'] as String? ?? '';
                    final aciklama = data['aciklama'] as String? ?? '';
                    final yontem = data['odemeYontemi'] as String? ?? 'Nakit';
                    final vTarih = data['verildigiTarih'] as String? ?? '';
                    final tTarih = data['tahsilEdilecegiTarih'] as String? ?? '';
                    final tutarVal = data['tutar'] ?? 0.0;
                    final double tutar = tutarVal is num ? tutarVal.toDouble() : (double.tryParse(tutarVal.toString()) ?? 0.0);
                    final durum = data['durum'] as String? ?? 'aktif';

                    Color statusColor;
                    String statusText;
                    if (durum == 'aktif') {
                      statusColor = Colors.blue;
                      statusText = 'Aktif';
                    } else if (durum == 'odendi') {
                      statusColor = Colors.green;
                      statusText = 'Ödenen';
                    } else {
                      statusColor = Colors.red;
                      statusText = 'İptal';
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(uretici, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '$vTarih • $yontem',
                                      style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                                      ),
                                    ),
                                  ],
                                ),
                                if (aciklama.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    aciklama,
                                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400, fontStyle: FontStyle.italic),
                                  ),
                                ],
                                const SizedBox(height: 4),
                                Text(
                                  'Tahsilat Planı: $tTarih',
                                  style: GoogleFonts.inter(fontSize: 9, color: AppColors.primary600, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              Text(
                                '- ${formatNumber.format(tutar)} ₺',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.more_vert_rounded, color: AppColors.gray500, size: 20),
                                onPressed: () => _showAvansIslemleriDialog(context, doc.id, uretici, tutar, durum),
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

// --- AVANS VER SCREEN ---
class AvansVerScreen extends StatefulWidget {
  const AvansVerScreen({super.key});

  @override
  State<AvansVerScreen> createState() => _AvansVerScreenState();
}

class _AvansVerScreenState extends State<AvansVerScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedUretici;
  final _tutarCtrl = TextEditingController();
  final _aciklamaCtrl = TextEditingController();
  String _odemeYontemi = 'Nakit'; // Nakit, Banka, Çek
  DateTime _verildigiTarih = DateTime.now();
  DateTime _tahsilEdilecegiTarih = DateTime.now();

  @override
  void dispose() {
    _tutarCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  void _selectDate(BuildContext context, bool isVerildigi) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isVerildigi ? _verildigiTarih : _tahsilEdilecegiTarih,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() {
        if (isVerildigi) {
          _verildigiTarih = picked;
          _tahsilEdilecegiTarih = picked;
        } else {
          _tahsilEdilecegiTarih = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final dateFormat = DateFormat('dd MMMM yyyy', 'tr_TR');

    return Scaffold(
      appBar: AppBar(
        title: Text('Avans Ver', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getProducersStream(firma: currentFirmaName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final producers = snapshot.hasData
              ? snapshot.data!.docs.map((doc) => (doc.data() as Map)['name'] as String).toList()
              : <String>[];

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Card: Form Inputs
                AppCard(
                  padding: const EdgeInsets.all(16),
                  shadow: AppShadows.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Müşteri Seçimi
                      SearchableDropdown(
                        items: producers,
                        value: _selectedUretici,
                        hint: 'Üretici / Müşteri Seçin',
                        label: 'Müşteri Seçiniz *',
                        validator: (value) => value == null || value.isEmpty ? 'Lütfen bir müşteri seçin' : null,
                        onChanged: (val) => setState(() => _selectedUretici = val),
                      ),
                      const SizedBox(height: 16),

                      // Tutar
                      Text('Tutar (₺) *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _tutarCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Lütfen tutar girin';
                          if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Lütfen geçerli bir sayı girin';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Ödeme Yöntemi Selector
                      Text('Ödeme Yöntemi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildYontemButton('Nakit', Icons.money_rounded),
                          const SizedBox(width: 8),
                          _buildYontemButton('Banka', Icons.account_balance_rounded),
                          const SizedBox(width: 8),
                          _buildYontemButton('Çek', Icons.description_rounded),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Açıklama
                      Text('Açıklama *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _aciklamaCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Açıklama giriniz',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Lütfen bir açıklama girin' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Card: Tarihler
                AppCard(
                  padding: const EdgeInsets.all(16),
                  shadow: AppShadows.sm,
                  child: Column(
                    children: [
                      // Verildiği Tarih
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: AppColors.primary600, size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Verildiği Tarih', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                                const SizedBox(height: 2),
                                Text(
                                  dateFormat.format(_verildigiTarih),
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
                          ],
                        ),
                      ),
                      const Divider(height: 24, color: AppColors.gray200),

                      // Tahsil Edileceği Tarih
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Colors.orange, size: 20),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tahsil Edileceği Tarih', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                                const SizedBox(height: 2),
                                Text(
                                  dateFormat.format(_tahsilEdilecegiTarih),
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                ),
                              ],
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Kaydet Button
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final double tutar = double.parse(_tutarCtrl.text.replaceAll(',', '.'));

                      await FirestoreService().addAvans({
                        'firma': currentFirmaName,
                        'uretici': _selectedUretici,
                        'tutar': tutar,
                        'odemeYontemi': _odemeYontemi,
                        'aciklama': _aciklamaCtrl.text,
                        'verildigiTarih': DateFormat('dd.MM.yyyy').format(_verildigiTarih),
                        'tahsilEdilecegiTarih': DateFormat('dd.MM.yyyy').format(_tahsilEdilecegiTarih),
                        'durum': 'aktif',
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$_selectedUretici üreticisine avans kaydı başarıyla eklendi!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        context.go('/firma/finans/avanslar');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Kaydet ve Gönder', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildYontemButton(String label, IconData icon) {
    final isSelected = _odemeYontemi == label;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _odemeYontemi = label),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary600 : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? AppColors.primary600 : AppColors.gray300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? Colors.white : AppColors.gray600, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppColors.gray700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
