import 'dart:convert';
import 'package:crypto/crypto.dart';

class QrToken {
  static const String _secret = "DEMO_SECRET_CHANGE_ME";

  static String generate({required String userId, required int ttlSeconds}) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final exp = now + ttlSeconds;

    final payload = "$userId.$exp";
    final sig = _hmac(payload);

    return "$userId.$exp.$sig";
  }

  static bool verify(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return false;

    final userId = parts[0];
    final expStr = parts[1];
    final sig = parts[2];

    final exp = int.tryParse(expStr);
    if (exp == null) return false;

    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now > exp) return false;

    final payload = "$userId.$exp";
    final expectedSig = _hmac(payload);

    return sig == expectedSig;
  }

  static String? extractUserId(String token) {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    return parts[0];
  }

  static String _hmac(String message) {
    final key = utf8.encode(_secret);
    final bytes = utf8.encode(message);
    final hmacSha256 = Hmac(sha256, key);
    final digest = hmacSha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }
}
