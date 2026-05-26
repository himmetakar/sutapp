import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class FirmaAracAtamaScreen extends StatefulWidget {
  const FirmaAracAtamaScreen({super.key});

  @override
  State<FirmaAracAtamaScreen> createState() => _FirmaAracAtamaScreenState();
}

class _FirmaAracAtamaScreenState extends State<FirmaAracAtamaScreen> {
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'Personele Araç Atama',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('suruculer')
              .where('firma', isEqualTo: currentFirmaName)
              .snapshots(),
          builder: (context, driverSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('araclar')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, vehicleSnapshot) {
                if (driverSnapshot.connectionState == ConnectionState.waiting ||
                    vehicleSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final drivers = driverSnapshot.data?.docs ?? [];
                final vehicles = vehicleSnapshot.data?.docs ?? [];

                // Count stats
                final totalDrivers = drivers.length;
                final totalVehicles = vehicles.length;

                // Find assigned and empty stats
                final assignedVehicles = <String>{}; // plates of assigned vehicles
                final driverAssignments = <String, String>{}; // map of driver name -> vehicle plate

                for (var vDoc in vehicles) {
                  final vData = vDoc.data() as Map<String, dynamic>;
                  final plate = vData['plaka'] ?? '';
                  final assignedDrivers = List<String>.from(vData['suruculer'] ?? []);
                  if (assignedDrivers.isNotEmpty) {
                    assignedVehicles.add(plate);
                    for (var dName in assignedDrivers) {
                      driverAssignments[dName] = plate;
                    }
                  }
                }

                final totalAssigned = assignedVehicles.length;
                final totalEmpty = totalVehicles - totalAssigned;

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Stats strip (Personel, Araç, Atanmış, Boş)
                    Row(
                      children: [
                        _buildStatBox('Personel', '$totalDrivers', Colors.blue, Icons.people_rounded),
                        const SizedBox(width: 8),
                        _buildStatBox('Araç', '$totalVehicles', Colors.green, Icons.local_shipping_rounded),
                        const SizedBox(width: 8),
                        _buildStatBox('Atanmış', '$totalAssigned', Colors.orange, Icons.link_rounded),
                        const SizedBox(width: 8),
                        _buildStatBox('Boş', '$totalEmpty', Colors.red, Icons.link_off_rounded),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Section: Personel Araç Atamaları
                    Text(
                      'Personel Araç Atamaları',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (drivers.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text('Kayıtlı personel bulunamadı.', style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13)),
                        ),
                      )
                    else
                      ...drivers.map((dDoc) {
                        final dData = dDoc.data() as Map<String, dynamic>;
                        final ad = dData['ad'] ?? '';
                        final soyad = dData['soyad'] ?? '';
                        final name = '$ad $soyad'.trim();
                        final email = dData['email'] ?? '';
                        final tel = dData['tel'] ?? '';

                        final assignedPlate = driverAssignments[name];

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
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          name,
                                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          email.isNotEmpty ? email : '-',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          tel.isNotEmpty ? tel : '-',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: assignedPlate != null ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          assignedPlate != null ? Icons.check : Icons.info_outline_rounded,
                                          size: 11,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          assignedPlate ?? 'Atanmadı',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 36,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF2563EB),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _showVehicleSelectorDialog(name, vehicles, driverAssignments),
                                        icon: const Icon(Icons.link_rounded, size: 16),
                                        label: Text(
                                          assignedPlate != null ? 'Araç Değiştir' : 'Araç Ata',
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (assignedPlate != null) ...[
                                    const SizedBox(width: 12),
                                    SizedBox(
                                      height: 36,
                                      child: ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFEF4444),
                                          foregroundColor: Colors.white,
                                          elevation: 0,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        onPressed: () => _removeAssignment(name, vehicles),
                                        icon: const Icon(Icons.link_off_rounded, size: 16),
                                        label: Text(
                                          'Kaldır',
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 24),

                    // Section: Araç Durumu
                    Text(
                      'Araç Durumu',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.gray800,
                      ),
                    ),
                    const SizedBox(height: 10),

                    if (vehicles.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: Text('Kayıtlı araç bulunamadı.', style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13)),
                        ),
                      )
                    else
                      ...vehicles.map((vDoc) {
                        final vData = vDoc.data() as Map<String, dynamic>;
                        final plate = vData['plaka'] ?? '';
                        final model = vData['model'] ?? 'Bilinmiyor';
                        final yil = vData['yil'] ?? '';

                        // Find driver assigned to this vehicle
                        String? assignedDriver;
                        final assignedDrivers = List<String>.from(vData['suruculer'] ?? []);
                        if (assignedDrivers.isNotEmpty) {
                          assignedDriver = assignedDrivers.first;
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
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
                                    plate,
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$model • $yil',
                                    style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: assignedDriver != null ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      assignedDriver != null ? Icons.person_rounded : Icons.close,
                                      size: 11,
                                      color: Colors.white,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      assignedDriver ?? 'Boşta',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
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
            ),
          ],
        ),
      ),
    );
  }

  void _showVehicleSelectorDialog(
    String driverName,
    List<QueryDocumentSnapshot> vehicles,
    Map<String, String> currentAssignments,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$driverName İçin Araç Seçin', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final vDoc = vehicles[index];
              final vData = vDoc.data() as Map<String, dynamic>? ?? {};
              final plate = vData['plaka'] ?? '';
              final model = vData['model'] ?? 'Bilinmiyor';

              // Check if already assigned to someone else
              String? driverAssigned;
              final assignedList = List<String>.from(vData['suruculer'] ?? []);
              if (assignedList.isNotEmpty) {
                driverAssigned = assignedList.first;
              }

              return ListTile(
                title: Text(plate, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('$model ${driverAssigned != null ? '(Şu anki sürücü: $driverAssigned)' : '(Boşta)'}', style: GoogleFonts.inter(fontSize: 11)),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _assignVehicle(driverName, plate, vehicles);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Kapat', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
        ],
      ),
    );
  }

  Future<void> _assignVehicle(String driverName, String plate, List<QueryDocumentSnapshot> vehicles) async {
    try {
      // 1. Remove this driver from any other vehicle first
      for (var vDoc in vehicles) {
        final vData = vDoc.data() as Map<String, dynamic>? ?? {};
        final List<String> suruculer = List<String>.from(vData['suruculer'] ?? []);
        if (suruculer.contains(driverName)) {
          suruculer.remove(driverName);
          await vDoc.reference.update({'suruculer': suruculer});
        }
      }

      // 2. Add driver to selected vehicle
      final targetDoc = vehicles.firstWhere((v) {
        final vData = v.data() as Map<String, dynamic>? ?? {};
        return vData['plaka'] == plate;
      });
      final targetData = targetDoc.data() as Map<String, dynamic>? ?? {};
      final List<String> suruculer = List<String>.from(targetData['suruculer'] ?? []);
      if (!suruculer.contains(driverName)) {
        suruculer.add(driverName);
        await targetDoc.reference.update({'suruculer': suruculer});
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$driverName isimli personele $plate plakalı araç atandı.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _removeAssignment(String driverName, List<QueryDocumentSnapshot> vehicles) async {
    try {
      // Remove this driver from all vehicles
      for (var vDoc in vehicles) {
        final vData = vDoc.data() as Map<String, dynamic>? ?? {};
        final List<String> suruculer = List<String>.from(vData['suruculer'] ?? []);
        if (suruculer.contains(driverName)) {
          suruculer.remove(driverName);
          await vDoc.reference.update({'suruculer': suruculer});
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$driverName isimli personelden araç ataması kaldırıldı.'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}
