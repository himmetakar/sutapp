import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'dart:math';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class UrunlerScreen extends StatefulWidget {
  const UrunlerScreen({super.key});

  @override
  State<UrunlerScreen> createState() => _UrunlerScreenState();
}

class _UrunlerScreenState extends State<UrunlerScreen> {
  String _currentView = 'hub'; // hub, kategoriler, stok, siparisler, satis_raporlari, urunler_list
  bool _isLoading = false;
  
  // Date range for Sales Reports
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  // Search & Filter State
  String _productSearchQuery = '';
  String _selectedCategory = 'Tümü';
  final _productSearchCtrl = TextEditingController();

  String _stockSearchQuery = '';
  String _stockFilter = 'Tümü'; // Tümü, Düşük, Kritik, Tükenen
  final _stockSearchCtrl = TextEditingController();

  String _orderSearchQuery = '';
  String _orderFilter = 'Tümü'; // Tümü, Bekliyor, Onaylandı, Teslimatta, Teslim Edildi, İptal
  final _orderSearchCtrl = TextEditingController();

  String _salesReportTab = 'En Çok Satan'; // En Çok Satan, En Yüksek Ciro, En Çok Kar

  @override
  void dispose() {
    _productSearchCtrl.dispose();
    _stockSearchCtrl.dispose();
    _orderSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final currentFirmaName = auth.user?.displayName ?? '';
    final isFirma = auth.user?.role == UserRole.firma;

    // Producers bypass the hub directly to product list with ordering capabilities
    if (!isFirma) {
      return _buildProducerStoreView(currentFirmaName, auth.user?.displayName ?? 'Üretici');
    }

    switch (_currentView) {
      case 'kategoriler':
        return _buildCategoriesView(currentFirmaName);
      case 'stok':
        return _buildStockView(currentFirmaName);
      case 'siparisler':
        return _buildOrdersView(currentFirmaName);
      case 'satis_raporlari':
        return _buildSalesReportsView(currentFirmaName);
      case 'urunler_list':
        return _buildProductsListView(currentFirmaName);
      case 'hub':
      default:
        return _buildFirmaHubView(currentFirmaName);
    }
  }

