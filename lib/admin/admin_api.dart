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

  Future<Map<String, dynamic>> resetPassword({required String uid}) async {
    final callable = _functions.httpsCallable('adminResetPassword');
    final res = await callable.call(<String, dynamic>{'uid': uid});
    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<Map<String, dynamic>> setDisabled({
    required String uid,
    required bool disabled,
  }) async {
    final callable = _functions.httpsCallable('adminSetDisabled');
    final res = await callable.call(<String, dynamic>{
      'uid': uid,
      'disabled': disabled,
    });
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
    required String uid,
    required String newClassId,
  }) async {
    final callable = _functions.httpsCallable('adminMoveStudentClass');
    final res = await callable.call(<String, dynamic>{
      'uid': uid,
      'newClassId': newClassId,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }
}
