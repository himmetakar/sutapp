import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../config/theme.dart';

class FirmaDuyuruGonderScreen extends StatefulWidget {
  const FirmaDuyuruGonderScreen({super.key});

  @override
  State<FirmaDuyuruGonderScreen> createState() => _FirmaDuyuruGonderScreenState();
}

class _FirmaDuyuruGonderScreenState extends State<FirmaDuyuruGonderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _targetDrivers = true;
  bool _targetProducers = true;
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _send(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_targetDrivers && !_targetProducers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir hedef grup seçin.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final user = auth.user;
      final firmaName = user?.displayName ?? 'Kayseri Çiftlik'; // fallback

      // Get firm message limits
      final firmSnap = await FirebaseFirestore.instance.collection('firmalar').where('ad', isEqualTo: firmaName).limit(1).get();
      if (firmSnap.docs.isNotEmpty) {
        final firmData = firmSnap.docs.first.data();
        final int maxMesaj = (firmData['maxMesaj'] as num?)?.toInt() ?? 20;
        final countSnap = await FirebaseFirestore.instance.collection('duyurular').where('senderFirma', isEqualTo: firmaName).get();
        if (countSnap.docs.length >= maxMesaj) {
          throw Exception('Firma maksimum mesaj limitine ($maxMesaj) ulaştınız. Daha fazla mesaj gönderemezsiniz.');
        }
      }

      await FirestoreService().sendAnnouncement(
        senderId: user?.uid ?? 'demo_firma',
        senderFirma: firmaName,
        baslik: _titleController.text.trim(),
        icerik: _contentController.text.trim(),
        targetDrivers: _targetDrivers,
        targetProducers: _targetProducers,
        isGlobal: false,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Duyuru başarıyla gönderildi.'),
            backgroundColor: AppColors.success,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          context.go('/firma');
        }
      }
    } catch (e) {
      if (mounted) {
        String errMsg = e.toString();
        if (errMsg.contains('Exception:')) {
          errMsg = errMsg.replaceAll('Exception:', '').trim();
        } else {
          errMsg = 'Duyuru gönderilirken hata oluştu: $errMsg';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errMsg),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 640;

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Yeni Duyuru Oluştur'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.gray200),
              ),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Firma Duyurusu Gönder',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Seçtiğiniz gruplardaki çalışan ve üreticilerinize anlık bildirim gider.',
                        style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.gray500),
                      ),
                      const SizedBox(height: 24),

                      // Title Field
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Duyuru Başlığı',
                          hintText: 'Örn: Süt Fiyatı Güncellemesi Hakkında',
                          prefixIcon: Icon(Icons.title_rounded, size: 18),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Lütfen bir başlık girin.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Content Field
                      TextFormField(
                        controller: _contentController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Duyuru İçeriği',
                          hintText: 'Duyuru detaylarını buraya yazın...',
                          alignLabelWithHint: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Lütfen duyuru içeriğini girin.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Target Groups Checkboxes
                      Text(
                        'Hedef Gruplar',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _targetDrivers,
                        onChanged: (val) => setState(() => _targetDrivers = val ?? false),
                        title: Text('Toplayıcılar', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500)),
                        subtitle: Text('Şirket bünyesindeki tüm aktif toplayıcılar', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.gray400)),
                        activeColor: AppColors.primary600,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: _targetProducers,
                        onChanged: (val) => setState(() => _targetProducers = val ?? false),
                        title: Text('Süt Üreticileri', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500)),
                        subtitle: Text('Firma altındaki tüm kayıtlı üreticiler', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.gray400)),
                        activeColor: AppColors.primary600,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _sending ? null : () => _send(auth),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Duyuruyu Yayınla',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDuyuruGonderScreen extends StatefulWidget {
  const AdminDuyuruGonderScreen({super.key});

  @override
  State<AdminDuyuruGonderScreen> createState() => _AdminDuyuruGonderScreenState();
}

