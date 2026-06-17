import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/sut_analiz_dialog.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/location_picker_field.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SurucuDashboard extends StatefulWidget {
  final bool showSutAlDirectly;
  final String? initialUretici;

  const SurucuDashboard({
    super.key,
    this.showSutAlDirectly = false,
    this.initialUretici,
  });

  @override
  State<SurucuDashboard> createState() => _SurucuDashboardState();
}

class _SurucuDashboardState extends State<SurucuDashboard> {
  final _firestoreService = FirestoreService();
  final _miktarFormCtrl = TextEditingController();
  String? _selectedUreticiForm;
  String? _selectedMilkTypeForm;
  String? _selectedCustomerTypeForm;
  final List<String> _milkTypes = const ['Soğuk Süt', 'Sıcak Süt', 'C kalite', 'D kalite'];
  String? _selectedUreticiForSutAl;
  String? _selectedQualityForm;
  String? _selectedTankForm;
  String? _lastSelectedTank;
  String _searchQuery = '';
  bool _isSaving = false;

  Stream<QuerySnapshot>? _profileStream;
  Stream<QuerySnapshot>? _vehicleStream;
  Stream<QuerySnapshot>? _collectionsStream;
  Stream<QuerySnapshot>? _producersStream;
  Stream<DocumentSnapshot>? _savedRotaStream;
  // Gauge icin sabit toplamalar stream - her rebuild'de sifirlanmasin
  Stream<QuerySnapshot>? _toplamaGaugeStream;
  String? _toplamaGaugePlate;
  String? _cachedDriverName;
  String? _cachedEmail;
  String? _cachedFirma;

  static final Set<String> _shownPopups = {};

  @override
  void initState() {
    super.initState();
    _checkForPopUpAds();
    if (widget.initialUretici != null) {
      _selectedUreticiForSutAl = widget.initialUretici;
      _selectedUreticiForm = widget.initialUretici;
    }
  }

