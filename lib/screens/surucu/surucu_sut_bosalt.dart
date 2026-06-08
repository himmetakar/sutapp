import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class SurucuSutBosaltScreen extends StatefulWidget {
  const SurucuSutBosaltScreen({super.key});

  @override
  State<SurucuSutBosaltScreen> createState() => _SurucuSutBosaltScreenState();
}

class _SurucuSutBosaltScreenState extends State<SurucuSutBosaltScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();

  String? _selectedSourceTank;
  String? _selectedTargetTank;
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final driverName = authProvider.user?.displayName ?? '';
    final userEmail = authProvider.user?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Süt Boşalt', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/surucu'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: StreamBuilder<QuerySnapshot>(
        stream: _db.collection('suruculer').snapshots(),
        builder: (context, profileSnapshot) {
          String resolvedDriverName = driverName;

          if (profileSnapshot.hasData && profileSnapshot.data!.docs.isNotEmpty) {
            final docs = profileSnapshot.data!.docs;
            DocumentSnapshot? matchedDoc;
            
            if (driverName.isNotEmpty) {
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final ad = data['ad'] ?? '';
                final soyad = data['soyad'] ?? '';
                final fullName = '$ad $soyad'.trim();
                if (fullName.toLowerCase() == driverName.toLowerCase()) {
                  matchedDoc = doc;
                  break;
                }
              }
            }

            if (matchedDoc == null && userEmail.isNotEmpty) {
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final email = data['email'] ?? '';
                if (email.isNotEmpty && email == userEmail) {
                  matchedDoc = doc;
                  break;
                }
              }
            }

            if (matchedDoc != null) {
              final pData = matchedDoc.data() as Map<String, dynamic>;
              if (driverName.isEmpty) {
                final dbAd = pData['ad'] ?? '';
                final dbSoyad = pData['soyad'] ?? '';
                final dbFullName = '$dbAd $dbSoyad'.trim();
                if (dbFullName.isNotEmpty) {
                  resolvedDriverName = dbFullName;
                }
              }
            }
          }

          return StreamBuilder<QuerySnapshot>(
            stream: _firestoreService.getDriverVehicleStream(resolvedDriverName),
            builder: (context, vehicleSnapshot) {
              if (vehicleSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final vehicleDocs = vehicleSnapshot.data?.docs ?? [];
              final bool hasVehicle = vehicleDocs.isNotEmpty;
              
              bool hasTank = false;
              String plate = '';
              List<Map<String, dynamic>> tankList = [];
              String currentFirmaName = '';
              
              if (hasVehicle) {
                final vehicleDoc = vehicleDocs.first;
                final vehicleData = vehicleDoc.data() as Map<String, dynamic>;
                plate = vehicleData['plaka'] ?? '';
                final rawTankList = vehicleData['tanklar'] as List? ?? [];
                
                tankList = List<Map<String, dynamic>>.from(rawTankList);
                hasTank = tankList.isNotEmpty;
                currentFirmaName = vehicleData['firma'] ?? '';
              }

              if (!hasVehicle || !hasTank) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 64, color: AppColors.gray400),
                        const SizedBox(height: 16),
                        Text(
                          'Araç ve Tank Atanmadı!',
                          style: GoogleFonts.inter(fontSize: 16, color: AppColors.gray600, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Süt boşaltabilmek için üzerinize atanmış aktif bir araç ve tank olması gerekmektedir.',
                          style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (_selectedSourceTank == null || !tankList.any((t) => t['ad'] == _selectedSourceTank)) {
                _selectedSourceTank = tankList.isNotEmpty ? tankList.first['ad'] as String? : null;
              }

              final tank = tankList.firstWhere(
                (t) => t['ad'] == _selectedSourceTank,
                orElse: () => tankList.first,
              );
              final tankName = tank['ad'] ?? '';
              final double currentStock = (tank['stok'] as num?)?.toDouble() ?? 0.0;

              return FutureBuilder<QuerySnapshot>(
                future: _firestoreService.getQueryWithCachePriority(
                  _db.collection('tanklar')
                      .where('firma', isEqualTo: currentFirmaName),
                ),
                builder: (context, tanksSnapshot) {
                  if (tanksSnapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allTanks = tanksSnapshot.data?.docs ?? [];
                  final List<Map<String, dynamic>> otherTanks = allTanks
                      .where((doc) => doc['ad'] != tankName && (doc.data() as Map<String, dynamic>)['tip'] == 'merkez')
                      .map((doc) => {
                            'ad': doc['ad'] as String,
                            'tip': doc['tip'] as String,
                            'stok': (doc['stok'] as num?)?.toDouble() ?? 0.0,
                            'kap': (doc['kap'] as num?)?.toDouble() ?? 5000.0,
                          })
                      .toList();

                  if (otherTanks.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Boşaltılabilecek merkez tankı bulunamadı!',
                          style: GoogleFonts.inter(fontSize: 14, color: AppColors.gray600, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  // Load pending unload request amount to calculate remaining stock
                  return StreamBuilder<QuerySnapshot>(
                    stream: _db.collection('sut_kabul')
                        .where('kaynak', isEqualTo: tankName)
                        .where('durum', isEqualTo: 'Bekliyor')
                        .snapshots(),
                    builder: (context, pendingUnloadSnapshot) {
                      double pendingUnload = 0.0;
                      if (pendingUnloadSnapshot.hasData) {
                        for (var doc in pendingUnloadSnapshot.data!.docs) {
                          final val = doc['miktar'];
                          pendingUnload += val is num ? val.toDouble() : (double.tryParse(val.toString()) ?? 0.0);
                        }
                      }

                      final double remainingStock = (currentStock - pendingUnload).clamp(0.0, double.infinity);

                      if (_amountController.text.isEmpty && !_isSaving) {
                        _amountController.text = remainingStock.toStringAsFixed(0);
                      }
                      if (_selectedTargetTank == null || !otherTanks.any((t) => t['ad'] == _selectedTargetTank)) {
                        _selectedTargetTank = otherTanks.isNotEmpty ? otherTanks.first['ad'] as String : null;
                      }

                      return Form(
                        key: _formKey,
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Current Tank Status Card
                            AppCard(
                              padding: const EdgeInsets.all(16),
                              shadow: AppShadows.sm,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Araç Tank Durumu',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.propane_tank_rounded, color: AppColors.primary600, size: 22),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              tankName,
                                              style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                            ),
                                            Text(
                                              'Plaka: $plate',
                                              style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            '${currentStock.toStringAsFixed(0)} LT',
                                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.primary600),
                                          ),
                                          Text(
                                            'Mevcut Stok',
                                            style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  if (pendingUnload > 0) ...[
                                    const Divider(height: 24),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Onay Bekleyen Talep:', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.orange[800], fontWeight: FontWeight.w600)),
                                        Text('${pendingUnload.toStringAsFixed(0)} LT', style: GoogleFonts.inter(fontSize: 12, color: Colors.orange[850], fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('Kalan Boşaltılabilir:', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.green[800], fontWeight: FontWeight.w600)),
                                        Text('${remainingStock.toStringAsFixed(0)} LT', style: GoogleFonts.inter(fontSize: 12, color: Colors.green[800], fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Request Form Card
                            AppCard(
                              padding: const EdgeInsets.all(16),
                              shadow: AppShadows.sm,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Boşaltma Bilgileri',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                  ),
                                  const SizedBox(height: 16),
                                  if (tankList.length > 1) ...[
                                    DropdownButtonFormField<String>(
                                      value: _selectedSourceTank,
                                      decoration: const InputDecoration(labelText: 'Boşaltılacak Araç Tankı *'),
                                      items: tankList.map((t) {
                                        final name = t['ad'] ?? '';
                                        final double stock = (t['stok'] as num?)?.toDouble() ?? 0.0;
                                        final label = '$name (${stock.toStringAsFixed(0)} LT)';
                                        return DropdownMenuItem(
                                          value: name as String,
                                          child: Text(label, style: const TextStyle(fontSize: 13)),
                                        );
                                      }).toList(),
                                      onChanged: (val) {
                                        setState(() {
                                          _selectedSourceTank = val;
                                          _amountController.clear();
                                        });
                                      },
                                      validator: (val) => val == null ? 'Araç tankı seçmelisiniz' : null,
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  DropdownButtonFormField<String>(
                                    value: _selectedTargetTank,
                                    decoration: const InputDecoration(labelText: 'Boşaltılacak Hedef Tank *'),
                                    items: otherTanks.map((t) {
                                      final label = '${t['ad']} (Merkez)';
                                      return DropdownMenuItem(
                                        value: t['ad'] as String,
                                        child: Text(label, style: const TextStyle(fontSize: 13)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      setState(() {
                                        _selectedTargetTank = val;
                                      });
                                    },
                                    validator: (val) => val == null ? 'Hedef tank seçmelisiniz' : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _amountController,
                                    keyboardType: TextInputType.number,
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                    decoration: const InputDecoration(
                                      labelText: 'Boşaltılacak Miktar (LT) *',
                                      hintText: 'Örn: 1000',
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Boşaltılacak miktarı giriniz';
                                      final double? val = double.tryParse(value.replaceAll(',', '.'));
                                      if (val == null || val <= 0) return 'Lütfen geçerli bir miktar girin';
                                      if (val > remainingStock) return 'Maksimum $remainingStock LT boşaltabilirsiniz';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _isSaving ? null : () => _submitRequest(resolvedDriverName, tankName, remainingStock, plate, currentFirmaName),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary600,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(double.infinity, 44),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      elevation: 0,
                                    ),
                                    child: _isSaving
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                        : Text('Talebi Gönder', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Recent Unload Requests List (History)
                            Text(
                              'Son Boşaltma Talepleri',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                            ),
                            const SizedBox(height: 10),
                            StreamBuilder<QuerySnapshot>(
                              stream: _db.collection('sut_kabul')
                                  .where('kaynak', isEqualTo: tankName)
                                  .snapshots(),
                              builder: (context, historySnapshot) {
                                if (historySnapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                                }

                                final docs = historySnapshot.data?.docs ?? [];
                                
                                // Sort by timestamp descending
                                final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
                                sortedDocs.sort((a, b) {
                                  final aTime = (a.data() as Map)['timestamp'] as Timestamp?;
                                  final bTime = (b.data() as Map)['timestamp'] as Timestamp?;
                                  if (aTime == null && bTime == null) return 0;
                                  if (aTime == null) return 1;
                                  if (bTime == null) return -1;
                                  return bTime.compareTo(aTime);
                                });

                                if (sortedDocs.isEmpty) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(vertical: 24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: AppColors.gray200),
                                    ),
                                    child: Center(
                                      child: Text(
                                        'Henüz boşaltma talebi bulunmuyor.',
                                        style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400),
                                      ),
                                    ),
                                  );
                                }

                                return ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: sortedDocs.length.clamp(0, 10),
                                  itemBuilder: (context, index) {
                                    final doc = sortedDocs[index];
                                    final data = doc.data() as Map<String, dynamic>;
                                    final miktar = data['miktar'] ?? 0;
                                    final hedef = data['hedef'] ?? '';
                                    final durum = data['durum'] ?? 'Bekliyor';
                                    final tarih = data['tarih'] ?? '';

                                    Color statusColor = Colors.orange;
                                    if (durum == 'Kabul Edildi') statusColor = Colors.green;
                                    if (durum == 'Reddedildi') statusColor = Colors.red;

                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.gray200),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Hedef: $hedef',
                                                  style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray800),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  'Miktar: ${miktar.toStringAsFixed(0)} LT • $tarih',
                                                  style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              durum,
                                              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                            ),
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

  Future<void> _submitRequest(
    String driverName,
    String sourceTankName,
    double remainingStock,
    String vehiclePlate,
    String currentFirmaName,
  ) async {
    if (!_formKey.currentState!.validate() || _selectedTargetTank == null) return;

    setState(() {
      _isSaving = true;
    });

    final double amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final String formattedDate = DateFormat('dd.MM.yyyy').format(DateTime.now());

    try {
      await _db.collection('sut_kabul').add({
        'sr': driverName,
        'kaynak': sourceTankName,
        'hedef': _selectedTargetTank,
        'miktar': amount,
        'plaka': vehiclePlate,
        'tarih': formattedDate,
        'durum': 'Bekliyor',
        'firma': currentFirmaName,
        'timestamp': FieldValue.serverTimestamp(),
      });

      // Send notification to company
      await _firestoreService.sendNotification(
        recipientName: currentFirmaName,
        role: 'firma',
        baslik: 'Yeni Süt Kabul Talebi',
        icerik: '$driverName toplayıcısı $sourceTankName tankından ${_selectedTargetTank} tankına ${amount.toStringAsFixed(0)} LT süt boşaltmak için onay bekliyor.',
        type: 'sut_kabul',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Boşaltma talebi başarıyla firma onayına gönderildi!'), backgroundColor: AppColors.success),
        );
        context.go('/surucu');
      }
    } catch (e) {
      print('Error submitting unload request: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Talep gönderilirken hata oluştu: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
