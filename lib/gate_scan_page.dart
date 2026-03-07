import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
    final db = FirebaseFirestore.instance;
    final tokenRef = db.collection('qrTokens').doc(tokenId);

    return db.runTransaction((tx) async {
      final snap = await tx.get(tokenRef);

      if (!snap.exists) {
        return {"ok": false, "reason": "NOT_FOUND"};
      }

      final data = snap.data()!;
      final used = (data['used'] as bool?) ?? false;
      final userId = data['userId']?.toString() ?? "unknown";
      final expiresAt = data['expiresAt'];

      if (used) {
        return {"ok": false, "reason": "ALREADY_USED", "userId": userId};
      }

      if (expiresAt is! Timestamp) {
        return {"ok": false, "reason": "BAD_EXPIRES", "userId": userId};
      }

      final now = Timestamp.now();
      if (expiresAt.compareTo(now) <= 0) {
        return {"ok": false, "reason": "EXPIRED", "userId": userId};
      }

      // Marchează token ca folosit (atomic)
      tx.update(tokenRef, {"used": true, "usedAt": now});

      // Log acces (opțional dar recomandat)
      final eventRef = db.collection('accessEvents').doc();
      tx.set(eventRef, {
        "tokenId": tokenId,
        "userId": userId,
        "timestamp": now,
        "type": "entry",
      });

      return {"ok": true, "userId": userId};
    });
  }

  Future<void> _handleToken(String tokenId) async {
    setState(() {
      _status = "Verificare...";
    });

    final res = await _redeemToken(tokenId);

    final ok = res["ok"] == true;
    final userId = res["userId"] ?? "-";
    final reason = res["reason"] ?? "";

    setState(() {
      _isAllowed = ok;
      _status = ok
          ? "✅ ALLOW (userId=$userId)"
          : "❌ DENY ($reason) (userId=$userId)";
    });

    _lock = true;

    // după 2 secunde se resetează și poți scana iar
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

                _lock = true; // blochează instant ca să nu dubleze scanarea
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
