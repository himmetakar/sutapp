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
  String _selectedVakit = 'Sabah';
  String? _selectedUreticiForSutAl;
  String? _selectedQualityForm;
  String? _selectedTankForm;
  String _searchQuery = '';

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
                      lastMilkType: isYem ? 'Yok' : (isSicak ? 'Sıcak Süt' : 'Soğuk Süt'),
                      customerType: isYem ? 'yem' : 'sut',
                    );

                    // Send notification to the company (firma)
                    try {
                      final authProvider = Provider.of<AuthProvider>(context, listen: false);
                      final driverName = authProvider.user?.displayName ?? 'Ahmet Kara';

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
    const List<String> milkTypes = ['Soğuk Süt', 'Sıcak Süt', 'C Kalite', 'D Kalite'];
    
    // Track selected tank inside the dialog
    String? localSelectedTank = tankList.isNotEmpty ? (tankList.first as Map)['ad'] as String : null;

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
                              });
                            }
                          },
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

                      final bool isOverflow = tCurrentStock + miktar > tCapacity;

                      // Get producer region
                      String region = 'Merkez';
                      try {
                        final prodDoc = prodSnapshot.data!.docs.firstWhere((doc) => doc['name'] == localSelectedUretici);
                        region = prodDoc['group'] ?? 'Merkez';
                      } catch (_) {}

                      await _firestoreService.recordMilkCollection(
                        producerName: localSelectedUretici!,
                        tankName: localSelectedTank!,
                        miktar: miktar,
                        driverName: driverName,
                        vehiclePlate: plate,
                        region: region,
                        sutTipi: localSelectedMilkType ?? 'Soğuk Süt',
                        customerType: localSelectedCustomerType ?? 'sut',
                      );

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
        final rawTankList = vehicleData['tanklar'] as List? ?? [];
        
        // Filter tankList to only contain tanks where this driver is assigned
        final tankList = rawTankList.where((t) {
          final tankMap = t as Map;
          final tDrivers = List<String>.from(tankMap['suruculer'] as List? ?? []);
          return tDrivers.contains(driverName);
        }).toList();

        final currentFirmaName = vehicleData['firma'] ?? '';

        if (tankList.isEmpty) {
          return Scaffold(
            backgroundColor: AppColors.gray50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.propane_tank_rounded, size: 64, color: AppColors.gray400),
                  const SizedBox(height: 16),
                  Text(
                    'Üzerinize atanmış aktif tank bulunamadı!',
                    style: GoogleFonts.inter(fontSize: 16, color: AppColors.gray600, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Yönetici tarafından tank ataması yapılması gerekmektedir.',
                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                  ),
                ],
              ),
            ),
          );
        }

        final tank = tankList.first as Map;
        final tankName = tank['ad'] ?? '';
        final double currentStock = (tank['stok'] as num?)?.toDouble() ?? 0.0;
        final double capacity = (tank['kap'] as num?)?.toDouble() ?? 2000.0;

        return Scaffold(
          backgroundColor: AppColors.gray50,
          floatingActionButton: widget.showSutAlDirectly
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton.extended(
                      onPressed: () => _showAddProducerDialog(currentFirmaName),
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
                      onPressed: () => _showSutAlDialog(plate, tankList, driverName, currentFirmaName, canAddCustomer),
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

                  widget.showSutAlDirectly
                      ? _buildSutAlFormView(isDesktop, plate, tankName, currentStock, capacity, driverName, currentFirmaName, canAddCustomer, tankList)
                      : _buildResponsiveLayout(isDesktop, isTablet, plate, driverName, tankList),
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

  Widget _buildMusteriZiyaretListesi(String driverName, String firma, bool canAddCustomer) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestoreService.getDriverCollectionsStream(driverName),
      builder: (context, collectionsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getProducersStream(firma: firma),
          builder: (context, producersSnapshot) {
            if (!producersSnapshot.hasData || !collectionsSnapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(32.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final producersDocs = producersSnapshot.data!.docs;
            final collectionsDocs = collectionsSnapshot.data!.docs;

            // Find who has been visited today
            final today = DateTime.now();
            final visitedProducersToday = collectionsDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['timestamp'] as Timestamp?;
              if (ts == null) return false;
              final date = ts.toDate();
              return date.year == today.year && date.month == today.month && date.day == today.day;
            }).map((doc) => (doc.data() as Map<String, dynamic>)['u'] as String).toSet();

            // Filter/Search producers
            final filteredProducers = producersDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['name'] ?? '').toString().toLowerCase();
              final group = (data['group'] ?? '').toString().toLowerCase();
              final query = _searchQuery.toLowerCase();
              return name.contains(query) || group.contains(query);
            }).toList();

            final totalProducers = producersDocs.length;
            final visitedCount = producersDocs.where((doc) {
              final name = (doc.data() as Map<String, dynamic>)['name'] ?? '';
              return visitedProducersToday.contains(name);
            }).length;

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
                      if (canAddCustomer)
                        ElevatedButton.icon(
                          onPressed: () => _showAddProducerDialog(firma),
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
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredProducers.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final doc = filteredProducers[index];
                      final data = doc.data() as Map<String, dynamic>;
                      final name = data['name'] ?? '';
                      final group = data['group'] ?? 'Bilinmeyen Bölge';
                      final avg = (data['avg'] as num?)?.toDouble() ?? 0.0;
                      final lastMilkType = data['lastMilkType'] ?? 'Soğuk Süt';
                      final hasBeenVisited = visitedProducersToday.contains(name);

                      return _buildProducerItemTile(
                        name: name,
                        group: group,
                        avg: avg,
                        lastMilkType: lastMilkType,
                        hasBeenVisited: hasBeenVisited,
                        onTap: () {
                          setState(() {
                            _selectedUreticiForSutAl = name;
                            _selectedUreticiForm = name;
                            _selectedMilkTypeForm = lastMilkType;
                            _selectedCustomerTypeForm = data['customerType'] ?? 'sut';
                            _selectedQualityForm = lastMilkType; // Default quality matches last milk type
                            _miktarFormCtrl.clear();
                          });
                        },
                      );
                    },
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildProducerItemTile({
    required String name,
    required String group,
    required double avg,
    required String lastMilkType,
    required bool hasBeenVisited,
    required VoidCallback onTap,
  }) {
    final isSicak = lastMilkType == 'Sıcak Süt';

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
                        : (isSicak ? Colors.red[50] : Colors.blue[50]),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: hasBeenVisited
                        ? Icon(Icons.check_rounded, color: Colors.grey[600], size: 20)
                        : Icon(
                            Icons.water_drop_rounded,
                            color: isSicak ? Colors.red[600] : Colors.blue[600],
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
                          if (hasBeenVisited)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              width: 18,
                              height: 18,
                              decoration: const BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: Text(
                                  'S',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$group • Ort: ${avg.toStringAsFixed(0)} LT',
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
      _selectedTankForm = tanks.isNotEmpty ? tanks.first : tankName;
    }

    final qualities = const ['A Kalite', 'B Kalite', 'C Kalite', 'D Kalite'];
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

    final double enteredMiktar = double.tryParse(_miktarFormCtrl.text) ?? 0.0;
    final double previewStock = tCurrentStock + enteredMiktar;
    final double previewPct = (previewStock / tCapacity).clamp(0.0, 1.0);
    final bool previewOverflow = previewStock > tCapacity;

    final String todayDateStr = DateFormat('dd MMMM yyyy, Eeee', 'tr_TR').format(DateTime.now());

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
                      _selectedUreticiForSutAl!,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray900),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _saveCustomSutGirisi(plate, tankName, currentStock, capacity, driverName, firma, tankList),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      elevation: 0,
                    ),
                    child: Text(
                      'Kaydet',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, thickness: 1, color: AppColors.gray200),

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

              // Vakit Toggle Row (Sabah/Akşam)
              Row(
                children: [
                  Text(
                    'Vakit:',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray700),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildVakitSegment('Sabah', Icons.wb_sunny_rounded, Colors.orange),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildVakitSegment('Akşam', Icons.nights_stay_rounded, Colors.indigo),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Litre Input
              TextField(
                controller: _miktarFormCtrl,
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

              // Analiz Ekle / Yeni Üretici Ekle
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        SutAnalizDialog.show(
                          context,
                          targetName: _selectedUreticiForSutAl!,
                          tip: 'Üretici',
                        );
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
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showAddProducerDialog(firma),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 16),
                      label: Text(
                        'Üretici Ekle',
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
                ],
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
                    if (ts == null) return false;
                    final date = ts.toDate();
                    return name == _selectedUreticiForSutAl &&
                        date.year == today.year &&
                        date.month == today.month &&
                        date.day == today.day;
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
                        final kalite = rData['kalite'] ?? 'A Kalite';

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
                                  '$s • $vakit • $kalite',
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

  Widget _buildVakitSegment(String val, IconData icon, Color color) {
    final isSelected = _selectedVakit == val;
    return GestureDetector(
      onTap: () => setState(() => _selectedVakit = val),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : AppColors.gray200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : AppColors.gray400),
            const SizedBox(width: 6),
            Text(
              val,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? color : AppColors.gray600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveCustomSutGirisi(
    String plate,
    String defaultTankName,
    double defaultCurrentStock,
    double defaultCapacity,
    String driverName,
    String firma,
    List<dynamic> tankList,
  ) async {
    final double? miktar = double.tryParse(_miktarFormCtrl.text);
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

    // Find capacity and stock of the selected tank
    double tCapacity = defaultCapacity;
    double tCurrentStock = defaultCurrentStock;
    try {
      final tankInfo = tankList.firstWhere((t) => (t as Map)['ad'] == targetTank);
      tCapacity = (tankInfo['kap'] as num?)?.toDouble() ?? defaultCapacity;
      tCurrentStock = (tankInfo['stok'] as num?)?.toDouble() ?? defaultCurrentStock;
    } catch (_) {}

    final bool isOverflow = tCurrentStock + miktar > tCapacity;

    // Get producer group/region
    String region = 'Merkez';
    try {
      final prodQuery = await FirebaseFirestore.instance
          .collection('ureticiler')
          .where('name', isEqualTo: _selectedUreticiForSutAl)
          .limit(1)
          .get();

      if (prodQuery.docs.isNotEmpty) {
        region = prodQuery.docs.first['group'] ?? 'Merkez';
      }
    } catch (_) {}

    await _firestoreService.recordMilkCollection(
      producerName: _selectedUreticiForSutAl!,
      tankName: targetTank,
      miktar: miktar,
      driverName: driverName,
      vehiclePlate: plate,
      region: region,
      sutTipi: _selectedMilkTypeForm ?? 'Soğuk Süt',
      customerType: _selectedCustomerTypeForm ?? 'sut',
      vakit: _selectedVakit,
      kalite: _selectedQualityForm ?? 'A Kalite',
    );

    _miktarFormCtrl.clear();
    final savedProducer = _selectedUreticiForSutAl;

    setState(() {
      _selectedUreticiForSutAl = null;
      _selectedQualityForm = null;
      _selectedTankForm = null;
    });

    if (isOverflow) {
      _showLimitExceededDialog(
        context,
        targetTank,
        onDismiss: () {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$savedProducer üreticisinden ${miktar.toStringAsFixed(0)} LT süt alındı!'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        },
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$savedProducer üreticisinden ${miktar.toStringAsFixed(0)} LT süt alındı!'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  Widget _buildResponsiveLayout(
    bool isDesktop,
    bool isTablet,
    String plate,
    String driverName,
    List<dynamic> assignedTanks,
  ) {
    final tankerDurumuWidget = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: assignedTanks.map<Widget>((t) {
        final tank = t as Map;
        final tankName = tank['ad'] ?? '';
        final double currentStock = (tank['stok'] as num?)?.toDouble() ?? 0.0;
        final double capacity = (tank['kap'] as num?)?.toDouble() ?? 2000.0;

        final pct = (currentStock / capacity).clamp(0.0, 1.0);
        final pctText = ((currentStock / capacity) * 100).toStringAsFixed(0);
        final bool isOverflow = currentStock > capacity;
        final Color gaugeColor = isOverflow ? Colors.red : AppColors.primary500;
        final Color textColor = isOverflow ? Colors.red : AppColors.primary600;
        final Color badgeBgColor = isOverflow ? const Color(0xFFFEE2E2) : AppColors.primary50;
        final Color badgeTextColor = isOverflow ? Colors.red : AppColors.primary600;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: AppCard(
            shadow: AppShadows.md,
            borderColor: isOverflow ? Colors.red : null,
            borderWidth: isOverflow ? 2.0 : null,
            child: Column(
              children: [
                Row(
                  children: [
                    Text(tankName, style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600)),
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
                          valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(currentStock.toStringAsFixed(0), style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w700, color: textColor)),
                          Text('/ ${capacity.toStringAsFixed(0)} LT', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: badgeBgColor, borderRadius: BorderRadius.circular(6)),
                            child: Text('%$pctText', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: badgeTextColor)),
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
          ),
        );
      }).toList(),
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
                        const SizedBox(width: 8),
                        // Delete button
                        GestureDetector(
                          onTap: () {
                            final double mDouble = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: Text('Kaydı Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                                content: Text(
                                  '$u üreticisinden alınan $mStr LT süt kaydını silmek istediğinize emin misiniz?',
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
                                      await _firestoreService.deleteMilkCollection(t.id);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('$mStr LT süt kaydı silindi.'),
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
                            child: const Icon(Icons.delete_outline_rounded, size: 14, color: Colors.red),
                          ),
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
