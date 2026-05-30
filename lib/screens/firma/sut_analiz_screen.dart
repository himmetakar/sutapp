import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';

class SutAnalizScreen extends StatefulWidget {
  const SutAnalizScreen({super.key});

  @override
  State<SutAnalizScreen> createState() => _SutAnalizScreenState();
}

class _SutAnalizScreenState extends State<SutAnalizScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if (!AppConstants.isProduction) {
      _initializeAnalizData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeAnalizData() async {
    final db = FirebaseFirestore.instance;
    final snap = await db.collection('sut_analiz').limit(1).get();
    if (snap.docs.isEmpty) {
      await db.collection('sut_analiz').add({
        'tip': 'Üretici',
        'hedef': 'Ahmet Yılmaz (Üretici)',
        'tarih': '26 May 2026 09:30',
        'yag': 3.6,
        'protein': 3.2,
        'su': 0.0,
        'sicaklik': 4.2,
        'somatik': 180000,
        'durum': 'Normal',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await db.collection('sut_analiz').add({
        'tip': 'Üretici',
        'hedef': 'Ayşe Demir (Üretici)',
        'tarih': '26 May 2026 08:15',
        'yag': 2.9, // Low fat warning!
        'protein': 2.8,
        'su': 5.0, // Water addition warning!
        'sicaklik': 8.5, // High temp warning!
        'somatik': 350000,
        'durum': 'Riskli',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await db.collection('sut_analiz').add({
        'tip': 'Tank',
        'hedef': 'Merkez Tank #1',
        'tarih': '25 May 2026 17:00',
        'yag': 3.5,
        'protein': 3.1,
        'su': 0.0,
        'sicaklik': 3.8,
        'somatik': 150000,
        'durum': 'Normal',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await db.collection('sut_analiz').add({
        'tip': 'Tank',
        'hedef': 'Araç Tankı - 34 EMR 190',
        'tarih': '25 May 2026 12:45',
        'yag': 3.4,
        'protein': 3.0,
        'su': 1.2,
        'sicaklik': 5.0,
        'somatik': 220000,
        'durum': 'Normal',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Analiz Raporları',
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
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary600,
          unselectedLabelColor: AppColors.gray500,
          indicatorColor: AppColors.primary600,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Üretici Analizleri'),
            Tab(text: 'Tank Analizleri'),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('sut_analiz')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || _isRefreshing) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          return TabBarView(
            controller: _tabController,
            children: [
              _buildAnalizList(docs, 'Üretici'),
              _buildAnalizList(docs, 'Tank'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildAnalizList(List<QueryDocumentSnapshot> docs, String tipFilter) {
    final filtered = docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final String tipVal = data['tip'] ?? '';
      if (tipFilter == 'Üretici') {
        return tipVal == 'Üretici' || tipVal == 'Müşteri';
      }
      return tipVal == tipFilter;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Text(
          'Analiz kaydı bulunamadı.',
          style: GoogleFonts.inter(color: AppColors.gray500),
        ),
      );
    }

    // Compute averages
    double totalYag = 0;
    double totalProtein = 0;
    double totalSicaklik = 0;
    int riskliCount = 0;

    for (var doc in filtered) {
      final data = doc.data() as Map<String, dynamic>;
      totalYag += (data['yag'] as num?)?.toDouble() ?? 0.0;
      totalProtein += (data['protein'] as num?)?.toDouble() ?? 0.0;
      totalSicaklik += (data['sicaklik'] as num?)?.toDouble() ?? 0.0;
      if (data['durum'] == 'Riskli') {
        riskliCount++;
      }
    }

    final int totalCount = filtered.length;
    final double avgYag = totalCount > 0 ? totalYag / totalCount : 0.0;
    final double avgProtein = totalCount > 0 ? totalProtein / totalCount : 0.0;
    final double avgSicaklik = totalCount > 0 ? totalSicaklik / totalCount : 0.0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Average Stats Box
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.gray200),
            boxShadow: AppShadows.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Genel Ortalama Değerler',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.gray800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatItem('Ort. Yağ', '${avgYag.toStringAsFixed(2)}%', const Color(0xFF3B82F6)),
                  _buildStatItem('Ort. Protein', '${avgProtein.toStringAsFixed(2)}%', const Color(0xFF10B981)),
                  _buildStatItem('Ort. Sıcaklık', '${avgSicaklik.toStringAsFixed(1)}°C', const Color(0xFFF59E0B)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Riskli Alert Box if any riskli test exists
        if (riskliCount > 0)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFEE2E2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dikkat: Standart dışı değerlere sahip $riskliCount adet analiz tespit edildi! Lütfen detayları kontrol edin.',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF991B1B),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Analysis Cards List
        ...filtered.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final String hedef = data['hedef'] ?? '';
          final String tarih = data['tarih'] ?? '';
          final double yag = (data['yag'] as num?)?.toDouble() ?? 0.0;
          final double protein = (data['protein'] as num?)?.toDouble() ?? 0.0;
          final double su = (data['su'] as num?)?.toDouble() ?? 0.0;
          final double sicaklik = (data['sicaklik'] as num?)?.toDouble() ?? 0.0;
          final int somatik = (data['somatik'] as num?)?.toInt() ?? 0;
          final String durum = data['durum'] ?? 'Normal';

          final isRiskli = durum == 'Riskli';

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isRiskli ? const Color(0xFFFCA5A5) : AppColors.gray200,
                width: isRiskli ? 1.5 : 1.0,
              ),
              boxShadow: AppShadows.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Target & Date)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hedef,
                            style: GoogleFonts.inter(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gray800,
                            ),
                          ),
                          Text(
                            tarih,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.gray400,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRiskli ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRiskli ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        durum,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isRiskli ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Metrics Grid
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMetricCol('Yağ', '${yag.toStringAsFixed(1)}%', yag < 3.0 ? const Color(0xFFEF4444) : AppColors.gray700),
                    _buildMetricCol('Protein', '${protein.toStringAsFixed(1)}%', protein < 2.9 ? const Color(0xFFEF4444) : AppColors.gray700),
                    _buildMetricCol('Eklenen Su', '${su.toStringAsFixed(1)}%', su > 0.0 ? const Color(0xFFEF4444) : AppColors.gray700),
                    _buildMetricCol('Sıcaklık', '${sicaklik.toStringAsFixed(1)}°C', sicaklik > 6.0 ? const Color(0xFFEF4444) : AppColors.gray700),
                  ],
                ),

                // Somatik Hücre Count Row
                if (somatik > 0) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.gray100),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Somatik Hücre Sayısı:',
                        style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.gray500),
                      ),
                      Text(
                        '${somatik.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} / mL',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: somatik > 300000 ? const Color(0xFFEF4444) : AppColors.gray700,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatItem(String label, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            color: AppColors.gray500,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCol(String label, String val, Color valColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            color: AppColors.gray400,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          val,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: valColor,
          ),
        ),
      ],
    );
  }
}
