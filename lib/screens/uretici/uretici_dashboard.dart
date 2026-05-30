import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';
import '../firma/urunler_screen.dart';

class UreticiDashboard extends StatelessWidget {
  const UreticiDashboard({super.key});

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isThisMonth(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month;
  }

  DateTime? _getDocDate(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    if (data == null) return null;
    final ts = data['timestamp'] as Timestamp?;
    if (ts != null) return ts.toDate();
    final dateStr = data['tarih'] as String?;
    if (dateStr != null && dateStr.isNotEmpty) {
      try {
        final parts = dateStr.split('.');
        return DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
      } catch (_) {}
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final producerName = authProvider.user?.displayName ?? 'Mehmet Yılmaz';
    final firestoreService = FirestoreService();
    return PopUpAdWrapper(
      role: 'uretici',
      child: StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('ureticiler')
          .where('name', isEqualTo: producerName)
          .limit(1)
          .snapshots(),
      builder: (context, producerSnap) {
        String bolge = '';
        String group = '';
        String currentFirma = '';
        if (producerSnap.hasData && producerSnap.data!.docs.isNotEmpty) {
          final pDoc = producerSnap.data!.docs.first.data() as Map<String, dynamic>;
          bolge = pDoc['bolge'] ?? '';
          group = pDoc['group'] ?? '';
          final List<dynamic> firms = pDoc['firmalar'] ?? [];
          if (firms.isNotEmpty) {
            currentFirma = firms.first.toString();
          }
        }

        return StreamBuilder<QuerySnapshot>(
          stream: firestoreService.getMilkPricesStream(firma: currentFirma),
          builder: (context, pricesSnap) {
            final priceDocs = pricesSnap.data?.docs ?? [];

            return StreamBuilder<QuerySnapshot>(
              stream: firestoreService.getProducerCollectionsStream(producerName),
              builder: (context, snapshot) {
                double bugunTotal = 0.0;
                double ayTotal = 0.0;

                final docs = List<QueryDocumentSnapshot>.from(snapshot.data?.docs ?? []);
                docs.sort((a, b) {
                  final aTime = _getDocDate(a);
                  final bTime = _getDocDate(b);
                  if (aTime == null) return -1;
                  if (bTime == null) return 1;
                  return bTime.compareTo(aTime);
                });
                final now = DateTime.now();
                final last7DaysVal = List<double>.filled(7, 0.0);

                for (var doc in docs) {
                  final data = doc.data() as Map<String, dynamic>;
                  final mVal = data['m'];
                  final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);

                  final docDate = _getDocDate(doc);
                  if (docDate != null) {
                    if (_isToday(docDate)) {
                      bugunTotal += m;
                    }
                    if (_isThisMonth(docDate)) {
                      ayTotal += m;
                    }

                    final docLocalDate = DateTime(docDate.year, docDate.month, docDate.day);
                    final nowLocalDate = DateTime(now.year, now.month, now.day);
                    final difference = nowLocalDate.difference(docLocalDate).inDays;
                    if (difference >= 0 && difference < 7) {
                      final index = 6 - difference;
                      if (index >= 0 && index < 7) {
                        last7DaysVal[index] += m;
                      }
                    }
                  } else {
                    bugunTotal += m;
                    ayTotal += m;
                    last7DaysVal[6] += m;
                  }
                }

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('tahsilatlar')
                      .where('uretici', isEqualTo: producerName)
                      .snapshots(),
                  builder: (context, tahsilatlarSnap) {
                    final tDocs = tahsilatlarSnap.data?.docs ?? [];

                    return StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('avanslar')
                          .where('uretici', isEqualTo: producerName)
                          .snapshots(),
                      builder: (context, avanslarSnap) {
                        final aDocs = avanslarSnap.data?.docs ?? [];

                        return StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('kesintiler')
                              .where('uretici', isEqualTo: producerName)
                              .snapshots(),
                          builder: (context, kesintilerSnap) {
                            final kDocs = kesintilerSnap.data?.docs ?? [];

                            return StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('cezalar')
                                  .where('uretici', isEqualTo: producerName)
                                  .snapshots(),
                              builder: (context, cezalarSnap) {
                                final cDocs = cezalarSnap.data?.docs ?? [];

                                return StreamBuilder<QuerySnapshot>(
                                  stream: FirebaseFirestore.instance
                                      .collection('devirler')
                                      .where('uretici', isEqualTo: producerName)
                                      .snapshots(),
                                  builder: (context, devirlerSnap) {
                                    final devirDocs = devirlerSnap.data?.docs ?? [];

                                    final ledger = firestoreService.calculateLedger(
                                      collections: docs,
                                      prices: priceDocs,
                                      tahsilatlar: tDocs,
                                      avanslar: aDocs,
                                      kesintiler: kDocs,
                                      cezalar: cDocs,
                                      producerName: producerName,
                                      bolge: bolge,
                                      group: group,
                                      kesintiAyarlari: producerSnap.hasData && producerSnap.data!.docs.isNotEmpty
                                          ? (producerSnap.data!.docs.first.data() as Map<String, dynamic>)['kesintiAyarlari'] as Map<String, dynamic>?
                                          : null,
                                    );

                                    final double toplamAlacak = ledger['toplamAlacak'];
                                    final double totalTahsilat = ledger['totalTahsilat'];
                                    final double totalAvans = ledger['totalAvans'];
                                    final double totalKesinti = ledger['totalKesinti'];
                                    final double totalCeza = ledger['totalCeza'];

                                    // Calculate prior collections & balances
                                    final startOfThisMonth = DateTime(now.year, now.month, 1);

                                    final priorDocs = docs.where((doc) {
                                      final date = _getDocDate(doc);
                                      return date != null && date.isBefore(startOfThisMonth);
                                    }).toList();

                                    final priorTDocs = tDocs.where((doc) {
                                      final date = _getDocDate(doc);
                                      return date != null && date.isBefore(startOfThisMonth);
                                    }).toList();

                                    final priorADocs = aDocs.where((doc) {
                                      final date = _getDocDate(doc);
                                      return date != null && date.isBefore(startOfThisMonth);
                                    }).toList();

                                    final priorKDocs = kDocs.where((doc) {
                                      final date = _getDocDate(doc);
                                      return date != null && date.isBefore(startOfThisMonth);
                                    }).toList();

                                    final priorCDocs = cDocs.where((doc) {
                                      final date = _getDocDate(doc);
                                      return date != null && date.isBefore(startOfThisMonth);
                                    }).toList();

                                    final priorLedger = firestoreService.calculateLedger(
                                      collections: priorDocs,
                                      prices: priceDocs,
                                      tahsilatlar: priorTDocs,
                                      avanslar: priorADocs,
                                      kesintiler: priorKDocs,
                                      cezalar: priorCDocs,
                                      producerName: producerName,
                                      bolge: bolge,
                                      group: group,
                                      kesintiAyarlari: producerSnap.hasData && producerSnap.data!.docs.isNotEmpty
                                          ? (producerSnap.data!.docs.first.data() as Map<String, dynamic>)['kesintiAyarlari'] as Map<String, dynamic>?
                                          : null,
                                    );

                                    double priorDevirSum = 0.0;
                                    double totalDevir = 0.0;
                                    for (var doc in devirDocs) {
                                      final date = _getDocDate(doc);
                                      final data = doc.data() as Map<String, dynamic>;
                                      final val = data['tutar'];
                                      final double valDouble = val is num ? val.toDouble() : (double.tryParse(val.toString()) ?? 0.0);
                                      totalDevir += valDouble;
                                      if (date != null && date.isBefore(startOfThisMonth)) {
                                        priorDevirSum += valDouble;
                                      }
                                    }

                                    final double bekleyenOdeme = priorLedger['netBalance'] + priorDevirSum;
                                    final double netAlacak = ledger['netBalance'] + totalDevir;

                                    final currentDay = now.day;
                                    final double gunlukOrtalama = currentDay > 0 ? (ayTotal / currentDay) : 0.0;

                                    bool siparisIzni = true;
                                    if (producerSnap.hasData && producerSnap.data!.docs.isNotEmpty) {
                                      final pDoc = producerSnap.data!.docs.first.data() as Map<String, dynamic>;
                                      siparisIzni = pDoc['siparisIzni'] ?? true;
                                    }

                                    return LayoutBuilder(
                                      builder: (context, constraints) {
                                        final isDesktop = constraints.maxWidth >= 1024;
                                        final isTablet = constraints.maxWidth >= 640 && constraints.maxWidth < 1024;

                                        return ListView(
                                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                                          children: [
                                            // Header
                                            StreamBuilder<QuerySnapshot>(
                                              stream: FirebaseFirestore.instance
                                                  .collection('firmalar')
                                                  .where('ad', isEqualTo: currentFirma)
                                                  .limit(1)
                                                  .snapshots(),
                                              builder: (context, companySnap) {
                                                String? logoUrl;
                                                if (companySnap.hasData && companySnap.data!.docs.isNotEmpty) {
                                                  final companyData = companySnap.data!.docs.first.data() as Map<String, dynamic>;
                                                  logoUrl = companyData['logoUrl'] as String?;
                                                }

                                                return Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                           Row(
                                                             children: [
                                                               Text(
                                                                 'Üretici Paneli',
                                                                 style: GoogleFonts.inter(
                                                                   fontSize: isDesktop ? 22 : 18,
                                                                   fontWeight: FontWeight.w700,
                                                                   color: AppColors.gray900,
                                                                 ),
                                                               ),
                                                               const SizedBox(width: 8),
                                                               ElevatedButton.icon(
                                                                 onPressed: () => context.push('/uretici/dijital-kart'),
                                                                 icon: const Icon(Icons.badge_rounded, size: 13),
                                                                 label: Text(
                                                                   'Dijital Süt Kartı',
                                                                   style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold),
                                                                 ),
                                                                 style: ElevatedButton.styleFrom(
                                                                   backgroundColor: AppColors.primary600,
                                                                   foregroundColor: Colors.white,
                                                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                                                   padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                   minimumSize: Size.zero,
                                                                   tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                                                 ),
                                                               ),
                                                             ],
                                                           ),
                                                          const SizedBox(height: 4),
                                                          Text(
                                                            'Süt teslimatlarınızı ve güncel geçmişinizi buradan inceleyebilirsiniz.',
                                                            style: GoogleFonts.inter(
                                                              fontSize: isDesktop ? 12 : 11,
                                                              color: AppColors.gray500,
                                                              fontWeight: FontWeight.w400,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Padding(
                                                      padding: const EdgeInsets.only(left: 12),
                                                      child: Column(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          Container(
                                                            width: 60,
                                                            height: 60,
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(12),
                                                              border: Border.all(color: AppColors.gray200, width: 1.5),
                                                              color: Colors.white,
                                                              image: logoUrl != null && logoUrl.isNotEmpty
                                                                  ? DecorationImage(
                                                                      image: logoUrl.startsWith('data:image')
                                                                          ? MemoryImage(base64Decode(logoUrl.substring(logoUrl.indexOf(',') + 1))) as ImageProvider
                                                                          : NetworkImage(logoUrl),
                                                                      fit: BoxFit.cover,
                                                                    )
                                                                  : null,
                                                            ),
                                                            child: logoUrl == null || logoUrl.isEmpty
                                                                ? Center(
                                                                    child: Icon(Icons.business_rounded, color: AppColors.gray400, size: 24),
                                                                  )
                                                                : null,
                                                          ),
                                                          if (currentFirma.isNotEmpty) ...[
                                                            const SizedBox(height: 6),
                                                            SizedBox(
                                                              width: 72,
                                                              child: Text(
                                                                currentFirma,
                                                                textAlign: TextAlign.center,
                                                                maxLines: 2,
                                                                overflow: TextOverflow.ellipsis,
                                                                style: GoogleFonts.inter(
                                                                  fontSize: 11.5,
                                                                  fontWeight: FontWeight.bold,
                                                                  color: AppColors.gray800,
                                                                  height: 1.1,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                );
                                              }
                                            ),
                                            const SizedBox(height: 20),

                                            // Stat Cards Grid
                                            _buildStatCards(isDesktop, isTablet, bugunTotal, ayTotal, gunlukOrtalama, bekleyenOdeme),
                                            const SizedBox(height: 24),

                                            // Hızlı İşlemler Section Title
                                            Text(
                                              'Hızlı İşlemler',
                                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                            ),
                                            const SizedBox(height: 12),
                                            _buildQuickActionsGrid(context, producerName, currentFirma, bolge, group, siparisIzni),
                                            const SizedBox(height: 24),

                                            // Mali Özet Section Title
                                            Text(
                                              'Mali Durum Özeti',
                                              style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                            ),
                                            const SizedBox(height: 12),
                                            _buildMaliCards(isDesktop, isTablet, toplamAlacak, totalTahsilat, totalAvans, totalCeza, totalKesinti, netAlacak),
                                            const SizedBox(height: 24),

                                            // Charts & History
                                            _buildContentLayout(isDesktop, docs, last7DaysVal),
                                            const SizedBox(height: 80),
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
        );
      },
    ),
  );
  }

  Widget _buildQuickActionsGrid(BuildContext context, String producerName, String currentFirma, String bolge, String group, bool siparisIzni) {
    final List<Map<String, dynamic>> actions = [
      {
        'title': 'Hesap Özeti',
        'subtitle': 'Aylık detaylı rapor',
        'icon': Icons.description_rounded,
        'color': Colors.blue,
        'onTap': () => context.push('/uretici/hesap-ozeti'),
      },
      {
        'title': 'Dijital Kart',
        'subtitle': 'Teslimat barkodu',
        'icon': Icons.qr_code_rounded,
        'color': Colors.teal,
        'onTap': () => context.push('/uretici/dijital-kart'),
      },
      {
        'title': 'Destek Hattı',
        'subtitle': 'Toplayıcıyı ara',
        'icon': Icons.support_agent_rounded,
        'color': Colors.orange,
        'onTap': () => _handleSupportCall(context, producerName, currentFirma, bolge, group),
      },
      if (siparisIzni)
        {
          'title': 'Ürün Siparişi',
          'subtitle': 'Yem, kepek sipariş et',
          'icon': Icons.shopping_bag_rounded,
          'color': Colors.indigo,
          'onTap': () => context.push('/uretici/urunler'),
        },
      {
        'title': 'Sipariş Takip',
        'subtitle': 'Sipariş durumunu izle',
        'icon': Icons.local_shipping_rounded,
        'color': Colors.purple,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (ctx) => ProducerOrdersHistoryPage(
                producerName: producerName,
                firmaName: currentFirma,
              ),
            ),
          );
        },
      },
      {
        'title': 'Analiz Sonuçları',
        'subtitle': 'Süt analiz değerleri',
        'icon': Icons.science_rounded,
        'color': Colors.deepOrange,
        'onTap': () => _showAnalysisHistoryDialog(context, producerName),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth >= 1024) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth >= 640) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: actions.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final action = actions[index];
            final Color color = action['color'];
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: AppShadows.sm,
                border: Border.all(color: AppColors.gray100),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: action['onTap'],
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(action['icon'], color: color, size: 20),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              action['title'],
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gray800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              action['subtitle'],
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.gray500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleSupportCall(BuildContext context, String producerName, String firma, String bolge, String group) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    String? assignedDriver;

    try {
      final atamalarQuery = await FirebaseFirestore.instance
          .collection('toplayici_atamalari')
          .where('firma', isEqualTo: firma)
          .get();

      for (var doc in atamalarQuery.docs) {
        final data = doc.data();
        final hTip = data['hedefTip'];
        final hAd = data['hedefAd'];
        if (hTip == 'uretici' && hAd == producerName) {
          assignedDriver = data['toplayici'];
          break;
        }
      }
      if (assignedDriver == null) {
        for (var doc in atamalarQuery.docs) {
          final data = doc.data();
          final hTip = data['hedefTip'];
          final hAd = data['hedefAd'];
          if (hTip == 'grup' && hAd == group && group.isNotEmpty) {
            assignedDriver = data['toplayici'];
            break;
          }
        }
      }
      if (assignedDriver == null) {
        for (var doc in atamalarQuery.docs) {
          final data = doc.data();
          final hTip = data['hedefTip'];
          final hAd = data['hedefAd'];
          if (hTip == 'bolge' && hAd == bolge && bolge.isNotEmpty) {
            assignedDriver = data['toplayici'];
            break;
          }
        }
      }
    } catch (_) {}

    if (context.mounted) {
      Navigator.pop(context);
    }

    if (assignedDriver == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıtlı süt toplayıcınız bulunamadı.'), backgroundColor: AppColors.warning),
      );
      return;
    }

    try {
      final surucuQuery = await FirebaseFirestore.instance
          .collection('suruculer')
          .where('firma', isEqualTo: firma)
          .get();

      String? phone;
      for (var doc in surucuQuery.docs) {
        final data = doc.data();
        final ad = data['ad'] ?? '';
        final soyad = data['soyad'] ?? '';
        final fullName = '$ad $soyad'.trim();
        if (fullName.toLowerCase() == assignedDriver.toLowerCase()) {
          phone = data['tel'];
          break;
        }
      }

      if (phone != null && phone.isNotEmpty) {
        final Uri telUri = Uri.parse('tel:$phone');
        if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Arama başlatılamadı: $phone'), backgroundColor: AppColors.danger),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$assignedDriver için telefon numarası bulunamadı.'), backgroundColor: AppColors.warning),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Toplayıcı telefon bilgisi alınamadı: $e'), backgroundColor: AppColors.danger),
      );
    }
  }

  void _showAnalysisHistoryDialog(BuildContext context, String producerName) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Süt Analiz Sonuçlarım',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sut_analiz')
                  .where('hedef', isEqualTo: producerName)
                  .where('tip', isEqualTo: 'Üretici')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Kayıtlı analiz sonucu bulunamadı.',
                      style: GoogleFonts.inter(color: AppColors.gray500, fontSize: 13),
                    ),
                  );
                }

                final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
                docs.sort((a, b) {
                  final aTime = (a.data() as Map)['timestamp'] as Timestamp?;
                  final bTime = (b.data() as Map)['timestamp'] as Timestamp?;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                return ListView.separated(
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const Divider(height: 16),
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final tarih = data['tarih'] ?? '-';
                    final yag = (data['yag'] as num?)?.toDouble() ?? 0.0;
                    final protein = (data['protein'] as num?)?.toDouble() ?? 0.0;
                    final su = (data['su'] as num?)?.toDouble() ?? 0.0;
                    final sicaklik = (data['sicaklik'] as num?)?.toDouble() ?? 0.0;
                    final durum = data['durum'] ?? 'Normal';
                    final isRiskli = durum == 'Riskli';

                    return ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Row(
                        children: [
                          Icon(
                            isRiskli ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                            color: isRiskli ? Colors.red : Colors.green,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tarih,
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isRiskli ? Colors.red[50] : Colors.green[50],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              durum,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isRiskli ? Colors.red[700] : Colors.green[700],
                              ),
                            ),
                          ),
                        ],
                      ),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1.2),
                              1: FlexColumnWidth(1),
                            },
                            children: [
                              TableRow(children: [
                                _buildTableCell('Yağ (%)', header: true),
                                _buildTableCell(yag.toStringAsFixed(2)),
                              ]),
                              TableRow(children: [
                                _buildTableCell('Protein (%)', header: true),
                                _buildTableCell(protein.toStringAsFixed(2)),
                              ]),
                              TableRow(children: [
                                _buildTableCell('Eklenen Su (%)', header: true),
                                _buildTableCell(su.toStringAsFixed(2)),
                              ]),
                              TableRow(children: [
                                _buildTableCell('Sıcaklık (°C)', header: true),
                                _buildTableCell(sicaklik.toStringAsFixed(1)),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kapat'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTableCell(String text, {bool header = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: header ? FontWeight.w600 : FontWeight.w400,
          color: header ? AppColors.gray700 : AppColors.gray900,
        ),
      ),
    );
  }

  Widget _buildStatCards(bool isDesktop, bool isTablet, double bugun, double buAy, double gunlukOrtalama, double bekleyenOdeme) {
    final formatLitre = NumberFormat('#,##0', 'tr_TR');
    final formatCurrency = NumberFormat('#,##0.00', 'tr_TR');
    final cards = [
      StatCard(
        icon: Icons.today_rounded,
        value: formatLitre.format(bugun),
        label: 'Bugün (LT)',
        color: AppColors.primary600,
        subtext: 'Bugünkü Alım Miktarı',
        isUp: true,
      ),
      StatCard(
        icon: Icons.calendar_month_rounded,
        value: formatLitre.format(buAy),
        label: 'Bu Ay (LT)',
        color: AppColors.success,
        subtext: '1\'inden bugüne toplam',
        isUp: true,
      ),
      StatCard(
        icon: Icons.trending_up_rounded,
        value: formatLitre.format(gunlukOrtalama),
        label: 'Günlük Ortalama (LT)',
        color: AppColors.warning,
        subtext: 'Aylık Ortalama',
        isUp: true,
      ),
      StatCard(
        icon: Icons.account_balance_wallet_rounded,
        value: '${formatCurrency.format(bekleyenOdeme.abs())} ₺',
        label: bekleyenOdeme >= 0 ? 'Devreden Alacak' : 'Devreden Borç',
        color: bekleyenOdeme >= 0 ? Colors.green : Colors.red,
        subtext: 'Önceki aydan devir',
        isUp: bekleyenOdeme >= 0,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: c,
        ))).toList(),
      );
    } else if (isTablet) {
      return StatsGrid(
        crossAxisCount: 2,
        spacing: 12,
        children: cards,
      );
    } else {
      return StatsGrid(
        crossAxisCount: 2,
        spacing: 10,
        children: cards,
      );
    }
  }

  Widget _buildContentLayout(bool isDesktop, List<QueryDocumentSnapshot> docs, List<double> last7DaysVal) {
    final spots = <FlSpot>[];
    for (int i = 0; i < 7; i++) {
      spots.add(FlSpot(i.toDouble(), last7DaysVal[i]));
    }

    final d = <String>[];
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      d.add(DateFormat('E', 'tr_TR').format(date));
    }

    // Determine max y value for proper chart scaling
    double maxY = 50.0;
    for (var val in last7DaysVal) {
      if (val > maxY) maxY = val + 10.0;
    }

    final chartWidget = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Son 7 Gün Grafiği',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gray800),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.gray100, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY,
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) {
                        final index = v.toInt();
                        if (index >= 0 && index < d.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(d[index], style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (spots) => spots.map((s) => LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} LT',
                      GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                    )).toList(),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.primary600,
                    barWidth: 3,
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppColors.primary400.withValues(alpha: 0.25), AppColors.primary400.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                        radius: 4,
                        color: AppColors.primary600,
                        strokeWidth: 2.5,
                        strokeColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
            ),
          ),
        ],
      ),
    );

    final historyWidget = AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Teslim Geçmişi',
              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.gray800),
            ),
          ),
          const SizedBox(height: 12),
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Henüz teslimat kaydı bulunmuyor.',
                  style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400),
                ),
              ),
            )
          else
            ...docs.map((t) {
              final data = t.data() as Map<String, dynamic>;
              final timestamp = data['timestamp'] as Timestamp?;
              final dateStr = timestamp != null ? DateFormat('dd.MM.yyyy').format(timestamp.toDate()) : '-';
              final s = data['s'] ?? '';
              final sr = data['sr'] ?? 'Ahmet Kara';
              final mVal = data['m'] ?? 0;
              final mStr = mVal is num ? mVal.toStringAsFixed(0) : mVal.toString();

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: AppColors.gray50, borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppColors.primary400.withValues(alpha: 0.15), AppColors.primary600.withValues(alpha: 0.08)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.water_drop_rounded, color: AppColors.primary500, size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('$dateStr • $s', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                    Text('Teslim Edilen: $sr', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: AppColors.primary50, borderRadius: BorderRadius.circular(6)),
                    child: Text('$mStr LT', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary600)),
                  ),
                ]),
              );
            }),
        ],
      ),
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 6, child: chartWidget),
          const SizedBox(width: 16),
          Expanded(flex: 4, child: historyWidget),
        ],
      );
    }

    return Column(
      children: [
        chartWidget,
        const SizedBox(height: 16),
        historyWidget,
      ],
    );
  }

  Widget _buildMaliCards(bool isDesktop, bool isTablet, double alacak, double tahsilat, double avans, double ceza, double kesinti, double net) {
    final format = NumberFormat('#,##0.00', 'tr_TR');
    final cards = [
      StatCard(
        icon: Icons.payments_rounded,
        value: format.format(alacak),
        label: 'Toplam Süt Alacağı',
        color: AppColors.primary600,
        change: '',
        subtext: 'Dinamik Fiyatlandırma',
        sparklineData: const [],
        isUp: true,
      ),
      StatCard(
        icon: Icons.account_balance_wallet_rounded,
        value: format.format(tahsilat),
        label: 'Tahsil Edilen Tutar',
        color: Colors.purple,
        change: '',
        subtext: 'Ödenen toplam süt bedeli',
        sparklineData: const [],
        isUp: true,
      ),
      StatCard(
        icon: Icons.money_off_rounded,
        value: format.format(avans),
        label: 'Alınan Toplam Avans',
        color: Colors.red,
        change: '',
        subtext: 'Tahsilattan düşülen avanslar',
        sparklineData: const [],
        isUp: false,
      ),
      StatCard(
        icon: Icons.gavel_rounded,
        value: format.format(ceza),
        label: 'Uygulanan Cezalar',
        color: Colors.orange,
        change: '',
        subtext: 'Süt kalite kesintileri',
        sparklineData: const [],
        isUp: false,
      ),
      StatCard(
        icon: Icons.content_cut_rounded,
        value: format.format(kesinti),
        label: 'Uygulanan Kesintiler',
        color: Colors.redAccent,
        change: '',
        subtext: 'Yem, aidat vb. kesintileri',
        sparklineData: const [],
        isUp: false,
      ),
      StatCard(
        icon: Icons.price_check_rounded,
        value: format.format(net.abs()),
        label: net >= 0 ? 'Kalan Net Alacak' : 'Kalan Toplam Borç',
        color: net >= 0 ? Colors.green : Colors.red,
        change: '',
        subtext: net >= 0 ? 'Ödenmesi gereken net bakiye' : 'Firmaya olan eksi bakiye',
        sparklineData: const [],
        isUp: net >= 0,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: cards.map((c) => Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: c,
        ))).toList(),
      );
    } else if (isTablet) {
      return StatsGrid(
        crossAxisCount: 2,
        spacing: 12,
        children: cards,
      );
    } else {
      return StatsGrid(
        crossAxisCount: 2,
        spacing: 10,
        children: cards,
      );
    }
  }
}

