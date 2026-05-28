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
  final List<String> _milkTypes = const ['Soğuk süt', 'Sıcak süt', 'C kalite', 'D kalite'];
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
                      lastMilkType: isYem ? 'Yok' : (isSicak ? 'Sıcak süt' : 'Soğuk süt'),
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
    const List<String> milkTypes = ['Soğuk süt', 'Sıcak süt', 'C kalite', 'D kalite'];
    
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
              localSelectedMilkType = docData['lastMilkType'] ?? 'Soğuk süt';
              localSelectedCustomerType = docData['customerType'] ?? 'sut';
            } catch (_) {
              localSelectedMilkType = 'Soğuk süt';
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
            localSelectedMilkType = 'Soğuk süt';
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
                                localSelectedMilkType = docData['lastMilkType'] ?? 'Soğuk süt';
                                localSelectedCustomerType = docData['customerType'] ?? 'sut';
                              } catch (_) {
                                localSelectedMilkType = 'Soğuk süt';
                                localSelectedCustomerType = 'sut';
                              }
                              if (localSelectedMilkType == null || !milkTypes.contains(localSelectedMilkType)) {
                                localSelectedMilkType = 'Soğuk süt';
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
                        sutTipi: localSelectedMilkType ?? 'Soğuk süt',
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
                                  isSicak ? 'Sıcak süt' : 'Soğuk süt',
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
                            'Sıcak süt',
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
                            'Soğuk süt',
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

  Future<bool> _checkYesterdayEmptyStatus(String driverName, String plate) async {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    
    final startOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day, 0, 0, 0);
    final endOfYesterday = DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
    
    final collectionsQuery = await FirebaseFirestore.instance
        .collection('toplamalar')
        .where('sr', isEqualTo: driverName)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfYesterday))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endOfYesterday))
        .limit(1)
        .get();
        
    if (collectionsQuery.docs.isEmpty) {
      return true;
    }
    
    final dateStr = DateFormat('dd.MM.yyyy').format(yesterday);
    final deliveriesQuery = await FirebaseFirestore.instance
        .collection('teslimatlar')
        .where('plaka', isEqualTo: plate)
        .where('tarih', isEqualTo: dateStr)
        .limit(1)
        .get();
        
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
    final driverName = authProvider.user?.displayName ?? 'Ahmet Kara';
    final userEmail = authProvider.user?.email ?? '';

    final profileStream = FirebaseFirestore.instance
        .collection('suruculer')
        .where('email', isEqualTo: userEmail)
        .limit(1)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(
      stream: profileStream,
      builder: (context, profileSnapshot) {
        bool canAddCustomer = true;
        bool canEditCustomer = true;
        bool canCreateOrder = true;
        String resolvedDriverName = driverName;

        if (profileSnapshot.hasData && profileSnapshot.data!.docs.isNotEmpty) {
          final pDoc = profileSnapshot.data!.docs.first;
          final pData = pDoc.data() as Map<String, dynamic>;
          canAddCustomer = pData['canAddCustomer'] ?? true;
          canEditCustomer = pData['canEditCustomer'] ?? true;
          canCreateOrder = pData['canCreateOrder'] ?? true;
          final dbAd = pData['ad'] ?? '';
          final dbSoyad = pData['soyad'] ?? '';
          final dbFullName = '$dbAd $dbSoyad'.trim();
          if (dbFullName.isNotEmpty) {
            resolvedDriverName = dbFullName;
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getDriverVehicleStream(resolvedDriverName),
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
          floatingActionButton: widget.showSutAlDirectly
              ? null
              : FloatingActionButton.extended(
                  onPressed: () => context.go('/surucu/toplama'),
                  heroTag: 'sut_al_fab',
                  backgroundColor: AppColors.primary600,
                  icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  label: Text(
                    'Süt Al',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                  ),
                ),
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
                          // Right side action (Üretici Ekle) and logo
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
                                if (logoUrl != null && logoUrl.isNotEmpty) const SizedBox(width: 12),
                              ],
                              if (logoUrl != null && logoUrl.isNotEmpty)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.gray200, width: 1.5),
                                    image: DecorationImage(
                                      image: logoUrl.startsWith('data:image')
                                          ? MemoryImage(base64Decode(logoUrl.substring(logoUrl.indexOf(',') + 1))) as ImageProvider
                                          : NetworkImage(logoUrl),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
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
                        _buildResponsiveLayout(isDesktop, isTablet, plate, resolvedDriverName, tankList),
                        const SizedBox(height: 16),
                      ],
                      _buildSutAlFormView(isDesktop, plate, tankName, currentStock, capacity, resolvedDriverName, currentFirmaName, canAddCustomer, tankList),
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
                      final lastMilkType = data['lastMilkType'] ?? 'Soğuk süt';
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
    final isSicak = lastMilkType == 'Sıcak süt';

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

    final qualities = const ['A Kalite', 'B Kalite', 'C kalite', 'D kalite'];
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
      sutTipi: _selectedMilkTypeForm ?? 'Soğuk süt',
      customerType: _selectedCustomerTypeForm ?? 'sut',
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
    if (assignedTanks.isEmpty) return const SizedBox();
    return _buildVerticalDriverTankList(assignedTanks, plate);
  }

  Widget _buildVerticalDriverTankList(List<dynamic> tanks, String plate) {
    final double cardHeight = 88.0;
    final double spacing = 8.0;
    final double totalItemHeight = cardHeight + spacing;
    final double containerHeight = tanks.length <= 4 
        ? (tanks.length * totalItemHeight) 
        : (4 * totalItemHeight);

    return SizedBox(
      height: containerHeight,
      child: ListView.builder(
        scrollDirection: Axis.vertical,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tanks.length,
        itemBuilder: (context, index) {
          final tank = tanks[index] as Map;
          final String ad = tank['ad'] ?? '';
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
            child: Row(
              children: [
                // Left: Shipping Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.local_shipping_rounded,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Middle: Name & Vehicle Info
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
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plate.isNotEmpty ? plate : 'Araç Tankı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.gray400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stok.toStringAsFixed(0)} / ${kap.toStringAsFixed(0)} LT',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isOverflow ? Colors.red : AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Right: Horizontal Progress Bar & Details
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
                            'Doluluk',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.gray400),
                          ),
                          Text(
                            '%${(fillPercent * 100).toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isOverflow ? Colors.red : AppColors.gray800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fillPercent.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: AppColors.gray100,
                          valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Action Button: Detay
                GestureDetector(
                  onTap: () => _showDriverTankIcerik(context, ad),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        Text(
                          'Detay',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDriverTankIcerik(BuildContext context, String tankAdi) {
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
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('toplamalar')
                    .orderBy('tarih', descending: true)
                    .limit(15)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'Kayıt bulunamadı.',
                        style: GoogleFonts.inter(color: AppColors.gray400),
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final doc = docs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final u = data['u'] ?? 'Bilinmeyen Üretici';
                      final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
                      final s = data['s'] ?? '';
                      final t = data['tarih'] ?? '';

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
                          trailing: Text(
                            '${m.toStringAsFixed(1)} LT',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6), fontSize: 14),
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
