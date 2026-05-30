import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class FirmaProfilScreen extends StatefulWidget {
  const FirmaProfilScreen({super.key});

  @override
  State<FirmaProfilScreen> createState() => _FirmaProfilScreenState();
}

class _FirmaProfilScreenState extends State<FirmaProfilScreen> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _logoController;

  bool _loadingAddress = false;
  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _districts = [];
  Map<String, dynamic>? _selectedProvince;
  Map<String, dynamic>? _selectedDistrict;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;

    _nameController = TextEditingController(text: user?.displayName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    _logoController = TextEditingController();
    
    _loadCompanyLogo();
    _loadProvinces();
  }

  Future<void> _loadCompanyLogo() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    if (user != null) {
      try {
        final compQuery = await FirebaseFirestore.instance
            .collection('firmalar')
            .where('ad', isEqualTo: user.displayName)
            .limit(1)
            .get();
        if (compQuery.docs.isNotEmpty) {
          final compDoc = compQuery.docs.first;
          final compData = compDoc.data();
          if (compData.containsKey('logoUrl')) {
            if (mounted) {
              setState(() {
                _logoController.text = compData['logoUrl'] ?? '';
              });
            }
          }
        }
      } catch (e) {
        print('Error loading company logo: $e');
      }
    }
  }

  ImageProvider _getLogoImageProvider(String logoStr) {
    if (logoStr.startsWith('data:image')) {
      final commaIndex = logoStr.indexOf(',');
      if (commaIndex != -1) {
        final base64Part = logoStr.substring(commaIndex + 1);
        try {
          return MemoryImage(base64Decode(base64Part));
        } catch (e) {
          print('Base64 decode error: $e');
        }
      }
    }
    return NetworkImage(logoStr);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _logoController.dispose();
    super.dispose();
  }

  Future<void> _loadProvinces() async {
    if (mounted) setState(() => _loadingAddress = true);
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('https://turkiyeapi.dev/api/v1/provinces?fields=id,name'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded['status'] == 'OK' && decoded['data'] != null) {
          final list = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map((e) => {'id': e['id'], 'name': e['name']})
          );
          list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          if (mounted) {
            setState(() {
              _provinces = list;
              // Preselect current province
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final user = auth.user;
              if (user?.il != null && user!.il!.isNotEmpty) {
                final match = list.firstWhere(
                  (p) => p['name'].toString().toLowerCase() == user.il!.toLowerCase(),
                  orElse: () => <String, dynamic>{},
                );
                if (match.isNotEmpty) {
                  _selectedProvince = match;
                  _loadDistricts(match['id']);
                }
              }
            });
          }
        }
      }
    } catch (e) {
      print('Load provinces error: $e');
    } finally {
      client.close();
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  Future<void> _loadDistricts(int provinceId) async {
    if (mounted) setState(() => _loadingAddress = true);
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('https://turkiyeapi.dev/api/v1/districts?provinceId=$provinceId&fields=id,name'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded['status'] == 'OK' && decoded['data'] != null) {
          final list = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map((e) => {'id': e['id'], 'name': e['name']})
          );
          list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          if (mounted) {
            setState(() {
              _districts = list;
              // Preselect current district
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final user = auth.user;
              if (user?.ilce != null && user!.ilce!.isNotEmpty) {
                final match = list.firstWhere(
                  (d) => d['name'].toString().toLowerCase() == user.ilce!.toLowerCase(),
                  orElse: () => <String, dynamic>{},
                );
                if (match.isNotEmpty) {
                  _selectedDistrict = match;
                }
              }
            });
          }
        }
      }
    } catch (e) {
      print('Load districts error: $e');
    } finally {
      client.close();
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  void _resetFields() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final user = auth.user;
    setState(() {
      _nameController.text = user?.displayName ?? '';
      _emailController.text = user?.email ?? '';
      _phoneController.text = user?.phone ?? '';
      
      _selectedProvince = null;
      _selectedDistrict = null;
      _districts = [];
      
      if (user?.il != null && user!.il!.isNotEmpty) {
        final matchProv = _provinces.firstWhere(
          (p) => p['name'].toString().toLowerCase() == user.il!.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (matchProv.isNotEmpty) {
          _selectedProvince = matchProv;
          _loadDistricts(matchProv['id']);
        }
      }
      _isEditing = false;
    });
    _loadCompanyLogo();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final il = _selectedProvince?['name'] ?? '';
    final ilce = _selectedDistrict?['name'] ?? '';

    if (il.isEmpty || ilce.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Lütfen il ve ilçe seçiniz.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final oldName = auth.user?.displayName;
    
    try {
      await auth.updateUserProfile(
        displayName: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        il: il,
        ilce: ilce,
      );

      // Update company logoUrl in 'firmalar' collection
      final user = auth.user;
      if (user != null) {
        final queryName = (oldName != null && oldName.isNotEmpty) ? oldName : user.displayName;
        final compQuery = await FirebaseFirestore.instance
            .collection('firmalar')
            .where('ad', isEqualTo: queryName)
            .limit(1)
            .get();
        if (compQuery.docs.isNotEmpty) {
          final compDoc = compQuery.docs.first;
          await compDoc.reference.update({
            'ad': user.displayName,
            'logoUrl': _logoController.text.trim(),
          });
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profil başarıyla güncellendi.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.success,
        ),
      );

      setState(() {
        _isEditing = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Profil güncellenirken hata oluştu: $e',
            style: GoogleFonts.inter(fontWeight: FontWeight.w500),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final String currentFirma = user?.displayName ?? '';

    final avatarChar = user?.displayName.isNotEmpty == true 
        ? user!.displayName.substring(0, 1).toUpperCase() 
        : 'F';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('firmalar')
          .where('ad', isEqualTo: currentFirma)
          .snapshots(),
      builder: (context, firmSnap) {
        bool isNearExpiration = false;
        DateTime? expiryDate;

        if (firmSnap.hasData && firmSnap.data!.docs.isNotEmpty) {
          final firmData = firmSnap.data!.docs.first.data() as Map<String, dynamic>;
          final Timestamp? expiryTs = firmData['abonelikBitis'] as Timestamp?;
          if (expiryTs != null) {
            expiryDate = expiryTs.toDate();
            final now = DateTime.now();
            if (expiryDate.difference(now).inDays <= 30 && expiryDate.isAfter(now)) {
              isNearExpiration = true;
            }
          }
        }

        return Scaffold(
          backgroundColor: AppColors.gray50,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                if (isNearExpiration && expiryDate != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Abonelik süreniz doluyor! Son tarih: ${DateFormat('dd.MM.yyyy').format(expiryDate)}',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF991B1B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
            // Title
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  color: AppColors.gray700,
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/firma');
                    }
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  'Profil',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gray900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Profile Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.gray200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Avatar / Logo
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: _logoController.text.isEmpty
                            ? const LinearGradient(
                                colors: [AppColors.primary500, AppColors.primary700],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        shape: BoxShape.circle,
                        image: _logoController.text.isNotEmpty
                            ? DecorationImage(
                                image: _getLogoImageProvider(_logoController.text),
                                fit: BoxFit.cover,
                              )
                            : null,
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.blueAccent,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: _logoController.text.isEmpty
                          ? Center(
                              child: Text(
                                avatarChar,
                                style: GoogleFonts.inter(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Name
                    Text(
                      user?.displayName ?? 'Firma Yöneticisi',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Role Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        user?.roleName ?? 'Firma Yöneticisi',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section Title with Edit Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kişisel Bilgiler',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gray700,
                          ),
                        ),
                        if (!_isEditing)
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _isEditing = true;
                              });
                            },
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: Text(
                              'Düzenle',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary600,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Details Section (Normal or Edit mode)
                    if (!_isEditing) ...[
                      _buildDetailItem(Icons.person_outline_rounded, 'Ad Soyad', user?.displayName ?? '-'),
                      _buildDetailItem(Icons.mail_outline_rounded, 'E-posta', user?.email ?? '-'),
                      _buildDetailItem(Icons.phone_outlined, 'Telefon', user?.phone ?? '-'),
                      _buildDetailItem(Icons.info_outline_rounded, 'Firma ID', user?.firmaId ?? 'Demo Firma'),
                      _buildDetailItem(Icons.image_outlined, 'Firma Logosu', _logoController.text.isNotEmpty ? 'Eklenmiş' : 'Eklenmemiş'),
                      _buildDetailItem(
                        Icons.location_on_outlined, 
                        'Konum', 
                        '${user?.il ?? "-"}${(user?.ilce != null && user!.ilce!.isNotEmpty) ? " / ${user.ilce}" : ""}'
                      ),
                    ] else ...[
                      _buildEditField(Icons.person_outline_rounded, 'Ad Soyad', _nameController, (val) {
                        if (val == null || val.trim().isEmpty) return 'Ad Soyad boş bırakılamaz.';
                        return null;
                      }),
                      _buildEditField(Icons.mail_outline_rounded, 'E-posta', _emailController, (val) {
                        if (val == null || val.trim().isEmpty) return 'E-posta boş bırakılamaz.';
                        if (!val.contains('@')) return 'Geçerli bir e-posta adresi girin.';
                        return null;
                      }),
                      _buildEditField(Icons.phone_outlined, 'Telefon', _phoneController, (val) {
                        if (val == null || val.trim().isEmpty) return 'Telefon boş bırakılamaz.';
                        return null;
                      }),
                      
                      // Custom image picker widget instead of logo text field
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Firma Logosu',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gray700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: AppColors.gray100,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.gray300),
                                    image: _logoController.text.isNotEmpty
                                        ? DecorationImage(
                                            image: _getLogoImageProvider(_logoController.text),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: _logoController.text.isEmpty
                                      ? const Icon(Icons.image_outlined, color: AppColors.gray400)
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    try {
                                      final ImagePicker picker = ImagePicker();
                                      final XFile? image = await picker.pickImage(
                                        source: ImageSource.gallery,
                                        maxWidth: 300,
                                        maxHeight: 300,
                                        imageQuality: 70,
                                      );
                                      if (image != null) {
                                        final bytes = await image.readAsBytes();
                                        final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
                                        setState(() {
                                          _logoController.text = base64String;
                                        });
                                      }
                                    } catch (e) {
                                      print("Error picking image: $e");
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Dosya seçilirken bir hata oluştu: $e'),
                                          backgroundColor: AppColors.danger,
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.photo_library_rounded, size: 16),
                                  label: const Text('Dosya Seç'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                if (_logoController.text.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _logoController.text = '';
                                      });
                                    },
                                    icon: const Icon(Icons.delete_outline_rounded, size: 16, color: AppColors.danger),
                                    label: const Text('Kaldır', style: TextStyle(color: AppColors.danger)),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      // Province Dropdown
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedProvince,
                        hint: const Text('İl Seçiniz'),
                        decoration: InputDecoration(
                          labelText: 'İl *',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          prefixIcon: Icon(Icons.map_outlined, size: 18, color: AppColors.gray400),
                        ),
                        items: _provinces.map((prov) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: prov,
                            child: Text(prov['name']),
                          );
                        }).toList(),
                        onChanged: _loadingAddress ? null : (prov) {
                          setState(() {
                            _selectedProvince = prov;
                            _selectedDistrict = null;
                            _districts = [];
                          });
                          if (prov != null) {
                            _loadDistricts(prov['id']);
                          }
                        },
                        validator: (v) => v == null ? 'Lütfen il seçin' : null,
                      ),
                      const SizedBox(height: 12),

                      // District Dropdown
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedDistrict,
                        hint: const Text('İlçe Seçiniz'),
                        decoration: InputDecoration(
                          labelText: 'İlçe *',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          prefixIcon: Icon(Icons.location_city_outlined, size: 18, color: AppColors.gray400),
                        ),
                        items: _districts.map((dist) {
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: dist,
                            child: Text(dist['name']),
                          );
                        }).toList(),
                        onChanged: (_loadingAddress || _selectedProvince == null) ? null : (dist) {
                          setState(() {
                            _selectedDistrict = dist;
                          });
                        },
                        validator: (v) => v == null ? 'Lütfen ilçe seçin' : null,
                      ),
                      const SizedBox(height: 12),
                      
                      _buildReadOnlyDetailItem(Icons.info_outline_rounded, 'Firma ID', user?.firmaId ?? 'Demo Firma'),
                    ],

                    const SizedBox(height: 24),

                    // Action Buttons (Save/Cancel or Logout)
                    if (_isEditing) ...[
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _resetFields,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: AppColors.gray300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(
                                  'Vazgeç',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gray700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                onPressed: (auth.loading || _loadingAddress) ? null : _saveProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary600,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: auth.loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                        ),
                                      )
                                    : Text(
                                        'Kaydet',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            auth.logout();
                            context.go('/login');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.danger,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.logout_rounded, size: 16),
                          label: Text(
                            'Çıkış Yap',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            ],
          ),
        ),
      );
    },
  );
}

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Container(
        padding: const EdgeInsets.only(bottom: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.gray100),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppColors.gray400),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppColors.gray500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.gray800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadOnlyDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.gray400),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.gray500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.gray800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(
    IconData icon,
    String label,
    TextEditingController controller,
    FormFieldValidator<String>? validator,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        validator: validator,
        style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray800, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.w500),
          prefixIcon: Icon(icon, size: 18, color: AppColors.gray400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: AppColors.gray300),
          ),
          enabledBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: AppColors.gray300),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: AppColors.primary500, width: 1.5),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8)),
            borderSide: BorderSide(color: Colors.red),
          ),
        ),
      ),
    );
  }
}
