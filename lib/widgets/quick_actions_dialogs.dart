import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../config/theme.dart';
import '../services/firestore_service.dart';
import 'common_widgets.dart';
import 'sut_analiz_dialog.dart';
import 'milk_loading_indicator.dart';

class QuickActionsDialogs {
  static void showSutGirisiDialog(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final miktarCtrl = TextEditingController();
    String? selectedUretici;
    String? selectedTank;
    String? selectedMilkType;
    String? selectedCustomerType;
    const List<String> milkTypes = ['Soğuk Süt', 'Sıcak Süt', 'C kalite', 'D kalite'];

    debugPrint('showSutGirisiDialog: currentFirmaName = "$currentFirmaName"');
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<QuerySnapshot>(
        future: FirestoreService().getQueryWithCachePriority(
          FirebaseFirestore.instance
              .collection('ureticiler')
              .where('firmalar', arrayContains: currentFirmaName),
        ),
        builder: (ctx1, ureticiSnapshot) {
          if (ureticiSnapshot.hasError) {
            debugPrint('showSutGirisiDialog: uretici query error: ${ureticiSnapshot.error}');
            return AlertDialog(
              title: const Text('Hata'),
              content: Text('Üretici verileri yüklenirken hata oluştu: ${ureticiSnapshot.error}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kapat'),
                ),
              ],
            );
          }
          return FutureBuilder<QuerySnapshot>(
            future: FirestoreService().getQueryWithCachePriority(
              FirebaseFirestore.instance.collection('tanklar').where('firma', isEqualTo: currentFirmaName),
            ),
            builder: (ctx2, tankSnapshot) {
              if (tankSnapshot.hasError) {
                debugPrint('showSutGirisiDialog: tank query error: ${tankSnapshot.error}');
                return AlertDialog(
                  title: const Text('Hata'),
                  content: Text('Tank verileri yüklenirken hata oluştu: ${tankSnapshot.error}'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Kapat'),
                    ),
                  ],
                );
              }

              if (!ureticiSnapshot.hasData || !tankSnapshot.hasData) {
                return const AlertDialog(
                  content: SizedBox(
                    height: 80,
                    child: Center(child: MilkLoadingIndicator(size: 60)),
                  ),
                );
              }

              final producers = ureticiSnapshot.data!.docs
                  .map((doc) {
                    try {
                      final data = doc.data() as Map<String, dynamic>?;
                      return data?['name']?.toString() ?? '';
                    } catch (_) {
                      return '';
                    }
                  })
                  .where((name) => name.isNotEmpty)
                  .toSet()
                  .toList();

              final tanks = tankSnapshot.data!.docs
                  .map((doc) {
                    try {
                      final data = doc.data() as Map<String, dynamic>?;
                      return data?['ad']?.toString() ?? '';
                    } catch (_) {
                      return '';
                    }
                  })
                  .where((ad) => ad.isNotEmpty)
                  .toSet()
                  .toList();

              debugPrint('showSutGirisiDialog: fetched ${producers.length} producers and ${tanks.length} tanks');

              if (producers.isEmpty || tanks.isEmpty) {
                return AlertDialog(
                  title: const Text('Bilgi'),
                  content: Text('Sistemde kayıtlı üretici veya tank bulunamadı! (Firma: $currentFirmaName)'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Kapat'),
                    ),
                  ],
                );
              }

              String normalize(String? raw) {
                if (raw == null) return 'Soğuk Süt';
                final norm = raw.trim().toLowerCase();
                if (norm == 'a kalite' || norm == 'soğuk süt') return 'Soğuk Süt';
                if (norm == 'b kalite' || norm == 'sıcak süt') return 'Sıcak Süt';
                if (norm == 'c kalite') return 'C kalite';
                if (norm == 'd kalite') return 'D kalite';
                return raw;
              }

              if (selectedUretici == null || !producers.contains(selectedUretici)) {
                selectedUretici = producers.first;
                try {
                  final prodDoc = ureticiSnapshot.data!.docs.firstWhere((doc) => doc['name'] == selectedUretici);
                  final docData = prodDoc.data() as Map<String, dynamic>;
                  selectedMilkType = normalize(docData['lastMilkType']);
                  selectedCustomerType = docData['customerType'] ?? 'sut';
                } catch (_) {
                  selectedMilkType = 'Soğuk Süt';
                  selectedCustomerType = 'sut';
                }
              } else if (selectedCustomerType == null) {
                try {
                  final prodDoc = ureticiSnapshot.data!.docs.firstWhere((doc) => doc['name'] == selectedUretici);
                  final docData = prodDoc.data() as Map<String, dynamic>;
                  selectedCustomerType = docData['customerType'] ?? 'sut';
                } catch (_) {
                  selectedCustomerType = 'sut';
                }
              }

              if (selectedMilkType == null || !milkTypes.contains(selectedMilkType)) {
                selectedMilkType = 'Soğuk Süt';
              }

              if (selectedTank == null || !tanks.contains(selectedTank)) {
                selectedTank = tanks.first;
              }

              return StatefulBuilder(
                builder: (context, setDialogState) => AlertDialog(
                  title: Text('Süt Girişi Yap (Süt Al)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SearchableDropdown(
                          items: producers,
                          value: selectedUretici,
                          hint: 'Üretici seçin veya yazın',
                          label: 'Üretici *',
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedUretici = val;
                                try {
                                  final prodDoc = ureticiSnapshot.data!.docs.firstWhere((doc) => doc['name'] == selectedUretici);
                                  final docData = prodDoc.data() as Map<String, dynamic>;
                                  selectedMilkType = normalize(docData['lastMilkType']);
                                  selectedCustomerType = docData['customerType'] ?? 'sut';
                                } catch (_) {
                                  selectedMilkType = 'Soğuk Süt';
                                  selectedCustomerType = 'sut';
                                }
                                if (selectedMilkType == null || !milkTypes.contains(selectedMilkType)) {
                                  selectedMilkType = 'Soğuk Süt';
                                }
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedTank,
                          decoration: const InputDecoration(labelText: 'Hedef Tank'),
                          items: tanks.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedTank = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedMilkType,
                          decoration: const InputDecoration(labelText: 'Süt Tipi'),
                          items: milkTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                          onChanged: (val) {
                            if (val != null) setDialogState(() => selectedMilkType = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: selectedCustomerType,
                          decoration: InputDecoration(
                            labelText: 'Üretici Türü',
                            fillColor: selectedCustomerType == 'yem' ? Colors.amber[50] : AppColors.gray50,
                            filled: true,
                          ),
                          items: const [
                            DropdownMenuItem(value: 'sut', child: Text('Süt Üreticisi')),
                            DropdownMenuItem(value: 'yem', child: Text('Yem Müşterisi')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedCustomerType = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: miktarCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Miktar (Litre)', hintText: 'Örn: 250', suffixText: 'LT'),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              if (selectedUretici != null) {
                                SutAnalizDialog.show(
                                  context,
                                  targetName: selectedUretici!,
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
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500))),
                    ElevatedButton(
                      onPressed: () async {
                        final double? miktar = double.tryParse(miktarCtrl.text);
                        if (miktar == null || miktar <= 0) return;

                        double targetCapacity = 2000.0;
                        double targetCurrentStock = 0.0;
                        try {
                          final tankDoc = tankSnapshot.data!.docs.firstWhere((doc) => doc['ad'] == selectedTank);
                          targetCapacity = (tankDoc['kap'] as num?)?.toDouble() ?? 2000.0;
                          targetCurrentStock = (tankDoc['stok'] as num?)?.toDouble() ?? 0.0;
                        } catch (_) {}

                        final bool isOverflow = (targetCurrentStock + miktar > targetCapacity);

                        // Run in background without awaiting to prevent UI hang when offline
                        FirestoreService().recordMilkCollection(
                          producerName: selectedUretici!,
                          tankName: selectedTank!,
                          miktar: miktar,
                          sutTipi: selectedMilkType ?? 'Soğuk Süt',
                          customerType: selectedCustomerType ?? 'sut',
                        );

                        Navigator.pop(ctx);
                        if (isOverflow) {
                          _showLimitExceededDialog(context, selectedTank!);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$selectedUretici üreticisinden $selectedTank tankına ${miktar.toStringAsFixed(0)} LT süt girişi kaydedildi!'),
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
                      child: const Text('Kaydet'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  static void showSutKabulDialog(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final miktarCtrl = TextEditingController();
    String? selectedSourceVehicle;
    String? selectedSourceTank;
    String? selectedTargetTank;

    debugPrint('showSutKabulDialog: currentFirmaName = "$currentFirmaName"');
    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('araclar')
            .where('active', isEqualTo: true)
            .where('firma', isEqualTo: currentFirmaName)
            .get(),
        builder: (ctx1, vehicleSnapshot) {
          if (vehicleSnapshot.hasError) {
            debugPrint('showSutKabulDialog: vehicle query error: ${vehicleSnapshot.error}');
            return AlertDialog(
              title: const Text('Hata'),
              content: Text('Araç verileri yüklenirken hata oluştu: ${vehicleSnapshot.error}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Kapat'),
                ),
              ],
            );
          }
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('tanklar')
                .where('tip', isEqualTo: 'merkez')
                .where('firma', isEqualTo: currentFirmaName)
                .get(),
            builder: (ctx2, targetTankSnapshot) {
              if (targetTankSnapshot.hasError) {
                debugPrint('showSutKabulDialog: targetTank query error: ${targetTankSnapshot.error}');
                return AlertDialog(
                  title: const Text('Hata'),
                  content: Text('Hedef tank verileri yüklenirken hata oluştu: ${targetTankSnapshot.error}'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Kapat'),
                    ),
                  ],
                );
              }

              if (!vehicleSnapshot.hasData || !targetTankSnapshot.hasData) {
                return const AlertDialog(
                  content: SizedBox(
                    height: 80,
                    child: Center(child: MilkLoadingIndicator(size: 60)),
                  ),
                );
              }

              final vehicles = vehicleSnapshot.data!.docs;
              final targetTanks = targetTankSnapshot.data!.docs
                  .map((doc) {
                    try {
                      final data = doc.data() as Map<String, dynamic>?;
                      return data?['ad']?.toString() ?? '';
                    } catch (_) {
                      return '';
                    }
                  })
                  .where((ad) => ad.isNotEmpty)
                  .toSet()
                  .toList();

              debugPrint('showSutKabulDialog: fetched ${vehicles.length} vehicles and ${targetTanks.length} target tanks');

              if (vehicles.isEmpty || targetTanks.isEmpty) {
                return AlertDialog(
                  title: const Text('Bilgi'),
                  content: Text('Sistemde aktif araç veya merkez tankı bulunamadı! (Firma: $currentFirmaName)'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Kapat'),
                    ),
                  ],
                );
              }

              return StatefulBuilder(
                builder: (context, setDialogState) {
                  if (selectedSourceVehicle == null || !vehicles.any((v) => v['plaka'] == selectedSourceVehicle)) {
                    selectedSourceVehicle = vehicles.first['plaka'] as String;
                  }
                  
                  if (selectedTargetTank == null || !targetTanks.contains(selectedTargetTank)) {
                    selectedTargetTank = targetTanks.first;
                  }

                  final currentVehicleDoc = vehicles.firstWhere((doc) => doc['plaka'] == selectedSourceVehicle);
                  final sourceTanks = (currentVehicleDoc['tanklar'] as List? ?? [])
                      .map((t) => t['ad'] as String)
                      .toSet()
                      .toList();
                  if (sourceTanks.isNotEmpty) {
                    if (selectedSourceTank == null || !sourceTanks.contains(selectedSourceTank)) {
                      selectedSourceTank = sourceTanks.first;
                    }
                  } else {
                    selectedSourceTank = null;
                  }

                  return AlertDialog(
                    title: Text('Süt Kabul İşlemi (Transfer)', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    content: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<String>(
                            value: selectedSourceVehicle,
                            decoration: const InputDecoration(labelText: 'Kaynak Araç (Tank)'),
                            items: vehicles.map((v) {
                              final plate = v['plaka'] as String;
                              return DropdownMenuItem(value: plate, child: Text(plate));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedSourceVehicle = val;
                                  final vDoc = vehicles.firstWhere((doc) => doc['plaka'] == val);
                                  final sTanks = (vDoc['tanklar'] as List? ?? [])
                                      .map((t) => t['ad'] as String)
                                      .toSet()
                                      .toList();
                                  selectedSourceTank = sTanks.isNotEmpty ? sTanks.first : null;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: 12),
                          if (sourceTanks.isNotEmpty)
                            DropdownButtonFormField<String>(
                              value: selectedSourceTank,
                              decoration: const InputDecoration(labelText: 'Kaynak Tank'),
                              items: sourceTanks.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                              onChanged: (val) {
                                if (val != null) setDialogState(() => selectedSourceTank = val);
                              },
                            )
                          else
                            const Padding(
                              padding: EdgeInsets.only(top: 8.0),
                              child: Text(
                                'Bu araç üzerinde tank bulunmuyor!',
                                style: TextStyle(color: AppColors.danger, fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: selectedTargetTank,
                            decoration: const InputDecoration(labelText: 'Hedef Merkez Tankı'),
                            items: targetTanks.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                            onChanged: (val) {
                              if (val != null) setDialogState(() => selectedTargetTank = val);
                            },
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: miktarCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Kabul Miktarı (Litre)', hintText: 'Örn: 1000', suffixText: 'LT'),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500))),
                      ElevatedButton(
                        onPressed: (selectedSourceTank == null) ? null : () async {
                          final double? miktar = double.tryParse(miktarCtrl.text);
                          if (miktar == null || miktar <= 0) return;

                          final currentVehicleTanks = currentVehicleDoc['tanklar'] as List? ?? [];
                          final sourceTankInfo = currentVehicleTanks.firstWhere((t) => t['ad'] == selectedSourceTank);
                          final double availableSourceStock = (sourceTankInfo['stok'] as num?)?.toDouble() ?? 0.0;

                          if (miktar > availableSourceStock) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Hata: Kaynak tankta yeterli süt yok! Mevcut: ${availableSourceStock.toStringAsFixed(0)} LT.'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                            return;
                          }

                          final targetTankDoc = targetTankSnapshot.data!.docs.firstWhere((doc) => doc['ad'] == selectedTargetTank);
                          final double targetCurrentStock = (targetTankDoc['stok'] as num?)?.toDouble() ?? 0.0;
                          final double targetCapacity = (targetTankDoc['kap'] as num?)?.toDouble() ?? 2000.0;

                          final bool isOverflow = (targetCurrentStock + miktar > targetCapacity);

                          await FirestoreService().recordMilkTransfer(
                            vehiclePlate: selectedSourceVehicle!,
                            sourceTankName: selectedSourceTank!,
                            targetTankName: selectedTargetTank!,
                            miktar: miktar,
                          );

                          Navigator.pop(ctx);
                          if (isOverflow) {
                            _showLimitExceededDialog(context, selectedTargetTank!);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('$selectedSourceVehicle tankından $selectedTargetTank merkez tankına ${miktar.toStringAsFixed(0)} LT süt kabul edildi!'),
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
                        child: const Text('Kabul Et'),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  static void showTahsilatDialog(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.white,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) {
        return _TahsilatEkleScreen(currentFirmaName: currentFirmaName);
      },
    );
  }

  static void _showLimitExceededDialog(BuildContext context, String tankName, {VoidCallback? onDismiss}) {
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

class _TahsilatEkleScreen extends StatefulWidget {
  final String currentFirmaName;
  const _TahsilatEkleScreen({required this.currentFirmaName});

  @override
  State<_TahsilatEkleScreen> createState() => _TahsilatEkleScreenState();
}

class _TahsilatEkleScreenState extends State<_TahsilatEkleScreen> {
  final _tutarCtrl = TextEditingController(text: '0.00');
  final _aciklamaCtrl = TextEditingController();
  String? _selectedFirma;
  String _odemeYontemi = 'Nakit'; // Nakit, Banka, Çek
  bool _isSaving = false;

  List<String> _firmalar = [];
  bool _isLoadingFirmalar = true;

  @override
  void initState() {
    super.initState();
    _loadFirmalar();
  }

  Future<void> _loadFirmalar() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('satislar')
          .where('firma', isEqualTo: widget.currentFirmaName)
          .get();

      final Set<String> buyerSet = {};
      for (var doc in snapshot.docs) {
        final buyer = doc.data()['buyer'] as String?;
        if (buyer != null && buyer.trim().isNotEmpty) {
          buyerSet.add(buyer.trim());
        }
      }

      final staticBuyers = [
        'Sütaş',
        'Pınar Süt',
        'Torku Süt',
        'İçim (Ak Gıda)',
        'Sek Süt',
        'Yörükoğlu',
        'Danone Türkiye',
        'Kaanlar Gıda',
        'Süteks',
      ];
      for (var b in staticBuyers) {
        buyerSet.add(b);
      }

      setState(() {
        _firmalar = buyerSet.toList()..sort();
        if (_firmalar.contains('Sütaş')) {
          _selectedFirma = 'Sütaş';
        } else if (_firmalar.isNotEmpty) {
          _selectedFirma = _firmalar.first;
        }
        _isLoadingFirmalar = false;
      });
    } catch (e) {
      setState(() {
        _firmalar = [
          'Sütaş',
          'Pınar Süt',
          'Torku Süt',
          'İçim (Ak Gıda)',
          'Sek Süt',
          'Yörükoğlu',
          'Danone Türkiye',
          'Kaanlar Gıda',
          'Süteks',
        ];
        _selectedFirma = 'Sütaş';
        _isLoadingFirmalar = false;
      });
    }
  }

  @override
  void dispose() {
    _tutarCtrl.dispose();
    _aciklamaCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveTahsilat() async {
    final double? tutar = double.tryParse(_tutarCtrl.text.replaceAll(',', '.'));
    if (_selectedFirma == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen bir firma seçin!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }
    if (tutar == null || tutar <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir tutar girin!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await FirestoreService().recordTahsilat(
        producerName: _selectedFirma!,
        tutar: tutar,
        odemeYontemi: _odemeYontemi,
        aciklama: _aciklamaCtrl.text,
        firma: widget.currentFirmaName,
        tip: 'tahsilat',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_selectedFirma firmasından ${tutar.toStringAsFixed(2)} ₺ tahsilat kaydı oluşturuldu!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata oluştu: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Widget _buildPaymentMethodButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final primaryColor = AppColors.primary500;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor : Colors.white,
          border: Border.all(
            color: isSelected ? primaryColor : AppColors.gray200,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : AppColors.gray600,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.gray700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Custom AppBar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // İptal Button
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'İptal',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.normal,
                        color: AppColors.gray500,
                      ),
                    ),
                  ),
                  // Title
                  Text(
                    'Tahsilat Ekle',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gray800,
                    ),
                  ),
                  // Kaydet Button
                  GestureDetector(
                    onTap: _isSaving ? null : _saveTahsilat,
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            'Kaydet',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary600,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const Divider(color: AppColors.gray100, height: 1, thickness: 1.5),

            // Scrollable Content
            Expanded(
              child: _isLoadingFirmalar
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Firma Seçin *
                          Text(
                            'Firma Seçin *',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.gray800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // List of companies in a card/container
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.gray200, width: 1.5),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _firmalar.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(color: AppColors.gray100, height: 1, thickness: 1),
                              itemBuilder: (context, index) {
                                final firmaName = _firmalar[index];
                                final isSelected = _selectedFirma == firmaName;
                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedFirma = firmaName;
                                    });
                                  },
                                  borderRadius: index == 0
                                      ? const BorderRadius.vertical(top: Radius.circular(11))
                                      : index == _firmalar.length - 1
                                          ? const BorderRadius.vertical(bottom: Radius.circular(11))
                                          : null,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          firmaName,
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                            color: isSelected ? AppColors.primary600 : AppColors.gray800,
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: AppColors.primary600,
                                            size: 20,
                                          )
                                        else
                                          const Icon(
                                            Icons.radio_button_off_rounded,
                                            color: AppColors.gray300,
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Tutar (₺) *
                          Text(
                            'Tutar (₺) *',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.gray800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _tutarCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              hintText: '0.00',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.gray200, width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.gray200, width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.primary400, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            ),
                            style: GoogleFonts.inter(fontSize: 15, color: AppColors.gray800),
                            onTap: () {
                              if (_tutarCtrl.text == '0.00') {
                                _tutarCtrl.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: _tutarCtrl.text.length,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // Ödeme Yöntemi
                          Text(
                            'Ödeme Yöntemi',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.gray800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPaymentMethodButton(
                                  label: 'Nakit',
                                  icon: Icons.payments_outlined,
                                  isSelected: _odemeYontemi == 'Nakit',
                                  onTap: () => setState(() => _odemeYontemi = 'Nakit'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildPaymentMethodButton(
                                  label: 'Banka',
                                  icon: Icons.account_balance_rounded,
                                  isSelected: _odemeYontemi == 'Banka',
                                  onTap: () => setState(() => _odemeYontemi = 'Banka'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildPaymentMethodButton(
                                  label: 'Çek',
                                  icon: Icons.receipt_long_rounded,
                                  isSelected: _odemeYontemi == 'Çek',
                                  onTap: () => setState(() => _odemeYontemi = 'Çek'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Açıklama
                          Text(
                            'Açıklama',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: AppColors.gray800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _aciklamaCtrl,
                            maxLines: 4,
                            minLines: 3,
                            decoration: InputDecoration(
                              hintText: 'Açıklama',
                              alignLabelWithHint: true,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.gray200, width: 1.5),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.gray200, width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: AppColors.primary400, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                            ),
                            style: GoogleFonts.inter(fontSize: 15, color: AppColors.gray800),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
