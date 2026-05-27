import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/firestore_service.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import 'package:go_router/go_router.dart';

class FirmaRaporlar extends StatefulWidget {
  const FirmaRaporlar({super.key});

  @override
  State<FirmaRaporlar> createState() => _FirmaRaporlarState();
}

class _FirmaRaporlarState extends State<FirmaRaporlar> {
  String _selectedFilter = 'Günlük'; // 'Günlük', 'Aylık', 'Yıllık'
  DateTime _selectedDate = DateTime.now();

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
          'Süt Toplama Raporu',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirestoreService().getCollectionsStream(firma: currentFirmaName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Filter documents based on selected period
          final filteredDocs = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['timestamp'] as Timestamp?;
            if (ts == null) return false;
            final date = ts.toDate();

            switch (_selectedFilter) {
              case 'Günlük':
                return date.year == _selectedDate.year &&
                    date.month == _selectedDate.month &&
                    date.day == _selectedDate.day;
              case 'Aylık':
                return date.year == _selectedDate.year &&
                    date.month == _selectedDate.month;
              case 'Yıllık':
                return date.year == _selectedDate.year;
              default:
                return true;
            }
          }).toList();

          // Calculate total milk
          double totalMilk = 0.0;
          final Map<String, double> producerTotals = {};

          for (var doc in filteredDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final mVal = data['m'] ?? 0;
            final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);
            totalMilk += m;

            final producer = data['u'] as String? ?? 'Bilinmiyor';
            producerTotals[producer] = (producerTotals[producer] ?? 0.0) + m;
          }

          // Sort producers by total descending
          final sortedProducers = producerTotals.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));

          // Format period label
          String periodLabel;
          switch (_selectedFilter) {
            case 'Günlük':
              periodLabel = DateFormat('d MMMM yyyy', 'tr_TR').format(_selectedDate);
              break;
            case 'Aylık':
              periodLabel = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);
              break;
            case 'Yıllık':
              periodLabel = _selectedDate.year.toString();
              break;
            default:
              periodLabel = '';
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Filter Selector
              _buildFilterSelector(),
              const SizedBox(height: 12),

              // Period navigation
              _buildPeriodNavigation(periodLabel),
              const SizedBox(height: 16),

              // Total milk summary card
              _buildTotalSummaryCard(totalMilk, filteredDocs.length),
              const SizedBox(height: 16),

              // Top producers
              _buildTopProducersCard(sortedProducers),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterSelector() {
    final filters = ['Günlük', 'Aylık', 'Yıllık'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.gray100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedFilter = filter;
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    filter,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary600 : AppColors.gray500,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPeriodNavigation(String label) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: () {
            setState(() {
              switch (_selectedFilter) {
                case 'Günlük':
                  _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                  break;
                case 'Aylık':
                  _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                  break;
                case 'Yıllık':
                  _selectedDate = DateTime(_selectedDate.year - 1, 1, 1);
                  break;
              }
            });
          },
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        GestureDetector(
          onTap: () async {
            if (_selectedFilter == 'Günlük') {
              final picked = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (picked != null) {
                setState(() => _selectedDate = picked);
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.gray200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.primary600),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.gray800,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              switch (_selectedFilter) {
                case 'Günlük':
                  _selectedDate = _selectedDate.add(const Duration(days: 1));
                  break;
                case 'Aylık':
                  _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                  break;
                case 'Yıllık':
                  _selectedDate = DateTime(_selectedDate.year + 1, 1, 1);
                  break;
              }
            });
          },
          icon: const Icon(Icons.chevron_right_rounded),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildTotalSummaryCard(double totalMilk, int entryCount) {
    final bool useTons = totalMilk >= 10000;
    final String displayValue = useTons
        ? (totalMilk / 1000).toStringAsFixed(2)
        : totalMilk.toStringAsFixed(0);
    final String unit = useTons ? 'Ton' : 'Litre';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0369A1), Color(0xFF0284C7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0369A1).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Toplanan Süt',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.85),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _selectedFilter,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                displayValue,
                style: GoogleFonts.inter(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  unit,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.receipt_long_rounded, size: 14, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  '$entryCount kayıt',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopProducersCard(List<MapEntry<String, double>> sortedProducers) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Text(
                'En Çok Süt Veren Üreticiler',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$_selectedFilter bazında sıralama',
            style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
          ),
          const SizedBox(height: 16),
          if (sortedProducers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.water_drop_outlined, size: 40, color: AppColors.gray300),
                    const SizedBox(height: 8),
                    Text(
                      'Bu dönemde süt toplama kaydı bulunmuyor.',
                      style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                    ),
                  ],
                ),
              ),
            )
          else
            ...sortedProducers.take(10).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final e = entry.value;
              final rank = idx + 1;
              final double miktar = e.value;

              final bool useTons = miktar >= 10000;
              final String formattedMiktar = useTons
                  ? '${(miktar / 1000).toStringAsFixed(2)} Ton'
                  : '${miktar.toStringAsFixed(0)} LT';

              final medalColor = rank == 1
                  ? const Color(0xFFFFD700)
                  : rank == 2
                      ? const Color(0xFFC0C0C0)
                      : rank == 3
                          ? const Color(0xFFCD7F32)
                          : AppColors.gray300;

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: rank <= 3 ? medalColor.withOpacity(0.06) : AppColors.gray50,
                  borderRadius: BorderRadius.circular(10),
                  border: rank <= 3 ? Border.all(color: medalColor.withOpacity(0.15)) : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: rank <= 3 ? medalColor.withOpacity(0.2) : AppColors.gray100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: rank <= 3
                            ? Icon(
                                Icons.emoji_events_rounded,
                                size: 16,
                                color: medalColor,
                              )
                            : Text(
                                '$rank',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.gray500,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        e.key,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        formattedMiktar,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
