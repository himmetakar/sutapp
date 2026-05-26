import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../config/theme.dart';
import '../../widgets/common_widgets.dart';
import '../../services/firestore_service.dart';

class FirmaSuruculer extends StatefulWidget {
  const FirmaSuruculer({super.key});

  @override
  State<FirmaSuruculer> createState() => _FirmaSuruculerState();
}

class _FirmaSuruculerState extends State<FirmaSuruculer> {
  final _firestoreService = FirestoreService();

  void _showAddDriverDialog() {
    final adCtrl = TextEditingController();
    final soyadCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final tcCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Yeni Toplayıcı Ekle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adCtrl,
                decoration: const InputDecoration(labelText: 'Ad', hintText: 'Örn: Ramazan'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: soyadCtrl,
                decoration: const InputDecoration(labelText: 'Soyad', hintText: 'Örn: Şen'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: telCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon', hintText: 'Örn: 0530 123 4567'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-posta (Opsiyonel)', hintText: 'Örn: ramazan@sutapp.com'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tcCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'TC Kimlik No (Gizli)', hintText: 'Örn: 11 haneli TC'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('İptal', style: GoogleFonts.inter(color: AppColors.gray500))),
          ElevatedButton(
            onPressed: () async {
              if (adCtrl.text.isEmpty || soyadCtrl.text.isEmpty || telCtrl.text.isEmpty) return;
              
              final tcObfuscated = tcCtrl.text.length >= 9
                  ? '${tcCtrl.text.substring(0, 9)}**'
                  : '*********';
                  
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final currentFirmaName = auth.user?.displayName ?? '';

              await _firestoreService.addDriver({
                'ad': adCtrl.text,
                'soyad': soyadCtrl.text,
                'tel': telCtrl.text,
                'email': emailCtrl.text,
                'tc': tcObfuscated,
                'uretici': 0,
                'active': true,
                'firma': currentFirmaName,
              });

              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Yeni toplayıcı başarıyla eklendi!'), backgroundColor: AppColors.success),
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

  void _showDriverDetailsDialog(DocumentSnapshot doc) {
    final s = doc.data() as Map<String, dynamic>;
    final ad = s['ad'] ?? '';
    final soyad = s['soyad'] ?? '';
    final tel = s['tel'] ?? '';
    final email = s['email'] ?? '';
    final ureticiSayisi = s['uretici'] ?? 0;

    bool canAddCustomer = s['canAddCustomer'] ?? true;
    bool canEditCustomer = s['canEditCustomer'] ?? true;
    bool canCreateOrder = s['canCreateOrder'] ?? true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Toplayıcı Profili & Yetkileri', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                      child: Center(
                        child: Text(
                          '${ad.isNotEmpty ? ad[0] : ''}${soyad.isNotEmpty ? soyad[0] : ''}',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$ad $soyad', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold)),
                          Text(tel, style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray500)),
                          if (email.isNotEmpty)
                            Text(email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                StatusBadge.info('$ureticiSayisi üretici atanmış'),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 12),
                Text('Toplayıcı İzinleri', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.gray700)),
                const SizedBox(height: 10),

                SwitchListTile(
                  title: Text('Müşteri Ekleyebilir', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text('Toplayıcı panelinden yeni üretici kaydı oluşturma izni.', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                  value: canAddCustomer,
                  activeColor: AppColors.primary600,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) async {
                    setDialogState(() => canAddCustomer = val);
                    await doc.reference.update({'canAddCustomer': val});
                  },
                ),
                SwitchListTile(
                  title: Text('Müşteri Düzenleyebilir', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text('Müşteri bilgilerini düzenleme izni.', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                  value: canEditCustomer,
                  activeColor: AppColors.primary600,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) async {
                    setDialogState(() => canEditCustomer = val);
                    await doc.reference.update({'canEditCustomer': val});
                  },
                ),
                SwitchListTile(
                  title: Text('Sipariş Oluşturma İzni', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
                  subtitle: Text('Toplayıcının sipariş oluşturma yetkisi.', style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray400)),
                  value: canCreateOrder,
                  activeColor: AppColors.primary600,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) async {
                    setDialogState(() => canCreateOrder = val);
                    await doc.reference.update({'canCreateOrder': val});
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Kapat', style: GoogleFonts.inter(color: AppColors.primary600, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentFirmaName = auth.user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.gray50,
      floatingActionButton: AppFab(
        icon: Icons.person_add_rounded,
        label: 'Toplayıcı Ekle',
        onTap: _showAddDriverDialog,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestoreService.getDriversStream(firma: currentFirmaName),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Hata: ${snapshot.error}'));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'Sistemde kayıtlı toplayıcı bulunmuyor.',
                style: GoogleFonts.inter(color: AppColors.gray500),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final doc = docs[i];
              final s = doc.data() as Map<String, dynamic>;
              final active = s['active'] as bool? ?? true;
              final ad = s['ad'] ?? '';
              final soyad = s['soyad'] ?? '';
              final tel = s['tel'] ?? '';
              final email = s['email'] ?? '';
              final ureticiSayisi = s['uretici'] ?? 0;

              return GestureDetector(
                onTap: () => _showDriverDetailsDialog(doc),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), boxShadow: AppShadows.sm),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        gradient: active ? AppColors.primaryGradient : null,
                        color: active ? null : AppColors.gray200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${ad.isNotEmpty ? ad[0] : ''}${soyad.isNotEmpty ? soyad[0] : ''}',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : AppColors.gray500),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text('$ad $soyad', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 6),
                        active ? StatusBadge.active() : StatusBadge.inactive(),
                      ]),
                      const SizedBox(height: 5),
                      Row(children: [
                        const Icon(Icons.phone_rounded, size: 11, color: AppColors.gray400),
                        const SizedBox(width: 4),
                        Text(tel, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                      ]),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(children: [
                          const Icon(Icons.email_rounded, size: 11, color: AppColors.gray400),
                          const SizedBox(width: 4),
                          Text(email, style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray500)),
                        ]),
                      ],
                      const SizedBox(height: 6),
                      StatusBadge.info('$ureticiSayisi üretici atanmış'),
                    ])),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
