import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaUreticiListesiScreen extends StatefulWidget {
  const FirmaUreticiListesiScreen({super.key});

  @override
  State<FirmaUreticiListesiScreen> createState() => _FirmaUreticiListesiScreenState();
}

class _FirmaUreticiListesiScreenState extends State<FirmaUreticiListesiScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddProducerDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    showDialog(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final bolgeCtrl = TextEditingController(text: 'Merkez');

        String? selectedGroup;
        String? selectedBirlik;

        bool isSicak = false;
        bool isYem = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Yeni Üretici Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Ad Soyad', hintText: 'Örn: Mustafa Yılmaz'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Telefon', hintText: 'Örn: 0532 999 8877'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bolgeCtrl,
                        decoration: const InputDecoration(labelText: 'Bölge / İlçe', hintText: 'Örn: Kocasinan'),
                      ),
                      const SizedBox(height: 16),
                      
                      // Group dropdown (loaded dynamically)
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('musteri_gruplari').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final List<String> groups = docs.map((d) => d['ad'] as String).toList();
                          
                          return DropdownButtonFormField<String>(
                            value: selectedGroup,
                            hint: const Text('Üretici Grubu Seçin'),
                            decoration: const InputDecoration(labelText: 'Grup'),
                            items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) => setState(() => selectedGroup = val),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Birlik dropdown (loaded dynamically)
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('birlikler').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final List<String> birlikler = docs.map((d) => d['ad'] as String).toList();
                          
                          return DropdownButtonFormField<String>(
                            value: selectedBirlik,
                            hint: const Text('Birlik Seçin (İsteğe Bağlı)'),
                            decoration: const InputDecoration(labelText: 'Birlik Kaydı'),
                            items: birlikler.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (val) => setState(() => selectedBirlik = val),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Custom toggle
                      _buildTempToggle(
                        isSicak,
                        (val) => setState(() => isSicak = val),
                        enabled: !isYem,
                      ),
                      const SizedBox(height: 16),
                      _buildCustomerTypeToggle(
                        isYem,
                        (val) => setState(() => isYem = val),
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
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final bolge = bolgeCtrl.text.trim();
                    final selectedMilkType = isYem ? 'Yok' : (isSicak ? 'Sıcak süt' : 'Soğuk süt');

                    if (name.isEmpty || phone.isEmpty || bolge.isEmpty) return;

                    await _db.collection('ureticiler').add({
                      'name': name,
                      'phone': phone,
                      'bolge': bolge,
                      'group': selectedGroup ?? 'Genel',
                      'birlik': selectedBirlik ?? 'Yok',
                      'avg': 30.0,
                      'total': 0.0,
                      'firmalar': [currentFirmaName],
                      'lastMilkType': selectedMilkType,
                      'customerType': isYem ? 'yem' : 'sut',
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Yeni üretici başarıyla eklendi!'), backgroundColor: AppColors.success),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditProducerDialog(DocumentSnapshot doc) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final data = doc.data() as Map<String, dynamic>;

    showDialog(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController(text: data['name'] ?? '');
        final phoneCtrl = TextEditingController(text: data['phone'] ?? '');
        final bolgeCtrl = TextEditingController(text: data['bolge'] ?? '');

        String? selectedGroup = data['group'];
        String? selectedBirlik = data['birlik'];

        final currentMilkType = data['lastMilkType'] ?? 'Soğuk süt';
        bool isSicak = currentMilkType == 'Sıcak süt';
        bool isYem = data['customerType'] == 'yem';

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Üreticiyi Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Ad Soyad'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Telefon'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bolgeCtrl,
                        decoration: const InputDecoration(labelText: 'Bölge / İlçe'),
                      ),
                      const SizedBox(height: 16),
                      
                      // Group dropdown
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('musteri_gruplari').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final List<String> groups = docs.map((d) => d['ad'] as String).toList();
                          if (selectedGroup != null && !groups.contains(selectedGroup)) {
                            groups.add(selectedGroup!);
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: selectedGroup,
                            hint: const Text('Üretici Grubu Seçin'),
                            decoration: const InputDecoration(labelText: 'Grup'),
                            items: groups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (val) => setState(() => selectedGroup = val),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Birlik dropdown
                      StreamBuilder<QuerySnapshot>(
                        stream: _db.collection('birlikler').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, snapshot) {
                          final docs = snapshot.data?.docs ?? [];
                          final List<String> birlikler = docs.map((d) => d['ad'] as String).toList();
                          if (selectedBirlik != null && !birlikler.contains(selectedBirlik)) {
                            birlikler.add(selectedBirlik!);
                          }
                          
                          return DropdownButtonFormField<String>(
                            value: selectedBirlik,
                            hint: const Text('Birlik Seçin (İsteğe Bağlı)'),
                            decoration: const InputDecoration(labelText: 'Birlik Kaydı'),
                            items: birlikler.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (val) => setState(() => selectedBirlik = val),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Custom toggle
                      _buildTempToggle(
                        isSicak,
                        (val) => setState(() => isSicak = val),
                        enabled: !isYem,
                      ),
                      const SizedBox(height: 16),
                      _buildCustomerTypeToggle(
                        isYem,
                        (val) => setState(() => isYem = val),
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
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final bolge = bolgeCtrl.text.trim();
                    final selectedMilkType = isYem ? 'Yok' : (isSicak ? 'Sıcak süt' : 'Soğuk süt');

                    if (name.isEmpty || phone.isEmpty || bolge.isEmpty) return;

                    await doc.reference.update({
                      'name': name,
                      'phone': phone,
                      'bolge': bolge,
                      'group': selectedGroup ?? 'Genel',
                      'birlik': selectedBirlik ?? 'Yok',
                      'lastMilkType': selectedMilkType,
                      'customerType': isYem ? 'yem' : 'sut',
                    });

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Üretici bilgileri başarıyla güncellendi!'), backgroundColor: AppColors.success),
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

  void _showProducerDetailsDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? '';
    final phone = data['phone'] ?? '';
    final group = data['group'] ?? '';
    final bolge = data['bolge'] ?? '';
    final birlik = data['birlik'] ?? 'Yok';
    final avg = (data['avg'] as num?)?.toDouble() ?? 0.0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    String lastMilkType = data['lastMilkType'] ?? 'Soğuk süt';
    String customerType = data['customerType'] ?? 'sut';

    const List<String> milkTypes = ['Soğuk süt', 'Sıcak süt', 'C kalite', 'D kalite'];
    if (!milkTypes.contains(lastMilkType)) {
      lastMilkType = 'Soğuk süt';
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Üretici Bilgileri',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow(Icons.person_rounded, 'Ad Soyad', name),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.phone_rounded, 'Telefon', phone),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.location_on_rounded, 'Bölge / Mahalle', '$bolge - $group'),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.account_balance_rounded, 'Birlik Kaydı', birlik),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.bar_chart_rounded, 'Günlük Ort. Süt', '${avg.toStringAsFixed(0)} LT'),
                const SizedBox(height: 12),
                _buildDetailRow(Icons.water_drop_rounded, 'Toplam Alınan Süt', '${total.toStringAsFixed(0)} LT'),
                const SizedBox(height: 12),
                _buildDetailRow(
                  Icons.category_rounded,
                  'Üretici Türü',
                  customerType == 'yem' ? 'Yem Müşterisi' : 'Süt Üreticisi',
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: lastMilkType,
                  decoration: const InputDecoration(
                    labelText: 'Varsayılan Süt Türü',
                    border: OutlineInputBorder(),
                  ),
                  items: milkTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) async {
                    if (val != null) {
                      setDialogState(() {
                        lastMilkType = val;
                      });
                      await doc.reference.update({'lastMilkType': val});
                    }
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: customerType,
                  decoration: const InputDecoration(
                    labelText: 'Varsayılan Üretici Türü',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'sut', child: Text('Süt Üreticisi')),
                    DropdownMenuItem(value: 'yem', child: Text('Yem Müşterisi')),
                  ],
                  onChanged: (val) async {
                    if (val != null) {
                      setDialogState(() {
                        customerType = val;
                      });
                      await doc.reference.update({'customerType': val});
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Kapat',
                style: GoogleFonts.inter(color: AppColors.primary600, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDigitalCardDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? '';
    final group = data['group'] ?? 'Genel';
    final avg = (data['avg'] as num?)?.toDouble() ?? 0.0;
    final total = (data['total'] as num?)?.toDouble() ?? 0.0;
    final docId = doc.id;
    final cardNumber = "8024 ${docId.hashCode.abs().toString().padRight(12, '0').substring(0, 12).replaceAllMapped(RegExp(r".{4}"), (match) => "${match.group(0)} ")}".trim();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The Card
            Container(
              width: double.infinity,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  )
                ],
              ),
              child: Stack(
                children: [
                  // Decorative water drop background
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Opacity(
                      opacity: 0.1,
                      child: Icon(Icons.water_drop_rounded, size: 180, color: Colors.blue[300]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Card Header
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.water_drop_rounded, color: Colors.blue, size: 24),
                                const SizedBox(width: 6),
                                Text(
                                  'SütApp Kart',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(Icons.contactless_outlined, color: Colors.white60, size: 24),
                          ],
                        ),
                        // Chip
                        Container(
                          width: 40,
                          height: 30,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFCD34D), Color(0xFFF59E0B)],
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        // Producer Details & Card Number
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.toUpperCase(),
                              style: GoogleFonts.spaceMono(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  cardNumber,
                                  style: GoogleFonts.spaceMono(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    letterSpacing: 2.0,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    group.toUpperCase(),
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Details & Action Modal Body
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    'Dijital Süt Kartı',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Üreticinin günlük süt alımlarını ve aylık detaylı kartını inceleyin.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      context.push('/firma/dijital-kart?name=$name');
                    },
                    icon: const Icon(Icons.badge_rounded, size: 16),
                    label: const Text('Dijital Süt Kartını Görüntüle'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Producer statistics row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('Günlük Ort.', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('${avg.toStringAsFixed(0)} LT', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                        ],
                      ),
                      Container(width: 1, height: 24, color: AppColors.gray200),
                      Column(
                        children: [
                          Text('Toplam Teslimat', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text('${total.toStringAsFixed(0)} LT', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.gray600,
                      side: const BorderSide(color: AppColors.gray200),
                      minimumSize: const Size(double.infinity, 40),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Kapat'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary500),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray800, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTempToggle(bool isSicak, ValueChanged<bool> onChanged, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Varsayılan Süt Sıcaklığı',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: enabled ? () {
            onChanged(!isSicak);
          } : null,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(24),
              ),
              child: Stack(
                children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: isSicak ? Alignment.centerLeft : Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSicak ? Colors.red[600] : Colors.blue[600],
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isSicak ? Colors.red : Colors.blue).withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isSicak ? Icons.whatshot : Icons.ac_unit,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isSicak ? 'Sıcak süt' : 'Soğuk süt',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'Sıcak süt',
                          style: GoogleFonts.inter(
                            color: isSicak ? Colors.transparent : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Soğuk süt',
                          style: GoogleFonts.inter(
                            color: !isSicak ? Colors.transparent : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCustomerTypeToggle(bool isYem, ValueChanged<bool> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Üretici Türü',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            onChanged(!isYem);
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: isYem ? Alignment.centerRight : Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isYem ? Colors.amber[600] : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isYem ? Colors.amber : Colors.grey).withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                          border: isYem ? null : Border.all(color: Colors.grey[300]!, width: 0.5),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isYem ? Icons.grass_rounded : Icons.water_drop_rounded,
                                color: isYem ? Colors.white : AppColors.primary600,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isYem ? 'Yem Müşterisi' : 'Süt Üreticisi',
                                style: GoogleFonts.inter(
                                  color: isYem ? Colors.white : AppColors.primary800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'Süt Üreticisi',
                          style: GoogleFonts.inter(
                            color: !isYem ? Colors.transparent : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Yem Müşterisi',
                          style: GoogleFonts.inter(
                            color: isYem ? Colors.transparent : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text('Üretici Listesi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/ureticiler'),
        ),
      ),
      floatingActionButton: AppFab(
        icon: Icons.person_add_rounded,
        label: 'Üretici Ekle',
        onTap: _showAddProducerDialog,
      ),
      body: Column(
        children: [
          // Search Field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Üretici adı veya telefon ara...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),

          // Producers list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.collection('ureticiler').where('firmalar', arrayContains: currentFirmaName).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }

                final docs = snapshot.data?.docs ?? [];
                
                // Filter docs based on search
                final filteredDocs = docs.where((doc) {
                  if (_searchQuery.isEmpty) return true;
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final phone = (data['phone'] as String? ?? '').toLowerCase();
                  return name.contains(_searchQuery.toLowerCase()) || phone.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'Sistemde kayıtlı üretici bulunmuyor.',
                      style: GoogleFonts.inter(color: AppColors.gray500),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (_, i) {
                    final doc = filteredDocs[i];
                    final u = doc.data() as Map<String, dynamic>;
                    final name = u['name'] ?? '';
                    final phone = u['phone'] ?? '';
                    final group = u['group'] ?? 'Genel';
                    final birlik = u['birlik'] ?? 'Yok';

                    final isYem = u['customerType'] == 'yem';

                    return GestureDetector(
                      onTap: () => _showProducerDetailsDialog(doc),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isYem ? Colors.amber[50]!.withValues(alpha: 0.7) : Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: AppShadows.sm,
                          border: isYem
                              ? Border.all(color: Colors.amber[200]!, width: 1)
                              : null,
                        ),
                        child: Row(children: [
                          Container(
                            width: 38, height: 38,
                            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                            child: Center(child: Text(name.isNotEmpty ? name[0] : 'Ü', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white))),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 3),
                            Row(children: [
                              const Icon(Icons.phone_rounded, size: 11, color: AppColors.gray400),
                              const SizedBox(width: 4),
                              Text(phone, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                            ]),
                            const SizedBox(height: 5),
                            Row(children: [
                              StatusBadge.info(group),
                              if (birlik != 'Yok') ...[
                                const SizedBox(width: 6),
                                StatusBadge.active(birlik),
                              ],
                            ]),
                          ])),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.badge_rounded, color: Colors.orange, size: 20),
                                onPressed: () {
                                  _showDigitalCardDialog(doc);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.description_rounded, color: AppColors.primary600, size: 20),
                                onPressed: () {
                                  context.push('/firma/hesap-ozeti?name=$name');
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_rounded, color: AppColors.gray500, size: 20),
                                onPressed: () {
                                  _showEditProducerDialog(doc);
                                },
                              ),
                            ],
                          ),
                        ]),
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
}

class BarcodePainter extends CustomPainter {
  final String data;
  BarcodePainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.0;

    double x = 10.0;
    final double step = (size.width - 20) / 40;
    for (int i = 0; i < 40; i++) {
      final double width = (i % 3 == 0 || i % 7 == 0) ? 3.5 : 1.5;
      paint.strokeWidth = width;
      if (i % 4 != 0) {
        canvas.drawLine(Offset(x, 2.0), Offset(x, size.height - 15.0), paint);
      }
      x += step;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: data,
        style: GoogleFonts.spaceMono(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, size.height - 12.0));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
