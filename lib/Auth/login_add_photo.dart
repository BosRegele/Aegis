import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';

class ProfilePicturePage extends StatefulWidget {
  final User user;
  final VoidCallback? onBack;
  final Future<void> Function()? onFinalize;
  final bool canUploadPhoto;
  final bool showSkipButton;

  const ProfilePicturePage({
    required this.user,
    this.onBack,
    this.onFinalize,
    this.canUploadPhoto = true,
    this.showSkipButton = false,
    super.key,
  });

  @override
  State<ProfilePicturePage> createState() => _ProfilePicturePageState();
}

class _ProfilePicturePageState extends State<ProfilePicturePage> {
  // ── colours matching the mockup ─────────────────────────────────────────────
  static const _darkBg = Color(0xFF0B2B17);
  static const _leftPanelGreen = Color(0xFF0C5A22);
  static const _primaryGreen = Color(0xFF1F6B38);
  static const _cardCream = Color(0xFFF5F1E8);
  static const _infoBoxBg = Color(0xFFE9F4EE);
  static const _infoBoxBorder = Color(0xFFBFDECC);

  Uint8List? _imageBytes;
  String? _imageFilePath;
  bool _loading = false;

  // ── image picking ────────────────────────────────────────────────────────────
  Future<void> _pickImage() async {
    if (!widget.canUploadPhoto) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _imageBytes = bytes;
      _imageFilePath = picked.path;
    });
  }

  // ── finalize / upload ────────────────────────────────────────────────────────
  Future<void> _finalize() async {
    setState(() => _loading = true);
    try {
      if (!widget.canUploadPhoto) {
        await widget.onFinalize?.call();
        return;
      }

      if (_imageBytes != null) {
        final ref = FirebaseStorage.instance.ref(
          'profile_pictures/${widget.user.uid}.jpg',
        );
        final meta = SettableMetadata(contentType: 'image/jpeg');

        String downloadUrl;
        if (kIsWeb) {
          final snap = await ref.putData(_imageBytes!, meta);
          downloadUrl = await snap.ref.getDownloadURL();
        } else {
          final snap = await ref.putFile(File(_imageFilePath!), meta);
          downloadUrl = await snap.ref.getDownloadURL();
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.user.uid)
            .update({'profilePictureUrl': downloadUrl});
      }
      await widget.onFinalize?.call();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'unauthorized' =>
          'Nu am putut salva fotografia acum. Incearca din nou in cateva secunde.',
        'canceled' => 'Incarcarea fotografiei a fost anulata.',
        'quota-exceeded' =>
          'Spatiul de stocare este momentan indisponibil. Incearca din nou mai tarziu.',
        _ => 'Nu am putut salva fotografia acum. Incearca din nou.',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Nu am putut salva fotografia acum. Incearca din nou.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── build ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _BgDotsPainter(), size: Size.infinite),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return Center(
                  child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── wide (desktop / web) layout ──────────────────────────────────────────────
  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.24),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: SizedBox(
              height: 560,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 40, child: _buildLeftPanel()),
                  Expanded(flex: 60, child: _buildRightPanel()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── narrow (mobile) layout ───────────────────────────────────────────────────
  Widget _buildNarrowLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Material(
          color: Colors.transparent,
          elevation: 20,
          shadowColor: Colors.black,
          borderRadius: BorderRadius.circular(24),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: _buildRightPanel(),
          ),
        ),
      ),
    );
  }

  // ── left green panel ─────────────────────────────────────────────────────────
  Widget _buildLeftPanel() {
    return Container(
      color: _leftPanelGreen,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(painter: _PhotoLeftDotsPainter()),
          Positioned(top: -34, right: -24, child: _panelCircle(130)),
          Positioned(bottom: -42, left: -28, child: _panelCircle(150)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 48),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // app icon / logo
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _primaryGreen,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryGreen.withValues(alpha: 0.35),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/aegis_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                const Text(
                  'Poarta ta către\nsecuritate academică',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Soluția completă, optimizată pentru mobil, '
                  'pentru gestionarea accesului și plecărilor din '
                  'școală. Crește siguranța prin identități QR '
                  'dinamice, integrare automată a orarului și '
                  'aprobări în timp real din partea părinților.',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 13.5,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _panelCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        shape: BoxShape.circle,
      ),
    );
  }

  // ── right cream panel ────────────────────────────────────────────────────────
  Widget _buildRightPanel() {
    return Container(
      color: _cardCream,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight.isFinite
                    ? constraints.maxHeight
                    : 0,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 44,
                  vertical: 36,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStepIndicator(),
                    const SizedBox(height: 22),
                    const Text(
                      'Imagine Profil',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Încarcă o fotografie de profil pentru identificare vizuală.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF777777),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Center(child: _buildAvatar()),
                    const SizedBox(height: 24),
                    _buildUploadButton(),
                    const SizedBox(height: 12),
                    _buildInfoBox(),
                    const SizedBox(height: 28),
                    _buildNavigationRow(),
                    const SizedBox(height: 18),
                    _buildHelpText(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── step indicator row ───────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Row(
      children: [
        const Text(
          'PASUL 3 DIN 3',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w600,
            color: _primaryGreen,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 2 ? 5.0 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    color: _primaryGreen,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── avatar circle with camera overlay ───────────────────────────────────────
  Widget _buildAvatar() {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 65,
            backgroundColor: const Color(0xFFD0D0D0),
            backgroundImage: _imageBytes != null
                ? MemoryImage(_imageBytes!)
                : null,
            child: _imageBytes == null
                ? Icon(Icons.person, size: 72, color: Colors.grey.shade500)
                : null,
          ),
          Positioned(
            bottom: 2,
            right: 2,
            child: Opacity(
              opacity: widget.canUploadPhoto ? 1 : 0.45,
              child: GestureDetector(
                onTap: (_loading || !widget.canUploadPhoto) ? null : _pickImage,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _primaryGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── "Încarcă Foto" outlined button ──────────────────────────────────────────
  Widget _buildUploadButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (_loading || !widget.canUploadPhoto) ? null : _pickImage,
        icon: const Icon(
          Icons.file_upload_outlined,
          color: Color(0xFF333333),
          size: 20,
        ),
        label: Text(
          widget.canUploadPhoto
              ? 'Încarcă Foto'
              : 'Upload indisponibil pentru acest rol',
          style: TextStyle(
            color: Color(0xFF333333),
            fontWeight: FontWeight.w500,
            fontSize: 15,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFDDDDDD)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }

  // ── criteria info box ────────────────────────────────────────────────────────
  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _infoBoxBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _infoBoxBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF2D7A4F),
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.canUploadPhoto
                  ? 'Criterii: Față trebuie să fie vizibilă clar, fundal neutru, fără accesorii care ascund trăsăturile.'
                  : 'Pentru conturile de secretariat, încărcarea pozei de profil este dezactivată. Apasă Skip pentru a continua.',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF3D3D3D),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── navigation buttons ───────────────────────────────────────────────────────
  Widget _buildNavigationRow() {
    return Row(
      children: [
        if (widget.showSkipButton) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: _loading ? null : _finalize,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFCCCCCC)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Skip',
                style: TextStyle(
                  color: Color(0xFF333333),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _loading ? null : widget.onBack,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: Color(0xFF333333),
            ),
            label: const Text(
              'Pasul anterior',
              style: TextStyle(
                color: Color(0xFF333333),
                fontWeight: FontWeight.w500,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Color(0xFFCCCCCC)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _loading ? null : _finalize,
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryGreen,
              disabledBackgroundColor: Color(0xFF1F6B38).withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.canUploadPhoto ? 'Finalizare' : 'Continuă',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // ── help text ────────────────────────────────────────────────────────────────
  Widget _buildHelpText() {
    return Center(
      child: Column(
        children: [
          const Text(
            'Ai nevoie de ajutor?',
            style: TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
          GestureDetector(
            onTap: () {
              // TODO: open IT support link / dialog
            },
            child: const Text(
              'Contactează suportul IT',
              style: TextStyle(
                fontSize: 13,
                color: _primaryGreen,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: _primaryGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BgDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withAlpha(8)
      ..style = PaintingStyle.fill;
    const spacing = 20.0;
    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.0, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PhotoLeftDotsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.09);
    const spacing = 18.0;
    for (double y = 12; y < size.height; y += spacing) {
      for (double x = 12; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 0.9, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
