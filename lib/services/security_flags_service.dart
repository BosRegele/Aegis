import 'package:cloud_firestore/cloud_firestore.dart';

class SecurityFlags {
  final bool onboardingEnabled;
  final bool twoFactorEnabled;

  const SecurityFlags({
    required this.onboardingEnabled,
    required this.twoFactorEnabled,
  });

  static const defaults = SecurityFlags(
    onboardingEnabled: true,
    twoFactorEnabled: false,
  );

  factory SecurityFlags.fromMap(Map<String, dynamic>? map) {
    return SecurityFlags(
      onboardingEnabled: map?['onboardingEnabled'] as bool? ?? true,
      twoFactorEnabled: map?['twoFactorEnabled'] as bool? ?? false,
    );
  }
}

class SecurityFlagsService {
  SecurityFlagsService._();
  static const Duration _requestTimeout = Duration(seconds: 12);

  static final _docRef = FirebaseFirestore.instance
      .collection('app_settings')
      .doc('security');

  static Stream<SecurityFlags> watch() {
    return _docRef
        .snapshots()
        // Skip "document not found" snapshots that come from an empty local
        // cache on first load.  Wait for the server to confirm the real state.
        // Without this, SecurityFlags.fromMap(null) → defaults (both = true)
        // causes a brief OnboardingPage/TwoFactorPage flash before real data.
        .where((snap) => snap.exists || !snap.metadata.isFromCache)
        .map((snapshot) => SecurityFlags.fromMap(snapshot.data()));
  }

  static Future<SecurityFlags> getOnce() async {
    final snapshot = await _docRef.get().timeout(_requestTimeout);
    return SecurityFlags.fromMap(snapshot.data());
  }

  static Future<void> setOnboardingEnabled(bool enabled) {
    return _docRef.set({
      'onboardingEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> setTwoFactorEnabled(bool enabled) {
    return _docRef.set({
      'twoFactorEnabled': enabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
