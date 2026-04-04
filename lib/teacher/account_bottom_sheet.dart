import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../admin/services/admin_api.dart';
import '../core/session.dart';
import '../student/logout_dialog.dart';

const _primary = Color(0xFF0D631B);
const _surfaceLowest = Color(0xFFFFFFFF);
const _surfaceContainerLow = Color(0xFFF0F4E9);
const _outline = Color(0xFF5A6B5C);
const _outlineVariant = Color(0xFFC8D1C2);
const _onSurface = Color(0xFF111811);
const _danger = Color(0xFF8E3557);

/// Functia principala care deschide panoul de setari pentru diriginte.
void showAccountBottomSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _SettingsSheet(),
  );
}

class _SettingsSheet extends StatelessWidget {
  const _SettingsSheet();

  Future<void> _logout(BuildContext context) async {
    final shouldLogout = await showStudentLogoutDialog(
      context,
      accentColor: _primary,
      surfaceColor: Colors.white,
      softSurfaceColor: const Color(0xFFEAF2EC),
      titleColor: _primary,
      messageColor: const Color(0xFF3A4A3F),
    );

    if (!shouldLogout) return;
    try {
      await FirebaseAuth.instance.signOut();
      AppSession.clear();
      if (context.mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (_) {}
  }

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
              showDialog<void>(
                context: ctx,
                barrierDismissible: true,
                builder: (_) => const _AccountSettingsDialog(),
              );
            },
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.logout,
            label: 'Deconectează-te',
            danger: true,
            onTap: () => _logout(ctx),
          ),
        ],
      ),
    );
  }
}

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
  bool _sendingCode = false;
  bool _codeSent = false;
  bool _emailVerified = false;
  bool _obscurePassword = true;


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

  Future<bool> _reauthenticate() async {
    final currentPassword = await showDialog<String>(
      context: context,
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
          setState(() => _saving = false);
          return;
        }
        updates['personalEmail'] = _emailC.text.trim();
      }

      if (_editingPassword &&
          _passwordC.text.trim().isNotEmpty &&
          _passwordC.text.trim() != '••••••••••••') {
        if (_passwordC.text.trim() != _confirmPasswordC.text.trim()) {
          setState(() => _saving = false);
          return;
        }
        if (_passwordC.text.trim().length < 8) {
          setState(() => _saving = false);
          return;
        }
        final ok = await _reauthenticate();
        if (!ok) return;
        await FirebaseAuth.instance.currentUser?.updatePassword(_passwordC.text.trim());
      }

      if (updates.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update(updates);
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Eroare: $e')));
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
              color: Colors.black.withOpacity(0.14),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: const Text('Anulează', style: TextStyle(color: _outline)),
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Salvează'),
                  ),
                ],
              ),
              const Divider(height: 24),
              
              // EMAIL
              const Text('EMAIL PERSONAL', style: TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outlined, color: _primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _editingEmail
                          ? TextField(
                              controller: _emailC,
                              autofocus: true,
                              style: const TextStyle(fontSize: 15),
                              decoration: const InputDecoration.collapsed(hintText: 'Email'),
                            )
                          : Text(_emailC.text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: () => setState(() {
                        _editingEmail = !_editingEmail;
                        _codeSent = false;
                        _emailVerified = false;
                        _verificationCodeC.clear();
                      }),
                    ),
                  ],
                ),
              ),
              
              if (_editingEmail && !_emailVerified) ...[
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _sendingCode ? null : _sendVerificationCode,
                  icon: _sendingCode 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_codeSent ? 'Retrimite cod' : 'Trimite cod verificare'),
                  style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
                ),
              ],

              if (_codeSent && !_emailVerified) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _verificationCodeC,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Cod 6 cifre',
                    suffixIcon: TextButton(onPressed: _verifyCode, child: const Text('Verifică')),
                  ),
                ),
              ],

              if (_emailVerified) const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('✓ Email verificat', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 24),
              // PAROLA
              const Text('PAROLĂ', style: TextStyle(color: _primary, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outlined, color: _primary, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _editingPassword
                          ? TextField(
                              controller: _passwordC,
                              obscureText: _obscurePassword,
                              decoration: const InputDecoration.collapsed(hintText: 'Parola nouă'),
                            )
                          : const Text('••••••••••••', style: TextStyle(fontSize: 15)),
                    ),
                    IconButton(
                      icon: Icon(_editingPassword ? Icons.close : Icons.edit_outlined, size: 20),
                      onPressed: () => setState(() {
                        _editingPassword = !_editingPassword;
                        if (!_editingPassword) _passwordC.text = '••••••••••••';
                        else _passwordC.clear();
                      }),
                    ),
                  ],
                ),
              ),
              if (_editingPassword) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _confirmPasswordC,
                  obscureText: _obscurePassword,
                  decoration: const InputDecoration(hintText: 'Confirmă parola nouă'),
                ),
              ],
              
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendVerificationCode() async {
    final email = _emailC.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      return;
    }
    setState(() => _sendingCode = true);
    try {
      await _api.sendVerificationEmail(uid: FirebaseAuth.instance.currentUser!.uid, email: email);
      setState(() { _codeSent = true; _sendingCode = false; });
    } catch (e) {
      setState(() { _sendingCode = false; });
    }
  }

  Future<void> _verifyCode() async {
    final code = _verificationCodeC.text.trim();
    if (code.isEmpty) return;
    try {
      final res = await _api.verifyEmailCode(uid: FirebaseAuth.instance.currentUser!.uid, code: code);
      if (res['verified'] == true) setState(() => _emailVerified = true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cod invalid')));
    }
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
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Confirmare identitate'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Introdu parola actuală pentru a putea face modificări sensibile.'),
          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              hintText: 'Parola actuală',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Anulează')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _ctrl.text),
          style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white),
          child: const Text('Confirmă'),
        ),
      ],
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
    final color = danger ? _danger : _primary;
    return Material(
      color: danger ? color.withOpacity(0.07) : _surfaceContainerLow,
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
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}