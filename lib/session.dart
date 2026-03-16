class AppSession {
  static String? uid;
  static String? username;
  static String? role;
  static String? fullName;
  static String? classId;

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

  static void clear() {
    uid = null;
    username = null;
    role = null;
    fullName = null;
    classId = null;
  }
}
