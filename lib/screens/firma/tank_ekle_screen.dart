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
  final _aracCtrl = TextEditingController();
  
  String _tankTip = 'arac'; // 'arac' (Normal Tank) or 'merkez' (Merkez Tankı)

  @override
  void dispose() {
    _adCtrl.dispose();
    _hacimCtrl.dispose();
    _aracCtrl.dispose();
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
        builder: (context, snapshot) {
          final existingCount = snapshot.data?.docs.length ?? 0;
          final autoCode = 'TANK-${(existingCount + 1).toString().padLeft(3, '0')}';

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

                // Optional Vehicle Plate Input if Normal Tank is selected
                if (_tankTip == 'arac') ...[
                  Text(
                    'Araç Plakası (Opsiyonel)',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _aracCtrl,
                    style: GoogleFonts.inter(fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Örn: 38 AB 123',
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

                // Save Button
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final double cap = double.parse(_hacimCtrl.text.replaceAll(',', '.'));
                      
                      final newTank = {
                        'ad': _adCtrl.text.trim(),
                        'kod': autoCode,
                        'kap': cap,
                        'stok': 0.0,
                        'tip': _tankTip,
                        'arac': _tankTip == 'arac' ? _aracCtrl.text.trim().toUpperCase() : '',
                        'firma': currentFirmaName,
                        'durum': 'aktif',
                      };

                      await FirebaseFirestore.instance.collection('tanklar').add(newTank);

                      // If vehicle plate is provided, link tank inside the vehicle's array
                      if (_tankTip == 'arac' && _aracCtrl.text.trim().isNotEmpty) {
                        final plate = _aracCtrl.text.trim().toUpperCase();
                        final vehicleQuery = await FirebaseFirestore.instance
                            .collection('araclar')
                            .where('plaka', isEqualTo: plate)
                            .limit(1)
                            .get();
                            
                        if (vehicleQuery.docs.isNotEmpty) {
                          final vehicleDoc = vehicleQuery.docs.first;
                          final List<dynamic> vehicleTanks = List.from(vehicleDoc['tanklar'] as List? ?? []);
                          vehicleTanks.add({
                            'ad': _adCtrl.text.trim(),
                            'stok': 0.0,
                            'kap': cap,
                          });
                          await vehicleDoc.reference.update({'tanklar': vehicleTanks});
                        }
                      }

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tank başarıyla kaydedildi!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                        context.pop();
                      }
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
                  child: Text(
                    'Tankı Kaydet',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
