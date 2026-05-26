import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class TankListesiScreen extends StatefulWidget {
  const TankListesiScreen({super.key});

  @override
  State<TankListesiScreen> createState() => _TankListesiScreenState();
}

class _TankListesiScreenState extends State<TankListesiScreen> {
  String _searchQuery = '';
  String _selectedType = 'Tümü'; // Tümü, Normal, Merkez
  String _selectedStatus = 'Tümü'; // Tümü, Aktif, Bakım, Pasif

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma'),
        ),
        title: Text(
          'Tank Listesi',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        actions: [
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
      body: Column(
        children: [
          // Search & Filters Panel
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Search Field
                TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val.toLowerCase();
                    });
                  },
                  style: GoogleFonts.inter(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Tank adı, kod veya araç ara...',
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
                const SizedBox(height: 12),
                
                // First Row Filters (Type)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Tümü', 'Normal', 'Merkez'].map((type) {
                      final isSelected = _selectedType == type;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedType = type),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF3B82F6) : AppColors.gray100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            type,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.gray600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Second Row Filters (Status)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ['Tümü', 'Aktif', 'Bakım', 'Pasif'].map((status) {
                      final isSelected = _selectedStatus == status;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedStatus = status),
                        child: Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF3B82F6) : AppColors.gray100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : AppColors.gray600,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          
          // Tank List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('tanklar')
                  .where('firma', isEqualTo: currentFirmaName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                var docs = snapshot.data?.docs ?? [];

                // Local filter by search and categories
                var filtered = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['ad'] ?? '').toString().toLowerCase();
                  final code = (data['kod'] ?? '').toString().toLowerCase();
                  final vehicle = (data['arac'] ?? '').toString().toLowerCase();
                  final typeVal = data['tip'] ?? 'merkez'; // arac/merkez
                  final statusVal = data['durum'] ?? 'aktif'; // aktif/bakim/pasif

                  // Search match
                  final matchesSearch = name.contains(_searchQuery) ||
                      code.contains(_searchQuery) ||
                      vehicle.contains(_searchQuery);

                  // Type filter match
                  bool matchesType = true;
                  if (_selectedType == 'Normal') {
                    matchesType = (typeVal == 'arac');
                  } else if (_selectedType == 'Merkez') {
                    matchesType = (typeVal == 'merkez');
                  }

                  // Status filter match
                  bool matchesStatus = true;
                  if (_selectedStatus == 'Aktif') {
                    matchesStatus = (statusVal == 'aktif');
                  } else if (_selectedStatus == 'Bakım') {
                    matchesStatus = (statusVal == 'bakim');
                  } else if (_selectedStatus == 'Pasif') {
                    matchesStatus = (statusVal == 'pasif');
                  }

                  return matchesSearch && matchesType && matchesStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'Aramaya uygun tank bulunamadı.',
                        style: GoogleFonts.inter(color: AppColors.gray400),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final String id = doc.id;
                    final String name = data['ad'] ?? '';
                    final String code = data['kod'] ?? 'TANK-${index + 1}';
                    final double kap = (data['kap'] as num?)?.toDouble() ?? 2000.0;
                    final String typeVal = data['tip'] ?? 'merkez';
                    final String vehicle = data['arac'] ?? '';
                    final String statusVal = data['durum'] ?? 'aktif';

                    final isMerkez = typeVal == 'merkez';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: AppShadows.sm,
                        border: Border.all(color: AppColors.gray200),
                      ),
                      child: Row(
                        children: [
                          // Left Icon
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.storage_rounded,
                                color: Color(0xFF3B82F6),
                                size: 24,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          
                          // Center Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.gray800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  code,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.gray400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      'Kapasite: ${kap.toStringAsFixed(0)}L',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: AppColors.gray500,
                                      ),
                                    ),
                                    if (!isMerkez && vehicle.isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Text(
                                        'Araç: $vehicle',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: AppColors.gray500,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Right Badges
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              // Type Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isMerkez ? const Color(0xFFFAF5FF) : const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isMerkez ? Icons.business_rounded : Icons.local_shipping_outlined,
                                      size: 11,
                                      color: isMerkez ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      isMerkez ? 'Merkez' : 'Normal',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: isMerkez ? const Color(0xFF8B5CF6) : const Color(0xFF3B82F6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              
                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: statusVal == 'aktif'
                                        ? const Color(0xFF10B981)
                                        : statusVal == 'bakim'
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFEF4444),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  statusVal == 'aktif'
                                      ? 'Aktif'
                                      : statusVal == 'bakim'
                                          ? 'Bakımda'
                                          : 'Pasif',
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: statusVal == 'aktif'
                                        ? const Color(0xFF10B981)
                                        : statusVal == 'bakim'
                                            ? const Color(0xFFF59E0B)
                                            : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ],
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
