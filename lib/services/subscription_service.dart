import 'package:cloud_firestore/cloud_firestore.dart';

const String kContactPhone = '0536 259 0990';

class SubscriptionStatus {
  final bool isExpired;
  final bool isWarning; // daysLeft <= 7
  final int daysLeft;
  final String abonelikTipi; // 'deneme' | 'standart' | ''

  const SubscriptionStatus({
    required this.isExpired,
    required this.isWarning,
    required this.daysLeft,
    required this.abonelikTipi,
  });

  /// No subscription data found → treat as expired
  factory SubscriptionStatus.unknown() => const SubscriptionStatus(
        isExpired: true,
        isWarning: true,
        daysLeft: 0,
        abonelikTipi: '',
      );

  /// Perfectly active
  factory SubscriptionStatus.active(int daysLeft, String tip) =>
      SubscriptionStatus(
        isExpired: false,
        isWarning: daysLeft <= 7,
        daysLeft: daysLeft,
        abonelikTipi: tip,
      );
}

class SubscriptionService {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  // Simple in-memory cache: firmaName → (status, fetchedAt)
  final Map<String, (SubscriptionStatus, DateTime)> _cache = {};
  static const _cacheDuration = Duration(minutes: 5);

  /// Returns subscription status for a given firma name.
  Future<SubscriptionStatus> checkFirma(String firmaName) async {
    if (firmaName.isEmpty) return SubscriptionStatus.unknown();

    // Cache hit
    final cached = _cache[firmaName];
    if (cached != null &&
        DateTime.now().difference(cached.$2) < _cacheDuration) {
      return cached.$1;
    }

    try {
      final snap = await FirebaseFirestore.instance
          .collection('firmalar')
          .where('ad', isEqualTo: firmaName)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return SubscriptionStatus.unknown();

      final data = snap.docs.first.data();
      final Timestamp? expiryTs = data['abonelikBitis'] as Timestamp?;
      final String tip = data['abonelikTipi'] as String? ?? '';

      if (expiryTs == null) return SubscriptionStatus.unknown();

      final expiry = expiryTs.toDate();
      final now = DateTime.now();
      final daysLeft = expiry.difference(now).inDays;
      final isExpired = now.isAfter(expiry);

      final status = isExpired
          ? SubscriptionStatus(
              isExpired: true,
              isWarning: true,
              daysLeft: daysLeft,
              abonelikTipi: tip,
            )
          : SubscriptionStatus.active(daysLeft, tip);

      _cache[firmaName] = (status, DateTime.now());
      return status;
    } catch (e) {
      // On error, don't block the user — return active
      return const SubscriptionStatus(
        isExpired: false,
        isWarning: false,
        daysLeft: 999,
        abonelikTipi: '',
      );
    }
  }

  /// Invalidate cache for a firma (call after admin updates subscription)
  void invalidate(String firmaName) => _cache.remove(firmaName);
}
