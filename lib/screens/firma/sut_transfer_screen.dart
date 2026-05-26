import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';

class SutTransferScreen extends StatefulWidget {
  const SutTransferScreen({super.key});

  @override
  State<SutTransferScreen> createState() => _SutTransferScreenState();
}

class _SutTransferScreenState extends State<SutTransferScreen> {
  bool _isRefreshing = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _initializeTransferData();
  }

  Future<void> _initializeTransferData() async {
    final db = FirebaseFirestore.instance;
    final snap = await db.collection('sut_transferleri').limit(1).get();
    if (snap.docs.isEmpty) {
      // Seed mock data for Süt Transferleri
      await db.collection('sut_transferleri').add({
        'plaka': '34 EMR 190',
        'surucu': 'Emre Can Yılmaz',
        'goz': '1. Göz',
        'hedef_tank': 'Merkez Tank #1',
        'miktar': 1500.0,
        'tarih': '25 May 2026 14:32',
        'durum': 'Tamamlandı',
        'handler': 'Metin Aktaş',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await db.collection('sut_transferleri').add({
        'plaka': '06 BJK 1903',
        'surucu': 'Süleyman Seba',
        'goz': '2. Göz',
        'hedef_tank': 'Firma 1 Merkez Tankı',
        'miktar': 2200.0,
        'tarih': '25 May 2026 10:15',
        'durum': 'Tamamlandı',
        'handler': 'Ahmet Nur',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await db.collection('sut_transferleri').add({
        'plaka': '16 TMB 16',
        'surucu': 'Bursasporlu Driver',
        'goz': '3. Göz',
        'hedef_tank': 'Merkez Tank #2',
        'miktar': 850.0,
        'tarih': '24 May 2026 18:45',
        'durum': 'Tamamlandı',
        'handler': 'Metin Aktaş',
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
          'Süt Transferleri',
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
      ),
      body: Column(
        children: [
          // Search & Metrics Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Plaka, sürücü veya tank ara...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.gray400),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gray200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.gray200),
                    ),
                    fillColor: AppColors.gray50,
                    filled: true,
                  ),
                ),
              ],
            ),
          ),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sut_transferleri')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting || _isRefreshing) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];
                
                final filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final plaka = (data['plaka'] ?? '').toString().toLowerCase();
                  final surucu = (data['surucu'] ?? '').toString().toLowerCase();
                  final hedef = (data['hedef_tank'] ?? '').toString().toLowerCase();
                  final handler = (data['handler'] ?? '').toString().toLowerCase();

                  return plaka.contains(_searchQuery) ||
                      surucu.contains(_searchQuery) ||
                      hedef.contains(_searchQuery) ||
                      handler.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'Kayıtlı transfer işlemi bulunamadı.',
                      style: GoogleFonts.inter(color: AppColors.gray500),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final data = filtered[index].data() as Map<String, dynamic>;
                    final String plaka = data['plaka'] ?? '';
                    final String surucu = data['surucu'] ?? '';
                    final String goz = data['goz'] ?? '1. Göz';
                    final String hedefTank = data['hedef_tank'] ?? '';
                    final double miktar = (data['miktar'] as num?)?.toDouble() ?? 0.0;
                    final String tarih = data['tarih'] ?? '';
                    final String durum = data['durum'] ?? 'Tamamlandı';
                    final String handler = data['handler'] ?? '';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
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
                          // Plaka, Goz & Status
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.gray100,
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: AppColors.gray300),
                                    ),
                                    child: Text(
                                      plaka,
                                      style: GoogleFonts.inter(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.gray800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      goz,
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.check_circle, size: 12, color: Color(0xFF10B981)),
                                    const SizedBox(width: 4),
                                    Text(
                                      durum,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF10B981),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Sürücü & Handler
                          Row(
                            children: [
                              const Icon(Icons.person_rounded, size: 16, color: AppColors.gray400),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Sürücü: $surucu',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.gray700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.assignment_ind_rounded, size: 16, color: AppColors.gray400),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Teslim Alan: $handler',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: AppColors.gray600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Target & Volume Box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.gray50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.gray100),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.storage_rounded, size: 16, color: Color(0xFF8B5CF6)),
                                    const SizedBox(width: 6),
                                    Text(
                                      hedefTank,
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.gray700,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '${miktar.toStringAsFixed(0)} L',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gray800,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),
                          // Date Text
                          Align(
                            alignment: Alignment.bottomRight,
                            child: Text(
                              tarih,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.gray400,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
