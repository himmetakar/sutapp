import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

class DijitalSutKartiScreen extends StatefulWidget {
  final String? producerName;
  const DijitalSutKartiScreen({super.key, this.producerName});

  @override
  State<DijitalSutKartiScreen> createState() => _DijitalSutKartiScreenState();
}

class _DijitalSutKartiScreenState extends State<DijitalSutKartiScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DateTime _selectedMonth = DateTime.now();

  int _daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  String _formatLitres(double value) {
    final format = NumberFormat('#,##0', 'tr_TR');
    return format.format(value);
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setBottomSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tarih Seçin',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        onPressed: () {
                          setBottomSheetState(() {
                            _selectedMonth = DateTime(_selectedMonth.year - 1, _selectedMonth.month);
                          });
                          setState(() {});
                        },
                      ),
                      Text(
                        '${_selectedMonth.year}',
                        style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary600),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        onPressed: () {
                          setBottomSheetState(() {
                            _selectedMonth = DateTime(_selectedMonth.year + 1, _selectedMonth.month);
                          });
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const Divider(),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.5,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final monthNum = index + 1;
                      final isSelected = _selectedMonth.month == monthNum;
                      final monthName = DateFormat('MMM', 'tr_TR').format(DateTime(2026, monthNum, 1));
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedMonth = DateTime(_selectedMonth.year, monthNum);
                          });
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary600 : AppColors.gray50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isSelected ? AppColors.primary700 : AppColors.gray200),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            monthName.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: isSelected ? Colors.white : AppColors.gray700,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final targetName = widget.producerName ?? auth.user?.displayName ?? '';
    final daysCount = _daysInMonth(_selectedMonth);

    final headerStyle = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: AppColors.gray500,
    );

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          targetName.toLowerCase(),
          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('toplamalar')
            .where('u', isEqualTo: targetName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final rawDocs = snapshot.data?.docs ?? [];

          // Filter collections by selected month & year
          final monthDocs = rawDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            if (ts == null) return false;
            final date = ts.toDate();
            return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
          }).toList();

          double aylikToplam = 0.0;
          double sabahToplam = 0.0;
          double aksamToplam = 0.0;

          // Day -> Shift ('S' / 'A') -> Milk amount
          final Map<int, Map<String, double>> dailyData = {};
          final Set<int> daysWithCollections = {};

          for (var doc in monthDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            if (ts == null) continue;
            final date = ts.toDate();
            final day = date.day;

            final mVal = data['m'] ?? 0;
            final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);

            // Determine shift
            String vakit = data['vakit'] ?? '';
            if (vakit.isEmpty) {
              vakit = date.hour < 14 ? 'S' : 'A';
            } else {
              vakit = vakit.toLowerCase().contains('sabah') ? 'S' : 'A';
            }

            aylikToplam += m;
            daysWithCollections.add(day);

            if (vakit == 'S') {
              sabahToplam += m;
            } else {
              aksamToplam += m;
            }

            if (!dailyData.containsKey(day)) {
              dailyData[day] = {'S': 0.0, 'A': 0.0};
            }
            dailyData[day]![vakit] = (dailyData[day]![vakit] ?? 0.0) + m;
          }

          final double gunlukOrt = daysWithCollections.isNotEmpty
              ? aylikToplam / daysWithCollections.length
              : 0.0;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Month Selector Bar
                GestureDetector(
                  onTap: () => _showMonthPicker(context),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.gray200),
                      boxShadow: AppShadows.sm,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.primary600, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth),
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.gray800),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.gray500, size: 18),
                      ],
                    ),
                  ),
                ),

                // Metrics Grid (Responsive Layout)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth >= 640;
                    return GridView.count(
                      crossAxisCount: isWide ? 4 : 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      childAspectRatio: isWide ? 2.5 : 2.0,
                      children: [
                        _buildStatCard(
                          icon: Icons.water_drop_rounded,
                          iconColor: const Color(0xFF2563EB),
                          bgColor: const Color(0xFFEFF6FF),
                          value: '${_formatLitres(aylikToplam)} L',
                          label: 'Aylık Toplam',
                        ),
                        _buildStatCard(
                          icon: Icons.wb_sunny_rounded,
                          iconColor: const Color(0xFFF59E0B),
                          bgColor: const Color(0xFFFEF3C7),
                          value: '${_formatLitres(sabahToplam)} L',
                          label: 'Sabah Toplam',
                        ),
                        _buildStatCard(
                          icon: Icons.nightlight_round,
                          iconColor: const Color(0xFF1E293B),
                          bgColor: const Color(0xFFF1F5F9),
                          value: '${_formatLitres(aksamToplam)} L',
                          label: 'Akşam Toplam',
                        ),
                        _buildStatCard(
                          icon: Icons.bar_chart_rounded,
                          iconColor: const Color(0xFF10B981),
                          bgColor: const Color(0xFFD1FAE5),
                          value: '${_formatLitres(gunlukOrt)} L',
                          label: 'Günlük Ort.',
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Daily Details Table
                Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.gray200),
                    boxShadow: AppShadows.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Row
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.gray200, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 2, child: Center(child: Text('Gün', style: headerStyle))),
                            Expanded(flex: 3, child: Center(child: Text('Sabah', style: headerStyle))),
                            Expanded(flex: 3, child: Center(child: Text('Akşam', style: headerStyle))),
                            Expanded(flex: 3, child: Center(child: Text('Toplam', style: headerStyle))),
                          ],
                        ),
                      ),
                      // Table Body Row Items
                      ...List.generate(daysCount, (idx) {
                        final day = idx + 1;
                        final dayData = dailyData[day] ?? {'S': 0.0, 'A': 0.0};
                        final sVal = dayData['S'] ?? 0.0;
                        final aVal = dayData['A'] ?? 0.0;
                        final totalVal = sVal + aVal;

                        final dayDate = DateTime(_selectedMonth.year, _selectedMonth.month, day);
                        final weekdayStr = DateFormat('E', 'tr_TR').format(dayDate);

                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: const BoxDecoration(
                            border: Border(bottom: BorderSide(color: AppColors.gray100, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('$day', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gray800)),
                                    Text(weekdayStr, style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400)),
                                  ],
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Center(
                                  child: Text(
                                    sVal > 0 ? sVal.toStringAsFixed(1) : '-',
                                    style: GoogleFonts.inter(fontSize: 12.5, color: sVal > 0 ? AppColors.gray700 : AppColors.gray300, fontWeight: sVal > 0 ? FontWeight.w600 : FontWeight.normal),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Center(
                                  child: Text(
                                    aVal > 0 ? aVal.toStringAsFixed(1) : '-',
                                    style: GoogleFonts.inter(fontSize: 12.5, color: aVal > 0 ? AppColors.gray700 : AppColors.gray300, fontWeight: aVal > 0 ? FontWeight.w600 : FontWeight.normal),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Center(
                                  child: Text(
                                    totalVal > 0 ? totalVal.toStringAsFixed(1) : '-',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: totalVal > 0 ? FontWeight.bold : FontWeight.normal,
                                      color: totalVal > 0 ? const Color(0xFF2563EB) : AppColors.gray300,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String value,
    required String label,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gray200),
        boxShadow: AppShadows.sm,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.gray500, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.gray900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
