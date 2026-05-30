import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';

class FirmaTanklar extends StatefulWidget {
  const FirmaTanklar({super.key});

  @override
  State<FirmaTanklar> createState() => _FirmaTanklarState();
}

class _FirmaTanklarState extends State<FirmaTanklar> {
  bool _isRefreshing = false;

  void _showTankIcerik(BuildContext context, String tankAdi) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, sc) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.gray300,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(
                    '$tankAdi Giriş Kayıtları',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF3B82F6), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bu tanka son giren süt toplama kayıtları listelenmektedir.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF1D4ED8), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('toplamalar')
                    .where('tank', isEqualTo: tankAdi)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rawDocs = snapshot.data?.docs ?? [];
                  if (rawDocs.isEmpty) {
                    return Center(
                      child: Text(
                        'Kayıt bulunamadı.',
                        style: GoogleFonts.inter(color: AppColors.gray400),
                      ),
                    );
                  }

                  // Sort in memory by timestamp descending
                  final docs = List<QueryDocumentSnapshot>.from(rawDocs);
                  docs.sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;

                    final aTs = aData['timestamp'];
                    final bTs = bData['timestamp'];

                    DateTime aDate = DateTime(1970);
                    DateTime bDate = DateTime(1970);

                    if (aTs is Timestamp) {
                      aDate = aTs.toDate();
                    } else if (aData['tarih'] is String) {
                      aDate = _parseDateStr(aData['tarih']);
                    }

                    if (bTs is Timestamp) {
                      bDate = bTs.toDate();
                    } else if (bData['tarih'] is String) {
                      bDate = _parseDateStr(bData['tarih']);
                    }

                    return bDate.compareTo(aDate);
                  });

                  final displayDocs = docs.take(15).toList();

                  return ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayDocs.length,
                    itemBuilder: (_, i) {
                      final doc = displayDocs[i];
                      final data = doc.data() as Map<String, dynamic>;
                      final u = data['u'] ?? 'Bilinmeyen Üretici';
                      final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
                      final s = data['s'] ?? '';
                      
                      final ts = data['timestamp'];
                      String t = '';
                      if (ts is Timestamp) {
                        t = DateFormat('dd.MM.yyyy').format(ts.toDate());
                      } else {
                        t = data['tarih'] ?? '';
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: ListTile(
                          title: Text(
                            u,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gray800),
                          ),
                          subtitle: Text(
                            '$t $s',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                          ),
                          trailing: Text(
                            '${m.toStringAsFixed(1)} LT',
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: const Color(0xFF3B82F6), fontSize: 14),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

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
          'Tank Durumu',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              setState(() => _isRefreshing = true);
              await Future.delayed(const Duration(milliseconds: 600));
              setState(() => _isRefreshing = false);
            },
          ),
          IconButton(
            icon: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF3B82F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 18),
            ),
            onPressed: () => context.push('/firma/tanklar/ekle'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tanklar')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isRefreshing) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          // Compute stats
          int totalTanks = docs.length;
          int fullTanks = 0;
          int emptyTanks = 0;
          double totalFillRate = 0.0;

          List<QueryDocumentSnapshot> merkezTanks = [];
          List<QueryDocumentSnapshot> aracTanks = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final String tip = data['tip'] ?? 'merkez';
            final double stok = (data['stok'] as num?)?.toDouble() ?? 0.0;
            final double kap = (data['kap'] as num?)?.toDouble() ?? 2000.0;
            final double fillRate = kap > 0 ? (stok / kap) : 0.0;

            totalFillRate += fillRate;

            if (fillRate >= 0.8) {
              fullTanks++;
            } else if (stok <= 0) {
              emptyTanks++;
            }

            if (tip == 'merkez') {
              merkezTanks.add(doc);
            } else {
              aracTanks.add(doc);
            }
          }

          final double avgFillRate = totalTanks > 0 ? (totalFillRate / totalTanks) * 100 : 0.0;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Metrics Summary Grid (4 items)
              Row(
                children: [
                  Expanded(child: _buildMetricCard('Toplam Tank', '$totalTanks', const Color(0xFF3B82F6), Icons.storage_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Dolu (>=80%)', '$fullTanks', const Color(0xFFEF4444), Icons.opacity_rounded)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Boş Tank', '$emptyTanks', const Color(0xFFF59E0B), Icons.opacity_outlined)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildMetricCard('Ort. Doluluk', '%${avgFillRate.toStringAsFixed(0)}', const Color(0xFF10B981), Icons.align_vertical_bottom_rounded)),
                ],
              ),
              const SizedBox(height: 24),

              // Merkez Tankları Section
              _buildSectionTitle('Merkez Tankları', merkezTanks.length),
              const SizedBox(height: 12),
              merkezTanks.isEmpty
                  ? _buildEmptyState('Kayıtlı merkez tankı bulunmamaktadır.')
                  : _buildVerticalTankList(merkezTanks),

              const SizedBox(height: 28),

              // Araç Tankları Section
              _buildSectionTitle('Araç Tankları', aracTanks.length),
              const SizedBox(height: 12),
              aracTanks.isEmpty
                  ? _buildEmptyState('Kayıtlı araç tankı bulunmamaktadır.')
                  : _buildVerticalTankList(aracTanks),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.gray800,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.gray100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count Adet',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.gray600,
            ),
          ),
        ),
      ],
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

  Widget _buildVerticalTankList(List<QueryDocumentSnapshot> tanks) {
    final double cardHeight = 88.0;
    final double spacing = 8.0;
    final double totalItemHeight = cardHeight + spacing;
    final double containerHeight = tanks.length <= 4 
        ? (tanks.length * totalItemHeight) 
        : (4 * totalItemHeight);

    return SizedBox(
      height: containerHeight,
      child: ListView.builder(
        scrollDirection: Axis.vertical,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: tanks.length,
        itemBuilder: (context, index) {
          final data = tanks[index].data() as Map<String, dynamic>;
          final String ad = data['ad'] ?? '';
          final double stok = (data['stok'] as num?)?.toDouble() ?? 0.0;
          final double kap = (data['kap'] as num?)?.toDouble() ?? 2000.0;
          final double fillPercent = kap > 0 ? (stok / kap) : 0.0;
          final String tip = data['tip'] ?? 'merkez';
          final String arac = data['arac'] ?? '';

          Color gaugeColor = const Color(0xFF3B82F6);
          final bool isOverflow = stok > kap;
          if (isOverflow || fillPercent >= 0.8) {
            gaugeColor = const Color(0xFFEF4444);
          } else if (fillPercent >= 0.5) {
            gaugeColor = const Color(0xFFF59E0B);
          }

          return Container(
            height: cardHeight,
            margin: EdgeInsets.only(bottom: spacing),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isOverflow ? Colors.red : AppColors.gray200, width: isOverflow ? 1.5 : 1.0),
              boxShadow: AppShadows.sm,
            ),
            child: Row(
              children: [
                // Left: Storage Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.storage_rounded,
                      color: Color(0xFF3B82F6),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Middle: Name & Vehicle Info
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        ad,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tip == 'merkez' ? 'Merkez Tankı' : (arac.isNotEmpty ? arac : 'Araç Tankı'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          color: AppColors.gray400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${stok.toStringAsFixed(0)} / ${kap.toStringAsFixed(0)} LT',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: isOverflow ? Colors.red : AppColors.gray600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Right: Horizontal Progress Bar & Details
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Doluluk',
                            style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.gray400),
                          ),
                          Text(
                            '%${(fillPercent * 100).toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: isOverflow ? Colors.red : AppColors.gray800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: fillPercent.clamp(0.0, 1.0),
                          minHeight: 8,
                          backgroundColor: AppColors.gray100,
                          valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Action Button: Detay
                GestureDetector(
                  onTap: () => _showTankIcerik(context, ad),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.visibility_rounded, size: 12, color: AppColors.gray600),
                        const SizedBox(width: 4),
                        Text(
                          'Detay',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 16),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              color: AppColors.gray800,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 8.5,
              color: AppColors.gray500,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  DateTime _parseDateStr(String dateStr) {
    try {
      final parts = dateStr.split('.');
      if (parts.length == 3) {
        final day = int.parse(parts[0]);
        final month = int.parse(parts[1]);
        final year = int.parse(parts[2]);
        return DateTime(year, month, day);
      }
    } catch (_) {}
    return DateTime(1970);
  }
}
