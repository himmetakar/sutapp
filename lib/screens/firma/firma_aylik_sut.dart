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
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _changeMonth(int delta) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';
    final monthStr = DateFormat('MMMM yyyy', 'tr_TR').format(_selectedMonth);

    return Scaffold(
      appBar: AppBar(
        title: Text('Aylık Süt Kayıtları', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/ureticiler'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      body: Column(
        children: [
          // Month Selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, color: AppColors.primary600),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  monthStr.toUpperCase(),
                  style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.gray800),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, color: AppColors.primary600),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const Divider(),

          // Search Field
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Üretici, toplayıcı veya bölge ara...',
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.gray400),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                });
              },
            ),
          ),

          // Flat list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db
                  .collection('toplamalar')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Hata: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rawDocs = snapshot.data?.docs ?? [];
                
                // Sort in memory to avoid index requirements
                final docs = List<QueryDocumentSnapshot>.from(rawDocs);
                docs.sort((a, b) {
                  final aData = a.data() as Map<String, dynamic>;
                  final bData = b.data() as Map<String, dynamic>;
                  final aTime = aData['timestamp'] as Timestamp?;
                  final bTime = bData['timestamp'] as Timestamp?;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                // Filter by month and search query
                final filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final Timestamp? ts = data['timestamp'] as Timestamp?;
                  if (ts == null) return false;
                  final date = ts.toDate();

                  final monthMatches = date.year == _selectedMonth.year && date.month == _selectedMonth.month;
                  if (!monthMatches) return false;

                  if (_searchQuery.isEmpty) return true;

                  final u = (data['u'] as String? ?? '').toLowerCase();
                  final sr = (data['sr'] as String? ?? '').toLowerCase();
                  final b = (data['b'] as String? ?? '').toLowerCase();

                  return u.contains(_searchQuery.toLowerCase()) ||
                      sr.contains(_searchQuery.toLowerCase()) ||
                      b.contains(_searchQuery.toLowerCase());
                }).toList();

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Text(
                      'Bu dönemde süt alım kaydı bulunamadı.',
                      style: GoogleFonts.inter(color: AppColors.gray500),
                    ),
                  );
                }

                // Sum of filtered milk
                double totalMilk = filteredDocs.fold(0.0, (sum, doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final mVal = data['m'] ?? 0.0;
                  final m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);
                  return sum + m;
                });

                return Column(
                  children: [
                    // Summary indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      color: AppColors.primary50,
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Kayıt Sayısı: ${filteredDocs.length}',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary800),
                          ),
                          Text(
                            'Toplam Süt: ${totalMilk.toStringAsFixed(1)} LT',
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary800),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final doc = filteredDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final u = data['u'] ?? '';
                          final mVal = data['m'] ?? 0.0;
                          final double m = mVal is num ? mVal.toDouble() : (double.tryParse(mVal.toString()) ?? 0.0);
                          final Timestamp? ts = data['timestamp'] as Timestamp?;
                          final date = ts?.toDate() ?? DateTime.now();
                          final dateStr = DateFormat('dd.MM.yyyy - HH:mm').format(date);
                          final type = data['tip'] ?? 'Soğuk Süt';
                          final collector = data['sr'] ?? 'Toplayıcı';
                          final region = data['b'] ?? '';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: AppShadows.sm,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.water_drop_rounded, color: AppColors.primary600, size: 18),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(u, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Toplayıcı: $collector | Bölge: $region',
                                        style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray500),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$dateStr • $type',
                                        style: GoogleFonts.inter(fontSize: 9, color: AppColors.gray400),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${m.toStringAsFixed(1)} LT',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary700),
                                  ),
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
          ),
        ],
      ),
    );
  }
}
