import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class FirmaPersonelPerformansScreen extends StatefulWidget {
  const FirmaPersonelPerformansScreen({super.key});

  @override
  State<FirmaPersonelPerformansScreen> createState() => _FirmaPersonelPerformansScreenState();
}

class _FirmaPersonelPerformansScreenState extends State<FirmaPersonelPerformansScreen> {
  String _selectedPeriod = 'Bugün'; // 'Bugün', 'Bu Ay', 'Bu Yıl'

  bool _isWithinPeriod(DateTime recordDate) {
    final now = DateTime.now();
    if (_selectedPeriod == 'Bugün') {
      return recordDate.year == now.year &&
          recordDate.month == now.month &&
          recordDate.day == now.day;
    } else if (_selectedPeriod == 'Bu Ay') {
      return recordDate.year == now.year && recordDate.month == now.month;
    } else {
      return recordDate.year == now.year;
    }
  }

  bool _isStringDateWithinPeriod(String dateStr) {
    try {
      final parts = dateStr.split('.');
      if (parts.length != 3) return false;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final recordDate = DateTime(year, month, day);
      return _isWithinPeriod(recordDate);
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'Personel Performans Raporu',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              children: [
            // Period Selector Card
            Container(
              margin: const EdgeInsets.all(16),
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
                  Text(
                    'Dönem Seçimi',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildPeriodButton('Bugün'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPeriodButton('Bu Ay'),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildPeriodButton('Bu Yıl'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                      'Seçilen Dönem: $_selectedPeriod',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.gray500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Performance List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('suruculer')
                    .where('firma', isEqualTo: currentFirmaName)
                    .snapshots(),
                builder: (context, driverSnapshot) {
                  if (driverSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final drivers = driverSnapshot.data?.docs ?? [];
                  if (drivers.isEmpty) {
                    return Center(
                      child: Text(
                        'Kayıtlı personel bulunamadı.',
                        style: GoogleFonts.inter(color: AppColors.gray500),
                      ),
                    );
                  }

                  // Now stream all collections (toplamalar) and deliveries (teslimatlar) to compute stats in memory
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('toplamalar')
                        .where('firma', isEqualTo: currentFirmaName)
                        .snapshots(),
                    builder: (context, collectionsSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('sut_kabul')
                            .where('firma', isEqualTo: currentFirmaName)
                            .where('durum', isEqualTo: 'Kabul Edildi')
                            .snapshots(),
                        builder: (context, deliveriesSnapshot) {
                          final collections = collectionsSnapshot.data?.docs ?? [];
                          final deliveries = deliveriesSnapshot.data?.docs ?? [];

                          final bool isWeb = MediaQuery.of(context).size.width > 750;

                              Widget buildDriverCard(QueryDocumentSnapshot driverDoc) {
                                final driverName = '${driverDoc['ad']} ${driverDoc['soyad']}'.trim();

                                // Filter collections for this driver and period
                                final driverCollections = collections.where((c) {
                                  final cData = c.data() as Map<String, dynamic>;
                                  final sr = cData['sr'] ?? '';
                                  if (sr != driverName) return false;

                                  // Check date
                                  final ts = cData['timestamp'];
                                  if (ts is Timestamp) {
                                    return _isWithinPeriod(ts.toDate());
                                  }
                                  final tarih = cData['tarih'];
                                  if (tarih is String) {
                                    return _isStringDateWithinPeriod(tarih);
                                  }
                                  return false;
                                }).toList();

                                // Compute milk sum
                                double totalMilk = 0.0;
                                final uniqueProducers = <String>{};
                                for (var col in driverCollections) {
                                  final colData = col.data() as Map<String, dynamic>;
                                  final mVal = colData['m'];
                                  if (mVal is num) {
                                    totalMilk += mVal.toDouble();
                                  }
                                  final uVal = colData['u'];
                                  if (uVal is String && uVal.isNotEmpty) {
                                    uniqueProducers.add(uVal);
                                  }
                                }

                                // Compute Tank Açığı/Fazlası (fark)
                                double tankShortage = 0.0;
                                final driverDeliveries = deliveries.where((d) {
                                  final dData = d.data() as Map<String, dynamic>;
                                  final String sr = dData['sr'] ?? dData['surucuName'] ?? dData['email'] ?? '';
                                  if (sr != driverName) return false;

                                  // Check date
                                  final ts = dData['timestamp'];
                                  if (ts is Timestamp) {
                                    return _isWithinPeriod(ts.toDate());
                                  }
                                  final tarih = dData['tarih'];
                                  if (tarih is String) {
                                    return _isStringDateWithinPeriod(tarih);
                                  }
                                  return false;
                                }).toList();
                                for (var del in driverDeliveries) {
                                  final dData = del.data() as Map<String, dynamic>;
                                  final double toplanan = (dData['miktar'] ?? 0.0).toDouble();
                                  final double teslim = (dData['kabulEdilenMiktar'] ?? dData['miktar'] ?? 0.0).toDouble();
                                  final double fark = toplanan - teslim;
                                  tankShortage += fark;
                                }

                                return Container(
                                  margin: isWeb ? EdgeInsets.zero : const EdgeInsets.only(bottom: 16),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: AppColors.gray200),
                                    boxShadow: AppShadows.sm,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        driverName,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.gray800,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      GridView.count(
                                        crossAxisCount: 2,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        childAspectRatio: isWeb ? 2.2 : 1.5,
                                        children: [
                                          // Toplam Süt
                                          _buildMetricCard(
                                            icon: Icons.water_drop_rounded,
                                            iconColor: Colors.blue,
                                            value: '${NumberFormat('#,##0', 'tr_TR').format(totalMilk)} L',
                                            label: 'Toplam Süt',
                                          ),
                                          // Üretici
                                          _buildMetricCard(
                                            icon: Icons.people_rounded,
                                            iconColor: const Color(0xFF10B981),
                                            value: '${uniqueProducers.length}',
                                            label: 'Üretici',
                                          ),
                                          // Teslimat
                                          _buildMetricCard(
                                            icon: Icons.local_shipping_rounded,
                                            iconColor: const Color(0xFFF59E0B),
                                            value: '${driverCollections.length}',
                                            label: 'Teslimat',
                                          ),
                                          // Tank Açığı / Tank Fazlası
                                          _buildMetricCard(
                                            icon: tankShortage >= 0 ? Icons.warning_amber_rounded : Icons.check_circle_rounded,
                                            iconColor: tankShortage >= 0 ? Colors.red : Colors.green,
                                            value: '${NumberFormat('#,##0', 'tr_TR').format(tankShortage.abs())} L',
                                            label: tankShortage >= 0 ? 'Tank Açığı' : 'Tank Fazlası',
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Text(
                                      'Personel Performansları (${drivers.length})',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.gray800,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: isWeb
                                        ? GridView.builder(
                                            padding: const EdgeInsets.all(16),
                                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                              crossAxisCount: 2,
                                              crossAxisSpacing: 16,
                                              mainAxisSpacing: 16,
                                              mainAxisExtent: 220,
                                            ),
                                            itemCount: drivers.length,
                                            itemBuilder: (context, index) {
                                              return buildDriverCard(drivers[index]);
                                            },
                                          )
                                        : ListView.builder(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            itemCount: drivers.length,
                                            itemBuilder: (context, index) {
                                              return buildDriverCard(drivers[index]);
                                            },
                                          ),
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
            ),
          ],
        ),
            ),
          ),
        ),
    );
  }

  Widget _buildPeriodButton(String period) {
    final isSelected = _selectedPeriod == period;
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF8B5CF6) : Colors.white,
          foregroundColor: isSelected ? Colors.white : AppColors.gray600,
          elevation: 0,
          side: BorderSide(
            color: isSelected ? const Color(0xFF8B5CF6) : AppColors.gray300,
            width: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {
          setState(() {
            _selectedPeriod = period;
          });
        },
        child: Text(
          period,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200, width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.gray800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: AppColors.gray500,
            ),
          ),
        ],
      ),
    );
  }
}
