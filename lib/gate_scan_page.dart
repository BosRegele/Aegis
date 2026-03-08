import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_functions/cloud_functions.dart';

class GateScanPage extends StatefulWidget {
  const GateScanPage({super.key});

  @override
  State<GateScanPage> createState() => _GateScanPageState();
}

class _GateScanPageState extends State<GateScanPage> {
  String _status = "Scanează un QR...";
  bool _isAllowed = false;
  bool _lock = false;

  Future<Map<String, dynamic>> _redeemToken(String tokenId) async {
    final callable = FirebaseFunctions.instance.httpsCallable('redeemQrToken');

    final res = await callable.call(<String, dynamic>{'token': tokenId});

    return Map<String, dynamic>.from(res.data as Map);
  }

  Future<void> _logAccessEvent({
    required String tokenId,
    required bool allowed,
    required String reason,
    String? userId,
  }) async {
    await FirebaseFirestore.instance.collection('accessEvents').add({
      'tokenId': tokenId,
      'userId': userId,
      'timestamp': Timestamp.now(),
      'scanType': 'entry',
      'result': allowed ? 'allow' : 'deny',
      'reason': reason,
    });
  }

  Future<void> _handleToken(String tokenId) async {
    setState(() {
      _status = "Verificare...";
    });

    try {
      final res = await _redeemToken(tokenId);

      final ok = res["ok"] == true;
      final userId = (res["userId"] ?? "-").toString();
      final fullName = (res["fullName"] ?? "").toString();
      final classId = (res["classId"] ?? "").toString();
      final reason = (res["reason"] ?? "").toString();

      await _logAccessEvent(
        tokenId: tokenId,
        allowed: ok,
        reason: reason,
        userId: userId == '-' ? null : userId,
      );

      setState(() {
        _isAllowed = ok;
        _status = ok
            ? "✅ ALLOW\n$fullName\n$classId\n(userId=$userId)"
            : "❌ DENY ($reason)\n$fullName\n$classId\n(userId=$userId)";
      });
    } catch (e) {
      setState(() {
        _isAllowed = false;
        _status = "❌ Eroare validare: $e";
      });
    }

    _lock = true;

    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    setState(() {
      _lock = false;
      _status = "Scanează un QR...";
      _isAllowed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Poartă - Scan (Firebase)")),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (_lock) return;
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) return;

                final raw = barcodes.first.rawValue;
                if (raw == null || raw.isEmpty) return;

                _lock = true;
                _handleToken(raw);
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: _isAllowed ? Colors.green : Colors.red,
            child: Text(
              _status,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
