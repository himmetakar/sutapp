import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaBirliklerScreen extends StatefulWidget {
  const FirmaBirliklerScreen({super.key});

  @override
  State<FirmaBirliklerScreen> createState() => _FirmaBirliklerScreenState();
}

class _FirmaBirliklerScreenState extends State<FirmaBirliklerScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _showAddUnionDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Yeni Birlik Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Birlik Adı', hintText: 'Örn: Damızlık Sığır Yetiştiricileri Birliği'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final currentFirmaName = auth.user?.displayName ?? '';
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              await _db.collection('birlikler').add({
                'ad': name,
                'firma': currentFirmaName,
                'timestamp': FieldValue.serverTimestamp(),
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Birlik başarıyla eklendi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Ekle'),
          ),
        ],
      ),
    );
  }

  void _showEditUnionDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['ad'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Birliği Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Birlik Adı'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;

              await doc.reference.update({'ad': name});
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Birlik başarıyla güncellendi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Güncelle'),
          ),
        ],
      ),
    );
  }

  void _deleteUnion(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Birliği Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu birliği silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Birlik silindi!'), backgroundColor: AppColors.success),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text('Birlik Kaydı', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/ureticiler'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      floatingActionButton: AppFab(
        icon: Icons.add_rounded,
        label: 'Birlik Ekle',
        onTap: _showAddUnionDialog,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('birlikler')
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
                'Kayıtlı birlik bulunamadı.',
                style: GoogleFonts.inter(color: AppColors.gray500),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final name = data['ad'] ?? '';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: AppShadows.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                        child: Icon(Icons.account_balance_rounded, color: AppColors.primary600, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          // Count how many producers are registered under this union
                          StreamBuilder<QuerySnapshot>(
                            stream: _db
                                .collection('ureticiler')
                                .where('firmalar', arrayContains: currentFirmaName)
                                .where('birlik', isEqualTo: name)
                                .snapshots(),
                            builder: (context, prodSnap) {
                              final count = prodSnap.data?.docs.length ?? 0;
                              return Text(
                                '$count Müşteri',
                                style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppColors.gray500, size: 20),
                      onPressed: () => _showEditUnionDialog(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: AppColors.danger, size: 20),
                      onPressed: () => _deleteUnion(doc),
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
