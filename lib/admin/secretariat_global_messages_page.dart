import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/session.dart';

class SecretariatGlobalMessagesPage extends StatefulWidget {
  const SecretariatGlobalMessagesPage({super.key});

  @override
  State<SecretariatGlobalMessagesPage> createState() =>
      _SecretariatGlobalMessagesPageState();
}

class _SecretariatGlobalMessagesPageState
    extends State<SecretariatGlobalMessagesPage> {
  final TextEditingController _messageController = TextEditingController();

  bool _sendToStudents = true;
  bool _sendToParents = true;
  bool _sendToTeachers = true;
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendGlobalMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showSnack('Scrie un mesaj înainte de trimitere.');
      return;
    }

    if (!_sendToStudents && !_sendToParents && !_sendToTeachers) {
      _showSnack('Selectează cel puțin un destinatar.');
      return;
    }

    if (_sending) return;

    setState(() => _sending = true);

    try {
      final now = Timestamp.now();
      final broadcastId =
          '${now.millisecondsSinceEpoch}_${(AppSession.uid ?? '').trim()}';
      final senderUid = (AppSession.uid ?? '').trim();
      final senderName = (AppSession.fullName ?? 'Secretariat').trim();

      final drafts = <_SecretariatMessageDraft>[];

      if (_sendToStudents) {
        drafts.add(
          _SecretariatMessageDraft(
            recipientRole: 'student',
            recipientUid: '',
            studentUid: '',
            studentUsername: '',
            studentName: '',
            classId: '',
            message: message,
            senderUid: senderUid,
            senderName: senderName,
            createdAt: now,
            broadcastId: broadcastId,
            audienceLabel: 'Toți elevii',
          ),
        );
      }

      if (_sendToParents) {
        drafts.add(
          _SecretariatMessageDraft(
            recipientRole: 'parent',
            recipientUid: '',
            studentUid: '',
            studentUsername: '',
            studentName: '',
            classId: '',
            message: message,
            senderUid: senderUid,
            senderName: senderName,
            createdAt: now,
            broadcastId: broadcastId,
            audienceLabel: 'Toți părinții',
          ),
        );
      }

      if (_sendToTeachers) {
        drafts.add(
          _SecretariatMessageDraft(
            recipientRole: 'teacher',
            recipientUid: '',
            studentUid: '',
            studentUsername: '',
            studentName: '',
            classId: '',
            message: message,
            senderUid: senderUid,
            senderName: senderName,
            createdAt: now,
            broadcastId: broadcastId,
            audienceLabel: 'Toți diriginții',
          ),
        );
      }

      await _writeInChunks(drafts);

      if (!mounted) return;
      _showSnack('Mesaj global trimis către rolurile selectate.');
      _messageController.clear();
    } catch (error) {
      if (!mounted) return;
      _showSnack('Eroare la trimitere: $error');
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<int> _writeInChunks(List<_SecretariatMessageDraft> drafts) async {
    if (drafts.isEmpty) return 0;

    const chunkSize = 400;
    int written = 0;

    for (int i = 0; i < drafts.length; i += chunkSize) {
      final chunk = drafts.skip(i).take(chunkSize);
      final batch = FirebaseFirestore.instance.batch();

      for (final draft in chunk) {
        final ref = FirebaseFirestore.instance
            .collection('secretariatMessages')
            .doc(draft.docId);
        batch.set(ref, draft.toMap());
        written++;
      }

      await batch.commit();
    }

    return written;
  }

  void _showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAF5B),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        title: const Text(
          'Mesagerie Globală',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  'Mesajul va fi trimis în căsuțele existente de mesaje, exact ca fluxul de cereri.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF2D3142),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Destinatari',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2D3142),
                      ),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _sendToStudents,
                      title: const Text('Elevi'),
                      onChanged: (value) {
                        setState(() => _sendToStudents = value ?? false);
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _sendToParents,
                      title: const Text('Părinți'),
                      onChanged: (value) {
                        setState(() => _sendToParents = value ?? false);
                      },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _sendToTeachers,
                      title: const Text('Diriginți'),
                      onChanged: (value) {
                        setState(() => _sendToTeachers = value ?? false);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _messageController,
                      minLines: 5,
                      maxLines: 10,
                      decoration: InputDecoration(
                        labelText: 'Mesaj',
                        hintText: 'Scrie mesajul ce va apărea în inbox.',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _sending ? null : _sendGlobalMessage,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(
                          'Trimite global',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5A9641),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF5A9641),
                          disabledForegroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecretariatMessageDraft {
  final String recipientRole;
  final String recipientUid;
  final String studentUid;
  final String studentUsername;
  final String studentName;
  final String classId;
  final String message;
  final Timestamp createdAt;
  final String senderUid;
  final String senderName;
  final String broadcastId;
  final String audienceLabel;

  String get docId => '${broadcastId}_$recipientRole';

  const _SecretariatMessageDraft({
    required this.recipientRole,
    required this.recipientUid,
    required this.studentUid,
    required this.studentUsername,
    required this.studentName,
    required this.classId,
    required this.message,
    required this.createdAt,
    required this.senderUid,
    required this.senderName,
    required this.broadcastId,
    required this.audienceLabel,
  });

  Map<String, dynamic> toMap() {
    return {
      'recipientRole': recipientRole,
      'recipientUid': recipientUid,
      'studentUid': studentUid,
      'studentUsername': studentUsername,
      'studentName': studentName,
      'classId': classId,
      'recipientName': '',
      'recipientUsername': '',
      'message': message,
      'title': 'Mesaj Secretariat',
      'createdAt': createdAt,
      'senderUid': senderUid,
      'senderName': senderName,
      'broadcastId': broadcastId,
      'audienceLabel': audienceLabel,
      'messageType': 'secretariatGlobal',
      'source': 'secretariat',
    };
  }
}
