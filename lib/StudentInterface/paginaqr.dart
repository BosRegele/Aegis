import 'dart:async';
import 'dart:math';

import 'package:firster/StudentInterface/meniu.dart';
import 'package:firster/session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TeodorScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const TeodorScreen({super.key, this.onNavigateTab});

  @override
  State<TeodorScreen> createState() => _TeodorScreenState();
}

class _TeodorScreenState extends State<TeodorScreen> {
  Timer? _timer;
  String _token = '';
  bool _loadingToken = false;

  @override
  void initState() {
    super.initState();
    _regen();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _regen());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<String> _createToken(String userId) async {
    final rand = Random();
    final tokenId = List.generate(16, (_) => rand.nextInt(10)).join();
    final expiresAt = DateTime.now().add(const Duration(seconds: 20));

    await FirebaseFirestore.instance.collection('qrTokens').doc(tokenId).set({
      'userId': userId,
      'expiresAt': expiresAt,
      'used': false,
    });

    return tokenId;
  }

  Future<void> _regen() async {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          _token = '';
        });
      }
      return;
    }

    if (mounted) {
      setState(() => _loadingToken = true);
    }

    try {
      final newToken = await _createToken(uid);
      if (!mounted) return;
      setState(() {
        _token = newToken;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut genera codul QR.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingToken = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = (AppSession.username?.trim().isNotEmpty ?? false)
        ? AppSession.username!.trim()
        : 'Nume Prenume';

    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAF5B),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () {
            if (widget.onNavigateTab != null) {
              widget.onNavigateTab!(0);
              return;
            }

            final navigator = Navigator.of(context);
            if (navigator.canPop()) {
              navigator.pop();
            } else {
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => const MeniuScreen()),
              );
            }
          },
        ),
        title: const Text(
          'Acces QR',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 30,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFFE7EDF0),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      child: Column(
                        children: [
                          Container(
                            width: 110,
                            height: 110,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD8E3C2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 56,
                              color: Color(0xFF6A7A4D),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 34,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1C1C1C),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Elev',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF3A3A3A),
                            ),
                          ),
                          const Text(
                            'Clasa 11 I',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF3A3A3A),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            height: 1,
                            color: const Color(0xFFD0D0D0),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 540),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: _loadingToken ? null : _regen,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF6F6F6),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFFE0E0E0),
                                      ),
                                    ),
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        final squareSide =
                                            constraints.biggest.shortestSide;
                                        final badgeSize = squareSide * 0.25;

                                        return Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            if (_token.isNotEmpty)
                                              Padding(
                                                padding: EdgeInsets.all(
                                                  squareSide * 0.08,
                                                ),
                                                child: QrImageView(
                                                  data: _token,
                                                  backgroundColor: Colors.white,
                                                ),
                                              )
                                            else
                                              const Center(
                                                child: Text(
                                                  'QR indisponibil',
                                                  style: TextStyle(
                                                    fontSize: 22,
                                                    color: Color(0xFF4A4A4A),
                                                  ),
                                                ),
                                              ),
                                            if (_loadingToken)
                                              const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                            if (_token.isNotEmpty)
                                              Container(
                                                width: badgeSize,
                                                height: badgeSize,
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFEAF2D7,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        squareSide * 0.06,
                                                      ),
                                                  border: Border.all(
                                                    color: const Color(
                                                      0xFF86AB4A,
                                                    ),
                                                    width: 2,
                                                  ),
                                                ),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Padding(
                                                    padding: EdgeInsets.all(
                                                      squareSide * 0.04,
                                                    ),
                                                    child: const Icon(
                                                      Icons.shield_rounded,
                                                      color: Color(0xFF86AB4A),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (_token.isNotEmpty)
                            Text(
                              'Token: $_token',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF4A4A4A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD2D8C9),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                    child: const Text(
                      'Codul QR se reinnoieste automat,\napasa pentru reinnoire manuala',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 25,
                        height: 1.2,
                        color: Color(0xFF616161),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
