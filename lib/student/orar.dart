import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firster/admin/services/admin_api.dart';
import 'package:firster/student/logout_dialog.dart';
import 'package:firster/core/session.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const _primary = Color(0xFF0D631B);
const _surface = Color(0xFFF7F9F0);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFF0F4E9);
const _surfaceContainerHigh = Color(0xFFE7EDE1);
const _outline = Color(0xFF717B6E);
const _outlineVariant = Color(0xFFC8D1C2);
const _onSurface = Color(0xFF151A14);

class OrarScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;

  const OrarScreen({super.key, this.onBackToHome});

  @override
  State<OrarScreen> createState() => _OrarScreenState();
}

class _OrarScreenState extends State<OrarScreen> {
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _userDocStream;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      return;
    }
    _userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .snapshots();
  }

  Future<void> _logout() async {
    final shouldLogout = await showStudentLogoutDialog(
      context,
      accentColor: _primary,
      surfaceColor: _surface,
      softSurfaceColor: _surfaceContainerHigh,
      titleColor: _onSurface,
      messageColor: _outline,
      dangerColor: const Color(0xFF8E3557),
    );
    if (!shouldLogout) return;
    await FirebaseAuth.instance.signOut();
    AppSession.clear();
  }

  void _goBack() {
    if (widget.onBackToHome != null) {
      widget.onBackToHome!();
      return;
    }
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final fallbackName = (AppSession.username?.trim().isNotEmpty ?? false)
        ? AppSession.username!.trim()
        : 'Elev';

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        top: false,
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _userDocStream,
          builder: (context, userSnapshot) {
            final userData = userSnapshot.data?.data() ?? <String, dynamic>{};
            final fullName = (userData['fullName'] ?? '').toString().trim();
            final classId = (userData['classId'] ?? '').toString().trim();
            final className = (userData['className'] ?? '').toString().trim();
            final displayName = fullName.isNotEmpty ? fullName : fallbackName;
            final studentUsername = (userData['username'] ?? '')
                .toString()
                .trim();
            final profilePictureUrl = (userData['profilePictureUrl'] ?? '')
                .toString()
                .trim();

            final resolvedClassName = className.isNotEmpty
                ? className
                : (classId.isNotEmpty ? classId : 'Clasa necunoscută');

            final classStream = classId.isNotEmpty
                ? FirebaseFirestore.instance
                      .collection('classes')
                      .doc(classId)
                      .snapshots()
                : null;

            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: classStream,
              builder: (context, classSnapshot) {
                final classData =
                    classSnapshot.data?.data() ?? const <String, dynamic>{};

                final scheduleRows = _buildScheduleRows(classData);
                final teacherUid = (classData['teacherUid'] ?? '')
                    .toString()
                    .trim();
                final teacherUsername = (classData['teacherUsername'] ?? '')
                    .toString()
                    .trim();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OrarHeroHeader(onBack: _goBack, onLogout: _logout),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                              child: _ProfileIdentityCard(
                                displayName: displayName,
                                className: resolvedClassName,
                                profilePictureUrl: profilePictureUrl,
                                username: studentUsername,
                                teacherUid: teacherUid,
                                teacherUsername: teacherUsername,
                                onLogout: _logout,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  18,
                                ),
                                decoration: BoxDecoration(
                                  color: _surfaceLowest,
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: _outlineVariant.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Orar Clasa ${_classToRoman(resolvedClassName)}',
                                      style: const TextStyle(
                                        color: _onSurface,
                                        fontSize: 22,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    if (scheduleRows.isEmpty)
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: _surfaceContainerLow,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        child: const Text(
                                          'Nu există orar definit pe server pentru clasa ta.',
                                          style: TextStyle(
                                            color: _outline,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    for (final row in scheduleRows) ...[
                                      _ScheduleRow(
                                        dayName: row.dayName,
                                        intervalText: row.intervalText,
                                        rowDayNumber: row.dayNumber,
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _OrarHeroHeader extends StatelessWidget {
  final VoidCallback onBack;
  final Future<void> Function() onLogout;

  const _OrarHeroHeader({required this.onBack, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final headerHeight = compact ? 138.0 : 146.0;
    final titleSize = compact ? 29.0 : 33.0;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(52),
        bottomRight: Radius.circular(52),
      ),
      child: Container(
        height: headerHeight,
        color: _primary,
        child: Stack(
          children: [
            Positioned(
              top: -72,
              right: -52,
              child: _Circle(size: 220, opacity: 0.08),
            ),
            Positioned(
              top: 44,
              right: 34,
              child: _Circle(size: 72, opacity: 0.07),
            ),
            Positioned(
              left: 156,
              bottom: -28,
              child: _Circle(size: 82, opacity: 0.08),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Center(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _HeaderIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: onBack,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Profil',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 34,
        height: 34,
        child: Center(child: Icon(icon, color: Colors.white, size: 32)),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size;
  final double opacity;

  const _Circle({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _ProfileIdentityCard extends StatelessWidget {
  final String displayName;
  final String className;
  final String profilePictureUrl;
  final String username;
  final String teacherUid;
  final String teacherUsername;
  final VoidCallback onLogout;

  const _ProfileIdentityCard({
    required this.displayName,
    required this.className,
    required this.profilePictureUrl,
    required this.username,
    required this.teacherUid,
    required this.teacherUsername,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(38),
      child: Container(
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(38),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120D631B),
              blurRadius: 28,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile picture + class badge below
                  Column(
                    children: [
                      GestureDetector(
                        onTap: profilePictureUrl.isNotEmpty
                            ? () => _openFullScreenImage(
                                context,
                                profilePictureUrl,
                              )
                            : null,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: profilePictureUrl.isNotEmpty
                              ? Image.network(
                                  profilePictureUrl,
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 64,
                                    height: 64,
                                    color: _surfaceContainerHigh,
                                    child: const Icon(
                                      Icons.person,
                                      color: _outline,
                                      size: 34,
                                    ),
                                  ),
                                )
                              : Container(
                                  width: 64,
                                  height: 64,
                                  color: _surfaceContainerHigh,
                                  child: const Icon(
                                    Icons.person,
                                    color: _outline,
                                    size: 34,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: _onSurface,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        if (username.isNotEmpty) ...[
                          Text(
                            '@$username',
                            style: const TextStyle(
                              color: _primary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _showSettingsSheet(context),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: _surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.settings_outlined,
                          color: _primary,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              Container(height: 1, color: const Color(0xFFF0F1EA)),
              const SizedBox(height: 22),
              _PersonInfoBox(
                label: 'DIRIGINTE',
                icon: Icons.school,
                teacherUid: teacherUid,
                teacherUsername: teacherUsername,
              ),
              const SizedBox(height: 12),
              const _ParentInfoBox(),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SettingsSheet(onLogout: onLogout),
    );
  }
}

void _openFullScreenImage(BuildContext context, String url) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      barrierDismissible: true,
      pageBuilder: (_, __, ___) => _FullScreenImageView(url: url),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _FullScreenImageView extends StatelessWidget {
  final String url;
  const _FullScreenImageView({required this.url});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSheet extends StatelessWidget {
  final VoidCallback onLogout;
  const _SettingsSheet({required this.onLogout});

  @override
  Widget build(BuildContext ctx) {
    return Container(
      decoration: const BoxDecoration(
        color: _surfaceLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: _outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Setări cont',
              style: TextStyle(
                color: _onSurface,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 18),
          _SettingsTile(
            icon: Icons.edit_outlined,
            label: 'Editare profil',
            onTap: () {
              Navigator.pop(ctx);
              _showEditProfileSheet(ctx);
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Deconectează-te',
            danger: true,
            onTap: () {
              Navigator.pop(ctx);
              onLogout();
            },
          ),
        ],
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => const _AccountSettingsDialog(),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// ACCOUNT SETTINGS DIALOG  (Email · Parolă · Imagine Profil)
// ────────────────────────────────────────────────────────────────────────────
class _AccountSettingsDialog extends StatefulWidget {
  const _AccountSettingsDialog();

  @override
  State<_AccountSettingsDialog> createState() => _AccountSettingsDialogState();
}

class _AccountSettingsDialogState extends State<_AccountSettingsDialog> {
  final _emailC = TextEditingController();
  final _passwordC = TextEditingController();
  final _confirmPasswordC = TextEditingController();
  final _verificationCodeC = TextEditingController();
  final _api = AdminApi();
  bool _editingEmail = false;
  bool _editingPassword = false;
  bool _saving = false;
  bool _uploading = false;
  bool _sendingCode = false;
  bool _codeSent = false;
  bool _emailVerified = false;
  String? _profilePictureUrl;
  bool _obscurePassword = true;
  String? _passwordError;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    _emailC.text = user?.email ?? '';
    _passwordC.text = '••••••••••••';
    final uid = user?.uid;
    if (uid != null) {
      FirebaseFirestore.instance.collection('users').doc(uid).get().then((doc) {
        if (mounted) {
          setState(() {
            _profilePictureUrl = (doc.data()?['profilePictureUrl'] ?? '')
                .toString();
            final email = (doc.data()?['personalEmail'] ?? '').toString();
            if (email.isNotEmpty) _emailC.text = email;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _emailC.dispose();
    _passwordC.dispose();
    _confirmPasswordC.dispose();
    _verificationCodeC.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final ref = FirebaseStorage.instance.ref().child(
        'profile_pictures/$uid.jpg',
      );
      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'profilePictureUrl': url,
        'photoUrl': url,
      });

      if (mounted) setState(() => _profilePictureUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Eroare la încărcare: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<bool> _reauthenticate() async {
    final currentPassword = await showDialog<String>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.4),
      builder: (_) => const _ReauthDialog(),
    );

    if (currentPassword == null || currentPassword.isEmpty) return false;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) return false;

    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        ),
      );
      return true;
    } on FirebaseAuthException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Parola actuală este incorectă.')),
        );
      }
      return false;
    }
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    setState(() => _saving = true);
    var closed = false;

    try {
      final updates = <String, dynamic>{};

      if (_editingEmail && _emailC.text.trim().isNotEmpty) {
        if (!_emailVerified) {
          setState(() {
            _emailError = 'Verifică mai întâi email-ul nou.';
            _saving = false;
          });
          return;
        }
        updates['personalEmail'] = _emailC.text.trim();
      }

      if (_editingPassword &&
          _passwordC.text.trim().isNotEmpty &&
          _passwordC.text.trim() != '••••••••••••') {
        if (_passwordC.text.trim() != _confirmPasswordC.text.trim()) {
          setState(() {
            _passwordError = 'Parolele nu se potrivesc.';
            _saving = false;
          });
          return;
        }
        if (_passwordC.text.trim().length < 8) {
          setState(() {
            _passwordError = 'Parola trebuie să aibă cel puțin 8 caractere.';
            _saving = false;
          });
          return;
        }
        setState(() => _passwordError = null);
        final ok = await _reauthenticate();
        if (!ok) return;
        await FirebaseAuth.instance.currentUser?.updatePassword(
          _passwordC.text.trim(),
        );
      }

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .update(updates);
      }

      if (mounted) {
        closed = true;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Setări actualizate.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Eroare: $e')));
      }
    } finally {
      if (!closed && mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 40),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ScrollbarTheme(
          data: ScrollbarThemeData(
            thickness: WidgetStatePropertyAll(2),
            radius: const Radius.circular(2),
            crossAxisMargin: -12,
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Setări Cont',
                          style: TextStyle(
                            color: _onSurface,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Anulează',
                          style: TextStyle(
                            color: _outline,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      ElevatedButton(
                        onPressed: _saving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Salvează',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Divider(color: Color(0xFFF0F1EA)),
                  const SizedBox(height: 18),

                  // ── EMAIL ──
                  const Text(
                    'EMAIL',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.mail_outlined, color: _primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editingEmail
                              ? TextField(
                                  controller: _emailC,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                  ),
                                  decoration: const InputDecoration.collapsed(
                                    hintText: 'Email',
                                  ),
                                )
                              : Text(
                                  _emailC.text,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _editingEmail = !_editingEmail;
                              _codeSent = false;
                              _emailVerified = false;
                              _emailError = null;
                              _verificationCodeC.clear();
                            });
                          },
                          child: Icon(
                            Icons.edit_outlined,
                            color: _outline,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── VERIFICARE EMAIL ──
                  if (_editingEmail && !_emailVerified) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 44,
                            child: ElevatedButton.icon(
                              onPressed: _sendingCode
                                  ? null
                                  : () async {
                                      final email = _emailC.text.trim();
                                      if (email.isEmpty ||
                                          !email.contains('@')) {
                                        setState(
                                          () => _emailError = 'Email invalid.',
                                        );
                                        return;
                                      }
                                      final uid = FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.uid;
                                      if (uid == null) return;
                                      setState(() {
                                        _sendingCode = true;
                                        _emailError = null;
                                      });
                                      try {
                                        await _api.sendVerificationEmail(
                                          uid: uid,
                                          email: email,
                                        );
                                        if (mounted)
                                          setState(() {
                                            _codeSent = true;
                                            _sendingCode = false;
                                          });
                                      } catch (e) {
                                        if (mounted)
                                          setState(() {
                                            _emailError =
                                                'Nu am putut trimite codul.';
                                            _sendingCode = false;
                                          });
                                      }
                                    },
                              icon: _sendingCode
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                _codeSent ? 'Retrimite cod' : 'Trimite cod',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                                textStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_codeSent && !_emailVerified) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: _outline,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Am trimis un cod la ${_emailC.text.trim()}. Introdu-l mai jos.',
                            style: const TextStyle(
                              color: _outline,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.pin_outlined, color: _primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _verificationCodeC,
                              keyboardType: TextInputType.number,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 15,
                                letterSpacing: 4,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration.collapsed(
                                hintText: '••••••',
                                hintStyle: TextStyle(
                                  color: _outlineVariant,
                                  fontSize: 15,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () async {
                              final code = _verificationCodeC.text.trim();
                              if (code.isEmpty) {
                                setState(() => _emailError = 'Introdu codul.');
                                return;
                              }
                              final uid =
                                  FirebaseAuth.instance.currentUser?.uid;
                              if (uid == null) return;
                              setState(() => _emailError = null);
                              try {
                                final result = await _api.verifyEmailCode(
                                  uid: uid,
                                  code: code,
                                );
                                if (result['verified'] == true) {
                                  if (mounted)
                                    setState(() => _emailVerified = true);
                                } else {
                                  if (mounted)
                                    setState(
                                      () => _emailError = 'Cod invalid.',
                                    );
                                }
                              } catch (e) {
                                if (mounted)
                                  setState(() => _emailError = 'Cod invalid.');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Verifică',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_emailVerified) ...[
                    const SizedBox(height: 8),
                    const Row(
                      children: [
                        Icon(Icons.check_circle, color: _primary, size: 18),
                        SizedBox(width: 6),
                        Text(
                          'Email verificat cu succes!',
                          style: TextStyle(
                            color: _primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_emailError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _emailError!,
                      style: const TextStyle(
                        color: Color(0xFF8E3557),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),

                  // ── PAROLĂ ──
                  const Text(
                    'PAROLĂ',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outlined, color: _primary, size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _editingPassword
                              ? TextField(
                                  controller: _passwordC,
                                  autofocus: true,
                                  obscureText: _obscurePassword,
                                  style: const TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                  ),
                                  decoration: InputDecoration.collapsed(
                                    hintText: 'Parola nouă',
                                  ),
                                )
                              : const Text(
                                  '••••••••••••',
                                  style: TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              if (!_editingPassword) {
                                _editingPassword = true;
                                _passwordC.clear();
                                _confirmPasswordC.clear();
                                _passwordError = null;
                              } else {
                                _editingPassword = false;
                                _passwordC.text = '••••••••••••';
                                _confirmPasswordC.clear();
                                _passwordError = null;
                              }
                            });
                          },
                          child: Icon(
                            Icons.edit_outlined,
                            color: _outline,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── CONFIRMARE PAROLĂ ──
                  if (_editingPassword) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_outlined, color: _primary, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _confirmPasswordC,
                              obscureText: _obscurePassword,
                              style: const TextStyle(
                                color: _onSurface,
                                fontSize: 15,
                              ),
                              decoration: const InputDecoration.collapsed(
                                hintText: 'Confirmă parola',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_passwordError != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _passwordError!,
                      style: const TextStyle(
                        color: Color(0xFF8E3557),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),

                  // ── IMAGINE PROFIL ──
                  const Text(
                    'IMAGINE PROFIL',
                    style: TextStyle(
                      color: _primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: _uploading ? null : _pickAndUploadImage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: _surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          // Avatar
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap:
                                    (_profilePictureUrl != null &&
                                        _profilePictureUrl!.isNotEmpty)
                                    ? () => _openFullScreenImage(
                                        context,
                                        _profilePictureUrl!,
                                      )
                                    : null,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child:
                                      (_profilePictureUrl != null &&
                                          _profilePictureUrl!.isNotEmpty)
                                      ? Image.network(
                                          _profilePictureUrl!,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                                width: 56,
                                                height: 56,
                                                color: _surfaceContainerHigh,
                                                child: const Icon(
                                                  Icons.person,
                                                  color: _outline,
                                                  size: 30,
                                                ),
                                              ),
                                        )
                                      : Container(
                                          width: 56,
                                          height: 56,
                                          color: _surfaceContainerHigh,
                                          child: const Icon(
                                            Icons.person,
                                            color: _outline,
                                            size: 30,
                                          ),
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: -4,
                                right: -4,
                                child: Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: _primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _surfaceLowest,
                                      width: 2,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.file_upload_outlined,
                                    color: Colors.white,
                                    size: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Schimbă poza de profil',
                                  style: TextStyle(
                                    color: _onSurface,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Folosește o poză clară, doar cu tine, pe un fundal simplu.',
                                  style: TextStyle(
                                    color: _outline,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _uploading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: _primary,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.edit_outlined,
                                  color: _outline,
                                  size: 20,
                                ),
                        ],
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

class _ReauthDialog extends StatefulWidget {
  const _ReauthDialog();

  @override
  State<_ReauthDialog> createState() => _ReauthDialogState();
}

class _ReauthDialogState extends State<_ReauthDialog> {
  final _ctrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        decoration: BoxDecoration(
          color: _surfaceLowest,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirmare identitate',
              style: TextStyle(
                color: _onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Introdu parola actuală pentru a continua.',
              style: TextStyle(color: _outline, fontSize: 13.5, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              obscureText: _obscure,
              autofocus: true,
              style: const TextStyle(color: _onSurface, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Parola actuală',
                hintStyle: const TextStyle(color: _outline),
                filled: true,
                fillColor: _surfaceContainerLow,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 13,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFCED8C8),
                    width: 1.2,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: Color(0xFFCED8C8),
                    width: 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: _primary, width: 1.6),
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: _outline,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: _surfaceContainerLow,
                      foregroundColor: _onSurface,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Anulează',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, _ctrl.text),
                    style: TextButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Confirmă',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFF8E3557) : _primary;
    return Material(
      color: danger
          ? const Color(0xFF8E3557).withValues(alpha: 0.07)
          : _surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 14),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileDetailRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: _primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: _primary, size: 28),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _outline,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: _onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PersonInfoBox extends StatelessWidget {
  final String label;
  final IconData icon;
  final String teacherUid;
  final String teacherUsername;

  const _PersonInfoBox({
    required this.label,
    required this.icon,
    required this.teacherUid,
    required this.teacherUsername,
  });

  @override
  Widget build(BuildContext context) {
    if (teacherUid.isEmpty && teacherUsername.isEmpty) {
      return _ProfileDetailRow(label: label, value: 'Nedefinit', icon: icon);
    }

    if (teacherUid.isNotEmpty) {
      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(teacherUid)
            .snapshots(),
        builder: (context, snapshot) {
          final teacherData = snapshot.data?.data() ?? <String, dynamic>{};
          final teacherName = _resolveDisplayName(
            fullName: teacherData['fullName'],
            username: teacherData['username'],
            fallback: teacherUsername,
          );

          return _buildInfoCard(teacherName);
        },
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: teacherUsername.toLowerCase())
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        final teacherData = snapshot.hasData && snapshot.data!.docs.isNotEmpty
            ? snapshot.data!.docs.first.data()
            : const <String, dynamic>{};
        final teacherName = _resolveDisplayName(
          fullName: teacherData['fullName'],
          username: teacherData['username'],
          fallback: teacherUsername,
        );

        return _buildInfoCard(teacherName);
      },
    );
  }

  Widget _buildInfoCard(String name) {
    final displayName = name.trim().isEmpty ? 'Nedefinit' : name.trim();

    return _ProfileDetailRow(label: label, value: displayName, icon: icon);
  }
}

class _ParentInfoBox extends StatelessWidget {
  const _ParentInfoBox();

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      return const _ProfileDetailRow(
        label: 'PÂRINTE / TUTORE',
        value: 'Nedefinit',
        icon: Icons.family_restroom,
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? <String, dynamic>{};
        final parentIds = List<String>.from(
          userData['parents'] ?? const <String>[],
        ).where((id) => id.trim().isNotEmpty).toList();
        final legacyParentId =
            (userData['parentUid'] ?? userData['parentId'] ?? '')
                .toString()
                .trim();
        final parentId = parentIds.isNotEmpty
            ? parentIds.first
            : legacyParentId;

        if (parentId.isEmpty) {
          return const _ProfileDetailRow(
            label: 'PÂRINTE / TUTORE',
            value: 'Nedefinit',
            icon: Icons.family_restroom,
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(parentId)
              .snapshots(),
          builder: (context, parentSnapshot) {
            final parentData =
                parentSnapshot.data?.data() ?? <String, dynamic>{};
            final displayName = _resolveDisplayName(
              fullName: parentData['fullName'],
              username: parentData['username'],
              fallback: parentId,
            );

            return _ProfileDetailRow(
              label: 'PÂRINTE / TUTORE',
              value: displayName,
              icon: Icons.family_restroom,
            );
          },
        );
      },
    );
  }
}

String _toRoman(int n) {
  if (n <= 0) return n.toString();
  const vals = [10, 9, 5, 4, 1];
  const syms = ['X', 'IX', 'V', 'IV', 'I'];
  var result = '';
  var num = n;
  for (var i = 0; i < vals.length; i++) {
    while (num >= vals[i]) {
      result += syms[i];
      num -= vals[i];
    }
  }
  return result;
}

String _classToRoman(String classId) {
  final match = RegExp(r'^(\d+)\s*([A-Za-z]*)$').firstMatch(classId.trim());
  if (match == null) return classId;
  final num = int.tryParse(match.group(1) ?? '') ?? 0;
  final letter = (match.group(2) ?? '').toUpperCase();
  final roman = _toRoman(num);
  return letter.isNotEmpty ? 'a $roman-a $letter' : 'a $roman-a';
}

String _resolveDisplayName({
  required Object? fullName,
  required Object? username,
  required String fallback,
}) {
  final normalizedFullName = (fullName ?? '').toString().trim();
  if (normalizedFullName.isNotEmpty) {
    return normalizedFullName;
  }

  final normalizedUsername = (username ?? '').toString().trim();
  if (normalizedUsername.isNotEmpty) {
    return normalizedUsername;
  }

  return fallback.trim();
}

class _ScheduleRowData {
  final String dayName;
  final String intervalText;
  final int dayNumber;

  const _ScheduleRowData({
    required this.dayName,
    required this.intervalText,
    required this.dayNumber,
  });
}

List<_ScheduleRowData> _buildScheduleRows(Map<String, dynamic> classData) {
  final result = <_ScheduleRowData>[];
  final schedule = classData['schedule'];

  if (schedule is Map) {
    const dayMap = {
      1: 'Luni',
      2: 'Marți',
      3: 'Miercuri',
      4: 'Joi',
      5: 'Vineri',
    };

    final dayKeys = <int>[];
    for (final key in schedule.keys) {
      final day = int.tryParse(key.toString());
      if (day != null && day >= 1 && day <= 5) {
        dayKeys.add(day);
      }
    }
    dayKeys.sort();

    for (final day in dayKeys) {
      final row = schedule['$day'];
      if (row is Map) {
        final start = (row['start'] ?? '').toString().trim();
        final end = (row['end'] ?? '').toString().trim();
        if (start.isNotEmpty && end.isNotEmpty) {
          result.add(
            _ScheduleRowData(
              dayName: dayMap[day] ?? 'Ziua $day',
              intervalText: '$start - $end',
              dayNumber: day,
            ),
          );
        }
      }
    }
  }

  if (result.isNotEmpty) {
    return result;
  }

  final oldStart = (classData['noExitStart'] ?? '').toString().trim();
  final oldEnd = (classData['noExitEnd'] ?? '').toString().trim();
  final oldDays = classData['noExitDays'];

  if (oldStart.isEmpty || oldEnd.isEmpty || oldDays is! List) {
    return const [];
  }

  const dayMap = {1: 'Luni', 2: 'Marți', 3: 'Miercuri', 4: 'Joi', 5: 'Vineri'};

  final normalizedDays = oldDays.whereType<int>().toList()..sort();
  return normalizedDays
      .where((day) => day >= 1 && day <= 5)
      .map(
        (day) => _ScheduleRowData(
          dayName: dayMap[day] ?? 'Ziua $day',
          intervalText: '$oldStart - $oldEnd',
          dayNumber: day,
        ),
      )
      .toList();
}

class _ScheduleRow extends StatelessWidget {
  final String dayName;
  final String intervalText;
  final int rowDayNumber;

  const _ScheduleRow({
    required this.dayName,
    required this.intervalText,
    required this.rowDayNumber,
  });

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now().weekday; // 1=Mon..7=Sun, but 6=Sat, 7=Sun
    final isToday = rowDayNumber == today;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isToday ? _primary : _surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            dayName,
            style: TextStyle(
              color: isToday ? Colors.white : _onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Text(
            intervalText,
            style: TextStyle(
              color: isToday ? Colors.white : _onSurface,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
