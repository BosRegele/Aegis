import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';
import 'services/admin_store.dart';

class AdminTeachersPage extends StatefulWidget {
  const AdminTeachersPage({super.key});

  @override
  State<AdminTeachersPage> createState() => _AdminTeachersPageState();
}

class _AdminTeachersPageState extends State<AdminTeachersPage> {
  final store = AdminStore();
  int _currentPage = 0;
  static const int _pageSize = 7;
  String _searchQuery = '';
  String _sortBy = 'name';

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
              'Diriginți',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A2E1A),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Gestionează și monitorizează activitatea cadrelor didactice, clasele acestora și detaliile conturilor într-o vizualizare centrală.',
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
                                      'Caută diriginte după nume, username sau clasă...',
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
                                    value: 'class',
                                    child: Text('Sortare: Clasă'),
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
                          Expanded(
                            flex: 5,
                            child: _colHeader('NUME DIRIGINTE'),
                          ),
                          Expanded(
                            flex: 2,
                            child: Center(child: _colHeader('CLASĂ')),
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
                            .where('role', isEqualTo: 'teacher')
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
                            if (_sortBy == 'class') {
                              final ac = (ad['classId'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final bc = (bd['classId'] ?? '')
                                  .toString()
                                  .toLowerCase();
                              final cmp = ac.compareTo(bc);
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
                                    ? 'Nu există diriginți'
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
                                  separatorBuilder: (_, __) =>
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
                                    final email = data['email']?.toString();
                                    final status = (data['status'] ?? 'active')
                                        .toString();
                                    final isActive = status != 'disabled';

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
                                            flex: 1,
                                            child: Center(
                                              child: IconButton(
                                                icon: const Icon(
                                                  Icons.settings_outlined,
                                                  color: Color(0xFF757575),
                                                  size: 22,
                                                ),
                                                onPressed: () =>
                                                    _openTeacherDialog(
                                                      context,
                                                      username: username,
                                                      fullName: fullName,
                                                      classId: classId,
                                                      status: status,
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

  String _formatClassName(String classId) {
    if (classId.isEmpty) return '-';
    if (classId.toLowerCase().startsWith('clasa')) return classId;

    final original = classId.trim();
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF5F6771),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E3B4E),
              fontSize: 15,
            ),
          ),
        ],
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

  Future<void> _openTeacherDialog(
    BuildContext context, {
    required String username,
    required String fullName,
    required String classId,
    required String status,
  }) async {
    await showDialog(
      context: context,
      builder: (_) {
        bool busy = false;
        return StatefulBuilder(
          builder: (ctx, setDialogState) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF7AAF5B), Color(0xFF5A9641)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Text(
                      fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow("Username utilizator", username),
                        _buildDetailRow(
                          "Clasa reprezentată",
                          classId.isEmpty ? "Nespecificată" : classId,
                        ),
                        _buildDetailRow(
                          "Status cont",
                          status == 'disabled'
                              ? 'Dezactivat'
                              : 'Activ (Enabled)',
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: status == 'disabled'
                                      ? const Color(0xFF4CAF50)
                                      : Colors.orangeAccent,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final disable = status != 'disabled';
                                        final nav = Navigator.of(context);
                                        setDialogState(() => busy = true);
                                        await store.setDisabled(
                                          username,
                                          disable,
                                        );
                                        if (!mounted) return;
                                        nav.pop();
                                      },
                                child: Text(
                                  status == 'disabled'
                                      ? "Activează"
                                      : "Dezactivează",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE53935),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                onPressed: busy
                                    ? null
                                    : () async {
                                        final nav = Navigator.of(context);
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: const Text("Ștergere"),
                                            content: Text(
                                              "Sigur dorești să ștergi profesorul: $username?",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text("Anulează"),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text("Șterge"),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok != true) return;
                                        setDialogState(() => busy = true);
                                        try {
                                          await store.deleteUser(username);
                                          if (!mounted) return;
                                          nav.pop();
                                        } catch (_) {
                                          setDialogState(() => busy = false);
                                        }
                                      },
                                child: busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        "Șterge",
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey.withValues(
                                alpha: 0.1,
                              ),
                              foregroundColor: const Color(0xFF2E3B4E),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: const Text(
                              "Închide",
                              style: TextStyle(fontWeight: FontWeight.w700),
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
      },
    );
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
