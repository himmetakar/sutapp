import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaTankAtamaScreen extends StatefulWidget {
  const FirmaTankAtamaScreen({super.key});

  @override
  State<FirmaTankAtamaScreen> createState() => _FirmaTankAtamaScreenState();
}

class _FirmaTankAtamaScreenState extends State<FirmaTankAtamaScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  bool _isLoading = false;

  void _showTankSelectorDialog(
    String vehiclePlate,
    List<String> vehicleDrivers,
    List<QueryDocumentSnapshot> allTanks,
    List<String> currentTankNames,
  ) {
    // List only tanks of type 'arac'
    final aracTanks = allTanks.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['tip'] ?? 'merkez') == 'arac';
    }).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        final selectedTanks = Set<String>.from(currentTankNames);

        return StatefulBuilder(
          builder: (context, setDialogState) {
            if (_isLoading) {
              return const AlertDialog(
                content: SizedBox(
                  height: 80,
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }

            return AlertDialog(
              title: Text('$vehiclePlate İçin Tank Seçin', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: double.maxFinite,
                child: aracTanks.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Sistemde kayıtlı araç tankı bulunmuyor.',
                          style: GoogleFonts.inter(color: AppColors.gray400, fontSize: 13),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bu araca atamak istediğiniz tankları işaretleyin. Bir tank sadece tek bir araca atanabilir.',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                          ),
                          const SizedBox(height: 12),
                          Flexible(
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: aracTanks.length,
                              itemBuilder: (context, index) {
                                final doc = aracTanks[index];
                                final data = doc.data() as Map<String, dynamic>;
                                final name = data['ad'] ?? '';
                                final cap = (data['kap'] as num?)?.toDouble() ?? 2000.0;
                                final currentAssignedVehicle = data['arac'] ?? '';

                                final isSelected = selectedTanks.contains(name);
                                final isAssignedToOther = currentAssignedVehicle.isNotEmpty && currentAssignedVehicle != vehiclePlate;

                                String subtitle = '${cap.toStringAsFixed(0)} LT';
                                if (isAssignedToOther) {
                                  subtitle += ' (Atandığı Araç: $currentAssignedVehicle)';
                                } else if (currentAssignedVehicle == vehiclePlate) {
                                  subtitle += ' (Bu Araçta)';
                                } else {
                                  subtitle += ' (Boşta)';
                                }

                                return CheckboxListTile(
                                  title: Text(name, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: isAssignedToOther ? AppColors.gray400 : AppColors.gray800)),
                                  subtitle: Text(subtitle, style: GoogleFonts.inter(fontSize: 11, color: isAssignedToOther ? Colors.red[300] : AppColors.gray500)),
                                  value: isSelected,
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: isAssignedToOther
                                      ? null // disable selection if assigned to another vehicle
                                      : (val) {
                                          setDialogState(() {
                                            if (val == true) {
                                              selectedTanks.add(name);
                                            } else {
                                              selectedTanks.remove(name);
                                            }
                                          });
                                        },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    setDialogState(() => _isLoading = true);
                    setState(() => _isLoading = true);
                    try {
                      final batch = _db.batch();

                      // 1. Build new tank list for the vehicle document
                      final newVehicleTanks = <Map<String, dynamic>>[];

                      for (var doc in aracTanks) {
                        final data = doc.data() as Map<String, dynamic>;
                        final String name = data['ad'] ?? '';
                        final String currentVehicle = data['arac'] ?? '';
                        final double stock = (data['stok'] as num?)?.toDouble() ?? 0.0;
                        final double capacity = (data['kap'] as num?)?.toDouble() ?? 2000.0;

                        if (selectedTanks.contains(name)) {
                          newVehicleTanks.add({
                            'ad': name,
                            'stok': stock,
                            'kap': capacity,
                            'suruculer': vehicleDrivers,
                          });

                          // Update tank document: bind to this vehicle and copy its drivers
                          batch.update(doc.reference, {
                            'arac': vehiclePlate,
                            'suruculer': vehicleDrivers,
                          });
                        } else {
                          // If this tank was previously assigned to this vehicle, clear it
                          if (currentVehicle == vehiclePlate) {
                            batch.update(doc.reference, {
                              'arac': '',
                              'suruculer': <String>[],
                            });
                          }
                        }
                      }

                      // 2. Query and update vehicle document's 'tanklar' array
                      final vehicleQuery = await _db
                          .collection('araclar')
                          .where('plaka', isEqualTo: vehiclePlate)
                          .limit(1)
                          .get();

                      if (vehicleQuery.docs.isNotEmpty) {
                        batch.update(vehicleQuery.docs.first.reference, {
                          'tanklar': newVehicleTanks,
                        });
                      }

                      await batch.commit();

                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$vehiclePlate aracının tank atamaları güncellendi.'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: AppColors.danger),
                      );
                    } finally {
                      if (mounted) {
                        setState(() => _isLoading = false);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Ata'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _removeTankAssignment(String vehiclePlate, String tankName, double capacity, List<QueryDocumentSnapshot> allTanks) async {
    setState(() => _isLoading = true);
    try {
      final batch = _db.batch();

      // Find the tank document
      final tankDoc = allTanks.firstWhere((t) => (t.data() as Map)['ad'] == tankName);
      batch.update(tankDoc.reference, {
        'arac': '',
        'suruculer': <String>[],
      });

      // Find vehicle
      final vehicleQuery = await _db
          .collection('araclar')
          .where('plaka', isEqualTo: vehiclePlate)
          .limit(1)
          .get();

      if (vehicleQuery.docs.isNotEmpty) {
        final vDoc = vehicleQuery.docs.first;
        final vData = vDoc.data();
        final currentTanks = List<Map<String, dynamic>>.from(vData['tanklar'] ?? []);
        currentTanks.removeWhere((t) => t['ad'] == tankName);
        batch.update(vDoc.reference, {
          'tanklar': currentTanks,
        });
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('"$tankName" tankı araçtan kaldırıldı.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenantFirma = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'Tank Atama',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _db
              .collection('araclar')
              .where('firma', isEqualTo: tenantFirma)
              .snapshots(),
          builder: (context, vehicleSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('tanklar')
                  .where('firma', isEqualTo: tenantFirma)
                  .snapshots(),
              builder: (context, tankSnapshot) {
                if (vehicleSnapshot.connectionState == ConnectionState.waiting ||
                    tankSnapshot.connectionState == ConnectionState.waiting ||
                    _isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                final vehicles = vehicleSnapshot.data?.docs ?? [];
                final tanks = tankSnapshot.data?.docs ?? [];

                // Filter only 'arac' type tanks for assignment metrics
                final aracTanks = tanks.where((t) => (t.data() as Map)['tip'] == 'arac').toList();

                int totalVehicles = vehicles.length;
                int totalAracTanks = aracTanks.length;
                int assignedTanksCount = aracTanks.where((t) => ((t.data() as Map)['arac'] ?? '').isNotEmpty).length;
                int freeTanksCount = totalAracTanks - assignedTanksCount;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Stats boxes
                    Row(
                      children: [
                        _buildStatBox('Toplam Araç', '$totalVehicles', Colors.blue, Icons.local_shipping_rounded),
                        const SizedBox(width: 8),
                        _buildStatBox('Toplam Tank', '$totalAracTanks', Colors.teal, Icons.propane_tank_rounded),
                        const SizedBox(width: 8),
                        _buildStatBox('Atanmış', '$assignedTanksCount', Colors.orange, Icons.link_rounded),
                        const SizedBox(width: 8),
                        _buildStatBox('Boşta', '$freeTanksCount', Colors.red, Icons.link_off_rounded),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section header: Araçlar ve Atanan Tanklar
                    Text(
                      'Araçlar ve Atanan Tanklar',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                    ),
                    const SizedBox(height: 10),

                    if (vehicles.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Text('Kayıtlı araç bulunmuyor.', style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13)),
                        ),
                      )
                    else
                      ...vehicles.map((vDoc) {
                        final vData = vDoc.data() as Map<String, dynamic>;
                        final plate = vData['plaka'] ?? '';
                        final drivers = List<String>.from(vData['suruculer'] ?? []);
                        final vTanks = List<Map<String, dynamic>>.from(vData['tanklar'] ?? []);
                        final currentTankNames = vTanks.map((t) => t['ad'] as String).toList();

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.gray200),
                            boxShadow: AppShadows.sm,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Plate and drivers subtitle
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          plate,
                                          style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          drivers.isEmpty ? 'Sürücü Atanmamış' : 'Sürücüler: ${drivers.join(', ')}',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: vTanks.isNotEmpty ? AppColors.primary50 : AppColors.gray100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${vTanks.length} Tank Atandı',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: vTanks.isNotEmpty ? AppColors.primary600 : AppColors.gray500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 12),
                              const Divider(),
                              const SizedBox(height: 12),

                              // Assigned tanks list
                              if (vTanks.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Bu araca atanmış tank bulunmamaktadır.',
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400, fontStyle: FontStyle.italic),
                                  ),
                                )
                              else
                                ...vTanks.map((t) {
                                  final name = t['ad'] ?? '';
                                  final double kap = (t['kap'] as num?)?.toDouble() ?? 2000.0;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 6),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.gray50,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.gray100),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.propane_tank_rounded, color: AppColors.gray500, size: 16),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            '$name (${kap.toStringAsFixed(0)} LT)',
                                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.gray800),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.link_off_rounded, color: AppColors.danger, size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () => _removeTankAssignment(plate, name, kap, tanks),
                                          tooltip: 'Tank Atamasını Kaldır',
                                        ),
                                      ],
                                    ),
                                  );
                                }),

                              const SizedBox(height: 14),

                              // Edit assignment button
                              SizedBox(
                                width: double.infinity,
                                height: 36,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary600,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  onPressed: () => _showTankSelectorDialog(plate, drivers, tanks, currentTankNames),
                                  icon: const Icon(Icons.link_rounded, size: 16),
                                  label: Text(
                                    vTanks.isNotEmpty ? 'Tankları Düzenle' : 'Tank Ata',
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 24),

                    // Section header: Boştaki / Diğer Tanklar
                    Text(
                      'Tüm Araç Tankları Durumu',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                    ),
                    const SizedBox(height: 10),

                    if (aracTanks.isEmpty)
                      _buildEmptyState('Sistemde kayıtlı araç tankı bulunmuyor.')
                    else
                      ...aracTanks.map((tDoc) {
                        final data = tDoc.data() as Map<String, dynamic>;
                        final name = data['ad'] ?? '';
                        final cap = (data['kap'] as num?)?.toDouble() ?? 2000.0;
                        final assignedPlate = data['arac'] ?? '';

                        final isAssigned = assignedPlate.isNotEmpty;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray200),
                            boxShadow: AppShadows.sm,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Kapasite: ${cap.toStringAsFixed(0)} LT',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAssigned ? Colors.green[50] : Colors.red[50],
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  isAssigned ? 'Atandı: $assignedPlate' : 'Boşta',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isAssigned ? Colors.green[700] : Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 32),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              value,
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray500, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.inter(color: AppColors.gray400, fontSize: 12.5),
        ),
      ),
    );
  }
}
