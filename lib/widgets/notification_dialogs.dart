import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../services/firestore_service.dart';
import '../models/user_model.dart';
import '../config/theme.dart';

class NotificationDrawerDialog extends StatelessWidget {
  final String userId;
  final UserRole role;
  final BuildContext parentContext;

  const NotificationDrawerDialog({
    super.key,
    required this.userId,
    required this.role,
    required this.parentContext,
  });

  static void show(BuildContext context, String userId, UserRole role) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Bildirimler',
      barrierColor: Colors.black.withOpacity(0.4),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: NotificationDrawerDialog(userId: userId, role: role, parentContext: context),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        final slide = Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic));

        return SlideTransition(
          position: slide,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();
    final width = MediaQuery.of(context).size.width;
    final isDesktop = width >= 640;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: isDesktop ? 400 : width * 0.85,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.notifications_rounded, color: AppColors.primary600, size: 22),
                    const SizedBox(width: 10),
                    Text(
                      'Bildirimler',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.gray800,
                      ),
                    ),
                    const Spacer(),
                    if (role == UserRole.admin || role == UserRole.firma)
                      IconButton(
                        icon: const Icon(Icons.campaign_outlined, color: AppColors.primary600, size: 24),
                        onPressed: () {
                          Navigator.pop(context);
                          if (role == UserRole.admin) {
                            parentContext.push('/admin/duyuru-gonder');
                          } else {
                            parentContext.push('/firma/duyuru-gonder');
                          }
                        },
                        tooltip: 'Duyuru Gönder',
                      ),
                    // Settings Gear Icon
                    IconButton(
                      icon: const Icon(Icons.settings_outlined, color: AppColors.gray500),
                      onPressed: () {
                        Navigator.pop(context);
                        NotificationSettingsDialog.show(parentContext, userId, role);
                      },
                      tooltip: 'Bildirim Ayarları',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.gray500),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: AppColors.gray100),

              // Notification List Stream
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: firestoreService.getNotificationsStream(userId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      );
                    }

                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.primary50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.notifications_none_rounded,
                              size: 40,
                              color: AppColors.primary400,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Hiç bildiriminiz yok',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.gray700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Yeni bildirimleriniz burada görünecek.',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.gray400,
                            ),
                          ),
                        ],
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: docs.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, thickness: 1, color: AppColors.gray100),
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final isRead = data['read'] as bool? ?? false;
                        final timestamp = data['timestamp'] as Timestamp?;
                        final title = data['baslik'] as String? ?? 'Bildirim';
                        final body = data['icerik'] as String? ?? '';
                        final type = data['type'] as String? ?? 'genel';

                        IconData iconData = Icons.info_outline_rounded;
                        Color iconColor = AppColors.primary600;
                        Color iconBgColor = AppColors.primary50;

                        if (type == 'sut_alim') {
                          iconData = Icons.water_drop_rounded;
                          iconColor = const Color(0xFF008AAE);
                          iconBgColor = const Color(0xFFE0F7FA);
                        } else if (type == 'depo_aktarim') {
                          iconData = Icons.local_shipping_rounded;
                          iconColor = AppColors.success;
                          iconBgColor = AppColors.successLight;
                        } else if (type == 'firma_bildirim') {
                          iconData = Icons.business_rounded;
                          iconColor = Colors.orange;
                          iconBgColor = const Color(0xFFFFF3E0);
                        } else if (type == 'admin_bildirim') {
                          iconData = Icons.admin_panel_settings_rounded;
                          iconColor = const Color(0xFF7C3AED);
                          iconBgColor = const Color(0xFFF3E5F5);
                        }

                        String dateStr = '';
                        if (timestamp != null) {
                          final dt = timestamp.toDate();
                          dateStr = DateFormat('dd.MM.yyyy HH:mm').format(dt);
                        }

                        return InkWell(
                          onTap: () {
                            if (!isRead) {
                              firestoreService.markNotificationRead(doc.id);
                            }
                          },
                          child: Container(
                            color: isRead ? Colors.transparent : AppColors.primary50.withOpacity(0.3),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: iconBgColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(iconData, color: iconColor, size: 18),
                                ),
                                const SizedBox(width: 12),
                                // Content
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              title,
                                              style: GoogleFonts.inter(
                                                fontSize: 13,
                                                fontWeight: isRead ? FontWeight.w600 : FontWeight.w700,
                                                color: AppColors.gray800,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (!isRead)
                                            Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: AppColors.primary600,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        body,
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: isRead ? FontWeight.w400 : FontWeight.w500,
                                          color: isRead ? AppColors.gray500 : AppColors.gray700,
                                          height: 1.35,
                                        ),
                                      ),
                                      if (dateStr.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          dateStr,
                                          style: GoogleFonts.inter(
                                            fontSize: 9.5,
                                            color: AppColors.gray400,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),

              // Actions Bottom Bar
              const Divider(height: 1, thickness: 1, color: AppColors.gray100),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => firestoreService.markAllNotificationsRead(userId),
                      child: Text(
                        'Tümünü Okundu İşaretle',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => firestoreService.clearAllNotifications(userId),
                      child: Text(
                        'Temizle',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationSettingsDialog extends StatefulWidget {
  final String userId;
  final UserRole role;

  const NotificationSettingsDialog({
    super.key,
    required this.userId,
    required this.role,
  });

  static void show(BuildContext context, String userId, UserRole role) {
    showDialog(
      context: context,
      builder: (context) => NotificationSettingsDialog(userId: userId, role: role),
    );
  }

  @override
  State<NotificationSettingsDialog> createState() => _NotificationSettingsDialogState();
}

class _NotificationSettingsDialogState extends State<NotificationSettingsDialog> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _loading = true;
  Map<String, bool> _settings = {};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.userId).get();
      Map<String, bool> loadedSettings = {};
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('notificationSettings')) {
          final sMap = data['notificationSettings'] as Map<String, dynamic>;
          sMap.forEach((key, value) {
            if (value is bool) {
              loadedSettings[key] = value;
            }
          });
        }
      }

      // Initialize default toggles based on role if missing
      final defaultKeys = _getKeysForRole(widget.role);
      for (var key in defaultKeys) {
        loadedSettings.putIfAbsent(key, () => true);
      }

      if (!mounted) return;
      setState(() {
        _settings = loadedSettings;
        _loading = false;
      });
    } catch (e) {
      print('Bildirim ayarları yüklenemedi: $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<String> _getKeysForRole(UserRole role) {
    switch (role) {
      case UserRole.uretici:
        return ['sut_alim', 'firma_bildirim', 'admin_bildirim'];
      case UserRole.surucu:
        return ['depo_aktarim', 'firma_bildirim', 'admin_bildirim'];
      case UserRole.firma:
        return ['sut_alim', 'depo_aktarim', 'admin_bildirim'];
      case UserRole.admin:
        return ['admin_bildirim'];
    }
  }

  String _getLabelForType(String type) {
    switch (type) {
      case 'sut_alim':
        return 'Süt Alım Bildirimleri';
      case 'depo_aktarim':
        return 'Depo Teslimat Bildirimleri';
      case 'firma_bildirim':
        return 'Firma Duyuruları';
      case 'admin_bildirim':
        return 'Sistem / Admin Duyuruları';
      default:
        return type;
    }
  }

  String _getDescForType(String type) {
    switch (type) {
      case 'sut_alim':
        return 'Süt araçları süt topladığında gelecek bildirimler.';
      case 'depo_aktarim':
        return 'Araçtaki süt depoya aktarıldığında toplayıcıya giden bildirimler.';
      case 'firma_bildirim':
        return 'Üyesi olduğunuz süt toplama firmasından gelen duyurular.';
      case 'admin_bildirim':
        return 'Sistem yöneticilerinden gelen önemli duyurular.';
      default:
        return '';
    }
  }

  Future<void> _toggleSetting(String type, bool value) async {
    setState(() {
      _settings[type] = value;
    });
    try {
      await _firestoreService.updateNotificationSettings(widget.userId, _settings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ayarlar kaydedilirken hata oluştu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.settings_outlined, color: AppColors.primary600, size: 22),
          const SizedBox(width: 10),
          Text(
            'Bildirim Ayarları',
            style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      content: SizedBox(
        width: 320,
        child: _loading
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: _settings.keys.map((key) {
                  return SwitchListTile(
                    value: _settings[key] ?? true,
                    onChanged: (val) => _toggleSetting(key, val),
                    title: Text(
                      _getLabelForType(key),
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.gray800,
                      ),
                    ),
                    subtitle: Text(
                      _getDescForType(key),
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        color: AppColors.gray400,
                      ),
                    ),
                    activeColor: AppColors.primary600,
                  );
                }).toList(),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Kapat',
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.primary600,
            ),
          ),
        ),
      ],
    );
  }
}
