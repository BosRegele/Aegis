import 'package:flutter/foundation.dart';

class AppSession {
  static String? uid;
  static String? username;
  static String? role;
  static String? fullName;
  static String? classId;
  static Map<String, dynamic>? bootstrapUserData;

  // Reactive flag — ValueListenableBuilder in main.dart listens to this.
  // Must NOT be reset by calling code except via AppSession.clear().
  static final ValueNotifier<bool> twoFactorNotifier = ValueNotifier(false);
  static bool get twoFactorVerified => twoFactorNotifier.value;
  static set twoFactorVerified(bool v) => twoFactorNotifier.value = v;

  static bool get isAdmin => role == 'admin';

  static void setUser({
    required String uidValue,
    required String usernameValue,
    required String roleValue,
    String? fullNameValue,
    String? classIdValue,
  }) {
    uid = uidValue;
    username = usernameValue;
    role = roleValue;
    fullName = fullNameValue;
    classId = classIdValue;
  }

  static void setBootstrapUserData({
    required String uidValue,
    required Map<String, dynamic> data,
  }) {
    uid = uidValue;
    bootstrapUserData = Map<String, dynamic>.from(data);
  }

  static void clear() {
    uid = null;
    username = null;
    role = null;
    fullName = null;
    classId = null;
    bootstrapUserData = null;
    twoFactorNotifier.value = false;
  }
}