  // --- ARROW BACK UTILITY ---
  Widget _buildBackButton() {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      onPressed: () {
        setState(() {
          _productSearchQuery = '';
          _selectedCategory = 'Tümü';
          _productSearchCtrl.clear();
          _stockSearchQuery = '';
          _stockFilter = 'Tümü';
          _stockSearchCtrl.clear();
          _orderSearchQuery = '';
          _orderFilter = 'Tümü';
          _orderSearchCtrl.clear();
          _currentView = 'hub';
        });
      },
    );
  }

  // Generate random order ID (e.g. #F0CDQ3)
  String _generateOrderId() {
    final rand = Random();
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return '#' + List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  // ==========================================
  // 1. FIRMA HUB VIEW
  // ==========================================
  Widget _buildFirmaHubView(String currentFirmaName) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Header Mockup style
            Center(
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.inventory_rounded, color: AppColors.danger, size: 24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ürün Yönetimi',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.gray900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ürün ve stok işlemlerini buradan yönetebilirsiniz',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Grid of 5 Actions
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 600 ? 3 : 2;
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: 1.3,
                  children: [
                    _buildHubGridItem(
                      label: 'Ürün Ekle',
                      icon: Icons.add_circle_rounded,
                      iconColor: const Color(0xFF009688),
                      bgColor: const Color(0xFFE0F2F1),
                      onTap: () => setState(() => _currentView = 'urunler_list'),
                    ),
                    _buildHubGridItem(
                      label: 'Kategori Ekle',
                      icon: Icons.local_offer_rounded,
                      iconColor: const Color(0xFF4CAF50),
                      bgColor: const Color(0xFFE8F5E9),
                      onTap: () => setState(() => _currentView = 'kategoriler'),
                    ),
                    _buildHubGridItem(
                      label: 'Stok Takibi',
                      icon: Icons.inventory_2_rounded,
                      iconColor: const Color(0xFFFF9800),
                      bgColor: const Color(0xFFFFF3E0),
                      onTap: () => setState(() => _currentView = 'stok'),
                    ),
                    _buildHubGridItem(
                      label: 'Sipariş Yönetimi',
                      icon: Icons.shopping_bag_rounded,
                      iconColor: const Color(0xFF2196F3),
                      bgColor: const Color(0xFFE3F2FD),
                      onTap: () => setState(() => _currentView = 'siparisler'),
                    ),
                    _buildHubGridItem(
                      label: 'Satış Raporları',
                      icon: Icons.bar_chart_rounded,
                      iconColor: const Color(0xFF9C27B0),
                      bgColor: const Color(0xFFF3E5F5),
                      onTap: () => setState(() => _currentView = 'satis_raporlari'),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHubGridItem({
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.gray200, width: 1),
      ),
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.gray800),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // 2. PRODUCT DIALOG (ADD / EDIT)
  // ==========================================
  void _showAddProductDialog(String currentFirmaName, {String? docId, Map<String, dynamic>? existingData}) {
    final adCtrl = TextEditingController(text: existingData?['ad'] ?? '');
    final birimCtrl = TextEditingController(text: existingData?['birim'] ?? '');
    final fiyatCtrl = TextEditingController(text: existingData != null ? (existingData['fiyat'] as num).toStringAsFixed(2) : '');
    final stokCtrl = TextEditingController(text: existingData != null ? (existingData['stok'] as num).toStringAsFixed(0) : '100');
    final minStokCtrl = TextEditingController(text: existingData != null ? (existingData['minStok'] as num?)?.toStringAsFixed(0) ?? '10' : '10');
    String selectedKategori = existingData?['kategori'] ?? 'Yem';
    final customKatCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(docId == null ? 'Yeni Ürün Ekle' : 'Ürün Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: adCtrl,
                  decoration: const InputDecoration(labelText: 'Ürün Adı *', hintText: 'Örn: 19 Protein Süt Yemi'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedKategori,
                  decoration: const InputDecoration(labelText: 'Kategori *'),
                  items: const [
                    DropdownMenuItem(value: 'Yem', child: Text('Yem')),
                    DropdownMenuItem(value: 'Vitamin', child: Text('Vitamin')),
                    DropdownMenuItem(value: 'İlaç', child: Text('İlaç')),
                    DropdownMenuItem(value: 'Araç Gereç', child: Text('Araç Gereç')),
                    DropdownMenuItem(value: 'Diğer', child: Text('Diğer (Yeni yazın)')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => selectedKategori = val);
                    }
                  },
                ),
                if (selectedKategori == 'Diğer') ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: customKatCtrl,
                    decoration: const InputDecoration(labelText: 'Yeni Kategori Adı *'),
                  ),
                ],
                const SizedBox(height: 12),
                TextField(
                  controller: birimCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Birim *',
                    hintText: 'Adet, KG, Litre, Torba vb.',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fiyatCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Birim Fiyatı (₺) *', hintText: 'Örn: 625.00'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: stokCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Stok Miktarı', hintText: 'Örn: 100'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: minStokCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kritik Stok Limiti *', hintText: 'Örn: 10'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Vazgeç', style: GoogleFonts.inter(color: AppColors.gray500)),
            ),
            ElevatedButton(
              onPressed: () async {
                final String ad = adCtrl.text.trim();
                final String birim = birimCtrl.text.trim();
                final double? fiyat = double.tryParse(fiyatCtrl.text.replaceAll(',', '.'));
                final double? stok = double.tryParse(stokCtrl.text);
                final double? minStok = double.tryParse(minStokCtrl.text);

                if (ad.isEmpty || birim.isEmpty || fiyat == null || fiyat <= 0 || minStok == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen zorunlu alanları doldurun!'), backgroundColor: AppColors.danger),
                  );
                  return;
                }

                final String kat = selectedKategori == 'Diğer' ? customKatCtrl.text.trim() : selectedKategori;
                if (kat.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen kategori adını girin!'), backgroundColor: AppColors.danger),
                  );
                  return;
                }

                final dataMap = {
                  'ad': ad,
                  'kategori': kat,
                  'birim': birim,
                  'fiyat': fiyat,
                  'stok': stok ?? 0.0,
                  'minStok': minStok,
                  'firma': currentFirmaName,
                  'timestamp': FieldValue.serverTimestamp(),
                };

                // Add category if not exists
                if (selectedKategori == 'Diğer') {
                  final catQuery = await FirebaseFirestore.instance
                      .collection('urunler_kategoriler')
                      .where('ad', isEqualTo: kat)
                      .where('firma', isEqualTo: currentFirmaName)
                      .limit(1)
                      .get();
                  if (catQuery.docs.isEmpty) {
                    await FirebaseFirestore.instance.collection('urunler_kategoriler').add({
                      'ad': kat,
                      'firma': currentFirmaName,
                      'timestamp': FieldValue.serverTimestamp(),
                    });
                  }
                }

                if (docId == null) {
                  await FirebaseFirestore.instance.collection('urunler').add(dataMap);
                } else {
                  await FirebaseFirestore.instance.collection('urunler').doc(docId).update(dataMap);
                }

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(docId == null ? 'Ürün başarıyla eklendi!' : 'Ürün güncellendi!'), backgroundColor: AppColors.success),
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
        ),
      ),
    );
  }

  Future<void> _deleteProduct(String docId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ürünü Sil'),
        content: const Text('Bu ürünü silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('urunler').doc(docId).delete();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ürün silindi!'), backgroundColor: AppColors.success),
      );
    }
  }

  // ==========================================
  // 3. CATEGORIES VIEW
  // ==========================================
  Widget _buildCategoriesView(String currentFirmaName) {
    final catCtrl = TextEditingController();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Kategori Yönetimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: _buildBackButton(),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Yeni Kategori Ekle'),
                          content: TextField(
                            controller: catCtrl,
                            decoration: const InputDecoration(labelText: 'Kategori Adı *'),
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                            ElevatedButton(
                              onPressed: () async {
                                final name = catCtrl.text.trim();
                                if (name.isEmpty) return;

                                await FirebaseFirestore.instance.collection('urunler_kategoriler').add({
                                  'ad': name,
                                  'firma': currentFirmaName,
                                  'timestamp': FieldValue.serverTimestamp(),
                                });
                                catCtrl.clear();
                                Navigator.pop(ctx);
                              },
                              child: const Text('Ekle'),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni Kategori'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary600,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 44),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('urunler_kategoriler')
                    .where('firma', isEqualTo: currentFirmaName)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Default categories if Firestore list is empty
                  final docs = snapshot.data?.docs ?? [];
                  final categories = docs.map((doc) => {'id': doc.id, 'ad': doc['ad'] as String}).toList();

                  // Insert static categories if they aren't saved yet
                  if (categories.isEmpty) {
                    final defaultCats = ['Araç Gereç', 'Vitamin', 'Yem', 'İlaç'];
                    return ListView.builder(
                      itemCount: defaultCats.length,
                      itemBuilder: (context, idx) {
                        return _buildCategoryItemRow(defaultCats[idx], null);
                      },
                    );
                  }

                  return ListView.builder(
                    itemCount: categories.length,
                    itemBuilder: (context, idx) {
                      return _buildCategoryItemRow(categories[idx]['ad']!, categories[idx]['id']);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItemRow(String name, String? docId) {
    IconData getCategoryIcon(String cat) {
      if (cat.contains('Araç') || cat.contains('Gereç')) return Icons.build_rounded;
      if (cat.contains('Vitamin')) return Icons.science_rounded;
      if (cat.contains('Yem')) return Icons.eco_rounded;
      if (cat.contains('İlaç') || cat.contains('ilac')) return Icons.medical_services_rounded;
      return Icons.folder_rounded;
    }

    Color getCategoryColor(String cat) {
      if (cat.contains('Araç') || cat.contains('Gereç')) return Colors.blue;
      if (cat.contains('Vitamin')) return Colors.green;
      if (cat.contains('Yem')) return Colors.orange;
      if (cat.contains('İlaç') || cat.contains('ilac')) return Colors.red;
      return Colors.purple;
    }

    final dateStr = DateFormat('dd.MM.yyyy').format(DateTime.now());

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: getCategoryColor(name).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(getCategoryIcon(name), color: getCategoryColor(name), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                Text(dateStr, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
              ],
            ),
          ),
          if (docId != null) ...[
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 20),
              onPressed: () {
                final editCtrl = TextEditingController(text: name);
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Kategori Düzenle'),
                    content: TextField(controller: editCtrl),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                      ElevatedButton(
                        onPressed: () async {
                          final newName = editCtrl.text.trim();
                          if (newName.isEmpty) return;
                          await FirebaseFirestore.instance.collection('urunler_kategoriler').doc(docId).update({'ad': newName});
                          Navigator.pop(ctx);
                        },
                        child: const Text('Güncelle'),
                      ),
                    ],
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 20),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Kategoriyi Sil'),
                    content: const Text('Bu kategoriyi silmek istediğinize emin misiniz?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Sil'),
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await FirebaseFirestore.instance.collection('urunler_kategoriler').doc(docId).delete();
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================
  // 3b. PRODUCT LIST VIEW
  // ==========================================
  Widget _buildProductsListView(String currentFirmaName) {
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Ürün Yönetimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: _buildBackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary600),
            onPressed: () => _showAddProductDialog(currentFirmaName),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _productSearchCtrl,
              decoration: InputDecoration(
                hintText: 'Ürün ara...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400),
                suffixIcon: _productSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          setState(() {
                            _productSearchQuery = '';
                            _productSearchCtrl.clear();
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
                  _productSearchQuery = val.trim();
                });
              },
            ),
          ),
          // Category Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                'Tümü',
                'Yem',
                'Vitamin',
                'İlaç',
                'Araç Gereç',
                'Diğer',
              ].map((category) {
                final isSelected = _selectedCategory == category;
                IconData catIcon;
                switch (category) {
                  case 'Yem':
                    catIcon = Icons.eco_rounded;
                    break;
                  case 'Vitamin':
                    catIcon = Icons.science_rounded;
                    break;
                  case 'İlaç':
                    catIcon = Icons.medical_services_rounded;
                    break;
                  case 'Araç Gereç':
                    catIcon = Icons.build_rounded;
                    break;
                  case 'Tümü':
                  default:
                    catIcon = Icons.category_rounded;
                    break;
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    avatar: Icon(catIcon, size: 16, color: isSelected ? Colors.white : AppColors.gray500),
                    label: Text(category),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    },
                    selectedColor: AppColors.primary600,
                    checkmarkColor: Colors.white,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.white : AppColors.gray700,
                    ),
                    backgroundColor: AppColors.gray50,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: isSelected ? AppColors.primary600 : AppColors.gray200),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 1),
          // Products Stream
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('urunler')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Hata oluştu: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red)),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                var docs = (snapshot.data?.docs ?? []).toList();

                // Sort by timestamp descending
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return -1;
                  if (bTime == null) return 1;
                  return bTime.compareTo(aTime);
                });

                // Filter by category
                if (_selectedCategory != 'Tümü') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final cat = data['kategori'] ?? 'Diğer';
                    if (_selectedCategory == 'Diğer') {
                      return cat != 'Yem' && cat != 'Vitamin' && cat != 'İlaç' && cat != 'Araç Gereç';
                    }
                    return cat == _selectedCategory;
                  }).toList();
                }

                // Filter by search query
                if (_productSearchQuery.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final ad = (data['ad'] ?? '').toString().toLowerCase();
                    return ad.contains(_productSearchQuery.toLowerCase());
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Ürün bulunamadı.',
                      style: GoogleFonts.inter(color: AppColors.gray400, fontSize: 13),
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
                    final minStok = (data['minStok'] as num?)?.toDouble() ?? 10.0;

                    // Stock badge configuration
                    Color stockBadgeColor = Colors.green;
                    String stockStatus = 'Stokta';
                    if (stok <= 0) {
                      stockBadgeColor = Colors.red;
                      stockStatus = 'Tükendi';
                    } else if (stok <= minStok) {
                      stockBadgeColor = Colors.orange;
                      stockStatus = 'Düşük';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                        boxShadow: AppShadows.sm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary50,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary600, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  ad,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.gray100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        kat,
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray600),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: stockBadgeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '$stockStatus: ${stok.toStringAsFixed(0)} $birim',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: stockBadgeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${formatNumber.format(fiyat)} ₺',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _showAddProductDialog(currentFirmaName, docId: docId, existingData: data),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit_rounded, color: Colors.blue, size: 16),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => _deleteProduct(docId),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.delete_rounded, color: Colors.red, size: 16),
                                    ),
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

  // ==========================================
  // 4. STOCK VIEW
  // ==========================================
  Widget _buildStockView(String currentFirmaName) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Stok Takibi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: _buildBackButton(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('urunler')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(child: Text('Kayıtlı ürün bulunmuyor.'));
          }

          // Calculations for metrics
          int totalProducts = docs.length;
          int criticalProducts = 0;
          int outOfStockProducts = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final double stock = (data['stok'] as num?)?.toDouble() ?? 0.0;
            final double minStok = (data['minStok'] as num?)?.toDouble() ?? 10.0;
            if (stock <= 0) {
              outOfStockProducts++;
            } else if (stock <= minStok) {
              criticalProducts++;
            }
          }

          // Apply filters in memory
          var filteredDocs = docs.toList();

          // Search query filter
          if (_stockSearchQuery.isNotEmpty) {
            filteredDocs = filteredDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ad = (data['ad'] ?? '').toString().toLowerCase();
              return ad.contains(_stockSearchQuery.toLowerCase());
            }).toList();
          }

          // Stock status filter
          if (_stockFilter != 'Tümü') {
            filteredDocs = filteredDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final double stock = (data['stok'] as num?)?.toDouble() ?? 0.0;
              final double minStok = (data['minStok'] as num?)?.toDouble() ?? 10.0;
              if (_stockFilter == 'Tükenen') {
                return stock <= 0;
              } else if (_stockFilter == 'Kritik') {
                return stock > 0 && stock <= minStok;
              } else if (_stockFilter == 'Normal') {
                return stock > minStok;
              }
              return true;
            }).toList();
          }

          return Column(
            children: [
              // Metrics bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                color: AppColors.gray50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildOrderStatItem(totalProducts.toString(), 'Toplam Ürün'),
                    _buildOrderStatItem(criticalProducts.toString(), 'Kritik Stok'),
                    _buildOrderStatItem(outOfStockProducts.toString(), 'Tükenen'),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Search input
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  controller: _stockSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ürün ara...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400),
                    suffixIcon: _stockSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              setState(() {
                                _stockSearchQuery = '';
                                _stockSearchCtrl.clear();
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
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  ),
                  onChanged: (val) {
                    setState(() {
                      _stockSearchQuery = val.trim();
                    });
                  },
                ),
              ),
              // Filter chips for stock
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: ['Tümü', 'Kritik', 'Tükenen', 'Normal'].map((filter) {
                    final isSelected = _stockFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _stockFilter = filter;
                          });
                        },
                        selectedColor: AppColors.primary600,
                        labelStyle: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : AppColors.gray700,
                        ),
                        backgroundColor: AppColors.gray50,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: isSelected ? AppColors.primary600 : AppColors.gray200),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, idx) {
                    final doc = filteredDocs[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final ad = data['ad'] ?? '';
                    final birim = data['birim'] ?? 'Adet';
                    final double stock = (data['stok'] as num?)?.toDouble() ?? 0.0;
                    final double minStok = (data['minStok'] as num?)?.toDouble() ?? 10.0;

                    Color badgeColor = Colors.green;
                    String statusText = 'Normal';
                    if (stock <= 0) {
                      badgeColor = Colors.red;
                      statusText = 'Tükendi';
                    } else if (stock <= minStok) {
                      badgeColor = Colors.orange;
                      statusText = 'Kritik';
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.gray200),
                        boxShadow: AppShadows.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ad, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text('Stok: ${stock.toStringAsFixed(0)} $birim', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600, fontWeight: FontWeight.w600)),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: GoogleFonts.inter(fontSize: 10, color: badgeColor, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              final changeCtrl = TextEditingController(text: stock.toStringAsFixed(0));
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Stok Güncelle'),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text('$ad için yeni stok değerini girin:'),
                                      const SizedBox(height: 10),
                                      TextField(
                                        controller: changeCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(labelText: 'Yeni Stok ($birim)'),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                                    ElevatedButton(
                                      onPressed: () async {
                                        final double? val = double.tryParse(changeCtrl.text);
                                        if (val == null) return;
                                        await doc.reference.update({'stok': val});
                                        Navigator.pop(ctx);
                                      },
                                      child: const Text('Güncelle'),
                                    ),
                                  ],
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary50,
                              foregroundColor: AppColors.primary600,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Güncelle'),
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

  // ==========================================
  // 5. ORDERS VIEW (SIPARIS YONETIMI)
  // ==========================================
  Widget _buildOrdersView(String currentFirmaName) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Sipariş Yönetimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: _buildBackButton(),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('urunler_siparisler')
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
          final docs = (snapshot.data?.docs ?? []).toList();
          // Sort locally by timestamp descending
          docs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Henüz ürün siparişi bulunmuyor.',
                style: GoogleFonts.inter(fontSize: 14, color: AppColors.gray400),
              ),
            );
          }

          // Header stats calculations
          int totalOrders = docs.length;
          int pendingOrders = docs.where((doc) => doc['durum'] == 'Bekliyor').length;
          int approvedOrders = docs.where((doc) => doc['durum'] == 'Onaylandı').length;
          int deliveredOrders = docs.where((doc) => doc['durum'] == 'Teslim Edildi').length;

          return Column(
            children: [
              // Summary bar matching mockup Sipariş Yönetimi
              Container(
                padding: const EdgeInsets.all(12),
                color: AppColors.gray50,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildOrderStatItem(totalOrders.toString(), 'Toplam'),
                    _buildOrderStatItem(pendingOrders.toString(), 'Bekleyen'),
                    _buildOrderStatItem(approvedOrders.toString(), 'Onaylanan'),
                    _buildOrderStatItem(deliveredOrders.toString(), 'Teslim Edilen'),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, idx) {
                    final doc = docs[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final uretici = data['uretici'] ?? 'Üretici';
                    final urun = data['urun'] ?? 'Ürün';
                    final miktar = (data['miktar'] as num?)?.toDouble() ?? 1.0;
                    final birim = data['birim'] ?? 'Adet';
                    final birimFiyat = (data['birimFiyat'] as num?)?.toDouble() ?? 0.0;
                    final toplam = (data['toplam'] as num?)?.toDouble() ?? 0.0;
                    final durum = data['durum'] ?? 'Bekliyor';
                    final tarih = data['tarih'] ?? '';
                    final saat = data['saat'] ?? '';
                    final orderId = data['id'] ?? '#ORDERID';

                    Color statusColor = Colors.orange;
                    if (durum == 'Onaylandı') statusColor = Colors.blue;
                    if (durum == 'Teslimatta') statusColor = Colors.purple;
                    if (durum == 'Teslim Edildi') statusColor = Colors.green;
                    if (durum == 'İptal') statusColor = Colors.red;

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.gray200),
                      ),
                      color: Colors.white,
                      child: Padding(
                        padding: const EdgeInsets.all(14.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.person_rounded, size: 18, color: AppColors.gray500),
                                    const SizedBox(width: 6),
                                    Text(
                                      uretici,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.gray800),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    durum,
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Sipariş $orderId • $tarih $saat', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                            const Divider(height: 20),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  urun,
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.gray800),
                                ),
                                Text(
                                  '${miktar.toStringAsFixed(0)} $birim x ${birimFiyat.toStringAsFixed(2)} ₺',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Toplam:',
                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray700),
                                ),
                                Text(
                                  '${toplam.toStringAsFixed(2)} ₺',
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.primary600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Operations row matching mockup: Düzenle, Onayla, Teslim Et, İptal, Sil
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  if (durum == 'Bekliyor')
                                    _buildOrderActionButton('Onayla', Colors.green, () async {
                                      await doc.reference.update({'durum': 'Onaylandı'});
                                    }),
                                  if (durum == 'Onaylandı')
                                    _buildOrderActionButton('Teslimatta Yap', Colors.purple, () async {
                                      await doc.reference.update({'durum': 'Teslimatta'});
                                    }),
                                  if (durum == 'Teslimatta')
                                    _buildOrderActionButton('Teslim Et', Colors.green, () async {
                                      await doc.reference.update({'durum': 'Teslim Edildi'});
                                      
                                      // Subtract stock
                                      final urunQuery = await FirebaseFirestore.instance
                                          .collection('urunler')
                                          .where('ad', isEqualTo: urun)
                                          .where('firma', isEqualTo: currentFirmaName)
                                          .limit(1)
                                          .get();
                                      if (urunQuery.docs.isNotEmpty) {
                                        final uDoc = urunQuery.docs.first;
                                        final double currentStock = (uDoc['stok'] as num).toDouble();
                                        await uDoc.reference.update({'stok': (currentStock - miktar).clamp(0.0, double.infinity)});
                                      }

                                      // Also record a deduction (Kesinti) from producer's milk payment!
                                      await FirebaseFirestore.instance.collection('kesintiler').add({
                                        'uretici': uretici,
                                        'tutar': toplam,
                                        'kesintiTuru': '$urun Alımı',
                                        'durum': 'aktif',
                                        'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                                        'timestamp': FieldValue.serverTimestamp(),
                                        'firma': currentFirmaName,
                                      });
                                    }),
                                  if (durum != 'Teslim Edildi' && durum != 'İptal')
                                    _buildOrderActionButton('İptal', Colors.orange, () async {
                                      await doc.reference.update({'durum': 'İptal'});
                                    }),
                                  _buildOrderActionButton('Sil', Colors.red, () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Siparişi Sil'),
                                        content: const Text('Bu sipariş kaydını tamamen silmek istiyor musunuz?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                            onPressed: () => Navigator.pop(ctx, true),
                                            child: const Text('Sil'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await doc.reference.delete();
                                    }
                                  }),
                                ],
                              ),
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
    );
  }

  Widget _buildOrderStatItem(String val, String label) {
    return Column(
      children: [
        Text(val, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.gray800)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
      ],
    );
  }

  Widget _buildOrderActionButton(String label, Color color, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(60, 30),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ==========================================
  // 6. SALES REPORTS (SATIS RAPORLARI)
  // ==========================================
  Widget _buildSalesReportsView(String currentFirmaName) {
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');
    final startDisplay = DateFormat('dd.MM.yyyy').format(_startDate);
    final endDisplay = DateFormat('dd.MM.yyyy').format(_endDate);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Satış Raporları', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: _buildBackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('urunler_siparisler')
            .where('firma', isEqualTo: currentFirmaName)
            .where('durum', isEqualTo: 'Teslim Edildi')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // Process Sales Stats
          double totalCiro = 0.0;
          double totalProductsSold = 0.0;
          final Map<String, Map<String, dynamic>> productStats = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final date = _getDocDate(data['timestamp']);
            
            // Check Date filter
            if (date != null && date.isAfter(_startDate.subtract(const Duration(seconds: 1))) && date.isBefore(_endDate.add(const Duration(days: 1)))) {
              final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
              final double toplamVal = (data['toplam'] as num?)?.toDouble() ?? 0.0;
              final String urun = data['urun'] ?? 'Ürün';
              final String birim = data['birim'] ?? 'Adet';
              final double unitPrice = (data['birimFiyat'] as num?)?.toDouble() ?? 0.0;

              totalCiro += toplamVal;
              totalProductsSold += miktar;

              if (!productStats.containsKey(urun)) {
                productStats[urun] = {
                  'miktar': 0.0,
                  'toplam': 0.0,
                  'birim': birim,
                  'birimFiyat': unitPrice,
                };
              }
              productStats[urun]!['miktar'] = (productStats[urun]!['miktar'] as double) + miktar;
              productStats[urun]!['toplam'] = (productStats[urun]!['toplam'] as double) + toplamVal;
            }
          }

          // Sort product stats by sales revenue
          final sortedProducts = productStats.entries.toList()
            ..sort((a, b) => (b.value['toplam'] as double).compareTo(a.value['toplam'] as double));

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date picker row matching mockup
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.gray200),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDate = picked.start;
                                _endDate = picked.end;
                              });
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Başlangıç', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                                  const SizedBox(height: 2),
                                  Text(startDisplay, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                ],
                              ),
                              const Icon(Icons.arrow_forward_rounded, color: AppColors.gray300, size: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Bitiş', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                                  const SizedBox(height: 2),
                                  Text(endDisplay, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Top stats card matching mockup Satış Raporları
                Row(
                  children: [
                    Expanded(
                      child: _buildReportCiroCard('Toplam Ciro', '${formatNumber.format(totalCiro)} ₺', const Color(0xFF4CAF50)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildReportCiroCard('Satılan Ürün', totalProductsSold.toStringAsFixed(0), const Color(0xFF2196F3)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildReportCiroCard('Toplam Kar', '${formatNumber.format(totalCiro)} ₺', const Color(0xFF9C27B0)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Product Rankings Section
                Text(
                  'Ürün Sıralaması',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray900),
                ),
                const SizedBox(height: 14),

                if (sortedProducts.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text('Belirtilen tarihler arasında satış kaydı bulunmuyor.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400)),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: sortedProducts.length,
                    itemBuilder: (context, idx) {
                      final item = sortedProducts[idx];
                      final name = item.key;
                      final miktar = item.value['miktar'] as double;
                      final birim = item.value['birim'] as String;
                      final double toplam = item.value['toplam'] as double;
                      final double unitPrice = item.value['birimFiyat'] as double;
                      final double percent = totalCiro > 0 ? (toplam / totalCiro) * 100 : 0.0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
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
                                color: idx == 0
                                    ? Colors.orange.withOpacity(0.15)
                                    : AppColors.gray100,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  (idx + 1).toString(),
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: idx == 0 ? Colors.orange : AppColors.gray600,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                  Text(
                                    'Birim: ${unitPrice.toStringAsFixed(2)} ₺ • Pay: %${percent.toStringAsFixed(1)}',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${miktar.toStringAsFixed(0)} $birim', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                                const SizedBox(height: 2),
                                Text(
                                  '${toplam.toStringAsFixed(2)} ₺',
                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportCiroCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(Icons.analytics, size: 12, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.gray800),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 7. PRODUCER STORE VIEW (VIEW & ORDER)
  // ==========================================
  Widget _buildProducerStoreView(String currentFirmaName, String producerName) {
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ureticiler')
          .where('name', isEqualTo: producerName)
          .snapshots(),
      builder: (context, producerSnapshot) {
        if (producerSnapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text('Hata oluştu: ${producerSnapshot.error}', style: GoogleFonts.inter(color: Colors.red)),
              ),
            ),
          );
        }
        if (producerSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        List<String> connectedFirmalar = ['Kayseri Çiftlik']; // Fallback default
        if (producerSnapshot.hasData && producerSnapshot.data!.docs.isNotEmpty) {
          final pDoc = producerSnapshot.data!.docs.first;
          final pData = pDoc.data() as Map<String, dynamic>;
          final dynamic fList = pData['firmalar'];
          if (fList is List) {
            connectedFirmalar = List<String>.from(fList.map((e) => e.toString()));
          }
        }

        // If connectedFirmalar is empty, fallback to default
        if (connectedFirmalar.isEmpty) {
          connectedFirmalar = ['Kayseri Çiftlik'];
        }

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text('Ürünler', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
            actions: [
              IconButton(
                icon: const Icon(Icons.history_rounded),
                onPressed: () {
                  // Show orders placed by this producer
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => _ProducerOrdersHistoryPage(
                        producerName: producerName,
                        firmaName: connectedFirmalar.first,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('urunler')
                .where('firma', whereIn: connectedFirmalar)
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
              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Text('Firmaya ait satışta ürün bulunmamaktadır.', style: GoogleFonts.inter(color: AppColors.gray400)),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, idx) {
                  final doc = docs[idx];
                  final data = doc.data() as Map<String, dynamic>;
                  final ad = data['ad'] ?? '';
                  final kat = data['kategori'] ?? 'Diğer';
                  final birim = data['birim'] ?? 'Adet';
                  final fiyat = (data['fiyat'] as num?)?.toDouble() ?? 0.0;
                  final stok = (data['stok'] as num?)?.toDouble() ?? 0.0;
                  final productFirma = data['firma'] ?? connectedFirmalar.first;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray200),
                      boxShadow: AppShadows.sm,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.primary50,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_bag_outlined, color: AppColors.primary600, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(ad, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                              Text('$kat • Stok: ${stok.toStringAsFixed(0)} $birim', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${formatNumber.format(fiyat)} ₺', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary600)),
                            const SizedBox(height: 6),
                            ElevatedButton(
                              onPressed: stok <= 0
                                  ? null
                                  : () {
                                      final miktarCtrl = TextEditingController(text: '1');
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Ürün Sipariş Et'),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text('$ad sipariş etmek istediğiniz miktarı girin:'),
                                              const SizedBox(height: 12),
                                              TextField(
                                                controller: miktarCtrl,
                                                keyboardType: TextInputType.number,
                                                decoration: InputDecoration(
                                                  labelText: 'Miktar ($birim)',
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                                            ElevatedButton(
                                              onPressed: () async {
                                                final double? miktarVal = double.tryParse(miktarCtrl.text);
                                                if (miktarVal == null || miktarVal <= 0 || miktarVal > stok) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Lütfen geçerli/stokta olan bir miktar girin!'), backgroundColor: AppColors.danger),
                                                  );
                                                  return;
                                                }

                                                final totalCost = miktarVal * fiyat;

                                                // Place order in urunler_siparisler
                                                await FirebaseFirestore.instance.collection('urunler_siparisler').add({
                                                  'id': _generateOrderId(),
                                                  'uretici': producerName,
                                                  'firma': productFirma,
                                                  'urun': ad,
                                                  'miktar': miktarVal,
                                                  'birim': birim,
                                                  'birimFiyat': fiyat,
                                                  'toplam': totalCost,
                                                  'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                                                  'saat': DateFormat('HH:mm').format(DateTime.now()),
                                                  'durum': 'Bekliyor',
                                                  'timestamp': FieldValue.serverTimestamp(),
                                                });

                                                Navigator.pop(ctx);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Siparişiniz başarıyla firmaya iletildi!'), backgroundColor: AppColors.success),
                                                );
                                              },
                                              child: const Text('Sipariş Ver'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: stok <= 0 ? Colors.grey : AppColors.primary600,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: const Size(60, 28),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: Text(stok <= 0 ? 'Tükendi' : 'Sipariş Et', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
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
      },
    );
  }

  DateTime? _getDocDate(dynamic field) {
    if (field == null) return null;
    if (field is Timestamp) return field.toDate();
    if (field is DateTime) return field;
    if (field is String) return DateTime.tryParse(field);
    return null;
  }
}

// --- PRODUCER ORDERS HISTORY PAGE ---
class _ProducerOrdersHistoryPage extends StatelessWidget {
  final String producerName;
  final String firmaName;
  const _ProducerOrdersHistoryPage({required this.producerName, required this.firmaName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Siparişlerim'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('urunler_siparisler')
            .where('uretici', isEqualTo: producerName)
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
          final docs = (snapshot.data?.docs ?? []).toList();
          // Sort locally by timestamp descending
          docs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          if (docs.isEmpty) {
            return Center(
              child: Text('Kayıtlı siparişiniz bulunmuyor.', style: GoogleFonts.inter(color: AppColors.gray400)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, idx) {
              final data = docs[idx].data() as Map<String, dynamic>;
              final urun = data['urun'] ?? '';
              final miktar = (data['miktar'] as num?)?.toDouble() ?? 1.0;
              final birim = data['birim'] ?? 'Adet';
              final toplam = (data['toplam'] as num?)?.toDouble() ?? 0.0;
              final durum = data['durum'] ?? 'Bekliyor';
              final tarih = data['tarih'] ?? '';
              final orderId = data['id'] ?? '';

              Color statusColor = Colors.orange;
              if (durum == 'Onaylandı') statusColor = Colors.blue;
              if (durum == 'Teslimatta') statusColor = Colors.purple;
              if (durum == 'Teslim Edildi') statusColor = Colors.green;
              if (durum == 'İptal') statusColor = Colors.red;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.gray200),
                  boxShadow: AppShadows.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Sipariş $orderId', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gray800)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Text(durum, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Tarih: $tarih', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(urun, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800)),
                        Text('${miktar.toStringAsFixed(0)} $birim', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Toplam Tutar:', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                        Text('${toplam.toStringAsFixed(2)} ₺', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary600)),
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
