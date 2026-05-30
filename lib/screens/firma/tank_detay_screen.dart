import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class TankDetayScreen extends StatefulWidget {
  const TankDetayScreen({super.key});

  @override
  State<TankDetayScreen> createState() => _TankDetayScreenState();
}

class _TankDetayScreenState extends State<TankDetayScreen> {
  DateTime _selectedDate = DateTime.now();
  final Map<String, bool> _expandedGroups = {};

  void _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final formattedDateStr = DateFormat('dd.MM.yyyy').format(_selectedDate);
    final displayDateStr = DateFormat('d MMMM yyyy', 'tr_TR').format(_selectedDate);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            const Icon(Icons.storage_rounded, color: Color(0xFF3B82F6), size: 20),
            const SizedBox(width: 8),
            Text(
              'Tank İçerik Detayı',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Date Filter Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tarih Seçin',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray500,
                  ),
                ),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _showDatePicker,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_outlined, size: 18, color: AppColors.gray500),
                            const SizedBox(width: 8),
                            Text(
                              displayDateStr,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray700),
                            ),
                          ],
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.gray500),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Grouped collections data
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tanklar')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, tankSnapshot) {
                final tankDocs = tankSnapshot.data?.docs ?? [];
                final Map<String, String> plateToTankName = {};
                for (var doc in tankDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final String name = data['ad'] ?? '';
                  final String assignedVehicle = data['arac'] ?? '';
                  if (assignedVehicle.isNotEmpty) {
                    plateToTankName[assignedVehicle] = name;
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('toplamalar')
                      .where('firma', isEqualTo: currentFirmaName)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    
                    final docs = snapshot.data?.docs ?? [];
                    
                    // Filter locally by date
                    final dateFiltered = docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final date = data['tarih'] ?? '';
                      // If collection contains date field, compare it. If timestamp exists, compare it.
                      if (date.isNotEmpty) {
                        return date == formattedDateStr;
                      }
                      final ts = data['timestamp'] as Timestamp?;
                      if (ts != null) {
                        final d = ts.toDate();
                        return d.year == _selectedDate.year &&
                            d.month == _selectedDate.month &&
                            d.day == _selectedDate.day;
                      }
                      return false;
                    }).toList();

                    // Calculate metrics
                    int totalGiris = dateFiltered.length;
                    double totalSut = 0.0;
                    
                    // Group entries by tank name
                    final Map<String, List<QueryDocumentSnapshot>> groups = {};
                    for (var doc in dateFiltered) {
                      final data = doc.data() as Map<String, dynamic>;
                      final mVal = data['m'] ?? 0;
                      final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);
                      totalSut += m;

                      // Group Key: tank name (fall back to vehicle if no tank info)
                      final vehicle = data['km'] ?? 'Araçsız';
                      final driver = data['sr'] ?? 'Yönetici';
                      // Try to get the tank name from the collection record or map
                      final String assignedTank = plateToTankName[vehicle] ?? vehicle;
                      final tankName = data['tank'] ?? data['tankAd'] ?? assignedTank;
                      final groupKey = '$tankName|$vehicle|$driver';
                      if (!groups.containsKey(groupKey)) {
                        groups[groupKey] = [];
                      }
                      groups[groupKey]!.add(doc);
                    }


                int totalTanks = groups.keys.length;

                return Column(
                  children: [
                    // Summary metrics box
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gray200),
                          boxShadow: AppShadows.sm,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text('Toplam Tank', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                                const SizedBox(height: 4),
                                Text('$totalTanks', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6))),
                              ],
                            ),
                            Container(width: 1, height: 32, color: AppColors.gray200),
                            Column(
                              children: [
                                Text('Toplam Giriş', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                                const SizedBox(height: 4),
                                Text('$totalGiris', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6))),
                              ],
                            ),
                            Container(width: 1, height: 32, color: AppColors.gray200),
                            Column(
                              children: [
                                Text('Toplam Süt', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                                const SizedBox(height: 4),
                                Text('${totalSut.toStringAsFixed(0)} L', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable Groups List
                    Expanded(
                      child: totalGiris == 0
                          ? Center(
                              child: Text(
                                'Bu tarihe ait veri bulunmamaktadır.',
                                style: GoogleFonts.inter(color: AppColors.gray500),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: groups.keys.length,
                              itemBuilder: (context, index) {
                                final key = groups.keys.elementAt(index);
                                final list = groups[key]!;
                                final parts = key.split('|');
                                final tankName = parts[0];
                                final vehicle = parts.length > 1 ? parts[1] : '';
                                final driver = parts.length > 2 ? parts[2] : '';

                                // Group metrics
                                double groupTotal = 0.0;
                                for (var doc in list) {
                                  final mVal = doc['m'] ?? 0;
                                  groupTotal += mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);
                                }

                                final isExpanded = _expandedGroups[key] ?? true;

                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.gray200),
                                    boxShadow: AppShadows.sm,
                                  ),
                                  child: Column(
                                    children: [
                                      // Group Header
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _expandedGroups[key] = !isExpanded;
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.only(
                                              topLeft: const Radius.circular(14),
                                              topRight: const Radius.circular(14),
                                              bottomLeft: Radius.circular(isExpanded ? 0 : 14),
                                              bottomRight: Radius.circular(isExpanded ? 0 : 14),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 38,
                                                height: 38,
                                                decoration: const BoxDecoration(
                                                  color: Color(0xFF0284C7),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.propane_tank_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      tankName,
                                                      style: GoogleFonts.inter(
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 14.5,
                                                        color: AppColors.gray800,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        const Icon(Icons.local_shipping_outlined, size: 12, color: AppColors.gray400),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          '$vehicle • $driver',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 12,
                                                            color: AppColors.gray400,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    '${list.length} giriş',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 11,
                                                      color: AppColors.gray500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    '${groupTotal.toStringAsFixed(0)} L',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF3B82F6),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 10),
                                              Icon(
                                                isExpanded
                                                    ? Icons.keyboard_arrow_up_rounded
                                                    : Icons.keyboard_arrow_down_rounded,
                                                color: AppColors.gray400,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),

                                      // Expanded Child List
                                      if (isExpanded) ...[
                                        const Divider(),
                                        ListView.separated(
                                          shrinkWrap: true,
                                          physics: const NeverScrollableScrollPhysics(),
                                          itemCount: list.length,
                                          separatorBuilder: (_, __) => const Divider(indent: 64),
                                          itemBuilder: (context, idx) {
                                            final doc = list[idx];
                                            final data = doc.data() as Map<String, dynamic>;
                                            final String producer = data['u'] ?? '-';
                                            final String time = data['s'] ?? '';
                                            final rawQuality = data['kalite'] ?? data['tip'] ?? data['b'] ?? 'Soğuk Süt';
                                            final String quality = (rawQuality == 'A Kalite' || rawQuality == 'Soğuk süt')
                                                ? 'Soğuk Süt'
                                                : (rawQuality == 'B Kalite' || rawQuality == 'Sıcak süt')
                                                    ? 'Sıcak Süt'
                                                    : rawQuality;
                                            final mVal = data['m'] ?? 0;
                                            final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);

                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    width: 32,
                                                    height: 32,
                                                    decoration: const BoxDecoration(
                                                      color: Color(0xFFEFF6FF),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.person_rounded,
                                                      color: Color(0xFF3B82F6),
                                                      size: 16,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          producer,
                                                          style: GoogleFonts.inter(
                                                            fontSize: 13.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: AppColors.gray800,
                                                          ),
                                                        ),
                                                        const SizedBox(height: 3),
                                                        Row(
                                                          children: [
                                                            const Icon(Icons.wb_sunny_outlined, size: 11, color: Color(0xFFF59E0B)),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Sabah • $quality',
                                                              style: GoogleFonts.inter(
                                                                fontSize: 10.5,
                                                                color: AppColors.gray500,
                                                              ),
                                                            ),
                                                            const SizedBox(width: 8),
                                                            const Icon(Icons.access_time_rounded, size: 11, color: AppColors.gray400),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              time,
                                                              style: GoogleFonts.inter(
                                                                fontSize: 10.5,
                                                                color: AppColors.gray400,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Text(
                                                    '${m.toStringAsFixed(1)} L',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.bold,
                                                      color: const Color(0xFF3B82F6),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
        ],
      ),
    );
  }
}
