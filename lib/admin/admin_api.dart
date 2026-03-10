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

  Future<Map<String, dynamic>> resetPassword({required String username}) async {
    final callable = _functions.httpsCallable('adminResetPassword');
    final res = await callable.call(<String, dynamic>{
      'username': username.trim().toLowerCase(),
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

  Future<Map<String, dynamic>> deleteUser({
    required String username,
  }) async {
    final callable = _functions.httpsCallable('adminDeleteUser');
    final res = await callable.call(<String, dynamic>{
      'username': username.trim().toLowerCase(),
    });
    return Map<String, dynamic>.from(res.data as Map);
  }
}
