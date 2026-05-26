import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../config/theme.dart';

class SutAnalizDialog extends StatefulWidget {
  final String targetName;
  final String tip; // 'Müşteri' or 'Tank'

  const SutAnalizDialog({
    super.key,
    required this.targetName,
    required this.tip,
  });

  static Future<void> show(BuildContext context, {required String targetName, required String tip}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => SutAnalizDialog(targetName: targetName, tip: tip),
    );
  }

  @override
  State<SutAnalizDialog> createState() => _SutAnalizDialogState();
}

class _SutAnalizDialogState extends State<SutAnalizDialog> {
  final _yagCtrl = TextEditingController(text: '0');
  final _proteinCtrl = TextEditingController(text: '0');
  final _suCtrl = TextEditingController(text: '0');
  final _sicaklikCtrl = TextEditingController(text: '0');
  final _yagsizKatilarCtrl = TextEditingController(text: '0');
  final _laktozCtrl = TextEditingController(text: '0');
  final _tuzCtrl = TextEditingController(text: '0');
  final _donmaNoktasiCtrl = TextEditingController(text: '0');

  bool _isSaving = false;

  @override
  void dispose() {
    _yagCtrl.dispose();
    _proteinCtrl.dispose();
    _suCtrl.dispose();
    _sicaklikCtrl.dispose();
    _yagsizKatilarCtrl.dispose();
    _laktozCtrl.dispose();
    _tuzCtrl.dispose();
    _donmaNoktasiCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final double yag = double.tryParse(_yagCtrl.text) ?? 0.0;
    final double protein = double.tryParse(_proteinCtrl.text) ?? 0.0;
    final double su = double.tryParse(_suCtrl.text) ?? 0.0;
    final double sicaklik = double.tryParse(_sicaklikCtrl.text) ?? 0.0;
    final double yagsizKatilar = double.tryParse(_yagsizKatilarCtrl.text) ?? 0.0;
    final double laktoz = double.tryParse(_laktozCtrl.text) ?? 0.0;
    final double tuz = double.tryParse(_tuzCtrl.text) ?? 0.0;
    final double donmaNoktasi = double.tryParse(_donmaNoktasiCtrl.text) ?? 0.0;

    setState(() => _isSaving = true);

    try {
      // Risk evaluation: standard limits
      // - Yağ < 3.0 %
      // - Eklenen Su > 0.0 %
      // - Sıcaklık > 6.0 °C
      bool isRiskli = yag < 3.0 || su > 0.0 || sicaklik > 6.0;
      final String durum = isRiskli ? 'Riskli' : 'Normal';

      final String formattedDate = DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(DateTime.now());

      await FirebaseFirestore.instance.collection('sut_analiz').add({
        'tip': widget.tip,
        'hedef': widget.targetName,
        'tarih': formattedDate,
        'yag': yag,
        'protein': protein,
        'su': su,
        'sicaklik': sicaklik,
        'yagsiz_katilar': yagsizKatilar,
        'laktoz': laktoz,
        'tuz': tuz,
        'donma_noktasi': donmaNoktasi,
        'durum': durum,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.targetName} için süt analizi başarıyla kaydedildi.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Analiz kaydedilirken hata oluştu: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.gray100)),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Row(
                        children: [
                          const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.primary600),
                          const SizedBox(width: 4),
                          Text(
                            'Geri',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'Süt Analizi',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gray800),
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    // Target subtitle
                    Text(
                      widget.targetName.toLowerCase(),
                      style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 20),

                    // Fields Grid (2 columns)
                    Row(
                      children: [
                        Expanded(child: _buildInputField('Yağ (%)', _yagCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInputField('Protein (%)', _proteinCtrl)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInputField('Eklenen Su (%)', _suCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInputField('Sıcaklık (°C)', _sicaklikCtrl)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInputField('Yağsız Katılar (%)', _yagsizKatilarCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInputField('Laktoz (%)', _laktozCtrl)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInputField('Tuz (%)', _tuzCtrl)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInputField('Donma Noktası (°C)', _donmaNoktasiCtrl)),
                      ],
                    ),
                    
                    const SizedBox(height: 24),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3B82F6),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                'Kaydet',
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.gray200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.primary600, width: 1.5),
            ),
            fillColor: Colors.white,
            filled: true,
          ),
        ),
      ],
    );
  }
}
