import 'package:cloud_functions/cloud_functions.dart';

class AdminApi {
  final FirebaseFunctions _functions;

  AdminApi({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    String? classId,
  }) async {
    final callable = _functions.httpsCallable('adminCreateUser');

    final res = await callable.call({
      "username": username,
      "password": password,
      "fullName": fullName,
      "role": role,
      "classId": classId,
    });

    return Map<String, dynamic>.from(res.data);
  }

  Future<Map<String, dynamic>> resetPassword({
    required String username,
    required String newPassword,
  }) async {
    final callable = _functions.httpsCallable('adminResetPassword');
    final res = await callable.call(<String, dynamic>{
      'username': username.trim().toLowerCase(),
      'newPassword': newPassword,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> setClassNoExitSchedule({
    required String classId,
    required String startHHmm,
    required String endHHmm,
  }) async {
    final callable = _functions.httpsCallable('adminSetClassNoExitSchedule');
    final res = await callable.call(<String, dynamic>{
      'classId': classId,
      'startHHmm': startHHmm,
      'endHHmm': endHHmm,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> setClassNoExitScheduleForDays({
    required String classId,
    required String startHHmm,
    required String endHHmm,
    required List<int> days,
  }) async {
    final callable = _functions.httpsCallable('adminSetClassNoExitSchedule');
    final res = await callable.call(<String, dynamic>{
      'classId': classId,
      'startHHmm': startHHmm,
      'endHHmm': endHHmm,
      'days': days,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> setClassSchedulePerDay({
    required String classId,
    required Map<int, Map<String, String>> schedulePerDay,
  }) async {
    final callable = _functions.httpsCallable('adminSetClassSchedulePerDay');
    // Construct schedule as flat structure: day1_start, day1_end, day2_start, day2_end...
    // or keep it nested but be explicit
    final scheduleMap = <String, Map<String, String>>{};

    for (final entry in schedulePerDay.entries) {
      final dayNum = entry.key.toString();
      final times = entry.value;
      scheduleMap[dayNum] = {
        'start': times['start'] ?? '07:30',
        'end': times['end'] ?? '13:00',
      };
    }

    final data = <String, dynamic>{
      'classId': classId.trim().toUpperCase(),
      'schedule': scheduleMap,
    };

    final res = await callable.call(data);
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> deleteClassCascade({
    required String classId,
  }) async {
    final callable = _functions.httpsCallable('adminDeleteClassCascade');
    final res = await callable.call(<String, dynamic>{'classId': classId});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> setDisabled({
    required String username,
    required bool disabled,
  }) async {
    final callable = _functions.httpsCallable('adminSetDisabled');
    final res = await callable.call(<String, dynamic>{
      'username': username.trim().toLowerCase(),
      'disabled': disabled,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> assignParentToStudent({
    required String studentUid,
    required String parentUid,
  }) async {
    final callable = _functions.httpsCallable('adminAssignParentToStudent');
    final res = await callable.call(<String, dynamic>{
      'studentUid': studentUid,
      'parentUid': parentUid,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> removeParentFromStudent({
    required String studentUid,
    required String parentUid,
  }) async {
    final callable = _functions.httpsCallable('adminRemoveParentFromStudent');
    final res = await callable.call(<String, dynamic>{
      'studentUid': studentUid,
      'parentUid': parentUid,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> redeemQrToken({required String token}) async {
    final callable = _functions.httpsCallable('redeemQrToken');
    final res = await callable.call(<String, dynamic>{'token': token});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> createClass({
    required String name,
    int? grade,
    String? letter,
    String? year,
    String? teacherUid,
  }) async {
    final callable = _functions.httpsCallable('adminCreateClass');
    final res = await callable.call(<String, dynamic>{
      'name': name,
      'grade': grade,
      'letter': letter,
      'year': year,
      'teacherUid': teacherUid,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> moveStudentClass({
    required String username,
    required String newClassId,
  }) async {
    final callable = _functions.httpsCallable('adminMoveStudentClass');
    final res = await callable.call(<String, dynamic>{
      'username': username.trim().toLowerCase(),
      'newClassId': newClassId.trim().toUpperCase(),
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> deleteUser({required String username}) async {
    final callable = _functions.httpsCallable('adminDeleteUser');
    final res = await callable.call(<String, dynamic>{
      'username': username.trim().toLowerCase(),
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> updateUserFullName({
    required String username,
    required String fullName,
  }) async {
    final callable = _functions.httpsCallable('adminUpdateUserFullName');
    final res = await callable.call(<String, dynamic>{
      'username': username.trim().toLowerCase(),
      'fullName': fullName.trim(),
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> sendVerificationEmail({
    required String uid,
    required String email,
  }) async {
    final callable = _functions.httpsCallable('sendVerificationEmail');
    await callable.call(<String, dynamic>{'uid': uid, 'email': email});
  }

  Future<Map<String, dynamic>> verifyEmailCode({
    required String uid,
    required String code,
  }) async {
    final callable = _functions.httpsCallable('verifyEmailCode');
    final res = await callable.call(<String, dynamic>{
      'uid': uid,
      'code': code,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> markPasswordChanged({
    required String uid,
  }) async {
    final callable = _functions.httpsCallable('markPasswordChanged');
    final res = await callable.call(<String, dynamic>{'uid': uid});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> setNewPassword({
    required String password,
  }) async {
    final callable = _functions.httpsCallable('setNewPassword');
    final res = await callable.call(<String, dynamic>{'password': password});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> removePersonalEmail({
    required String username,
  }) async {
    final callable = _functions.httpsCallable('adminRemovePersonalEmail');
    final res = await callable.call(<String, dynamic>{
      'username': username.trim().toLowerCase(),
    });
    return Map<String, dynamic>.from(res.data as Map);
  }
}
