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

class SurucuDashboard extends StatefulWidget {
  final bool showSutAlDirectly;

  const SurucuDashboard({super.key, this.showSutAlDirectly = false});

  @override
  State<SurucuDashboard> createState() => _SurucuDashboardState();
}

class _SurucuDashboardState extends State<SurucuDashboard> {
  final _firestoreService = FirestoreService();
  final _miktarFormCtrl = TextEditingController();
  String? _selectedUreticiForm;
  String? _selectedMilkTypeForm;
  String? _selectedCustomerTypeForm;
  final List<String> _milkTypes = const ['Soğuk Süt', 'Sıcak Süt', 'C Kalite', 'D Kalite'];

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
        bool isSicak = false;
        bool isYem = false;
        bool loading = false;

        final nameCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final manualMahalleCtrl = TextEditingController();

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
                        decoration: const InputDecoration(labelText: 'Telefon', hintText: '0532 999 8877'),
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
                        const SizedBox(height: 24),
                      ],

                      // Custom toggle
                      _buildTempToggle(
                        isSicak,
                        (val) => setState(() => isSicak = val),
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

                    if (nameCtrl.text.isEmpty || phoneCtrl.text.isEmpty || il.isEmpty || ilce.isEmpty || mahalleKoy.isEmpty) return;

                    await _firestoreService.addProducer(
                      name: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      group: mahalleKoy,
                      bolge: ilce,
                      avg: 30.0,
                      firma: currentFirmaName,
                      lastMilkType: isYem ? 'Yok' : (isSicak ? 'Sıcak Süt' : 'Soğuk Süt'),
                      customerType: isYem ? 'yem' : 'sut',
                    );

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

  void _showSutAlDialog(String plate, String tankName, double currentStock, double capacity, String driverName, String firma, bool canAddCustomer) {
    final miktarCtrl = TextEditingController();
    String? localSelectedUretici;
    String? localSelectedMilkType;
    String? localSelectedCustomerType;
    const List<String> milkTypes = ['Soğuk Süt', 'Sıcak Süt', 'C Kalite', 'D Kalite'];

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

          if (localSelectedUretici == null || !producers.contains(localSelectedUretici)) {
            localSelectedUretici = producers.first;
            try {
              final prodDoc = prodSnapshot.data!.docs.firstWhere((doc) => doc['name'] == localSelectedUretici);
              final docData = prodDoc.data() as Map<String, dynamic>;
              localSelectedMilkType = docData['lastMilkType'] ?? 'Soğuk Süt';
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
            builder: (context, setDialogState) => AlertDialog(
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
                              localSelectedMilkType = docData['lastMilkType'] ?? 'Soğuk Süt';
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
                    DropdownButtonFormField<String>(
                      value: localSelectedMilkType,
                      decoration: const InputDecoration(labelText: 'Süt Tipi'),
                      items: milkTypes
                          .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            localSelectedMilkType = val;
                          });
                        }
                      },
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
                    final double? miktar = double.tryParse(miktarCtrl.text);
                    if (miktar == null || miktar <= 0) return;

                    if (currentStock + miktar > capacity) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Hata: Tank kapasitesi aşılıyor!'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    // Get producer region
                    String region = 'Merkez';
                    try {
                      final prodDoc = prodSnapshot.data!.docs.firstWhere((doc) => doc['name'] == localSelectedUretici);
                      region = prodDoc['group'] ?? 'Merkez';
                    } catch (_) {}

                    await _firestoreService.recordMilkCollection(
                      producerName: localSelectedUretici!,
                      tankName: tankName,
                      miktar: miktar,
                      driverName: driverName,
                      vehiclePlate: plate,
                      region: region,
                      sutTipi: localSelectedMilkType ?? 'Soğuk Süt',
                      customerType: localSelectedCustomerType ?? 'sut',
                    );

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$localSelectedUretici üreticisinden ${miktar.toStringAsFixed(0)} LT süt alındı! Tank güncellendi.'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Süt Al'),
                ),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildTempToggle(bool isSicak, ValueChanged<bool> onChanged, {bool enabled = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Varsayılan Süt Sıcaklığı',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: enabled ? () {
            onChanged(!isSicak);
          } : null,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
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
                      Expanded(
                        child: Center(
                          child: Text(
                            'Soğuk Süt',
                            style: GoogleFonts.inter(
                              color: !isSicak ? Colors.transparent : Colors.grey[600],
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

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final driverName = authProvider.user?.displayName ?? 'Ahmet Kara';

    final parts = driverName.split(' ');
    final ad = parts.isNotEmpty ? parts.first : '';
    final soyad = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    final profileStream = FirebaseFirestore.instance
        .collection('suruculer')
        .where('ad', isEqualTo: ad)
        .where('soyad', isEqualTo: soyad)
        .limit(1)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: profileStream,
      builder: (context, profileSnapshot) {
        bool canAddCustomer = true;
        bool canEditCustomer = true;
        bool canCreateOrder = true;

        if (profileSnapshot.hasData && profileSnapshot.data!.docs.isNotEmpty) {
          final pDoc = profileSnapshot.data!.docs.first;
          final pData = pDoc.data() as Map<String, dynamic>;
          canAddCustomer = pData['canAddCustomer'] ?? true;
          canEditCustomer = pData['canEditCustomer'] ?? true;
          canCreateOrder = pData['canCreateOrder'] ?? true;
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getDriverVehicleStream(driverName),
          builder: (context, vehicleSnapshot) {
        if (vehicleSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final vehicleDocs = vehicleSnapshot.data?.docs ?? [];
        if (vehicleDocs.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.gray50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.gray400),
                  const SizedBox(height: 16),
                  Text(
                    'Aktif aracınız bulunamadı!',
                    style: GoogleFonts.inter(fontSize: 16, color: AppColors.gray600, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yönetici tarafından araç ataması yapılması gerekmektedir.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                  ),
                ],
              ),
            ),
          );
        }

        final vehicleDoc = vehicleDocs.first;
        final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
        final plate = vehicleData['plaka'] ?? '';
        final tankList = vehicleData['tanklar'] as List? ?? [];
        final currentFirmaName = vehicleData['firma'] ?? '';

        if (tankList.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.gray50,
            body: Center(
              child: Text(
                'Araca atanmış tank bulunamadı!',
                style: GoogleFonts.inter(fontSize: 16, color: AppColors.gray600, fontWeight: FontWeight.bold),
              ),
            ),
          );
        }

        final tank = tankList.first as Map;
        final tankName = tank['ad'] ?? '';
        final double currentStock = (tank['stok'] as num?)?.toDouble() ?? 0.0;
        final double capacity = (tank['kap'] as num?)?.toDouble() ?? 2000.0;

        final pct = (currentStock / capacity).clamp(0.0, 1.0);
        final pctText = (pct * 100).toStringAsFixed(0);

        return Scaffold(
          backgroundColor: AppColors.gray50,
          floatingActionButton: widget.showSutAlDirectly
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: () => _showAddProducerApprovalDialog(currentFirmaName, driverName),
                      heroTag: 'yeni_uretici_fab',
                      backgroundColor: AppColors.primary600,
                      icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 20),
                      label: Text(
                        'Yeni Üretici',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 12),
                    FloatingActionButton.extended(
                      onPressed: () => _showSutAlDialog(plate, tankName, currentStock, capacity, driverName, currentFirmaName, canAddCustomer),
                      heroTag: 'sut_al_fab',
                      backgroundColor: AppColors.primary600,
                      icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                      label: Text(
                        'Süt Al',
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                    ),
                  ],
                ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1024;
              final isTablet = constraints.maxWidth >= 640 && constraints.maxWidth < 1024;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  // Header
                  Row(
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
                            const SizedBox(height: 4),
                            Text(
                              widget.showSutAlDirectly
                                  ? 'Üreticiden aldığınız süt miktarını girerek tank stoğuna ekleyin.'
                                  : 'Süt toplama rotanızı ve araç tank doluluğunu buradan takip edebilirsiniz.',
                              style: GoogleFonts.inter(
                                fontSize: isDesktop ? 12 : 11,
                                color: AppColors.gray500,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Main Responsive Layout / Süt Al Form view
                  widget.showSutAlDirectly
                      ? _buildSutAlFormView(isDesktop, plate, tankName, currentStock, capacity, driverName, currentFirmaName, canAddCustomer)
                      : _buildResponsiveLayout(isDesktop, isTablet, pct, pctText, plate, tankName, currentStock, capacity, driverName),
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

  Widget _buildSutAlFormView(bool isDesktop, String plate, String tankName, double currentStock, double capacity, String driverName, String firma, bool canAddCustomer) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getProducersStream(firma: firma),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const AppCard(child: Center(child: CircularProgressIndicator()));
            }

            final producers = snapshot.data!.docs.map((doc) => doc['name'] as String).toSet().toList();
            if (producers.isEmpty) {
              return const AppCard(child: Center(child: Text('Kayıtlı üretici bulunamadı!')));
            }

            if (_selectedUreticiForm == null || !producers.contains(_selectedUreticiForm)) {
              _selectedUreticiForm = producers.first;
              try {
                final prodDoc = snapshot.data!.docs.firstWhere((doc) => doc['name'] == _selectedUreticiForm);
                final docData = prodDoc.data() as Map<String, dynamic>;
                _selectedMilkTypeForm = docData['lastMilkType'] ?? 'Soğuk Süt';
                _selectedCustomerTypeForm = docData['customerType'] ?? 'sut';
              } catch (_) {
                _selectedMilkTypeForm = 'Soğuk Süt';
                _selectedCustomerTypeForm = 'sut';
              }
            } else if (_selectedCustomerTypeForm == null) {
              try {
                final prodDoc = snapshot.data!.docs.firstWhere((doc) => doc['name'] == _selectedUreticiForm);
                final docData = prodDoc.data() as Map<String, dynamic>;
                _selectedCustomerTypeForm = docData['customerType'] ?? 'sut';
              } catch (_) {
                _selectedCustomerTypeForm = 'sut';
              }
            }

            if (_selectedMilkTypeForm == null || !_milkTypes.contains(_selectedMilkTypeForm)) {
              _selectedMilkTypeForm = 'Soğuk Süt';
            }

            return AppCard(
              shadow: AppShadows.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedUreticiForm,
                    decoration: const InputDecoration(labelText: 'Üretici Seçin'),
                    items: producers
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedUreticiForm = val;
                          try {
                            final prodDoc = snapshot.data!.docs.firstWhere((doc) => doc['name'] == _selectedUreticiForm);
                            final docData = prodDoc.data() as Map<String, dynamic>;
                            _selectedMilkTypeForm = docData['lastMilkType'] ?? 'Soğuk Süt';
                            _selectedCustomerTypeForm = docData['customerType'] ?? 'sut';
                          } catch (_) {
                            _selectedMilkTypeForm = 'Soğuk Süt';
                            _selectedCustomerTypeForm = 'sut';
                          }
                          if (_selectedMilkTypeForm == null || !_milkTypes.contains(_selectedMilkTypeForm)) {
                            _selectedMilkTypeForm = 'Soğuk Süt';
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
                  DropdownButtonFormField<String>(
                    value: _selectedMilkTypeForm,
                    decoration: const InputDecoration(labelText: 'Süt Tipi'),
                    items: _milkTypes
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedMilkTypeForm = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: _selectedCustomerTypeForm == 'yem' ? Colors.amber[100] : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: _selectedCustomerTypeForm == 'yem'
                          ? Border.all(color: Colors.amber[300]!, width: 1)
                          : Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedCustomerTypeForm,
                      decoration: const InputDecoration(
                        labelText: 'Üretici Türü',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'sut', child: Text('Süt Üreticisi')),
                        DropdownMenuItem(value: 'yem', child: Text('Yem Müşterisi')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedCustomerTypeForm = val;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _miktarFormCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Miktar (Litre)',
                      hintText: 'Örn: 50',
                      suffixText: 'LT',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        if (_selectedUreticiForm != null) {
                          SutAnalizDialog.show(
                            context,
                            targetName: _selectedUreticiForm!,
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final double? miktar = double.tryParse(_miktarFormCtrl.text);
                        if (miktar == null || miktar <= 0) return;

                        if (currentStock + miktar > capacity) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Hata: Tank kapasitesi aşılıyor!'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }

                        String region = 'Merkez';
                        try {
                          final prodDoc = snapshot.data!.docs.firstWhere((doc) => doc['name'] == _selectedUreticiForm);
                          region = prodDoc['group'] ?? 'Merkez';
                        } catch (_) {}

                        await _firestoreService.recordMilkCollection(
                          producerName: _selectedUreticiForm!,
                          tankName: tankName,
                          miktar: miktar,
                          driverName: driverName,
                          vehiclePlate: plate,
                          region: region,
                          sutTipi: _selectedMilkTypeForm,
                          customerType: _selectedCustomerTypeForm ?? 'sut',
                        );

                        _miktarFormCtrl.clear();

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('$_selectedUreticiForm üreticisinden ${miktar.toStringAsFixed(0)} LT süt alındı! Tank güncellendi.'),
                            backgroundColor: AppColors.success,
                          ),
                        );

                        context.go('/surucu');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.water_drop_rounded, size: 18),
                      label: Text(
                        'Süt Alımını Kaydet',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(bool isDesktop, bool isTablet, double pct, String pctText, String plate, String tankName, double currentStock, double capacity, String driverName) {
    final tankerDurumuWidget = AppCard(
      shadow: AppShadows.md,
      child: Column(
        children: [
          Row(
            children: [
              Text('Tank Durumu', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
              const Spacer(),
              StatusBadge.active('Yolda'),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 150,
            height: 150,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: pct,
                    strokeWidth: 12,
                    backgroundColor: AppColors.gray100,
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
                    strokeCap: StrokeCap.round,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(currentStock.toStringAsFixed(0), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary600)),
                    Text('/ ${capacity.toStringAsFixed(0)} LT', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(6)),
                      child: Text('%$pctText', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(8)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping_rounded, size: 14, color: AppColors.primary600),
                const SizedBox(width: 6),
                Text('$plate • $tankName', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.gray700)),
              ],
            ),
          ),
        ],
      ),
    );

    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getDriverCollectionsStream(driverName),
      builder: (context, collectionsSnapshot) {
        final docs = List<QueryDocumentSnapshot>.from(collectionsSnapshot.data?.docs ?? []);
        docs.sort((a, b) {
          final aTime = (a.data() as Map)['timestamp'] as Timestamp?;
          final bTime = (b.data() as Map)['timestamp'] as Timestamp?;
          if (aTime == null) return -1;
          if (bTime == null) return 1;
          return bTime.compareTo(aTime);
        });
        
        // Calculate dynamic values for card
        double todayTotal = 0;
        for (var doc in docs) {
          final mVal = doc['m'];
          if (mVal is num) {
            todayTotal += mVal.toDouble();
          } else if (mVal is String) {
            todayTotal += double.tryParse(mVal) ?? 0;
          }
        }

        final statsCardsWidget = Column(
          children: [
            StatCard(
              icon: Icons.water_drop_rounded,
              value: todayTotal.toStringAsFixed(0),
              label: 'Bugün Toplanan (LT)',
              color: AppColors.primary600,
              change: '+%15',
              subtext: 'Tank Güncel Hacmi',
              sparklineData: const [120, 150, 180, 210, 240, 280, 320],
              isUp: true,
            ),
            const SizedBox(height: 12),
            StatCard(
              icon: Icons.people_rounded,
              value: docs.length.toString(),
              label: 'Ziyaret Edilen Üretici',
              color: AppColors.success,
              change: '+1',
              subtext: 'Hedef: 12',
              sparklineData: const [3, 4, 5, 5, 6, 7, 8],
              isUp: true,
            ),
          ],
        );

        final listWidget = AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Bugünkü Toplamalar', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const LiveDot(),
                ],
              ),
              const SizedBox(height: 14),
              if (docs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Henüz süt toplama kaydı bulunmuyor.', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                  ),
                )
              else
                ...docs.map((t) {
                  final data = t.data() as Map<String, dynamic>;
                  final u = data['u'] ?? '-';
                  final mVal = data['m'] ?? 0;
                  final mStr = mVal is num ? mVal.toStringAsFixed(0) : mVal.toString();
                  final s = data['s'] ?? '';
                  final sync = data['sync'] ?? true;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(8)),
                          child: Center(
                            child: Text(
                              u.isNotEmpty ? u[0] : 'U',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(u, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                              Row(
                                children: [
                                  Text(s, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                                  const SizedBox(width: 6),
                                  Icon(
                                    sync ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                    size: 12,
                                    color: sync ? AppColors.success : AppColors.warning,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(6)),
                          child: Text('$mStr LT', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary600)),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        );

        if (isDesktop) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: tankerDurumuWidget),
              const SizedBox(width: 16),
              Expanded(flex: 3, child: statsCardsWidget),
              const SizedBox(width: 16),
              Expanded(flex: 4, child: listWidget),
            ],
          );
        } else if (isTablet) {
          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: tankerDurumuWidget),
                  const SizedBox(width: 16),
                  Expanded(child: statsCardsWidget),
                ],
              ),
              const SizedBox(height: 16),
              listWidget,
            ],
          );
        }

        return Column(
          children: [
            tankerDurumuWidget,
            const SizedBox(height: 16),
            statsCardsWidget,
            const SizedBox(height: 16),
            listWidget,
          ],
        );
      }
    );
  }



  void _showAddProducerApprovalDialog(String currentFirmaName, String driverName) {
    showDialog(
      context: context,
      builder: (ctx) {
        final nameCtrl = TextEditingController();
        final phoneCtrl = TextEditingController();
        final bolgeCtrl = TextEditingController(text: 'Merkez');

        bool isSicak = false;
        bool isYem = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Yeni Üretici Kayıt Talebi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 400,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Ad Soyad', hintText: 'Örn: Ahmet Yılmaz'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(labelText: 'Telefon', hintText: 'Örn: 0532 999 8877'),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: bolgeCtrl,
                        decoration: const InputDecoration(labelText: 'Bölge / İlçe', hintText: 'Örn: Talas'),
                      ),
                      const SizedBox(height: 24),
                      _buildTempToggle(
                        isSicak,
                        (val) => setState(() => isSicak = val),
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
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    final phone = phoneCtrl.text.trim();
                    final bolge = bolgeCtrl.text.trim();
                    final selectedMilkType = isYem ? 'Yok' : (isSicak ? 'Sıcak Süt' : 'Soğuk Süt');

                    if (name.isEmpty || phone.isEmpty || bolge.isEmpty) return;

                    // Add request to uretici_onaylari
                    await FirebaseFirestore.instance.collection('uretici_onaylari').add({
                      'name': name,
                      'phone': phone,
                      'bolge': bolge,
                      'lastMilkType': selectedMilkType,
                      'customerType': isYem ? 'yem' : 'sut',
                      'toplayici': driverName,
                      'firma': currentFirmaName,
                      'status': 'Bekliyor',
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // Send notification to the producer
                    await _firestoreService.sendNotification(
                      recipientName: name,
                      role: 'uretici',
                      baslik: 'Üretici Kayıt Talebi',
                      icerik: '$currentFirmaName firması adına toplayıcı $driverName sizin için yeni üretici kayıt talebi oluşturdu.',
                      type: 'sistem',
                    );

                    // Send notification to the company
                    await _firestoreService.sendNotification(
                      recipientName: currentFirmaName,
                      role: 'firma',
                      baslik: 'Yeni Üretici Onay Talebi',
                      icerik: '$driverName toplayıcısı yeni bir üretici ekledi: $name. Lütfen onaylayın.',
                      type: 'sistem',
                    );

                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Yeni üretici kayıt talebi gönderildi! Firma onayından sonra listelenecektir.'), backgroundColor: AppColors.success),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Talep Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
