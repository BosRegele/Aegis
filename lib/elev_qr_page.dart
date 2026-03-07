import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ElevQrPage extends StatefulWidget {
  final String userId;
  const ElevQrPage({super.key, required this.userId});

  @override
  State<ElevQrPage> createState() => _ElevQrPageState();
}

class _ElevQrPageState extends State<ElevQrPage> {
  late Timer _timer;
  String _token = "";

  @override
  void initState() {
    super.initState();
    _regen();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _regen());
  }

  Future<String> createToken(String userId) async {
    final rand = Random();
    final tokenId = List.generate(16, (i) => rand.nextInt(9)).join();

    final expiresAt = DateTime.now().add(const Duration(seconds: 20));

    await FirebaseFirestore.instance.collection("qrTokens").doc(tokenId).set({
      "userId": userId,
      "expiresAt": expiresAt,
      "used": false,
    });

    return tokenId;
  }

  void _regen() async {
    final newToken = await createToken(widget.userId);

    setState(() {
      _token = newToken;
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Elev - QR Dinamic")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(data: _token, size: 260),
            const SizedBox(height: 12),
            Text("Token:\n$_token", textAlign: TextAlign.center),
            const SizedBox(height: 12),
            const Text("Se regenerează la 5 sec. Expiră în 20 sec."),
          ],
        ),
      ),
    );
  }
}