class _AdminDuyuruGonderScreenState extends State<AdminDuyuruGonderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  bool _sendToAdmin = false;
  bool _sendToFirma = true;
  bool _sendToSurucu = true;
  bool _sendToUretici = true;
  bool _isPopUp = false;
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _send(AuthProvider auth) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_sendToAdmin && !_sendToFirma && !_sendToSurucu && !_sendToUretici) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen en az bir hedef rol seçin.')),
      );
      return;
    }

    setState(() => _sending = true);

    try {
      final List<String> targetRoles = [];
      if (_sendToAdmin) targetRoles.add('admin');
      if (_sendToFirma) targetRoles.add('firma');
      if (_sendToSurucu) targetRoles.add('surucu');
      if (_sendToUretici) targetRoles.add('uretici');

      final user = auth.user;

      await FirestoreService().sendAnnouncement(
        senderId: user?.uid ?? 'demo_admin',
        senderFirma: 'Sistem Yöneticisi',
        baslik: _titleController.text.trim(),
        icerik: _contentController.text.trim(),
        targetDrivers: false,
        targetProducers: false,
        isGlobal: true,
        targetRoles: targetRoles,
        isPopUp: _isPopUp,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sistem genel duyurusu başarıyla gönderildi.'),
            backgroundColor: AppColors.success,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.pop(context);
        } else {
          context.go('/admin');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Duyuru gönderilirken hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: AppBar(
        title: const Text('Yeni Sistem Duyurusu'),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: AppColors.gray200),
              ),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Sistem Genel Duyurusu',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tüm platform genelindeki kullanıcılara anlık sistem duyurusu gönderin.',
                        style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.gray500),
                      ),
                      const SizedBox(height: 24),

                      // Title Field
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Duyuru Başlığı',
                          hintText: 'Örn: Sistem Bakım Çalışması Bildirimi',
                          prefixIcon: Icon(Icons.title_rounded, size: 18),
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Lütfen bir başlık girin.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Content Field
                      TextFormField(
                        controller: _contentController,
                        maxLines: 5,
                        decoration: const InputDecoration(
                          labelText: 'Duyuru İçeriği',
                          hintText: 'Duyuru detaylarını buraya yazın...',
                          alignLabelWithHint: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Lütfen duyuru içeriğini girin.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Target Roles Checkboxes
                      Text(
                        'Hedef Roller',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gray700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CheckboxListTile(
                        value: _sendToFirma,
                        onChanged: (val) => setState(() => _sendToFirma = val ?? false),
                        title: Text('Firma Yöneticileri', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500)),
                        activeColor: AppColors.primary600,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: _sendToSurucu,
                        onChanged: (val) => setState(() => _sendToSurucu = val ?? false),
                        title: Text('Toplayıcılar', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500)),
                        activeColor: AppColors.primary600,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: _sendToUretici,
                        onChanged: (val) => setState(() => _sendToUretici = val ?? false),
                        title: Text('Süt Üreticileri', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500)),
                        activeColor: AppColors.primary600,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      CheckboxListTile(
                        value: _sendToAdmin,
                        onChanged: (val) => setState(() => _sendToAdmin = val ?? false),
                        title: Text('Sistem Yöneticileri (Admin)', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w500)),
                        activeColor: AppColors.primary600,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 12),
                      CheckboxListTile(
                        value: _isPopUp,
                        onChanged: (val) => setState(() => _isPopUp = val ?? false),
                        title: Text('Pop-up Reklam Bildirimi', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        subtitle: Text('Kullanıcılar uygulamaya girdiğinde tam ekran pop-up olarak gösterilir', style: GoogleFonts.inter(fontSize: 10.5, color: AppColors.gray400)),
                        activeColor: Colors.blueAccent,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _sending ? null : () => _send(auth),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary600,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: _sending
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Sistem Duyurusunu Yayınla',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Divider(height: 32),
                      Text(
                        'Gönderilen Sistem Duyuruları',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gray800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('duyurular')
                            .where('isGlobal', isEqualTo: true)
                            .orderBy('timestamp', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final docs = snapshot.data?.docs ?? [];
                          if (docs.isEmpty) {
                            return Center(
                              child: Text(
                                'Henüz sistem duyurusu gönderilmemiş.',
                                style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray400),
                              ),
                            );
                          }
                          return ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: docs.length,
                            separatorBuilder: (context, index) => const Divider(height: 24),
                            itemBuilder: (context, index) {
                              final data = docs[index].data() as Map<String, dynamic>;
                              final baslik = data['baslik'] ?? '';
                              final icerik = data['icerik'] ?? '';
                              final timestamp = data['timestamp'] as Timestamp?;
                              final dateStr = timestamp != null
                                  ? DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate())
                                  : '-';
                              final isPopUp = data['isPopUp'] as bool? ?? false;
                              final iletilen = data['iletilenCount'] ?? 0;
                              final iletilemeyen = data['iletilemeyenCount'] ?? 0;
                              final List<dynamic>? roles = data['targetRoles'] as List<dynamic>?;
                              final rolesStr = roles?.join(', ') ?? 'Hepsi';

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          baslik,
                                          style: GoogleFonts.inter(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.gray900,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        dateStr,
                                        style: GoogleFonts.inter(fontSize: 11, color: AppColors.gray400),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    icerik,
                                    style: GoogleFonts.inter(fontSize: 12, color: AppColors.gray600),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.gray100,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Roller: $rolesStr',
                                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.gray600, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                      if (isPopUp)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Pop-up Reklam',
                                            style: GoogleFonts.inter(fontSize: 10, color: Colors.blue.shade700, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.success.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'İletilen: $iletilen',
                                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.danger.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'İletilemeyen: $iletilemeyen',
                                          style: GoogleFonts.inter(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
