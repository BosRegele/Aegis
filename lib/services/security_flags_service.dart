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
    twoFactorEnabled: true,
  );

  factory SecurityFlags.fromMap(Map<String, dynamic>? map) {
    return SecurityFlags(
      onboardingEnabled: map?['onboardingEnabled'] as bool? ?? true,
      twoFactorEnabled: map?['twoFactorEnabled'] as bool? ?? true,
    );
  }
}

class SecurityFlagsService {
  SecurityFlagsService._();

  static final _docRef = FirebaseFirestore.instance
      .collection('app_settings')
      .doc('security');

  static Stream<SecurityFlags> watch() {
    return _docRef.snapshots().map(
      (snapshot) => SecurityFlags.fromMap(snapshot.data()),
    );
  }

  static Future<SecurityFlags> getOnce() async {
    final snapshot = await _docRef.get();
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
