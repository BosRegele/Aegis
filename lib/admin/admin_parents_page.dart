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

class AdminParentsPage extends StatefulWidget {
  const AdminParentsPage({super.key});

  @override
  State<AdminParentsPage> createState() => _AdminParentsPageState();
}

class _AdminParentsPageState extends State<AdminParentsPage> {
  final store = AdminStore();
  final Random _rng = Random.secure();
  int _currentPage = 0;
  static const int _pageSize = 7;
  String _searchQuery = '';
  String _sortBy = 'name';

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
              'Părinți',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2E1A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Gestionează și monitorizează activitatea părinților, copiii înscriși și detaliile de contact într-o vizualizare centrală.',
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
                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 16, 40, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: TextField(
                                onChanged: (v) => setState(() {
                                  _searchQuery = v.trim().toLowerCase();
                                  _currentPage = 0;
                                }),
                                decoration: InputDecoration(
                                  hintText:
                                      'Caută părinte după nume sau username...',
                                  hintStyle: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFFA0B090),
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.search_rounded,
                                    size: 20,
                                    color: Color(0xFF7A9070),
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFF4F9F3),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDDE8D5),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFDDE8D5),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF5C8B42),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F9F3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFDDE8D5),
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _sortBy,
                                icon: const Icon(
                                  Icons.unfold_more_rounded,
                                  size: 18,
                                  color: Color(0xFF7A9070),
                                ),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2E4A2E),
                                  fontWeight: FontWeight.w600,
                                ),
                                items: const [
                                  DropdownMenuItem(
                                    value: 'name',
                                    child: Text('Sortare: Nume'),
                                  ),
                                  DropdownMenuItem(
                                    value: 'children',
                                    child: Text('Sortare: Nr. elevi'),
                                  ),
                                ],
                                onChanged: (v) => setState(() {
                                  _sortBy = v!;
                                  _currentPage = 0;
                                }),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.fromLTRB(40, 16, 40, 16),
                      decoration: const BoxDecoration(color: Color(0xFFF4F9F3)),
                      child: Row(
                        children: [
                          Expanded(flex: 5, child: _colHeader('NUME PĂRINTE')),
                          Expanded(
                            flex: 3,
                            child: Center(child: _colHeader('ELEVI ATRIBUIȚI')),
                          ),
                          Expanded(
                            flex: 4,
                            child: Center(child: _colHeader('EMAIL')),
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
                            .where('role', isEqualTo: 'parent')
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
                            if (_sortBy == 'children') {
                              final ac = (ad['children'] as List?)?.length ?? 0;
                              final bc = (bd['children'] as List?)?.length ?? 0;
                              final cmp = bc.compareTo(ac);
                              if (cmp != 0) return cmp;
                            }
                            return (ad['fullName'] ?? '')
                                .toString()
                                .toLowerCase()
                                .compareTo(
                                  (bd['fullName'] ?? '')
                                      .toString()
                                      .toLowerCase(),
                                );
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
                                  return name.contains(_searchQuery) ||
                                      user.contains(_searchQuery);
                                }).toList();

                          if (filtered.isEmpty) {
                            return Center(
                              child: Text(
                                _searchQuery.isEmpty
                                    ? 'Nu există părinți'
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
                                    final childrenIds = List<String>.from(
                                      data['children'] ?? [],
                                    );

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
                                                  child: Text(
                                                    _initials(fullName),
                                                    style: const TextStyle(
                                                      color: Color(0xFF1A1A1A),
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 13,
                                                    ),
                                                  ),
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
                                            flex: 3,
                                            child: Align(
                                              alignment: Alignment.center,
                                              child: childrenIds.isEmpty
                                                  ? Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 14,
                                                            vertical: 6,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF5F5F5,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: const Text(
                                                        'NEATRIBUIT',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: Color(
                                                            0xFF9E9E9E,
                                                          ),
                                                        ),
                                                      ),
                                                    )
                                                  : FutureBuilder<
                                                      List<DocumentSnapshot>
                                                    >(
                                                      future: Future.wait(
                                                        childrenIds.map(
                                                          (id) =>
                                                              FirebaseFirestore
                                                                  .instance
                                                                  .collection(
                                                                    'users',
                                                                  )
                                                                  .doc(id)
                                                                  .get(),
                                                        ),
                                                      ),
                                                      builder: (context, csnap) {
                                                        if (!csnap.hasData) {
                                                          return const SizedBox.shrink();
                                                        }
                                                        return Wrap(
                                                          spacing: 4,
                                                          runSpacing: 4,
                                                          children: csnap.data!.map((
                                                            ds,
                                                          ) {
                                                            final md =
                                                                ds.data()
                                                                    as Map<
                                                                      String,
                                                                      dynamic
                                                                    >? ??
                                                                {};
                                                            final name =
                                                                (md['fullName'] ??
                                                                        md['username'] ??
                                                                        ds.id)
                                                                    .toString();
                                                            return Container(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        10,
                                                                    vertical: 5,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color:
                                                                    const Color(
                                                                      0xFFDCEEDC,
                                                                    ),
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      20,
                                                                    ),
                                                              ),
                                                              child: Text(
                                                                name,
                                                                style: const TextStyle(
                                                                  fontSize: 12,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Color(
                                                                    0xFF2E7D32,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          }).toList(),
                                                        );
                                                      },
                                                    ),
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
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Expanded(
                                            flex: 1,
                                            child: Center(
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.settings_outlined,
                                                  color: Color(0xFF757575),
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
                                                      childrenIds: childrenIds,
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
    required List<String> childrenIds,
  }) async {
    final addChildC = TextEditingController();
    final renameC = TextEditingController(text: fullName);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (dialogContext, animation, secondaryAnimation, child) {
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
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        bool busy = false;
        String? msg;
        bool msgIsError = false;
        final assignedChildren = List<String>.from(childrenIds);
        final studentsFuture = FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'student')
            .get();
        String currentFullName = fullName;

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
                      // ── SCROLLABLE BODY ──────────────────────────────────────
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 36, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // main content row: left form + right avatar
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // LEFT
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
                                          // title + badge
                                          Row(
                                            children: [
                                              const Text(
                                                'Detalii Părinte',
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
                                          // COPII ÎNREGISTRAȚI
                                          const Text(
                                            'COPII ÎNREGISTRAȚI',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 1,
                                              color: Color(0xFF2A5C30),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          FutureBuilder<QuerySnapshot>(
                                            future: studentsFuture,
                                            builder: (_, snap) {
                                              if (!snap.hasData) {
                                                return const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                                  child:
                                                      LinearProgressIndicator(
                                                        minHeight: 2,
                                                      ),
                                                );
                                              }

                                              final allStudents =
                                                  snap.data!.docs.map((d) {
                                                    final data =
                                                        d.data()
                                                            as Map<
                                                              String,
                                                              dynamic
                                                            >;
                                                    return {
                                                      'uid': d.id,
                                                      'fullName':
                                                          (data['fullName'] ??
                                                                  data['username'] ??
                                                                  d.id)
                                                              .toString(),
                                                      'username':
                                                          (data['username'] ??
                                                                  d.id)
                                                              .toString(),
                                                    };
                                                  }).toList()..sort(
                                                    (a, b) => a['fullName']!
                                                        .compareTo(
                                                          b['fullName']!,
                                                        ),
                                                  );

                                              String labelFor(String childUid) {
                                                final hit = allStudents
                                                    .cast<
                                                      Map<String, String>?
                                                    >()
                                                    .firstWhere(
                                                      (s) =>
                                                          s?['uid'] == childUid,
                                                      orElse: () => null,
                                                    );
                                                return hit?['fullName'] ??
                                                    childUid;
                                              }

                                              Future<void> addChild(
                                                String childUid,
                                              ) async {
                                                if (assignedChildren.contains(
                                                  childUid,
                                                )) {
                                                  setS(() {
                                                    msg =
                                                        'Copilul este deja atribuit acestui părinte.';
                                                    msgIsError = true;
                                                  });
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
                                                        'children':
                                                            FieldValue.arrayUnion(
                                                              [childUid],
                                                            ),
                                                      });
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(childUid)
                                                      .update({
                                                        'parents':
                                                            FieldValue.arrayUnion(
                                                              [uid],
                                                            ),
                                                      });
                                                  setS(() {
                                                    assignedChildren.add(
                                                      childUid,
                                                    );
                                                    busy = false;
                                                    msg =
                                                        'Copilul a fost adăugat la părinte.';
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

                                              Future<void> removeChild(
                                                String childUid,
                                              ) async {
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
                                                        'children':
                                                            FieldValue.arrayRemove(
                                                              [childUid],
                                                            ),
                                                      });
                                                  await FirebaseFirestore
                                                      .instance
                                                      .collection('users')
                                                      .doc(childUid)
                                                      .update({
                                                        'parents':
                                                            FieldValue.arrayRemove(
                                                              [uid],
                                                            ),
                                                      });
                                                  setS(() {
                                                    assignedChildren.remove(
                                                      childUid,
                                                    );
                                                    busy = false;
                                                    msg =
                                                        'Copilul a fost eliminat din listă.';
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

                                              final query = addChildC.text
                                                  .trim()
                                                  .toLowerCase();
                                              final suggestions = allStudents
                                                  .where(
                                                    (s) =>
                                                        !assignedChildren
                                                            .contains(
                                                              s['uid'],
                                                            ) &&
                                                        (query.isEmpty ||
                                                            s['fullName']!
                                                                .toLowerCase()
                                                                .contains(
                                                                  query,
                                                                ) ||
                                                            s['username']!
                                                                .toLowerCase()
                                                                .contains(
                                                                  query,
                                                                )),
                                                  )
                                                  .take(8)
                                                  .toList();

                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  // chips
                                                  if (assignedChildren.isEmpty)
                                                    const Text(
                                                      'Niciun copil atribuit',
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        color: Color(
                                                          0xFF6F7B6F,
                                                        ),
                                                      ),
                                                    )
                                                  else
                                                    Wrap(
                                                      spacing: 10,
                                                      runSpacing: 10,
                                                      children: assignedChildren.map((
                                                        childUid,
                                                      ) {
                                                        return Container(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 14,
                                                                vertical: 8,
                                                              ),
                                                          decoration: BoxDecoration(
                                                            color: const Color(
                                                              0xFFD9DED2,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  24,
                                                                ),
                                                          ),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .min,
                                                            children: [
                                                              Text(
                                                                labelFor(
                                                                  childUid,
                                                                ),
                                                                style: const TextStyle(
                                                                  fontSize: 15,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  color: Color(
                                                                    0xFF1A2E1A,
                                                                  ),
                                                                ),
                                                              ),
                                                              const SizedBox(
                                                                width: 10,
                                                              ),
                                                              GestureDetector(
                                                                onTap: busy
                                                                    ? null
                                                                    : () => removeChild(
                                                                        childUid,
                                                                      ),
                                                                child: const Icon(
                                                                  Icons.close,
                                                                  size: 17,
                                                                  color: Color(
                                                                    0xFF1A2E1A,
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  const SizedBox(height: 12),
                                                  // search bar
                                                  Container(
                                                    width: double.infinity,
                                                    height: 48,
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFFEBEFE5,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .manage_search_rounded,
                                                          size: 20,
                                                          color: Color(
                                                            0xFF55636B,
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: TextField(
                                                            controller:
                                                                addChildC,
                                                            onChanged: (_) =>
                                                                setS(() {}),
                                                            decoration: const InputDecoration(
                                                              hintText:
                                                                  'Adaugă un elev nou...',
                                                              hintStyle: TextStyle(
                                                                fontSize: 15,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Color(
                                                                  0xFF8A9792,
                                                                ),
                                                              ),
                                                              border:
                                                                  InputBorder
                                                                      .none,
                                                              isDense: true,
                                                            ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          onPressed:
                                                              busy ||
                                                                  suggestions
                                                                      .isEmpty
                                                              ? null
                                                              : () async {
                                                                  await addChild(
                                                                    suggestions
                                                                        .first['uid']!,
                                                                  );
                                                                  addChildC
                                                                      .clear();
                                                                  setS(() {});
                                                                },
                                                          icon: const Icon(
                                                            Icons
                                                                .add_circle_outline,
                                                            color: Color(
                                                              0xFF0B7A45,
                                                            ),
                                                            size: 24,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  // dropdown suggestions
                                                  if (query.isNotEmpty &&
                                                      suggestions
                                                          .isNotEmpty) ...[
                                                    const SizedBox(height: 8),
                                                    Container(
                                                      width: double.infinity,
                                                      constraints:
                                                          const BoxConstraints(
                                                            maxHeight: 140,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: const Color(
                                                          0xFFF4F9F3,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        border: Border.all(
                                                          color: const Color(
                                                            0xFFDDE8D5,
                                                          ),
                                                        ),
                                                      ),
                                                      child: ListView.separated(
                                                        shrinkWrap: true,
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              vertical: 6,
                                                            ),
                                                        itemCount:
                                                            suggestions.length,
                                                        separatorBuilder:
                                                            (_, _) =>
                                                                const Divider(
                                                                  height: 1,
                                                                  color: Color(
                                                                    0xFFE4ECE1,
                                                                  ),
                                                                ),
                                                        itemBuilder: (_, index) {
                                                          final student =
                                                              suggestions[index];
                                                          return InkWell(
                                                            onTap: busy
                                                                ? null
                                                                : () async {
                                                                    await addChild(
                                                                      student['uid']!,
                                                                    );
                                                                    addChildC
                                                                        .clear();
                                                                    setS(() {});
                                                                  },
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        10,
                                                                  ),
                                                              child: Text(
                                                                '${student['fullName']} (${student['username']})',
                                                                style: const TextStyle(
                                                                  fontSize: 14,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  color: Color(
                                                                    0xFF1A2E1A,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 24),
                                  // RIGHT: avatar
                                  Column(
                                    children: [
                                      const SizedBox(height: 8),
                                      CircleAvatar(
                                        radius: 63,
                                        backgroundColor: _avatarColor(
                                          currentFullName,
                                        ),
                                        child: Text(
                                          _initials(currentFullName),
                                          style: const TextStyle(
                                            color: Color(0xFF1A1A1A),
                                            fontWeight: FontWeight.w800,
                                            fontSize: 32,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 72),
                              // Export / Reset password button
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
                                      'Extrage Date / Reseteaza Parola',
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
                                        vertical: 18,
                                        horizontal: 30,
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
                                              final excel =
                                                  xls.Excel.createExcel();
                                              final sheet = excel['Parinte'];
                                              sheet.appendRow([
                                                xls.TextCellValue(
                                                  'Nume Complet',
                                                ),
                                                xls.TextCellValue('Username'),
                                                xls.TextCellValue('Email'),
                                                xls.TextCellValue(
                                                  'Copii Atribuiti',
                                                ),
                                                xls.TextCellValue(
                                                  'Parola Noua',
                                                ),
                                              ]);
                                              sheet.appendRow([
                                                xls.TextCellValue(
                                                  currentFullName,
                                                ),
                                                xls.TextCellValue(username),
                                                xls.TextCellValue(email ?? '-'),
                                                xls.TextCellValue(
                                                  '${assignedChildren.length}',
                                                ),
                                                xls.TextCellValue(newPass),
                                              ]);
                                              final bytes = excel.encode();
                                              if (bytes != null) {
                                                await FileSaver.instance
                                                    .saveFile(
                                                      name: 'parinte_$username',
                                                      bytes: Uint8List.fromList(
                                                        bytes,
                                                      ),
                                                      ext: 'xlsx',
                                                      mimeType: MimeType
                                                          .microsoftExcel,
                                                    );
                                              }
                                              await AdminApi().resetPassword(
                                                username: username,
                                                newPassword: newPass,
                                              );
                                              setS(() {
                                                busy = false;
                                                msg =
                                                    'Date exportate si parola a fost resetata automat.';
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
                              // Delete button
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
                                    label: const Text('Sterge Utilizator'),
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
                                            final ok = await showGeneralDialog<bool>(
                                              context: ctx,
                                              barrierDismissible: true,
                                              barrierLabel:
                                                  'Confirmare stergere parinte',
                                              barrierColor: Colors.transparent,
                                              transitionDuration:
                                                  const Duration(
                                                    milliseconds: 220,
                                                  ),
                                              transitionBuilder:
                                                  (
                                                    dialogContext,
                                                    animation,
                                                    secondaryAnimation,
                                                    child,
                                                  ) {
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
                                              pageBuilder:
                                                  (
                                                    dialogCtx,
                                                    animation,
                                                    secondaryAnimation,
                                                  ) {
                                                    return SafeArea(
                                                      child: Center(
                                                        child: Padding(
                                                          padding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 24,
                                                                vertical: 24,
                                                              ),
                                                          child: Material(
                                                            color: Colors
                                                                .transparent,
                                                            child: Container(
                                                              constraints:
                                                                  const BoxConstraints(
                                                                    maxWidth:
                                                                        520,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .white,
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
                                                                    blurRadius:
                                                                        32,
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
                                                                          width:
                                                                              52,
                                                                          height:
                                                                              52,
                                                                          decoration: BoxDecoration(
                                                                            color: const Color(
                                                                              0xFFFDEBEB,
                                                                            ),
                                                                            borderRadius: BorderRadius.circular(
                                                                              16,
                                                                            ),
                                                                          ),
                                                                          child: const Icon(
                                                                            Icons.delete_outline_rounded,
                                                                            color: Color(
                                                                              0xFFD92D20,
                                                                            ),
                                                                            size:
                                                                                26,
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              14,
                                                                        ),
                                                                        const Expanded(
                                                                          child: Column(
                                                                            crossAxisAlignment:
                                                                                CrossAxisAlignment.start,
                                                                            children: [
                                                                              Text(
                                                                                'Sterge parinte',
                                                                                style: TextStyle(
                                                                                  fontSize: 24,
                                                                                  fontWeight: FontWeight.w800,
                                                                                  color: Color(
                                                                                    0xFF1A2E1A,
                                                                                  ),
                                                                                ),
                                                                              ),
                                                                              SizedBox(
                                                                                height: 6,
                                                                              ),
                                                                              Text(
                                                                                'Confirmarea este permanenta si va sterge contul parintelui si datele asociate acestuia.',
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
                                                                      height:
                                                                          18,
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
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          const Text(
                                                                            'Parinte selectat',
                                                                            style: TextStyle(
                                                                              fontSize: 11,
                                                                              fontWeight: FontWeight.w700,
                                                                              letterSpacing: 1,
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
                                                                              horizontal: 12,
                                                                              vertical: 8,
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
                                                                                fontSize: 13,
                                                                                fontWeight: FontWeight.w800,
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
                                                                              fontSize: 12,
                                                                              color: Color(
                                                                                0xFF667466,
                                                                              ),
                                                                              height: 1.4,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                    const SizedBox(
                                                                      height:
                                                                          22,
                                                                    ),
                                                                    Row(
                                                                      children: [
                                                                        Expanded(
                                                                          child: OutlinedButton(
                                                                            onPressed: () =>
                                                                                Navigator.of(
                                                                                  dialogCtx,
                                                                                ).pop(
                                                                                  false,
                                                                                ),
                                                                            style: OutlinedButton.styleFrom(
                                                                              padding: const EdgeInsets.symmetric(
                                                                                vertical: 16,
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
                                                                          width:
                                                                              12,
                                                                        ),
                                                                        Expanded(
                                                                          child: FilledButton(
                                                                            style: FilledButton.styleFrom(
                                                                              backgroundColor: const Color(
                                                                                0xFFD92D20,
                                                                              ),
                                                                              foregroundColor: Colors.white,
                                                                              padding: const EdgeInsets.symmetric(
                                                                                vertical: 16,
                                                                              ),
                                                                              shape: RoundedRectangleBorder(
                                                                                borderRadius: BorderRadius.circular(
                                                                                  14,
                                                                                ),
                                                                              ),
                                                                            ),
                                                                            onPressed: () =>
                                                                                Navigator.of(
                                                                                  dialogCtx,
                                                                                ).pop(
                                                                                  true,
                                                                                ),
                                                                            child: const Text(
                                                                              'Sterge parinte',
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
                                              if (ctx.mounted) {
                                                Navigator.pop(ctx);
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    addChildC.dispose();
    renameC.dispose();
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
      addPage(0);
      if (_currentPage > 2) addEllipsis();
      final start = (_currentPage - 1).clamp(1, totalPages - 2);
      final end = (_currentPage + 1).clamp(1, totalPages - 2);
      for (int i = start; i <= end; i++) {
        addPage(i);
      }
      if (_currentPage < totalPages - 3) addEllipsis();
      addPage(totalPages - 1);
    }

    return pages;
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
      builder: (context, child) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: _color.value, shape: BoxShape.circle),
      ),
    );
  }
}
