import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../utils/password_hash.dart';

class AdminStore {
  final _db = FirebaseFirestore.instance;

  Future<void> createUser({
    required String username,
    required String password,
    required String role, // student|teacher|admin|gate
    required String fullName,
    String? classId,
  }) async {
    username = username.trim().toLowerCase();

    if (username.isEmpty || password.isEmpty || fullName.isEmpty) {
      throw Exception("Campuri lipsa");
    }
    if (!["student", "teacher", "admin", "gate", "parent"].contains(role)) {
      throw Exception("Role invalid");
    }
    if ((role == "student" || role == "teacher") &&
        (classId == null || classId.trim().isEmpty)) {
      throw Exception("classId obligatoriu pentru $role");
    }
    // âœ… Dacă e student/teacher, clasa TREBUIE să existe deja în /classes
    if (role == "student" || role == "teacher") {
      final cId = classId!.trim().toUpperCase();
      final classSnap = await _db.collection('classes').doc(cId).get();

      if (!classSnap.exists) {
        throw Exception("Clasa $cId nu exista");
      }
    }
    final ref = _db.collection('users').doc(username);
    final snap = await ref.get();
    if (snap.exists) throw Exception("Username deja exista");
    if (role == "teacher") {
      await _createTeacherAndAssign(
        username: username,
        password: password,
        fullName: fullName,
        classId: classId!,
      );
      return;
    }
    final hp = await PasswordHash.hashPassword(password);
    await ref.set({
      "username": username,
      "role": role,
      "fullName": fullName,
      "classId": (role == "student" || role == "teacher")
          ? classId!.trim().toUpperCase()
          : null,
      "status": "active",
      "passwordAlgo": hp["algo"],
      "passwordSalt": hp["saltB64"],
      "passwordHash": hp["hashB64"],
      "createdAt": FieldValue.serverTimestamp(),
    });
    if (role == "teacher") {
      await changeClassTeacher(classId: classId!, teacherUsername: username);
    }
  }

