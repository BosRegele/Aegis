import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_functions/cloud_functions.dart';
<<<<<<< HEAD
=======
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/session.dart';
>>>>>>> 27bca0e4608c337456fd15066f71715965184be2

class GateScanPage extends StatefulWidget {
  const GateScanPage({super.key});

  @override
  State<GateScanPage> createState() => _GateScanPageState();
}

class _GateScanPageState extends State<GateScanPage> {
  String _status = "Scanează un QR...";
  bool _isAllowed = false;
  bool _lock = false;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
  }

  Future<Map<String, dynamic>> _redeemToken(String tokenId) async {
    final callable = FirebaseFunctions.instance.httpsCallable('redeemQrToken');

    final res = await callable.call(<String, dynamic>{'token': tokenId});

    return Map<String, dynamic>.from(res.data as Map);
  }

  // Logging is now handled in the backend (Cloud Function)

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
      final scanType = (res["type"] ?? (ok ? "entry" : "deny")).toString();

      // Logging is now handled in the backend (Cloud Function)

      String statusMessage;
      if (ok) {
        if (scanType == "exit") {
          statusMessage = "✅ EXIT\n$fullName\n$classId\n(userId=$userId)";
        } else {
          statusMessage = "✅ ALLOW\n$fullName\n$classId\n(userId=$userId)";
        }
      } else if (reason == "ALREADY_IN_SCHOOL") {
        statusMessage =
            "❌ DENY (already in school)\nClasele nu s-au terminat încă";
      } else if (reason == "OUTSIDE_CLASS_DAY") {
        statusMessage =
            "❌ DENY (outside class day)\nNu se pot ieși în afara zilei de școală";
      } else if (reason == "NO_SCHEDULE") {
        statusMessage =
            "❌ DENY (no schedule)\nOrarul nu este setat pentru clasa acestui elev";
      } else {
        statusMessage =
            "❌ DENY ($reason)\n$fullName\n$classId\n(userId=$userId)";
      }

      setState(() {
        _isAllowed = ok;
        _status = statusMessage;
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
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Deconecteaza-te',
          icon: const Icon(Icons.logout),
          onPressed: _logout,
        ),
        title: const Text("Poartă - Scan (Firebase)"),
      ),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              onDetect: (capture) {
                if (_lock) return;
                _lock = true;
                final barcodes = capture.barcodes;
                if (barcodes.isEmpty) {
                  _lock = false;
                  return;
                }

                final raw = barcodes.first.rawValue;
                if (raw == null || raw.isEmpty) {
                  _lock = false;
                  return;
                }

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
