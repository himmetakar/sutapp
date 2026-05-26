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

// --- MÜŞTERİ KESİNTİLERİ LIST SCREEN ---
class MusteriKesintileriScreen extends StatefulWidget {
  const MusteriKesintileriScreen({super.key});

  @override
  State<MusteriKesintileriScreen> createState() => _MusteriKesintileriScreenState();
}

class _MusteriKesintileriScreenState extends State<MusteriKesintileriScreen> {
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  String _selectedStatus = 'tumu'; // tumu, aktif, odendi, iptal

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

  Widget _buildStatusTab(String statusKey, String label, int count) {
    final isSelected = _selectedStatus == statusKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = statusKey),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary600 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary600 : AppColors.gray300),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  void _showKesintiIslemleriDialog(BuildContext context, String docId, String uretici, double tutar, String currentDurum) {
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Kesinti İşlemleri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('$uretici adına tanımlanan ${formatNumber.format(tutar)} ₺ tutarındaki kesinti kaydı üzerinde yapılacak işlemi seçin:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          if (currentDurum != 'odendi')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('kesintiler').doc(docId).update({'durum': 'odendi'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kesinti ödendi olarak güncellendi!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('Ödendi Yap'),
            ),
          if (currentDurum != 'iptal')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('kesintiler').doc(docId).update({'durum': 'iptal'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kesinti iptal edildi!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('İptal Et'),
            ),
          if (currentDurum != 'aktif')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('kesintiler').doc(docId).update({'durum': 'aktif'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Kesinti aktif yapıldı!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('Aktif Yap'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              await FirestoreService().deleteKesinti(docId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kesinti kaydı silindi!'), backgroundColor: AppColors.success),
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
        title: Text('Üretici Kesintileri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getKesintilerStream(firma: currentFirmaName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.hasData ? snapshot.data!.docs : [];
          
          double monthlyTotal = 0.0;
          int monthlyCount = 0;
          final List<QueryDocumentSnapshot> filteredKesintiler = [];

          int totalCount = 0;
          int aktifCount = 0;
          int odendiCount = 0;
          int iptalCount = 0;

          for (var doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final date = timestamp?.toDate() ?? DateTime.now();

            if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
              final durum = data['durum'] as String? ?? 'aktif';
              if (durum == 'aktif') aktifCount++;
              else if (durum == 'odendi') odendiCount++;
              else if (durum == 'iptal') iptalCount++;
              totalCount++;

              final uretici = data['uretici'] as String? ?? '';
              final aciklama = data['aciklama'] as String? ?? '';
              final tur = data['kesintiTuru'] as String? ?? 'Yem Kesintisi';
              final tutarVal = data['tutar'] ?? 0.0;
              final double tutar = tutarVal is num ? tutarVal.toDouble() : (double.tryParse(tutarVal.toString()) ?? 0.0);

              final matchesSearch = _searchQuery.isEmpty ||
                  uretici.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  aciklama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  tur.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  tutar.toString().contains(_searchQuery);

              final matchesStatus = _selectedStatus == 'tumu' || durum == _selectedStatus;

              if (matchesSearch && matchesStatus) {
                filteredKesintiler.add(doc);
                monthlyTotal += tutar;
                monthlyCount++;
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // + Kesinti Ekle Button
              ElevatedButton.icon(
                onPressed: () => context.go('/firma/finans/kesintiler/ekle'),
                icon: const Icon(Icons.content_cut_rounded, color: Colors.white, size: 18),
                label: const Text('Kesinti Uygula (Ekle)'),
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
                    hintText: 'Üretici adı, kesinti türü veya açıklama ile ar...',
                    hintStyle: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Status Tabs
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatusTab('tumu', 'Tümü', totalCount),
                    _buildStatusTab('aktif', 'Aktif', aktifCount),
                    _buildStatusTab('odendi', 'Ödenen', odendiCount),
                    _buildStatusTab('iptal', 'İptal', iptalCount),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Total Kesinti Summary Card
              AppCard(
                padding: const EdgeInsets.all(16),
                shadow: AppShadows.sm,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.content_cut_rounded, color: AppColors.primary600, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$monthStr Toplam Kesinti', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          '${formatNumber.format(monthlyTotal)} ₺',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray800),
                        ),
                        Text('$monthlyCount kesinti kaydı', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Kesinti Geçmişi Title
              Text(
                'Kesinti Geçmişi',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
              ),
              const SizedBox(height: 12),

              // List of Kesintiler
              if (filteredKesintiler.isEmpty)
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
                      const Icon(Icons.content_cut_rounded, size: 48, color: AppColors.gray300),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz uygun kesinti kaydı bulunmuyor',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Filtreyi değiştirin veya yeni kesinti ekleyin',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredKesintiler.length,
                  itemBuilder: (context, idx) {
                    final doc = filteredKesintiler[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final uretici = data['uretici'] as String? ?? '';
                    final aciklama = data['aciklama'] as String? ?? '';
                    final tur = data['kesintiTuru'] as String? ?? 'Yem Kesintisi';
                    final tarih = data['tarih'] as String? ?? '';
                    final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
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
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(uretici, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        tur,
                                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.orange[800]),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '$tarih • Süt Ödeme Kesintisi',
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
                                onPressed: () => _showKesintiIslemleriDialog(context, doc.id, uretici, tutar, durum),
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

// --- KESİNTİ UYGULA SCREEN ---
class KesintiUygulaScreen extends StatefulWidget {
  const KesintiUygulaScreen({super.key});

  @override
  State<KesintiUygulaScreen> createState() => _KesintiUygulaScreenState();
}

class _KesintiUygulaScreenState extends State<KesintiUygulaScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedUretici;
  final _tutarCtrl = TextEditingController();
  final _aciklamaCtrl = TextEditingController();
  String _kesintiTuru = 'Yem Kesintisi';
  DateTime _kesintiTarihi = DateTime.now();

  final List<String> _kesintiTurleri = [
    'Yem Kesintisi',
    'Ekipman Kesintisi',
    'Kooperatif Aidatı',
    'Bağış',
    'Diğer'
  ];

  @override
  void dispose() {
    _tutarCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _kesintiTarihi,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() {
        _kesintiTarihi = picked;
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
        title: Text('Kesinti Uygula', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans/kesintiler'),
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
                // Card: Form Girdileri
                AppCard(
                  padding: const EdgeInsets.all(16),
                  shadow: AppShadows.sm,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üretici Seçimi
                      SearchableDropdown(
                        items: producers,
                        value: _selectedUretici,
                        hint: 'Kesinti Yapılacak Üreticiyi Seçin',
                        label: 'Üretici Seçiniz *',
                        validator: (value) => value == null || value.isEmpty ? 'Lütfen bir üretici seçin' : null,
                        onChanged: (val) => setState(() => _selectedUretici = val),
                      ),
                      const SizedBox(height: 16),

                      // Kesinti Türü
                      Text('Kesinti Türü *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _kesintiTuru,
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(),
                        ),
                        items: _kesintiTurleri.map((t) => DropdownMenuItem(value: t, child: Text(t, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _kesintiTuru = val);
                        },
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
                          final numVal = double.tryParse(value.replaceAll(',', '.'));
                          if (numVal == null) return 'Lütfen geçerli bir sayı girin';
                          if (numVal <= 0) return 'Tutar sıfırdan büyük olmalıdır';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Gerekçe / Açıklama
                      Text('Açıklama / Kesinti Detayı *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _aciklamaCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Kesinti ile ilgili ayrıntıları giriniz',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Lütfen açıklama girin' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Card: Tarih
                AppCard(
                  padding: const EdgeInsets.all(16),
                  shadow: AppShadows.sm,
                  child: InkWell(
                    onTap: () => _selectDate(context),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.primary600, size: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kesinti Tarihi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                            const SizedBox(height: 2),
                            Text(
                              dateFormat.format(_kesintiTarihi),
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Kaydet Button
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final double tutar = double.parse(_tutarCtrl.text.replaceAll(',', '.'));

                      await FirestoreService().addKesinti({
                        'firma': currentFirmaName,
                        'uretici': _selectedUretici,
                        'kesintiTuru': _kesintiTuru,
                        'tutar': tutar,
                        'aciklama': _aciklamaCtrl.text,
                        'tarih': DateFormat('dd.MM.yyyy').format(_kesintiTarihi),
                        'durum': 'aktif',
                      });

                      // Send notification to uretici
                      await FirebaseFirestore.instance.collection('bildirimler').add({
                        'aliciName': _selectedUretici,
                        'baslik': 'Ödemenizden Kesinti Yapıldı',
                        'icerik': '$currentFirmaName tarafından hesabınızdan ${_kesintiTuru} kapsamında ${tutar.toStringAsFixed(2)} ₺ kesinti yapılmıştır. Gerekçe: ${_aciklamaCtrl.text}',
                        'okundu': false,
                        'tarih': DateFormat('dd.MM.yyyy').format(_kesintiTarihi),
                        'timestamp': FieldValue.serverTimestamp(),
                        'tip': 'kesinti',
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$_selectedUretici üreticisine kesinti kaydı başarıyla eklendi!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        context.go('/firma/finans/kesintiler');
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
                  child: Text('Kesintiyi Kaydet ve Gönder', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