  void _checkForPopUpAds() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Kısa bekleme: ekran render olduktan sonra dialog gösterilsin
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      try {
        // Cache yerine doğrudan Firestore'dan çek
        final query = await FirebaseFirestore.instance
            .collection('duyurular')
            .where('isGlobal', isEqualTo: true)
            .where('isPopUp', isEqualTo: true)
            .get();

        final docs = query.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final targetRoles = data['targetRoles'] as List<dynamic>?;
          return targetRoles != null && targetRoles.contains('surucu');
        }).toList();

        if (docs.isEmpty) return;

        docs.sort((a, b) {
          final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });

        final doc = docs.first;
        final docId = doc.id;

        final prefs = await SharedPreferences.getInstance();
        final List<String> shownList = prefs.getStringList('shown_popups') ?? [];
        if (shownList.contains(docId)) return;

        shownList.add(docId);
        await prefs.setStringList('shown_popups', shownList);

        final data = doc.data() as Map<String, dynamic>?;
        final baslik = data?['baslik'] ?? '';
        final icerik = data?['icerik'] ?? '';
        final imageUrl = data?['imageUrl'] as String?;

        if (!mounted) return;

        showDialog(
          context: context,
          barrierDismissible: true,
          barrierColor: Colors.black54,
          builder: (ctx) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              title: Row(
                children: [
                  const Icon(Icons.campaign_rounded, color: Colors.blueAccent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      baslik,
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 200,
                              minWidth: double.infinity,
                            ),
                            child: imageUrl.startsWith('data:image')
                                ? Image.memory(
                                    base64Decode(imageUrl.contains(',') ? imageUrl.split(',').last : imageUrl),
                                    fit: BoxFit.cover,
                                    gaplessPlayback: true,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  )
                                : Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Text(
                        icerik,
                        style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray700),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('Kapat', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      } catch (e) {
        debugPrint('Pop-up hata: $e');
      }
    });
  }

  @override
  void dispose() {
    _miktarFormCtrl.dispose();
    super.dispose();
  }

  void _showAddProducerDialog(String currentFirmaName) {
    showDialog(
      context: context,
      builder: (ctx) {
        List<Map<String, dynamic>> provinces = [];
        List<Map<String, dynamic>> districts = [];
        List<Map<String, dynamic>> neighborhoods = [];
        Map<String, dynamic>? selectedProvince;
        Map<String, dynamic>? selectedDistrict;
        Map<String, dynamic>? selectedNeighborhood;
        String selectedMilkType = 'Soğuk Süt';
        bool isYem = false;
        bool loading = false;

        final nameCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final manualMahalleCtrl = TextEditingController();
        final latCtrl = TextEditingController();
        final lngCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> loadProvinces() async {
              setState(() => loading = true);
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
                      provinces = list;
                    });
                  }
                }
              } catch (e) {
                print(e);
              } finally {
                client.close();
                setState(() => loading = false);
              }
            }

            Future<void> loadDistricts(int provinceId) async {
              setState(() {
                loading = true;
                districts = [];
                neighborhoods = [];
                selectedDistrict = null;
                selectedNeighborhood = null;
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
                      districts = list;
                    });
                  }
                }
              } catch (e) {
                print(e);
              } finally {
                client.close();
                setState(() => loading = false);
              }
            }

            Future<void> loadNeighborhoods(int districtId) async {
              setState(() {
                loading = true;
                neighborhoods = [];
                selectedNeighborhood = null;
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
                      neighborhoods = list;
                    });
                  }
                }
              } catch (e) {
                print(e);
              } finally {
                client.close();
                setState(() => loading = false);
              }
            }

            if (provinces.isEmpty && !loading) {
              Future.microtask(() => loadProvinces());
            }

            return AlertDialog(
              title: Text('Yeni Üretici Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Ad Soyad', hintText: 'Mustafa Yılmaz'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        maxLength: 11,
                        decoration: const InputDecoration(
                          labelText: 'Telefon',
                          hintText: '0532 999 8877',
                          counterText: '',
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (loading && provinces.isEmpty)
                        const Center(child: CircularProgressIndicator())
                      else ...[
                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: selectedProvince,
                          hint: const Text('İl Seçiniz'),
                          decoration: const InputDecoration(
                            labelText: 'İl *',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: provinces.map((prov) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: prov,
                              child: Text(prov['name']),
                            );
                          }).toList(),
                          onChanged: loading ? null : (prov) {
                            setState(() {
                              selectedProvince = prov;
                            });
                            if (prov != null) {
                              loadDistricts(prov['id']);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        DropdownButtonFormField<Map<String, dynamic>>(
                          value: selectedDistrict,
                          hint: const Text('İlçe Seçiniz'),
                          decoration: const InputDecoration(
                            labelText: 'İlçe *',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: districts.map((dist) {
                            return DropdownMenuItem<Map<String, dynamic>>(
                              value: dist,
                              child: Text(dist['name']),
                            );
                          }).toList(),
                          onChanged: (loading || selectedProvince == null) ? null : (dist) {
                            setState(() {
                              selectedDistrict = dist;
                            });
                            if (dist != null) {
                              loadNeighborhoods(dist['id']);
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        neighborhoods.isNotEmpty
                            ? DropdownButtonFormField<Map<String, dynamic>>(
                                value: selectedNeighborhood,
                                hint: const Text('Mahalle / Köy Seçiniz'),
                                decoration: const InputDecoration(
                                  labelText: 'Mahalle / Köy *',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: neighborhoods.map((neigh) {
                                  return DropdownMenuItem<Map<String, dynamic>>(
                                    value: neigh,
                                    child: Text(neigh['name'], overflow: TextOverflow.ellipsis),
                                  );
                                }).toList(),
                                onChanged: (loading || selectedDistrict == null) ? null : (neigh) {
                                  setState(() {
                                    selectedNeighborhood = neigh;
                                  });
                                },
                              )
                            : TextField(
                                controller: manualMahalleCtrl,
                                decoration: const InputDecoration(labelText: 'Mahalle / Köy', hintText: 'Akarsu Köyü'),
                              ),
                        const SizedBox(height: 16),
                      ],

                      // Location picker
                      LocationPickerField(
                        latController: latCtrl,
                        lngController: lngCtrl,
                        setDialogState: setState,
                      ),
                      const SizedBox(height: 24),

                      // Custom selector
                      _buildMilkTypeSelector(
                        selectedType: selectedMilkType,
                        onChanged: (val) => setState(() => selectedMilkType = val),
                        enabled: !isYem,
                      ),
                      const SizedBox(height: 16),
                      _buildCustomerTypeToggle(
                        isYem,
                        (val) => setState(() => isYem = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500))),
                ElevatedButton(
                  onPressed: () async {
                    final il = selectedProvince?['name'] ?? '';
                    final ilce = selectedDistrict?['name'] ?? '';
                    final mahalleKoy = selectedNeighborhood?['name'] ?? manualMahalleCtrl.text.trim();
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();

                    if (name.isEmpty || phone.isEmpty || il.isEmpty || ilce.isEmpty || mahalleKoy.isEmpty) return;

                    await _firestoreService.addProducer(
                      name: name,
                      phone: phone,
                      group: mahalleKoy,
                      bolge: ilce,
                      avg: 30.0,
                      firma: currentFirmaName,
                      lastMilkType: isYem ? 'Yok' : selectedMilkType,
                      customerType: isYem ? 'yem' : 'sut',
                      latitude: (double.tryParse(latCtrl.text.trim()) != null && double.tryParse(lngCtrl.text.trim()) != null)
                          ? double.tryParse(latCtrl.text.trim())
                          : null,
                      longitude: (double.tryParse(latCtrl.text.trim()) != null && double.tryParse(lngCtrl.text.trim()) != null)
                          ? double.tryParse(lngCtrl.text.trim())
                          : null,
                      mapsLink: (double.tryParse(latCtrl.text.trim()) == null || double.tryParse(lngCtrl.text.trim()) == null) && latCtrl.text.trim().isNotEmpty
                          ? latCtrl.text.trim()
                          : null,
                    );

                    // Send notification to the company (firma)
                    try {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final driverName = authProvider.user?.displayName ?? '';

                      await _firestoreService.sendNotification(
                        recipientName: currentFirmaName,
                        role: 'firma',
                        baslik: 'Yeni Üretici Eklendi',
                        icerik: '$driverName toplayıcısı yeni bir üretici ekledi: $name.',
                        type: 'sistem',
                      );
                    } catch (e) {
                      print('Bildirim gönderme hatası: $e');
                    }

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Yeni üretici başarıyla eklendi!'), backgroundColor: AppColors.success),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Ekle'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSutAlDialog(String plate, List<dynamic> tankList, String driverName, String firma, bool canAddCustomer) {
    final miktarCtrl = TextEditingController();
    String? localSelectedUretici;
    String? localSelectedMilkType;
    String? localSelectedCustomerType;
    const List<String> milkTypes = ['Soğuk Süt', 'Sıcak Süt', 'C kalite', 'D kalite'];
    
    // Track selected tank inside the dialog
    String? localSelectedTank;
    if (_lastSelectedTank != null && tankList.any((t) => (t as Map)['ad'] == _lastSelectedTank)) {
      localSelectedTank = _lastSelectedTank;
    } else {
      localSelectedTank = tankList.isNotEmpty ? (tankList.first as Map)['ad'] as String : null;
    }

    showDialog(
      context: context,
      builder: (ctx) => StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getProducersStream(firma: firma),
        builder: (context, prodSnapshot) {
          if (!prodSnapshot.hasData) {
            return const AlertDialog(
              content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            );
          }

          final producers = prodSnapshot.data!.docs.map((doc) => doc['name'] as String).toSet().toList();
          if (producers.isEmpty) {
            return const AlertDialog(
              content: Text('Sistemde kayıtlı üretici bulunamadı!'),
            );
          }

          String normalize(String? raw) {
            if (raw == null) return 'Soğuk Süt';
            final norm = raw.trim().toLowerCase();
            if (norm.contains('soğuk') || norm.contains('a kalite')) return 'Soğuk Süt';
            if (norm.contains('sıcak') || norm.contains('b kalite')) return 'Sıcak Süt';
            if (norm.contains('c kalite')) return 'C kalite';
            if (norm.contains('d kalite')) return 'D kalite';
            return 'Soğuk Süt';
          }

          if (localSelectedUretici == null || !producers.contains(localSelectedUretici)) {
            localSelectedUretici = producers.first;
            try {
              final prodDoc = prodSnapshot.data!.docs.firstWhere((doc) => doc['name'] == localSelectedUretici);
              final docData = prodDoc.data() as Map<String, dynamic>;
              localSelectedMilkType = normalize(docData['lastMilkType']);
              localSelectedCustomerType = docData['customerType'] ?? 'sut';
            } catch (_) {
              localSelectedMilkType = 'Soğuk Süt';
              localSelectedCustomerType = 'sut';
            }
          } else if (localSelectedCustomerType == null) {
            try {
              final prodDoc = prodSnapshot.data!.docs.firstWhere((doc) => doc['name'] == localSelectedUretici);
              final docData = prodDoc.data() as Map<String, dynamic>;
              localSelectedCustomerType = docData['customerType'] ?? 'sut';
            } catch (_) {
              localSelectedCustomerType = 'sut';
            }
          }

          if (localSelectedMilkType == null || !milkTypes.contains(localSelectedMilkType)) {
            localSelectedMilkType = 'Soğuk Süt';
          }

          return StatefulBuilder(
            builder: (context, setDialogState) {
              // Find selected tank info
              Map? selectedTankInfo;
              try {
                selectedTankInfo = tankList.firstWhere((t) => (t as Map)['ad'] == localSelectedTank);
              } catch (_) {}

              final double tCapacity = (selectedTankInfo?['kap'] as num?)?.toDouble() ?? 2000.0;
              final double tCurrentStock = (selectedTankInfo?['stok'] as num?)?.toDouble() ?? 0.0;

              return AlertDialog(
                title: Text('Süt Alım Kaydı', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        value: localSelectedUretici,
                        decoration: const InputDecoration(labelText: 'Üretici Seçin'),
                        items: producers
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              localSelectedUretici = val;
                              try {
                                final prodDoc = prodSnapshot.data!.docs.firstWhere((doc) => doc['name'] == localSelectedUretici);
                                final docData = prodDoc.data() as Map<String, dynamic>;
                                localSelectedMilkType = normalize(docData['lastMilkType']);
                                localSelectedCustomerType = docData['customerType'] ?? 'sut';
                              } catch (_) {
                                localSelectedMilkType = 'Soğuk Süt';
                                localSelectedCustomerType = 'sut';
                              }
                              if (localSelectedMilkType == null || !milkTypes.contains(localSelectedMilkType)) {
                                localSelectedMilkType = 'Soğuk Süt';
                              }
                            });
                          }
                        },
                      ),
                      if (canAddCustomer) ...[
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            icon: const Icon(Icons.person_add_alt_1_rounded, size: 16, color: AppColors.primary600),
                            label: Text('Yeni Üretici Ekle', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary600)),
                            onPressed: () => _showAddProducerDialog(firma),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      // Tank Dropdown if driver has multiple tanks
                      if (tankList.length > 1) ...[
                        DropdownButtonFormField<String>(
                          value: localSelectedTank,
                          decoration: const InputDecoration(labelText: 'Araç Tankı'),
                          items: tankList
                              .map((t) => DropdownMenuItem(value: (t as Map)['ad'] as String, child: Text(t['ad'] as String)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                    localSelectedTank = val;
                                    _lastSelectedTank = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildMilkTypeSelector(
                        selectedType: localSelectedMilkType ?? 'Soğuk Süt',
                        onChanged: (val) => setDialogState(() => localSelectedMilkType = val),
                        enabled: localSelectedCustomerType != 'yem',
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: localSelectedCustomerType,
                        decoration: InputDecoration(
                          labelText: 'Üretici Türü',
                          fillColor: localSelectedCustomerType == 'yem' ? Colors.amber[50] : AppColors.gray50,
                          filled: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'sut', child: Text('Süt Üreticisi')),
                          DropdownMenuItem(value: 'yem', child: Text('Yem Müşterisi')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              localSelectedCustomerType = val;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: miktarCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Miktar (Litre)',
                          hintText: 'Örn: 50',
                          suffixText: 'LT',
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            if (localSelectedUretici != null) {
                              SutAnalizDialog.show(
                                context,
                                targetName: localSelectedUretici!,
                                tip: 'Üretici',
                              );
                            }
                          },
                          icon: const Icon(Icons.science_rounded, size: 16),
                          label: Text(
                            'Analiz Ekle',
                            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primary600),
                            foregroundColor: AppColors.primary600,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500))),
                  ElevatedButton(
                    onPressed: () async {
                      final double? miktar = double.tryParse(miktarCtrl.text.replaceAll(',', '.'));
                      if (miktar == null || miktar <= 0) return;

                      final bool isOverflow = tCurrentStock + miktar > tCapacity;

                      // Get producer region
                      String region = 'Merkez';
                      try {
                        final prodDoc = prodSnapshot.data!.docs.firstWhere((doc) => doc['name'] == localSelectedUretici);
                        region = prodDoc['group'] ?? 'Merkez';
                      } catch (_) {}

                      // Run in background without awaiting to prevent UI hang when offline
                      _firestoreService.recordMilkCollection(
                        producerName: localSelectedUretici!,
                        tankName: localSelectedTank!,
                        miktar: miktar,
                        driverName: driverName,
                        vehiclePlate: plate,
                        region: region,
                        sutTipi: localSelectedMilkType ?? 'Soğuk Süt',
                        customerType: localSelectedCustomerType ?? 'sut',
                      );

                      _lastSelectedTank = localSelectedTank;
                      Navigator.pop(ctx);
                      if (isOverflow) {
                        _showLimitExceededDialog(context, localSelectedTank!);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$localSelectedUretici üreticisinden ${miktar.toStringAsFixed(0)} LT süt alındı! Tank güncellendi.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Süt Al'),
                  ),
                ],
              );
            }
          );
        }
      ),
    );
  }

  Widget _buildMilkTypeSelector({
    required String selectedType,
    required ValueChanged<String> onChanged,
    bool enabled = true,
  }) {
    final norm = selectedType.trim().toLowerCase();
    bool isSicak = norm.contains('sıcak') || norm.contains('b kalite') || norm.contains('b quality');
    bool isSoguk = norm.contains('soğuk') || norm.contains('a kalite') || norm.contains('a quality');
    bool isC = norm.contains('c kalite');
    bool isD = norm.contains('d kalite');
    bool isToggleActive = isSicak || isSoguk;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Varsayılan Süt Sıcaklığı / Kalitesi',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                if (isToggleActive)
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOut,
                    alignment: isSicak ? Alignment.centerLeft : Alignment.centerRight,
                    child: FractionallySizedBox(
                      widthFactor: 0.5,
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSicak ? Colors.red[600] : Colors.blue[600],
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: (isSicak ? Colors.red : Colors.blue).withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 3),
                              )
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isSicak ? Icons.whatshot : Icons.ac_unit,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isSicak ? 'Sıcak Süt' : 'Soğuk Süt',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: enabled ? () => onChanged('Sıcak Süt') : null,
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            'Sıcak Süt',
                            style: GoogleFonts.inter(
                              color: isSicak ? Colors.transparent : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: enabled ? () => onChanged('Soğuk Süt') : null,
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: Text(
                            'Soğuk Süt',
                            style: GoogleFonts.inter(
                              color: isSoguk ? Colors.transparent : Colors.grey[600],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: InkWell(
                  onTap: enabled ? () => onChanged(isC ? 'Soğuk Süt' : 'C kalite') : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isC ? Colors.teal[50] : Colors.transparent,
                      border: Border.all(
                        color: isC ? Colors.teal[600]! : Colors.grey[300]!,
                        width: isC ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isC ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isC ? Colors.teal[600] : Colors.grey[500],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'C Kalite',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isC ? Colors.teal[800] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: InkWell(
                  onTap: enabled ? () => onChanged(isD ? 'Soğuk Süt' : 'D kalite') : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isD ? Colors.orange[50] : Colors.transparent,
                      border: Border.all(
                        color: isD ? Colors.orange[600]! : Colors.grey[300]!,
                        width: isD ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isD ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                          color: isD ? Colors.orange[600] : Colors.grey[500],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'D Kalite',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isD ? Colors.orange[800] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCustomerTypeToggle(bool isYem, ValueChanged<bool> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Üretici Türü',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            onChanged(!isYem);
          },
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: isYem ? Alignment.centerRight : Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isYem ? Colors.amber[600] : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: (isYem ? Colors.amber : Colors.grey).withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ],
                          border: isYem ? null : Border.all(color: Colors.grey[300]!, width: 0.5),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                isYem ? Icons.grass_rounded : Icons.water_drop_rounded,
                                color: isYem ? Colors.white : AppColors.primary600,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isYem ? 'Yem Müşterisi' : 'Süt Üreticisi',
                                style: GoogleFonts.inter(
                                  color: isYem ? Colors.white : AppColors.primary800,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Center(
                        child: Text(
                          'Süt Üreticisi',
                          style: GoogleFonts.inter(
                            color: !isYem ? Colors.transparent : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Yem Müşterisi',
                          style: GoogleFonts.inter(
                            color: isYem ? Colors.transparent : Colors.grey[600],
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<bool> _checkYesterdayEmptyStatus(String driverName, String plate) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final dateStr = DateFormat('dd.MM.yyyy').format(yesterday);

    // Use cache-first approach with a short server fallback timeout
    Future<QuerySnapshot> fetchWithCacheFallback(Query q) async {
      try {
        final snap = await q.get(const GetOptions(source: Source.cache));
        if (snap.docs.isNotEmpty) return snap;
      } catch (_) {}
      try {
        return await q
            .get(const GetOptions(source: Source.server))
            .timeout(const Duration(seconds: 3));
      } catch (_) {
        return q.get(const GetOptions(source: Source.cache));
      }
    }

    final collectionsQuery = await fetchWithCacheFallback(
      FirebaseFirestore.instance
          .collection('toplamalar')
          .where('sr', isEqualTo: driverName)
          .where('tarih', isEqualTo: dateStr)
          .limit(1),
    );

    if (collectionsQuery.docs.isEmpty) {
      return true;
    }

    final deliveriesQuery = await fetchWithCacheFallback(
      FirebaseFirestore.instance
          .collection('teslimatlar')
          .where('plaka', isEqualTo: plate)
          .where('tarih', isEqualTo: dateStr)
          .limit(1),
    );

    return deliveriesQuery.docs.isNotEmpty;
  }

  Widget _buildYesterdayWarning() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dün Süt Boşaltımı Yapmadınız!',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF991B1B),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Bir gün öncenin tankındaki süt sistemde merkez tanka boşaltılmamıştır.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF7F1D1D),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final driverName = authProvider.user?.displayName ?? '';
    final userEmail = authProvider.user?.email ?? '';
    print('[Dashboard] auth displayName="${authProvider.user?.displayName}", driverName="$driverName", email="$userEmail"');

    if (_cachedEmail != userEmail || _profileStream == null) {
      _cachedEmail = userEmail;
      _profileStream = FirebaseFirestore.instance
          .collection('suruculer')
          .where('firma', isEqualTo: authProvider.currentFirma)
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _profileStream!,
      builder: (context, profileSnapshot) {
        bool canAddCustomer = true;
        bool canEditCustomer = true;
        bool canCreateOrder = true;
        String resolvedDriverName = driverName;

        if (profileSnapshot.hasData && profileSnapshot.data!.docs.isNotEmpty) {
          final docs = profileSnapshot.data!.docs;
          DocumentSnapshot? matchedDoc;
          
          // Pass 1: Try to match by name first (highest priority)
          if (driverName.isNotEmpty) {
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final ad = data['ad'] ?? '';
              final soyad = data['soyad'] ?? '';
              final fullName = '$ad $soyad'.trim();
              if (fullName.toLowerCase() == driverName.toLowerCase()) {
                matchedDoc = doc;
                break;
              }
            }
          }

          // Pass 2: If no name match, try email match
          if (matchedDoc == null && userEmail.isNotEmpty) {
            for (var doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final email = data['email'] ?? '';
              if (email.isNotEmpty && email == userEmail) {
                matchedDoc = doc;
                break;
              }
            }
          }

          if (matchedDoc != null) {
            final pData = matchedDoc.data() as Map<String, dynamic>;
            canAddCustomer = pData['canAddCustomer'] ?? true;
            canEditCustomer = pData['canEditCustomer'] ?? true;
            canCreateOrder = pData['canCreateOrder'] ?? true;
            // Only override resolvedDriverName if displayName was empty
            if (driverName.isEmpty) {
              final dbAd = pData['ad'] ?? '';
              final dbSoyad = pData['soyad'] ?? '';
              final dbFullName = '$dbAd $dbSoyad'.trim();
              if (dbFullName.isNotEmpty) {
                resolvedDriverName = dbFullName;
              }
            }
          }
        }

        if (_cachedDriverName != resolvedDriverName || _vehicleStream == null) {
          _cachedDriverName = resolvedDriverName;
          _vehicleStream = _firestoreService.getDriverVehicleStream(resolvedDriverName, firma: authProvider.currentFirma);
          _savedRotaStream = FirebaseFirestore.instance
              .collection('surucu_rota_siralamalari')
              .doc(resolvedDriverName)
              .snapshots();
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _vehicleStream!,
          builder: (context, vehicleSnapshot) {
        if (vehicleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final vehicleDocs = vehicleSnapshot.data?.docs ?? [];
        final bool hasVehicle = vehicleDocs.isNotEmpty;
        
        bool hasTank = false;
        String plate = '';
        List<Map<String, dynamic>> tankList = [];
        String currentFirmaName = '';
        
        if (hasVehicle) {
          final vehicleDoc = vehicleDocs.first;
          final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
          plate = vehicleData['plaka'] ?? '';
          final rawTankList = vehicleData['tanklar'] as List? ?? [];
          
          tankList = List<Map<String, dynamic>>.from(rawTankList);
          hasTank = tankList.isNotEmpty;
          currentFirmaName = vehicleData['firma'] ?? '';
        }
        
        if (!hasVehicle || !hasTank) {
          String mainMessage = '';
          String subMessage = '';
          IconData icon = Icons.warning_amber_rounded;
          
          if (!hasVehicle && !hasTank) {
            mainMessage = 'Araç ve Tank Atanmadı!';
            subMessage = 'Sistemi kullanabilmek için yönetici tarafından üzerinize araç ve tank ataması yapılması gerekmektedir.';
            icon = Icons.local_shipping_outlined;
          } else if (!hasVehicle) {
            mainMessage = 'Araç Atanmadı!';
            subMessage = 'Sistemi kullanabilmek için yönetici tarafından üzerinize araç ataması yapılması gerekmektedir.';
            icon = Icons.local_shipping_outlined;
          } else {
            mainMessage = 'Tank Atanmadı!';
            subMessage = 'Sistemi kullanabilmek için yönetici tarafından aracınıza ($plate) tank ataması yapılması gerekmektedir.';
            icon = Icons.propane_tank_rounded;
          }
          
          return Scaffold(
            backgroundColor: AppColors.gray50,
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 64, color: AppColors.gray400),
                    const SizedBox(height: 16),
                    Text(
                      mainMessage,
                      style: GoogleFonts.inter(fontSize: 16, color: AppColors.gray600, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subMessage,
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final tank = tankList.first;
        final tankName = tank['ad'] ?? '';
        final double currentStock = (tank['stok'] as num?)?.toDouble() ?? 0.0;
        final double capacity = (tank['kap'] as num?)?.toDouble() ?? 2000.0;

        return Scaffold(
          backgroundColor: AppColors.gray50,
          floatingActionButton: (widget.showSutAlDirectly && _selectedUreticiForSutAl == null)
              ? FloatingActionButton.extended(
                  onPressed: () {
                    setState(() {
                      _selectedUreticiForSutAl = "";
                      _selectedUreticiForm = null;
                      _miktarFormCtrl.clear();
                    });
                  },
                  heroTag: 'sut_al_fab',
                  backgroundColor: AppColors.primary600,
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  label: Text(
                    'Süt Al',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                )
              : null,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;
              final isTablet = constraints.maxWidth >= 640 && constraints.maxWidth < 1024;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  // Header
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('firmalar')
                        .where('ad', isEqualTo: currentFirmaName)
                        .limit(1)
                        .snapshots(),
                    builder: (context, companySnap) {
                      String? logoUrl;
                      if (companySnap.hasData && companySnap.data!.docs.isNotEmpty) {
                        final companyData = companySnap.data!.docs.first.data() as Map<String, dynamic>;
                        logoUrl = companyData['logoUrl'] as String?;
                      }

                      final isMobile = constraints.maxWidth < 640;
                      if (isMobile) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.showSutAlDirectly ? 'Süt Alım Formu' : 'Toplayıcı Paneli',
                                        style: GoogleFonts.inter(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.gray900),
                                      ),
                                      if (resolvedDriverName.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          resolvedDriverName,
                                          style: GoogleFonts.inter(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary600,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 70,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: AppColors.gray200, width: 1.5),
                                        color: Colors.white,
                                        image: logoUrl != null && logoUrl.isNotEmpty
                                            ? DecorationImage(
                                                image: logoUrl.startsWith('data:image')
                                                    ? MemoryImage(base64Decode(logoUrl.substring(logoUrl.indexOf(',') + 1))) as ImageProvider
                                                    : NetworkImage(logoUrl),
                                                fit: BoxFit.cover,
                                              )
                                            : null,
                                      ),
                                      child: logoUrl == null || logoUrl.isEmpty
                                          ? Center(
                                              child: Icon(Icons.business_rounded, color: AppColors.gray400, size: 28),
                                            )
                                          : null,
                                    ),
                                    if (currentFirmaName.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 80,
                                        child: Text(
                                          currentFirmaName,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.gray800,
                                            height: 1.1,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            if (widget.showSutAlDirectly) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Üreticiden aldığınız süt miktarını girerek tank stoğuna ekleyin.',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppColors.gray500,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                            if (canAddCustomer) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _showAddProducerDialog(currentFirmaName),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                  label: Text(
                                    'Üretici Ekle',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    elevation: 0,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.showSutAlDirectly ? 'Süt Alım Formu' : 'Toplayıcı Paneli',
                                  style: GoogleFonts.inter(
                                      fontSize: isDesktop ? 22 : 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.gray900),
                                ),
                                if (resolvedDriverName.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    resolvedDriverName,
                                    style: GoogleFonts.inter(
                                      fontSize: isDesktop ? 14 : 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primary600,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Right side action (Üretici Ekle) and logo + name
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (canAddCustomer) ...[
                                ElevatedButton.icon(
                                  onPressed: () => _showAddProducerDialog(currentFirmaName),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                                  label: Text(
                                    'Üretici Ekle',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],

                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.gray200, width: 1.5),
                                      color: Colors.white,
                                      image: logoUrl != null && logoUrl.isNotEmpty
                                          ? DecorationImage(
                                              image: logoUrl.startsWith('data:image')
                                                  ? MemoryImage(base64Decode(logoUrl.substring(logoUrl.indexOf(',') + 1))) as ImageProvider
                                                  : NetworkImage(logoUrl),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                    ),
                                    child: logoUrl == null || logoUrl.isEmpty
                                        ? Center(
                                            child: Icon(Icons.business_rounded, color: AppColors.gray400, size: 32),
                                          )
                                        : null,
                                  ),
                                  if (currentFirmaName.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    SizedBox(
                                      width: 90,
                                      child: Text(
                                        currentFirmaName,
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gray800,
                                          height: 1.1,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<bool>(
                    future: _checkYesterdayEmptyStatus(resolvedDriverName, plate),
                    builder: (context, emptySnapshot) {
                      if (emptySnapshot.hasData && emptySnapshot.data == false) {
                        return _buildYesterdayWarning();
                      }
                      return const SizedBox.shrink();
                    },
                  ),

                  Column(
                    children: [
                      if (!widget.showSutAlDirectly) ...[
                        _buildQuickActionsGrid(
                          context,
                          plate,
                          tankList.isNotEmpty ? (tankList.first['ad'] as String? ?? '') : '',
                        ),
                        const SizedBox(height: 24),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Tank Durumu',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildResponsiveLayout(isDesktop, isTablet, plate, resolvedDriverName, tankList, currentFirmaName),
                      ] else ...[
                        _buildSutAlFormView(isDesktop, plate, tankName, currentStock, capacity, resolvedDriverName, currentFirmaName, canAddCustomer, tankList),
                      ],
                    ],
                  ),
                  const SizedBox(height: 80),
                ],
              );
            },
          ),
        );
      },
    );
  },
);
}

  Widget _buildSutAlFormView(
    bool isDesktop,
    String plate,
    String tankName,
    double currentStock,
    double capacity,
    String driverName,
    String firma,
    bool canAddCustomer,
    List<dynamic> tankList,
  ) {
    if (_selectedUreticiForSutAl == null) {
      return _buildMusteriZiyaretListesi(driverName, firma, canAddCustomer);
    } else {
      return _buildCustomSutGirisiForm(plate, tankName, currentStock, capacity, driverName, firma, canAddCustomer, tankList);
    }
  }

  Widget _buildNoAssignmentState() {
    return Column(
      children: [
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(24),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.gray200),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_off_rounded, color: Color(0xFFF59E0B), size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Atanmış Üretici Yok',
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
              ),
              const SizedBox(height: 8),
              Text(
                'Henüz size üretici ataması yapılmamış.\nFirma yöneticinizden atama yapmasını isteyiniz.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500, height: 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Cached streams for _buildMusteriZiyaretListesi
  String? _cachedAtamalarDriver;
  String? _cachedAtamalarFirma;
  Stream<QuerySnapshot>? _atamalarStream;

  String normalizeTurkish(String text) {
    return text
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('â', 'a')
        .replaceAll('î', 'i')
        .replaceAll('û', 'u')
        .trim();
  }

  List<String> getNameVariations(String name) {
    final cleanName = name.trim();
    final Set<String> variations = {cleanName, cleanName.toLowerCase(), cleanName.toUpperCase()};
    
    final parts = cleanName.split(' ');
    final titleCase = parts.map((p) {
      if (p.isEmpty) return p;
      return p[0].toUpperCase() + p.substring(1).toLowerCase();
    }).join(' ');
    variations.add(titleCase);

    String trToLower(String text) {
      return text.toLowerCase()
          .replaceAll('I', 'ı')
          .replaceAll('İ', 'i')
          .replaceAll('Ğ', 'ğ')
          .replaceAll('Ü', 'ü')
          .replaceAll('Ş', 'ş')
          .replaceAll('Ö', 'ö')
          .replaceAll('Ç', 'ç');
    }
    
    String trToUpper(String text) {
      return text.toUpperCase()
          .replaceAll('i', 'İ')
          .replaceAll('ı', 'I')
          .replaceAll('ğ', 'Ğ')
          .replaceAll('ü', 'Ü')
          .replaceAll('ş', 'Ş')
          .replaceAll('ö', 'Ö')
          .replaceAll('ç', 'Ç');
    }

    String replaceTurkishChars(String text) {
      return text
          .replaceAll('ı', 'i')
          .replaceAll('ğ', 'g')
          .replaceAll('ü', 'u')
          .replaceAll('ş', 's')
          .replaceAll('ö', 'o')
          .replaceAll('ç', 'c')
          .replaceAll('Ğ', 'G')
          .replaceAll('Ü', 'U')
          .replaceAll('Ş', 'S')
          .replaceAll('Ö', 'O')
          .replaceAll('Ç', 'C');
    }

    final lowerTr = trToLower(cleanName);
    final upperTr = trToUpper(cleanName);
    variations.addAll([lowerTr, upperTr]);

    final titleTr = parts.map((p) {
      if (p.isEmpty) return p;
      final lower = trToLower(p);
      return lower[0].toUpperCase() + lower.substring(1);
    }).join(' ');
    variations.add(titleTr);

    final engName = replaceTurkishChars(cleanName);
    variations.addAll([
      engName,
      engName.toLowerCase(),
      engName.toUpperCase(),
      parts.map((p) => replaceTurkishChars(p)).map((p) {
        if (p.isEmpty) return p;
        return p[0].toUpperCase() + p.substring(1).toLowerCase();
      }).join(' ')
    ]);

    return variations.toList();
  }

  Widget _buildMusteriZiyaretListesi(String driverName, String firma, bool canAddCustomer) {
    if (_cachedDriverName != driverName || _collectionsStream == null) {
      _cachedDriverName = driverName;
      _collectionsStream = _firestoreService.getDriverCollectionsStream(driverName);
    }
    if (_cachedFirma != firma || _producersStream == null) {
      _cachedFirma = firma;
      _producersStream = _firestoreService.getProducersStream(firma: firma);
    }
    if (_cachedAtamalarDriver != driverName || _cachedAtamalarFirma != firma || _atamalarStream == null) {
      _cachedAtamalarDriver = driverName;
      _cachedAtamalarFirma = firma;
      _atamalarStream = FirebaseFirestore.instance
          .collection('toplayici_atamalari')
          .where('toplayici', isEqualTo: driverName)
          .where('firma', isEqualTo: firma)
          .snapshots();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: _atamalarStream!,
      builder: (context, atamalarSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _collectionsStream!,
          builder: (context, collectionsSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: _producersStream!,
              builder: (context, producersSnapshot) {
                if (!producersSnapshot.hasData || !collectionsSnapshot.hasData || !atamalarSnapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }

                final producersDocs = producersSnapshot.data!.docs;
                final collectionsDocs = collectionsSnapshot.data!.docs;
                final atamalarDocs = atamalarSnapshot.data!.docs;


                // Separate direct-name assignments from group/birlik ones.
                final List<String> assignedProducers = [];
                final List<String> assignedGroups = [];
                final List<String> assignedBirlikler = [];

                for (var doc in atamalarDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final hTip = data['hedefTip'];
                  final hAd = (data['hedefAd'] as String? ?? '').trim();
                  if (hAd.isEmpty) continue;
                  if (hTip == 'uretici') {
                    assignedProducers.add(hAd);
                  } else if (hTip == 'grup') {
                    assignedGroups.add(hAd);
                  } else if (hTip == 'birlik' || hTip == 'bolge') {
                    assignedBirlikler.add(hAd);
                  }
                }

                print('[ZiyaretListesi] driverName=$driverName, firma=$firma');
                print('[ZiyaretListesi] atamalarDocs.length=${atamalarDocs.length}');
                print('[ZiyaretListesi] assignedProducers=$assignedProducers');
                print('[ZiyaretListesi] assignedGroups=$assignedGroups');
                print('[ZiyaretListesi] assignedBirlikler=$assignedBirlikler');
                print('[ZiyaretListesi] producersDocs.length=${producersDocs.length}');

                // If there are NO assignments at all, show empty state
                if (assignedProducers.isEmpty && assignedGroups.isEmpty && assignedBirlikler.isEmpty) {
                  return _buildNoAssignmentState();
                }

                final assignedProducersNorm = assignedProducers.map((s) => normalizeTurkish(s)).toSet();
                final assignedGroupsNorm = assignedGroups.map((s) => normalizeTurkish(s)).toSet();
                final assignedBirliklerNorm = assignedBirlikler.map((s) => normalizeTurkish(s)).toSet();

                // Step 1: Filter the firma-stream producers by assignment
                final myProducers = producersDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = normalizeTurkish(data['name'] ?? '');
                  final group = normalizeTurkish(data['group'] ?? '');
                  final bolge = normalizeTurkish(data['bolge'] ?? '');
                  final birlik = normalizeTurkish(data['birlik'] ?? 'Yok');

                  return assignedProducersNorm.contains(name) ||
                      (assignedGroupsNorm.isNotEmpty && group.isNotEmpty && assignedGroupsNorm.contains(group)) ||
                      (assignedBirliklerNorm.isNotEmpty && bolge.isNotEmpty && assignedBirliklerNorm.contains(bolge)) ||
                      (assignedBirliklerNorm.isNotEmpty && birlik.isNotEmpty && birlik != 'yok' && assignedBirliklerNorm.contains(birlik));
                }).toList();

                print('[ZiyaretListesi] myProducers.length=${myProducers.length}');

                // Step 2: For directly-named producers NOT in the firma stream
                // (firmalar field mismatch), fetch them separately by name.
                final myProducerNamesNorm = myProducers
                    .map((d) => normalizeTurkish(((d.data() as Map<String, dynamic>)['name'] ?? '').toString()))
                    .toSet();
                final missingNames = assignedProducers
                    .where((n) => !myProducerNamesNorm.contains(normalizeTurkish(n)))
                    .toList();
                final queryNames = missingNames.expand((name) => getNameVariations(name)).toSet().toList();

                // Step 2 – fetch directly-named producers missing from the stream
                // (happens when their `firmalar` array doesn't include this firma)
                return FutureBuilder<QuerySnapshot?>(
                  future: queryNames.isEmpty
                      ? Future.value(null)
                      : _firestoreService.getQueryWithCachePriority(
                          FirebaseFirestore.instance
                              .collection('ureticiler')
                              .where('name', whereIn: queryNames.take(30).toList()),
                        ),
                  builder: (context, missingSnap) {
                    final allProducers = List<QueryDocumentSnapshot>.from(myProducers);
                    if (missingSnap.hasData && missingSnap.data != null) {
                      final already = allProducers
                          .map((d) => normalizeTurkish(((d.data() as Map)['name'] ?? '').toString()))
                          .toSet();
                      for (var doc in missingSnap.data!.docs) {
                        final n = normalizeTurkish(((doc.data() as Map)['name'] ?? '').toString());
                        if (!already.contains(n)) allProducers.add(doc);
                      }
                    }

                    print('[ZiyaretListesi] allProducers.length=${allProducers.length}');

                // Find who has been visited today, how much milk they gave, and who has pending writes
                final today = DateTime.now();
                final Map<String, double> todayMilkMap = {};
                final Set<String> pendingWriteProducers = {};
                final visitedProducersToday = collectionsDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final ts = data['timestamp'] as Timestamp?;
                  bool isToday = false;
                  if (ts != null) {
                    final date = ts.toDate();
                    isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                  } else {
                    final tarihStr = data['tarih'] as String?;
                    if (tarihStr != null) {
                      final todayStr = DateFormat('dd.MM.yyyy').format(today);
                      isToday = tarihStr == todayStr;
                    }
                  }
                  if (isToday) {
                    final String name = data['u'] ?? '';
                    final double mVal = (data['m'] as num?)?.toDouble() ?? 0.0;
                    todayMilkMap[name] = (todayMilkMap[name] ?? 0.0) + mVal;
                    // Track pending writes — offline kayıtlar henüz sunucuya ulaşmadı
                    if (doc.metadata.hasPendingWrites) {
                      pendingWriteProducers.add(name);
                    }
                  }
                  return isToday;
                }).map((doc) => (doc.data() as Map<String, dynamic>)['u'] as String).toSet();

                // Filter/Search producers
                final filteredProducers = allProducers.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final group = (data['group'] ?? '').toString().toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return name.contains(query) || group.contains(query);
                }).toList();

                final totalProducers = allProducers.length;
                final visitedProducersTodayNorm = visitedProducersToday.map((s) => normalizeTurkish(s)).toSet();
                final visitedCount = allProducers.where((doc) {
                  final name = normalizeTurkish((doc.data() as Map<String, dynamic>)['name'] ?? '');
                  return visitedProducersTodayNorm.contains(name);
                }).length;

                return StreamBuilder<DocumentSnapshot>(
                  stream: _savedRotaStream!,
                  builder: (context, rotaSnapshot) {
                    if (rotaSnapshot.hasData && rotaSnapshot.data!.exists) {
                      final rotaData = rotaSnapshot.data!.data() as Map<String, dynamic>?;
                      final List<dynamic>? orderedNames = rotaData?['sirali_ureticiler'] as List<dynamic>?;
                      if (orderedNames != null) {
                        filteredProducers.sort((a, b) {
                          final aName = (a.data() as Map)['name'] ?? '';
                          final bName = (b.data() as Map)['name'] ?? '';
                          int aIndex = orderedNames.indexOf(aName);
                          int bIndex = orderedNames.indexOf(bName);
                          if (aIndex == -1) aIndex = 999999;
                          if (bIndex == -1) bIndex = 999999;
                          return aIndex.compareTo(bIndex);
                        });
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header card with statistics and controls
                        AppCard(
                          shadow: AppShadows.sm,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Ziyaret İlerlemesi',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Bugün Tamamlanan: $visitedCount / $totalProducers',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.gray900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Search Bar
                        TextField(
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          decoration: InputDecoration(
                            hintText: 'Müşteri veya bölge ara...',
                            prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                            fillColor: Colors.white,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.gray200),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary500, width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Customer list
                        if (filteredProducers.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32.0),
                              child: Text(
                                'Aramanızla eşleşen müşteri bulunamadı.',
                                style: GoogleFonts.inter(color: AppColors.gray500),
                              ),
                            ),
                          )
                        else
                          ReorderableListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredProducers.length,
                            onReorder: (oldIndex, newIndex) async {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              setState(() {
                                final item = filteredProducers.removeAt(oldIndex);
                                filteredProducers.insert(newIndex, item);
                              });

                              final namesList = filteredProducers
                                  .map((doc) => (doc.data() as Map)['name'] as String)
                                  .toList();

                              await FirebaseFirestore.instance
                                  .collection('surucu_rota_siralamalari')
                                  .doc(driverName)
                                  .set({
                                'sirali_ureticiler': namesList,
                                'lastUpdated': FieldValue.serverTimestamp(),
                              });
                            },
                            itemBuilder: (context, index) {
                              final doc = filteredProducers[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final name = data['name'] ?? '';
                              final group = data['group'] ?? 'Bilinmeyen Bölge';
                              final double bugunVerilenSut = todayMilkMap[name] ?? 0.0;
                              final lastMilkType = data['lastMilkType'] ?? 'Soğuk Süt';
                              final hasBeenVisited = visitedProducersToday.contains(name);
                              final bool hasPendingWrite = pendingWriteProducers.contains(name);

                              return Container(
                                key: ValueKey(name),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: _buildProducerItemTile(
                                  name: name,
                                  group: group,
                                  bugunVerilenSut: bugunVerilenSut,
                                  lastMilkType: lastMilkType,
                                  hasBeenVisited: hasBeenVisited,
                                  hasPendingWrite: hasPendingWrite,
                                  onTap: hasBeenVisited
                                      ? null
                                      : () {
                                          if (!widget.showSutAlDirectly) {
                                            context.go('/surucu/toplama?uretici=${Uri.encodeComponent(name)}');
                                          } else {
                                            setState(() {
                                              _selectedUreticiForSutAl = name;
                                              _selectedUreticiForm = name;
                                              _selectedMilkTypeForm = lastMilkType;
                                              _selectedCustomerTypeForm = data['customerType'] ?? 'sut';
                                              
                                              final norm = lastMilkType.trim().toLowerCase();
                                              if (norm.contains('soğuk') || norm.contains('a kalite')) {
                                                _selectedQualityForm = 'Soğuk Süt';
                                              } else if (norm.contains('sıcak') || norm.contains('b kalite')) {
                                                _selectedQualityForm = 'Sıcak Süt';
                                              } else if (norm.contains('c kalite')) {
                                                _selectedQualityForm = 'C kalite';
                                              } else if (norm.contains('d kalite')) {
                                                _selectedQualityForm = 'D kalite';
                                              } else {
                                                _selectedQualityForm = 'Soğuk Süt';
                                              }
                                              
                                              _miktarFormCtrl.clear();
                                            });
                                          }
                                        },
                                ),
                              );
                            },
                          ),
                      ],
                    );
                  },
                );
              },
            );
          }, // closes FutureBuilder builder
        ); // closes FutureBuilder
          },
        );
      },
    );
  }

  Widget _buildProducerItemTile({
    required String name,
    required String group,
    required double bugunVerilenSut,
    required String lastMilkType,
    required bool hasBeenVisited,
    required VoidCallback? onTap,
    bool hasPendingWrite = false,
  }) {
    final norm = lastMilkType.trim().toLowerCase();
    final isSicak = norm.contains('sıcak') || norm.contains('b kalite') || norm.contains('b quality');
    final isSoguk = norm.contains('soğuk') || norm.contains('a kalite') || norm.contains('a quality');

    return Container(
      decoration: BoxDecoration(
        color: hasBeenVisited ? Colors.grey[50] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasBeenVisited ? AppColors.gray200 : AppColors.gray100,
          width: 1,
        ),
        boxShadow: hasBeenVisited
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Left Icon (Status indicator)
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: hasBeenVisited
                        ? Colors.grey[200]
                        : (isSicak
                            ? Colors.red[50]
                            : (isSoguk ? Colors.blue[50] : Colors.grey[100])),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: hasBeenVisited
                        ? Icon(Icons.check_rounded, color: Colors.grey[600], size: 20)
                        : Icon(
                            Icons.water_drop_rounded,
                            color: isSicak
                                ? Colors.red[600]
                                : (isSoguk ? Colors.blue[600] : Colors.grey[600]),
                            size: 20,
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Name & Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: hasBeenVisited ? Colors.grey[500] : AppColors.gray900,
                                decoration: hasBeenVisited ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          // Offline pending sync icon
                          if (hasPendingWrite) ...[
                            const SizedBox(width: 6),
                            Tooltip(
                              message: 'Yükleniyor... (Offline kayıt)',
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange[600]!),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$group • Bugün: ${bugunVerilenSut % 1 == 0 ? bugunVerilenSut.toStringAsFixed(0) : bugunVerilenSut.toStringAsFixed(1)} LT',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.gray500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                // Trailing Arrow or Action
                if (!hasBeenVisited)
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppColors.gray400,
                    size: 20,
                  )
                else
                  Text(
                    'Tamamlandı',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: Colors.grey[500],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCustomSutGirisiForm(
    String plate,
    String tankName,
    double currentStock,
    double capacity,
    String driverName,
    String firma,
    bool canAddCustomer,
    List<dynamic> tankList,
  ) {
    // Determine vehicle tanks list
    final List<String> tanks = tankList.map((t) => (t as Map)['ad'] as String).toList();
    if (_selectedTankForm == null || !tanks.contains(_selectedTankForm)) {
      if (_lastSelectedTank != null && tanks.contains(_lastSelectedTank)) {
        _selectedTankForm = _lastSelectedTank;
      } else {
        _selectedTankForm = tanks.isNotEmpty ? tanks.first : tankName;
      }
    }

    final qualities = const ['Soğuk Süt', 'Sıcak Süt', 'C kalite', 'D kalite'];
    if (_selectedQualityForm == null || !qualities.contains(_selectedQualityForm)) {
      _selectedQualityForm = qualities.first;
    }

    // Dynamic tank level preview calculation
    Map? selectedTankInfo;
    try {
      selectedTankInfo = tankList.firstWhere((t) => t['ad'] == _selectedTankForm);
    } catch (_) {}

    final double tCapacity = (selectedTankInfo?['kap'] as num?)?.toDouble() ?? capacity;
    final double tCurrentStock = (selectedTankInfo?['stok'] as num?)?.toDouble() ?? currentStock;

    final double enteredMiktar = double.tryParse(_miktarFormCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final double previewStock = tCurrentStock + enteredMiktar;
    final double previewPct = (previewStock / tCapacity).clamp(0.0, 1.0);
    final bool previewOverflow = previewStock > tCapacity;

    final String todayDateStr = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(DateTime.now());

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: AppCard(
          shadow: AppShadows.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Header row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _selectedUreticiForSutAl = null),
                    icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primary600, size: 16),
                    label: Text(
                      'Geri',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary600, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _selectedUreticiForSutAl == "" ? 'Genel Süt Alımı' : _selectedUreticiForSutAl!,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray900),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveCustomSutGirisi(plate, tankName, currentStock, capacity, driverName, firma, tankList),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Kaydet',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1, color: AppColors.gray200),

              if (_selectedUreticiForSutAl == "") ...[
                StreamBuilder<QuerySnapshot>(
                  stream: _firestoreService.getProducersStream(firma: firma),
                  builder: (context, prodSnapshot) {
                    if (!prodSnapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final producers = prodSnapshot.data!.docs
                        .map((doc) => doc['name'] as String)
                        .toSet()
                        .toList();
                    if (producers.isEmpty) {
                      return const Text('Sistemde kayıtlı üretici bulunamadı!');
                    }

                    if (_selectedUreticiForm == null || !producers.contains(_selectedUreticiForm)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _selectedUreticiForm = producers.first;
                            try {
                              final prodDoc = prodSnapshot.data!.docs.firstWhere((doc) => doc['name'] == _selectedUreticiForm);
                              final docData = prodDoc.data() as Map<String, dynamic>;
                              final rawMilkType = docData['lastMilkType'] ?? 'Soğuk Süt';
                              final norm = rawMilkType.trim().toLowerCase();
                              if (norm.contains('soğuk') || norm.contains('a kalite')) {
                                _selectedQualityForm = 'Soğuk Süt';
                              } else if (norm.contains('sıcak') || norm.contains('b kalite')) {
                                _selectedQualityForm = 'Sıcak Süt';
                              } else if (norm.contains('c kalite')) {
                                _selectedQualityForm = 'C kalite';
                              } else if (norm.contains('d kalite')) {
                                _selectedQualityForm = 'D kalite';
                              } else {
                                _selectedQualityForm = 'Soğuk Süt';
                              }
                              _selectedCustomerTypeForm = docData['customerType'] ?? 'sut';
                            } catch (_) {
                              _selectedQualityForm = 'Soğuk Süt';
                              _selectedCustomerTypeForm = 'sut';
                            }
                          });
                        }
                      });
                      return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
                    }

                    return DropdownButtonFormField<String>(
                      value: _selectedUreticiForm,
                      decoration: const InputDecoration(
                        labelText: 'Üretici Seçin *',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: producers
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedUreticiForm = val;
                            try {
                              final prodDoc = prodSnapshot.data!.docs.firstWhere((doc) => doc['name'] == _selectedUreticiForm);
                              final docData = prodDoc.data() as Map<String, dynamic>;
                              final rawMilkType = docData['lastMilkType'] ?? 'Soğuk Süt';
                              final norm = rawMilkType.trim().toLowerCase();
                              if (norm.contains('soğuk') || norm.contains('a kalite')) {
                                _selectedQualityForm = 'Soğuk Süt';
                              } else if (norm.contains('sıcak') || norm.contains('b kalite')) {
                                _selectedQualityForm = 'Sıcak Süt';
                              } else if (norm.contains('c kalite')) {
                                _selectedQualityForm = 'C kalite';
                              } else if (norm.contains('d kalite')) {
                                _selectedQualityForm = 'D kalite';
                              } else {
                                _selectedQualityForm = 'Soğuk Süt';
                              }
                              _selectedCustomerTypeForm = docData['customerType'] ?? 'sut';
                            } catch (_) {
                              _selectedQualityForm = 'Soğuk Süt';
                              _selectedCustomerTypeForm = 'sut';
                            }
                          });
                        }
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Date read-only container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.gray500),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tarih',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.gray400),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          todayDateStr,
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.gray800),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const SizedBox(height: 0),

              // Litre Input
              TextField(
                controller: _miktarFormCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                decoration: const InputDecoration(
                  labelText: 'Miktar (Litre)',
                  hintText: '0.00',
                  suffixText: 'LT',
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
              const SizedBox(height: 16),

              // Tank and Quality dropdowns side by side or stacked
              DropdownButtonFormField<String>(
                value: _selectedTankForm,
                decoration: const InputDecoration(labelText: 'Araç Tankı'),
                items: tanks.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedTankForm = val;
                    _lastSelectedTank = val;
                  });
                },
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedQualityForm,
                decoration: const InputDecoration(labelText: 'Süt Kalitesi'),
                items: qualities.map((q) => DropdownMenuItem(value: q, child: Text(q))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedQualityForm = val;
                  });
                },
              ),
              const SizedBox(height: 20),

              // Tank level indicator bar
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.gray50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.gray200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Seçili Tank Doluluk Oranı',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray600),
                        ),
                        Text(
                          '${previewStock.toStringAsFixed(0)} / ${tCapacity.toStringAsFixed(0)} LT',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: previewOverflow ? Colors.red : AppColors.primary600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: previewPct,
                        backgroundColor: AppColors.gray200,
                        valueColor: AlwaysStoppedAnimation<Color>(previewOverflow ? Colors.red : AppColors.primary600),
                        minHeight: 8,
                      ),
                    ),
                    if (previewOverflow) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Limit aşılıyor! Tank taşma rengine (Kırmızı) dönecek.',
                              style: GoogleFonts.inter(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    final targetName = _selectedUreticiForSutAl == "" ? _selectedUreticiForm : _selectedUreticiForSutAl;
                    if (targetName != null && targetName.isNotEmpty) {
                      SutAnalizDialog.show(
                        context,
                        targetName: targetName,
                        tip: 'Üretici',
                      );
                    }
                  },
                  icon: const Icon(Icons.science_rounded, size: 16),
                  label: Text(
                    'Analiz Ekle',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary600),
                    foregroundColor: AppColors.primary600,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),

              // Today's records for this customer
              StreamBuilder<QuerySnapshot>(
                stream: _firestoreService.getDriverCollectionsStream(driverName),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const SizedBox();
                  final today = DateTime.now();
                  final records = snapshot.data!.docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final name = data['u'] ?? '';
                    final ts = data['timestamp'] as Timestamp?;
                    
                    bool isToday = false;
                    if (ts != null) {
                      final date = ts.toDate();
                      isToday = date.year == today.year && date.month == today.month && date.day == today.day;
                    } else {
                      final tarihStr = data['tarih'] as String?;
                      if (tarihStr != null) {
                        final todayStr = DateFormat('dd.MM.yyyy').format(today);
                        isToday = tarihStr == todayStr;
                      }
                    }

                    final currentTarget = _selectedUreticiForSutAl == "" ? _selectedUreticiForm : _selectedUreticiForSutAl;
                    return name == currentTarget && isToday;
                  }).toList();

                  if (records.isEmpty) return const SizedBox();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      Text(
                        'Bugünkü Kayıtlar',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                      ),
                      const SizedBox(height: 8),
                      ...records.map((r) {
                        final rData = r.data() as Map<String, dynamic>;
                        final m = (rData['m'] as num?)?.toDouble() ?? 0.0;
                        final s = rData['s'] ?? '';
                        final vakit = rData['vakit'] ?? 'Belirtilmemiş';
                        final rawQuality = rData['kalite'] ?? 'Soğuk Süt';
                        final kalite = (rawQuality == 'A Kalite' || rawQuality == 'Soğuk süt')
                            ? 'Soğuk Süt'
                            : (rawQuality == 'B Kalite' || rawQuality == 'Sıcak süt')
                                ? 'Sıcak Süt'
                                : rawQuality;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.gray50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.gray200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$s • $kalite',
                                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600, fontWeight: FontWeight.w500),
                                ),
                              ),
                              Text(
                                '${m.toStringAsFixed(0)} LT',
                                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary600),
                              ),
                              const SizedBox(width: 8),
                              // Delete button
                              GestureDetector(
                                onTap: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: Text('Kaydı Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                                      content: Text(
                                        '${m.toStringAsFixed(0)} LT süt kaydını silmek istediğinize emin misiniz? Tank stoku da geri düşürülecektir.',
                                        style: GoogleFonts.inter(fontSize: 14),
                                      ),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                                        ),
                                        ElevatedButton(
                                          onPressed: () async {
                                            Navigator.pop(ctx);
                                            await _firestoreService.deleteMilkCollection(r.id);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('${m.toStringAsFixed(0)} LT süt kaydı silindi.'),
                                                  backgroundColor: AppColors.danger,
                                                ),
                                              );
                                            }
                                          },
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          child: const Text('Sil'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Vakit toggle segment removed

  void _saveCustomSutGirisi(
    String plate,
    String defaultTankName,
    double defaultCurrentStock,
    double defaultCapacity,
    String driverName,
    String firma,
    List<dynamic> tankList,
  ) async {
    final double? miktar = double.tryParse(_miktarFormCtrl.text.replaceAll(',', '.'));
    if (miktar == null || miktar <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir miktar girin!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final targetTank = _selectedTankForm ?? defaultTankName;
    String? ureticiName = _selectedUreticiForSutAl;
    if (ureticiName == "") {
      ureticiName = _selectedUreticiForm;
    }
    final qualityForm = _selectedQualityForm ?? 'Soğuk Süt';
    final customerTypeForm = _selectedCustomerTypeForm ?? 'sut';

    if (ureticiName == null || ureticiName.isEmpty) return;

    // Find capacity and stock of the selected tank
    double tCapacity = defaultCapacity;
    double tCurrentStock = defaultCurrentStock;
    try {
      final tankInfo = tankList.firstWhere((t) => (t as Map)['ad'] == targetTank);
      tCapacity = (tankInfo['kap'] as num?)?.toDouble() ?? defaultCapacity;
      tCurrentStock = (tankInfo['stok'] as num?)?.toDouble() ?? defaultCurrentStock;
    } catch (_) {}

    final bool isOverflow = tCurrentStock + miktar > tCapacity;

    // Clear inputs immediately so user can enter the next one
    _miktarFormCtrl.clear();
    final savedProducer = ureticiName;
    _lastSelectedTank = targetTank;

    setState(() {
      _selectedUreticiForSutAl = null;
      _selectedQualityForm = null;
      _selectedTankForm = null;
      _isSaving = false;
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$savedProducer: ${miktar.toStringAsFixed(1)} LT Kayıt Başarıyla Alındı!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(milliseconds: 1500),
        ),
      );
    }

    if (isOverflow && context.mounted) {
      _showLimitExceededDialog(
        context,
        targetTank,
      );
    }

    // Execute database operations in the background
    Future.microtask(() async {
      // Get producer group/region
      String region = 'Merkez';
      try {
        final prodQuery = await _firestoreService.getQueryWithCachePriority(
          FirebaseFirestore.instance
              .collection('ureticiler')
              .where('name', isEqualTo: savedProducer)
              .limit(1)
        );

        if (prodQuery.docs.isNotEmpty) {
          region = prodQuery.docs.first['group'] ?? 'Merkez';
        }
      } catch (_) {}

      await _firestoreService.recordMilkCollection(
        producerName: savedProducer,
        tankName: targetTank,
        miktar: miktar,
        driverName: driverName,
        vehiclePlate: plate,
        region: region,
        sutTipi: qualityForm,
        customerType: customerTypeForm,
        kalite: qualityForm,
      );
    });
  }

  Widget _buildQuickActionsGrid(BuildContext context, String plate, String tankName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hızlı İşlemler',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.gray800,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'Süt Girişi',
                icon: Icons.add_rounded,
                iconColor: const Color(0xFF10B981), // Emerald
                bgColor: const Color(0xFFECFDF5),
                onTap: () {
                  context.go('/surucu/toplama');
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Siparişler',
                icon: Icons.bar_chart_rounded,
                iconColor: const Color(0xFF8B5CF6), // Purple
                bgColor: const Color(0xFFF5F3FF),
                onTap: () {
                  context.go('/surucu/teslimatlar');
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'Süt Boşaltma',
                icon: Icons.local_shipping_rounded,
                iconColor: const Color(0xFF3B82F6), // Blue
                bgColor: const Color(0xFFEFF6FF),
                onTap: () {
                  context.go('/surucu/sut-bosalt');
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Süt Geçmişi',
                icon: Icons.history_rounded,
                iconColor: const Color(0xFFF59E0B), // Amber
                bgColor: const Color(0xFFFFFBEB),
                onTap: () {
                  if (tankName.isNotEmpty) {
                    _showDriverTankIcerik(context, tankName, plate: plate);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Atanmış tank bulunamadı.')),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      height: 105,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gray200, width: 1),
        boxShadow: AppShadows.sm,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
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
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gray700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(
    bool isDesktop,
    bool isTablet,
    String plate,
    String driverName,
    List<dynamic> assignedTanks,
    String currentFirmaName,
  ) {
    if (assignedTanks.isEmpty) return const SizedBox();
    return _buildVerticalDriverTankList(assignedTanks, plate, currentFirmaName);
  }

  Widget _buildVerticalDriverTankList(List<dynamic> tanks, String plate, String currentFirmaName) {
    final tankNames = tanks
        .map((t) => (t as Map)['ad'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();

    if (tankNames.isEmpty) return const SizedBox.shrink();

    // toplamalar stream'ini State'de sakla - her rebuild'de sifirlanmasin
    // (tanklar stream tetiklenince widget rebuild olur; yeni stream nesnesi
    //  olusturmak Firestore'un pending->confirmed gecisini kaybettirir)
    if (plate.isNotEmpty && _toplamaGaugePlate != plate) {
      _toplamaGaugePlate = plate;
      _toplamaGaugeStream = FirebaseFirestore.instance
          .collection('toplamalar')
          .where('km', isEqualTo: plate)
          .snapshots(includeMetadataChanges: true);
    } else if (plate.isEmpty && _toplamaGaugeStream == null) {
      _toplamaGaugeStream = FirebaseFirestore.instance
          .collection('toplamalar')
          .where('tank', whereIn: tankNames)
          .snapshots(includeMetadataChanges: true);
    }

    // tanklar koleksiyonundan kapasite bilgisi
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('tanklar')
          .where('ad', whereIn: tankNames)
          .snapshots(includeMetadataChanges: true),
      builder: (context, tankSnapshot) {
        final Map<String, Map<String, dynamic>> tankDataMap = {};
        if (tankSnapshot.hasData) {
          for (final doc in tankSnapshot.data!.docs) {
            final d = doc.data() as Map<String, dynamic>;
            final name = d['ad'] as String? ?? '';
            if (name.isNotEmpty) tankDataMap[name] = d;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _toplamaGaugeStream,
          builder: (context, toplamaSnapshot) {
            // Her tank icin toplamalar toplamini hesapla (pending + confirmed)
            final resolvedTanks = tanks.map((t) {
              final Map tMap = t as Map;
              final String ad = tMap['ad'] as String? ?? '';
              final realData = tankDataMap[ad];
              final double kap = (realData?['kap'] as num?)?.toDouble()
                  ?? (tMap['kap'] as num?)?.toDouble()
                  ?? 2000.0;

              // toplamalar toplamini kullan - her durumda guvenilir
              // (pending + confirmed kayitlarin hepsi dahil)
              final double computedTotal = toplamaSnapshot.hasData
                  ? toplamaSnapshot.data!.docs
                      .where((doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        return d['tank'] == ad && d['bosaltildi'] != true;
                      })
                      .fold(0.0, (double acc, doc) {
                        final d = doc.data() as Map<String, dynamic>;
                        return acc + ((d['m'] as num?)?.toDouble() ?? 0.0);
                      })
                  : 0.0;

              // Fallback: toplamalar bossa (bosaltma sonrasi) tanklar.stok kullan
              final double tankStok = (realData?['stok'] as num?)?.toDouble()
                  ?? (tMap['stok'] as num?)?.toDouble()
                  ?? 0.0;
              final double stok = computedTotal > 0 ? computedTotal : tankStok;

              return {'ad': ad, 'stok': stok, 'kap': kap};
            }).toList();

            final double cardHeight = 112.0;
            final double spacing = 8.0;
            final double totalItemHeight = cardHeight + spacing;
            final double containerHeight = resolvedTanks.length <= 3
                ? (resolvedTanks.length * totalItemHeight)
                : (3 * totalItemHeight);

            return SizedBox(
              height: containerHeight,
              child: ListView.builder(
                scrollDirection: Axis.vertical,
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: resolvedTanks.length,
                itemBuilder: (context, index) {
                  final tank = resolvedTanks[index];
                  final String ad = tank['ad'] as String? ?? '';
                  final double stok = (tank['stok'] as num?)?.toDouble() ?? 0.0;
                  final double kap = (tank['kap'] as num?)?.toDouble() ?? 2000.0;
                  final double fillPercent = kap > 0 ? (stok / kap) : 0.0;

                  Color gaugeColor = const Color(0xFF3B82F6);
                  final bool isOverflow = stok > kap;
                  if (isOverflow || fillPercent >= 0.8) {
                    gaugeColor = const Color(0xFFEF4444);
                  } else if (fillPercent >= 0.5) {
                    gaugeColor = const Color(0xFFF59E0B);
                  }

                  return Container(
                    height: cardHeight,
                    margin: EdgeInsets.only(bottom: spacing),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isOverflow ? Colors.red : AppColors.gray200, width: isOverflow ? 1.5 : 1.0),
                      boxShadow: AppShadows.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Icon(Icons.local_shipping_rounded, color: Color(0xFF3B82F6), size: 20),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    ad,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    plate.isNotEmpty ? plate : 'Ara\u00e7 Tank\u0131',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${stok.toStringAsFixed(0)} / ${kap.toStringAsFixed(0)} LT',
                                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: isOverflow ? Colors.red : AppColors.gray600),
                                      ),
                                      Text(
                                        '%${(fillPercent * 100).toStringAsFixed(0)}',
                                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: isOverflow ? Colors.red : AppColors.gray800),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: fillPercent.clamp(0.0, 1.0),
                                      minHeight: 6,
                                      backgroundColor: AppColors.gray100,
                                      valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => _showDriverTankIcerik(context, ad, plate: plate),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppColors.gray50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppColors.gray200),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.visibility_rounded, size: 12, color: AppColors.gray600),
                                    const SizedBox(width: 4),
                                    Text('Detay', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.gray600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }



  void _showDriverTankIcerik(BuildContext context, String tankAdi, {String plate = ''}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '$tankAdi Giriş Kayıtları',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu tanka son giren süt toplama kayıtları listelenmektedir.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF1D4ED8), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: plate.isNotEmpty
                    ? FirebaseFirestore.instance
                        .collection('toplamalar')
                        .where('km', isEqualTo: plate)
                        .snapshots(includeMetadataChanges: true)
                    : FirebaseFirestore.instance
                        .collection('toplamalar')
                        .where('tank', isEqualTo: tankAdi)
                        .snapshots(includeMetadataChanges: true),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  // plate varsa client-side tank filtresi uygula
                  final allDocs = snapshot.data?.docs ?? [];
                  final rawDocs = plate.isNotEmpty
                      ? allDocs.where((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return d['tank'] == tankAdi && d['bosaltildi'] != true;
                        }).toList()
                      : allDocs.where((doc) {
                          final d = doc.data() as Map<String, dynamic>;
                          return d['bosaltildi'] != true;
                        }).toList();
                  if (rawDocs.isEmpty) {
                    return Center(
                      child: Text(
                        'Kayıt bulunamadı.',
                        style: GoogleFonts.inter(color: AppColors.gray400),
                      ),
                    );
                  }

                  // Sort in memory by timestamp descending
                  final docs = List<QueryDocumentSnapshot>.from(rawDocs);
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aTs = aData['timestamp'];
                    final bTs = bData['timestamp'];

                    DateTime aDate = DateTime(1970);
                    DateTime bDate = DateTime(1970);

                    if (aTs is Timestamp) {
                      aDate = aTs.toDate();
                    } else if (aData['tarih'] is String) {
                      aDate = _parseDateStr(aData['tarih']);
                    }

                    if (bTs is Timestamp) {
                      bDate = bTs.toDate();
                    } else if (bData['tarih'] is String) {
                      bDate = _parseDateStr(bData['tarih']);
                    }

                    return bDate.compareTo(aDate);
                  });

                  final displayDocs = docs.take(15).toList();

                  return ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayDocs.length,
                    itemBuilder: (_, i) {
                      final doc = displayDocs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final u = data['u'] ?? 'Bilinmeyen Üretici';
                      final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
                      final s = data['s'] ?? '';
                      final bool isPending = doc.metadata.hasPendingWrites;
                      
                      final ts = data['timestamp'];
                      String t = '';
                      if (ts is Timestamp) {
                        t = DateFormat('dd.MM.yyyy').format(ts.toDate());
                      } else {
                        t = data['tarih'] ?? '';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: ListTile(
                          title: Text(
                            u,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gray800),
                          ),
                          subtitle: Text(
                            '$t $s',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isPending) ...[
                                Text(
                                  'Yükleniyor...',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange[600],
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              Text(
                                '${m.toStringAsFixed(1)} LT',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.bold,
                                  color: isPending ? Colors.grey[500] : const Color(0xFF3B82F6),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
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

  DateTime _parseDateStr(String dateStr) {
    try {
      final parts = dateStr.split('.');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime(1970);
  }

  void _showLimitExceededDialog(BuildContext context, String tankName, {VoidCallback? onDismiss}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 10),
            Text('Limit Aşıldı', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text('Tank limiti aşıldı! ($tankName)', style: GoogleFonts.inter(fontSize: 14)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (onDismiss != null) onDismiss();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
