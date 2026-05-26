import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class FirmaAraclar extends StatefulWidget {
  const FirmaAraclar({super.key});

  @override
  State<FirmaAraclar> createState() => _FirmaAraclarState();
}

class _FirmaAraclarState extends State<FirmaAraclar> {
  final _firestoreService = FirestoreService();

  void _showAddVehicleDialog() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final plakaCtrl = TextEditingController();
    
    final selectedDrivers = <String>{};
    final selectedTanks = <String>{};

    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('suruculer').where('firma', isEqualTo: currentFirmaName).get(),
        builder: (context, driverSnap) {
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('tanklar').where('tip', isEqualTo: 'arac').where('firma', isEqualTo: currentFirmaName).get(),
            builder: (context, tankSnap) {
              if (!driverSnap.hasData || !tankSnap.hasData) {
                return const AlertDialog(
                  content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                );
              }

              final drivers = driverSnap.data!.docs.map((d) => '${d['ad']} ${d['soyad']}').toList();
              final tanks = tankSnap.data!.docs.map((t) => {'ad': t['ad'] as String, 'kap': (t['kap'] as num).toDouble()}).toList();

              return StatefulBuilder(
                builder: (context, setDialogState) => AlertDialog(
                  title: Text('Yeni Araç Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: plakaCtrl,
                          decoration: const InputDecoration(labelText: 'Plaka (Zorunlu)', hintText: 'Örn: 34 TR 100'),
                        ),
                        const SizedBox(height: 16),
                        Text('Toplayıcı Seçimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray700)),
                        const SizedBox(height: 6),
                        if (drivers.isEmpty)
                          Text('Firma toplayıcısı bulunamadı.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400))
                        else
                          ...drivers.map((d) {
                            final isChecked = selectedDrivers.contains(d);
                            return CheckboxListTile(
                              title: Text(d, style: GoogleFonts.inter(fontSize: 13)),
                              value: isChecked,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedDrivers.add(d);
                                  } else {
                                    selectedDrivers.remove(d);
                                  }
                                });
                              },
                            );
                          }),
                        const SizedBox(height: 16),
                        Text('Tank Seçimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray700)),
                        const SizedBox(height: 6),
                        if (tanks.isEmpty)
                          Text('Firma araç tankı bulunamadı.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400))
                        else
                          ...tanks.map((t) {
                            final name = t['ad'] as String;
                            final cap = t['kap'] as double;
                            final isChecked = selectedTanks.contains(name);
                            return CheckboxListTile(
                              title: Text('$name (${cap.toStringAsFixed(0)} LT)', style: GoogleFonts.inter(fontSize: 13)),
                              value: isChecked,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedTanks.add(name);
                                  } else {
                                    selectedTanks.remove(name);
                                  }
                                });
                              },
                            );
                          }),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500))),
                    ElevatedButton(
                      onPressed: () async {
                        if (plakaCtrl.text.isEmpty) return;
                        final plate = plakaCtrl.text.toUpperCase().trim();

                        final existing = await FirebaseFirestore.instance.collection('araclar').where('plaka', isEqualTo: plate).limit(1).get();
                        if (existing.docs.isNotEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Hata: $plate plakalı araç zaten sisteme kayıtlı!'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                          return;
                        }

                        final tanklar = <Map<String, dynamic>>[];
                        for (var t in tanks) {
                          final name = t['ad'] as String;
                          if (selectedTanks.contains(name)) {
                            tanklar.add({
                              'ad': name,
                              'stok': 0.0,
                              'kap': t['kap'] as double,
                            });

                            final tankQuery = await FirebaseFirestore.instance.collection('tanklar').where('ad', isEqualTo: name).limit(1).get();
                            if (tankQuery.docs.isNotEmpty) {
                              await tankQuery.docs.first.reference.update({'arac': plate});
                            }
                          }
                        }

                        await _firestoreService.addVehicle({
                          'plaka': plate,
                          'suruculer': selectedDrivers.toList(),
                          'tanklar': tanklar,
                          'active': true,
                          'firma': currentFirmaName,
                        });

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Yeni araç başarıyla eklendi!'), backgroundColor: AppColors.success),
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
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showEditVehicleDialog(String docId, Map<String, dynamic> vehicleData) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final plakaCtrl = TextEditingController(text: vehicleData['plaka'] as String);

    final currentDriversList = List<String>.from(vehicleData['suruculer'] as List? ?? []);
    final currentTanksList = (vehicleData['tanklar'] as List? ?? []).map((t) => t['ad'] as String).toList();

    final selectedDrivers = Set<String>.from(currentDriversList);
    final selectedTanks = Set<String>.from(currentTanksList);

    showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance.collection('suruculer').where('firma', isEqualTo: currentFirmaName).get(),
        builder: (context, driverSnap) {
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance.collection('tanklar').where('tip', isEqualTo: 'arac').where('firma', isEqualTo: currentFirmaName).get(),
            builder: (context, tankSnap) {
              if (!driverSnap.hasData || !tankSnap.hasData) {
                return const AlertDialog(
                  content: SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
                );
              }

              final drivers = driverSnap.data!.docs.map((d) => '${d['ad']} ${d['soyad']}').toList();
              final tanks = tankSnap.data!.docs.map((t) => {'ad': t['ad'] as String, 'kap': (t['kap'] as num).toDouble()}).toList();

              return StatefulBuilder(
                builder: (context, setDialogState) => AlertDialog(
                  title: Text('Aracı Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: plakaCtrl,
                          decoration: const InputDecoration(labelText: 'Plaka (Zorunlu)', hintText: 'Örn: 34 TR 100'),
                        ),
                        const SizedBox(height: 16),
                        Text('Toplayıcı Seçimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray700)),
                        const SizedBox(height: 6),
                        if (drivers.isEmpty)
                          Text('Firma toplayıcısı bulunamadı.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400))
                        else
                          ...drivers.map((d) {
                            final isChecked = selectedDrivers.contains(d);
                            return CheckboxListTile(
                              title: Text(d, style: GoogleFonts.inter(fontSize: 13)),
                              value: isChecked,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedDrivers.add(d);
                                  } else {
                                    selectedDrivers.remove(d);
                                  }
                                });
                              },
                            );
                          }),
                        const SizedBox(height: 16),
                        Text('Tank Seçimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.gray700)),
                        const SizedBox(height: 6),
                        if (tanks.isEmpty)
                          Text('Firma araç tankı bulunamadı.', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400))
                        else
                          ...tanks.map((t) {
                            final name = t['ad'] as String;
                            final cap = t['kap'] as double;
                            final isChecked = selectedTanks.contains(name);
                            return CheckboxListTile(
                              title: Text('$name (${cap.toStringAsFixed(0)} LT)', style: GoogleFonts.inter(fontSize: 13)),
                              value: isChecked,
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                setDialogState(() {
                                  if (val == true) {
                                    selectedTanks.add(name);
                                  } else {
                                    selectedTanks.remove(name);
                                  }
                                });
                              },
                            );
                          }),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500))),
                    ElevatedButton(
                      onPressed: () async {
                        if (plakaCtrl.text.isEmpty) return;
                        final plate = plakaCtrl.text.toUpperCase().trim();

                        if (plate != vehicleData['plaka']) {
                          final existing = await FirebaseFirestore.instance.collection('araclar').where('plaka', isEqualTo: plate).limit(1).get();
                          if (existing.docs.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Hata: $plate plakalı araç zaten sisteme kayıtlı!'),
                                backgroundColor: AppColors.danger,
                              ),
                            );
                            return;
                          }
                        }

                        final tanklar = <Map<String, dynamic>>[];
                        for (var t in tanks) {
                          final name = t['ad'] as String;
                          if (selectedTanks.contains(name)) {
                            final currentTankMap = (vehicleData['tanklar'] as List? ?? []).firstWhere(
                              (ct) => ct['ad'] == name,
                              orElse: () => null,
                            );
                            final double stock = currentTankMap != null ? (currentTankMap['stok'] as num).toDouble() : 0.0;
                            tanklar.add({
                              'ad': name,
                              'stok': stock,
                              'kap': t['kap'] as double,
                            });

                            final tankQuery = await FirebaseFirestore.instance.collection('tanklar').where('ad', isEqualTo: name).limit(1).get();
                            if (tankQuery.docs.isNotEmpty) {
                              await tankQuery.docs.first.reference.update({'arac': plate});
                            }
                          } else {
                            final currentTankMap = (vehicleData['tanklar'] as List? ?? []).firstWhere(
                              (ct) => ct['ad'] == name,
                              orElse: () => null,
                            );
                            if (currentTankMap != null) {
                              final tankQuery = await FirebaseFirestore.instance.collection('tanklar').where('ad', isEqualTo: name).limit(1).get();
                              if (tankQuery.docs.isNotEmpty) {
                                await tankQuery.docs.first.reference.update({'arac': ''});
                              }
                            }
                          }
                        }

                        await _firestoreService.updateVehicle(docId, {
                          'plaka': plate,
                          'suruculer': selectedDrivers.toList(),
                          'tanklar': tanklar,
                          'active': vehicleData['active'] ?? true,
                          'firma': currentFirmaName,
                        });

                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Araç başarıyla güncellendi!'), backgroundColor: AppColors.success),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary600,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Güncelle'),
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

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      floatingActionButton: AppFab(
        icon: Icons.add_rounded,
        label: 'Araç Ekle',
        onTap: _showAddVehicleDialog,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getVehiclesStream(firma: currentFirmaName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Sistemde kayıtlı araç bulunmuyor.',
                style: GoogleFonts.inter(color: AppColors.gray500),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final a = doc.data() as Map<String, dynamic>;
              final plaka = a['plaka'] ?? '';
              final active = a['active'] as bool? ?? true;
              final suruculer = a['suruculer'] as List? ?? [];
              final tanklar = a['tanklar'] as List? ?? [];

              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.sm,
                ),
                child: Column(children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: active ? const LinearGradient(colors: [AppColors.primary50, Color(0xFFF0F4FF)]) : null,
                      color: active ? null : AppColors.gray50,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                    child: Row(children: [
                      Container(
                        width: 42, height: 42,
                        decoration: BoxDecoration(
                          gradient: active ? AppColors.primaryGradient : null,
                          color: active ? null : AppColors.gray200,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: active
                              ? [BoxShadow(color: AppColors.primary500.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 2))]
                              : null,
                        ),
                        child: Icon(Icons.local_shipping_rounded, color: active ? Colors.white : AppColors.gray400, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(plaka, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                        active ? StatusBadge.active() : StatusBadge.inactive(),
                      ])),
                      IconButton(
                        onPressed: () => _showEditVehicleDialog(doc.id, a),
                        icon: Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: AppShadows.sm),
                          child: const Icon(Icons.edit_rounded, size: 14, color: AppColors.gray500),
                        ),
                      ),
                    ]),
                  ),
                  // Toplayıcılar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                    child: Row(children: [
                      const Icon(Icons.badge_rounded, size: 13, color: AppColors.gray400),
                      const SizedBox(width: 5),
                      Text('Toplayıcılar (${suruculer.length})', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.gray500, letterSpacing: 0.3)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: suruculer.map<Widget>((s) => StatusBadge.info(s as String)).toList(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    child: Container(height: 1, color: AppColors.gray100),
                  ),
                  // Tanklar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                    child: Column(children: [
                      Row(children: [
                        const Icon(Icons.propane_tank_rounded, size: 13, color: AppColors.gray400),
                        const SizedBox(width: 5),
                        Text('Tanklar (${tanklar.length})', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.gray500)),
                      ]),
                      const SizedBox(height: 8),
                      ...tanklar.map<Widget>((t) {
                        final tank = t as Map;
                        final stok = (tank['stok'] as num?)?.toDouble() ?? 0.0;
                        final kap = (tank['kap'] as num?)?.toDouble() ?? 2000.0;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(8)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(tank['ad'] as String, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray700)),
                            const SizedBox(height: 4),
                            StockGauge(current: stok, capacity: kap),
                          ]),
                        );
                      }),
                    ]),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
