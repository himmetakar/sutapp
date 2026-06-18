import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../services/firestore_service.dart';

class FirmaTanklar extends StatefulWidget {
  const FirmaTanklar({super.key});

  @override
  State<FirmaTanklar> createState() => _FirmaTanklarState();
}

class _FirmaTanklarState extends State<FirmaTanklar> {
  bool _isRefreshing = false;
  bool _isResetting = false;

  /// Tüm tankları silip her sürücüye yeni tank ata
  Future<void> _resetAndAssignTanks(String firma) async {
    // Onay dialogu
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sıfırla & Yeniden Ata', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text(
          'Tüm mevcut tanklar silinecek ve her sürücüye araçlarına bağlı yeni birer tank atanacak.\n\nBu işlem geri alınamaz. Devam etmek istiyor musunuz?',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Evet, Sıfırla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isResetting = true);
    final result = await FirestoreService().resetAndAssignAllTanks(firma);
    if (!mounted) return;
    setState(() => _isResetting = false);

    // Sonuç log dialogu
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('İşlem Tamamlandı', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        content: SingleChildScrollView(
          child: Text(result, style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.gray700)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  /// Sadece süt kayıtlarını ve tank stoklarını sıfırla (araçlar/tanklar korunur)
  Future<void> _resetMilkOnly(String firma) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Süt Kayıtlarını Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        content: Text(
          'Tüm süt toplama kayıtları silinecek ve tank stokları 0\'a sıfırlanacak.\n\nAraçlar, tanklar ve müşteriler korunur.\n\nBu işlem geri alınamaz!',
          style: GoogleFonts.inter(fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Evet, Sıfırla'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isResetting = true);
    final result = await FirestoreService().resetMilkCollectionsAndStocks(firma);
    if (!mounted) return;
    setState(() => _isResetting = false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('İşlem Tamamlandı', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 15)),
        content: SingleChildScrollView(
          child: Text(result, style: GoogleFonts.robotoMono(fontSize: 11, color: AppColors.gray700)),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  void _showTankIcerik(BuildContext context, String tankAdi, String tip) {
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
                    tip == 'merkez' ? '$tankAdi Geçmişi' : '$tankAdi Giriş Kayıtları',
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
                      tip == 'merkez'
                          ? 'Bu tanka ait giriş, çıkış ve transfer kayıtları listelenmektedir.'
                          : 'Bu tanka son giren süt toplama kayıtları listelenmektedir.',
                      style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF1D4ED8), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<TankHistoryEntry>>(
                future: _fetchTankHistory(tankAdi, tip),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        'Kayıt bulunamadı.',
                        style: GoogleFonts.inter(color: AppColors.gray400),
                      ),
                    );
                  }

                  final displayDocs = list.take(15).toList();

                  return ListView.builder(
                    controller: sc,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displayDocs.length,
                    itemBuilder: (_, i) {
                      final item = displayDocs[i];
                      final t = DateFormat('dd.MM.yyyy').format(item.date);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.gray200),
                        ),
                        child: ListTile(
                          title: Text(
                            item.title,
                            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gray800),
                          ),
                          subtitle: Text(
                            '${t != '01.01.1970' ? '$t\n' : ''}${item.subtitle}',
                            style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                          ),
                          trailing: Text(
                            '${item.isIncoming ? '+' : '-'} ${item.miktar.toStringAsFixed(1)} LT',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              color: item.isIncoming ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              fontSize: 14,
                            ),
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

  Future<List<TankHistoryEntry>> _fetchTankHistory(String tankAdi, String tip) async {
    final db = FirebaseFirestore.instance;

    if (tip == 'arac') {
      // Find the timestamp of the last time this tank was emptied (boşaltıldı)
      // That is: the most recent teslimatlar entry where kaynakTank == tankAdi
      DateTime? lastEmptyTime;
      try {
        final emptySnap = await db
            .collection('teslimatlar')
            .where('kaynakTank', isEqualTo: tankAdi)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
        if (emptySnap.docs.isNotEmpty) {
          final ts = emptySnap.docs.first.data()['timestamp'];
          if (ts is Timestamp) {
            lastEmptyTime = ts.toDate();
          }
        }
      } catch (_) {}

      // Fetch toplamalar for this tank, only AFTER the last emptying
      Query query = db.collection('toplamalar').where('tank', isEqualTo: tankAdi);
      if (lastEmptyTime != null) {
        query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(lastEmptyTime));
      }
      final snap = await query.get();

      final List<TankHistoryEntry> list = [];
      for (var doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final u = data['u'] ?? 'Bilinmeyen Üretici';
        final double m = (data['m'] as num?)?.toDouble() ?? 0.0;
        final s = data['s'] ?? '';
        final ts = data['timestamp'];
        DateTime date = DateTime(1970);
        if (ts is Timestamp) {
          date = ts.toDate();
        } else if (data['tarih'] is String) {
          date = _parseDateStr(data['tarih']);
        }

        list.add(TankHistoryEntry(
          title: u,
          subtitle: s,
          miktar: m,
          date: date,
          isIncoming: true,
        ));
      }
      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    } else {
      // Merkez tankı: find last outgoing event timestamp
      DateTime? lastEmptyTime;
      try {
        // Check last outgoing transfer (kaynakTank) or satış
        final transferSnap = await db
            .collection('teslimatlar')
            .where('kaynakTank', isEqualTo: tankAdi)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();
        final satisSnap = await db
            .collection('sut_satislari')
            .where('kaynakTank', isEqualTo: tankAdi)
            .orderBy('timestamp', descending: true)
            .limit(1)
            .get();

        DateTime? t1, t2;
        if (transferSnap.docs.isNotEmpty) {
          final ts = transferSnap.docs.first.data()['timestamp'];
          if (ts is Timestamp) t1 = ts.toDate();
        }
        if (satisSnap.docs.isNotEmpty) {
          final ts = satisSnap.docs.first.data()['timestamp'];
          if (ts is Timestamp) t2 = ts.toDate();
        }

        if (t1 != null && t2 != null) {
          lastEmptyTime = t1.isAfter(t2) ? t1 : t2;
        } else {
          lastEmptyTime = t1 ?? t2;
        }
      } catch (_) {}

      // Incoming transfers after last empty
      Query inQuery = db.collection('teslimatlar').where('hedefTank', isEqualTo: tankAdi);
      if (lastEmptyTime != null) {
        inQuery = inQuery.where('timestamp', isGreaterThan: Timestamp.fromDate(lastEmptyTime));
      }

      // Outgoing transfers after last empty
      Query outTransferQuery = db.collection('teslimatlar').where('kaynakTank', isEqualTo: tankAdi);
      if (lastEmptyTime != null) {
        outTransferQuery = outTransferQuery.where('timestamp', isGreaterThan: Timestamp.fromDate(lastEmptyTime));
      }

      // Outgoing sales after last empty
      Query satisQuery = db.collection('sut_satislari').where('kaynakTank', isEqualTo: tankAdi);
      if (lastEmptyTime != null) {
        satisQuery = satisQuery.where('timestamp', isGreaterThan: Timestamp.fromDate(lastEmptyTime));
      }

      final futures = await Future.wait([
        inQuery.get(),
        outTransferQuery.get(),
        satisQuery.get(),
      ]);

      final incomingTransfers = futures[0].docs;
      final outgoingTransfers = futures[1].docs;
      final sales = futures[2].docs;

      final List<TankHistoryEntry> list = [];

      for (var doc in incomingTransfers) {
        final data = doc.data() as Map<String, dynamic>;
        final double m = (data['miktar'] as num?)?.toDouble() ?? 0.0;
        final plaka = data['plaka'] ?? '';
        final kaynak = data['kaynakTank'] ?? '';
        final saat = data['saat'] ?? '';
        final ts = data['timestamp'];
        DateTime date = DateTime(1970);
        if (ts is Timestamp) {
          date = ts.toDate();
        } else if (data['tarih'] is String) {
          date = _parseDateStr(data['tarih']);
        }

        list.add(TankHistoryEntry(
          title: 'Süt Kabul (Giriş)',
          subtitle: 'Araç: $plaka\nKaynak: $kaynak • Saat: $saat',
          miktar: m,
          date: date,
          isIncoming: true,
        ));
      }

      for (var doc in outgoingTransfers) {
        final data = doc.data() as Map<String, dynamic>;
        final double m = (data['miktar'] as num?)?.toDouble() ?? 0.0;
        final plaka = data['plaka'] ?? '';
        final hedef = data['hedefTank'] ?? '';
        final saat = data['saat'] ?? '';
        final ts = data['timestamp'];
        DateTime date = DateTime(1970);
        if (ts is Timestamp) {
          date = ts.toDate();
        } else if (data['tarih'] is String) {
          date = _parseDateStr(data['tarih']);
        }

        list.add(TankHistoryEntry(
          title: 'Süt Transferi (Çıkış)',
          subtitle: 'Araç: $plaka\nHedef: $hedef • Saat: $saat',
          miktar: m,
          date: date,
          isIncoming: false,
        ));
      }

      for (var doc in sales) {
        final data = doc.data() as Map<String, dynamic>;
        final double m = (data['miktar'] as num?)?.toDouble() ?? 0.0;
        final alici = data['aliciFirma'] ?? '';
        final not_ = data['not'] ?? '';
        final ts = data['timestamp'];
        DateTime date = DateTime.now();
        if (ts is Timestamp) {
          date = ts.toDate();
        } else if (data['tarih'] is String) {
          try {
            final String tStr = data['tarih'];
            final parts = tStr.split(' ');
            if (parts.length >= 3) {
              final day = int.tryParse(parts[0]) ?? 1;
              final year = int.tryParse(parts[2]) ?? DateTime.now().year;
              final months = {
                'Oca': 1, 'Şub': 2, 'Mar': 3, 'Nis': 4, 'May': 5, 'Haz': 6,
                'Tem': 7, 'Ağu': 8, 'Eyl': 9, 'Eki': 10, 'Kas': 11, 'Ara': 12
              };
              int month = 1;
              final mWord = parts[1].substring(0, 3);
              if (months.containsKey(mWord)) {
                month = months[mWord]!;
              }
              int hour = 12;
              int minute = 0;
              if (parts.length >= 4 && parts[3].contains(':')) {
                final timeParts = parts[3].split(':');
                hour = int.tryParse(timeParts[0]) ?? 12;
                minute = int.tryParse(timeParts[1]) ?? 0;
              }
              date = DateTime(year, month, day, hour, minute);
            }
          } catch (_) {}
        }

        list.add(TankHistoryEntry(
          title: 'Süt Satışı (Çıkış)',
          subtitle: 'Alıcı: $alici${not_.isNotEmpty ? '\nNot: $not_' : ''}',
          miktar: m,
          date: date,
          isIncoming: false,
        ));
      }

      list.sort((a, b) => b.date.compareTo(a.date));
      return list;
    }
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
          // Süt kayıtlarını sıfırla butonu (kırmızı)
          Builder(builder: (ctx) {
            final firma = Provider.of<AuthProvider>(ctx, listen: false).user?.displayName ?? '';
            return _isResetting
                ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                : IconButton(
                    tooltip: 'Süt Kayıtlarını Sıfırla',
                    icon: const Icon(Icons.cleaning_services_rounded, color: Colors.red),
                    onPressed: () => _resetMilkOnly(firma),
                  );
          }),
          // Sıfırla & Ata butonu (turuncu)
          Builder(builder: (ctx) {
            final firma = Provider.of<AuthProvider>(ctx, listen: false).user?.displayName ?? '';
            return _isResetting
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: 'Tankları Sıfırla & Sürücülere Ata',
                    icon: const Icon(Icons.auto_fix_high_rounded, color: Colors.orange),
                    onPressed: () => _resetAndAssignTanks(firma),
                  );
          }),
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: StreamBuilder<QuerySnapshot>(
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
    ),
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
    final bool isWeb = MediaQuery.of(context).size.width > 750;
    
    Widget buildTankCard(QueryDocumentSnapshot doc) {
      final data = doc.data() as Map<String, dynamic>;
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
              onTap: () => _showTankIcerik(context, ad, tip),
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
    }

    if (isWeb) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 12,
          mainAxisExtent: 80,
        ),
        itemCount: tanks.length,
        itemBuilder: (context, index) {
          return buildTankCard(tanks[index]);
        },
      );
    }

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
          return buildTankCard(tanks[index]);
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

class TankHistoryEntry {
  final String title;
  final String subtitle;
  final double miktar;
  final DateTime date;
  final bool isIncoming;

  TankHistoryEntry({
    required this.title,
    required this.subtitle,
    required this.miktar,
    required this.date,
    required this.isIncoming,
  });
}

