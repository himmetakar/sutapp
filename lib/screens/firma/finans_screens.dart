import 'package:flutter/material.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

// --- PLACEHOLDER VIEW ---
class FinansPlaceholderScreen extends StatelessWidget {
  final String title;
  const FinansPlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline_rounded, size: 64, color: AppColors.gray400),
            const SizedBox(height: 16),
            Text(
              '$title özelliği yakında eklenecektir.',
              style: GoogleFonts.inter(fontSize: 16, color: AppColors.gray600, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

// --- MAIN MENU GRID ---
class FinansYonetimiScreen extends StatelessWidget {
  const FinansYonetimiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final menuItems = [
      {'title': 'Finansal Bakış', 'icon': Icons.speed_rounded, 'color': Colors.orange, 'path': '/firma/finans/genel-bakis'},
      {'title': 'Faturalar', 'icon': Icons.description_rounded, 'color': Colors.blue, 'path': '/firma/finans/faturalar'},
      {'title': 'Giderler', 'icon': Icons.credit_card_rounded, 'color': Colors.red, 'path': '/firma/finans/giderler'},
      {'title': 'Gelirler', 'icon': Icons.monetization_on_rounded, 'color': Colors.green, 'path': '/firma/finans/gelirler'},
      {'title': 'Avanslar', 'icon': Icons.handshake_rounded, 'color': Colors.orange, 'path': '/firma/finans/avanslar'},
      {'title': 'Tahsilat Yap', 'icon': Icons.credit_card_rounded, 'color': Colors.indigo, 'path': '/firma/tahsilat'},
      {'title': 'Devir İşlemleri', 'icon': Icons.sync_alt_rounded, 'color': Colors.purple, 'path': '/firma/finans/devir'},
      {'title': 'Süt Ödemeleri', 'icon': Icons.people_rounded, 'color': Colors.blue, 'path': '/firma/finans/sut-odemeleri'},
      {'title': 'Ödeme Geçmişi', 'icon': Icons.history_rounded, 'color': Colors.purple, 'path': '/firma/finans/odeme-gecmisi'},
      {'title': 'Müşteri Cezaları', 'icon': Icons.gavel_rounded, 'color': Colors.red, 'path': '/firma/finans/cezalar'},
      {'title': 'Kesintiler', 'icon': Icons.content_cut_rounded, 'color': Colors.red, 'path': '/firma/finans/kesintiler'},
    ];

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text('Finans Yönetimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma'),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;
          final isTablet = constraints.maxWidth >= 640 && constraints.maxWidth < 1024;
          final crossAxisCount = isDesktop ? 5 : (isTablet ? 3 : 2);

          return GridView.builder(
            padding: const EdgeInsets.all(24),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.1,
            ),
            itemCount: menuItems.length,
            itemBuilder: (context, index) {
              final item = menuItems[index];
              return AppCard(
                shadow: AppShadows.sm,
                child: InkWell(
                  onTap: () => context.go(item['path'] as String),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item['icon'] as IconData, color: item['color'] as Color, size: 24),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        item['title'] as String,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray800),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// --- FINANSAL GENEL BAKIS SCREEN ---
class FinansalGenelBakisScreen extends StatefulWidget {
  const FinansalGenelBakisScreen({super.key});

  @override
  State<FinansalGenelBakisScreen> createState() => _FinansalGenelBakisScreenState();
}

class _FinansalGenelBakisScreenState extends State<FinansalGenelBakisScreen> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: Text('Finansal Genel Bakış', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('faturalar')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, faturaSnapshot) {
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('giderler')
                .where('firma', isEqualTo: currentFirmaName)
                .snapshots(),
            builder: (context, giderSnapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('tahsilatlar')
                    .where('firma', isEqualTo: currentFirmaName)
                    .snapshots(),
                builder: (context, tahsilatSnapshot) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('kesintiler')
                        .where('firma', isEqualTo: currentFirmaName)
                        .snapshots(),
                    builder: (context, kesintiSnapshot) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('avanslar')
                            .where('firma', isEqualTo: currentFirmaName)
                            .snapshots(),
                        builder: (context, avansSnapshot) {
                          double totalFatura = 0.0;
                          int faturaCount = 0;
                          double totalGider = 0.0;
                          int giderCount = 0;
                          double totalGelir = 0.0;
                          int gelirCount = 0;
                          double totalAvans = 0.0;
                          int avansCount = 0;
                          double totalKesinti = 0.0;

                          // Parse invoices
                          if (faturaSnapshot.hasData) {
                            final docs = faturaSnapshot.data!.docs;
                            for (var doc in docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final t = (data['timestamp'] as Timestamp?)?.toDate();
                              if (t != null && t.year == _selectedDate.year && t.month == _selectedDate.month) {
                                faturaCount++;
                                final double val = (data['toplam'] as num?)?.toDouble() ?? 0.0;
                                totalFatura += val;
                              }
                            }
                          }

                          // Parse expenses
                          if (giderSnapshot.hasData) {
                            final docs = giderSnapshot.data!.docs;
                            for (var doc in docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final t = (data['timestamp'] as Timestamp?)?.toDate();
                              if (t != null && t.year == _selectedDate.year && t.month == _selectedDate.month) {
                                giderCount++;
                                final double val = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                                totalGider += val;
                              }
                            }
                          }

                          // Parse collections/revenue
                          if (tahsilatSnapshot.hasData) {
                            final docs = tahsilatSnapshot.data!.docs;
                            for (var doc in docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final t = (data['timestamp'] as Timestamp?)?.toDate();
                              if (t != null && t.year == _selectedDate.year && t.month == _selectedDate.month) {
                                gelirCount++;
                                final double val = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                                totalGelir += val;
                              }
                            }
                          }

                          // Parse kesintiler
                          if (kesintiSnapshot.hasData) {
                            final docs = kesintiSnapshot.data!.docs;
                            for (var doc in docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final durum = data['durum'] as String? ?? 'aktif';
                              if (durum == 'iptal') continue;
                              final t = (data['timestamp'] as Timestamp?)?.toDate();
                              if (t != null && t.year == _selectedDate.year && t.month == _selectedDate.month) {
                                final double val = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                                totalKesinti += val;
                              }
                            }
                          }

                          // Parse avanslar
                          if (avansSnapshot.hasData) {
                            final docs = avansSnapshot.data!.docs;
                            for (var doc in docs) {
                              final data = doc.data() as Map<String, dynamic>;
                              final t = (data['timestamp'] as Timestamp?)?.toDate();
                              if (t != null && t.year == _selectedDate.year && t.month == _selectedDate.month) {
                                avansCount++;
                                final double val = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                                totalAvans += val;
                              }
                            }
                          }

                          final formatNumber = NumberFormat('#,##0', 'tr_TR');
                          final double totalGelirCalculated = totalGelir + totalKesinti;
                          final double totalGiderCalculated = totalGider + totalAvans;
                          final double netDurum = totalGelirCalculated - totalGiderCalculated;

                          return ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              // Date Selector
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.chevron_left_rounded),
                                    onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1)),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    monthStr,
                                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                  ),
                                  const SizedBox(width: 12),
                                  IconButton(
                                    icon: const Icon(Icons.chevron_right_rounded),
                                    onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1)),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary600),
                                    onPressed: () => setState(() {}),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Grid of 6 Cards
                              GridView.count(
                                crossAxisCount: MediaQuery.of(context).size.width >= 600 ? 3 : 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 12,
                                mainAxisSpacing: 12,
                                childAspectRatio: 1.15,
                                children: [
                                  _buildBakisCard(
                                    title: 'Faturalar',
                                    subtext: '$faturaCount fatura',
                                    value: '${formatNumber.format(totalFatura)} ₺',
                                    icon: Icons.description_rounded,
                                    color: Colors.blue,
                                    onTap: () => context.go('/firma/finans/faturalar'),
                                  ),
                                  _buildBakisCard(
                                    title: 'Giderler',
                                    subtext: '$giderCount gider',
                                    value: '${formatNumber.format(totalGider)} ₺',
                                    icon: Icons.credit_card_rounded,
                                    color: Colors.red,
                                    onTap: () => context.go('/firma/finans/giderler'),
                                  ),
                                  _buildBakisCard(
                                    title: 'Gelirler',
                                    subtext: '$gelirCount gelir',
                                    value: '${formatNumber.format(totalGelir)} ₺',
                                    icon: Icons.monetization_on_rounded,
                                    color: Colors.green,
                                    onTap: () => context.go('/firma/finans/gelirler'),
                                  ),
                                  _buildBakisCard(
                                    title: 'Ödeme Geçmişi',
                                    subtext: 'Mali raporlar',
                                    value: 'Analiz',
                                    icon: Icons.history_rounded,
                                    color: Colors.purple,
                                    onTap: () => context.go('/firma/finans/odeme-gecmisi'),
                                  ),
                                  _buildBakisCard(
                                    title: 'Devir',
                                    subtext: 'Ödeme devri',
                                    value: 'Yönetim',
                                    icon: Icons.sync_alt_rounded,
                                    color: Colors.purple,
                                    onTap: () => context.go('/firma/finans/devir'),
                                  ),
                                  _buildBakisCard(
                                    title: 'Avanslar',
                                    subtext: '$avansCount avans',
                                    value: '${formatNumber.format(totalAvans)} ₺',
                                    icon: Icons.money_off_rounded,
                                    color: Colors.orange,
                                    onTap: () => context.go('/firma/finans/avanslar'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // Summary Card
                              AppCard(
                                shadow: AppShadows.md,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$monthStr Özeti',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildSummaryRow('Toplam Gelir (Süt + Ürün):', '${formatNumber.format(totalGelirCalculated)} ₺', AppColors.primary600),
                                    const SizedBox(height: 10),
                                    _buildSummaryRow('Toplam Gider (Avans + Gider):', '${formatNumber.format(totalGiderCalculated)} ₺', Colors.red),
                                    const Divider(height: 24, color: AppColors.gray200),
                                    _buildSummaryRow(
                                      'Net Durum:',
                                      '${netDurum >= 0 ? '+' : ''}${formatNumber.format(netDurum)} ₺',
                                      netDurum >= 0 ? Colors.green : Colors.red,
                                      isBold: true,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBakisCard({
    required String title,
    required String subtext,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AppCard(
      shadow: AppShadows.sm,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 20),
                const Icon(Icons.chevron_right_rounded, color: AppColors.gray400, size: 16),
              ],
            ),
            const Spacer(),
            Text(title, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.gray700)),
            Text(subtext, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
            const SizedBox(height: 4),
            Text(value, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color valueColor, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
        Text(value, style: GoogleFonts.inter(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor)),
      ],
    );
  }
}

// --- FATURALAR SCREEN ---
class FaturalarScreen extends StatefulWidget {
  const FaturalarScreen({super.key});

  @override
  State<FaturalarScreen> createState() => _FaturalarScreenState();
}

class _FaturalarScreenState extends State<FaturalarScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'tumu'; // tumu, aktif, odendi, iptal

  void _changeMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return Scaffold(
      appBar: AppBar(
        title: Text('Faturalar', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/firma/finans/faturalar/ekle'),
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Fatura Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('faturalar')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          int totalCount = 0;
          int aktifCount = 0;
          int odendiCount = 0;
          int iptalCount = 0;

          final List<QueryDocumentSnapshot> monthDocs = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final date = timestamp?.toDate() ?? DateTime.now();

            if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
              monthDocs.add(doc);
              final durum = data['durum'] as String? ?? 'aktif';
              if (durum == 'aktif') aktifCount++;
              else if (durum == 'odendi') odendiCount++;
              else if (durum == 'iptal') iptalCount++;
              totalCount++;
            }
          }

          // Filter by status
          final filteredDocs = monthDocs.where((doc) {
            if (_selectedStatus == 'tumu') return true;
            final data = doc.data() as Map<String, dynamic>;
            final durum = data['durum'] as String? ?? 'aktif';
            return durum == _selectedStatus;
          }).toList();

          double totalFatura = filteredDocs.fold(0.0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            final double val = (data['toplam'] as num?)?.toDouble() ?? 0.0;
            return sum + val;
          });

          return Column(
            children: [
              // Month Selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: AppColors.primary600, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          monthStr,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
              ),

              // Status Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusTab('tumu', 'Tümü', totalCount),
                      _buildStatusTab('aktif', 'Aktif', aktifCount),
                      _buildStatusTab('odendi', 'Ödenen', odendiCount),
                      _buildStatusTab('iptal', 'İptal', iptalCount),
                    ],
                  ),
                ),
              ),

              // Total Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  shadow: AppShadows.sm,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Toplam Tutar', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      Text('${formatNumber.format(totalFatura)} ₺', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary600)),
                    ],
                  ),
                ),
              ),

              // List of Invoices
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Text(
                          'Fatura bulunamadı.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final faturaNo = data['faturaNo'] ?? '';
                          final tip = data['tip'] ?? 'alis';
                          final tedarikci = data['tedarikci'] ?? '';
                          final tarih = data['tarih'] ?? '';
                          final double toplam = (data['toplam'] as num?)?.toDouble() ?? 0.0;
                          final listItems = data['kalemler'] as List? ?? [];
                          final durum = data['durum'] as String? ?? 'aktif';

                          final isAlis = tip == 'alis';

                          Color statusColor;
                          String statusText;
                          if (durum == 'aktif') {
                            statusColor = Colors.blue;
                            statusText = 'Aktif';
                          } else if (durum == 'odendi') {
                            statusColor = Colors.green;
                            statusText = 'Ödendi';
                          } else {
                            statusColor = Colors.red;
                            statusText = 'İptal';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: AppShadows.sm,
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: InkWell(
                              onTap: () => _showFaturaIslemleriDialog(context, doc.id, faturaNo, toplam, durum),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: isAlis ? const Color(0xFFFFEBEE) : const Color(0xFFE8F5E9),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isAlis ? Icons.arrow_outward_rounded : Icons.south_west_rounded,
                                      color: isAlis ? Colors.red : Colors.green,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(faturaNo, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                        Text(tedarikci, style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                                        const SizedBox(height: 2),
                                        Row(
                                          children: [
                                            Text('$tarih • ${listItems.length} kalem', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '${isAlis ? '-' : '+'}${formatNumber.format(toplam)} ₺',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: isAlis ? Colors.red : Colors.green),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.more_vert_rounded, color: AppColors.gray400),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusTab(String statusKey, String label, int count) {
    final isSelected = _selectedStatus == statusKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = statusKey),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary600 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary600 : AppColors.gray300),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  void _showFaturaIslemleriDialog(BuildContext context, String docId, String faturaNo, double toplam, String currentDurum) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Fatura İşlemleri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('"$faturaNo" (${toplam.toStringAsFixed(2)} ₺) faturası üzerinde yapılacak işlemi seçin:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          if (currentDurum != 'odendi')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('faturalar').doc(docId).update({'durum': 'odendi'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fatura ödendi yapıldı!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('Ödendi Yap'),
            ),
          if (currentDurum != 'iptal')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('faturalar').doc(docId).update({'durum': 'iptal'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fatura iptal edildi!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('İptal Et'),
            ),
          if (currentDurum != 'aktif')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('faturalar').doc(docId).update({'durum': 'aktif'});
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Fatura aktif yapıldı!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('Aktif Yap'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('faturalar').doc(docId).delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Fatura silindi!'), backgroundColor: AppColors.success),
              );
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

// --- FATURA EKLE SCREEN ---
class FaturaEkleScreen extends StatefulWidget {
  const FaturaEkleScreen({super.key});

  @override
  State<FaturaEkleScreen> createState() => _FaturaEkleScreenState();
}

class _FaturaEkleScreenState extends State<FaturaEkleScreen> {
  final _faturaNoCtrl = TextEditingController();
  final _tedarikciCtrl = TextEditingController();
  final _aciklamaCtrl = TextEditingController();
  final _faturaTarihiCtrl = TextEditingController();
  
  // Item controllers
  final _urunNameCtrl = TextEditingController();
  final _itemMiktarCtrl = TextEditingController();
  final _itemFiyatCtrl = TextEditingController();
  final _itemToplamFiyatCtrl = TextEditingController();

  double _productSellingPrice = 0.0;

  String _faturaTipi = 'alis'; // 'alis' | 'satis'
  DateTime? _faturaTarihi;

  String _selectedBirim = 'adet';
  String _selectedKategori = 'Genel';

  final List<Map<String, dynamic>> _kalemler = [];

  List<String> _musteriler = [];
  bool _isLoadingMusteriler = true;

  @override
  void initState() {
    super.initState();
    // Generate Invoice Number
    final timeStr = DateFormat('yyyyMMdd-HHmm').format(DateTime.now());
    _faturaNoCtrl.text = 'INV-$timeStr';
    _faturaTarihiCtrl.text = '';
    _loadMusteriler();
  }

  Future<void> _loadMusteriler() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final currentFirmaName = auth.user?.displayName ?? '';
      if (_faturaTipi == 'alis') {
        final snapshot = await FirebaseFirestore.instance
            .collection('cari_firmalar')
            .where('firma', isEqualTo: currentFirmaName)
            .where('tip', isEqualTo: 'tedarikci')
            .get();
        setState(() {
          _musteriler = snapshot.docs.map((doc) => doc['ad'] as String).toList();
          _isLoadingMusteriler = false;
        });
      } else {
        setState(() {
          _musteriler = [
            'Sütaş',
            'Pınar',
            'Torku',
            'İçim',
            'Danone',
            'Ak Gıda',
            'Eker',
            'Mis Süt',
            'SEK',
            'Yörükoğlu',
            'Tahsildaroğlu',
          ];
          _isLoadingMusteriler = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMusteriler = false;
      });
    }
  }

  void _showProductSelectionDialog(BuildContext context, String currentFirmaName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Ürün Seç', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('urunler')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Kayıtlı ürün bulunamadı.\nÖnce Ürün Ekle bölümünden tanımlayın.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final String ad = data['ad'] ?? '';
                    final double fiyat = (data['fiyat'] as num?)?.toDouble() ?? 0.0;
                    final String birim = data['birim'] ?? 'adet';
                    final String kategori = data['kategori'] ?? 'Genel';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(ad, style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('${fiyat.toStringAsFixed(2)} ₺/$birim • $kategori', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
                      onTap: () {
                        setState(() {
                          _urunNameCtrl.text = ad;
                          _itemFiyatCtrl.text = fiyat.toStringAsFixed(2);
                          _productSellingPrice = fiyat;
                          
                          // Match unit
                          _selectedBirim = birim.isNotEmpty ? birim : 'adet';

                          // Match category
                          final String cat = kategori;
                          if (cat.toLowerCase().contains('yem')) {
                            _selectedKategori = 'Firma';
                          } else if (['Araç', 'Personel', 'Genel', 'Bakım', 'Müşteri', 'Firma'].contains(cat)) {
                            _selectedKategori = cat;
                          } else {
                            _selectedKategori = 'Genel';
                          }

                          // Clear previous inputs
                          _itemMiktarCtrl.clear();
                          _itemToplamFiyatCtrl.clear();
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                );
              },
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.go('/firma/urunler');
                },
                icon: const Icon(Icons.add_circle_outline_rounded, color: AppColors.primary600),
                label: Text(
                  'Aradığınız ürün listede yok mu? Ürün Ekle',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.primary600, fontSize: 13),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatNumber = NumberFormat('#,##0', 'tr_TR');
    final double toplamTutar = _kalemler.fold(0.0, (sum, item) {
      final double m = item['miktar'] as double;
      final double f = item['fiyat'] as double;
      return sum + (m * f);
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Fatura Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans/faturalar'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Fatura Bilgileri Card
          AppCard(
            shadow: AppShadows.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fatura Bilgileri', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                const SizedBox(height: 16),
                // Toggle Button
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _faturaTipi == 'alis' ? Colors.orange : Colors.grey[200],
                          foregroundColor: _faturaTipi == 'alis' ? Colors.white : AppColors.gray700,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          setState(() {
                            _faturaTipi = 'alis';
                            _tedarikciCtrl.clear();
                            _isLoadingMusteriler = true;
                          });
                          _loadMusteriler();
                        },
                        child: const Text('Alış Faturası'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _faturaTipi == 'satis' ? Colors.orange : Colors.grey[200],
                          foregroundColor: _faturaTipi == 'satis' ? Colors.white : AppColors.gray700,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          setState(() {
                            _faturaTipi = 'satis';
                            _tedarikciCtrl.clear();
                            _isLoadingMusteriler = true;
                          });
                          _loadMusteriler();
                        },
                        child: const Text('Satış Faturası'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _faturaNoCtrl,
                  decoration: const InputDecoration(labelText: 'Fatura No'),
                ),
                _isLoadingMusteriler
                    ? const SizedBox(
                        height: 50,
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : SearchableDropdown(
                        items: _musteriler,
                        value: _tedarikciCtrl.text.isEmpty ? null : _tedarikciCtrl.text,
                        hint: 'Tedarikçi / Müşteri Firma',
                        label: 'Tedarikçi / Müşteri Firma',
                        onChanged: (val) {
                          setState(() {
                            _tedarikciCtrl.text = val ?? '';
                          });
                        },
                      ),
                const SizedBox(height: 12),
                // Date Picker field
                TextField(
                  controller: _faturaTarihiCtrl,
                  readOnly: true,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _faturaTarihi ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null) {
                      setState(() {
                        _faturaTarihi = picked;
                        _faturaTarihiCtrl.text = DateFormat('dd.MM.yyyy').format(picked);
                      });
                    }
                  },
                  decoration: const InputDecoration(
                    labelText: 'Fatura Tarihi',
                    hintText: 'Tarih Seçin',
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _aciklamaCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Açıklama (Opsiyonel)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Yeni Kalem Ekle Card
          AppCard(
            shadow: AppShadows.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Yeni Kalem Ekle', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _showProductSelectionDialog(context, currentFirmaName),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.gray300),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ürün Seçin *',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.gray500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _urunNameCtrl.text.isEmpty
                                    ? 'Ürün seçmek için tıklayın'
                                    : _urunNameCtrl.text,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: _urunNameCtrl.text.isEmpty
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                  color: _urunNameCtrl.text.isEmpty
                                      ? AppColors.gray400
                                      : AppColors.gray800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.list_alt_rounded, color: AppColors.primary600),
                      ],
                    ),
                  ),
                ),
                if (_urunNameCtrl.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.gray50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gray200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Birim: $_selectedBirim | Fiyat: ${_itemFiyatCtrl.text} ₺ | Kategori: $_selectedKategori',
                            style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _itemMiktarCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Stok (Miktar)',
                          hintText: 'Miktar girin',
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: _itemToplamFiyatCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Toplam Fiyat',
                          hintText: 'Fiyat girin',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      final name = _urunNameCtrl.text;
                      final double? miktar = double.tryParse(_itemMiktarCtrl.text);
                      final double? toplamFiyat = double.tryParse(_itemToplamFiyatCtrl.text);

                      if (name.isEmpty || miktar == null || miktar <= 0 || toplamFiyat == null || toplamFiyat < 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Lütfen geçerli miktar ve toplam fiyat girin.'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                        return;
                      }

                      final double calculatedUnitPrice = miktar > 0 ? (toplamFiyat / miktar) : 0.0;
                      final isYemProduct = name.toLowerCase().contains('yem');
                      final finalCategory = isYemProduct ? 'Firma' : _selectedKategori;

                      setState(() {
                        _kalemler.add({
                          'urun': name,
                          'miktar': miktar,
                          'birim': _selectedBirim,
                          'fiyat': calculatedUnitPrice,
                          'kategori': finalCategory,
                        });
                        // Clear item fields
                        _urunNameCtrl.clear();
                        _itemMiktarCtrl.clear();
                        _itemFiyatCtrl.clear();
                        _itemToplamFiyatCtrl.clear();
                        _productSellingPrice = 0.0;
                        _selectedBirim = 'adet';
                        _selectedKategori = 'Genel';
                      });
                    },
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Kalemi Ekle'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Fatura Kalemleri Card
          AppCard(
            shadow: AppShadows.sm,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fatura Kalemleri (${_kalemler.length})', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                const SizedBox(height: 16),
                if (_kalemler.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.shopping_cart_outlined, size: 48, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Henüz kalem eklenmedi.', style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12)),
                        ],
                      ),
                    ),
                  )
                else ...[
                  ..._kalemler.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final double m = item['miktar'] as double;
                    final double f = item['fiyat'] as double;
                    final double subtotal = m * f;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item['urun'] as String, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                Text('${m.toStringAsFixed(0)} ${item['birim']} • ${f.toStringAsFixed(2)} ₺', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                              ],
                            ),
                          ),
                          Text('${formatNumber.format(subtotal)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.red, size: 18),
                            onPressed: () => setState(() => _kalemler.removeAt(idx)),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Toplam Tutar:', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.gray800)),
                      Text('${formatNumber.format(toplamTutar)} ₺', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary600)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        if (_tedarikciCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lütfen tedarikçi / müşteri seçin.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (_faturaTarihi == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lütfen fatura tarihi seçin.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        if (_kalemler.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Lütfen faturaya en az bir kalem ekleyin.'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        // Save invoice to Firestore
                        await FirebaseFirestore.instance.collection('faturalar').add({
                          'faturaNo': _faturaNoCtrl.text,
                          'tip': _faturaTipi,
                          'tedarikci': _tedarikciCtrl.text,
                          'tarih': DateFormat('dd.MM.yyyy').format(_faturaTarihi!),
                          'aciklama': _aciklamaCtrl.text,
                          'kalemler': _kalemler,
                          'toplam': toplamTutar,
                          'firma': currentFirmaName,
                          'timestamp': FieldValue.serverTimestamp(),
                          'durum': 'aktif',
                        });

                        // Send invoice notification to client
                        await FirebaseFirestore.instance.collection('bildirimler').add({
                          'aliciName': _tedarikciCtrl.text,
                          'baslik': 'Yeni Fatura Tanımlandı',
                          'icerik': '$currentFirmaName tarafından adınıza ${_faturaNoCtrl.text} nolu fatura kesilmiştir. Toplam Tutar: ${formatNumber.format(toplamTutar)} ₺',
                          'okundu': false,
                          'tarih': DateFormat('dd.MM.yyyy').format(_faturaTarihi!),
                          'timestamp': FieldValue.serverTimestamp(),
                          'tip': 'fatura',
                          'faturaNo': _faturaNoCtrl.text,
                        });

                        // If it's a purchase invoice (Alış Faturası), log to expenses AND update inventory stock!
                        if (_faturaTipi == 'alis') {
                          for (var item in _kalemler) {
                            final String urunAd = item['urun'] as String;
                            final double m = item['miktar'] as double;
                            final double f = item['fiyat'] as double;
                            final String itemBirim = item['birim'] as String? ?? 'adet';
                            final String categoryName = item['kategori'] as String? ?? 'Genel';
                            final String resolvedCategory = (urunAd.toLowerCase().contains('yem') || categoryName.toLowerCase() == 'firma')
                                ? 'firma'
                                : categoryName.toLowerCase()
                                    .replaceAll('araç', 'arac')
                                    .replaceAll('bakım', 'bakim')
                                    .replaceAll('müşteri', 'musteri');

                            await FirebaseFirestore.instance.collection('giderler').add({
                              'kategori': resolvedCategory,
                              'aciklama': '${_faturaNoCtrl.text}: $urunAd',
                              'tutar': m * f,
                              'tarih': DateFormat('dd.MM.yyyy').format(_faturaTarihi!),
                              'firma': currentFirmaName,
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                            // Update urunler collection stock and sonGelisFiyati
                            final urunSnap = await FirebaseFirestore.instance.collection('urunler')
                                .where('firma', isEqualTo: currentFirmaName)
                                .where('ad', isEqualTo: urunAd)
                                .limit(1)
                                .get();

                            if (urunSnap.docs.isNotEmpty) {
                              final docRef = urunSnap.docs.first.reference;
                              await docRef.update({
                                'stok': FieldValue.increment(m),
                                'sonGelisFiyati': f,
                              });
                            } else {
                              // If product does not exist, create it!
                              await FirebaseFirestore.instance.collection('urunler').add({
                                'ad': urunAd,
                                'firma': currentFirmaName,
                                'stok': m,
                                'sonGelisFiyati': f,
                                'fiyat': f * 1.2, // Default markup
                                'minStok': 10.0,
                                'birim': itemBirim,
                                'kategori': categoryName,
                                'timestamp': FieldValue.serverTimestamp(),
                              });
                            }
                          }
                        } else if (_faturaTipi == 'satis') {
                          for (var item in _kalemler) {
                            final String urunAd = item['urun'] as String;
                            final double m = item['miktar'] as double;
                            final double f = item['fiyat'] as double;

                            // Log each sale to satislar collection so profit-loss and sales reports pick it up!
                            await FirebaseFirestore.instance.collection('satislar').add({
                              'uretici': _tedarikciCtrl.text,
                              'urun': urunAd,
                              'miktar': m,
                              'tutar': m * f,
                              'tarih': DateFormat('dd.MM.yyyy').format(_faturaTarihi!),
                              'firma': currentFirmaName,
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                            // Update urunler collection stock (decrement)
                            final urunSnap = await FirebaseFirestore.instance.collection('urunler')
                                .where('firma', isEqualTo: currentFirmaName)
                                .where('ad', isEqualTo: urunAd)
                                .limit(1)
                                .get();

                            if (urunSnap.docs.isNotEmpty) {
                              final uDoc = urunSnap.docs.first;
                              final double currentStock = (uDoc['stok'] as num?)?.toDouble() ?? 0.0;
                              final double minStok = (uDoc.data() as Map<String, dynamic>)['minStok']?.toDouble() ?? 10.0;
                              final String birim = (uDoc.data() as Map<String, dynamic>)['birim'] ?? 'Adet';
                              final double newStock = (currentStock - m).clamp(0.0, double.infinity);
                              
                              await uDoc.reference.update({
                                'stok': newStock,
                              });

                              // Check critical stock
                              if (newStock <= minStok) {
                                await FirestoreService().sendNotification(
                                  recipientName: currentFirmaName,
                                  role: 'firma',
                                  baslik: 'Kritik Stok Uyarısı',
                                  icerik: '$urunAd ürünü kritik stok limitinin altına düştü! Güncel Stok: ${newStock.toStringAsFixed(0)} $birim',
                                  type: 'stok',
                                );
                              }
                            }
                          }
                        }

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Fatura ${_faturaNoCtrl.text} başarıyla kaydedildi!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                          context.go('/firma/finans/faturalar');
                        }
                      },
                      child: const Text('Faturayı Kaydet'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _faturaNoCtrl.dispose();
    _tedarikciCtrl.dispose();
    _aciklamaCtrl.dispose();
    _faturaTarihiCtrl.dispose();
    _urunNameCtrl.dispose();
    _itemMiktarCtrl.dispose();
    _itemFiyatCtrl.dispose();
    _itemToplamFiyatCtrl.dispose();
    super.dispose();
  }
}

// --- GIDER YONETIMI SCREEN ---
class GiderYonetimiScreen extends StatefulWidget {
  const GiderYonetimiScreen({super.key});

  @override
  State<GiderYonetimiScreen> createState() => _GiderYonetimiScreenState();
}

class _GiderYonetimiScreenState extends State<GiderYonetimiScreen> {
  DateTime _selectedDate = DateTime.now();

  void _showAddExpenseDialog(String currentFirmaName) {
    final tutarCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController(text: 'Yakıt');
    final ekAciklamaCtrl = TextEditingController();
    String selectedKategori = 'arac';
    String selectedAracGideri = 'Yakıt';
    String selectedPersonelGideri = 'Maaş';
    String selectedGenelGideri = 'Elektrik';
    String selectedBakimGideri = 'Araç';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Yeni Gider Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedKategori,
                  decoration: const InputDecoration(labelText: 'Kategori'),
                  items: const [
                    DropdownMenuItem(value: 'arac', child: Text('Araç Giderleri')),
                    DropdownMenuItem(value: 'personel', child: Text('Personel Giderleri')),
                    DropdownMenuItem(value: 'genel', child: Text('Genel Giderler')),
                    DropdownMenuItem(value: 'bakim', child: Text('Bakım & Onarım')),
                    DropdownMenuItem(value: 'musteri', child: Text('Müşteri Giderleri')),
                    DropdownMenuItem(value: 'firma', child: Text('Firma Ödemeleri')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() {
                        selectedKategori = val;
                        if (val == 'arac') {
                          aciklamaCtrl.text = selectedAracGideri;
                        } else if (val == 'personel') {
                          aciklamaCtrl.text = selectedPersonelGideri;
                        } else if (val == 'genel') {
                          aciklamaCtrl.text = selectedGenelGideri;
                        } else if (val == 'bakim') {
                          aciklamaCtrl.text = selectedBakimGideri;
                        } else {
                          aciklamaCtrl.clear();
                        }
                      });
                    }
                  },
                ),
                const SizedBox(height: 12),
                selectedKategori == 'arac'
                    ? DropdownButtonFormField<String>(
                        value: selectedAracGideri,
                        decoration: const InputDecoration(labelText: 'Açıklama / Gider Türü'),
                        items: const [
                          DropdownMenuItem(value: 'Yakıt', child: Text('Yakıt')),
                          DropdownMenuItem(value: 'Bakım', child: Text('Bakım')),
                          DropdownMenuItem(value: 'Lastik', child: Text('Lastik')),
                          DropdownMenuItem(value: 'Sigorta', child: Text('Sigorta')),
                          DropdownMenuItem(value: 'Muayene', child: Text('Muayene')),
                          DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() {
                              selectedAracGideri = val;
                              aciklamaCtrl.text = val;
                            });
                          }
                        },
                      )
                    : selectedKategori == 'personel'
                        ? DropdownButtonFormField<String>(
                            value: selectedPersonelGideri,
                            decoration: const InputDecoration(labelText: 'Açıklama / Gider Türü'),
                            items: const [
                              DropdownMenuItem(value: 'Maaş', child: Text('Maaş')),
                              DropdownMenuItem(value: 'Prim', child: Text('Prim')),
                              DropdownMenuItem(value: 'Mesai', child: Text('Mesai')),
                              DropdownMenuItem(value: 'Avans', child: Text('Avans')),
                              DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() {
                                  selectedPersonelGideri = val;
                                  aciklamaCtrl.text = val;
                                });
                              }
                            },
                          )
                        : selectedKategori == 'genel'
                            ? DropdownButtonFormField<String>(
                                value: selectedGenelGideri,
                                decoration: const InputDecoration(labelText: 'Açıklama / Gider Türü'),
                                items: const [
                                  DropdownMenuItem(value: 'Elektrik', child: Text('Elektrik')),
                                  DropdownMenuItem(value: 'Su', child: Text('Su')),
                                  DropdownMenuItem(value: 'Kira', child: Text('Kira')),
                                  DropdownMenuItem(value: 'İnternet', child: Text('İnternet')),
                                  DropdownMenuItem(value: 'Telefon', child: Text('Telefon')),
                                  DropdownMenuItem(value: 'Ofis Malzemeleri', child: Text('Ofis Malzemeleri')),
                                  DropdownMenuItem(value: 'Temizlik', child: Text('Temizlik')),
                                  DropdownMenuItem(value: 'Güvenlik', child: Text('Güvenlik')),
                                  DropdownMenuItem(value: 'Sigorta', child: Text('Sigorta')),
                                  DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setDialogState(() {
                                      selectedGenelGideri = val;
                                      aciklamaCtrl.text = val;
                                    });
                                  }
                                },
                              )
                            : selectedKategori == 'bakim'
                                ? DropdownButtonFormField<String>(
                                    value: selectedBakimGideri,
                                    decoration: const InputDecoration(labelText: 'Açıklama / Gider Türü'),
                                    items: const [
                                      DropdownMenuItem(value: 'Araç', child: Text('Araç')),
                                      DropdownMenuItem(value: 'Tank', child: Text('Tank')),
                                      DropdownMenuItem(value: 'Pompa', child: Text('Pompa')),
                                      DropdownMenuItem(value: 'Soğutma', child: Text('Soğutma')),
                                      DropdownMenuItem(value: 'Tesisat', child: Text('Tesisat')),
                                      DropdownMenuItem(value: 'Bina', child: Text('Bina')),
                                      DropdownMenuItem(value: 'Diğer', child: Text('Diğer')),
                                    ],
                                    onChanged: (val) {
                                      if (val != null) {
                                        setDialogState(() {
                                          selectedBakimGideri = val;
                                          aciklamaCtrl.text = val;
                                        });
                                      }
                                    },
                                  )
                                : TextField(
                                    controller: aciklamaCtrl,
                                    decoration: const InputDecoration(labelText: 'Açıklama (Örn: Gider Detayı)'),
                                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: ekAciklamaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Ek Açıklama (Opsiyonel)',
                    hintText: 'Örn: Plaka, fiş no veya ek detaylar...',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: tutarCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Tutar (₺)', suffixText: 'TL'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final double? tutar = double.tryParse(tutarCtrl.text);
                final aciklama = aciklamaCtrl.text;
                if (tutar == null || tutar <= 0 || aciklama.isEmpty) return;

                await FirebaseFirestore.instance.collection('giderler').add({
                  'kategori': selectedKategori,
                  'aciklama': aciklama,
                  'ekAciklama': ekAciklamaCtrl.text,
                  'tutar': tutar,
                  'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                  'firma': currentFirmaName,
                  'timestamp': FieldValue.serverTimestamp(),
                  'durum': 'aktif',
                });

                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Gider başarıyla kaydedildi!'), backgroundColor: AppColors.success),
                );
              },
              child: const Text('Ekle'),
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
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);
    final formatNumber = NumberFormat('#,##0', 'tr_TR');

    return Scaffold(
      appBar: AppBar(
        title: Text('Gider Yönetimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddExpenseDialog(currentFirmaName),
        backgroundColor: AppColors.primary600,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Gider Ekle'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('giderler')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, snapshot) {
          double aracTotal = 0.0;
          double personelTotal = 0.0;
          double genelTotal = 0.0;
          double bakimTotal = 0.0;
          double musteriTotal = 0.0;
          double firmaTotal = 0.0;

          final docs = snapshot.data?.docs ?? [];
          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final t = (data['timestamp'] as Timestamp?)?.toDate();
            if (t != null && t.year == _selectedDate.year && t.month == _selectedDate.month) {
              final durum = data['durum'] as String? ?? 'aktif';
              if (durum == 'iptal') continue;

              final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
              final cat = data['kategori'] as String? ?? 'genel';
              
              if (cat == 'arac') aracTotal += tutar;
              else if (cat == 'personel') personelTotal += tutar;
              else if (cat == 'genel') genelTotal += tutar;
              else if (cat == 'bakim') bakimTotal += tutar;
              else if (cat == 'musteri') musteriTotal += tutar;
              else if (cat == 'firma') firmaTotal += tutar;
            }
          }

          final double toplamGider = aracTotal + personelTotal + genelTotal + bakimTotal + musteriTotal + firmaTotal;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Date Selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1)),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    monthStr,
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => setState(() => _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1)),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: AppColors.primary600),
                    onPressed: () => setState(() {}),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary
              AppCard(
                shadow: AppShadows.sm,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Toplam Gider', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: AppColors.gray700)),
                    Text('${formatNumber.format(toplamGider)} ₺', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // List of Categories
              Text(
                'Gider Kategorileri',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.gray800),
              ),
              Text(
                'Tüm işletme giderlerinizi kategorilere göre yönetin',
                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
              ),
              const SizedBox(height: 14),

              _buildGiderCategoryListItem('arac', 'Araç Giderleri', 'Araç yakıt, bakım ve onarım giderleri', aracTotal, Colors.red, Icons.local_shipping_rounded),
              _buildGiderCategoryListItem('personel', 'Personel Giderleri', 'Maaş, prim ve personel ödemeleri', personelTotal, Colors.green, Icons.people_rounded),
              _buildGiderCategoryListItem('genel', 'Genel Giderler', 'Elektrik, su, kira ve diğer giderler', genelTotal, Colors.orange, Icons.calculate_rounded),
              _buildGiderCategoryListItem('bakim', 'Bakım & Onarım', 'Ekipman ve tesis bakım giderleri', bakimTotal, Colors.purple, Icons.build_rounded),
              _buildGiderCategoryListItem('musteri', 'Müşteri Giderleri', 'Müşteri ağırlama ve temsil giderleri', musteriTotal, Colors.blue, Icons.monetization_on_rounded),
              _buildGiderCategoryListItem('firma', 'Firma Ödemeleri', 'Yem alışı ve diğer firma ödemeleri', firmaTotal, Colors.orange, Icons.business_rounded),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGiderCategoryListItem(String key, String title, String subtitle, double amount, Color color, IconData icon) {
    final formatNumber = NumberFormat('#,##0', 'tr_TR');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.go('/firma/finans/giderler/detay/$key'),
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.sm,
              border: Border.all(color: AppColors.gray200, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                      Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                    ],
                  ),
                ),
                Text('${formatNumber.format(amount)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded, color: AppColors.gray400),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- GIDER KATEGORI DETAY SCREEN ---
class GiderKategoriDetayScreen extends StatefulWidget {
  final String kategori;
  const GiderKategoriDetayScreen({super.key, required this.kategori});

  @override
  State<GiderKategoriDetayScreen> createState() => _GiderKategoriDetayScreenState();
}

class _GiderKategoriDetayScreenState extends State<GiderKategoriDetayScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'tumu'; // tumu, aktif, odendi, iptal

  void _changeMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
    });
  }

  String _getCategoryTitle(String cat) {
    switch (cat) {
      case 'arac': return 'Araç Giderleri';
      case 'personel': return 'Personel Giderleri';
      case 'genel': return 'Genel Giderler';
      case 'bakim': return 'Bakım & Onarım';
      case 'musteri': return 'Müşteri Giderleri';
      case 'firma': return 'Firma Ödemeleri';
      default: return 'Gider Detayı';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return Scaffold(
      appBar: AppBar(
        title: Text(_getCategoryTitle(widget.kategori), style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans/giderler'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('giderler')
            .where('firma', isEqualTo: currentFirmaName)
            .where('kategori', isEqualTo: widget.kategori)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          
          int totalCount = 0;
          int aktifCount = 0;
          int odendiCount = 0;
          int iptalCount = 0;

          final List<QueryDocumentSnapshot> monthDocs = [];

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final date = timestamp?.toDate() ?? DateTime.now();

            if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
              monthDocs.add(doc);
              final durum = data['durum'] as String? ?? 'aktif';
              if (durum == 'aktif') aktifCount++;
              else if (durum == 'odendi') odendiCount++;
              else if (durum == 'iptal') iptalCount++;
              totalCount++;
            }
          }

          // Filter by status tab
          final filteredDocs = monthDocs.where((doc) {
            if (_selectedStatus == 'tumu') return true;
            final data = doc.data() as Map<String, dynamic>;
            final durum = data['durum'] as String? ?? 'aktif';
            return durum == _selectedStatus;
          }).toList();

          double totalTutar = filteredDocs.fold(0.0, (sum, doc) {
            final data = doc.data() as Map<String, dynamic>;
            final tutarVal = data['tutar'] ?? 0.0;
            return sum + (tutarVal is num ? tutarVal.toDouble() : 0.0);
          });

          return Column(
            children: [
              // Date Selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: AppColors.primary600, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          monthStr,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
              ),

              // Status Tabs
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildStatusTab('tumu', 'Tümü', totalCount),
                      _buildStatusTab('aktif', 'Aktif', aktifCount),
                      _buildStatusTab('odendi', 'Ödenen', odendiCount),
                      _buildStatusTab('iptal', 'İptal', iptalCount),
                    ],
                  ),
                ),
              ),

              // Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  shadow: AppShadows.sm,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Toplam Tutar', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                      Text('${formatNumber.format(totalTutar)} ₺', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
                    ],
                  ),
                ),
              ),

              // List of expenses
              Expanded(
                child: filteredDocs.isEmpty
                    ? Center(
                        child: Text(
                          'Bu filtreye uygun gider bulunamadı.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final aciklama = data['aciklama'] as String? ?? '';
                          final ekAciklama = data['ekAciklama'] as String? ?? '';
                          final tarih = data['tarih'] as String? ?? '';
                          final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                          final durum = data['durum'] as String? ?? 'aktif';

                          Color statusColor;
                          String statusText;
                          if (durum == 'aktif') {
                            statusColor = Colors.blue;
                            statusText = 'Aktif';
                          } else if (durum == 'odendi') {
                            statusColor = Colors.green;
                            statusText = 'Ödendi';
                          } else {
                            statusColor = Colors.red;
                            statusText = 'İptal';
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppShadows.sm,
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: InkWell(
                              onTap: () => _showGiderIslemleriDialog(context, doc.id, aciklama, tutar, durum),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(aciklama, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                        if (ekAciklama.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(ekAciklama, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                                        ],
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Text(tarih, style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                                            const SizedBox(width: 8),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                statusText,
                                                style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '- ${formatNumber.format(tutar)} ₺',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.more_vert_rounded, color: AppColors.gray400),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusTab(String statusKey, String label, int count) {
    final isSelected = _selectedStatus == statusKey;
    return GestureDetector(
      onTap: () => setState(() => _selectedStatus = statusKey),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary600 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary600 : AppColors.gray300),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  void _showGiderIslemleriDialog(BuildContext context, String docId, String aciklama, double tutar, String currentDurum) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Gider İşlemleri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Text('"$aciklama" (${tutar.toStringAsFixed(2)} ₺) gideri üzerinde yapmak istediğiniz işlemi seçin:'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          if (currentDurum != 'odendi')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('giderler').doc(docId).update({'durum': 'odendi'});
                Navigator.pop(ctx);
              },
              child: const Text('Ödendi Yap'),
            ),
          if (currentDurum != 'iptal')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('giderler').doc(docId).update({'durum': 'iptal'});
                Navigator.pop(ctx);
              },
              child: const Text('İptal Et'),
            ),
          if (currentDurum != 'aktif')
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('giderler').doc(docId).update({'durum': 'aktif'});
                Navigator.pop(ctx);
              },
              child: const Text('Aktif Yap'),
            ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              await FirebaseFirestore.instance.collection('giderler').doc(docId).delete();
              Navigator.pop(ctx);
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}

// --- DEVIR YONETIMI SCREEN ---
class DevirYonetimiScreen extends StatefulWidget {
  const DevirYonetimiScreen({super.key});

  @override
  State<DevirYonetimiScreen> createState() => _DevirYonetimiScreenState();
}

class _DevirYonetimiScreenState extends State<DevirYonetimiScreen> {
  final _firestoreService = FirestoreService();
  String _searchQuery = '';
  String _filterStatus = 'Tümü'; // Tümü, Borçlular, Alacaklılar
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddDevirDialog(BuildContext context, String currentFirma, {String? defaultProducer}) {
    final formKey = GlobalKey<FormState>();
    final tutarCtrl = TextEditingController();
    final aciklamaCtrl = TextEditingController(text: 'Başlangıç Bakiyesi');
    String? selectedProducer = defaultProducer;

    showDialog(
      context: context,
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot>(
          stream: _firestoreService.getProducersStream(firma: currentFirma),
          builder: (context, prodSnapshot) {
            final producers = prodSnapshot.hasData
                ? prodSnapshot.data!.docs.map((doc) => doc['name'] as String).toList()
                : <String>[];

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  title: Text(defaultProducer != null ? '$defaultProducer - Düzeltme Ekle' : 'Düzeltme/Devir Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  content: Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (defaultProducer == null) ...[
                          DropdownButtonFormField<String>(
                            value: selectedProducer,
                            hint: const Text('Üretici Seçin *'),
                            decoration: const InputDecoration(labelText: 'Üretici *'),
                            items: producers.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedProducer = val;
                              });
                            },
                            validator: (val) => val == null ? 'Lütfen üretici seçin' : null,
                          ),
                          const SizedBox(height: 12),
                        ],
                        TextFormField(
                          controller: tutarCtrl,
                          keyboardType: TextInputType.text,
                          decoration: const InputDecoration(
                            labelText: 'Düzeltme Tutarı (₺) *',
                            hintText: 'Pozitif veya Negatif değer (Örn: -1500 veya 2000)',
                            helperText: 'Pozitif: Alacağı artırır, Negatif: Borcu artırır',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Lütfen tutar girin';
                            if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Geçerli bir sayı girin';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: aciklamaCtrl,
                          decoration: const InputDecoration(labelText: 'Açıklama/Gerekçe *'),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Lütfen açıklama girin';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600, foregroundColor: Colors.white),
                      onPressed: () async {
                        if (formKey.currentState!.validate() && selectedProducer != null) {
                          final double tutar = double.parse(tutarCtrl.text.replaceAll(',', '.'));
                          
                          await FirebaseFirestore.instance.collection('devirler').add({
                            'uretici': selectedProducer,
                            'tutar': tutar,
                            'aciklama': aciklamaCtrl.text,
                            'tarih': DateFormat('dd.MM.yyyy').format(DateTime.now()),
                            'firma': currentFirma,
                            'timestamp': FieldValue.serverTimestamp(),
                          });

                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$selectedProducer için ${tutar.toStringAsFixed(2)} ₺ düzeltme kaydedildi!'), backgroundColor: AppColors.success),
                          );
                        }
                      },
                      child: const Text('Kaydet'),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return Scaffold(
      appBar: AppBar(
        title: Text('Devir & Bakiye Düzeltme', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.primary600),
            onPressed: () => _showAddDevirDialog(context, currentFirmaName),
          ),
        ],
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getProducersStream(firma: currentFirmaName),
        builder: (context, prodSnapshot) {
          if (prodSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allProducers = prodSnapshot.hasData
              ? prodSnapshot.data!.docs.map((doc) => doc.data() as Map<String, dynamic>).toList()
              : [];

          if (allProducers.isEmpty) {
            return Center(child: Text('Kayıtlı üretici bulunamadı.', style: GoogleFonts.inter(color: AppColors.gray500)));
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getMilkPricesStream(firma: currentFirmaName),
            builder: (context, pricesSnap) {
              final priceDocs = pricesSnap.data?.docs ?? [];

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('toplamalar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                builder: (context, collectionsSnap) {
                  final allCollections = collectionsSnap.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('tahsilatlar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                    builder: (context, tahsilatlarSnap) {
                      final allTahsilatlar = tahsilatlarSnap.data?.docs ?? [];

                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('avanslar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                        builder: (context, avanslarSnap) {
                          final allAvanslar = avanslarSnap.data?.docs ?? [];

                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('kesintiler').where('firma', isEqualTo: currentFirmaName).snapshots(),
                            builder: (context, kesintilerSnap) {
                              final allKesintiler = kesintilerSnap.data?.docs ?? [];

                              return StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance.collection('cezalar').where('firma', isEqualTo: currentFirmaName).snapshots(),
                                builder: (context, cezalarSnap) {
                                  final allCezalar = cezalarSnap.data?.docs ?? [];

                                  return StreamBuilder<QuerySnapshot>(
                                    stream: FirebaseFirestore.instance.collection('devirler').where('firma', isEqualTo: currentFirmaName).snapshots(),
                                    builder: (context, devirlerSnap) {
                                      final allDevirler = devirlerSnap.data?.docs ?? [];

                                      // Compile balance sheet
                                      double totalCompanyDebt = 0.0;
                                      double totalCompanyReceivable = 0.0;

                                      final List<Map<String, dynamic>> compiledData = [];

                                      for (var p in allProducers) {
                                        final name = p['name'] as String;
                                        final bolge = p['bolge'] ?? '';
                                        final group = p['group'] ?? '';
                                        final email = p['email'] ?? '';
                                        final kesintiAyarlari = p['kesintiAyarlari'] as Map<String, dynamic>?;

                                        final pCollections = allCollections.where((doc) => doc['u'] == name).toList();
                                        final pTahsilatlar = allTahsilatlar.where((doc) => doc['uretici'] == name).toList();
                                        final pAvanslar = allAvanslar.where((doc) => doc['uretici'] == name).toList();
                                        final pKesintiler = allKesintiler.where((doc) => doc['uretici'] == name).toList();
                                        final pCezalar = allCezalar.where((doc) => doc['uretici'] == name).toList();
                                        final pDevirler = allDevirler.where((doc) => doc['uretici'] == name).toList();

                                        final ledger = _firestoreService.calculateLedger(
                                          collections: pCollections,
                                          prices: priceDocs,
                                          tahsilatlar: pTahsilatlar,
                                          avanslar: pAvanslar,
                                          kesintiler: pKesintiler,
                                          cezalar: pCezalar,
                                          devirler: pDevirler,
                                          producerName: name,
                                          bolge: bolge,
                                          group: group,
                                          kesintiAyarlari: kesintiAyarlari,
                                        );

                                        final double net = ledger['netBalance'];

                                        if (net > 0) {
                                          totalCompanyDebt += net;
                                        } else if (net < 0) {
                                          totalCompanyReceivable += net.abs();
                                        }

                                        compiledData.add({
                                          'name': name,
                                          'email': email,
                                          'net': net,
                                          'producer': p,
                                        });
                                      }

                                      // Filter search query
                                      var filteredData = compiledData;
                                      if (_searchQuery.isNotEmpty) {
                                        filteredData = filteredData.where((d) => (d['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                                      }

                                      // Filter by debt/receivable status
                                      if (_filterStatus == 'Borçlular') {
                                        filteredData = filteredData.where((d) => (d['net'] as double) < 0).toList();
                                      } else if (_filterStatus == 'Alacaklılar') {
                                        filteredData = filteredData.where((d) => (d['net'] as double) > 0).toList();
                                      }

                                      return Column(
                                        children: [
                                          // Top stats card matching Devir İşlemleri mockup
                                          Padding(
                                            padding: const EdgeInsets.all(16.0),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: AppCard(
                                                    padding: const EdgeInsets.all(12),
                                                    shadow: AppShadows.sm,
                                                    child: Column(
                                                      children: [
                                                        const Icon(Icons.arrow_downward_rounded, color: Colors.green, size: 20),
                                                        const SizedBox(height: 6),
                                                        Text('Toplam Alacak', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400, fontWeight: FontWeight.w600)),
                                                        const SizedBox(height: 4),
                                                        Text('${formatNumber.format(totalCompanyReceivable)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.green)),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: AppCard(
                                                    padding: const EdgeInsets.all(12),
                                                    shadow: AppShadows.sm,
                                                    child: Column(
                                                      children: [
                                                        const Icon(Icons.arrow_upward_rounded, color: Colors.red, size: 20),
                                                        const SizedBox(height: 6),
                                                        Text('Toplam Borç', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400, fontWeight: FontWeight.w600)),
                                                        const SizedBox(height: 4),
                                                        Text('${formatNumber.format(totalCompanyDebt)} ₺', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Search field
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                                            child: TextField(
                                              controller: _searchCtrl,
                                              decoration: InputDecoration(
                                                hintText: 'Üretici ara...',
                                                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400),
                                                suffixIcon: _searchQuery.isNotEmpty
                                                    ? IconButton(
                                                        icon: const Icon(Icons.clear_rounded),
                                                        onPressed: () {
                                                          setState(() {
                                                            _searchQuery = '';
                                                            _searchCtrl.clear();
                                                          });
                                                        },
                                                      )
                                                    : null,
                                                filled: true,
                                                fillColor: Colors.white,
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(12),
                                                  borderSide: BorderSide(color: AppColors.gray200, width: 1),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                                              ),
                                              onChanged: (val) {
                                                setState(() {
                                                  _searchQuery = val.trim();
                                                });
                                              },
                                            ),
                                          ),

                                          // Filter chips
                                          SingleChildScrollView(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                            child: Row(
                                              children: ['Tümü', 'Borçlular', 'Alacaklılar'].map((filter) {
                                                final isSelected = _filterStatus == filter;
                                                return Padding(
                                                  padding: const EdgeInsets.only(right: 8.0),
                                                  child: ChoiceChip(
                                                    label: Text(filter),
                                                    selected: isSelected,
                                                    onSelected: (selected) {
                                                      setState(() {
                                                        _filterStatus = filter;
                                                      });
                                                    },
                                                    selectedColor: AppColors.primary600,
                                                    labelStyle: GoogleFonts.inter(
                                                      fontSize: 12,
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                      color: isSelected ? Colors.white : AppColors.gray700,
                                                    ),
                                                    backgroundColor: Colors.white,
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(20),
                                                      side: BorderSide(color: isSelected ? AppColors.primary600 : AppColors.gray200),
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),

                                          const Divider(height: 1),

                                          // Customer list
                                          Expanded(
                                            child: filteredData.isEmpty
                                                ? Center(child: Text('Kayıt bulunamadı.', style: GoogleFonts.inter(color: AppColors.gray400)))
                                                : ListView.builder(
                                                    padding: const EdgeInsets.all(16),
                                                    itemCount: filteredData.length,
                                                    itemBuilder: (context, idx) {
                                                      final item = filteredData[idx];
                                                      final name = item['name'] as String;
                                                      final email = item['email'] as String;
                                                      final double net = item['net'] as double;

                                                      // net < 0: Producer owes company (Borçlu - Red)
                                                      // net > 0: Company owes producer (Alacaklı - Green)
                                                      final bool isDebtor = net < 0;
                                                      final Color balanceColor = isDebtor ? Colors.red : (net > 0 ? Colors.green : AppColors.gray500);
                                                      final String balanceLabel = isDebtor ? 'Borçlu' : (net > 0 ? 'Alacaklı' : 'Bakiye Sıfır');

                                                      return Container(
                                                        margin: const EdgeInsets.only(bottom: 12),
                                                        padding: const EdgeInsets.all(14),
                                                        decoration: BoxDecoration(
                                                          color: Colors.white,
                                                          borderRadius: BorderRadius.circular(14),
                                                          boxShadow: AppShadows.sm,
                                                          border: Border.all(color: AppColors.gray200),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Container(
                                                              width: 44,
                                                              height: 44,
                                                              decoration: BoxDecoration(
                                                                color: balanceColor.withOpacity(0.1),
                                                                shape: BoxShape.circle,
                                                              ),
                                                              child: Icon(Icons.person_outline_rounded, color: balanceColor, size: 22),
                                                            ),
                                                            const SizedBox(width: 14),
                                                            Expanded(
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                                                  if (email.isNotEmpty) Text(email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                                                                  const SizedBox(height: 4),
                                                                  Container(
                                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                                    decoration: BoxDecoration(
                                                                      color: balanceColor.withOpacity(0.1),
                                                                      borderRadius: BorderRadius.circular(4),
                                                                    ),
                                                                    child: Text(
                                                                      balanceLabel,
                                                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: balanceColor),
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Column(
                                                              crossAxisAlignment: CrossAxisAlignment.end,
                                                              children: [
                                                                Text(
                                                                  '${formatNumber.format(net.abs())} ₺',
                                                                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: balanceColor),
                                                                ),
                                                                const SizedBox(height: 6),
                                                                ElevatedButton(
                                                                  onPressed: () => _showAddDevirDialog(context, currentFirmaName, defaultProducer: name),
                                                                  style: ElevatedButton.styleFrom(
                                                                    backgroundColor: AppColors.primary50,
                                                                    foregroundColor: AppColors.primary600,
                                                                    elevation: 0,
                                                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                                    minimumSize: const Size(60, 28),
                                                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                  ),
                                                                  child: Text('Düzeltme', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
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
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// --- ODEME GECMISI SCREEN ---
class OdemeGecmisiScreen extends StatefulWidget {
  const OdemeGecmisiScreen({super.key});

  @override
  State<OdemeGecmisiScreen> createState() => _OdemeGecmisiScreenState();
}

class _OdemeGecmisiScreenState extends State<OdemeGecmisiScreen> {
  DateTime _selectedDate = DateTime.now();

  void _changeMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
    });
  }

  void _showEditOdemeDialog(BuildContext context, String docId, String uretici, double tutar, String yontem, String aciklama) {
    final formKey = GlobalKey<FormState>();
    final tutarCtrl = TextEditingController(text: tutar.toStringAsFixed(2));
    final aciklamaCtrl = TextEditingController(text: aciklama);
    String selectedYontem = yontem;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Ödemeyi Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Üretici: $uretici', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: tutarCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Tutar (₺) *'),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'Lütfen tutar girin';
                        if (double.tryParse(value.replaceAll(',', '.')) == null) return 'Geçerli bir sayı girin';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedYontem,
                      decoration: const InputDecoration(labelText: 'Ödeme Yöntemi'),
                      items: const [
                        DropdownMenuItem(value: 'Nakit', child: Text('Nakit')),
                        DropdownMenuItem(value: 'Banka', child: Text('Banka Havalesi')),
                        DropdownMenuItem(value: 'Çek', child: Text('Çek')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() {
                            selectedYontem = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: aciklamaCtrl,
                      decoration: const InputDecoration(labelText: 'Açıklama'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Ödeme Kaydını Sil'),
                        content: const Text('Bu ödeme kaydını tamamen silmek istediğinize emin misiniz?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Sil'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await FirebaseFirestore.instance.collection('tahsilatlar').doc(docId).delete();
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ödeme kaydı silindi!'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  child: const Text('Sil', style: TextStyle(color: Colors.red)),
                ),
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final double newTutar = double.parse(tutarCtrl.text.replaceAll(',', '.'));
                      await FirebaseFirestore.instance.collection('tahsilatlar').doc(docId).update({
                        'tutar': newTutar,
                        'odemeYontemi': selectedYontem,
                        'aciklama': aciklamaCtrl.text,
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ödeme kaydı güncellendi!'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  child: const Text('Kaydet'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return Scaffold(
      appBar: AppBar(
        title: Text('Ödeme Geçmişi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('tahsilatlar')
            .where('firma', isEqualTo: currentFirmaName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];
          final List<QueryDocumentSnapshot> monthDocs = [];

          double totalPayments = 0.0;
          int paymentsCount = 0;

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final timestamp = data['timestamp'] as Timestamp?;
            final date = timestamp?.toDate() ?? DateTime.now();

            if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
              monthDocs.add(doc);
              final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
              totalPayments += tutar;
              paymentsCount++;
            }
          }

          // Sort by timestamp descending
          monthDocs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          return Column(
            children: [
              // Month Selector
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left_rounded),
                      onPressed: () => _changeMonth(-1),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.calendar_month_rounded, color: AppColors.primary600, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          monthStr,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right_rounded),
                      onPressed: () => _changeMonth(1),
                    ),
                  ],
                ),
              ),

              // Summary Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: AppCard(
                  padding: const EdgeInsets.all(16),
                  shadow: AppShadows.sm,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Toplam Ödeme', style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text('$paymentsCount adet işlem', style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                        ],
                      ),
                      Text('${formatNumber.format(totalPayments)} ₺', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ),
              ),

              // Payments List
              Expanded(
                child: monthDocs.isEmpty
                    ? Center(
                        child: Text(
                          'Bu ay ödeme kaydı bulunmuyor.',
                          style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray500),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: monthDocs.length,
                        itemBuilder: (context, index) {
                          final doc = monthDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final uretici = data['uretici'] ?? 'Bilinmeyen';
                          final double tutar = (data['tutar'] as num?)?.toDouble() ?? 0.0;
                          final odemeYontemi = data['odemeYontemi'] ?? 'Nakit';
                          final aciklama = data['aciklama'] ?? '';
                          final tarih = data['tarih'] ?? '';
                          final saat = data['saat'] ?? '';
                          final code = doc.id.substring(0, min(6, doc.id.length)).toUpperCase();

                          IconData methodIcon = Icons.money_rounded;
                          Color methodColor = Colors.green;
                          if (odemeYontemi == 'Banka') {
                            methodIcon = Icons.account_balance_rounded;
                            methodColor = Colors.blue;
                          } else if (odemeYontemi == 'Çek') {
                            methodIcon = Icons.receipt_rounded;
                            methodColor = Colors.orange;
                          }

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppShadows.sm,
                              border: Border.all(color: AppColors.gray200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: methodColor.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(methodIcon, color: methodColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(uretici, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800)),
                                      Text(
                                        '$tarih $saat • Kod: #$code',
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400),
                                      ),
                                      if (aciklama.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(aciklama, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '${formatNumber.format(tutar)} ₺',
                                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green),
                                    ),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () => _showEditOdemeDialog(context, doc.id, uretici, tutar, odemeYontemi, aciklama),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppColors.gray50,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.gray200),
                                        ),
                                        child: Text(
                                          'Düzenle',
                                          style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.gray600),
                                        ),
                                      ),
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
      ),
    );
  }
}

class KesintiOranlariScreen extends StatefulWidget {
  const KesintiOranlariScreen({super.key});

  @override
  State<KesintiOranlariScreen> createState() => _KesintiOranlariScreenState();
}

class _KesintiOranlariScreenState extends State<KesintiOranlariScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();
  final _bagkurCtrl = TextEditingController();
  final _stopajCtrl = TextEditingController();
  final _borsaCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _bagkurCtrl.dispose();
    _stopajCtrl.dispose();
    _borsaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Kesinti Oranları Yönetimi', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/finans'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<DocumentSnapshot>(
        stream: _db.collection('finans_ayarlari').doc(currentFirmaName).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          double bagkur = 2.10;
          double stopaj = 1.00;
          double borsa = 0.20;

          if (snapshot.hasData && snapshot.data!.exists) {
            final sData = snapshot.data!.data() as Map<String, dynamic>;
            bagkur = (sData['bagkurOran'] as num?)?.toDouble() ?? 2.10;
            stopaj = (sData['stopajOran'] as num?)?.toDouble() ?? 1.00;
            borsa = (sData['borsaOran'] as num?)?.toDouble() ?? 0.20;
          }

          // Initialize controllers if they are empty
          if (_bagkurCtrl.text.isEmpty && !_loading) {
            _bagkurCtrl.text = bagkur.toStringAsFixed(2);
            _stopajCtrl.text = stopaj.toStringAsFixed(2);
            _borsaCtrl.text = borsa.toStringAsFixed(2);
          }

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'Yasal Kesinti Yüzdeleri',
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gray800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Üretici süt hak edişlerinden (süt geliri üzerinden) kesilecek yasal oranları ayarlayın. Boş bırakırsanız veya hatalı değer girilirse varsayılan yasal oranlar geçerli olur.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                ),
                const SizedBox(height: 24),
                
                TextFormField(
                  controller: _bagkurCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Bağkur Kesinti Oranı (%)',
                    suffixText: '%',
                    hintText: 'Örn: 2.10',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Oran giriniz';
                    if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Geçerli bir sayı giriniz';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _stopajCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Stopaj Kesinti Oranı (%)',
                    suffixText: '%',
                    hintText: 'Örn: 1.00',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Oran giriniz';
                    if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Geçerli bir sayı giriniz';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _borsaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Borsa Kesinti Oranı (%)',
                    suffixText: '%',
                    hintText: 'Örn: 0.20',
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Oran giriniz';
                    if (double.tryParse(val.replaceAll(',', '.')) == null) return 'Geçerli bir sayı giriniz';
                    return null;
                  },
                ),
                const SizedBox(height: 32),
                
                ElevatedButton(
                  onPressed: _loading ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      setState(() => _loading = true);
                      final bk = double.parse(_bagkurCtrl.text.replaceAll(',', '.'));
                      final st = double.parse(_stopajCtrl.text.replaceAll(',', '.'));
                      final bs = double.parse(_borsaCtrl.text.replaceAll(',', '.'));

                      await _db.collection('finans_ayarlari').doc(currentFirmaName).set({
                        'bagkurOran': bk,
                        'stopajOran': st,
                        'borsaOran': bs,
                        'timestamp': FieldValue.serverTimestamp(),
                      });

                      setState(() => _loading = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kesinti oranları başarıyla kaydedildi!'), backgroundColor: AppColors.success),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary600,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _loading 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Oranları Kaydet'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
