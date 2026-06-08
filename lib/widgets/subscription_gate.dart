import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../models/user_model.dart';
import '../services/subscription_service.dart';

/// Wraps any content and enforces subscription rules for firma & surucu roles.
/// - Üretici: always passes through unchanged.
/// - Firma / Surucu: checks Firestore subscription and shows warning/lock.
class SubscriptionGate extends StatefulWidget {
  final Widget child;
  const SubscriptionGate({super.key, required this.child});

  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate> {
  SubscriptionStatus? _status;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final auth = context.read<AuthProvider>();
    final role = auth.user?.role;

    // Üretici & admin are always free — skip
    if (role == UserRole.uretici || role == UserRole.admin) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final firmaName = auth.user?.displayName ?? '';

    // Demo users are never locked
    if (auth.user?.uid.startsWith('demo_') == true) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final status = await SubscriptionService().checkFirma(
      role == UserRole.surucu ? _getSurucuFirma(auth) : firmaName,
    );


    if (mounted) {
      setState(() {
        _status = status;
        _loading = false;
      });
    }
  }

  String _getSurucuFirma(AuthProvider auth) {
    // Surucu's firma is stored in firmaName (mapped to mahalleKoy in model)
    // Try firmaName field first
    final user = auth.user;
    if (user == null) return '';
    // firmaName is not directly on AppUser model, but stored in Firestore.
    // We use mahalleKoy as a proxy since that maps to `group`/`firmaName` for surucu.
    // Better: use displayName for firma lookup via surucu doc.
    // For now we use the stored firmaName from the provider.
    return user.mahalleKoy ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return widget.child;

    final auth = context.read<AuthProvider>();
    final role = auth.user?.role;

    // Exempt roles
    if (role == UserRole.uretici || role == UserRole.admin || _status == null) {
      return widget.child;
    }

    return Stack(
      children: [
        // Always render the child so the background is visible
        widget.child,

        // Warning Banner (7 days or less remaining)
        if (_status!.isWarning && !_status!.isExpired)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _WarningBanner(daysLeft: _status!.daysLeft),
          ),

        // Lock Overlay (expired)
        if (_status!.isExpired)
          Positioned.fill(
            child: _LockOverlay(),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Warning Banner
// ─────────────────────────────────────────────
class _WarningBanner extends StatelessWidget {
  final int daysLeft;
  const _WarningBanner({required this.daysLeft});

  @override
  Widget build(BuildContext context) {
    final msg = daysLeft <= 0
        ? 'Aboneliğiniz bugün sona eriyor!'
        : 'Abonelik süreniz $daysLeft gün içinde doluyor.';

    return Material(
      color: const Color(0xFFF59E0B),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      msg,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Aboneliğe devam etmek için iletişime geçin: $kContactPhone',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: kContactPhone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Numara kopyalandı: $kContactPhone')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ara',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Lock Overlay
// ─────────────────────────────────────────────
class _LockOverlay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AbsorbPointer(
      absorbing: true,
      child: Container(
        color: Colors.black.withOpacity(0.82),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFEF4444).withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFFEF4444),
                    size: 38,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Aboneliğiniz Sona Erdi',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  'Hesabınız şu an kilitlidir. Hizmetlerimize devam etmek için lütfen bizimle iletişime geçin.',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.75),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                // Phone button
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(const ClipboardData(text: kContactPhone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Numara kopyalandı: $kContactPhone'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2563EB).withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone_rounded, color: Colors.white, size: 18),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'İletişime Geçin',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              kContactPhone,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Logout button
                TextButton(
                  onPressed: () {
                    final auth = context.read<AuthProvider>();
                    auth.logout();
                  },
                  child: Text(
                    'Çıkış Yap',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
