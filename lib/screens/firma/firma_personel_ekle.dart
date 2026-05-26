import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class FirmaPersonelEkleScreen extends StatefulWidget {
  final Map<String, dynamic>? editDriverData;
  final String? editDriverId;

  const FirmaPersonelEkleScreen({
    super.key,
    this.editDriverData,
    this.editDriverId,
  });

  @override
  State<FirmaPersonelEkleScreen> createState() => _FirmaPersonelEkleScreenState();
}

class _FirmaPersonelEkleScreenState extends State<FirmaPersonelEkleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _adSoyadCtrl = TextEditingController();
  final _tcCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _sifreCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _adresCtrl = TextEditingController();
  final _bolgeCtrl = TextEditingController();

  bool _isSaving = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();
    if (widget.editDriverData != null && widget.editDriverId != null) {
      _isEdit = true;
      final data = widget.editDriverData!;
      final ad = data['ad'] ?? '';
      final soyad = data['soyad'] ?? '';
      _adSoyadCtrl.text = ad.isNotEmpty && soyad.isNotEmpty ? '$ad $soyad' : (ad.isNotEmpty ? ad : soyad);
      _tcCtrl.text = data['tc'] ?? '';
      _emailCtrl.text = data['email'] ?? '';
      _telCtrl.text = data['tel'] ?? '';
      _adresCtrl.text = data['adres'] ?? '';
      _bolgeCtrl.text = data['bolge'] ?? '';
      _sifreCtrl.text = data['sifre'] ?? '******'; // Placeholder for password edit
    }
  }

  @override
  void dispose() {
    _adSoyadCtrl.dispose();
    _tcCtrl.dispose();
    _emailCtrl.dispose();
    _sifreCtrl.dispose();
    _telCtrl.dispose();
    _adresCtrl.dispose();
    _bolgeCtrl.dispose();
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

      // Parse first name and last name
      final nameParts = _adSoyadCtrl.text.trim().split(' ');
      String ad = '';
      String soyad = '';
      if (nameParts.length > 1) {
        ad = nameParts.sublist(0, nameParts.length - 1).join(' ');
        soyad = nameParts.last;
      } else {
        ad = nameParts.first;
      }

      final tcVal = _tcCtrl.text.trim();
      final tcObfuscated = tcVal.length >= 9
          ? '${tcVal.substring(0, 9)}**'
          : tcVal;

      final phone = _telCtrl.text.trim();
      final email = _emailCtrl.text.trim();
      final sifre = _sifreCtrl.text;
      final adres = _adresCtrl.text.trim();
      final bolge = _bolgeCtrl.text.trim();

      final driverData = {
        'ad': ad,
        'soyad': soyad,
        'tel': phone,
        'email': email,
        'tc': tcObfuscated,
        'sifre': sifre,
        'adres': adres,
        'bolge': bolge,
        'firma': currentFirmaName,
        'active': widget.editDriverData?['active'] ?? true,
        'canAddCustomer': widget.editDriverData?['canAddCustomer'] ?? true,
        'canEditCustomer': widget.editDriverData?['canEditCustomer'] ?? true,
        'canCreateOrder': widget.editDriverData?['canCreateOrder'] ?? false,
      };

      if (_isEdit) {
        await FirebaseFirestore.instance.collection('suruculer').doc(widget.editDriverId).update(driverData);

        // Also update users collection if a user profile exists or create it
        final userQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();

        final userData = {
          'displayName': _adSoyadCtrl.text.trim(),
          'name': _adSoyadCtrl.text.trim(),
          'email': email,
          'phone': phone,
          'role': 'surucu',
          'firmaName': currentFirmaName,
          'ilce': bolge,
          'adresDetay': adres,
        };

        if (userQuery.docs.isNotEmpty) {
          await userQuery.docs.first.reference.update(userData);
        } else {
          // If password was changed/set, we can generate a new user profile doc
          final userUid = 'driver_${phone.hashCode}';
          await FirebaseFirestore.instance.collection('users').doc(userUid).set({
            ...userData,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      } else {
        // Checking for duplicates by phone
        final existing = await FirebaseFirestore.instance
            .collection('suruculer')
            .where('tel', isEqualTo: phone)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $phone numaralı personel zaten kayıtlı!'), backgroundColor: AppColors.danger),
          );
          setState(() {
            _isSaving = false;
          });
          return;
        }

        // Add to drivers collection
        await FirebaseFirestore.instance.collection('suruculer').add(driverData);

        // Add to users collection so driver can login
        final userUid = 'driver_${phone.hashCode}';
        await FirebaseFirestore.instance.collection('users').doc(userUid).set({
          'displayName': _adSoyadCtrl.text.trim(),
          'name': _adSoyadCtrl.text.trim(),
          'email': email,
          'phone': phone,
          'role': 'surucu',
          'firmaName': currentFirmaName,
          'ilce': bolge,
          'adresDetay': adres,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEdit ? 'Personel bilgileri güncellendi!' : 'Yeni personel başarıyla eklendi!'),
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
          _isEdit ? 'Personel Düzenle' : 'Yeni Personel Ekle',
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
                      'Personel Bilgileri',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Ad Soyad
                    Text(
                      'Ad Soyad',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _adSoyadCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Örn: Ahmet Kara',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen ad soyad girin' : null,
                    ),
                    const SizedBox(height: 16),

                    // TC Kimlik
                    Text(
                      'T.C. Kimlik Numarası',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _tcCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Örn: 11 Haneli T.C.',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Lütfen T.C. kimlik numarası girin';
                        if (v.trim().length != 11) return 'T.C. kimlik numarası 11 haneli olmalıdır';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // E-posta
                    Text(
                      'E-posta Adresi',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        hintText: 'Örn: ahmet@sutapp.com',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Şifre
                    Text(
                      'Şifre',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _sifreCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        hintText: 'En az 6 karakter',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (v) => (v == null || v.length < 6) ? 'Şifre en az 6 karakter olmalıdır' : null,
                    ),
                    const SizedBox(height: 16),

                    // Telefon
                    Text(
                      'Telefon Numarası',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _telCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        hintText: 'Örn: 0532 123 4567',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen telefon girin' : null,
                    ),
                    const SizedBox(height: 16),

                    // Adres
                    Text(
                      'Adres',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _adresCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Açık adres...',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Bölge
                    Text(
                      'Bölge',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray700),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _bolgeCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Örn: Kocasinan',
                        fillColor: Color(0xFFF8FAFC),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
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
                          _isEdit ? 'Personeli Güncelle' : '+ Personel Oluştur',
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
