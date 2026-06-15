import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/auth_provider.dart';

class FirmaFireTakip extends StatefulWidget {
  const FirmaFireTakip({super.key});

  @override
  State<FirmaFireTakip> createState() => _FirmaFireTakipState();
}

class _FirmaFireTakipState extends State<FirmaFireTakip> {
  String _selectedPeriod = 'Bu Ay'; // 'Bugün', 'Bu Hafta', 'Bu Ay', 'Bu Yıl', 'Özel'
  DateTimeRange? _customDateRange;
  String _selectedDriver = 'Tümü'; // 'Tümü' or driver full name

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => context.pop(),
              child: Row(
                children: [
                  const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: AppColors.primary600),
                  const SizedBox(width: 4),
                  Text(
                    'Geri',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        title: Text(
          'Fire Takibi',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('suruculer')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, driverSnapshot) {
          final List<String> drivers = ['Tümü'];
          if (driverSnapshot.hasData) {
            for (var doc in driverSnapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>;
              final String ad = data['ad'] ?? '';
              final String soyad = data['soyad'] ?? '';
              final String fullName = '$ad $soyad'.trim();
              if (fullName.isNotEmpty && !drivers.contains(fullName)) {
                drivers.add(fullName);
              }
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('fireler')
                .where('firma', isEqualTo: currentFirmaName)
                .snapshots(),
            builder: (context, fireSnapshot) {
              if (fireSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final docs = fireSnapshot.data?.docs ?? [];
              final filteredDocs = _filterFireDocs(docs);

              // Calculate stats
              double totalFire = 0;
              double totalBeyan = 0;
              int transactionCount = filteredDocs.length;

              for (var doc in filteredDocs) {
                final data = doc.data() as Map<String, dynamic>;
                final fVal = data['fire'];
                final fire = fVal is num ? fVal.toDouble() : (double.tryParse(fVal.toString()) ?? 0.0);
                final bVal = data['beyan'];
                final beyan = bVal is num ? bVal.toDouble() : (double.tryParse(bVal.toString()) ?? 0.0);
                totalFire += fire;
                totalBeyan += beyan;
              }

              final double avgFireOran = totalBeyan > 0 ? (totalFire / totalBeyan) * 100 : 0.0;

              return Column(
                children: [
                  // Filter header
                  _buildFilterSection(drivers),
                  
                  // Stats
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: StatsGrid(
                      children: [
                        StatCard(
                          icon: Icons.warning_amber_rounded,
                          value: '${totalFire.toStringAsFixed(1)} L',
                          label: 'Toplam Fire',
                          color: AppColors.danger,
                        ),
                        StatCard(
                          icon: Icons.percent_rounded,
                          value: '%${avgFireOran.toStringAsFixed(1)}',
                          label: 'Ort. Oran',
                          color: AppColors.warning,
                        ),
                        StatCard(
                          icon: Icons.analytics_rounded,
                          value: '$transactionCount',
                          label: 'Kayıt Sayısı',
                          color: AppColors.primary600,
                        ),
                      ],
                    ),
                  ),

                  // List of records
                  Expanded(
                    child: filteredDocs.isEmpty
                        ? Center(
                            child: Text(
                              'Seçilen kriterlere uygun fire kaydı bulunamadı.',
                              style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: filteredDocs.length,
                            itemBuilder: (context, index) {
                              final doc = filteredDocs[index];
                              final data = doc.data() as Map<String, dynamic>;
                              final String surucuName = data['surucuName'] ?? '';
                              final String plaka = data['plaka'] ?? '';
                              final String tarih = data['tarih'] ?? '';
                              final String kaynak = data['kaynak'] ?? '';
                              final String hedef = data['hedef'] ?? '';
                              final double fire = (data['fire'] as num?)?.toDouble() ?? 0.0;
                              final double beyan = (data['beyan'] as num?)?.toDouble() ?? 0.0;
                              final double kabul = (data['kabul'] as num?)?.toDouble() ?? 0.0;

                              final double fireOran = beyan > 0 ? (fire / beyan) * 100 : 0.0;

                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: AppShadows.sm,
                                  border: Border.all(color: AppColors.gray200),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: AppColors.dangerLight,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.warning_amber_rounded,
                                            color: AppColors.danger,
                                            size: 18,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                surucuName,
                                                style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '$plaka • $tarih',
                                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.dangerLight,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '% ${fireOran.toStringAsFixed(1)}',
                                            style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.danger),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(height: 1, thickness: 1, color: AppColors.gray100),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(Icons.storage_rounded, size: 14, color: AppColors.gray400),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$kaynak ➔ $hedef',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray600, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          'Beyan: ${beyan.toStringAsFixed(0)} L  |  Kabul: ${kabul.toStringAsFixed(0)} L',
                                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'Fire: -${fire.toStringAsFixed(0)} L',
                                          style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.danger),
                                        ),
                                      ],
                                    ),
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
    );
  }

  List<QueryDocumentSnapshot> _filterFireDocs(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    if (_selectedPeriod == 'Bugün') {
      startDate = DateTime(now.year, now.month, now.day);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedPeriod == 'Bu Hafta') {
      startDate = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedPeriod == 'Bu Ay') {
      startDate = DateTime(now.year, now.month, 1);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedPeriod == 'Bu Yıl') {
      startDate = DateTime(now.year, 1, 1);
      endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);
    } else if (_selectedPeriod == 'Özel' && _customDateRange != null) {
      startDate = DateTime(_customDateRange!.start.year, _customDateRange!.start.month, _customDateRange!.start.day);
      endDate = DateTime(_customDateRange!.end.year, _customDateRange!.end.month, _customDateRange!.end.day, 23, 59, 59);
    }

    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      
      // Driver filter
      if (_selectedDriver != 'Tümü') {
        final String surucuName = data['surucuName'] as String? ?? '';
        if (surucuName != _selectedDriver) return false;
      }

      // Date filter
      final ts = data['timestamp'];
      if (ts is Timestamp) {
        final dt = ts.toDate();
        if (startDate != null && dt.isBefore(startDate)) return false;
        if (endDate != null && dt.isAfter(endDate)) return false;
      } else {
        // Fallback using date string "dd.MM.yyyy"
        final dateStr = data['tarih'] as String? ?? '';
        try {
          final parts = dateStr.split('.');
          if (parts.length == 3) {
            final day = int.parse(parts[0]);
            final month = int.parse(parts[1]);
            final year = int.parse(parts[2]);
            final dt = DateTime(year, month, day);
            if (startDate != null && dt.isBefore(startDate)) return false;
            if (endDate != null && dt.isAfter(endDate)) return false;
          } else {
            return false;
          }
        } catch (_) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildFilterSection(List<String> drivers) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // Driver selector
          Row(
            children: [
              Icon(Icons.person_search_rounded, size: 18, color: AppColors.gray500),
              const SizedBox(width: 8),
              Text(
                'Toplayıcı:',
                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.gray700),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.gray200),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedDriver,
                      items: drivers.map((d) {
                        return DropdownMenuItem(
                          value: d,
                          child: Text(d, style: GoogleFonts.inter(fontSize: 12.5)),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedDriver = val);
                        }
                      },
                      style: GoogleFonts.inter(color: AppColors.gray800),
                      icon: const Icon(Icons.arrow_drop_down_rounded, color: AppColors.gray500),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Period selector chips
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Bugün', 'Bu Hafta', 'Bu Ay', 'Bu Yıl', 'Özel'].map((period) {
              final isSelected = _selectedPeriod == period;
              return ChoiceChip(
                label: Text(
                  period,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.primary600 : AppColors.gray600,
                  ),
                ),
                selected: isSelected,
                onSelected: (val) async {
                  if (val) {
                    if (period == 'Özel') {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2025),
                        lastDate: DateTime.now(),
                        initialDateRange: _customDateRange,
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedPeriod = period;
                          _customDateRange = picked;
                        });
                      }
                    } else {
                      setState(() {
                        _selectedPeriod = period;
                      });
                    }
                  }
                },
                selectedColor: AppColors.primary50,
                backgroundColor: AppColors.gray50,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary100 : Colors.transparent,
                  ),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
          if (_selectedPeriod == 'Özel' && _customDateRange != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              decoration: BoxDecoration(
                color: AppColors.gray50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Aralık: ${DateFormat('dd.MM.yyyy').format(_customDateRange!.start)} - ${DateFormat('dd.MM.yyyy').format(_customDateRange!.end)}',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray600, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
