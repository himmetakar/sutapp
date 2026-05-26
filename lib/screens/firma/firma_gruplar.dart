import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';

class FirmaGruplarScreen extends StatefulWidget {
  const FirmaGruplarScreen({super.key});

  @override
  State<FirmaGruplarScreen> createState() => _FirmaGruplarScreenState();
}

class _FirmaGruplarScreenState extends State<FirmaGruplarScreen> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _showAddGroupDialog() {
    final nameCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Yeni Grup Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Grup / Köy Adı', hintText: 'Örn: İshaklı Köyü'),
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

              await _db.collection('musteri_gruplari').add({
                'ad': name,
                'firma': currentFirmaName,
                'timestamp': FieldValue.serverTimestamp(),
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Grup başarıyla eklendi!'), backgroundColor: AppColors.success),
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

  void _showEditGroupDialog(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final nameCtrl = TextEditingController(text: data['ad'] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Grubu Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Grup / Köy Adı'),
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
                const SnackBar(content: Text('Grup başarıyla güncellendi!'), backgroundColor: AppColors.success),
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

  void _deleteGroup(DocumentSnapshot doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Grubu Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        content: const Text('Bu grubu silmek istediğinize emin misiniz? Bu gruptaki müşteriler gruptan çıkarılmayacaktır fakat grubun kendisi silinecektir.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () async {
              await doc.reference.delete();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Grup silindi!'), backgroundColor: AppColors.success),
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
        title: Text('Müşteri Grupları', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/firma/ureticiler'),
        ),
      ),
      backgroundColor: AppColors.gray50,
      floatingActionButton: AppFab(
        icon: Icons.add_rounded,
        label: 'Grup Ekle',
        onTap: _showAddGroupDialog,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _db
            .collection('musteri_gruplari')
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
                'Kayıtlı grup bulunamadı.',
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
                        child: Icon(Icons.folder_shared_rounded, color: AppColors.primary600, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          // Count how many producers are in this group
                          StreamBuilder<QuerySnapshot>(
                            stream: _db
                                .collection('ureticiler')
                                .where('firmalar', arrayContains: currentFirmaName)
                                .where('group', isEqualTo: name)
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
                      onPressed: () => _showEditGroupDialog(doc),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_rounded, color: AppColors.danger, size: 20),
                      onPressed: () => _deleteGroup(doc),
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
