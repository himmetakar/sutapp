import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../providers/auth_provider.dart';
import '../../utils/file_download_helper.dart';
import '../../widgets/milk_loading_indicator.dart';

class UreticiFaturalarScreen extends StatefulWidget {
  const UreticiFaturalarScreen({super.key});

  @override
  State<UreticiFaturalarScreen> createState() => _UreticiFaturalarScreenState();
}

class _UreticiFaturalarScreenState extends State<UreticiFaturalarScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedStatus = 'tumu'; // tumu, aktif, odendi, iptal

  void _changeMonth(int delta) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + delta);
    });
  }

  String _generateInvoiceText(Map<String, dynamic> data) {
    final faturaNo = data['faturaNo'] ?? '';
    final firma = data['firma'] ?? '';
    final tedarikci = data['tedarikci'] ?? '';
    final tarih = data['tarih'] ?? '';
    final aciklama = data['aciklama'] ?? '-';
    final double toplam = (data['toplam'] as num?)?.toDouble() ?? 0.0;
    final kalemler = data['kalemler'] as List? ?? [];

    final sb = StringBuffer();
    sb.writeln("========================================");
    sb.writeln("             SUTAPP FATURA              ");
    sb.writeln("========================================");
    sb.writeln("Fatura No  : $faturaNo");
    sb.writeln("Firma      : $firma");
    sb.writeln("Musteri    : $tedarikci");
    sb.writeln("Tarih      : $tarih");
    sb.writeln("Aciklama   : $aciklama");
    sb.writeln("----------------------------------------");
    sb.writeln("KALEMLER:");
    for (var item in kalemler) {
      final urun = item['urun'] ?? '';
      final double miktar = (item['miktar'] as num?)?.toDouble() ?? 0.0;
      final birim = item['birim'] ?? '';
      final double fiyat = (item['fiyat'] as num?)?.toDouble() ?? 0.0;
      final double subtotal = miktar * fiyat;
      sb.writeln("- $urun (${miktar.toStringAsFixed(0)} $birim) x ${fiyat.toStringAsFixed(2)} TL = ${subtotal.toStringAsFixed(2)} TL");
    }
    sb.writeln("----------------------------------------");
    sb.writeln("Toplam Tutar: ${toplam.toStringAsFixed(2)} TL");
    sb.writeln("========================================");
    sb.writeln("SutApp Finansal Yonetim Sistemi");
    return sb.toString();
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final producerName = auth.user?.displayName ?? 'Mehmet Yılmaz';
    final formatNumber = NumberFormat('#,##0.00', 'tr_TR');

    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth >= 1024;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                'Faturalarım ve Bildirimler',
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.gray900),
              ),
              const SizedBox(height: 4),
              Text(
                'Size kesilen faturaları indirebilir ve bildirimlerinizi inceleyebilirsiniz.',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
              ),
              const SizedBox(height: 24),

              if (isDesktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: _buildFaturalarSection(context, producerName, formatNumber)),
                    const SizedBox(width: 24),
                    Expanded(flex: 4, child: _buildBildirimlerSection(context, producerName)),
                  ],
                )
              else ...[
                _buildBildirimlerSection(context, producerName),
                const SizedBox(height: 24),
                _buildFaturalarSection(context, producerName, formatNumber),
              ],
              const SizedBox(height: 60),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary600 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppColors.primary600 : AppColors.gray300),
        ),
        child: Text(
          '$label ($count)',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.gray700,
          ),
        ),
      ),
    );
  }

  Widget _buildFaturalarSection(BuildContext context, String producerName, NumberFormat formatNumber) {
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedDate);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Faturalar Listesi',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
            ),
          ),
          const SizedBox(height: 8),

          // Dönem Seçici (Month Selector)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed: () => _changeMonth(-1),
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.primary600, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    monthStr,
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: () => _changeMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('faturalar')
                .where('tedarikci', isEqualTo: producerName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: MilkLoadingIndicator(size: 70));
              }

              final docs = snapshot.data?.docs ?? [];
              
              int totalCount = 0;
              int aktifCount = 0;
              int odendiCount = 0;
              int iptalCount = 0;

              final List<QueryDocumentSnapshot> monthDocs = [];

              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                DateTime date;
                final timestamp = data['timestamp'] as Timestamp?;
                if (timestamp != null) {
                  date = timestamp.toDate();
                } else {
                  final tarihStr = data['tarih'] as String? ?? '';
                  try {
                    date = DateFormat('dd.MM.yyyy').parse(tarihStr);
                  } catch (_) {
                    date = DateTime.now();
                  }
                }

                if (date.year == _selectedDate.year && date.month == _selectedDate.month) {
                  final durum = data['durum'] as String? ?? 'aktif';
                  if (durum == 'aktif') aktifCount++;
                  else if (durum == 'odendi') odendiCount++;
                  else if (durum == 'iptal') iptalCount++;
                  totalCount++;

                  monthDocs.add(doc);
                }
              }

              // Filter by status tab
              final filteredDocs = monthDocs.where((doc) {
                if (_selectedStatus == 'tumu') return true;
                final data = doc.data() as Map<String, dynamic>;
                final durum = data['durum'] as String? ?? 'aktif';
                return durum == _selectedStatus;
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Durum Sekmeleri
                  SingleChildScrollView(
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
                  const SizedBox(height: 16),

                  if (filteredDocs.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.description_outlined, size: 48, color: AppColors.gray300),
                            const SizedBox(height: 12),
                            Text(
                              'Bu döneme ve duruma ait fatura bulunamadı.',
                              style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredDocs.length,
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final faturaNo = data['faturaNo'] ?? '';
                        final firma = data['firma'] ?? '';
                        final tarih = data['tarih'] ?? '';
                        final double toplam = (data['toplam'] as num?)?.toDouble() ?? 0.0;
                        final kalemList = data['kalemler'] as List? ?? [];
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
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.gray50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.gray200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: AppColors.primary50,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.receipt_long_rounded, color: AppColors.primary600, size: 18),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      faturaNo,
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                    ),
                                    Text(
                                      '$firma • $tarih',
                                      style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray600),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          '${kalemList.length} Kalem',
                                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400),
                                        ),
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
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${formatNumber.format(toplam)} ₺',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary600),
                                  ),
                                  const SizedBox(height: 4),
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      minimumSize: const Size(60, 24),
                                      textStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      elevation: 0,
                                    ),
                                    onPressed: () async {
                                      final txtContent = _generateInvoiceText(data);
                                      await FileDownloadHelper.downloadTextFile(
                                        fileName: '$faturaNo.txt',
                                        content: txtContent,
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('$faturaNo nolu fatura dosyası paylaşıldı/kaydedildi!'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.download_rounded, size: 10),
                                    label: const Text('İndir'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBildirimlerSection(BuildContext context, String producerName) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Fatura Bildirimleri',
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                ),
                const Icon(Icons.notifications_active_rounded, color: Colors.orange, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('bildirimler')
                .where('aliciName', isEqualTo: producerName)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: MilkLoadingIndicator(size: 60));
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.notifications_none_rounded, size: 48, color: AppColors.gray300),
                        const SizedBox(height: 12),
                        Text(
                          'Yeni bildirim bulunmuyor.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Sort in memory to show newest first
              final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
              sortedDocs.sort((a, b) {
                final aTime = (a.data() as Map)['timestamp'] as Timestamp?;
                final bTime = (b.data() as Map)['timestamp'] as Timestamp?;
                if (aTime == null) return -1;
                if (bTime == null) return 1;
                return bTime.compareTo(aTime);
              });

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedDocs.length,
                itemBuilder: (context, index) {
                  final data = sortedDocs[index].data() as Map<String, dynamic>;
                  final baslik = data['baslik'] ?? 'Bildirim';
                  final icerik = data['icerik'] ?? '';
                  final tarih = data['tarih'] ?? '';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              baslik,
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gray800),
                            ),
                            Text(
                              tarih,
                              style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          icerik,
                          style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray600),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
