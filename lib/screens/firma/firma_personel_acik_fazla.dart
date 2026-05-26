import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class FirmaPersonelAcikFazlaScreen extends StatefulWidget {
  const FirmaPersonelAcikFazlaScreen({super.key});

  @override
  State<FirmaPersonelAcikFazlaScreen> createState() => _FirmaPersonelAcikFazlaScreenState();
}

class _FirmaPersonelAcikFazlaScreenState extends State<FirmaPersonelAcikFazlaScreen> {
  String _selectedTab = 'Aylık'; // 'Günlük', 'Aylık', 'Yıllık'
  DateTime _selectedDate = DateTime.now();
  String _selectedDriverFilter = 'Tümü'; // 'Tümü' or driver's name

  void _nextDate() {
    setState(() {
      if (_selectedTab == 'Günlük') {
        _selectedDate = _selectedDate.add(const Duration(days: 1));
      } else if (_selectedTab == 'Aylık') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
      } else {
        _selectedDate = DateTime(_selectedDate.year + 1);
      }
    });
  }

  void _prevDate() {
    setState(() {
      if (_selectedTab == 'Günlük') {
        _selectedDate = _selectedDate.subtract(const Duration(days: 1));
      } else if (_selectedTab == 'Aylık') {
        _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
      } else {
        _selectedDate = DateTime(_selectedDate.year - 1);
      }
    });
  }

  String _getDateLabel() {
    if (_selectedTab == 'Günlük') {
      return DateFormat('dd MMMM yyyy', 'tr_TR').format(_selectedDate);
    } else if (_selectedTab == 'Aylık') {
      return DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);
    } else {
      return DateFormat('yyyy', 'tr_TR').format(_selectedDate);
    }
  }

  bool _isRecordMatchingDate(String dateStr) {
    try {
      final parts = dateStr.split('.');
      if (parts.length != 3) return false;
      final day = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final year = int.parse(parts[2]);
      final recordDate = DateTime(year, month, day);

      if (_selectedTab == 'Günlük') {
        return recordDate.year == _selectedDate.year &&
            recordDate.month == _selectedDate.month &&
            recordDate.day == _selectedDate.day;
      } else if (_selectedTab == 'Aylık') {
        return recordDate.year == _selectedDate.year &&
            recordDate.month == _selectedDate.month;
      } else {
        return recordDate.year == _selectedDate.year;
      }
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
          'Personel Açık / Fazla Raporu',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Period Tabs (Günlük, Aylık, Yıllık)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  Expanded(child: _buildTabButton('Günlük')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTabButton('Aylık')),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTabButton('Yıllık')),
                ],
              ),
            ),

            // Date Selector Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_left_rounded, color: Colors.blue, size: 20),
                      padding: EdgeInsets.zero,
                      onPressed: _prevDate,
                    ),
                  ),
                  Text(
                    _getDateLabel(),
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.gray800,
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.chevron_right_rounded, color: Colors.blue, size: 20),
                      padding: EdgeInsets.zero,
                      onPressed: _nextDate,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Filter Chips Stream
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('suruculer')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, driverSnapshot) {
                final drivers = driverSnapshot.data?.docs ?? [];
                return SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      _buildFilterChip('Tümü'),
                      ...drivers.map((d) {
                        final name = '${d['ad']} ${d['soyad']}'.trim();
                        return _buildFilterChip(name);
                      }),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Main Content Area
            Expanded(
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('teslimatlar')
                      .where('firma', isEqualTo: currentFirmaName)
                      .snapshots(),
                  builder: (context, teslimSnapshot) {
                    if (teslimSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allDeliveries = teslimSnapshot.data?.docs ?? [];

                    // Filter by date and driver name
                    final filteredDeliveries = allDeliveries.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final String dateStr = data['tarih'] ?? '';
                      if (!_isRecordMatchingDate(dateStr)) return false;

                      if (_selectedDriverFilter != 'Tümü') {
                        final String driverName = data['sr'] ?? data['surucu'] ?? '';
                        if (driverName != _selectedDriverFilter) return false;
                      }

                      return true;
                    }).toList();

                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        // Personel Özeti Header
                        Row(
                          children: [
                            const Icon(Icons.people_alt_rounded, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Personel Özeti',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gray800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Info Alert Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline_rounded, color: Colors.blue, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Açık = Personelin beyan ettiği – Yöneticinin kabul ettiği miktar',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF1E40AF),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        if (filteredDeliveries.isEmpty) ...[
                          const SizedBox(height: 48),
                          Center(
                            child: Icon(
                              Icons.water_drop_outlined,
                              color: AppColors.gray300,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Bu dönem için veri bulunamadı',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Kabul edilmiş teslimat kaydı oluşturulduğunda burada görünür',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.gray400,
                            ),
                          ),
                        ] else ...[
                          // List shortage details
                          ...filteredDeliveries.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final String plaka = data['plaka'] ?? '-';
                            final String driver = data['sr'] ?? data['surucu'] ?? 'Bilinmeyen Sürücü';
                            final double toplanan = (data['toplanan'] ?? data['miktar'] ?? 0.0).toDouble();
                            final double teslim = (data['teslim'] ?? data['miktar'] ?? 0.0).toDouble();
                            final double fark = (data['fark'] ?? (toplanan - teslim)).toDouble();

                            final date = data['tarih'] ?? '';
                            final time = data['saat'] ?? '';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.gray200),
                                boxShadow: AppShadows.sm,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary50,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          plaka,
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          driver,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.gray800,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$date $time',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          color: AppColors.gray400,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      _buildCompactStatBox('Toplanan', '${toplanan.toStringAsFixed(0)} L', Colors.blue),
                                      _buildCompactStatBox('Teslim', '${teslim.toStringAsFixed(0)} L', Colors.green),
                                      _buildCompactStatBox('Açık', '${fark.toStringAsFixed(0)} L', Colors.red),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String tabName) {
    final isSelected = _selectedTab == tabName;
    return SizedBox(
      height: 38,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          foregroundColor: isSelected ? Colors.blue : AppColors.gray500,
          elevation: 0,
          side: BorderSide(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: 1,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: EdgeInsets.zero,
        ),
        onPressed: () {
          setState(() {
            _selectedTab = tabName;
            _selectedDate = DateTime.now();
          });
        },
        child: Text(
          tabName,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedDriverFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.blue : AppColors.gray600,
          ),
        ),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            _selectedDriverFilter = label;
          });
        },
        selectedColor: Colors.blue.withValues(alpha: 0.1),
        checkmarkColor: Colors.blue,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isSelected ? Colors.blue : AppColors.gray300, width: 0.8),
        ),
      ),
    );
  }

  Widget _buildCompactStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.1), width: 1),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 9, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
