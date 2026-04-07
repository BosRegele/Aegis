import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' as xls;
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import 'admin_api.dart';
import 'services/admin_store.dart';

class AdminStudentsPage extends StatefulWidget {
  const AdminStudentsPage({super.key});

  @override
  State<AdminStudentsPage> createState() => _AdminStudentsPageState();
}

class _AdminStudentsPageState extends State<AdminStudentsPage> {
  final store = AdminStore();
  final Random _rng = Random.secure();
  int _currentPage = 0;
  static const int _pageSize = 7;
  final String _searchQuery = '';
  final String _sortBy = 'name';

  String _randPassword(int len) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
    return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Access denied (admin only)")),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF5),
      body: Padding(
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
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE0E8D8), width: 1),
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
                      decoration: const BoxDecoration(color: Color(0xFFF4F9F3)),
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
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
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
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }

                          final docs = [...snap.data!.docs];
                          docs.sort((a, b) {
                            final ad = a.data() as Map;
                            final bd = b.data() as Map;
                            switch (_sortBy) {
                              case 'class':
                                final ac = (ad['classId'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final bc = (bd['classId'] ?? '')
                                    .toString()
                                    .toLowerCase();
                                final cmp = ac.compareTo(bc);
                                if (cmp != 0) return cmp;
                                return (ad['fullName'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .compareTo(
                                      (bd['fullName'] ?? '')
                                          .toString()
                                          .toLowerCase(),
                                    );
                              case 'status':
                                final aIn = ad['inSchool'] == true ? 0 : 1;
                                final bIn = bd['inSchool'] == true ? 0 : 1;
                                final cmp = aIn.compareTo(bIn);
                                if (cmp != 0) return cmp;
                                return (ad['fullName'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .compareTo(
                                      (bd['fullName'] ?? '')
                                          .toString()
                                          .toLowerCase(),
                                    );
                              default:
                                return (ad['fullName'] ?? '')
                                    .toString()
                                    .toLowerCase()
                                    .compareTo(
                                      (bd['fullName'] ?? '')
                                          .toString()
                                          .toLowerCase(),
                                    );
                            }
                          });

                          final filtered = _searchQuery.isEmpty
                              ? docs
                              : docs.where((d) {
                                  final data = d.data() as Map;
                                  final name = (data['fullName'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final user = (data['username'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  final cls = (data['classId'] ?? '')
                                      .toString()
                                      .toLowerCase();
                                  return name.contains(_searchQuery) ||
                                      user.contains(_searchQuery) ||
                                      cls.contains(_searchQuery);
                                }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'Nu există elevi'
                                    : 'Niciun rezultat pentru "$_searchQuery"',
                                style: const TextStyle(
                                  color: Color(0xFF7A9070),
                                  fontSize: 14,
                                ),
                              ),
                            );
                          }

                          final visibleDocs = filtered
                              .skip(_currentPage * _pageSize)
                              .take(_pageSize)
                              .toList();
                          final totalPages = (filtered.length / _pageSize)
                              .ceil();

                          return Column(
                            children: [
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.fromLTRB(
                                    40,
                                    16,
                                    40,
                                    0,
                                  ),
                                  itemCount: visibleDocs.length,
                                  separatorBuilder: (_, _) =>
                                      const SizedBox(height: 12),
                                  itemBuilder: (_, i) {
                                    final d = visibleDocs[i];
                                    final data =
                                        d.data() as Map<String, dynamic>;
                                    final uid = d.id;
                                    final username = (data['username'] ?? uid)
                                        .toString();
                                    final fullName =
                                        (data['fullName'] ?? username)
                                            .toString();
                                    final classId = (data['classId'] ?? '')
                                        .toString();
                                    final inSchool =
                                        data['inSchool'] as bool? ?? false;
                                    final email =
                                        (data['personalEmail'] ?? data['email'])
                                            ?.toString();
                                    final status = (data['status'] ?? 'active')
                                        .toString();
                                    final onboardingComplete =
                                        data['onboardingComplete'] as bool? ??
                                        false;
                                    final emailVerified =
                                        data['emailVerified'] as bool? ?? false;
                                    final passwordChanged =
                                        data['passwordChanged'] as bool? ??
                                        false;
                                    final parentUsernames = List<String>.from(
                                      data['parents'] ?? [],
                                    );
                                    final photoUrl =
                                        (data['photoUrl'] ??
                                                data['avatarUrl'] ??
                                                '')
                                            .toString();

                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
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
                                                  backgroundImage:
                                                      photoUrl.isNotEmpty
                                                      ? NetworkImage(photoUrl)
                                                            as ImageProvider
                                                      : null,
                                                  child: photoUrl.isEmpty
                                                      ? Text(
                                                          _initials(fullName),
                                                          style:
                                                              const TextStyle(
                                                                color: Color(
                                                                  0xFF1A1A1A,
                                                                ),
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w800,
                                                                fontSize: 13,
                                                              ),
                                                        )
                                                      : null,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        fullName,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          fontSize: 14,
                                                          color: Color(
                                                            0xFF111111,
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        'Username: $username',
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          color: Color(
                                                            0xFF7A9070,
                                                          ),
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
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        _formatClassName(
                                                          classId,
                                                        ),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Color(
                                                            0xFF2E7D32,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : const Text('-'),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              (email != null &&
                                                      email.isNotEmpty)
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: inSchool
                                                      ? const Color(0xFFDCEEDC)
                                                      : const Color(0xFFFDEBEB),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
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
                                                        ? const Color(
                                                            0xFF2E7D32,
                                                          )
                                                        : const Color(
                                                            0xFFD32F2F,
                                                          ),
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
                                                onPressed: () =>
                                                    _openStudentDialog(
                                                      context,
                                                      uid: uid,
                                                      username: username,
                                                      fullName: fullName,
                                                      classId: classId,
                                                      inSchool: inSchool,
                                                      status: status,
                                                      onboardingComplete:
                                                          onboardingComplete,
                                                      emailVerified:
                                                          emailVerified,
                                                      passwordChanged:
                                                          passwordChanged,
                                                      email: email,
                                                      parentUsernames:
                                                          parentUsernames,
                                                      photoUrl: photoUrl,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              if (totalPages > 1)
                                Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    40,
                                    14,
                                    40,
                                    14,
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
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    children: [
                                      _PaginationButton(
                                        icon: Icons.chevron_left_rounded,
                                        enabled: _currentPage > 0,
                                        onTap: () =>
                                            setState(() => _currentPage--),
                                      ),
                                      const SizedBox(width: 4),
                                      ..._buildPageButtons(totalPages),
                                      const SizedBox(width: 4),
                                      _PaginationButton(
                                        icon: Icons.chevron_right_rounded,
                                        enabled: _currentPage < totalPages - 1,
                                        onTap: () =>
                                            setState(() => _currentPage++),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          );
                        },
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

  List<Widget> _buildPageButtons(int totalPages) {
    final pages = <Widget>[];
    const maxVisible = 5;

    void addPage(int index) {
      pages.add(
        GestureDetector(
          onTap: () => setState(() => _currentPage = index),
          child: Container(
            width: 36,
            height: 36,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: _currentPage == index
                  ? const Color(0xFF424242)
                  : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _currentPage == index
                    ? const Color(0xFF424242)
                    : const Color(0xFFD0D0D0),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _currentPage == index
                    ? Colors.white
                    : const Color(0xFF333333),
              ),
            ),
          ),
        ),
      );
    }

    void addEllipsis() {
      pages.add(
        Container(
          width: 36,
          height: 36,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          alignment: Alignment.center,
          child: const Text(
            '...',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF999999),
            ),
          ),
        ),
      );
    }

    if (totalPages <= maxVisible) {
      for (int i = 0; i < totalPages; i++) {
        addPage(i);
      }
    } else {
      // Always show first page
      addPage(0);

      if (_currentPage > 2) {
        addEllipsis();
      }

      // Pages around current
      final start = (_currentPage - 1).clamp(1, totalPages - 2);
      final end = (_currentPage + 1).clamp(1, totalPages - 2);
      for (int i = start; i <= end; i++) {
        addPage(i);
      }

      if (_currentPage < totalPages - 3) {
        addEllipsis();
      }

      // Always show last page
      addPage(totalPages - 1);
    }

    return pages;
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
      if (numStr == '9') {
        roman = 'IX';
      } else if (numStr == '10') {
        roman = 'X';
      } else if (numStr == '11') {
        roman = 'XI';
      } else if (numStr == '12') {
        roman = 'XII';
      }

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
    String photoUrl = '',
  }) async {
    final addParentC = TextEditingController();
    final renameC = TextEditingController(text: fullName);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, animation, _, child) {
        return BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: 10 * animation.value,
            sigmaY: 10 * animation.value,
          ),
          child: Container(
            color: Colors.black.withValues(alpha: 0.55 * animation.value),
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              ),
              child: child,
            ),
          ),
        );
      },
      pageBuilder: (_, _, _) {
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
        // Class search/dropdown state
        String currentClassId = classId; // mutable — updated after move
        String currentFullName = fullName; // mutable — updated after rename
        List<String> allClassesList = [];
        bool allClassesLoaded = false;

        return StatefulBuilder(
          builder: (ctx, setS) {
            return PopScope(
              canPop: !busy,
              child: Dialog(
                backgroundColor: Colors.transparent,
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 55,
                  vertical: 16,
                ),
                child: Container(
                  constraints: const BoxConstraints(
                    maxWidth: 860,
                    minHeight: 760,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── HEADER ──────────────────────────────────────────────
                      Container(
                        padding: const EdgeInsets.fromLTRB(32, 22, 36, 22),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: Colors.grey.shade200,
                              width: 1,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'Setări Utilizator',
                              style: TextStyle(
                                fontSize: 27,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1A2E1A),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: busy ? null : () => Navigator.pop(ctx),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF5F6771),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 14,
                                ),
                              ),
                              child: const Text(
                                'Anulează',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 20),
                            ElevatedButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final newName = renameC.text.trim();
                                      if (newName.isNotEmpty &&
                                          newName != currentFullName) {
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
                                          return; // stay open to show success message
                                        } catch (e) {
                                          setS(() {
                                            busy = false;
                                            msg = e.toString().replaceFirst(
                                              'Exception: ',
                                              '',
                                            );
                                            msgIsError = true;
                                          });
                                          return;
                                        }
                                      }
                                      if (ctx.mounted) Navigator.pop(ctx);
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2E6B2E),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Salvează modificările',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── SCROLLABLE CONTENT ───────────────────────────────────
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 36, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left: form content
                                  Expanded(
                                    flex: 5,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (msg != null) ...[
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(
                                                maxWidth: 560,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: msgIsError
                                                      ? const Color(0xFFFFEBEB)
                                                      : const Color(0xFFE8F5E0),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: msgIsError
                                                        ? const Color(
                                                            0xFFE57373,
                                                          )
                                                        : const Color(
                                                            0xFF81C784,
                                                          ),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      msgIsError
                                                          ? Icons.error_outline
                                                          : Icons
                                                                .check_circle_outline,
                                                      size: 16,
                                                      color: msgIsError
                                                          ? const Color(
                                                              0xFFE53935,
                                                            )
                                                          : const Color(
                                                              0xFF388E3C,
                                                            ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: SelectableText(
                                                        msg!,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: msgIsError
                                                              ? const Color(
                                                                  0xFFB71C1C,
                                                                )
                                                              : const Color(
                                                                  0xFF1B5E20,
                                                                ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                          ],
                                          // Title + status badge
                                          Row(
                                            children: [
                                              const Text(
                                                'Detalii Elev',
                                                style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFF1A2E1A),
                                                ),
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: onboardingComplete
                                                      ? const Color(0xFFE6EFE8)
                                                      : const Color(0xFFFFEBEB),
                                                  border: Border.all(
                                                    color: onboardingComplete
                                                        ? const Color(
                                                            0xFFC6DAC9,
                                                          )
                                                        : const Color(
                                                            0xFFE8AAAA,
                                                          ),
                                                    width: 1.5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Text(
                                                      onboardingComplete
                                                          ? 'CONT CONFIGURAT'
                                                          : 'CONT NECONFIGURAT',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            onboardingComplete
                                                            ? const Color(
                                                                0xFF2E793A,
                                                              )
                                                            : const Color(
                                                                0xFFC0392B,
                                                              ),
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    if (onboardingComplete)
                                                      _PulsingDot(
                                                        colorA: const Color(
                                                          0xFFC6DAC9,
                                                        ),
                                                        colorB: const Color(
                                                          0xFF2E793A,
                                                        ),
                                                      )
                                                    else
                                                      _PulsingDot(
                                                        colorA: const Color(
                                                          0xFFE8AAAA,
                                                        ),
                                                        colorB: const Color(
                                                          0xFFC0392B,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 20),
                                          // NUME COMPLET
                                          const Text(
                                            'NUME COMPLET',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1,
                                              color: Color(0xFF2A5C30),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            width: double.infinity,
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                            ),
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEBEFE5),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: TextField(
                                              controller: renameC,
                                              textCapitalization:
                                                  TextCapitalization.words,
                                              textAlignVertical:
                                                  TextAlignVertical.center,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF000000),
                                              ),
                                              decoration: InputDecoration(
                                                hintText: currentFullName,
                                                hintStyle: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF000000),
                                                ),
                                                border: InputBorder.none,
                                                isDense: true,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 14,
                                                    ),
                                              ),
                                              onSubmitted: (val) async {
                                                if (busy) return;
                                                final newName = val.trim();
                                                if (newName.isEmpty ||
                                                    newName ==
                                                        currentFullName) {
                                                  return;
                                                }
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
                                          const SizedBox(height: 16),
                                          // USERNAME + EMAIL
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'USERNAME',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 1,
                                                        color: Color(
                                                          0xFF2A5C30,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      width: double.infinity,
                                                      height: 48,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF7F9F3,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        username,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          color: Color(
                                                            0xFF555555,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    const Text(
                                                      'EMAIL',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 1,
                                                        color: Color(
                                                          0xFF2A5C30,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      width: double.infinity,
                                                      height: 48,
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 12,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF7F9F3,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        email ?? '-',
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          color: Color(
                                                            0xFF555555,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          // PĂRINȚI + DIRIGINTE
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              // PĂRINȚI
                                              Expanded(
                                                child: FutureBuilder<QuerySnapshot>(
                                                  future: allParentsLoaded
                                                      ? null
                                                      : FirebaseFirestore
                                                            .instance
                                                            .collection('users')
                                                            .where(
                                                              'role',
                                                              isEqualTo:
                                                                  'parent',
                                                            )
                                                            .get(),
                                                  builder: (_, snap) {
                                                    if (!allParentsLoaded &&
                                                        snap.connectionState ==
                                                            ConnectionState
                                                                .waiting) {
                                                      return const Padding(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              vertical: 10,
                                                            ),
                                                        child:
                                                            LinearProgressIndicator(
                                                              minHeight: 2,
                                                            ),
                                                      );
                                                    }
                                                    if (!allParentsLoaded &&
                                                        snap.connectionState ==
                                                            ConnectionState
                                                                .done &&
                                                        snap.hasData) {
                                                      allParentsLoaded = true;
                                                      allParentsList = snap.data!.docs.map((
                                                        d,
                                                      ) {
                                                        final dd =
                                                            d.data()
                                                                as Map<
                                                                  String,
                                                                  dynamic
                                                                >;
                                                        return {
                                                          'uid': d.id,
                                                          'fullName':
                                                              (dd['fullName'] ??
                                                                      '')
                                                                  .toString(),
                                                          'username':
                                                              (dd['username'] ??
                                                                      '')
                                                                  .toString(),
                                                        };
                                                      }).toList();
                                                      allParentsList.sort(
                                                        (a, b) => a['fullName']!
                                                            .compareTo(
                                                              b['fullName']!,
                                                            ),
                                                      );
                                                    }

                                                    Future<void> setParentSlot(
                                                      int slot,
                                                      String? newUid,
                                                    ) async {
                                                      final oldUid =
                                                          slot < parents.length
                                                          ? parents[slot]
                                                          : null;
                                                      if (oldUid == newUid) {
                                                        return;
                                                      }
                                                      setS(() {
                                                        busy = true;
                                                        msg = null;
                                                      });
                                                      try {
                                                        // remove old
                                                        if (oldUid != null) {
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                'users',
                                                              )
                                                              .doc(uid)
                                                              .update({
                                                                'parents':
                                                                    FieldValue.arrayRemove(
                                                                      [oldUid],
                                                                    ),
                                                              });
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                'users',
                                                              )
                                                              .doc(oldUid)
                                                              .update({
                                                                'children':
                                                                    FieldValue.arrayRemove(
                                                                      [uid],
                                                                    ),
                                                              });
                                                        }
                                                        // add new
                                                        if (newUid != null) {
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                'users',
                                                              )
                                                              .doc(uid)
                                                              .update({
                                                                'parents':
                                                                    FieldValue.arrayUnion(
                                                                      [newUid],
                                                                    ),
                                                              });
                                                          await FirebaseFirestore
                                                              .instance
                                                              .collection(
                                                                'users',
                                                              )
                                                              .doc(newUid)
                                                              .update({
                                                                'children':
                                                                    FieldValue.arrayUnion(
                                                                      [uid],
                                                                    ),
                                                              });
                                                        }
                                                        setS(() {
                                                          busy = false;
                                                          if (oldUid != null) {
                                                            parents.remove(
                                                              oldUid,
                                                            );
                                                          }
                                                          if (newUid != null &&
                                                              !parents.contains(
                                                                newUid,
                                                              )) {
                                                            parents.add(newUid);
                                                          }
                                                          msg =
                                                              'Parentele a fost actualizat.';
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
                                                    }

                                                    Widget parentDropdown(
                                                      int slot,
                                                    ) {
                                                      final currentUid =
                                                          slot < parents.length
                                                          ? parents[slot]
                                                          : null;
                                                      final otherUid =
                                                          slot == 0 &&
                                                              parents.length > 1
                                                          ? parents[1]
                                                          : (slot == 1 &&
                                                                    parents
                                                                        .isNotEmpty
                                                                ? parents[0]
                                                                : null);
                                                      return Container(
                                                        width: double.infinity,
                                                        height: 48,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 10,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: const Color(
                                                            0xFFEBEFE5,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                10,
                                                              ),
                                                        ),
                                                        child: DropdownButtonHideUnderline(
                                                          child: DropdownButton<String>(
                                                            value:
                                                                allParentsList.any(
                                                                  (e) =>
                                                                      e['uid'] ==
                                                                      currentUid,
                                                                )
                                                                ? currentUid
                                                                : null,
                                                            isExpanded: true,
                                                            hint: Text(
                                                              currentUid != null
                                                                  ? (allParentsList.firstWhere(
                                                                          (e) =>
                                                                              e['uid'] ==
                                                                              currentUid,
                                                                          orElse: () => {
                                                                            'fullName':
                                                                                currentUid,
                                                                          },
                                                                        )['fullName'] ??
                                                                        currentUid)
                                                                  : 'Niciun părinte',
                                                              style: const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                  0xFF000000,
                                                                ),
                                                              ),
                                                            ),
                                                            icon: const Icon(
                                                              Icons
                                                                  .keyboard_arrow_down_rounded,
                                                              size: 20,
                                                              color: Color(
                                                                0xFF9AB88A,
                                                              ),
                                                            ),
                                                            items: [
                                                              const DropdownMenuItem<
                                                                String
                                                              >(
                                                                value:
                                                                    '__none__',
                                                                child: Text(
                                                                  'Niciun părinte',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    color: Color(
                                                                      0xFF9AB88A,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              ...allParentsList
                                                                  .where(
                                                                    (e) =>
                                                                        e['uid'] !=
                                                                        otherUid,
                                                                  )
                                                                  .map(
                                                                    (
                                                                      e,
                                                                    ) => DropdownMenuItem<String>(
                                                                      value:
                                                                          e['uid'],
                                                                      child: Text(
                                                                        e['fullName']!,
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              16,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color: Color(
                                                                            0xFF000000,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                            ],
                                                            onChanged: busy
                                                                ? null
                                                                : (val) async {
                                                                    final newVal =
                                                                        val ==
                                                                            '__none__'
                                                                        ? null
                                                                        : val;
                                                                    await setParentSlot(
                                                                      slot,
                                                                      newVal,
                                                                    );
                                                                  },
                                                          ),
                                                        ),
                                                      );
                                                    }

                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Text(
                                                          'PĂRINȚI',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            letterSpacing: 1,
                                                            color: Color(
                                                              0xFF2A5C30,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Row(
                                                          children: [
                                                            Expanded(
                                                              child:
                                                                  parentDropdown(
                                                                    0,
                                                                  ),
                                                            ),
                                                            const SizedBox(
                                                              width: 8,
                                                            ),
                                                            Expanded(
                                                              child:
                                                                  parentDropdown(
                                                                    1,
                                                                  ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              // DIRIGINTE
                                              Expanded(
                                                child: FutureBuilder<String>(
                                                  future:
                                                      currentClassId.isNotEmpty
                                                      ? FirebaseFirestore
                                                            .instance
                                                            .collection(
                                                              'classes',
                                                            )
                                                            .doc(currentClassId)
                                                            .get()
                                                            .then((snap) async {
                                                              if (!snap
                                                                  .exists) {
                                                                return '-';
                                                              }
                                                              final d =
                                                                  snap.data()
                                                                      as Map<
                                                                        String,
                                                                        dynamic
                                                                      >;
                                                              final tu =
                                                                  (d['teacherUsername'] ??
                                                                          '')
                                                                      .toString();
                                                              if (tu.isEmpty) {
                                                                return '-';
                                                              }
                                                              final uSnap =
                                                                  await FirebaseFirestore
                                                                      .instance
                                                                      .collection(
                                                                        'users',
                                                                      )
                                                                      .where(
                                                                        'username',
                                                                        isEqualTo:
                                                                            tu,
                                                                      )
                                                                      .limit(1)
                                                                      .get();
                                                              if (uSnap
                                                                  .docs
                                                                  .isEmpty) {
                                                                return tu;
                                                              }
                                                              return (uSnap
                                                                          .docs
                                                                          .first
                                                                          .data()['fullName'] ??
                                                                      tu)
                                                                  .toString();
                                                            })
                                                      : Future.value('-'),
                                                  builder: (_, snap) {
                                                    final diriginte =
                                                        snap.data ?? '…';

                                                    return Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        const Text(
                                                          'DIRIGINTE',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            letterSpacing: 1,
                                                            color: Color(
                                                              0xFF2A5C30,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 6,
                                                        ),
                                                        Container(
                                                          width:
                                                              double.infinity,
                                                          height: 48,
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 12,
                                                                vertical: 12,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFFF7F9F3,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            children: [
                                                              Expanded(
                                                                child: Text(
                                                                  diriginte,
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    color: Color(
                                                                      0xFF555555,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                              const Icon(
                                                                Icons
                                                                    .keyboard_arrow_down_rounded,
                                                                size: 18,
                                                                color: Color(
                                                                  0xFF9AB88A,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        const Text(
                                                          '* Se actualizează automat în funcție de clasă',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontStyle: FontStyle
                                                                .italic,
                                                            color: Color(
                                                              0xFF555555,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 16),
                                          // CLASĂ
                                          const Text(
                                            'CLASĂ',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1,
                                              color: Color(0xFF2A5C30),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
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
                                                        .toList()
                                                      ..sort();
                                              }
                                              return Container(
                                                width: double.infinity,
                                                height: 48,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFFEBEFE5,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: DropdownButtonHideUnderline(
                                                  child: DropdownButton<String>(
                                                    value:
                                                        allClassesList.contains(
                                                          currentClassId,
                                                        )
                                                        ? currentClassId
                                                        : null,
                                                    isExpanded: true,
                                                    hint: Text(
                                                      currentClassId.isNotEmpty
                                                          ? _formatClassName(
                                                              currentClassId,
                                                            )
                                                          : 'Selectează clasă...',
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Color(
                                                          0xFF000000,
                                                        ),
                                                      ),
                                                    ),
                                                    icon: const Icon(
                                                      Icons
                                                          .keyboard_arrow_down_rounded,
                                                      size: 20,
                                                      color: Color(0xFF9AB88A),
                                                    ),
                                                    items: allClassesList
                                                        .map(
                                                          (
                                                            c,
                                                          ) => DropdownMenuItem(
                                                            value: c,
                                                            child: Text(
                                                              _formatClassName(
                                                                c,
                                                              ),
                                                              style: const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                  0xFF000000,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                    onChanged: busy
                                                        ? null
                                                        : (val) async {
                                                            if (val == null ||
                                                                val ==
                                                                    currentClassId) {
                                                              return;
                                                            }
                                                            setS(() {
                                                              busy = true;
                                                              msg = null;
                                                            });
                                                            try {
                                                              await store
                                                                  .moveStudent(
                                                                    uid,
                                                                    val,
                                                                  );
                                                              setS(() {
                                                                busy = false;
                                                                currentClassId =
                                                                    val;
                                                                msg =
                                                                    'Elevul a fost mutat în clasa $val.';
                                                                msgIsError =
                                                                    false;
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
                                                                msgIsError =
                                                                    true;
                                                              });
                                                            }
                                                          },
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  // Right: avatar
                                  SizedBox(
                                    width: 160,
                                    child: Center(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.white,
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(
                                                alpha: 0.12,
                                              ),
                                              blurRadius: 16,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        padding: const EdgeInsets.all(5),
                                        child: CircleAvatar(
                                          radius: 63,
                                          backgroundColor: _avatarColor(
                                            currentFullName,
                                          ),
                                          backgroundImage: photoUrl.isNotEmpty
                                              ? NetworkImage(photoUrl)
                                              : null,
                                          child: photoUrl.isEmpty
                                              ? Text(
                                                  _initials(currentFullName),
                                                  style: const TextStyle(
                                                    color: Color(0xFF1A1A1A),
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 34,
                                                  ),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 72),
                              // Export + Reset Password
                              SizedBox(
                                width: double.infinity,
                                child: Center(
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
                                            Icons.download_outlined,
                                            size: 18,
                                          ),
                                    label: const Text(
                                      'Extrage Date / Resetează Parola',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF7B2D5E),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 22,
                                        horizontal: 36,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final newPass = _randPassword(10);

                                            setS(() {
                                              busy = true;
                                              msg = null;
                                            });
                                            try {
                                              // 1. Export Excel
                                              final excel =
                                                  xls.Excel.createExcel();
                                              final sheet = excel['Elev'];
                                              sheet.appendRow([
                                                xls.TextCellValue(
                                                  'Nume Complet',
                                                ),
                                                xls.TextCellValue('Username'),
                                                xls.TextCellValue('Email'),
                                                xls.TextCellValue('Clasă'),
                                                xls.TextCellValue(
                                                  'Parolă Nouă',
                                                ),
                                              ]);
                                              sheet.appendRow([
                                                xls.TextCellValue(
                                                  currentFullName,
                                                ),
                                                xls.TextCellValue(username),
                                                xls.TextCellValue(email ?? '-'),
                                                xls.TextCellValue(
                                                  _formatClassName(
                                                    currentClassId,
                                                  ),
                                                ),
                                                xls.TextCellValue(newPass),
                                              ]);
                                              final bytes = excel.encode();
                                              if (bytes != null) {
                                                await FileSaver.instance
                                                    .saveFile(
                                                      name: 'elev_$username',
                                                      bytes: Uint8List.fromList(
                                                        bytes,
                                                      ),
                                                      ext: 'xlsx',
                                                      mimeType: MimeType
                                                          .microsoftExcel,
                                                    );
                                              }

                                              // 2. Reset password
                                              await AdminApi().resetPassword(
                                                username: username,
                                                newPassword: newPass,
                                              );

                                              setS(() {
                                                busy = false;
                                                msg =
                                                    'Date exportate și parola a fost resetată automat.';
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
                                  ),
                                ),
                              ),
                              const SizedBox(height: 44),
                              const Divider(
                                height: 1,
                                color: Color(0xFFEEEEEE),
                              ),
                              const SizedBox(height: 28),
                              // Delete
                              SizedBox(
                                width: double.infinity,
                                child: Center(
                                  child: TextButton.icon(
                                    icon: busy
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFFD92D20),
                                            ),
                                          )
                                        : const Icon(
                                            Icons.delete_outline,
                                            size: 22,
                                          ),
                                    label: const Text('Șterge Utilizator'),
                                    style: ButtonStyle(
                                      foregroundColor:
                                          WidgetStateProperty.resolveWith((
                                            states,
                                          ) {
                                            if (states.contains(
                                              WidgetState.disabled,
                                            )) {
                                              return const Color(0xFFED8F88);
                                            }
                                            return const Color(0xFFD92D20);
                                          }),
                                      backgroundColor:
                                          WidgetStateProperty.resolveWith((
                                            states,
                                          ) {
                                            if (states.contains(
                                              WidgetState.hovered,
                                            )) {
                                              return const Color(0xFFF8E4E2);
                                            }
                                            if (states.contains(
                                              WidgetState.pressed,
                                            )) {
                                              return const Color(0xFFF3D6D3);
                                            }
                                            return Colors.transparent;
                                          }),
                                      overlayColor:
                                          WidgetStateProperty.resolveWith((
                                            states,
                                          ) {
                                            if (states.contains(
                                                  WidgetState.hovered,
                                                ) ||
                                                states.contains(
                                                  WidgetState.pressed,
                                                )) {
                                              return Colors.transparent;
                                            }
                                            return null;
                                          }),
                                      elevation: const WidgetStatePropertyAll(
                                        0,
                                      ),
                                      padding: const WidgetStatePropertyAll(
                                        EdgeInsets.symmetric(
                                          horizontal: 24,
                                          vertical: 18,
                                        ),
                                      ),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      textStyle: const WidgetStatePropertyAll(
                                        TextStyle(
                                          fontSize: 17,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final nav = Navigator.of(context);
                                            final ok = await showGeneralDialog<bool>(
                                              context: ctx,
                                              barrierDismissible: true,
                                              barrierLabel:
                                                  'Confirmare stergere elev',
                                              barrierColor: Colors.transparent,
                                              transitionDuration:
                                                  const Duration(
                                                    milliseconds: 220,
                                                  ),
                                              transitionBuilder:
                                                  (_, animation, _, child) {
                                                    return BackdropFilter(
                                                      filter: ImageFilter.blur(
                                                        sigmaX:
                                                            10 *
                                                            animation.value,
                                                        sigmaY:
                                                            10 *
                                                            animation.value,
                                                      ),
                                                      child: Container(
                                                        color: Colors.black
                                                            .withValues(
                                                              alpha:
                                                                  0.55 *
                                                                  animation
                                                                      .value,
                                                            ),
                                                        child: FadeTransition(
                                                          opacity:
                                                              CurvedAnimation(
                                                                parent:
                                                                    animation,
                                                                curve: Curves
                                                                    .easeOut,
                                                              ),
                                                          child: child,
                                                        ),
                                                      ),
                                                    );
                                                  },
                                              pageBuilder: (dialogCtx, _, _) {
                                                return SafeArea(
                                                  child: Center(
                                                    child: Padding(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 24,
                                                            vertical: 24,
                                                          ),
                                                      child: Material(
                                                        color:
                                                            Colors.transparent,
                                                        child: Container(
                                                          constraints:
                                                              const BoxConstraints(
                                                                maxWidth: 520,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: Colors.white,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  28,
                                                                ),
                                                            boxShadow: [
                                                              BoxShadow(
                                                                color: Colors
                                                                    .black
                                                                    .withValues(
                                                                      alpha:
                                                                          0.16,
                                                                    ),
                                                                blurRadius: 32,
                                                                offset:
                                                                    const Offset(
                                                                      0,
                                                                      14,
                                                                    ),
                                                              ),
                                                            ],
                                                          ),
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.fromLTRB(
                                                                  24,
                                                                  24,
                                                                  24,
                                                                  20,
                                                                ),
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .min,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Row(
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Container(
                                                                      width: 52,
                                                                      height:
                                                                          52,
                                                                      decoration: BoxDecoration(
                                                                        color: const Color(
                                                                          0xFFFDEBEB,
                                                                        ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              16,
                                                                            ),
                                                                      ),
                                                                      child: const Icon(
                                                                        Icons
                                                                            .delete_outline_rounded,
                                                                        color: Color(
                                                                          0xFFD92D20,
                                                                        ),
                                                                        size:
                                                                            26,
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 14,
                                                                    ),
                                                                    const Expanded(
                                                                      child: Column(
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Text(
                                                                            'Sterge elev',
                                                                            style: TextStyle(
                                                                              fontSize: 24,
                                                                              fontWeight: FontWeight.w800,
                                                                              color: Color(
                                                                                0xFF1A2E1A,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          SizedBox(
                                                                            height:
                                                                                6,
                                                                          ),
                                                                          Text(
                                                                            'Confirmarea este permanenta si va sterge contul elevului si datele asociate acestuia.',
                                                                            style: TextStyle(
                                                                              fontSize: 13,
                                                                              height: 1.4,
                                                                              color: Color(
                                                                                0xFF7B8A77,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                                const SizedBox(
                                                                  height: 18,
                                                                ),
                                                                Container(
                                                                  width: double
                                                                      .infinity,
                                                                  padding:
                                                                      const EdgeInsets.all(
                                                                        16,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: const Color(
                                                                      0xFFF8FBF6,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          18,
                                                                        ),
                                                                    border: Border.all(
                                                                      color: const Color(
                                                                        0xFFE1ECDB,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      const Text(
                                                                        'Elev selectat',
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              11,
                                                                          fontWeight:
                                                                              FontWeight.w700,
                                                                          letterSpacing:
                                                                              1,
                                                                          color: Color(
                                                                            0xFF6D7B6A,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            10,
                                                                      ),
                                                                      Container(
                                                                        padding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              12,
                                                                          vertical:
                                                                              8,
                                                                        ),
                                                                        decoration: BoxDecoration(
                                                                          color: const Color(
                                                                            0xFFFFE9E7,
                                                                          ),
                                                                          borderRadius: BorderRadius.circular(
                                                                            999,
                                                                          ),
                                                                        ),
                                                                        child: Text(
                                                                          currentFullName,
                                                                          style: const TextStyle(
                                                                            fontSize:
                                                                                13,
                                                                            fontWeight:
                                                                                FontWeight.w800,
                                                                            color: Color(
                                                                              0xFFB42318,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const SizedBox(
                                                                        height:
                                                                            12,
                                                                      ),
                                                                      Text(
                                                                        username,
                                                                        style: const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          color: Color(
                                                                            0xFF667466,
                                                                          ),
                                                                          height:
                                                                              1.4,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 22,
                                                                ),
                                                                Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: OutlinedButton(
                                                                        onPressed: () => Navigator.of(
                                                                          dialogCtx,
                                                                        ).pop(false),
                                                                        style: OutlinedButton.styleFrom(
                                                                          padding: const EdgeInsets.symmetric(
                                                                            vertical:
                                                                                16,
                                                                          ),
                                                                          side: const BorderSide(
                                                                            color: Color(
                                                                              0xFFD7E5D2,
                                                                            ),
                                                                          ),
                                                                          shape: RoundedRectangleBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              14,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        child: const Text(
                                                                          'Anuleaza',
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      width: 12,
                                                                    ),
                                                                    Expanded(
                                                                      child: FilledButton(
                                                                        style: FilledButton.styleFrom(
                                                                          backgroundColor: const Color(
                                                                            0xFFD92D20,
                                                                          ),
                                                                          foregroundColor:
                                                                              Colors.white,
                                                                          padding: const EdgeInsets.symmetric(
                                                                            vertical:
                                                                                16,
                                                                          ),
                                                                          shape: RoundedRectangleBorder(
                                                                            borderRadius: BorderRadius.circular(
                                                                              14,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        onPressed: () => Navigator.of(
                                                                          dialogCtx,
                                                                        ).pop(true),
                                                                        child: const Text(
                                                                          'Sterge elev',
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                            if (ok != true) return;
                                            setS(() {
                                              busy = true;
                                              msg = null;
                                            });
                                            try {
                                              await store.deleteUser(username);
                                              if (mounted) {
                                                nav.pop();
                                              }
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
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),
                    ],
                  ),
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

class _PaginationButton extends StatelessWidget {
  const _PaginationButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled ? const Color(0xFFD0D0D0) : const Color(0xFFE8E8E8),
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 20,
          color: enabled ? const Color(0xFF333333) : const Color(0xFFCCCCCC),
        ),
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color colorA;
  final Color colorB;
  const _PulsingDot({required this.colorA, required this.colorB});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _color;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _color = ColorTween(
      begin: widget.colorA,
      end: widget.colorB,
    ).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _color,
      builder: (_, _) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: _color.value, shape: BoxShape.circle),
      ),
    );
  }
}
