import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaAylikSutScreen extends StatefulWidget {
  const FirmaAylikSutScreen({super.key});

  @override
  State<FirmaAylikSutScreen> createState() => _FirmaAylikSutScreenState();
}

class _FirmaAylikSutScreenState extends State<FirmaAylikSutScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  DateTime _selectedMonth = DateTime.now();

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  int _daysInMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0).day;
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth);
    final daysCount = _daysInMonth(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text('Aylık Süt Kayıtları', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Print / Export button (placeholder)
          IconButton(
            icon: const Icon(Icons.print_rounded, color: Color(0xFF0F8B5A)),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PDF dışa aktarma özelliği yakında eklenecek.')),
              );
            },
          ),
          // Add new entry button
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F8B5A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
            ),
            onPressed: () {
              // Navigate to süt kabul or show add dialog
              context.push('/firma/sut-kabul');
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      backgroundColor: AppColors.gray50,
      body: Column(
        children: [
          // Month Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary600),
                  onPressed: () => _changeMonth(-1),
                ),
                const SizedBox(width: 8),
                Text(
                  monthStr[0].toUpperCase() + monthStr.substring(1),
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary600),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Table
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('toplamalar')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final rawDocs = snapshot.data?.docs ?? [];

                // Filter by selected month
                final monthDocs = rawDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final ts = data['timestamp'] as Timestamp?;
                  if (ts == null) return false;
                  final date = ts.toDate();
                  return date.year == _selectedMonth.year && date.month == _selectedMonth.month;
                }).toList();

                // Build producer data map
                // Key: producerName, Value: Map<int day, Map<String vakit, double amount>>
                final Map<String, Map<int, Map<String, double>>> producerData = {};
                // Also track milk type (hot/cold) per producer
                final Map<String, String> producerType = {};

                for (var doc in monthDocs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final producer = data['u'] as String? ?? '';
                  if (producer.isEmpty) continue;

                  final ts = data['timestamp'] as Timestamp?;
                  if (ts == null) continue;
                  final date = ts.toDate();
                  final day = date.day;

                  final mVal = data['m'] ?? 0;
                  final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);

                  // Determine vakit (S: Sabah, A: Akşam)
                  String vakit = data['vakit'] ?? '';
                  if (vakit.isEmpty) {
                    // Guess from timestamp hour
                    vakit = date.hour < 14 ? 'S' : 'A';
                  } else {
                    vakit = vakit.toLowerCase().contains('sabah') ? 'S' : 'A';
                  }

                  // Determine milk type
                  final tip = data['tip'] as String? ?? 'Soğuk Süt';
                  producerType[producer] = tip;

                  if (!producerData.containsKey(producer)) {
                    producerData[producer] = {};
                  }
                  if (!producerData[producer]!.containsKey(day)) {
                    producerData[producer]![day] = {'S': 0.0, 'A': 0.0};
                  }
                  producerData[producer]![day]![vakit] = (producerData[producer]![day]![vakit] ?? 0.0) + m;
                }

                // Sort producers alphabetically
                final sortedProducers = producerData.keys.toList()..sort();

                if (sortedProducers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.table_chart_outlined, size: 48, color: AppColors.gray300),
                        const SizedBox(height: 12),
                        Text(
                          'Bu ay için süt alım kaydı bulunamadı.',
                          style: GoogleFonts.inter(color: AppColors.gray500),
                        ),
                      ],
                    ),
                  );
                }

                // Calculate total per producer
                final Map<String, double> producerTotals = {};
                for (var producer in sortedProducers) {
                  double total = 0;
                  producerData[producer]!.forEach((day, vakitMap) {
                    total += (vakitMap['S'] ?? 0) + (vakitMap['A'] ?? 0);
                  });
                  producerTotals[producer] = total;
                }

                // Build the table
                return _buildMilkTable(
                  sortedProducers,
                  producerData,
                  producerType,
                  producerTotals,
                  daysCount,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilkTable(
    List<String> producers,
    Map<String, Map<int, Map<String, double>>> producerData,
    Map<String, String> producerType,
    Map<String, double> producerTotals,
    int daysCount,
  ) {
    // Fixed column width for days
    const double dayColWidth = 42.0;
    const double noColWidth = 32.0;
    const double nameColWidth = 100.0;
    const double vakitColWidth = 28.0;
    const double totalColWidth = 52.0;
    const double rowHeight = 28.0;

    final headerStyle = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.bold,
      color: Colors.white,
    );
    final cellStyle = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w500,
      color: AppColors.gray700,
    );
    final emptyStyle = GoogleFonts.inter(
      fontSize: 10,
      color: AppColors.gray300,
    );

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7),
              ),
              child: Row(
                children: [
                  // No column
                  Container(
                    width: noColWidth,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                    ),
                    child: Text('No', style: headerStyle),
                  ),
                  // Name column
                  Container(
                    width: nameColWidth,
                    height: 36,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                    ),
                    child: Text('Müşteri Adı', style: headerStyle),
                  ),
                  // S/A column
                  Container(
                    width: vakitColWidth,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                    ),
                    child: Text('S/A', style: headerStyle),
                  ),
                  // Day columns
                  ...List.generate(daysCount, (i) {
                    final day = i + 1;
                    return Container(
                      width: dayColWidth,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                      ),
                      child: Text('$day', style: headerStyle),
                    );
                  }),
                  // Total column
                  Container(
                    width: totalColWidth,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                      color: const Color(0xFF0369A1),
                    ),
                    child: Text('Top.', style: headerStyle),
                  ),
                ],
              ),
            ),

            // Producer rows
            ...producers.asMap().entries.map((entry) {
              final idx = entry.key;
              final producer = entry.value;
              final data = producerData[producer]!;
              final type = producerType[producer] ?? 'Soğuk Süt';
              final isHot = type.toLowerCase().contains('sıcak');
              final bgColor = idx % 2 == 0 ? Colors.white : AppColors.gray50;
              final total = producerTotals[producer] ?? 0.0;

              // Calculate S and A totals
              double sTotal = 0, aTotal = 0;
              data.forEach((day, vakitMap) {
                sTotal += vakitMap['S'] ?? 0;
                aTotal += vakitMap['A'] ?? 0;
              });

              return Column(
                children: [
                  // Sabah row
                  Container(
                    color: bgColor,
                    child: Row(
                      children: [
                        // No - merged over 2 rows visually by showing only on S row
                        Container(
                          width: noColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: Colors.transparent, width: 0.5),
                            ),
                          ),
                          child: Text(
                            '${idx + 1}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.gray600),
                          ),
                        ),
                        // Name - merged
                        Container(
                          width: nameColWidth,
                          height: rowHeight,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.only(left: 6),
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: Colors.transparent, width: 0.5),
                            ),
                          ),
                          child: Text(
                            producer,
                            style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.gray800),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // S indicator
                        Container(
                          width: vakitColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: AppColors.gray200, width: 0.5),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: isHot ? const Color(0xFFFEE2E2) : const Color(0xFFDBEAFE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'S',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isHot ? const Color(0xFFDC2626) : const Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ),
                        // Day values for Sabah
                        ...List.generate(daysCount, (i) {
                          final day = i + 1;
                          final val = data[day]?['S'] ?? 0.0;
                          final hasValue = val > 0;
                          return Container(
                            width: dayColWidth,
                            height: rowHeight,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: AppColors.gray100, width: 0.5),
                                bottom: BorderSide(color: AppColors.gray200, width: 0.5),
                              ),
                            ),
                            child: Text(
                              hasValue ? val.toStringAsFixed(0) : '-',
                              style: hasValue ? cellStyle : emptyStyle,
                            ),
                          );
                        }),
                        // S total
                        Container(
                          width: totalColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            border: Border.all(color: AppColors.gray200, width: 0.5),
                          ),
                          child: Text(
                            sTotal > 0 ? sTotal.toStringAsFixed(0) : '-',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: sTotal > 0 ? const Color(0xFF1D4ED8) : AppColors.gray300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Akşam row
                  Container(
                    color: bgColor,
                    child: Row(
                      children: [
                        // No - empty for merged look
                        Container(
                          width: noColWidth,
                          height: rowHeight,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: AppColors.gray300, width: 1),
                            ),
                          ),
                        ),
                        // Name - empty for merged look
                        Container(
                          width: nameColWidth,
                          height: rowHeight,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: AppColors.gray300, width: 1),
                            ),
                          ),
                        ),
                        // A indicator
                        Container(
                          width: vakitColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            border: Border(
                              right: BorderSide(color: AppColors.gray200, width: 0.5),
                              bottom: BorderSide(color: AppColors.gray300, width: 1),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'A',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gray500,
                              ),
                            ),
                          ),
                        ),
                        // Day values for Akşam
                        ...List.generate(daysCount, (i) {
                          final day = i + 1;
                          final val = data[day]?['A'] ?? 0.0;
                          final hasValue = val > 0;
                          return Container(
                            width: dayColWidth,
                            height: rowHeight,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              border: Border(
                                right: BorderSide(color: AppColors.gray100, width: 0.5),
                                bottom: BorderSide(color: AppColors.gray300, width: 1),
                              ),
                            ),
                            child: Text(
                              hasValue ? val.toStringAsFixed(0) : '-',
                              style: hasValue ? cellStyle : emptyStyle,
                            ),
                          );
                        }),
                        // A total
                        Container(
                          width: totalColWidth,
                          height: rowHeight,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            border: Border.all(color: AppColors.gray200, width: 0.5),
                          ),
                          child: Text(
                            aTotal > 0 ? aTotal.toStringAsFixed(0) : '-',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: aTotal > 0 ? const Color(0xFF1D4ED8) : AppColors.gray300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }),

            // Grand total row
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0284C7),
              ),
              child: Row(
                children: [
                  Container(
                    width: noColWidth + nameColWidth + vakitColWidth,
                    height: 32,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      'GENEL TOPLAM',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  ...List.generate(daysCount, (i) {
                    final day = i + 1;
                    double dayTotal = 0;
                    for (var producer in producers) {
                      dayTotal += (producerData[producer]![day]?['S'] ?? 0);
                      dayTotal += (producerData[producer]![day]?['A'] ?? 0);
                    }
                    return Container(
                      width: dayColWidth,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                      ),
                      child: Text(
                        dayTotal > 0 ? dayTotal.toStringAsFixed(0) : '-',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: dayTotal > 0 ? Colors.white : Colors.white54,
                        ),
                      ),
                    );
                  }),
                  Container(
                    width: totalColWidth,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0369A1),
                      border: Border.all(color: Colors.white.withOpacity(0.2), width: 0.5),
                    ),
                    child: Text(
                      producerTotals.values.fold(0.0, (sum, v) => sum + v).toStringAsFixed(0),
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
