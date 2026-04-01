import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import 'services/admin_store.dart';

class AdminStudentsPage extends StatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  State<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<AdminStudentsPage> {
  final store = AdminStore();
  bool _showAll = false;
  static const int _initialLimit = 7;

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF5),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Elevi',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2E1A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Gestionează și monitorizează înscrierile elevilor, starea prezenței și detaliile conturilor acestora dintr-o vizualizare centrală.',
              style: TextStyle(fontSize: 13, color: Color(0xFF5A8040)),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(40, 16, 40, 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF4F9F3),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 5, child: _colHeader('NUME ELEV')),
                        Expanded(
                          flex: 2,
                          child: Center(child: _colHeader('CLASĂ')),
                        ),
                        Expanded(
                          flex: 4,
                          child: Center(child: _colHeader('EMAIL')),
                        ),
                        Expanded(
                          flex: 2,
                          child: Center(child: _colHeader('STATUS')),
                        ),
                        Expanded(
                          flex: 1,
                          child: Center(child: _colHeader('SETĂRI')),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE8F5E0)),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('role', isEqualTo: 'student')
                        .snapshots(),
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return Center(
                          child: SelectableText("Eroare:\n${snap.error}"),
                        );
                      }
                      if (!snap.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final docs = [...snap.data!.docs];
                      docs.sort((a, b) {
                        final an = ((a.data() as Map)['fullName'] ?? '')
                            .toString()
                            .toLowerCase();
                        final bn = ((b.data() as Map)['fullName'] ?? '')
                            .toString()
                            .toLowerCase();
                        return an.compareTo(bn);
                      });

                      if (docs.isEmpty) {
                        return const Center(child: Text("Nu există elevi"));
                      }

                      final visibleDocs = _showAll
                          ? docs
                          : docs.take(_initialLimit).toList();
                      final hasMore = docs.length > _initialLimit;

                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(40, 16, 40, 0),
                            itemCount: visibleDocs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) {
                              final d = visibleDocs[i];
                              final data = d.data() as Map<String, dynamic>;
                              final uid = d.id;
                              final username = (data['username'] ?? uid)
                                  .toString();
                              final fullName = (data['fullName'] ?? username)
                                  .toString();
                              final classId = (data['classId'] ?? '')
                                  .toString();
                              final inSchool =
                                  data['inSchool'] as bool? ?? false;
                              final email = data['email']?.toString();
                              final status = (data['status'] ?? 'active')
                                  .toString();
                              final onboardingComplete =
                                  data['onboardingComplete'] as bool? ?? false;
                              final emailVerified =
                                  data['emailVerified'] as bool? ?? false;
                              final passwordChanged =
                                  data['passwordChanged'] as bool? ?? false;
                              final parentUsernames = List<String>.from(
                                data['parents'] ?? [],
                              );
                              final photoUrl =
                                  (data['photoUrl'] ?? data['avatarUrl'] ?? '')
                                      .toString();

                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      flex: 5,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: _avatarColor(
                                              fullName,
                                            ),
                                            backgroundImage: photoUrl.isNotEmpty
                                                ? NetworkImage(photoUrl)
                                                      as ImageProvider
                                                : null,
                                            child: photoUrl.isEmpty
                                                ? Text(
                                                    _initials(fullName),
                                                    style: const TextStyle(
                                                      color: Color(0xFF1A1A1A),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 13,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 14,
                                                    color: Color(0xFF111111),
                                                  ),
                                                ),
                                                Text(
                                                  'Username: $username',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF7A9070),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: classId.isNotEmpty
                                            ? Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFDCEEDC,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Text(
                                                  _formatClassName(classId),
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: Color(0xFF2E7D32),
                                                  ),
                                                ),
                                              )
                                            : const Text('-'),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 4,
                                      child: Text(
                                        (email != null && email.isNotEmpty)
                                            ? email
                                            : '-',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF2E4A2E),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: inSchool
                                                ? const Color(0xFFDCEEDC)
                                                : const Color(0xFFFDEBEB),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            inSchool
                                                ? 'ÎN INCINTĂ'
                                                : 'ÎN AFARA INCINTEI',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: inSchool
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFD32F2F),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Center(
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.settings_outlined,
                                            color: Color(0xFF424242),
                                            size: 22,
                                          ),
                                          onPressed: () => _openStudentDialog(
                                            context,
                                            uid: uid,
                                            username: username,
                                            fullName: fullName,
                                            classId: classId,
                                            inSchool: inSchool,
                                            status: status,
                                            onboardingComplete:
                                                onboardingComplete,
                                            emailVerified: emailVerified,
                                            passwordChanged: passwordChanged,
                                            email: email,
                                            parentUsernames: parentUsernames,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          if (hasMore || _showAll)
                            Container(
                              padding: const EdgeInsets.fromLTRB(
                                40,
                                10,
                                40,
                                12,
                              ),
                              decoration: const BoxDecoration(
                                color: Color(0xFFF4F9F3),
                                border: Border(
                                  top: BorderSide(color: Color(0xFFE8E8E8)),
                                ),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(20),
                                  bottomRight: Radius.circular(20),
                                ),
                              ),
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _showAll = !_showAll),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8E8E8),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _showAll
                                            ? 'Afișează mai puțin'
                                            : 'Afișează mai mult',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF333333),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        _showAll
                                            ? Icons.keyboard_arrow_up
                                            : Icons.keyboard_arrow_down,
                                        size: 18,
                                        color: const Color(0xFF333333),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatClassName(String classId) {
    if (classId.isEmpty) return '-';
    if (classId.toLowerCase().startsWith('clasa')) return classId;

    final original = classId.trim();
    // Match something like "9A", "10 C", "11B", "12"
    final match = RegExp(r'^(\d+)(.*)$').firstMatch(original);

    if (match != null) {
      final numStr = match.group(1)!;
      final letter = match.group(2)!.trim();

      String roman = numStr;
      if (numStr == '9')
        roman = 'IX';
      else if (numStr == '10')
        roman = 'X';
      else if (numStr == '11')
        roman = 'XI';
      else if (numStr == '12')
        roman = 'XII';

      if (letter.isNotEmpty) {
        return 'Clasa a $roman-a $letter';
      }
      return 'Clasa a $roman-a';
    }

    return 'Clasa $original';
  }

  String _initials(String name) {
    final trimmed = name.trim();
    final spaceIdx = trimmed.indexOf(' ');
    if (spaceIdx > 0 && spaceIdx < trimmed.length - 1) {
      return '${trimmed[0]}${trimmed[spaceIdx + 1]}'.toUpperCase();
    }
    return trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
  }

  Color _avatarColor(String name) {
    const colors = [
      Color(0xFF7986CB),
      Color(0xFF4DB6AC),
      Color(0xFFFF8A65),
      Color(0xFFA5D6A7),
      Color(0xFFCE93D8),
      Color(0xFF80DEEA),
      Color(0xFFFFCC80),
      Color(0xFF90A4AE),
    ];
    return colors[name.hashCode.abs() % colors.length];
  }

  Widget _colHeader(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: Color(0xFF006B3D),
        letterSpacing: 1.2,
      ),
    );
  }

  Future<void> _openStudentDialog(
    BuildContext context, {
    required String uid,
    required String username,
    required String fullName,
    required String classId,
    required bool inSchool,
    required String status,
    required bool onboardingComplete,
    required bool emailVerified,
    required bool passwordChanged,
    required String? email,
    required List<String> parentUsernames,
  }) async {
    final addParentC = TextEditingController();
    final renameC = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) {
        bool busy = false;
        String? msg;
        bool msgIsError = false;
        List<String> parents = List<String>.from(parentUsernames);
        final Map<String, String> parentNames = {};
        // Pre-fetch names for already-known parents
        for (final p in parents) {
          FirebaseFirestore.instance.collection('users').doc(p).get().then((s) {
            if (s.exists) {
              parentNames[p] = (s.data()?['fullName'] ?? p).toString();
            }
          });
        }
        // All parents cache for dropdown: uid -> {fullName, username}
        List<Map<String, String>> allParentsList = [];
        bool allParentsLoaded = false;
        String parentSearchQuery = '';
        // Selected parent from dropdown (uid)
        String? selectedParentUid;
        String? selectedParentLabel;
        // Class search/dropdown state
        String currentClassId = classId; // mutable — updated after move
        String currentFullName = fullName; // mutable — updated after rename
        List<String> allClassesList = [];
        bool allClassesLoaded = false;
        String classSearchQuery = '';
        String? selectedClassId;
        String? selectedClassLabel;

        return StatefulBuilder(
          builder: (ctx, setS) {
            Widget sectionHeader(String label) => Padding(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: Color(0xFF9AB88A),
                ),
              ),
            );

            Widget infoRow(String label, Widget value) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF5F6771),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(child: value),
                ],
              ),
            );

            Widget chip(String text, Color bg, Color fg) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: fg,
                ),
              ),
            );

            Widget boolRow(bool val, String yes, String no) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  val ? Icons.check_circle : Icons.cancel_outlined,
                  size: 16,
                  color: val
                      ? const Color(0xFF388E3C)
                      : const Color(0xFFBDBDBD),
                ),
                const SizedBox(width: 6),
                Text(
                  val ? yes : no,
                  style: TextStyle(
                    fontSize: 13,
                    color: val
                        ? const Color(0xFF388E3C)
                        : const Color(0xFF9E9E9E),
                  ),
                ),
              ],
            );

            InputDecoration fieldDeco(String hint) => InputDecoration(
              hintText: hint,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCDE8B0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCDE8B0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                  color: Color(0xFF5C8B42),
                  width: 2,
                ),
              ),
            );

            ButtonStyle greenFilled() => ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5C8B42),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            );

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 540),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── HEADER ──────────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF5C8B42), Color(0xFF40632D)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(24),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.25,
                            ),
                            child: Text(
                              _initials(fullName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@$username',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── SCROLLABLE CONTENT ───────────────────────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Message bar
                            if (msg != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: msgIsError
                                      ? const Color(0xFFFFEBEB)
                                      : const Color(0xFFE8F5E0),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: msgIsError
                                        ? const Color(0xFFE57373)
                                        : const Color(0xFF81C784),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      msgIsError
                                          ? Icons.error_outline
                                          : Icons.check_circle_outline,
                                      size: 16,
                                      color: msgIsError
                                          ? const Color(0xFFE53935)
                                          : const Color(0xFF388E3C),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SelectableText(
                                        msg!,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: msgIsError
                                              ? const Color(0xFFB71C1C)
                                              : const Color(0xFF1B5E20),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // ── INFORMAȚII ──────────────────────────────────
                            sectionHeader('INFORMAȚII'),
                            infoRow(
                              'Clasă',
                              currentClassId.isNotEmpty
                                  ? chip(
                                      currentClassId,
                                      const Color(0xFFE8F5E0),
                                      const Color(0xFF3A6B2A),
                                    )
                                  : const Text(
                                      '-',
                                      style: TextStyle(color: Colors.black38),
                                    ),
                            ),
                            infoRow(
                              'Email',
                              Text(
                                email ?? '-',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2E3B4E),
                                ),
                              ),
                            ),
                            infoRow(
                              'Status',
                              chip(
                                inSchool ? 'În incintă' : 'În afara incintei',
                                inSchool
                                    ? const Color(0xFFE8F5E0)
                                    : const Color(0xFFFFEBEB),
                                inSchool
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFB71C1C),
                              ),
                            ),
                            infoRow(
                              'Onboarding',
                              boolRow(
                                onboardingComplete,
                                'Completat',
                                'Incomplet',
                              ),
                            ),
                            const Divider(height: 28, color: Color(0xFFEEEEEE)),

                            // ── SCHIMBĂ NUME ──────────────────────────────────
                            sectionHeader('SCHIMBĂ NUME'),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: renameC,
                                    textCapitalization:
                                        TextCapitalization.words,
                                    decoration: fieldDeco(
                                      'Nume complet nou...',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: greenFilled(),
                                  onPressed: busy
                                      ? null
                                      : () async {
                                          final newName = renameC.text.trim();
                                          if (newName.isEmpty ||
                                              newName == currentFullName)
                                            return;
                                          setS(() {
                                            busy = true;
                                            msg = null;
                                          });
                                          try {
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(uid)
                                                .update({
                                                  'fullName': newName,
                                                  'updatedAt':
                                                      FieldValue.serverTimestamp(),
                                                });
                                            setS(() {
                                              busy = false;
                                              currentFullName = newName;
                                              renameC.clear();
                                              msg =
                                                  'Numele a fost schimbat în "$newName".';
                                              msgIsError = false;
                                            });
                                          } catch (e) {
                                            setS(() {
                                              busy = false;
                                              msg = e.toString().replaceFirst(
                                                'Exception: ',
                                                '',
                                              );
                                              msgIsError = true;
                                            });
                                          }
                                        },
                                  child: const Text('Salvează'),
                                ),
                              ],
                            ),

                            const Divider(height: 28, color: Color(0xFFEEEEEE)),

                            // ── MUTĂ ÎN CLASĂ ────────────────────────────────
                            sectionHeader('MUTĂ ÎN ALTĂ CLASĂ'),
                            FutureBuilder<QuerySnapshot>(
                              future: allClassesLoaded
                                  ? null
                                  : FirebaseFirestore.instance
                                        .collection('classes')
                                        .get(),
                              builder: (ctx2, snap) {
                                if (!allClassesLoaded &&
                                    snap.connectionState ==
                                        ConnectionState.done &&
                                    snap.hasData) {
                                  allClassesLoaded = true;
                                  allClassesList =
                                      snap.data!.docs
                                          .map((d) => d.id)
                                          .where((id) => id != currentClassId)
                                          .toList()
                                        ..sort();
                                }
                                final filteredClasses = classSearchQuery.isEmpty
                                    ? allClassesList
                                    : allClassesList
                                          .where(
                                            (c) => c.toLowerCase().contains(
                                              classSearchQuery.toLowerCase(),
                                            ),
                                          )
                                          .toList();
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Search field
                                    TextField(
                                      onChanged: (v) => setS(() {
                                        classSearchQuery = v.trim();
                                        selectedClassId = null;
                                        selectedClassLabel = null;
                                      }),
                                      decoration:
                                          fieldDeco(
                                            'Caută clasă (ex: 10A)...',
                                          ).copyWith(
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              size: 18,
                                              color: Color(0xFF9AB88A),
                                            ),
                                          ),
                                    ),
                                    // Selected badge
                                    if (selectedClassId != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E0),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF81C784),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Color(0xFF3A7A40),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                selectedClassLabel ?? '',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF2E3B4E),
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => setS(() {
                                                selectedClassId = null;
                                                selectedClassLabel = null;
                                              }),
                                              child: const Icon(
                                                Icons.close,
                                                size: 15,
                                                color: Color(0xFF888888),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Dropdown list (only when typing)
                                    if (classSearchQuery.isNotEmpty &&
                                        selectedClassId == null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        constraints: const BoxConstraints(
                                          maxHeight: 160,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFCDE8B0),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.07,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child:
                                            snap.connectionState ==
                                                    ConnectionState.waiting &&
                                                !allClassesLoaded
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : filteredClasses.isEmpty
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: Text(
                                                  'Nicio clasă găsită.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black38,
                                                  ),
                                                ),
                                              )
                                            : ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount:
                                                    filteredClasses.length,
                                                itemBuilder: (_, idx) {
                                                  final cid =
                                                      filteredClasses[idx];
                                                  return InkWell(
                                                    onTap: () => setS(() {
                                                      selectedClassId = cid;
                                                      selectedClassLabel = cid;
                                                      classSearchQuery = '';
                                                    }),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 10,
                                                          ),
                                                      child: Text(
                                                        cid,
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    const SizedBox(height: 10),
                                    ElevatedButton(
                                      style: greenFilled(),
                                      onPressed:
                                          (busy || selectedClassId == null)
                                          ? null
                                          : () async {
                                              final nc = selectedClassId!;
                                              setS(() {
                                                busy = true;
                                                msg = null;
                                              });
                                              try {
                                                await store.moveStudent(
                                                  uid,
                                                  nc,
                                                );
                                                setS(() {
                                                  busy = false;
                                                  currentClassId = nc;
                                                  allClassesLoaded = false;
                                                  allClassesList = [];
                                                  selectedClassId = null;
                                                  selectedClassLabel = null;
                                                  classSearchQuery = '';
                                                  msg =
                                                      'Elevul a fost mutat în clasa $nc.';
                                                  msgIsError = false;
                                                });
                                              } catch (e) {
                                                setS(() {
                                                  busy = false;
                                                  msg = e
                                                      .toString()
                                                      .replaceFirst(
                                                        'Exception: ',
                                                        '',
                                                      );
                                                  msgIsError = true;
                                                });
                                              }
                                            },
                                      child: const Text(
                                        'Mută în clasa selectată',
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const Divider(height: 28, color: Color(0xFFEEEEEE)),

                            // ── PĂRINȚI ──────────────────────────────────────
                            sectionHeader('PĂRINȚI ASIGNAȚI'),
                            if (parents.length >= 2)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  'Limită atinsă: maximum 2 părinți.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.orange.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            if (parents.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 10),
                                child: Text(
                                  'Niciun părinte asignat.',
                                  style: TextStyle(
                                    color: Colors.black38,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            else
                              ...parents.map(
                                (p) => Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FFF5),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFCDE8B0),
                                    ),
                                  ),
                                  child: FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(p)
                                        .get(),
                                    builder: (_, snap) {
                                      String display = p;
                                      if (snap.hasData && snap.data!.exists) {
                                        display =
                                            (snap.data!.data()
                                                    as Map<
                                                      String,
                                                      dynamic
                                                    >)['fullName']
                                                ?.toString() ??
                                            p;
                                      }
                                      return Row(
                                        children: [
                                          const Icon(
                                            Icons.family_restroom,
                                            size: 18,
                                            color: Color(0xFF7AAF5B),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              display,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2E3B4E),
                                              ),
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: busy
                                                ? null
                                                : () async {
                                                    setS(() {
                                                      busy = true;
                                                      msg = null;
                                                    });
                                                    try {
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('users')
                                                          .doc(uid)
                                                          .update({
                                                            'parents':
                                                                FieldValue.arrayRemove(
                                                                  [p],
                                                                ),
                                                          });
                                                      await FirebaseFirestore
                                                          .instance
                                                          .collection('users')
                                                          .doc(p)
                                                          .update({
                                                            'children':
                                                                FieldValue.arrayRemove(
                                                                  [uid],
                                                                ),
                                                          });
                                                      setS(() {
                                                        busy = false;
                                                        parents.remove(p);
                                                        msg =
                                                            'Părintele $display a fost eliminat.';
                                                        msgIsError = false;
                                                      });
                                                    } catch (e) {
                                                      setS(() {
                                                        busy = false;
                                                        msg = e
                                                            .toString()
                                                            .replaceFirst(
                                                              'Exception: ',
                                                              '',
                                                            );
                                                        msgIsError = true;
                                                      });
                                                    }
                                                  },
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Color(0xFFB71C1C),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ),
                              ),
                            const SizedBox(height: 8),
                            // ── Searchable parent dropdown ─────────────────
                            FutureBuilder<QuerySnapshot>(
                              future: allParentsLoaded
                                  ? null
                                  : FirebaseFirestore.instance
                                        .collection('users')
                                        .where('role', isEqualTo: 'parent')
                                        .get(),
                              builder: (_, snap) {
                                if (!allParentsLoaded &&
                                    snap.connectionState ==
                                        ConnectionState.done &&
                                    snap.hasData) {
                                  allParentsLoaded = true;
                                  allParentsList = snap.data!.docs.map((d) {
                                    final dd = d.data() as Map<String, dynamic>;
                                    return {
                                      'uid': d.id,
                                      'fullName': (dd['fullName'] ?? '')
                                          .toString(),
                                      'username': (dd['username'] ?? '')
                                          .toString(),
                                    };
                                  }).toList();
                                  allParentsList.sort(
                                    (a, b) => a['fullName']!.compareTo(
                                      b['fullName']!,
                                    ),
                                  );
                                }

                                final filtered = parentSearchQuery.isEmpty
                                    ? allParentsList
                                    : allParentsList.where((e) {
                                        final q = parentSearchQuery
                                            .toLowerCase();
                                        return e['fullName']!
                                                .toLowerCase()
                                                .contains(q) ||
                                            e['username']!
                                                .toLowerCase()
                                                .contains(q);
                                      }).toList();

                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Search field
                                    TextField(
                                      controller: addParentC,
                                      onChanged: (v) => setS(() {
                                        parentSearchQuery = v.trim();
                                        selectedParentUid = null;
                                        selectedParentLabel = null;
                                      }),
                                      decoration:
                                          fieldDeco(
                                            'Caută părinte după nume...',
                                          ).copyWith(
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              size: 18,
                                              color: Color(0xFF9AB88A),
                                            ),
                                            suffixIcon:
                                                addParentC.text.isNotEmpty
                                                ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear,
                                                      size: 16,
                                                    ),
                                                    onPressed: () => setS(() {
                                                      addParentC.clear();
                                                      parentSearchQuery = '';
                                                      selectedParentUid = null;
                                                      selectedParentLabel =
                                                          null;
                                                    }),
                                                  )
                                                : null,
                                          ),
                                    ),
                                    // Selected badge
                                    if (selectedParentUid != null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 6),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE8F5E0),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF81C784),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.check_circle,
                                              size: 16,
                                              color: Color(0xFF3A7A40),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                selectedParentLabel ?? '',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF2E3B4E),
                                                ),
                                              ),
                                            ),
                                            GestureDetector(
                                              onTap: () => setS(() {
                                                selectedParentUid = null;
                                                selectedParentLabel = null;
                                              }),
                                              child: const Icon(
                                                Icons.close,
                                                size: 15,
                                                color: Color(0xFF888888),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Dropdown list (only when typing)
                                    if (parentSearchQuery.isNotEmpty &&
                                        selectedParentUid == null)
                                      Container(
                                        margin: const EdgeInsets.only(top: 2),
                                        constraints: const BoxConstraints(
                                          maxHeight: 160,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFCDE8B0),
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.07,
                                              ),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                        child:
                                            snap.connectionState ==
                                                    ConnectionState.waiting &&
                                                !allParentsLoaded
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : filtered.isEmpty
                                            ? const Padding(
                                                padding: EdgeInsets.all(12),
                                                child: Text(
                                                  'Niciun părinte găsit.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black38,
                                                  ),
                                                ),
                                              )
                                            : ListView.builder(
                                                padding: EdgeInsets.zero,
                                                shrinkWrap: true,
                                                itemCount: filtered.length,
                                                itemBuilder: (_, idx) {
                                                  final e = filtered[idx];
                                                  final alreadyAssigned =
                                                      parents.contains(
                                                        e['uid'],
                                                      );
                                                  return InkWell(
                                                    onTap: alreadyAssigned
                                                        ? null
                                                        : () => setS(() {
                                                            selectedParentUid =
                                                                e['uid'];
                                                            selectedParentLabel =
                                                                '${e['fullName']} (@${e['username']})';
                                                            addParentC.clear();
                                                            parentSearchQuery =
                                                                '';
                                                          }),
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 10,
                                                          ),
                                                      child: Row(
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              '${e['fullName']} (@${e['username']})',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                color:
                                                                    alreadyAssigned
                                                                    ? Colors
                                                                          .black26
                                                                    : const Color(
                                                                        0xFF2E3B4E,
                                                                      ),
                                                              ),
                                                            ),
                                                          ),
                                                          if (alreadyAssigned)
                                                            const Text(
                                                              'asignat',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                color: Color(
                                                                  0xFF9AB88A,
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                              ),
                                      ),
                                    // Add button
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        style: greenFilled(),
                                        icon: const Icon(
                                          Icons.person_add,
                                          size: 16,
                                        ),
                                        label: const Text('Adaugă părinte'),
                                        onPressed:
                                            (busy ||
                                                selectedParentUid == null ||
                                                parents.length >= 2)
                                            ? null
                                            : () async {
                                                final pUid = selectedParentUid!;
                                                setS(() {
                                                  busy = true;
                                                  msg = null;
                                                });
                                                try {
                                                  if (parents.length >= 2) {
                                                    throw Exception(
                                                      'Un elev poate avea maximum 2 părinți asignați.',
                                                    );
                                                  }
                                                  if (parents.contains(pUid)) {
                                                    throw Exception(
                                                      'Părintele este deja asignat.',
                                                    );
                                                  }
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(uid)
                                                      .update({
                                                        'parents':
                                                            FieldValue.arrayUnion(
                                                              [pUid],
                                                            ),
                                                      });
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(pUid)
                                                      .update({
                                                        'children':
                                                            FieldValue.arrayUnion(
                                                              [uid],
                                                            ),
                                                      });
                                                  final label =
                                                      selectedParentLabel ??
                                                      pUid;
                                                  setS(() {
                                                    busy = false;
                                                    parents.add(pUid);
                                                    selectedParentUid = null;
                                                    selectedParentLabel = null;
                                                    msg =
                                                        '$label a fost asignat.';
                                                    msgIsError = false;
                                                  });
                                                } catch (e) {
                                                  setS(() {
                                                    busy = false;
                                                    msg = e
                                                        .toString()
                                                        .replaceFirst(
                                                          'Exception: ',
                                                          '',
                                                        );
                                                    msgIsError = true;
                                                  });
                                                }
                                              },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                            const Divider(height: 28, color: Color(0xFFEEEEEE)),

                            // ── CONT ─────────────────────────────────────────
                            sectionHeader('CONT'),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.delete_outline,
                                        size: 18,
                                      ),
                                label: const Text('Șterge cont'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final ok = await showDialog<bool>(
                                          context: ctx,
                                          builder: (_) => AlertDialog(
                                            title: const Text('Ștergere elev'),
                                            content: Text(
                                              'Ești sigur că vrei să ștergi elevul $fullName?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(ctx, false),
                                                child: const Text('Anulează'),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () =>
                                                    Navigator.pop(ctx, true),
                                                child: const Text('Șterge'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok != true) return;
                                        setS(() {
                                          busy = true;
                                          msg = null;
                                        });
                                        try {
                                          await store.deleteUser(username);
                                          if (mounted) Navigator.pop(context);
                                        } catch (e) {
                                          setS(() {
                                            busy = false;
                                            msg = e.toString().replaceFirst(
                                              'Exception: ',
                                              '',
                                            );
                                            msgIsError = true;
                                          });
                                        }
                                      },
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    // ── FOOTER ───────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      child: TextButton(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.withValues(alpha: 0.1),
                          foregroundColor: const Color(0xFF5F6771),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Închide',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    addParentC.dispose();
    renameC.dispose();
  }
}
