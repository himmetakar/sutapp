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
import '../../services/firestore_service.dart';

class UrunlerScreen extends StatefulWidget {
  const UrunlerScreen({super.key});

  @override
  State<UrunlerScreen> createState() => _UrunlerScreenState();
}

class _UrunlerScreenState extends State<UrunlerScreen> {
  String _currentView = 'hub'; // hub, kategoriler, stok, siparisler, satis_raporlari, urunler_list
  bool _isLoading = false;
  
  // Producer Cart & Store State
  final Map<String, Map<String, dynamic>> _cart = {}; // key: docId, value: cart item map
  String _selectedStoreCategory = 'Tümü';
  String _storeSearchQuery = '';
  final _storeSearchCtrl = TextEditingController();
  
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

  // Order Search & Filter State
  String _orderSearchQuery = '';
  String _orderFilter = 'Tümü';
  final _orderSearchCtrl = TextEditingController();

  // Sales Report Tab State
  String _salesReportTab = 'En Çok Satan';

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
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
      appBar: AppBar(
        title: Text('Ürün Yönetimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma'),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gray900,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Column(
          children: [
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

            // Grid of 6 Actions
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
                      label: 'Ürünler',
                      icon: Icons.inventory_rounded,
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
                      label: 'Ürün Satışları',
                      icon: Icons.list_alt_rounded,
                      iconColor: const Color(0xFF22C55E),
                      bgColor: const Color(0xFFE8F5E9),
                      onTap: () => context.push('/firma/satislar'),
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
  void _showAddProductDialog(String currentFirmaName, {String? docId, Map<String, dynamic>? existingData}) async {
    // Fetch categories dynamically
    final categoriesQuery = await FirebaseFirestore.instance
        .collection('urunler_kategoriler')
        .where('firma', isEqualTo: currentFirmaName)
        .get();
    final List<String> categories = categoriesQuery.docs
        .map((doc) => doc.data()['ad'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toSet()
        .toList();
    
    if (categories.isEmpty) {
      categories.addAll(['Yem', 'Vitamin', 'İlaç', 'Araç Gereç']);
    }
    if (existingData != null) {
      final existingKat = existingData['kategori'] as String?;
      if (existingKat != null && !categories.contains(existingKat)) {
        categories.add(existingKat);
      }
    }

    final adCtrl = TextEditingController(text: existingData?['ad'] ?? '');
    final birimCtrl = TextEditingController(text: existingData?['birim'] ?? '');
    final fiyatCtrl = TextEditingController(text: existingData != null ? (existingData['fiyat'] as num).toStringAsFixed(2) : '');
    final minStokCtrl = TextEditingController(text: existingData != null ? (existingData['minStok'] as num?)?.toStringAsFixed(0) ?? '10' : '10');
    String selectedKategori = existingData?['kategori'] ?? (categories.contains('Yem') ? 'Yem' : categories.first);
    final customKatCtrl = TextEditingController();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
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
                  items: [
                    ...categories.map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    const DropdownMenuItem(value: 'Diğer', child: Text('Diğer (Yeni yazın)')),
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
                  decoration: const InputDecoration(labelText: 'Satış Fiyatı (₺) *', hintText: 'Örn: 625.00'),
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
                final double? minStok = double.tryParse(minStokCtrl.text.replaceAll(',', '.'));

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

                final Map<String, dynamic> dataMap = {
                  'ad': ad,
                  'kategori': kat,
                  'birim': birim,
                  'fiyat': fiyat,
                  'minStok': minStok,
                  'firma': currentFirmaName,
                  'timestamp': FieldValue.serverTimestamp(),
                };

                if (docId == null) {
                  dataMap['stok'] = 0.0;
                }

                try {
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

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(docId == null ? 'Ürün başarıyla eklendi!' : 'Ürün güncellendi!'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  print('Product save error: $e');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Ürün kaydedilemedi: $e'), backgroundColor: AppColors.danger),
                    );
                  }
                }
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
                            onPressed: () => _showStockHistoryDialog(context, ad, currentFirmaName),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary50,
                              foregroundColor: AppColors.primary600,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Stok Geçmişi'),
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

  Widget _buildProgressTracker(String status) {
    if (status == 'İptal') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.shade100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cancel_rounded, color: Colors.red, size: 16),
            const SizedBox(width: 6),
            Text(
              'Sipariş İptal Edildi',
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade700),
            ),
          ],
        ),
      );
    }

    final steps = ['Alındı', 'Hazırlandı', 'Yolda', 'Teslim Edildi'];
    int currentStep = 0;
    if (status == 'Bekliyor') currentStep = 0;
    if (status == 'Onaylandı') currentStep = 1;
    if (status == 'Teslimatta') currentStep = 2;
    if (status == 'Teslim Edildi') currentStep = 3;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(steps.length, (index) {
        final stepName = steps[index];
        final isCompleted = index <= currentStep;
        final isActive = index == currentStep;

        Color circleColor = AppColors.gray200;
        Color textColor = AppColors.gray400;
        IconData icon = Icons.circle_outlined;

        if (isCompleted) {
          circleColor = AppColors.primary600;
          textColor = AppColors.gray800;
          icon = Icons.check_circle_rounded;
        }
        if (isActive) {
          circleColor = Colors.orange;
          textColor = Colors.orange.shade800;
          icon = Icons.radio_button_checked_rounded;
        }
        if (index == 3 && isCompleted) {
          circleColor = Colors.green;
          textColor = Colors.green.shade800;
          icon = Icons.check_circle_rounded;
        }

        return Expanded(
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == 0 ? Colors.transparent : (index <= currentStep ? AppColors.primary500 : AppColors.gray200),
                    ),
                  ),
                  Icon(icon, color: circleColor, size: 18),
                  Expanded(
                    child: Container(
                      height: 3,
                      color: index == steps.length - 1 ? Colors.transparent : (index < currentStep ? AppColors.primary500 : AppColors.gray200),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                stepName,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                  color: textColor,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _showStockHistoryDialog(BuildContext context, String productAd, String currentFirmaName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(20),
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadStockHistory(productAd, currentFirmaName),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snapshot.hasError) {
                  return SizedBox(
                    height: 250,
                    child: Center(child: Text('Hata: ${snapshot.error}')),
                  );
                }

                final history = snapshot.data ?? [];
                double totalIn = 0.0;
                double totalOut = 0.0;
                for (var item in history) {
                  final double qty = item['miktar'] as double;
                  if (item['tip'] == 'giris') {
                    totalIn += qty;
                  } else {
                    totalOut += qty;
                  }
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '$productAd Stok Geçmişi',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gray800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Toplam Giriş', style: GoogleFonts.inter(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${totalIn.toStringAsFixed(0)} Adet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green[800])),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Toplam Çıkış', style: GoogleFonts.inter(fontSize: 10, color: Colors.red[700], fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${totalOut.toStringAsFixed(0)} Adet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.red[800])),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Hareket Detayları',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray600),
                    ),
                    const SizedBox(height: 8),
                    if (history.isEmpty)
                      const SizedBox(
                        height: 200,
                        child: Center(
                          child: Text('Bu ürüne ait henüz stok hareketi bulunmuyor.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ),
                      )
                    else
                      Container(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: history.length,
                          itemBuilder: (context, index) {
                            final item = history[index];
                            final isGiris = item['tip'] == 'giris';
                            final date = item['tarih'] as String;
                            final partner = item['partner'] as String;
                            final desc = item['aciklama'] as String;
                            final double miktar = item['miktar'] as double;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.gray50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.gray200),
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: isGiris ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                                    child: Icon(
                                      isGiris ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                      color: isGiris ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          desc,
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          isGiris ? 'Tedarikçi: $partner' : 'Üretici: $partner',
                                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${isGiris ? "+" : "-"}${miktar.toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: isGiris ? Colors.green : Colors.red,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        date,
                                        style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400),
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
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadStockHistory(String productAd, String currentFirmaName) async {
    final List<Map<String, dynamic>> results = [];

    // 1. Fetch Alış Faturaları
    final faturalarSnap = await FirebaseFirestore.instance.collection('faturalar')
        .where('firma', isEqualTo: currentFirmaName)
        .where('tip', isEqualTo: 'alis')
        .get();

    for (var doc in faturalarSnap.docs) {
      final data = doc.data();
      final status = data['durum'] ?? 'aktif';
      if (status == 'iptal') continue;

      final faturaNo = data['faturaNo'] ?? '';
      final tedarikci = data['tedarikci'] ?? '';
      final tarih = data['tarih'] ?? '';
      final Timestamp? ts = data['timestamp'] as Timestamp?;
      final dateVal = ts?.toDate() ?? DateTime.now();

      final kalemler = data['kalemler'] as List? ?? [];
      for (var item in kalemler) {
        if (item is Map) {
          final urun = item['urun'] as String? ?? '';
          if (urun.toLowerCase().trim() == productAd.toLowerCase().trim()) {
            final double miktar = (item['miktar'] as num?)?.toDouble() ?? 0.0;
            results.add({
              'tip': 'giris',
              'partner': tedarikci,
              'miktar': miktar,
              'tarih': tarih,
              'aciklama': 'Alış Faturası ($faturaNo)',
              'timestamp': dateVal,
            });
          }
        }
      }
    }

    // 2. Fetch Direct Sales (satislar)
    final satislarSnap = await FirebaseFirestore.instance.collection('satislar')
        .where('firma', isEqualTo: currentFirmaName)
        .where('urun', isEqualTo: productAd)
        .get();

    for (var doc in satislarSnap.docs) {
      final data = doc.data();
      final uretici = data['uretici'] ?? '';
      final miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
      final tarih = data['tarih'] ?? '';
      final Timestamp? ts = data['timestamp'] as Timestamp?;
      final dateVal = ts?.toDate() ?? DateTime.now();

      results.add({
        'tip': 'cikis',
        'partner': uretici,
        'miktar': miktar,
        'tarih': tarih,
        'aciklama': 'Direkt Satış',
        'timestamp': dateVal,
      });
    }

    // 3. Fetch Delivered Producer Orders (urunler_siparisler)
    final siparislerSnap = await FirebaseFirestore.instance.collection('urunler_siparisler')
        .where('firma', isEqualTo: currentFirmaName)
        .where('durum', isEqualTo: 'Teslim Edildi')
        .get();

    for (var doc in siparislerSnap.docs) {
      final data = doc.data();
      final uretici = data['uretici'] ?? '';
      final tarih = data['tarih'] ?? '';
      final Timestamp? ts = data['timestamp'] as Timestamp?;
      final dateVal = ts?.toDate() ?? DateTime.now();

      if (data.containsKey('kalemler') && data['kalemler'] is List) {
        final List<dynamic> items = data['kalemler'];
        for (var item in items) {
          if (item is Map) {
            final urun = item['urun'] as String? ?? '';
            if (urun.toLowerCase().trim() == productAd.toLowerCase().trim()) {
              final double miktar = (item['miktar'] as num?)?.toDouble() ?? 0.0;
              results.add({
                'tip': 'cikis',
                'partner': uretici,
                'miktar': miktar,
                'tarih': tarih,
                'aciklama': 'Sipariş Teslimatı',
                'timestamp': dateVal,
              });
            }
          }
        }
      } else {
        final String urun = data['urun'] as String? ?? '';
        if (urun.toLowerCase().trim() == productAd.toLowerCase().trim()) {
          final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
          results.add({
            'tip': 'cikis',
            'partner': uretici,
            'miktar': miktar,
            'tarih': tarih,
            'aciklama': 'Sipariş Teslimatı',
            'timestamp': dateVal,
          });
        }
      }
    }

    // Sort results by timestamp descending
    results.sort((a, b) {
      final DateTime tA = a['timestamp'] as DateTime;
      final DateTime tB = b['timestamp'] as DateTime;
      return tB.compareTo(tA);
    });

    return results;
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
                    String statusText = durum;
                    if (durum == 'Bekliyor') {
                      statusColor = Colors.orange;
                      statusText = 'Alındı';
                    }
                    if (durum == 'Onaylandı') {
                      statusColor = Colors.blue;
                      statusText = 'Hazırlandı';
                    }
                    if (durum == 'Teslimatta') {
                      statusColor = Colors.purple;
                      statusText = 'Yolda';
                    }
                    if (durum == 'Teslim Edildi') {
                      statusColor = Colors.green;
                      statusText = 'Teslim Edildi';
                    }
                    if (durum == 'İptal') {
                      statusColor = Colors.red;
                      statusText = 'İptal';
                    }

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
                                    statusText,
                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text('Sipariş $orderId • $tarih $saat', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                            const SizedBox(height: 10),
                            _buildProgressTracker(durum),
                            const Divider(height: 20),
                            // Render products list
                            ...(() {
                              final List<Map<String, dynamic>> itemsList = data.containsKey('kalemler') && data['kalemler'] is List
                                  ? List<Map<String, dynamic>>.from((data['kalemler'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
                                  : [
                                      {
                                        'urun': urun,
                                        'miktar': miktar,
                                        'birim': birim,
                                        'birimFiyat': birimFiyat,
                                        'toplam': toplam,
                                      }
                                    ];
                              return itemsList.map((item) {
                                final String uName = item['urun'] ?? '';
                                final double qty = (item['miktar'] as num?)?.toDouble() ?? 1.0;
                                final String unit = item['birim'] ?? 'Adet';
                                final double price = (item['birimFiyat'] as num?)?.toDouble() ?? 0.0;
                                final double totalItem = (item['toplam'] as num?)?.toDouble() ?? 0.0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 6.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          uName,
                                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
                                        ),
                                      ),
                                      Text(
                                        '${qty.toStringAsFixed(0)} $unit x ${price.toStringAsFixed(2)} ₺',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        '${totalItem.toStringAsFixed(2)} ₺',
                                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray700),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList();
                            })(),
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
                                    _buildOrderActionButton('Hazırlandı Yap', Colors.green, () async {
                                      await doc.reference.update({'durum': 'Onaylandı'});
                                      await FirestoreService().sendNotification(
                                        recipientName: uretici,
                                        role: 'uretici',
                                        baslik: 'Siparişiniz Hazırlandı',
                                        icerik: '$orderId nolu siparişiniz firma tarafından hazırlandı.',
                                        type: 'siparis',
                                      );
                                      await _notifyDriversForProducer(
                                        currentFirmaName,
                                        uretici,
                                        orderId,
                                      );
                                    }),
                                  if (durum == 'Onaylandı')
                                    _buildOrderActionButton('Yolda Yap', Colors.purple, () async {
                                      await doc.reference.update({'durum': 'Teslimatta'});
                                      await FirestoreService().sendNotification(
                                        recipientName: uretici,
                                        role: 'uretici',
                                        baslik: 'Siparişiniz Yola Çıktı',
                                        icerik: '$orderId nolu siparişiniz dağıtıma çıkmıştır.',
                                        type: 'siparis',
                                      );
                                      await _notifyDriversForProducer(
                                        currentFirmaName,
                                        uretici,
                                        orderId,
                                        customBaslik: 'Sipariş Yola Çıktı',
                                        customIcerik: '$uretici üreticisine ait $orderId nolu sipariş yola çıktı.',
                                      );
                                    }),
                                  if (durum == 'Teslimatta')
                                    _buildOrderActionButton('Teslim Edildi Yap', Colors.green, () async {
                                      await doc.reference.update({'durum': 'Teslim Edildi'});
                                      
                                      await FirestoreService().sendNotification(
                                        recipientName: uretici,
                                        role: 'uretici',
                                        baslik: 'Siparişiniz Teslim Edildi',
                                        icerik: '$orderId nolu siparişiniz başarıyla teslim edilmiştir.',
                                        type: 'siparis',
                                      );

                                      await _notifyDriversForProducer(
                                        currentFirmaName,
                                        uretici,
                                        orderId,
                                        customBaslik: 'Sipariş Teslim Edildi',
                                        customIcerik: '$uretici üreticisine ait $orderId nolu sipariş teslim edildi.',
                                      );
                                      
                                      final List<Map<String, dynamic>> itemsList = data.containsKey('kalemler') && data['kalemler'] is List
                                          ? List<Map<String, dynamic>>.from((data['kalemler'] as List).map((e) => Map<String, dynamic>.from(e as Map)))
                                          : [
                                              {
                                                'urun': urun,
                                                'miktar': miktar,
                                                'birim': birim,
                                                'birimFiyat': birimFiyat,
                                                'toplam': toplam,
                                              }
                                            ];

                                      for (var item in itemsList) {
                                        final String uName = item['urun'] ?? '';
                                        final double qty = (item['miktar'] as num?)?.toDouble() ?? 1.0;
                                        final double totalItem = (item['toplam'] as num?)?.toDouble() ?? 0.0;

                                        // Subtract stock
                                        final urunQuery = await FirebaseFirestore.instance
                                            .collection('urunler')
                                            .where('ad', isEqualTo: uName)
                                            .where('firma', isEqualTo: currentFirmaName)
                                            .limit(1)
                                            .get();
                                        if (urunQuery.docs.isNotEmpty) {
                                          final uDoc = urunQuery.docs.first;
                                          final double currentStock = (uDoc['stok'] as num?)?.toDouble() ?? 0.0;
                                          final double minStok = (uDoc.data() as Map<String, dynamic>)['minStok']?.toDouble() ?? 10.0;
                                          final String birimVal = (uDoc.data() as Map<String, dynamic>)['birim'] ?? 'Adet';
                                          final double newStock = (currentStock - qty).clamp(0.0, double.infinity);
                                          await uDoc.reference.update({'stok': newStock});
                                          
                                          if (newStock <= minStok) {
                                            await FirestoreService().sendNotification(
                                              recipientName: currentFirmaName,
                                              role: 'firma',
                                              baslik: 'Kritik Stok Uyarısı',
                                              icerik: '$uName ürünü kritik stok limitinin altına düştü! Güncel Stok: ${newStock.toStringAsFixed(0)} $birimVal',
                                              type: 'stok',
                                            );
                                          }
                                        }

                                        // Record payment deduction (Kesinti)
                                        await FirebaseFirestore.instance.collection('kesintiler').add({
                                          'uretici': uretici,
                                          'tutar': totalItem,
                                          'kesintiTuru': '$uName Alımı',
                                          'durum': 'aktif',
                                          'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                                          'timestamp': FieldValue.serverTimestamp(),
                                          'firma': currentFirmaName,
                                        });
                                      }
                                    }),
                                  if (durum != 'Teslim Edildi' && durum != 'İptal')
                                    _buildOrderActionButton('İptal', Colors.orange, () async {
                                      await doc.reference.update({'durum': 'İptal'});
                                      await FirestoreService().sendNotification(
                                        recipientName: uretici,
                                        role: 'uretici',
                                        baslik: 'Siparişiniz İptal Edildi',
                                        icerik: '$orderId nolu siparişiniz firma tarafından iptal edilmiştir.',
                                        type: 'siparis',
                                      );
                                      await _notifyDriversForProducer(
                                        currentFirmaName,
                                        uretici,
                                        orderId,
                                        customBaslik: 'Sipariş İptal Edildi',
                                        customIcerik: '$uretici üreticisine ait $orderId nolu sipariş iptal edildi.',
                                      );
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

  Future<void> _notifyDriversForProducer(String firma, String ureticiName, String orderId, {String? customBaslik, String? customIcerik}) async {
    try {
      final prodSnap = await FirebaseFirestore.instance
          .collection('ureticiler')
          .where('name', isEqualTo: ureticiName)
          .limit(1)
          .get();
      
      if (prodSnap.docs.isEmpty) return;
      final pData = prodSnap.docs.first.data();
      final String group = pData['group'] ?? '';
      final String bolge = pData['bolge'] ?? '';
      final String birlik = pData['birlik'] ?? 'Yok';

      final atamalarSnap = await FirebaseFirestore.instance
          .collection('toplayici_atamalari')
          .where('firma', isEqualTo: firma)
          .get();

      final Set<String> driversToNotify = {};
      for (var doc in atamalarSnap.docs) {
        final data = doc.data();
        final hTip = data['hedefTip'];
        final hAd = data['hedefAd'];
        final driver = data['toplayici'] as String? ?? '';

        if (driver.isEmpty) continue;

        if (hTip == 'uretici' && hAd == ureticiName) {
          driversToNotify.add(driver);
        } else if (hTip == 'grup' && group.isNotEmpty && hAd == group) {
          driversToNotify.add(driver);
        } else if ((hTip == 'birlik' || hTip == 'bolge') &&
            ((bolge.isNotEmpty && hAd == bolge) || (birlik.isNotEmpty && birlik != 'Yok' && hAd == birlik))) {
          driversToNotify.add(driver);
        }
      }

      for (var driverName in driversToNotify) {
        await FirestoreService().sendNotification(
          recipientName: driverName,
          role: 'surucu',
          baslik: customBaslik ?? 'Yeni Dağıtım Görevi',
          icerik: customIcerik ?? '$ureticiName üreticisine ait $orderId nolu sipariş hazırlandı, teslim alabilirsiniz.',
          type: 'siparis',
        );
      }
    } catch (e) {
      print('Error notifying drivers: $e');
    }
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
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gray900,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('urunler_siparisler')
            .where('firma', isEqualTo: currentFirmaName)
            .where('durum', isEqualTo: 'Teslim Edildi')
            .snapshots(),
        builder: (context, ordersSnap) {
          if (ordersSnap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('urunler')
                .where('firma', isEqualTo: currentFirmaName)
                .snapshots(),
            builder: (context, productsSnap) {
              if (productsSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('satislar')
                    .where('firma', isEqualTo: currentFirmaName)
                    .snapshots(),
                builder: (context, salesSnap) {
                  if (salesSnap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final orderDocs = ordersSnap.data?.docs ?? [];
                  final productDocs = productsSnap.data?.docs ?? [];
                  final saleDocs = salesSnap.data?.docs ?? [];

                  // Map of product ad to sonGelisFiyati
                  final Map<String, double> costMap = {};
                  for (var doc in productDocs) {
                    final pData = doc.data() as Map<String, dynamic>;
                    final String ad = pData['ad'] ?? '';
                    final double cost = (pData['sonGelisFiyati'] as num?)?.toDouble() ?? 0.0;
                    costMap[ad.toLowerCase().trim()] = cost;
                  }

                  // Process Sales Stats
                  double totalCiro = 0.0;
                  double totalProductsSold = 0.0;
                  double totalCostSum = 0.0;
                  final Map<String, Map<String, dynamic>> productStats = {};

                  void processItem(String urun, double miktar, double toplamVal, String birim, double unitPrice, DateTime? date) {
                    if (date != null && date.isAfter(_startDate.subtract(const Duration(seconds: 1))) && date.isBefore(_endDate.add(const Duration(days: 1)))) {
                      final double costPrice = costMap[urun.toLowerCase().trim()] ?? 0.0;
                      final double itemCost = miktar * costPrice;
                      final double itemKar = toplamVal - itemCost;

                      totalCiro += toplamVal;
                      totalProductsSold += miktar;
                      totalCostSum += itemCost;

                      if (!productStats.containsKey(urun)) {
                        productStats[urun] = {
                          'miktar': 0.0,
                          'toplam': 0.0,
                          'kar': 0.0,
                          'birim': birim,
                          'birimFiyat': unitPrice,
                        };
                      }
                      productStats[urun]!['miktar'] = (productStats[urun]!['miktar'] as double) + miktar;
                      productStats[urun]!['toplam'] = (productStats[urun]!['toplam'] as double) + toplamVal;
                      productStats[urun]!['kar'] = (productStats[urun]!['kar'] as double) + itemKar;
                    }
                  }

                  // Process orders
                  for (var doc in orderDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final date = _getDocDate(data['timestamp']);
                    
                    if (data.containsKey('kalemler') && data['kalemler'] is List) {
                      final List<dynamic> items = data['kalemler'];
                      for (var item in items) {
                        if (item is Map) {
                          final double miktar = (item['miktar'] as num?)?.toDouble() ?? 0.0;
                          final double toplamVal = (item['toplam'] as num?)?.toDouble() ?? 0.0;
                          final String urun = item['urun'] ?? 'Ürün';
                          final String birim = item['birim'] ?? 'Adet';
                          final double unitPrice = (item['birimFiyat'] as num?)?.toDouble() ?? 0.0;
                          processItem(urun, miktar, toplamVal, birim, unitPrice, date);
                        }
                      }
                    } else {
                      // Fallback for single-item legacy orders
                      final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
                      final double toplamVal = (data['toplam'] as num?)?.toDouble() ?? 0.0;
                      final String urun = data['urun'] ?? 'Ürün';
                      final String birim = data['birim'] ?? 'Adet';
                      final double unitPrice = (data['birimFiyat'] as num?)?.toDouble() ?? 0.0;
                      processItem(urun, miktar, toplamVal, birim, unitPrice, date);
                    }
                  }

                  // Process direct sales
                  for (var doc in saleDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final date = _getDocDate(data['timestamp']);
                    final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
                    final double toplamVal = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                    final String urun = data['urun'] ?? 'Ürün';
                    const String birim = 'Adet';
                    final double unitPrice = miktar > 0 ? (toplamVal / miktar) : 0.0;
                    processItem(urun, miktar, toplamVal, birim, unitPrice, date);
                  }

                  final double totalKar = totalCiro - totalCostSum;

                  // Sort product stats based on _salesReportTab
                  final sortedProducts = productStats.entries.toList();
                  if (_salesReportTab == 'En Çok Satan') {
                    sortedProducts.sort((a, b) => (b.value['miktar'] as double).compareTo(a.value['miktar'] as double));
                  } else if (_salesReportTab == 'En Yüksek Ciro' || _salesReportTab == 'En Çok Ciro Yapan') {
                    sortedProducts.sort((a, b) => (b.value['toplam'] as double).compareTo(a.value['toplam'] as double));
                  } else if (_salesReportTab == 'En Çok Kar' || _salesReportTab == 'En Çok Kar Yapan') {
                    sortedProducts.sort((a, b) => (b.value['kar'] as double).compareTo(a.value['kar'] as double));
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date picker row
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

                        // Top stats cards
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
                              child: _buildReportCiroCard('Toplam Kar', '${formatNumber.format(totalKar)} ₺', const Color(0xFF9C27B0)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Product Rankings Header and Tabs
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Ürün Sıralaması',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray900),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            _buildReportSegmentButton('En Çok Satan', 'En Çok Satan'),
                            _buildReportSegmentButton('En Yüksek Ciro', 'En Çok Ciro yapan'),
                            _buildReportSegmentButton('En Çok Kar', 'En Çok Kar yapan'),
                          ],
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
                              final double kar = item.value['kar'] as double;
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
                                        Text('${miktar.toStringAsFixed(0)} $birim', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.w600)),
                                        const SizedBox(height: 2),
                                        Text(
                                          _salesReportTab == 'En Çok Kar'
                                              ? 'Kar: ${kar.toStringAsFixed(2)} ₺'
                                              : '${toplam.toStringAsFixed(2)} ₺',
                                          style: GoogleFonts.inter(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: _salesReportTab == 'En Çok Kar' ? Colors.purple : AppColors.success,
                                          ),
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
              );
            },
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

  Widget _buildReportSegmentButton(String tabName, String label) {
    final bool isActive = _salesReportTab == tabName;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: () {
            setState(() {
              _salesReportTab = tabName;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isActive ? AppColors.primary600 : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isActive ? AppColors.primary600 : AppColors.gray200),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.white : AppColors.gray600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryBox(String name, IconData icon, Color color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.gray200,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 3))]
              : [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 1))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : AppColors.gray500, size: 22),
            const SizedBox(height: 6),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? AppColors.gray800 : AppColors.gray600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
        bool siparisIzni = true;
        if (producerSnapshot.hasData && producerSnapshot.data!.docs.isNotEmpty) {
          final pDoc = producerSnapshot.data!.docs.first;
          final pData = pDoc.data() as Map<String, dynamic>;
          final dynamic fList = pData['firmalar'];
          if (fList is List) {
            connectedFirmalar = List<String>.from(fList.map((e) => e.toString()));
          }
          siparisIzni = pData['siparisIzni'] ?? true;
        }

        // If connectedFirmalar is empty, fallback to default
        if (connectedFirmalar.isEmpty) {
          connectedFirmalar = ['Kayseri Çiftlik'];
        }

        return Scaffold(
          backgroundColor: AppColors.gray50,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'Sipariş Ver',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.gray900),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.shopping_bag_rounded, color: AppColors.primary600),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (ctx) => ProducerOrdersHistoryPage(
                        producerName: producerName,
                        firmaName: connectedFirmalar.first,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header description block
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Ürünlerimizden seçin ve sipariş verin',
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500),
                ),
              ),

              // Search box
              Container(
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: TextField(
                  controller: _storeSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Ürün ara...',
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400),
                    suffixIcon: _storeSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              setState(() {
                                _storeSearchQuery = '';
                                _storeSearchCtrl.clear();
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
                      _storeSearchQuery = val.trim();
                    });
                  },
                ),
              ),

              // Category icons horizontal list
              Container(
                color: Colors.white,
                height: 74,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildCategoryBox('Tümü', Icons.grid_view_rounded, AppColors.primary600, _selectedStoreCategory == 'Tümü', () {
                      setState(() => _selectedStoreCategory = 'Tümü');
                    }),
                    _buildCategoryBox('Araç Gereç', Icons.build_rounded, const Color(0xFF009688), _selectedStoreCategory == 'Araç Gereç', () {
                      setState(() => _selectedStoreCategory = 'Araç Gereç');
                    }),
                    _buildCategoryBox('Vitamin', Icons.science_rounded, const Color(0xFF9C27B0), _selectedStoreCategory == 'Vitamin', () {
                      setState(() => _selectedStoreCategory = 'Vitamin');
                    }),
                    _buildCategoryBox('Yem', Icons.eco_rounded, const Color(0xFF4CAF50), _selectedStoreCategory == 'Yem', () {
                      setState(() => _selectedStoreCategory = 'Yem');
                    }),
                    _buildCategoryBox('İlaç', Icons.medical_services_rounded, const Color(0xFFEF4444), _selectedStoreCategory == 'İlaç', () {
                      setState(() => _selectedStoreCategory = 'İlaç');
                    }),
                  ],
                ),
              ),

              const Divider(height: 1),

              if (!siparisIzni)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.red[50],
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sipariş verme yetkiniz firma tarafından sınırlandırılmıştır.',
                          style: GoogleFonts.inter(fontSize: 12, color: Colors.red[800], fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
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
                    
                    var docs = (snapshot.data?.docs ?? []).toList();

                    // Apply store category filter
                    if (_selectedStoreCategory != 'Tümü') {
                      docs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final cat = data['kategori'] ?? 'Diğer';
                        return cat == _selectedStoreCategory;
                      }).toList();
                    }

                    // Apply store search query
                    if (_storeSearchQuery.isNotEmpty) {
                      docs = docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final ad = (data['ad'] ?? '').toString().toLowerCase();
                        return ad.contains(_storeSearchQuery.toLowerCase());
                      }).toList();
                    }

                    if (docs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40.0),
                          child: Text('Aradığınız kriterlere uygun ürün bulunmamaktadır.', style: GoogleFonts.inter(color: AppColors.gray400)),
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
                        final productFirma = data['firma'] ?? connectedFirmalar.first;

                        final inCart = _cart.containsKey(docId);
                        final qty = inCart ? _cart[docId]!['quantity'] as int : 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.gray200),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.02),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
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
                                    const SizedBox(height: 2),
                                    Text(kat, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                                    const SizedBox(height: 6),
                                    Text('${formatNumber.format(fiyat)} ₺ / $birim', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.primary600)),
                                    const SizedBox(height: 2),
                                    Text('Stok: ${stok.toStringAsFixed(0)} $birim', style: GoogleFonts.inter(fontSize: 11, color: stok <= 0 ? Colors.red : AppColors.gray500)),
                                  ],
                                ),
                              ),
                              if (inCart)
                                Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.remove, size: 14, color: AppColors.primary700),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        onPressed: () {
                                          setState(() {
                                            if (qty > 1) {
                                              _cart[docId]!['quantity'] = qty - 1;
                                            } else {
                                              _cart.remove(docId);
                                            }
                                          });
                                        },
                                      ),
                                      Text(
                                        qty.toString(),
                                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary800),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 14, color: AppColors.primary700),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                        onPressed: () {
                                          if (qty < stok) {
                                            setState(() {
                                              _cart[docId]!['quantity'] = qty + 1;
                                            });
                                          } else {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Yetersiz stok!'), backgroundColor: AppColors.danger),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ElevatedButton(
                                  onPressed: (stok <= 0 || !siparisIzni)
                                      ? null
                                      : () {
                                          setState(() {
                                            _cart[docId] = {
                                              'id': docId,
                                              'ad': ad,
                                              'birim': birim,
                                              'fiyat': fiyat,
                                              'stock': stok,
                                              'firma': productFirma,
                                              'quantity': 1,
                                            };
                                          });
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.add, size: 14),
                                      const SizedBox(width: 4),
                                      Text('Ekle', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
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
          bottomNavigationBar: _cart.isNotEmpty
              ? SafeArea(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_cart.length} Ürün Seçildi',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatNumber.format(_cart.values.fold(0.0, (sum, item) => sum + (item['fiyat'] as double) * (item['quantity'] as int)))} ₺',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary600),
                            ),
                          ],
                        ),
                        ElevatedButton(
                          onPressed: () => _showCartBottomSheet(producerName),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: Text(
                            'Sepeti Gör',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : null,
        );
      },
    );
  }

  void _showCartBottomSheet(String producerName) {
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            double total = 0.0;
            _cart.forEach((k, v) {
              total += (v['fiyat'] as double) * (v['quantity'] as int);
            });

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Sepetiniz',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: _cart.length,
                          itemBuilder: (context, index) {
                            final key = _cart.keys.elementAt(index);
                            final item = _cart[key]!;
                            final ad = item['ad'] as String;
                            final double price = item['fiyat'] as double;
                            final int qty = item['quantity'] as int;
                            final String unit = item['birim'] as String;
                            final double stock = item['stock'] as double;

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(ad, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                              subtitle: Text('${formatNumber.format(price)} ₺ / $unit'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                    onPressed: () {
                                      setState(() {
                                        if (qty > 1) {
                                          _cart[key]!['quantity'] = qty - 1;
                                        } else {
                                          _cart.remove(key);
                                        }
                                      });
                                      setSheetState(() {});
                                    },
                                  ),
                                  Text('$qty', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                    onPressed: () {
                                      if (qty < stock) {
                                        setState(() {
                                          _cart[key]!['quantity'] = qty + 1;
                                        });
                                        setSheetState(() {});
                                      }
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Toplam:', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('${formatNumber.format(total)} ₺', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary600)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _cart.isEmpty
                              ? null
                              : () async {
                                  final orderId = _generateOrderId();
                                  final itemsList = _cart.values.map((item) {
                                    final double itemTotal = (item['fiyat'] as double) * (item['quantity'] as int);
                                    return {
                                      'urun': item['ad'],
                                      'miktar': (item['quantity'] as int).toDouble(),
                                      'birim': item['birim'],
                                      'birimFiyat': item['fiyat'],
                                      'toplam': itemTotal,
                                    };
                                  }).toList();

                                  // Place multi-item order in urunler_siparisler
                                  await FirebaseFirestore.instance.collection('urunler_siparisler').add({
                                    'id': orderId,
                                    'uretici': producerName,
                                    'firma': _cart.values.first['firma'], // assume all from same company
                                    'durum': 'Bekliyor',
                                    'tarih': DateFormat('dd MMMM yyyy', 'tr_TR').format(DateTime.now()),
                                    'saat': DateFormat('HH:mm').format(DateTime.now()),
                                    'toplam': total,
                                    'timestamp': FieldValue.serverTimestamp(),
                                    'kalemler': itemsList,
                                  });

                                  setState(() {
                                    _cart.clear();
                                  });
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Siparişiniz başarıyla firmaya iletildi!'), backgroundColor: AppColors.success),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Siparişi Tamamla', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
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
class ProducerOrdersHistoryPage extends StatefulWidget {
  final String producerName;
  final String firmaName;
  const ProducerOrdersHistoryPage({required this.producerName, required this.firmaName});

  @override
  State<ProducerOrdersHistoryPage> createState() => _ProducerOrdersHistoryPageState();
}

class _ProducerOrdersHistoryPageState extends State<ProducerOrdersHistoryPage> {
  String _selectedStatusFilter = 'Tümü'; // Tümü, Bekliyor, Onaylandı, Teslimatta, Teslim Edildi, İptal

  List<Map<String, dynamic>> _getOrderItems(Map<String, dynamic> data) {
    if (data.containsKey('kalemler') && data['kalemler'] is List) {
      return List<Map<String, dynamic>>.from(
        (data['kalemler'] as List).map((e) => Map<String, dynamic>.from(e as Map))
      );
    } else {
      return [
        {
          'urun': data['urun'] ?? 'Bilinmeyen Ürün',
          'miktar': (data['miktar'] as num?)?.toDouble() ?? 1.0,
          'birim': data['birim'] ?? 'Adet',
          'birimFiyat': (data['birimFiyat'] as num?)?.toDouble() ?? 0.0,
          'toplam': (data['toplam'] as num?)?.toDouble() ?? 0.0,
        }
      ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'Siparişlerim',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtitle block
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Sipariş geçmişiniz ve durumu',
              style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500),
            ),
          ),

          // Filters horizontal list
          Container(
            color: Colors.white,
            height: 52,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: ['Tümü', 'Bekliyor', 'Onaylandı', 'Teslimatta', 'Teslim Edildi', 'İptal'].map((filter) {
                final isSelected = _selectedStatusFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(filter == 'Onaylandı' ? 'Hazırlandı' : filter),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedStatusFilter = filter;
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

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('urunler_siparisler')
                  .where('uretici', isEqualTo: widget.producerName)
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
                var docs = (snapshot.data?.docs ?? []).toList();

                // Sort locally by timestamp descending
                docs.sort((a, b) {
                  final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                // Apply status filter
                if (_selectedStatusFilter != 'Tümü') {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final durum = data['durum'] ?? 'Bekliyor';
                    return durum == _selectedStatusFilter;
                  }).toList();
                }

                if (docs.isEmpty) {
                  return Center(
                    child: Text('Kayıtlı siparişiniz bulunmuyor.', style: GoogleFonts.inter(color: AppColors.gray400)),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  itemBuilder: (context, idx) {
                    final doc = docs[idx];
                    final data = doc.data() as Map<String, dynamic>;
                    final durum = data['durum'] ?? 'Bekliyor';
                    final tarih = data['tarih'] ?? '';
                    final saat = data['saat'] ?? '';
                    final orderId = data['id'] ?? '';
                    final toplam = (data['toplam'] as num?)?.toDouble() ?? 0.0;
                    final items = _getOrderItems(data);

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
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.gray200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          )
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Sipariş $orderId', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.gray800)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                                child: Text(
                                  durum == 'Onaylandı' ? 'Hazırlandı' : durum,
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                ),
                              ),
                            ],
                          ),
                          if (durum == 'Bekliyor')
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Siparişi İptal Et'),
                                      content: const Text('Bu siparişi iptal etmek istediğinize emin misiniz?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Geri')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                                          onPressed: () async {
                                            await FirebaseFirestore.instance.collection('urunler_siparisler').doc(doc.id).update({'durum': 'İptal'});
                                            Navigator.pop(ctx, true);
                                          },
                                          child: const Text('Evet, İptal Et'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.red),
                                label: Text('İptal Et', style: GoogleFonts.inter(color: Colors.red, fontSize: 12)),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text('$tarih, $saat', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                          const SizedBox(height: 8),
                          ...items.map((item) => Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${item['miktar']} ${item['birim']} ${item['urun']}', style: GoogleFonts.inter(fontSize: 13)),
                                Text('${item['toplam'].toStringAsFixed(2)} TL', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          )),
                          const Divider(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Toplam: ', style: GoogleFonts.inter(fontSize: 14)),
                              Text('${toplam.toStringAsFixed(2)} TL', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold)),
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
}