class PopUpAdWrapper extends StatefulWidget {
  final Widget child;
  final String role;

  const PopUpAdWrapper({super.key, required this.child, required this.role});

  @override
  State<PopUpAdWrapper> createState() => _PopUpAdWrapperState();
}

class _PopUpAdWrapperState extends State<PopUpAdWrapper> {
  static final Set<String> _shownPopups = {};

  @override
  void initState() {
    super.initState();
    _checkForPopUpAds();
  }

  void _checkForPopUpAds() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final query = await FirebaseFirestore.instance
            .collection('duyurular')
            .where('isGlobal', isEqualTo: true)
            .get();

        final docs = query.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data == null) return false;
          final isPopUp = data['isPopUp'] as bool? ?? false;
          final targetRoles = data['targetRoles'] as List<dynamic>?;
          return isPopUp && (targetRoles != null && targetRoles.contains(widget.role));
        }).toList();

        if (docs.isNotEmpty) {
          docs.sort((a, b) {
            final aTime = (a.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            final bTime = (b.data() as Map<String, dynamic>)['timestamp'] as Timestamp?;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });
          final doc = docs.first;
          final docId = doc.id;
          
          if (_shownPopups.contains(docId)) return;
          _shownPopups.add(docId);

          final data = doc.data() as Map<String, dynamic>?;
          final baslik = data?['baslik'] ?? '';
          final icerik = data?['icerik'] ?? '';

          if (!mounted) return;

          showDialog(
            context: context,
            barrierDismissible: true,
            builder: (ctx) {
              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                title: Row(
                  children: [
                    const Icon(Icons.campaign_rounded, color: Colors.blueAccent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        baslik,
                        style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
                content: Text(
                  icerik,
                  style: GoogleFonts.inter(fontSize: 13, color: AppColors.gray700),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Kapat', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        }
      } catch (e) {
        print('Error checking pop-up ads: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
