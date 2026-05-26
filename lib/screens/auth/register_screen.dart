import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../config/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  // Manual text controllers for offline/manual mode
  final TextEditingController _manualIlController = TextEditingController();
  final TextEditingController _manualIlceController = TextEditingController();
  final TextEditingController _manualMahalleController = TextEditingController();

  bool _manualMode = false;
  bool _loadingAddress = false;
  String _errorMessage = '';

  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _districts = [];
  List<Map<String, dynamic>> _neighborhoods = [];

  Map<String, dynamic>? _selectedProvince;
  Map<String, dynamic>? _selectedDistrict;
  Map<String, dynamic>? _selectedNeighborhood;

  UserRole _selectedRole = UserRole.uretici;

  List<Map<String, dynamic>> _companiesList = [];
  Map<String, dynamic>? _selectedCompany;
  bool _loadingCompanies = false;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    if (!mounted) return;
    setState(() {
      _loadingCompanies = true;
    });
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final list = await auth.getCompanies();
      if (!mounted) return;
      setState(() {
        _companiesList = list;
      });
    } catch (e) {
      print('Load companies error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingCompanies = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _zipController.dispose();
    _emailController.dispose();
    _manualIlController.dispose();
    _manualIlceController.dispose();
    _manualMahalleController.dispose();
    super.dispose();
  }

  // Fetch provinces from API
  Future<void> _loadProvinces() async {
    setState(() {
      _loadingAddress = true;
      _errorMessage = '';
    });

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
          setState(() {
            _provinces = list;
            _manualMode = false;
          });
        } else {
          _enableManualMode();
        }
      } else {
        _enableManualMode();
      }
    } catch (e) {
      _enableManualMode();
    } finally {
      client.close();
      setState(() {
        _loadingAddress = false;
      });
    }
  }

  // Fetch districts based on province
  Future<void> _loadDistricts(int provinceId) async {
    setState(() {
      _loadingAddress = true;
      _districts = [];
      _neighborhoods = [];
      _selectedDistrict = null;
      _selectedNeighborhood = null;
    });

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
          setState(() {
            _districts = list;
          });
        }
      }
    } catch (e) {
      print('Districts error: $e');
    } finally {
      client.close();
      setState(() {
        _loadingAddress = false;
      });
    }
  }

  // Fetch neighborhoods based on district
  Future<void> _loadNeighborhoods(int districtId) async {
    setState(() {
      _loadingAddress = true;
      _neighborhoods = [];
      _selectedNeighborhood = null;
    });

    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse('https://turkiyeapi.dev/api/v1/neighborhoods?districtId=$districtId&fields=id,name'));
      final response = await request.close();
      if (response.statusCode == 200) {
        final body = await response.transform(utf8.decoder).join();
        final decoded = jsonDecode(body);
        if (decoded['status'] == 'OK' && decoded['data'] != null) {
          final list = List<Map<String, dynamic>>.from(
            (decoded['data'] as List).map((e) => {'id': e['id'], 'name': e['name']})
          );
          list.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
          setState(() {
            _neighborhoods = list;
          });
        }
      }
    } catch (e) {
      print('Neighborhoods error: $e');
    } finally {
      client.close();
      setState(() {
        _loadingAddress = false;
      });
    }
  }

  void _enableManualMode() {
    setState(() {
      _manualMode = true;
      _provinces = [];
      _districts = [];
      _neighborhoods = [];
      _selectedProvince = null;
      _selectedDistrict = null;
      _selectedNeighborhood = null;
    });
  }

  Future<void> _submit(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _errorMessage = '';
    });

    String il = _manualMode ? _manualIlController.text.trim() : (_selectedProvince?['name'] ?? '');
    String ilce = _manualMode ? _manualIlceController.text.trim() : (_selectedDistrict?['name'] ?? '');
    String mahalleKoy = _manualMode 
        ? _manualMahalleController.text.trim() 
        : (_selectedNeighborhood?['name'] ?? _manualMahalleController.text.trim());

    if (il.isEmpty || ilce.isEmpty || mahalleKoy.isEmpty) {
      setState(() {
        _errorMessage = 'Lütfen İl, İlçe ve Mahalle/Köy bilgilerini eksiksiz girin.';
      });
      return;
    }

    try {
      await auth.registerUser(
        displayName: _nameController.text.trim(),
        il: il,
        ilce: ilce,
        mahalleKoy: mahalleKoy,
        adresDetay: _addressController.text.trim(),
        postaKodu: _zipController.text.trim(),
        email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
        firmaId: _selectedCompany?['id'],
        firmaName: _selectedCompany?['ad'],
        role: _selectedRole,
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 450),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w800),
                          children: const [
                            TextSpan(text: 'Süt', style: TextStyle(color: AppColors.primary600)),
                            TextSpan(text: 'App', style: TextStyle(color: AppColors.gray800)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Hesabınızı Tamamlayın',
                        style: GoogleFonts.inter(fontSize: 14, color: AppColors.gray600, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 20),

                      // Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppShadows.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Verified Phone Info
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.successLight,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AppColors.success.withOpacity(0.3)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle, color: AppColors.success, size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Doğrulanmış Numara: ${auth.verifiedPhone ?? 'Bilinmiyor'}',
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // User Role Selection Dropdown
                            DropdownButtonFormField<UserRole>(
                              value: _selectedRole,
                              decoration: InputDecoration(
                                labelText: 'Kullanıcı Rolü *',
                                prefixIcon: Icon(Icons.badge_outlined, size: 18, color: AppColors.gray400),
                              ),
                              items: const [
                                DropdownMenuItem(value: UserRole.uretici, child: Text('Süt Üreticisi')),
                                DropdownMenuItem(value: UserRole.surucu, child: Text('Toplayıcı')),
                                DropdownMenuItem(value: UserRole.firma, child: Text('Firma Yöneticisi')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _selectedRole = val;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),

                            // Name Surname Field
                            TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: InputDecoration(
                                labelText: 'Ad Soyad *',
                                hintText: 'Mehmet Yılmaz',
                                prefixIcon: Icon(Icons.person_outline, size: 18, color: AppColors.gray400),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Ad Soyad zorunludur' : null,
                            ),
                            const SizedBox(height: 12),

                            // E-mail Field
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'E-posta (Opsiyonel)',
                                hintText: 'ornek@posta.com',
                                prefixIcon: Icon(Icons.email_outlined, size: 18, color: AppColors.gray400),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Company Selection Field (Optional)
                            DropdownButtonFormField<Map<String, dynamic>>(
                              value: _selectedCompany,
                              hint: const Text('Bağlı olduğunuz firmayı seçin'),
                              decoration: InputDecoration(
                                labelText: 'Süt Toplama Firması (Opsiyonel)',
                                helperText: 'Daha sonra da belirleyebilirsiniz',
                                helperStyle: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                prefixIcon: Icon(Icons.business_outlined, size: 18, color: AppColors.gray400),
                              ),
                              items: _companiesList.map((comp) {
                                return DropdownMenuItem<Map<String, dynamic>>(
                                  value: comp,
                                  child: Text(comp['ad'] ?? ''),
                                );
                              }).toList(),
                              onChanged: _loadingCompanies ? null : (comp) {
                                setState(() {
                                  _selectedCompany = comp;
                                });
                              },
                            ),
                            const SizedBox(height: 12),

                            // Address Section Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Adres Bilgileri *',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray700),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _manualMode = !_manualMode;
                                    });
                                  },
                                  child: Text(
                                    _manualMode ? 'Listeden Seç' : 'Elle Yaz',
                                    style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary600),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            if (_loadingAddress) ...[
                              const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                            ],

                            if (!_manualMode) ...[
                              // Dropdown Mode
                              // İl Dropdown
                              DropdownButtonFormField<Map<String, dynamic>>(
                                value: _selectedProvince,
                                hint: const Text('İl Seçiniz'),
                                decoration: InputDecoration(
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
                                  });
                                  if (prov != null) {
                                    _loadDistricts(prov['id']);
                                  }
                                },
                                validator: (v) => v == null ? 'Lütfen il seçin' : null,
                              ),
                              const SizedBox(height: 12),

                              // İlçe Dropdown
                              DropdownButtonFormField<Map<String, dynamic>>(
                                value: _selectedDistrict,
                                hint: const Text('İlçe Seçiniz'),
                                decoration: InputDecoration(
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
                                  if (dist != null) {
                                    _loadNeighborhoods(dist['id']);
                                  }
                                },
                                validator: (v) => v == null ? 'Lütfen ilçe seçin' : null,
                              ),
                              const SizedBox(height: 12),

                              // Mahalle Dropdown or Text input fallback
                              _neighborhoods.isNotEmpty
                                  ? DropdownButtonFormField<Map<String, dynamic>>(
                                      value: _selectedNeighborhood,
                                      hint: const Text('Mahalle / Köy Seçiniz'),
                                      decoration: InputDecoration(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        prefixIcon: Icon(Icons.home_work_outlined, size: 18, color: AppColors.gray400),
                                      ),
                                      items: _neighborhoods.map((neigh) {
                                        return DropdownMenuItem<Map<String, dynamic>>(
                                          value: neigh,
                                          child: Text(
                                            neigh['name'],
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (_loadingAddress || _selectedDistrict == null) ? null : (neigh) {
                                        setState(() {
                                          _selectedNeighborhood = neigh;
                                        });
                                      },
                                      validator: (v) => v == null ? 'Lütfen mahalle/köy seçin' : null,
                                    )
                                  : TextFormField(
                                      controller: _manualMahalleController,
                                      textCapitalization: TextCapitalization.words,
                                      decoration: InputDecoration(
                                        labelText: 'Mahalle / Köy *',
                                        hintText: 'Yayla Köyü',
                                        prefixIcon: Icon(Icons.home_work_outlined, size: 18, color: AppColors.gray400),
                                      ),
                                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Mahalle/Köy zorunludur' : null,
                                    ),
                            ] else ...[
                              // Manual Text Entry Mode
                              TextFormField(
                                controller: _manualIlController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'İl *',
                                  hintText: 'Kayseri',
                                  prefixIcon: Icon(Icons.map_outlined, size: 18, color: AppColors.gray400),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'İl zorunludur' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _manualIlceController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'İlçe *',
                                  hintText: 'Kocasinan',
                                  prefixIcon: Icon(Icons.location_city_outlined, size: 18, color: AppColors.gray400),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'İlçe zorunludur' : null,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _manualMahalleController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  labelText: 'Mahalle / Köy *',
                                  hintText: 'Yayla Köyü',
                                  prefixIcon: Icon(Icons.home_work_outlined, size: 18, color: AppColors.gray400),
                                ),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Mahalle/Köy zorunludur' : null,
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Address Details Field
                            TextFormField(
                              controller: _addressController,
                              textCapitalization: TextCapitalization.sentences,
                              decoration: InputDecoration(
                                labelText: 'Adres Detayı',
                                hintText: 'Sokak, Kapı No, İç Kapı...',
                                prefixIcon: Icon(Icons.location_on_outlined, size: 18, color: AppColors.gray400),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Zip Code Field
                            TextFormField(
                              controller: _zipController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Posta Kodu',
                                hintText: '38000',
                                prefixIcon: Icon(Icons.local_post_office_outlined, size: 18, color: AppColors.gray400),
                              ),
                            ),

                            if (_errorMessage.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage,
                                style: GoogleFonts.inter(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500),
                                textAlign: TextAlign.center,
                              ),
                            ],

                            const SizedBox(height: 24),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: GestureDetector(
                                onTap: auth.loading ? null : () => _submit(auth),
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: AppColors.primaryGradient,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: AppShadows.blue,
                                  ),
                                  child: Center(
                                    child: auth.loading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            'Kaydı Tamamla',
                                            style: GoogleFonts.inter(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Logout/Cancel option
                            TextButton(
                              onPressed: auth.loading ? null : () => auth.logout(),
                              child: Text(
                                'Çıkış Yap',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
