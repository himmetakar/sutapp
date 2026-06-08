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

// --- MÜŞTERİ CEZALARI LIST SCREEN ---
class MusteriCezalariScreen extends StatefulWidget {
  const MusteriCezalariScreen({super.key});

  @override
  State<MusteriCezalariScreen> createState() => _MusteriCezalariScreenState();
}

class _MusteriCezalariScreenState extends State<MusteriCezalariScreen> {
  DateTime _selectedDate = DateTime.now();
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  String _selectedStatus = 'tumu'; // tumu, aktif, odendi, iptal
  late Stream<QuerySnapshot> _cezalarStream;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    _cezalarStream = FirestoreService().getCezalarStream(firma: currentFirmaName);
  }

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

  void _showCezaIslemleriDialog(BuildContext context, String docId, String uretici, String cezaStr, String currentDurum) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Ceza İşlemleri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('$uretici adına tanımlanan $cezaStr tutarındaki ceza kaydı üzerinde yapılacak işlemi seçin:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          if (currentDurum != 'odendi')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('cezalar').doc(docId).update({'durum': 'odendi'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ceza ödendi olarak güncellendi!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('Ödendi Yap'),
            ),
          if (currentDurum != 'iptal')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('cezalar').doc(docId).update({'durum': 'iptal'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ceza iptal edildi!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('İptal Et'),
            ),
          if (currentDurum != 'aktif')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('cezalar').doc(docId).update({'durum': 'aktif'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ceza aktif yapıldı!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('Aktif Yap'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              await FirestoreService().deleteCeza(docId);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ceza kaydı silindi!'), backgroundColor: AppColors.success),
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
        title: Text('Müşteri Cezaları', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: _cezalarStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.hasData ? snapshot.data!.docs : [];
          
          double monthlyTotal = 0.0;
          int monthlyCount = 0;
          final List<QueryDocumentSnapshot> filteredCezalar = [];

          int totalCount = 0;
          int aktifCount = 0;
          int odendiCount = 0;
          int iptalCount = 0;

          for (var doc in allDocs) {
            final data = doc.data() as Map<String, dynamic>;
            DateTime? date;
            final rawDate = data['tarih'];
            if (rawDate != null) {
              try {
                date = DateFormat('dd.MM.yyyy').parse(rawDate.toString());
              } catch (_) {
                try {
                  date = DateFormat('dd MMMM yyyy', 'tr_TR').parse(rawDate.toString());
                } catch (_) {}
              }
            }
            if (date == null && data['timestamp'] != null) {
              date = (data['timestamp'] as Timestamp).toDate();
            }
            date ??= DateTime.now();

            if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
              final durum = data['durum'] as String? ?? 'aktif';
              if (durum == 'aktif') aktifCount++;
              else if (durum == 'odendi') odendiCount++;
              else if (durum == 'iptal') iptalCount++;
              totalCount++;

              final uretici = data['uretici'] as String? ?? '';
              final aciklama = data['aciklama'] as String? ?? '';
              final tip = data['tip'] as String? ?? 'miktarsal';
              final tutarVal = data['tutar'] ?? 0.0;
              final double tutar = tutarVal is num ? tutarVal.toDouble() : (double.tryParse(tutarVal.toString()) ?? 0.0);

              final matchesSearch = _searchQuery.isEmpty ||
                  uretici.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  aciklama.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                  tutar.toString().contains(_searchQuery);

              final matchesStatus = _selectedStatus == 'tumu' || durum == _selectedStatus;

              if (matchesSearch && matchesStatus) {
                filteredCezalar.add(doc);
                if (tip == 'miktarsal') {
                  monthlyTotal += tutar;
                }
                monthlyCount++;
              }
            }
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // + Ceza Kes Button
              ElevatedButton.icon(
                onPressed: () => context.go('/firma/finans/cezalar/ekle'),
                icon: const Icon(Icons.gavel_rounded, color: Colors.white, size: 18),
                label: const Text('Ceza Uygula (Kes)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
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
                      const Icon(Icons.calendar_month_rounded, color: AppColors.danger, size: 18),
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
                    hintText: 'Müşteri adı, ceza veya açıklama ile ar...',
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

              // Total Ceza Summary Card
              AppCard(
                padding: const EdgeInsets.all(16),
                shadow: AppShadows.sm,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.gavel_rounded, color: Colors.red, size: 22),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$monthStr Toplam Sabit Ceza', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          '${formatNumber.format(monthlyTotal)} ₺',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.gray800),
                        ),
                        Text('$monthlyCount ceza kaydı (Oransal cezalar hariç)', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Ceza Geçmişi Title
              Text(
                'Ceza Geçmişi',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
              ),
              const SizedBox(height: 12),

              // List of Cezalar
              if (filteredCezalar.isEmpty)
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
                      const Icon(Icons.gavel_rounded, size: 48, color: AppColors.gray300),
                      const SizedBox(height: 12),
                      Text(
                        'Henüz uygun ceza kaydı bulunmuyor',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Filtreyi değiştirin veya yeni ceza ekleyin',
                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filteredCezalar.length,
                  itemBuilder: (context, idx) {
                    final doc = filteredCezalar[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final uretici = data['uretici'] as String? ?? '';
                    final aciklama = data['aciklama'] as String? ?? '';
                    final tip = data['tip'] as String? ?? 'miktarsal';
                    final tarih = data['tarih'] as String? ?? '';
                    final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                    final double oran = (data['oran'] as num?)?.toDouble() ?? 0.0;
                    final durum = data['durum'] as String? ?? 'aktif';

                    final isOransal = tip == 'oransal';
                    final String cezaStr = isOransal ? '%${oran.toStringAsFixed(0)}' : '${formatNumber.format(tutar)} ₺';

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
                        border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
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
                                        color: isOransal ? Colors.purple.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        isOransal ? 'Oransal' : 'Miktarsal',
                                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: isOransal ? Colors.purple : Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      '$tarih • Süt Kalite Cezası',
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
                                '- $cezaStr',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.more_vert_rounded, color: AppColors.gray500, size: 20),
                                onPressed: () => _showCezaIslemleriDialog(context, doc.id, uretici, cezaStr, durum),
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

// --- CEZA KES SCREEN ---
class CezaKesScreen extends StatefulWidget {
  const CezaKesScreen({super.key});

  @override
  State<CezaKesScreen> createState() => _CezaKesScreenState();
}

class _CezaKesScreenState extends State<CezaKesScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedUretici;
  final _degerCtrl = TextEditingController(); // Tutar veya Oran değeri
  final _aciklamaCtrl = TextEditingController();
  String _cezaTipi = 'miktarsal'; // 'miktarsal' | 'oransal'
  DateTime _cezaTarihi = DateTime.now();
  late Stream<QuerySnapshot> _producersStream;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    _producersStream = FirestoreService().getProducersStream(firma: currentFirmaName);
  }

  @override
  void dispose() {
    _degerCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _cezaTarihi,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('tr', 'TR'),
    );
    if (picked != null) {
      setState(() {
        _cezaTarihi = picked;
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
        title: Text('Ceza Kes', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans/cezalar'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: _producersStream,
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
                        hint: 'Ceza Uygulanacak Üreticiyi Seçin',
                        label: 'Üretici / Müşteri Seçiniz *',
                        validator: (value) => value == null || value.isEmpty ? 'Lütfen bir üretici seçin' : null,
                        onChanged: (val) => setState(() => _selectedUretici = val),
                      ),
                      const SizedBox(height: 16),

                      // Ceza Tipi Selector
                      Text('Ceza Yöntemi / Tipi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildTipButton('miktarsal', 'Miktarsal (₺)', Icons.money_off_rounded),
                          const SizedBox(width: 8),
                          _buildTipButton('oransal', 'Oransal (%)', Icons.percent_rounded),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Ceza Tutarı / Oranı Değeri
                      Text(
                        _cezaTipi == 'miktarsal' ? 'Ceza Tutarı (₺) *' : 'Ceza Oranı (%) *',
                        style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _degerCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
                        decoration: InputDecoration(
                          hintText: _cezaTipi == 'miktarsal' ? '0.00' : 'Örn: 10',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Lütfen değer girin';
                          final numVal = double.tryParse(value.replaceAll(',', '.'));
                          if (numVal == null) return 'Lütfen geçerli bir sayı girin';
                          if (_cezaTipi == 'oransal' && (numVal <= 0 || numVal > 100)) {
                            return 'Oran 1 ile 100 arasında olmalıdır';
                          }
                          if (numVal <= 0) return 'Tutar sıfırdan büyük olmalıdır';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Açıklama
                      Text('Ceza Gerekçesi / Açıklama *', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _aciklamaCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Örn: Sütte su tespiti veya antibiyotikli süt kalıntısı',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Lütfen ceza gerekçesi yazın' : null,
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
                        const Icon(Icons.calendar_today_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Ceza Tarihi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                            const SizedBox(height: 2),
                            Text(
                              dateFormat.format(_cezaTarihi),
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
                      final double val = double.parse(_degerCtrl.text.replaceAll(',', '.'));

                      await FirestoreService().addCeza({
                        'firma': currentFirmaName,
                        'uretici': _selectedUretici,
                        'tip': _cezaTipi,
                        'tutar': _cezaTipi == 'miktarsal' ? val : 0.0,
                        'oran': _cezaTipi == 'oransal' ? val : 0.0,
                        'aciklama': _aciklamaCtrl.text,
                        'tarih': DateFormat('dd.MM.yyyy').format(_cezaTarihi),
                        'timestamp': Timestamp.fromDate(_cezaTarihi),
                        'durum': 'aktif',
                      });

                      // Send notification to client
                      final detailStr = _cezaTipi == 'oransal' ? '%${val.toStringAsFixed(0)} oranında' : '${val.toStringAsFixed(2)} ₺ tutarında';
                      await FirebaseFirestore.instance.collection('bildirimler').add({
                        'aliciName': _selectedUretici,
                        'baslik': 'Süt Kalite Cezası Uygulandı',
                        'icerik': '$currentFirmaName tarafından hesabınıza $detailStr ceza uygulanmıştır. Gerekçe: ${_aciklamaCtrl.text}',
                        'okundu': false,
                        'tarih': DateFormat('dd.MM.yyyy').format(_cezaTarihi),
                        'timestamp': FieldValue.serverTimestamp(),
                        'tip': 'ceza',
                      });

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$_selectedUretici üreticisine ceza kaydı başarıyla eklendi!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        context.go('/firma/finans/cezalar');
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  child: Text('Cezayı Kaydet ve Bildir', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTipButton(String value, String label, IconData icon) {
    final isSelected = _cezaTipi == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _cezaTipi = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.red : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? Colors.red : AppColors.gray300),
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
