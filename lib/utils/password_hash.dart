import 'dart:convert';
import 'dart:math';
import 'package:cryptography/cryptography.dart';

class PasswordHash {
  static final _rng = Random.secure();

  // PBKDF2-HMAC-SHA256
  static final Pbkdf2 _pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000, // ok pentru prototip; poți ajusta
    bits: 256,
  );

  static String _base64(List<int> bytes) => base64Encode(bytes);

  static List<int> _randomSalt([int length = 16]) =>
      List<int>.generate(length, (_) => _rng.nextInt(256));

  /// Returnează un map cu:
  /// - saltB64
  /// - hashB64
  /// - algo (string)
  static Future<Map<String, String>> hashPassword(String password) async {
    final salt = _randomSalt(16);
    final secretKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final hashBytes = await secretKey.extractBytes();

    return {
      'algo': 'pbkdf2_sha256',
      'saltB64': _base64(salt),
      'hashB64': _base64(hashBytes),
    };
  }

  /// Verifică parola pe baza salt+hash
  static Future<bool> verifyPassword({
    required String password,
    required String saltB64,
    required String hashB64,
  }) async {
    final salt = base64Decode(saltB64);

    final derivedKey = await _pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    final derivedBytes = await derivedKey.extractBytes();
    final derivedB64 = _base64(derivedBytes);

    // comparație simplă ok pentru prototip
    return derivedB64 == hashB64;
  }
}
