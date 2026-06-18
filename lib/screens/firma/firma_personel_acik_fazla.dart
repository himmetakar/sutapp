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

  bool _isRecordMatchingDate(Timestamp? timestamp, String dateStr) {
    DateTime? recordDate;
    if (timestamp != null) {
      recordDate = timestamp.toDate();
    } else if (dateStr.isNotEmpty) {
      try {
        final parts = dateStr.split('.');
        if (parts.length == 3) {
          final day = int.parse(parts[0]);
          final month = int.parse(parts[1]);
          final year = int.parse(parts[2]);
          recordDate = DateTime(year, month, day);
        }
      } catch (_) {}
    }
    if (recordDate == null) return false;

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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
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
                  GestureDetector(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        locale: const Locale('tr', 'TR'),
                        helpText: _selectedTab == 'Günlük' 
                            ? 'Gün Seçin' 
                            : _selectedTab == 'Aylık' 
                                ? 'Ay Seçin' 
                                : 'Yıl Seçin',
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDate = picked;
                        });
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getDateLabel(),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down_rounded, color: AppColors.primary600, size: 20),
                      ],
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
                      .collection('sut_kabul')
                      .where('firma', isEqualTo: currentFirmaName)
                      .where('durum', isEqualTo: 'Kabul Edildi')
                      .snapshots(),
                  builder: (context, teslimSnapshot) {
                    if (teslimSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final allDeliveries = teslimSnapshot.data?.docs ?? [];
                    final bool isWeb = MediaQuery.of(context).size.width > 750;

                    // Filter by date and driver name
                    final filteredDeliveries = allDeliveries.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final String dateStr = data['tarih'] ?? '';
                      final Timestamp? timestamp = data['timestamp'] as Timestamp?;
                      if (!_isRecordMatchingDate(timestamp, dateStr)) return false;

                      if (_selectedDriverFilter != 'Tümü') {
                        final String driverName = data['sr'] ?? data['surucuName'] ?? data['surucu'] ?? '';
                        if (driverName != _selectedDriverFilter) return false;
                      }

                      return true;
                    }).toList();

                    double toplamAcik = 0.0;
                    double toplamFazla = 0.0;

                    for (var doc in filteredDeliveries) {
                      final data = doc.data() as Map<String, dynamic>;
                      final double toplanan = (data['toplanan'] ?? data['miktar'] ?? 0.0).toDouble();
                      final double teslim = (data['teslim'] ?? data['kabulEdilenMiktar'] ?? data['miktar'] ?? 0.0).toDouble();
                      final double fark = toplanan - teslim;
                      if (fark > 0) {
                        toplamAcik += fark;
                      } else if (fark < 0) {
                        toplamFazla += fark.abs();
                      }
                    }

                    Widget buildShortageCard(QueryDocumentSnapshot doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final String plaka = data['plaka'] ?? '-';
                      final String driver = data['sr'] ?? data['surucuName'] ?? data['surucu'] ?? 'Bilinmeyen Sürücü';
                      final double toplanan = (data['toplanan'] ?? data['miktar'] ?? 0.0).toDouble();
                      final double teslim = (data['teslim'] ?? data['kabulEdilenMiktar'] ?? data['miktar'] ?? 0.0).toDouble();
                      final double fark = toplanan - teslim;

                      String date = data['tarih'] ?? '';
                      String time = data['saat'] ?? '';
                      
                      final Timestamp? ts = data['timestamp'] as Timestamp?;
                      if (ts != null) {
                        final dt = ts.toDate();
                        date = DateFormat('dd.MM.yyyy').format(dt);
                        time = DateFormat('HH:mm').format(dt);
                      }

                      return Container(
                        margin: isWeb ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.gray200),
                          boxShadow: AppShadows.sm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    plaka,
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
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
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.gray800,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  '$date $time',
                                  style: GoogleFonts.inter(
                                    fontSize: 9,
                                    color: AppColors.gray400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildCompactStatBox('Toplanan', '${toplanan.toStringAsFixed(0)} L', Colors.blue),
                                _buildCompactStatBox('Teslim', '${teslim.toStringAsFixed(0)} L', Colors.green),
                                if (fark > 0)
                                  _buildCompactStatBox('Açık', '${fark.toStringAsFixed(0)} L', Colors.red)
                                else if (fark < 0)
                                  _buildCompactStatBox('Fazla', '${fark.abs().toStringAsFixed(0)} L', Colors.green)
                                else
                                  _buildCompactStatBox('Açık', '0 L', AppColors.gray500),
                              ],
                            ),
                          ],
                        ),
                      );
                    }

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
                                  'Açık: Beyan edilen > Kabul edilen miktar (Eksik süt)\nFazla: Beyan edilen < Kabul edilen miktar (Fazla süt)',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF1E40AF),
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Period Summary Card
                        if (filteredDeliveries.isNotEmpty) ...[
                          Container(
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
                                  'Dönem Özeti',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gray800,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    _buildSummaryStatBox('Toplam Açık', '${toplamAcik.toStringAsFixed(0)} L', Colors.red),
                                    const SizedBox(width: 10),
                                    _buildSummaryStatBox('Toplam Fazla', '${toplamFazla.toStringAsFixed(0)} L', Colors.green),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

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
                          isWeb
                              ? GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 12,
                                    mainAxisExtent: 95,
                                  ),
                                  itemCount: filteredDeliveries.length,
                                  itemBuilder: (context, idx) {
                                    return buildShortageCard(filteredDeliveries[idx]);
                                  },
                                )
                              : Column(
                                  children: filteredDeliveries.map((doc) => buildShortageCard(doc)).toList(),
                                ),
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

  Widget _buildSummaryStatBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
