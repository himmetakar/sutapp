import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class FirmaAracEkleScreen extends StatefulWidget {
  final Map<String, dynamic>? editVehicleData;
  final String? editVehicleId;

  const FirmaAracEkleScreen({
    super.key,
    this.editVehicleData,
    this.editVehicleId,
  });

  @override
  State<FirmaAracEkleScreen> createState() => _FirmaAracEkleScreenState();
}

class _FirmaAracEkleScreenState extends State<FirmaAracEkleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adCtrl = TextEditingController();
  final _plakaCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yilCtrl = TextEditingController();
  final _kapasiteCtrl = TextEditingController();

  bool _isSaving = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    if (widget.editVehicleData != null && widget.editVehicleId != null) {
      _isEdit = true;
      final data = widget.editVehicleData!;
      _adCtrl.text = data['ad'] ?? data['aracAdi'] ?? '';
      _plakaCtrl.text = data['plaka'] ?? '';
      _modelCtrl.text = data['model'] ?? '';
      _yilCtrl.text = (data['yil'] ?? '').toString();
      
      // Get capacity from tanklar list or kapasite field
      double cap = 0.0;
      if (data['kapasite'] != null) {
        cap = (data['kapasite'] as num).toDouble();
      } else {
        final tankList = data['tanklar'] as List?;
        if (tankList != null && tankList.isNotEmpty) {
          cap = (tankList.first['kap'] as num).toDouble();
        }
      }
      _kapasiteCtrl.text = cap > 0 ? cap.toStringAsFixed(0) : '';
    }
  }

  @override
  void dispose() {
    _adCtrl.dispose();
    _plakaCtrl.dispose();
    _modelCtrl.dispose();
    _yilCtrl.dispose();
    _kapasiteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentFirmaName = auth.user?.displayName ?? '';

      if (!_isEdit) {
        final firmSnap = await FirebaseFirestore.instance.collection('firmalar').where('ad', isEqualTo: currentFirmaName).limit(1).get();
        if (firmSnap.docs.isNotEmpty) {
          final firmData = firmSnap.docs.first.data();
          final int maxArac = (firmData['maxArac'] as num?)?.toInt() ?? 5;
          final vehicleSnap = await FirebaseFirestore.instance.collection('araclar').where('firma', isEqualTo: currentFirmaName).get();
          if (vehicleSnap.docs.length >= maxArac) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Maksimum araç limitine ulaşıldı ($maxArac). Daha fazla araç ekleyemezsiniz.'),
                backgroundColor: AppColors.danger,
              ),
            );
            setState(() {
              _isSaving = false;
            });
            return;
          }
        }
      }

      final plate = _plakaCtrl.text.toUpperCase().trim();
      final ad = _adCtrl.text.trim();
      final model = _modelCtrl.text.trim();
      final yil = int.tryParse(_yilCtrl.text.trim()) ?? DateTime.now().year;
      final double capacity = double.tryParse(_kapasiteCtrl.text.trim()) ?? 0.0;

      // Create vehicle tank details
      final tankName = 'Tank-$plate';
      final List<Map<String, dynamic>> tanklar = [
        {
          'ad': tankName,
          'stok': widget.editVehicleData != null 
              ? ((widget.editVehicleData!['tanklar'] as List?)?.first['stok'] ?? 0.0) 
              : 0.0,
          'kap': capacity,
        }
      ];

      final vehicleData = {
        'plaka': plate,
        'ad': ad,
        'model': model,
        'yil': yil,
        'kapasite': capacity,
        'active': widget.editVehicleData?['active'] ?? true,
        'firma': currentFirmaName,
        'suruculer': widget.editVehicleData?['suruculer'] ?? [],
        'tanklar': tanklar,
      };

      if (_isEdit) {
        await FirebaseFirestore.instance.collection('araclar').doc(widget.editVehicleId).update(vehicleData);

        // Also update corresponding tank in tanklar collection
        final tankQuery = await FirebaseFirestore.instance
            .collection('tanklar')
            .where('arac', isEqualTo: widget.editVehicleData!['plaka'])
            .limit(1)
            .get();

        if (tankQuery.docs.isNotEmpty) {
          await tankQuery.docs.first.reference.update({
            'ad': tankName,
            'arac': plate,
            'kap': capacity,
          });
        }
      } else {
        // Checking for duplicates by plaka
        final existing = await FirebaseFirestore.instance
            .collection('araclar')
            .where('plaka', isEqualTo: plate)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $plate plakalı araç zaten kayıtlı!'), backgroundColor: AppColors.danger),
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }

        // Add to vehicles
        await FirebaseFirestore.instance.collection('araclar').add(vehicleData);

        // Create vehicle tank in tanklar collection
        await FirebaseFirestore.instance.collection('tanklar').add({
          'ad': tankName,
          'kap': capacity,
          'stok': 0.0,
          'tip': 'arac',
          'arac': plate,
          'firma': currentFirmaName,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Araç bilgileri güncellendi!' : 'Yeni araç başarıyla eklendi!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Araç Düzenle' : 'Yeni Araç Ekle',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isSaving
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Araç Bilgileri',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Araç Adı
                    Text(
                      'Araç Adı *',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _adCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Örn: Süt Toplama Aracı 1',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen araç adı girin' : null,
                    ),
                    const SizedBox(height: 16),

                    // Plaka
                    Text(
                      'Plaka *',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _plakaCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Örn: 06 ABC 123',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen plaka girin' : null,
                    ),
                    const SizedBox(height: 16),

                    // Model
                    Text(
                      'Model *',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _modelCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Örn: Ford Transit',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen model girin' : null,
                    ),
                    const SizedBox(height: 16),

                    // Yıl
                    Text(
                      'Yıl *',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _yilCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Örn: 2022',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen yıl girin' : null,
                    ),
                    const SizedBox(height: 16),

                    // Kapasite
                    Text(
                      'Kapasite (Litre) *',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _kapasiteCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Örn: 5000',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (v) => (v == null || double.tryParse(v.trim()) == null || double.parse(v.trim()) <= 0) 
                          ? 'Lütfen geçerli bir kapasite girin' 
                          : null,
                    ),
                    const SizedBox(height: 28),

                    // Create Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _save,
                        child: Text(
                          _isEdit ? 'Aracı Güncelle' : '+ Araç Oluştur',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
