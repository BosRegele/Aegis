import 'dart:async';
import 'dart:math';

import 'package:firster/StudentInterface/meniu.dart';
import 'package:firster/session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TeodorScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;
  final bool isActive;

  const TeodorScreen({super.key, this.onNavigateTab, this.isActive = true});

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
    if (widget.isActive) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(TeodorScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _regen();
      _startTimer();
    } else if (!widget.isActive && oldWidget.isActive) {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _startTimer() {
    _timer?.cancel();
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

  Future<bool> _regen() async {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) {
      if (mounted) {
        setState(() {
          _token = '';
        });
      }
      return false;
    }

    if (mounted) {
      setState(() => _loadingToken = true);
    }

    try {
      final newToken = await _createToken(uid);
      if (!mounted) return true;
      setState(() {
        _token = newToken;
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu am putut genera codul QR.')),
      );
      return false;
    } finally {
      if (mounted) {
        setState(() => _loadingToken = false);
      }
    }
  }

  Future<void> _onManualRefreshPressed() async {
    if (_loadingToken) {
      return;
    }

    final ok = await _regen();
    if (!mounted) {
      return;
    }

    if (ok) {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cod QR reinnoit manual.'),
          duration: Duration(milliseconds: 900),
        ),
      );
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
        toolbarHeight: 68,
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
          height: double.infinity,
          clipBehavior: Clip.antiAlias,
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
                  const SizedBox(height: 70),
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.topCenter,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 48, 16, 14),
                          child: Column(
                            children: [
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 27,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1C1C1C),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                height: 1,
                                color: const Color(0xFFD0D0D0),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 300,
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: _loadingToken
                                          ? null
                                          : _onManualRefreshPressed,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF6F6F6),
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE0E0E0),
                                          ),
                                        ),
                                        child: LayoutBuilder(
                                          builder: (context, constraints) {
                                            final squareSide = constraints
                                                .biggest
                                                .shortestSide;

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
                                                      backgroundColor:
                                                          Colors.white,
                                                    ),
                                                  )
                                                else
                                                  const Center(
                                                    child: Text(
                                                      'QR indisponibil',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        color: Color(
                                                          0xFF4A4A4A,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                if (_loadingToken)
                                                  const Center(
                                                    child:
                                                        CircularProgressIndicator(),
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
                              const SizedBox(height: 8),
                              if (_token.isNotEmpty)
                                Text(
                                  'Token: $_token',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF4A4A4A),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        top: -50,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD8E3C2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 52,
                            color: Color(0xFF6A7A4D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Material(
                    color: const Color(0xFFD2D8C9),
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _loadingToken ? null : _onManualRefreshPressed,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _loadingToken
                                  ? Icons.hourglass_top_rounded
                                  : Icons.refresh_rounded,
                              size: 18,
                              color: const Color(0xFF616161),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _loadingToken
                                    ? 'Se reinnoieste codul QR...'
                                    : 'Codul QR se reinnoieste automat,\napasa pentru reinnoire manuala',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 17,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