  Future<void> setClassNoExitSchedule({
    required String classId,
    required String startHHmm,
    required String endHHmm,
  }) async {
    classId = classId.trim().toUpperCase();
    if (classId.isEmpty) throw Exception("classId lipsa");

    // (opțional) verifică format HH:mm
    bool ok(String s) => RegExp(r'^\d{2}:\d{2}$').hasMatch(s);
    if (!ok(startHHmm) || !ok(endHHmm)) {
      throw Exception("Format invalid. Foloseste HH:mm (ex: 07:30)");
    }

    // clasa trebuie să existe (cum ai vrut)
    final classRef = _db.collection('classes').doc(classId);
    final snap = await classRef.get();
    if (!snap.exists) throw Exception("Clasa $classId nu exista");

    await classRef.set({
      "noExitStart": startHHmm,
      "noExitEnd": endHHmm,
      "noExitDays": [1, 2, 3, 4, 5],
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setClassNoExitScheduleForDays({
    required String classId,
    required String startHHmm,
    required String endHHmm,
    required List<String> days,
  }) async {
    classId = classId.trim().toUpperCase();
    if (classId.isEmpty) throw Exception("classId lipsa");

    // (opțional) verifică format HH:mm
    bool ok(String s) => RegExp(r'^\d{2}:\d{2}$').hasMatch(s);
    if (!ok(startHHmm) || !ok(endHHmm)) {
      throw Exception("Format invalid. Foloseste HH:mm (ex: 07:30)");
    }

    // clasa trebuie să existe
    final classRef = _db.collection('classes').doc(classId);
    final snap = await classRef.get();
    if (!snap.exists) throw Exception("Clasa $classId nu exista");

    // converti zilele din Romanian format la numere (1-5)
    final dayMapping = {
      'Luni': 1,
      'Marți': 2,
      'Miercuri': 3,
      'Joi': 4,
      'Vineri': 5,
    };

    final dayNumbers = days
        .map((day) => dayMapping[day])
        .whereType<int>()
        .toList();

    await classRef.set({
      "noExitStart": startHHmm,
      "noExitEnd": endHHmm,
      "noExitDays": dayNumbers,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> deleteClassCascade(String classId) async {
    classId = classId.trim().toUpperCase();
    if (classId.isEmpty) throw Exception("classId lipsa");

    final classRef = _db.collection('classes').doc(classId);

    // ia teacherUsername înainte
    final classSnap = await classRef.get();
    final teacherUsername = (classSnap.data()?['teacherUsername'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    // 1) șterge toți elevii din clasa asta
    final studentsSnap = await _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .where('classId', isEqualTo: classId)
        .get();

    final batch = _db.batch();
    for (final d in studentsSnap.docs) {
      batch.delete(d.reference);
    }

    // 2) dacă există teacher -> șterge-l și pe el (sau doar scoți classId, vezi comentariu)
    if (teacherUsername.isNotEmpty) {
      final tRef = _db.collection('users').doc(teacherUsername);
      batch.delete(tRef);

      // alternativ mai safe (nu ștergi profesorul, doar îl â€œdezasigneziâ€):
      // batch.update(tRef, {"classId": FieldValue.delete()});
    }

    // 3) șterge clasa
    batch.delete(classRef);

    await batch.commit();
  }

  Future<void> _createTeacherAndAssign({
    required String username,
    required String password,
    required String fullName,
    required String classId,
  }) async {
    username = username.trim().toLowerCase();
    classId = classId.trim().toUpperCase();

    final userRef = _db.collection('users').doc(username);
    final classRef = _db.collection('classes').doc(classId);

    final hp = await PasswordHash.hashPassword(password);

    await _db.runTransaction((tx) async {
      final uSnap = await tx.get(userRef);
      if (uSnap.exists) throw Exception("Username deja exista");

      final cSnap = await tx.get(classRef);
      final existingTeacher = cSnap.exists
          ? ((cSnap.data() as Map<String, dynamic>)['teacherUsername'] ?? '')
                .toString()
                .trim()
                .toLowerCase()
          : '';
      if (existingTeacher.isNotEmpty) {
        throw Exception("Clasa $classId are deja diriginte: $existingTeacher");
      }

      // 1) creează user teacher
      tx.set(userRef, {
        "username": username,
        "role": "teacher",
        "fullName": fullName,
        "classId": classId,
        "status": "active",
        "passwordAlgo": hp["algo"],
        "passwordSalt": hp["saltB64"],
        "passwordHash": hp["hashB64"],
        "createdAt": FieldValue.serverTimestamp(),
      });

      // 2) setează teacher pe clasă
      tx.set(classRef, {
        "name": classId,
        "teacherUsername": username,
        "updatedAt": FieldValue.serverTimestamp(),
        "createdAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<String> resetPassword(String username) async {
    username = username.trim().toLowerCase();
    final newPass = _randomPass(10);
    final hp = await PasswordHash.hashPassword(newPass);
    await _db.collection('users').doc(username).update({
      "passwordAlgo": hp["algo"],
      "passwordSalt": hp["saltB64"],
      "passwordHash": hp["hashB64"],
    });
    return newPass; // secretariat o copiază
  }

  Future<void> deleteUser(String username) async {
    username = username.trim().toLowerCase();
    if (username.isEmpty) throw Exception("username lipsa");

    Future<void> clearTeacherFromClasses() async {
      final classesSnap = await _db
          .collection('classes')
          .where('teacherUsername', isEqualTo: username)
          .get();
      if (classesSnap.docs.isEmpty) return;

      final batch = _db.batch();
      for (final classDoc in classesSnap.docs) {
        batch.set(classDoc.reference, {
          "teacherUsername": FieldValue.delete(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }

    // Preferred path: backend function deletes both Firebase Auth account
    // and Firestore user data.
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'adminDeleteUser',
      );
      await callable.call(<String, dynamic>{'username': username});
      // Defensive cleanup for legacy/inconsistent records.
      await clearTeacherFromClasses();
      return;
    } catch (_) {
      // Fallback to local cleanup to avoid blocking admin workflows.
    }

    final snap = await _db
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception("User inexistent");
    }

    final userRef = snap.docs.first.reference;
    final data = snap.docs.first.data();
    final role = (data['role'] ?? '').toString();
    final classId = (data['classId'] ?? '').toString().toUpperCase();

    if (role == "teacher") {
      await clearTeacherFromClasses();
      if (classId.isNotEmpty) {
        await _db.collection('classes').doc(classId).set({
          "teacherUsername": FieldValue.delete(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    }

    await userRef.delete();
  }

  Future<void> setDisabled(String username, bool disabled) async {
    username = username.trim().toLowerCase();
    if (username.isEmpty) throw Exception("username lipsa");

    final callable = FirebaseFunctions.instance.httpsCallable(
      'adminSetDisabled',
    );
    await callable.call(<String, dynamic>{
      'username': username,
      'disabled': disabled,
    });
  }

  Future<void> moveStudent(String userIdentifier, String newClassId) async {
    userIdentifier = userIdentifier.trim();
    newClassId = newClassId.trim().toUpperCase();

    if (userIdentifier.isEmpty) throw Exception("identificator user lipsa");
    if (newClassId.isEmpty) throw Exception("classId lipsa");

    // Support both user document id (uid/username) and username field.
    DocumentReference<Map<String, dynamic>>? userRef;
    final directRef = _db.collection('users').doc(userIdentifier);
    final directSnap = await directRef.get();
    if (directSnap.exists) {
      userRef = directRef;
    } else {
      final byUsername = await _db
          .collection('users')
          .where('username', isEqualTo: userIdentifier.toLowerCase())
          .limit(1)
          .get();
      if (byUsername.docs.isNotEmpty) {
        userRef = byUsername.docs.first.reference;
      }
    }

    if (userRef == null) {
      throw Exception(
        "User inexistent (verifică uid/username): $userIdentifier",
      );
    }
    final resolvedUserRef = userRef;

    final newClassRef = _db.collection('classes').doc(newClassId);

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(resolvedUserRef);
      if (!userSnap.exists) throw Exception("User inexistent");

      final userData = userSnap.data() as Map<String, dynamic>;
      final role = (userData["role"] ?? "").toString();
      final username = (userData["username"] ?? "")
          .toString()
          .trim()
          .toLowerCase();
      final oldClassId = (userData["classId"] ?? "")
          .toString()
          .trim()
          .toUpperCase();

      if (role != "student" && role != "teacher") {
        throw Exception("Doar student/teacher poate fi mutat");
      }

      // asigură clasa există
      final newClassSnap = await tx.get(newClassRef);
      if (!newClassSnap.exists) {
        tx.set(newClassRef, {
          "name": newClassId,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // STUDENT: doar update classId
      if (role == "student") {
        tx.update(resolvedUserRef, {
          "classId": newClassId,
          "updatedAt": FieldValue.serverTimestamp(),
        });
        return;
      }

      // TEACHER: verifică dacă noua clasă are deja diriginte
      final newClassData = newClassSnap.exists
          ? (newClassSnap.data() as Map<String, dynamic>)
          : <String, dynamic>{};

      final existingTeacher = (newClassData["teacherUsername"] ?? "")
          .toString()
          .trim()
          .toLowerCase();

      if (existingTeacher.isNotEmpty && existingTeacher != username) {
        throw Exception(
          "Clasa $newClassId are deja un diriginte: $existingTeacher",
        );
      }

      // dacă teacher era diriginte la clasa veche, îl scoatem de acolo
      if (oldClassId.isNotEmpty && oldClassId != newClassId) {
        final oldClassRef = _db.collection('classes').doc(oldClassId);
        final oldClassSnap = await tx.get(oldClassRef);
        if (oldClassSnap.exists) {
          final oldClassData = oldClassSnap.data() as Map<String, dynamic>;
          final oldTeacher = (oldClassData["teacherUsername"] ?? "")
              .toString()
              .trim()
              .toLowerCase();

          if (oldTeacher == username) {
            // scoate complet teacherUsername
            tx.set(oldClassRef, {
              "teacherUsername": FieldValue.delete(),
              "updatedAt": FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
        }
      }

      // setează teacher ca diriginte pe noua clasă
      tx.set(newClassRef, {
        "name": newClassId,
        "teacherUsername": username,
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // update user.classId
      tx.update(resolvedUserRef, {
        "classId": newClassId,
        "updatedAt": FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> changeClassTeacher({
    required String classId,
    required String teacherUsername, // poate fi "" ca sa scoti teacher
  }) async {
    classId = classId.trim().toUpperCase();
    teacherUsername = teacherUsername.trim().toLowerCase();

    final classRef = _db.collection('classes').doc(classId);

    await _db.runTransaction((tx) async {
      final classSnap = await tx.get(classRef);
      if (!classSnap.exists) {
        throw Exception("Clasa $classId nu exista");
      }

      String? oldTeacher;
      if (classSnap.exists) {
        final data = classSnap.data() as Map<String, dynamic>;
        oldTeacher = (data['teacherUsername'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        if (oldTeacher.isEmpty) oldTeacher = null;
      }

      // daca exista deja diriginte si incerci sa pui altul -> ERROR
      if (teacherUsername.isNotEmpty &&
          oldTeacher != null &&
          oldTeacher != teacherUsername) {
        throw Exception("Clasa $classId are deja diriginte: $oldTeacher");
      }

      // 1) set new teacher on class
      if (teacherUsername.isEmpty) {
        // scoate complet teacherUsername
        tx.set(classRef, {
          "name": classId,
          "updatedAt": FieldValue.serverTimestamp(),
          "teacherUsername": FieldValue.delete(),
        }, SetOptions(merge: true));

        if (oldTeacher != null && oldTeacher.isNotEmpty) {
          final oldTeacherRef = _db.collection('users').doc(oldTeacher);
          final oldSnap = await tx.get(oldTeacherRef);
          if (oldSnap.exists) {
            final oldData = oldSnap.data() as Map<String, dynamic>;
            final oldClassId = (oldData['classId'] ?? '')
                .toString()
                .toUpperCase();
            if (oldClassId == classId) {
              tx.update(oldTeacherRef, {"classId": FieldValue.delete()});
            }
          }
        }
      } else {
        tx.set(classRef, {
          "name": classId,
          "teacherUsername": teacherUsername,
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // 2) validate + update new teacher user doc (NU crea user dacă nu există)
      if (teacherUsername.isNotEmpty) {
        final newTeacherRef = _db.collection('users').doc(teacherUsername);
        final newSnap = await tx.get(newTeacherRef);

        if (!newSnap.exists) {
          throw Exception("Profesorul '$teacherUsername' nu exista in users");
        }

        final newData = newSnap.data() as Map<String, dynamic>;
        final newRole = (newData["role"] ?? "").toString();
        if (newRole != "teacher") {
          throw Exception("User '$teacherUsername' nu are role=teacher");
        }

        // teacher already assigned to another class?
        final teacherClass = (newData["classId"] ?? "")
            .toString()
            .toUpperCase();
        if (teacherClass.isNotEmpty && teacherClass != classId) {
          throw Exception(
            "Profesorul '$teacherUsername' este deja diriginte la $teacherClass",
          );
        }

        // ok -> update teacher's classId
        tx.update(newTeacherRef, {
          "classId": classId,
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }

      // 3) optional: clear old teacher classId if he was tied to this class
      if (oldTeacher != null &&
          oldTeacher != teacherUsername &&
          oldTeacher.isNotEmpty) {
        final oldTeacherRef = _db.collection('users').doc(oldTeacher);
        final oldSnap = await tx.get(oldTeacherRef);
        if (oldSnap.exists) {
          final oldData = oldSnap.data() as Map<String, dynamic>;
          final oldClassId = (oldData['classId'] ?? '')
              .toString()
              .toUpperCase();
          if (oldClassId == classId) {
            tx.update(oldTeacherRef, {"classId": FieldValue.delete()});
          }
        }
      }
    });
  }

  Future<void> createClass({
    required String classId,
    String? teacherUsername, // null = nu schimba, "" = remove, "abc" = set
  }) async {
    classId = classId.trim().toUpperCase();
    if (classId.isEmpty) throw Exception("classId lipsa");

    // doar asigura clasa exista
    await _db.collection('classes').doc(classId).set({
      "name": classId,
      "updatedAt": FieldValue.serverTimestamp(),
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // daca null -> nu schimba dirigintele
    if (teacherUsername == null) return;

    // IMPORTANT: cheama changeClassTeacher si pentru "" (remove)
    await changeClassTeacher(
      classId: classId,
      teacherUsername: teacherUsername,
    );
  }

  String _randomPass(int len) {
    const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789";
    final r = Random();
    return List.generate(len, (_) => chars[r.nextInt(chars.length)]).join();
  }
}
