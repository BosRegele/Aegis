class AppSession {
  static String? uid;
  static String? username;
  static String? role;

  static bool get isAdmin => role == 'admin';

  static void setUser({
    required String uidValue,
    required String usernameValue,
    required String roleValue,
  }) {
    uid = uidValue;
    username = usernameValue;
    role = roleValue;
  }

  static void clear() {
    uid = null;
    username = null;
    role = null;
  }
}
