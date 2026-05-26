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

// --- MÜŞTERİ FİYAT AYARLARI SCREEN ---
class MusteriFiyatAyarlariScreen extends StatefulWidget {
  const MusteriFiyatAyarlariScreen({super.key});

  @override
  State<MusteriFiyatAyarlariScreen> createState() => _MusteriFiyatAyarlariScreenState();
}

class _MusteriFiyatAyarlariScreenState extends State<MusteriFiyatAyarlariScreen> with SingleTickerProviderStateMixin {
  late TabController _subTabController;
  String _selectedGrup = 'Tümü';
  String _selectedBolge = 'Tümü';
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
  );

  final Map<String, Map<String, TextEditingController>> _controllers = {};

  @override
  void initState() {
    super.initState();
    _subTabController = TabController(length: 2, vsync: this); // Bireysel, Grup Fiyatları
  }

  @override
  void dispose() {
    _subTabController.dispose();
    _controllers.forEach((_, controllers) {
      controllers.values.forEach((c) => c.dispose());
    });
    super.dispose();
  }

  TextEditingController _getController(String targetName, String key, String initialValue) {
    final compositeKey = '$targetName-$key';
    if (!_controllers.containsKey(compositeKey)) {
      _controllers[compositeKey] = {};
    }
    if (!_controllers[compositeKey]!.containsKey(key)) {
      _controllers[compositeKey]![key] = TextEditingController(text: initialValue);
    }
    return _controllers[compositeKey]![key]!;
  }

  void _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary600,
              onPrimary: Colors.white,
              onSurface: AppColors.gray800,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final dateFormat = DateFormat('dd MMM yyyy', 'tr_TR');

    return Scaffold(
      appBar: AppBar(
        title: Text('Süt Fiyat Girişleri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
        bottom: TabBar(
          controller: _subTabController,
          indicatorColor: AppColors.primary600,
          labelColor: AppColors.primary600,
          unselectedLabelColor: AppColors.gray500,
          tabs: const [
            Tab(text: 'Kişiye Özel Fiyatlar'),
            Tab(text: 'Gruba Özel Fiyatlar'),
          ],
          onTap: (idx) {
            setState(() {});
          },
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getProducersStream(firma: currentFirmaName),
        builder: (context, prodSnapshot) {
          if (prodSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allProducers = prodSnapshot.hasData
              ? prodSnapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList()
              : [];

          final gruplarList = allProducers.map((p) => p['group'] as String? ?? '').where((g) => g.isNotEmpty).toSet().toList();

          return StreamBuilder<QuerySnapshot>(
            stream: FirestoreService().getMilkPricesStream(firma: currentFirmaName),
            builder: (context, priceSnapshot) {
              final prices = priceSnapshot.hasData
                  ? priceSnapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList()
                  : [];

              double getResolvedPrice(String name, String type, String targetType) {
                // targetType = 'uretici' or 'grup'
                final match = prices.firstWhere(
                  (p) => p['tip'] == targetType && p['hedef'] == name,
                  orElse: () => <String, dynamic>{},
                );
                if (match.isNotEmpty && match['fiyatlar']?[type] != null) {
                  return (match['fiyatlar'][type] as num).toDouble();
                }

                // If not found for individual, check global as default
                if (targetType == 'uretici') {
                  final genPrice = prices.firstWhere(
                    (p) => p['tip'] == 'genel',
                    orElse: () => <String, dynamic>{},
                  );
                  if (genPrice.isNotEmpty && genPrice['fiyatlar']?[type] != null) {
                    return (genPrice['fiyatlar'][type] as num).toDouble();
                  }
                }
                return 0.0;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Date range selector (tarih aralığı seçebilelim)
                  AppCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shadow: AppShadows.sm,
                    color: AppColors.primary50,
                    child: InkWell(
                      onTap: () => _selectDateRange(context),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: AppColors.primary600),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Fiyat Geçerlilik Tarih Aralığı', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary700)),
                              const SizedBox(height: 2),
                              Text(
                                '${dateFormat.format(_selectedDateRange.start)} - ${dateFormat.format(_selectedDateRange.end)}',
                                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(Icons.arrow_drop_down_rounded, color: AppColors.gray500),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Actions header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text('Fiyat Geçmişi Kuralları', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: prices.isEmpty
                                    ? const Text('Kayıtlı fiyat kuralı bulunmuyor.')
                                    : ListView.builder(
                                        shrinkWrap: true,
                                        itemCount: prices.length,
                                        itemBuilder: (context, idx) {
                                          final p = prices[idx];
                                          final f = p['fiyatlar'] ?? {};
                                          return ListTile(
                                            contentPadding: EdgeInsets.zero,
                                            title: Text('${p['tip'].toString().toUpperCase()} - ${p['hedef']}'),
                                            subtitle: Text(
                                              'Sıcak: ${f['sicak'] ?? 0} ₺ | Soğuk: ${f['soguk'] ?? 0} ₺\nC Kalite: ${f['c_kalite'] ?? 0} ₺\nD Kalite: ${f['d_kalite'] ?? 0} ₺',
                                              style: GoogleFonts.inter(fontSize: 11),
                                            ),
                                            trailing: Text(
                                              '${p['baslangicTarihi'] ?? ''}\n${p['bitisTarihi'] ?? ''}',
                                              textAlign: TextAlign.right,
                                              style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('Fiyat Geçmişi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.gray700,
                          side: const BorderSide(color: AppColors.gray300),
                          elevation: 0,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => context.go('/firma/finans/sut-fiyatlari/toplu'),
                        icon: const Icon(Icons.settings_suggest_rounded, size: 18),
                        label: const Text('Toplu İşlemler'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary600,
                          foregroundColor: Colors.white,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Table Headers
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        Expanded(flex: 3, child: Text(_subTabController.index == 0 ? 'Üretici' : 'Grup', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500))),
                        Expanded(
                          flex: 5,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildTableHeaderIcon(Icons.water_drop_rounded, 'Sıcak', Colors.blue),
                              _buildTableHeaderIcon(Icons.ac_unit_rounded, 'Soğuk', Colors.teal),
                              _buildTableHeaderIcon(Icons.science_rounded, 'C Kal.', Colors.red),
                              _buildTableHeaderIcon(Icons.warning_amber_rounded, 'D Kal.', Colors.orange),
                              const SizedBox(width: 32), // space for settings cog
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: AppColors.gray200),

                  // Table Body
                  if (_subTabController.index == 0) ...[
                    // Customer Price List
                    allProducers.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Kayıtlı üretici bulunamadı.')))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: allProducers.length,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.gray100, height: 1),
                            itemBuilder: (context, index) {
                              final u = allProducers[index];
                              final name = u['name'] as String;
                              final phone = u['phone'] as String;

                              final double sicak = getResolvedPrice(name, 'sicak', 'uretici');
                              final double soguk = getResolvedPrice(name, 'soguk', 'uretici');
                              final double cKalite = getResolvedPrice(name, 'c_kalite', 'uretici');
                              final double dKalite = getResolvedPrice(name, 'd_kalite', 'uretici');

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                          Text(phone, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildPriceInput(name, 'sicak', sicak, 'uretici', currentFirmaName),
                                          _buildPriceInput(name, 'soguk', soguk, 'uretici', currentFirmaName),
                                          _buildPriceInput(name, 'c_kalite', cKalite, 'uretici', currentFirmaName),
                                          _buildPriceInput(name, 'd_kalite', dKalite, 'uretici', currentFirmaName),
                                          IconButton(
                                            icon: const Icon(Icons.settings_rounded, color: AppColors.primary600, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              _showSinglePriceDialog(context, name, 'uretici', currentFirmaName, sicak, soguk, cKalite, dKalite);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ] else ...[
                    // Group Price List
                    gruplarList.isEmpty
                        ? const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Kayıtlı grup bulunamadı.')))
                        : ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: gruplarList.length,
                            separatorBuilder: (context, index) => const Divider(color: AppColors.gray100, height: 1),
                            itemBuilder: (context, index) {
                              final groupName = gruplarList[index];

                              final double sicak = getResolvedPrice(groupName, 'sicak', 'grup');
                              final double soguk = getResolvedPrice(groupName, 'soguk', 'grup');
                              final double cKalite = getResolvedPrice(groupName, 'c_kalite', 'grup');
                              final double dKalite = getResolvedPrice(groupName, 'd_kalite', 'grup');

                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(groupName, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                          Text('Köy/Grup fiyatı', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _buildPriceInput(groupName, 'sicak', sicak, 'grup', currentFirmaName),
                                          _buildPriceInput(groupName, 'soguk', soguk, 'grup', currentFirmaName),
                                          _buildPriceInput(groupName, 'c_kalite', cKalite, 'grup', currentFirmaName),
                                          _buildPriceInput(groupName, 'd_kalite', dKalite, 'grup', currentFirmaName),
                                          IconButton(
                                            icon: const Icon(Icons.settings_rounded, color: AppColors.primary600, size: 20),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            onPressed: () {
                                              _showSinglePriceDialog(context, groupName, 'grup', currentFirmaName, sicak, soguk, cKalite, dKalite);
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTableHeaderIcon(IconData icon, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w500, color: AppColors.gray400)),
        Text('₺/L', style: GoogleFonts.inter(fontSize: 8, color: AppColors.gray400)),
      ],
    );
  }

  Widget _buildPriceInput(String targetName, String key, double value, String targetType, String firmaName) {
    final controller = _getController('$targetName-$targetType', key, value.toStringAsFixed(2));

    if (double.tryParse(controller.text) != value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (double.tryParse(controller.text) != value) {
          controller.text = value.toStringAsFixed(2);
        }
      });
    }

    return SizedBox(
      width: 44,
      height: 32,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray800),
        decoration: InputDecoration(
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: AppColors.gray100,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: AppColors.primary500, width: 1)),
        ),
        onSubmitted: (val) async {
          final double? doubleVal = double.tryParse(val.replaceAll(',', '.'));
          if (doubleVal != null) {
            final double sVal = key == 'sicak' ? doubleVal : double.tryParse(_getController('$targetName-$targetType', 'sicak', '0.0').text) ?? 0.0;
            final double soVal = key == 'soguk' ? doubleVal : double.tryParse(_getController('$targetName-$targetType', 'soguk', '0.0').text) ?? 0.0;
            final double cVal = key == 'c_kalite' ? doubleVal : double.tryParse(_getController('$targetName-$targetType', 'c_kalite', '0.0').text) ?? 0.0;
            final double dVal = key == 'd_kalite' ? doubleVal : double.tryParse(_getController('$targetName-$targetType', 'd_kalite', '0.0').text) ?? 0.0;

            await FirestoreService().saveMilkPrice({
              'firma': firmaName,
              'tip': targetType,
              'hedef': targetName,
              'baslangicTarihi': DateFormat('dd.MM.yyyy').format(_selectedDateRange.start),
              'bitisTarihi': DateFormat('dd.MM.yyyy').format(_selectedDateRange.end),
              'fiyatlar': {
                'sicak': sVal,
                'soguk': soVal,
                'c_kalite': cVal,
                'd_kalite': dVal,
              }
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$targetName için fiyat güncellendi!'),
                backgroundColor: AppColors.success,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        },
      ),
    );
  }

  void _showSinglePriceDialog(BuildContext context, String targetName, String targetType, String firma, double sicak, double soguk, double cKalite, double dKalite) {
    final sicakCtrl = TextEditingController(text: sicak.toStringAsFixed(2));
    final sogukCtrl = TextEditingController(text: soguk.toStringAsFixed(2));
    final cCtrl = TextEditingController(text: cKalite.toStringAsFixed(2));
    final dCtrl = TextEditingController(text: dKalite.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$targetName Özel Fiyatı', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogInput('Sıcak Süt (₺/L)', sicakCtrl, Icons.water_drop_rounded, Colors.blue),
            const SizedBox(height: 8),
            _buildDialogInput('Soğuk Süt (₺/L)', sogukCtrl, Icons.ac_unit_rounded, Colors.teal),
            const SizedBox(height: 8),
            _buildDialogInput('C Kalite Süt (₺/L)', cCtrl, Icons.science_rounded, Colors.red),
            const SizedBox(height: 8),
            _buildDialogInput('D Kalite Süt (₺/L)', dCtrl, Icons.warning_amber_rounded, Colors.orange),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600, foregroundColor: Colors.white),
            onPressed: () async {
              final double s = double.tryParse(sicakCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final double so = double.tryParse(sogukCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final double c = double.tryParse(cCtrl.text.replaceAll(',', '.')) ?? 0.0;
              final double d = double.tryParse(dCtrl.text.replaceAll(',', '.')) ?? 0.0;

              await FirestoreService().saveMilkPrice({
                'firma': firma,
                'tip': targetType,
                'hedef': targetName,
                'baslangicTarihi': DateFormat('dd.MM.yyyy').format(_selectedDateRange.start),
                'bitisTarihi': DateFormat('dd.MM.yyyy').format(_selectedDateRange.end),
                'fiyatlar': {
                  'sicak': s,
                  'soguk': so,
                  'c_kalite': c,
                  'd_kalite': d,
                }
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$targetName özel fiyatı başarıyla kaydedildi!'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Kaydet'),
          )
        ],
      ),
    );
  }

  Widget _buildDialogInput(String label, TextEditingController ctrl, IconData icon, Color color) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color, size: 18),
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}

// --- TOPLU İŞLEMLER SCREEN ---
class TopluIslemlerScreen extends StatefulWidget {
  const TopluIslemlerScreen({super.key});

  @override
  State<TopluIslemlerScreen> createState() => _TopluIslemlerScreenState();
}

class _TopluIslemlerScreenState extends State<TopluIslemlerScreen> {
  String _selectedGrup = 'Tümü';
  String _selectedBolge = 'Tümü';
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime(DateTime.now().year, DateTime.now().month, 1),
    end: DateTime(DateTime.now().year, DateTime.now().month + 1, 0),
  );

  final _sicakCtrl = TextEditingController();
  final _sogukCtrl = TextEditingController();
  final _cCtrl = TextEditingController();
  final _dCtrl = TextEditingController();

  @override
  void dispose() {
    _sicakCtrl.dispose();
    _sogukCtrl.dispose();
    _cCtrl.dispose();
    _dCtrl.dispose();
    super.dispose();
  }

  void _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('tr', 'TR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary600,
              onPrimary: Colors.white,
              onSurface: AppColors.gray800,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final dateFormat = DateFormat('dd MMM yyyy', 'tr_TR');

    return Scaffold(
      appBar: AppBar(
        title: Text('Toplu İşlemler', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans/sut-fiyatlari'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getProducersStream(firma: currentFirmaName),
        builder: (context, prodSnapshot) {
          if (prodSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allProducers = prodSnapshot.hasData
              ? prodSnapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList()
              : [];

          final gruplar = {'Tümü', ...allProducers.map((p) => p['group'] as String? ?? '').where((g) => g.isNotEmpty)};
          final bolgeler = {'Tümü', ...allProducers.map((p) => p['bolge'] as String? ?? '').where((b) => b.isNotEmpty)};

          final int matchedCount = allProducers.where((p) {
            final grupMatch = _selectedGrup == 'Tümü' || p['group'] == _selectedGrup;
            final bolgeMatch = _selectedBolge == 'Tümü' || p['bolge'] == _selectedBolge;
            return grupMatch && bolgeMatch;
          }).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                shadow: AppShadows.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hedef Kitle Seçimi', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Grup', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedGrup,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.gray300)),
                                ),
                                items: gruplar.map((g) => DropdownMenuItem(value: g, child: Text(g, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                                onChanged: (val) => setState(() => _selectedGrup = val ?? 'Tümü'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bölge', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: _selectedBolge,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  border: OutlineInputBorder(borderSide: BorderSide(color: AppColors.gray300)),
                                ),
                                items: bolgeler.map((b) => DropdownMenuItem(value: b, child: Text(b, style: GoogleFonts.inter(fontSize: 13)))).toList(),
                                onChanged: (val) => setState(() => _selectedBolge = val ?? 'Tümü'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$matchedCount üretici seçildi',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                shadow: AppShadows.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fiyat Dönemi', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _selectDateRange(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.gray50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.gray300),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: AppColors.gray600, size: 20),
                            const SizedBox(width: 10),
                            Text(
                              '${dateFormat.format(_selectedDateRange.start)} - ${dateFormat.format(_selectedDateRange.end)}',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_drop_down_rounded, color: AppColors.gray500),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              AppCard(
                padding: const EdgeInsets.all(16),
                shadow: AppShadows.sm,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Fiyat Güncelleme (₺/L)', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                    const SizedBox(height: 4),
                    Text('Sadece değiştirmek istediğiniz fiyatları girin.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: _buildFormInput('Sıcak Süt', _sicakCtrl, Colors.blue, Icons.water_drop_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildFormInput('Soğuk Süt', _sogukCtrl, Colors.teal, Icons.ac_unit_rounded)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildFormInput('C Kalite', _cCtrl, Colors.red, Icons.science_rounded)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildFormInput('D Kalite', _dCtrl, Colors.orange, Icons.warning_amber_rounded)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: matchedCount == 0 ? null : () async {
                  final double? sicak = double.tryParse(_sicakCtrl.text.replaceAll(',', '.'));
                  final double? soguk = double.tryParse(_sogukCtrl.text.replaceAll(',', '.'));
                  final double? cVal = double.tryParse(_cCtrl.text.replaceAll(',', '.'));
                  final double? dVal = double.tryParse(_dCtrl.text.replaceAll(',', '.'));

                  final Map<String, double> fiyatlar = {};
                  if (sicak != null) fiyatlar['sicak'] = sicak;
                  if (soguk != null) fiyatlar['soguk'] = soguk;
                  if (cVal != null) fiyatlar['c_kalite'] = cVal;
                  if (dVal != null) fiyatlar['d_kalite'] = dVal;

                  if (fiyatlar.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lütfen en az bir fiyat alanı doldurun!'), backgroundColor: Colors.orange),
                    );
                    return;
                  }

                  String tip = 'genel';
                  String hedef = 'Tümü';

                  if (_selectedBolge != 'Tümü') {
                    tip = 'bolge';
                    hedef = _selectedBolge;
                  } else if (_selectedGrup != 'Tümü') {
                    tip = 'grup';
                    hedef = _selectedGrup;
                  }

                  await FirestoreService().saveMilkPrice({
                    'firma': currentFirmaName,
                    'tip': tip,
                    'hedef': hedef,
                    'baslangicTarihi': DateFormat('dd.MM.yyyy').format(_selectedDateRange.start),
                    'bitisTarihi': DateFormat('dd.MM.yyyy').format(_selectedDateRange.end),
                    'fiyatlar': fiyatlar,
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Toplu fiyat güncellemesi başarıyla uygulandı! ($matchedCount Üretici)'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                    context.go('/firma/finans/sut-fiyatlari');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary600,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.gray300,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: Text('Kaydet ve Uygula', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormInput(String label, TextEditingController ctrl, Color color, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.gray500)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: color, size: 16),
            hintText: '0.00',
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: const OutlineInputBorder(borderSide: BorderSide(color: AppColors.gray300)),
          ),
        ),
      ],
    );
  }
}
