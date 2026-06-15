import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class TankEkleScreen extends StatefulWidget {
  const TankEkleScreen({super.key});

  @override
  State<TankEkleScreen> createState() => _TankEkleScreenState();
}

class _TankEkleScreenState extends State<TankEkleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  final _hacimCtrl = TextEditingController();
  
  String _tankTip = 'arac';
  String? _selectedPlaka;
  String? _selectedSurucu;
  bool _saving = false; // çift tıklamayı önler

  @override
  void dispose() {
    _adCtrl.dispose();
    _hacimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Yeni Tank Ekle',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tanklar')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, tankSnapshot) {
          final existingCount = tankSnapshot.data?.docs.length ?? 0;
          final autoCode = 'TANK-${(existingCount + 1).toString().padLeft(3, '0')}';

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('araclar')
                .where('firma', isEqualTo: currentFirmaName)
                .snapshots(),
            builder: (context, vehicleSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('suruculer')
                    .where('firma', isEqualTo: currentFirmaName)
                    .snapshots(),
                builder: (context, driverSnapshot) {
                  // Build vehicle plate list
                  final List<String> vehiclePlates = [];
                  if (vehicleSnapshot.hasData) {
                    for (var doc in vehicleSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final plaka = data['plaka'] as String? ?? '';
                      if (plaka.isNotEmpty) vehiclePlates.add(plaka);
                    }
                  }

                  // Build driver name list
                  final List<String> driverNames = [];
                  if (driverSnapshot.hasData) {
                    for (var doc in driverSnapshot.data!.docs) {
                      final data = doc.data() as Map<String, dynamic>;
                      final ad = data['ad'] as String? ?? '';
                      final soyad = data['soyad'] as String? ?? '';
                      final fullName = '$ad $soyad'.trim();
                      if (fullName.isNotEmpty) driverNames.add(fullName);
                    }
                  }

                  // Ensure selected values are still valid
                  if (_selectedPlaka != null && !vehiclePlates.contains(_selectedPlaka)) {
                    _selectedPlaka = null;
                  }
                  if (_selectedSurucu != null && !driverNames.contains(_selectedSurucu)) {
                    _selectedSurucu = null;
                  }

                  return Form(
                    key: _formKey,
                    child: ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Tank Adı
                        Text(
                          'Tank Adı',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _adCtrl,
                          style: GoogleFonts.inter(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Örn: Ana Soğutma Tankı',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty ? 'Lütfen tank adı girin' : null,
                        ),
                        const SizedBox(height: 20),

                        // Tank Kodu
                        Text(
                          'Tank Kodu (Otomatik)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: AppColors.gray100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.gray200),
                          ),
                          child: Text(
                            autoCode,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tank kodu sistem tarafından otomatik olarak oluşturulur.',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: AppColors.gray400,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Tank Türü Selection Cards
                        Text(
                          'Tank Türü',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Normal Tank Radio Container
                        GestureDetector(
                          onTap: () => setState(() => _tankTip = 'arac'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _tankTip == 'arac' ? const Color(0xFF3B82F6) : AppColors.gray200,
                                width: _tankTip == 'arac' ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'arac',
                                  groupValue: _tankTip,
                                  activeColor: const Color(0xFF3B82F6),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _tankTip = val);
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Normal Tank',
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gray800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Araçlara atanabilen mobil tanklar',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.gray500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Merkez Tankı Radio Container
                        GestureDetector(
                          onTap: () => setState(() => _tankTip = 'merkez'),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _tankTip == 'merkez' ? const Color(0xFF3B82F6) : AppColors.gray200,
                                width: _tankTip == 'merkez' ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Radio<String>(
                                  value: 'merkez',
                                  groupValue: _tankTip,
                                  activeColor: const Color(0xFF3B82F6),
                                  onChanged: (val) {
                                    if (val != null) setState(() => _tankTip = val);
                                  },
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Merkez Tankı',
                                        style: GoogleFonts.inter(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gray800,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Fabrika/işletme merkezindeki sabit tanklar',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.gray500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Vehicle & Driver Selection - Only for Normal Tank
                        if (_tankTip == 'arac') ...[
                          // Vehicle Plate Dropdown
                          Text(
                            'Araç Seçimi (Opsiyonel)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedPlaka,
                              hint: Text(
                                'Araç plakası seçin...',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                              ),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.local_shipping_rounded, size: 18, color: AppColors.gray400),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                suffixIcon: _selectedPlaka != null
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.gray400),
                                        onPressed: () => setState(() => _selectedPlaka = null),
                                      )
                                    : null,
                              ),
                              isExpanded: true,
                              items: vehiclePlates.map((plaka) {
                                return DropdownMenuItem<String>(
                                  value: plaka,
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.gray100,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.gray300),
                                        ),
                                        child: Text(
                                          plaka,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.gray700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedPlaka = val);
                              },
                            ),
                          ),
                          if (vehiclePlates.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Sistemde kayıtlı araç bulunamadı.',
                                style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.gray400, fontStyle: FontStyle.italic),
                              ),
                            ),
                          const SizedBox(height: 20),

                          // Driver Selection Dropdown
                          Text(
                            'Toplayıcı Seçimi (Opsiyonel)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _selectedSurucu,
                              hint: Text(
                                'Toplayıcı seçin...',
                                style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray400),
                              ),
                              decoration: InputDecoration(
                                prefixIcon: const Icon(Icons.person_rounded, size: 18, color: AppColors.gray400),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                suffixIcon: _selectedSurucu != null
                                    ? IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.gray400),
                                        onPressed: () => setState(() => _selectedSurucu = null),
                                      )
                                    : null,
                              ),
                              isExpanded: true,
                              items: driverNames.map((name) {
                                return DropdownMenuItem<String>(
                                  value: name,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0F8B5A).withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            name.isNotEmpty ? name[0] : '?',
                                            style: GoogleFonts.inter(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFF0F8B5A),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        name,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.gray700,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() => _selectedSurucu = val);
                              },
                            ),
                          ),
                          if (driverNames.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Sistemde kayıtlı toplayıcı bulunamadı.',
                                style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.gray400, fontStyle: FontStyle.italic),
                              ),
                            ),
                          const SizedBox(height: 20),
                        ],

                        // Tank Hacmi
                        Text(
                          'Tank Hacmi (Litre)',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _hacimCtrl,
                          style: GoogleFonts.inter(fontSize: 13),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            hintText: 'Örn: 5000',
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) return 'Lütfen tank hacmini girin';
                            if (double.tryParse(value) == null) return 'Geçerli bir sayı girin';
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),

                        // Kaydet butonu
                        ElevatedButton(
                          onPressed: _saving
                              ? null
                              : () async {
                                  if (!_formKey.currentState!.validate()) return;
                                  setState(() => _saving = true);
                                  try {
                                    final double cap = double.parse(_hacimCtrl.text.replaceAll(',', '.'));
                                    final String plateValue = _selectedPlaka ?? '';

                                    final List<String> tankSuruculer = [];
                                    if (_selectedSurucu != null && _selectedSurucu!.isNotEmpty) {
                                      tankSuruculer.add(_selectedSurucu!);
                                    }

                                    final newTank = {
                                      'ad': _adCtrl.text.trim(),
                                      'kod': autoCode,
                                      'kap': cap,
                                      'stok': 0.0,
                                      'tip': _tankTip,
                                      'arac': _tankTip == 'arac' ? plateValue : '',
                                      'firma': currentFirmaName,
                                      'durum': 'aktif',
                                      if (tankSuruculer.isNotEmpty) 'suruculer': tankSuruculer,
                                    };

                                    await FirebaseFirestore.instance.collection('tanklar').add(newTank);

                                    if (_tankTip == 'arac' && plateValue.isNotEmpty) {
                                      final vehicleQuery = await FirebaseFirestore.instance
                                          .collection('araclar')
                                          .where('plaka', isEqualTo: plateValue)
                                          .limit(1)
                                          .get();

                                      if (vehicleQuery.docs.isNotEmpty) {
                                        final vehicleDoc = vehicleQuery.docs.first;
                                        final List<dynamic> vehicleTanks =
                                            List.from(vehicleDoc['tanklar'] as List? ?? []);
                                        vehicleTanks.add({
                                          'ad': _adCtrl.text.trim(),
                                          'stok': 0.0,
                                          'kap': cap,
                                          if (tankSuruculer.isNotEmpty) 'suruculer': tankSuruculer,
                                        });
                                        await vehicleDoc.reference.update({'tanklar': vehicleTanks});

                                        if (_selectedSurucu != null && _selectedSurucu!.isNotEmpty) {
                                          final List<dynamic> vehicleDrivers =
                                              List.from(vehicleDoc['suruculer'] as List? ?? []);
                                          if (!vehicleDrivers.contains(_selectedSurucu)) {
                                            vehicleDrivers.add(_selectedSurucu!);
                                            await vehicleDoc.reference.update({'suruculer': vehicleDrivers});
                                          }
                                        }
                                      }
                                    }

                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('✅ Tank başarıyla kaydedildi!'),
                                          backgroundColor: AppColors.success,
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                      context.pop();
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Hata: $e'),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                    setState(() => _saving = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF3B82F6),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Tankı Kaydet',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
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
      ),
    );
  }
}
