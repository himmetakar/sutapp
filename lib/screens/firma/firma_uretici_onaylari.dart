import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class FirmaUreticiOnaylariScreen extends StatefulWidget {
  const FirmaUreticiOnaylariScreen({super.key});

  @override
  State<FirmaUreticiOnaylariScreen> createState() => _FirmaUreticiOnaylariScreenState();
}

class _FirmaUreticiOnaylariScreenState extends State<FirmaUreticiOnaylariScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirestoreService _firestoreService = FirestoreService();

  Future<void> _handleApprove(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? '';
    final phone = data['phone'] ?? '';
    final bolge = data['bolge'] ?? '';
    final lastMilkType = data['lastMilkType'] ?? 'Soğuk Süt';
    final customerType = data['customerType'] ?? 'sut';
    final firma = data['firma'] ?? '';

    try {
      // 1. Add producer to ureticiler collection
      await _firestoreService.addProducer(
        name: name,
        phone: phone,
        group: 'Genel',
        bolge: bolge,
        avg: 30.0,
        firma: firma,
        lastMilkType: lastMilkType,
        customerType: customerType,
      );

      // 2. Update status to Onaylandı
      await doc.reference.update({'status': 'Onaylandı'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name üretici kaydı onaylandı ve eklendi!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  Future<void> _handleReject(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>;
    final name = data['name'] ?? '';

    try {
      // Update status to Reddedildi
      await doc.reference.update({'status': 'Reddedildi'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$name üretici kayıt talebi reddedildi.'), backgroundColor: AppColors.warning),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: Text(
          'Yeni Üretici Onayları',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('uretici_onaylari')
            .where('firma', isEqualTo: currentFirmaName)
            .where('status', isEqualTo: 'Bekliyor')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 48, color: AppColors.gray300),
                  const SizedBox(height: 12),
                  Text(
                    'Kabul bekleyen üretici kaydı bulunmuyor.',
                    style: GoogleFonts.inter(color: AppColors.gray500),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['name'] ?? '';
              final phone = data['phone'] ?? '';
              final bolge = data['bolge'] ?? '';
              final toplayici = data['toplayici'] ?? 'Bilinmeyen Sürücü';
              final lastMilkType = data['lastMilkType'] ?? 'Soğuk Süt';
              final customerType = data['customerType'] ?? 'sut';
              final isYem = customerType == 'yem';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isYem ? Colors.amber[50]!.withOpacity(0.4) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isYem ? Colors.amber[200]! : AppColors.gray200,
                  ),
                  boxShadow: AppShadows.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.gray800,
                            ),
                          ),
                        ),
                         StatusBadge.info(
                          isYem ? 'Yem Müşterisi' : 'Süt Üreticisi',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.phone_android_rounded, size: 14, color: AppColors.gray400),
                        const SizedBox(width: 6),
                        Text(phone, style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                        const SizedBox(width: 16),
                        const Icon(Icons.location_on_rounded, size: 14, color: AppColors.gray400),
                        const SizedBox(width: 6),
                        Text(bolge, style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          lastMilkType == 'Sıcak Süt' ? Icons.whatshot : Icons.ac_unit,
                          size: 14,
                          color: lastMilkType == 'Sıcak Süt' ? Colors.red : Colors.blue,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          lastMilkType,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: lastMilkType == 'Sıcak Süt' ? Colors.red[700] : Colors.blue[700],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: AppColors.gray200),
                    Row(
                      children: [
                        const Icon(Icons.local_shipping_rounded, size: 14, color: AppColors.primary600),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Ekleyen: $toplayici (Toplayıcı)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.gray500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _handleReject(doc),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.danger),
                              foregroundColor: AppColors.danger,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('Reddet'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _handleApprove(doc),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              elevation: 0,
                            ),
                            child: const Text('Onayla ve Ekle'),
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
    );
  }
}
