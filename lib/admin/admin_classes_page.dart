import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:excel/excel.dart' as xls;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/session.dart';
import 'admin_api.dart';
import 'admin_notifications.dart';
import 'admin_parents_page.dart';
import 'admin_students_page.dart';
import 'admin_teachers_page.dart';
import 'admin_turnstiles_page.dart';
import 'admin_vacante.dart' as admin_vacante;
import 'services/admin_store.dart';

Future<T?> _showBlurDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  String? barrierLabel,
  Duration transitionDuration = const Duration(milliseconds: 220),
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: barrierLabel ?? 'dialog',
    barrierColor: Colors.transparent,
    transitionDuration: transitionDuration,
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10 * animation.value,
          sigmaY: 10 * animation.value,
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.48 * animation.value),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
  );
}

Widget _buildDialogStatusBanner(String message, bool isError) {
  return ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 560),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEBEB) : const Color(0xFFE8F5E0),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isError ? const Color(0xFFE57373) : const Color(0xFF81C784),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 16,
            color: isError ? const Color(0xFFE53935) : const Color(0xFF388E3C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              message,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isError
                    ? const Color(0xFFB71C1C)
                    : const Color(0xFF1B5E20),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<bool?> _showDeleteUserConfirmationDialog({
  required BuildContext context,
  required String barrierLabel,
  required String title,
  required String description,
  required String selectedLabel,
  required String selectedName,
  required String selectedSubtitle,
  required String confirmLabel,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 220),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 10 * animation.value,
          sigmaY: 10 * animation.value,
        ),
        child: Container(
          color: Colors.black.withValues(alpha: 0.48 * animation.value),
          child: FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Dialog(
            insetPadding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDEBEB),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFD92D20),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1A2E1A),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                description,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.4,
                                  color: Color(0xFF7B8A77),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FBF6),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE1ECDB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: Color(0xFF6D7B6A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE9E7),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              selectedName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFFB42318),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            selectedSubtitle,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF667466),
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFFD7E5D2)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: const Text('Anuleaza'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFD92D20),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(confirmLabel),
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
      );
    },
  );
}

class AdminClassesPage extends StatefulWidget {
  const AdminClassesPage({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<AdminClassesPage> createState() => _AdminClassesPageState();
}

class _AdminClassesPageState extends State<AdminClassesPage> {
  final api = AdminApi();
  final store = AdminStore();
  final Random _rng = Random.secure();
  bool _sidebarBusy = false;

  String? selectedClassId;
  Map<String, dynamic>? selectedClassData;
  String? _pendingCreatedClassId;
  final Set<String> _optimisticClassIds = <String>{};
  final Set<String> _optimisticDeletedClassIds = <String>{};
  bool _exportBusy = false;

  static const Map<String, String> _dayNames = {
    '1': 'Luni',
    '2': 'Marti',
    '3': 'Miercuri',
    '4': 'Joi',
    '5': 'Vineri',
  };

  int _compareClassLabels(String a, String b) {
    final aTrim = a.trim();
    final bTrim = b.trim();

    final aNumMatch = RegExp(r'^\d+').firstMatch(aTrim);
    final bNumMatch = RegExp(r'^\d+').firstMatch(bTrim);

    final aNum = aNumMatch != null ? int.tryParse(aNumMatch.group(0)!) : null;
    final bNum = bNumMatch != null ? int.tryParse(bNumMatch.group(0)!) : null;

    if (aNum != null && bNum != null && aNum != bNum) {
      return aNum.compareTo(bNum);
    }
    if (aNum != null && bNum == null) return -1;
    if (aNum == null && bNum != null) return 1;

    final aSuffix = aNumMatch != null
        ? aTrim.substring(aNumMatch.end).trim().toUpperCase()
        : aTrim.toUpperCase();
    final bSuffix = bNumMatch != null
        ? bTrim.substring(bNumMatch.end).trim().toUpperCase()
        : bTrim.toUpperCase();

    final suffixCmp = aSuffix.compareTo(bSuffix);
    if (suffixCmp != 0) return suffixCmp;

    return aTrim.toLowerCase().compareTo(bTrim.toLowerCase());
  }

  String _randPassword(int len) {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#';
    return List.generate(len, (_) => chars[_rng.nextInt(chars.length)]).join();
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

  Map<String, Map<String, String>> _existingSchedule(
    Map<String, dynamic>? schedule,
  ) {
    final out = <String, Map<String, String>>{};
    for (final key in _dayNames.keys) {
      final day = schedule?[key] as Map<String, dynamic>?;
      if (day == null) continue;
      final start = (day['start'] ?? '').toString().trim();
      final end = (day['end'] ?? '').toString().trim();
      if (start.isEmpty || end.isEmpty) continue;
      out[key] = {'start': start, 'end': end};
    }
    return out;
  }

  Future<void> _saveSchedule({
    required String classId,
    required Map<String, Map<String, String>> schedule,
  }) async {
    await FirebaseFirestore.instance.collection('classes').doc(classId).update({
      'schedule': schedule,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;

    setState(() {
      final base = Map<String, dynamic>.from(selectedClassData ?? const {});
      base['schedule'] = schedule;
      selectedClassData = base;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Orarul a fost salvat.')));
  }

  Future<void> _replacePage(Widget page) async {
    if (_sidebarBusy || !mounted) return;
    _sidebarBusy = true;
    try {
      await Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
          pageBuilder: (_, _, _) => page,
        ),
      );
    } finally {
      _sidebarBusy = false;
    }
  }

  Future<void> _showLogoutDialog() async {
    await _showBlurDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        bool busy = false;

        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return PopScope(
              canPop: !busy,
              child: Dialog(
                insetPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                backgroundColor: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 520),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.logout_rounded,
                                color: Color(0xFF1F7A36),
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Deconectare',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1A2E1A),
                                    ),
                                  ),
                                  SizedBox(height: 6),
                                  Text(
                                    'Vei iesi din sesiunea curenta si vei reveni la ecranul de autentificare.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.4,
                                      color: Color(0xFF7B8A77),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FBF6),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE1ECDB)),
                          ),
                          child: const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sesiune activa',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                  color: Color(0xFF6D7B6A),
                                ),
                              ),
                              SizedBox(height: 10),
                              Text(
                                'Esti sigur ca vrei sa te deloghezi?',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF213321),
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Actiunea va inchide sesiunea curenta si te va duce inapoi la ecranul principal de autentificare.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF667466),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => Navigator.of(dialogContext).pop(),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFD7E5D2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: const Text('Ramai conectat'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: busy
                                    ? null
                                    : () async {
                                        setDialogState(() => busy = true);
                                        await FirebaseAuth.instance.signOut();
                                        if (!mounted) return;
                                        Navigator.of(
                                          context,
                                        ).popUntil((route) => route.isFirst);
                                      },
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F7422),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Deconecteaza-te'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _syncSelectedClass(List<QueryDocumentSnapshot> docs) {
    final existingIds = docs.map((doc) => doc.id).toSet();
    _optimisticClassIds.removeWhere(existingIds.contains);

    if (docs.isEmpty) {
      if (selectedClassId != null || selectedClassData != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            selectedClassId = null;
            selectedClassData = null;
            _pendingCreatedClassId = null;
          });
        });
      }
      return;
    }

    QueryDocumentSnapshot? selectedDoc;
    if (_pendingCreatedClassId != null) {
      for (final doc in docs) {
        if (doc.id == _pendingCreatedClassId) {
          selectedDoc = doc;
          break;
        }
      }
      if (selectedDoc == null && selectedClassId == _pendingCreatedClassId) {
        return;
      }
    }

    if (selectedClassId != null) {
      for (final doc in docs) {
        if (doc.id == selectedClassId) {
          selectedDoc ??= doc;
          break;
        }
      }
    }

    if (selectedDoc == null) {
      if (selectedClassId != null || selectedClassData != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            selectedClassId = null;
            selectedClassData = null;
            _pendingCreatedClassId = null;
          });
        });
      }
      return;
    }

    final selectedData = selectedDoc.data() as Map<String, dynamic>;
    final shouldUpdate =
        selectedClassId != selectedDoc.id ||
        (_pendingCreatedClassId != null &&
            _pendingCreatedClassId == selectedDoc.id);

    if (!shouldUpdate) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        selectedClassId = selectedDoc!.id;
        selectedClassData = Map<String, dynamic>.from(selectedData);
        if (_pendingCreatedClassId == selectedDoc.id) {
          _pendingCreatedClassId = null;
        }
      });
    });
  }

  String _classLabelFromDoc(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final name = (data['name'] ?? '').toString().trim();
    return name.isEmpty ? doc.id : name;
  }

  Future<void> _showCreateClassDialog() async {
    final controller = TextEditingController();
    String? errorText;
    bool busy = false;

    await _showBlurDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 24,
              ),
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 28,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5E9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              Icons.add_business_rounded,
                              color: Color(0xFF1B5E20),
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Creează clasă nouă',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1A2E1A),
                                  ),
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Adaugă rapid o clasă nouă și selecteaz-o imediat după creare.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                    color: Color(0xFF7B8A77),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: controller,
                        autofocus: true,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Numele clasei',
                          hintText: 'Ex: 9A, 10B, 11 INFO',
                          errorText: errorText,
                          filled: true,
                          fillColor: const Color(0xFFF4F9F3),
                          prefixIcon: const Icon(
                            Icons.class_outlined,
                            color: Color(0xFF6B8E62),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFD8E7D3),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFD8E7D3),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF5C8B42),
                              width: 1.5,
                            ),
                          ),
                        ),
                        onChanged: (_) {
                          setDialogState(() {
                            if (errorText != null) {
                              errorText = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: busy
                                  ? null
                                  : () => Navigator.of(ctx).pop(),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFD7E5D2),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text('Anulează'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      final name = controller.text
                                          .trim()
                                          .toUpperCase();
                                      if (name.isEmpty) {
                                        setDialogState(
                                          () => errorText =
                                              'Introdu numele clasei',
                                        );
                                        return;
                                      }
                                      setDialogState(() => busy = true);
                                      try {
                                        await api.createClass(name: name);
                                        if (mounted) {
                                          setState(() {
                                            _optimisticClassIds.add(name);
                                            selectedClassId = name;
                                            selectedClassData = {'name': name};
                                            _pendingCreatedClassId = name;
                                          });
                                        }
                                        if (ctx.mounted) {
                                          Navigator.of(ctx).pop();
                                        }
                                      } catch (e) {
                                        setDialogState(() {
                                          busy = false;
                                          errorText = e.toString().replaceAll(
                                            RegExp(r'\[.*?\]\s*'),
                                            '',
                                          );
                                        });
                                      }
                                    },
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF0F7422),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Creează clasa'),
                            ),
                          ),
                        ],
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
    controller.dispose();
  }

  Future<void> _exportSelectedClassStudentsReport() async {
    final classId = selectedClassId;
    if (classId == null || classId.isEmpty) return;
    if (_exportBusy) return;

    setState(() => _exportBusy = true);

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: classId)
          .get();

      final students = snap.docs.map((d) {
        final data = d.data();
        return {
          'fullName': (data['fullName'] ?? '').toString(),
          'userId': (data['username'] ?? d.id).toString(),
        };
      }).toList();

      students.sort((a, b) {
        final an = (a['fullName'] ?? '').toLowerCase();
        final bn = (b['fullName'] ?? '').toLowerCase();
        return an.compareTo(bn);
      });

      final exported = <Map<String, String>>[];
      var resetOk = 0;
      var resetFailed = 0;

      for (final s in students) {
        final fullName = (s['fullName'] ?? '').trim();
        final userId = (s['userId'] ?? '').trim().toLowerCase();

        if (userId.isEmpty) {
          resetFailed++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'password': 'RESETARE EȘUATĂ: lipsă ID utilizator',
          });
          continue;
        }

        final newPassword = _randPassword(10);

        try {
          await api.resetPassword(username: userId, newPassword: newPassword);
          resetOk++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'password': newPassword,
          });
        } catch (_) {
          resetFailed++;
          exported.add({
            'fullName': fullName,
            'userId': userId,
            'password': 'RESETARE EȘUATĂ',
          });
        }
      }

      final excel = xls.Excel.createExcel();
      final defaultSheet = excel.getDefaultSheet();
      final sheet = excel[defaultSheet ?? 'Elevi'];

      sheet.appendRow([
        xls.TextCellValue('Clasa'),
        xls.TextCellValue('Nume'),
        xls.TextCellValue('ID utilizator'),
        xls.TextCellValue('Parola'),
      ]);

      for (final s in exported) {
        sheet.appendRow([
          xls.TextCellValue(classId),
          xls.TextCellValue(s['fullName'] ?? ''),
          xls.TextCellValue(s['userId'] ?? ''),
          xls.TextCellValue(s['password'] ?? ''),
        ]);
      }

      final fileName = 'StudentData_$classId';

      if (kIsWeb) {
        // On web, excel.save(fileName:) handles the browser download directly.
        // Using FileSaver on top would cause a second download.
        excel.save(fileName: '$fileName.xlsx');
      } else {
        final bytes = excel.save();
        if (bytes == null) {
          throw Exception('Nu am putut genera fisierul Excel.');
        }
        await FileSaver.instance.saveFile(
          name: fileName,
          bytes: Uint8List.fromList(bytes),
          ext: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Raport pentru clasa $classId descarcat. Resetate: $resetOk, esuate: $resetFailed.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Eroare la export: $e')));
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
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
    required String photoUrl,
  }) async {
    final addParentC = TextEditingController();
    final renameC = TextEditingController(text: fullName);

    await _showBlurDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        bool busy = false;
        String? msg;
        bool msgIsError = false;
        List<String> parents = List<String>.from(parentUsernames);
        final Map<String, String> parentNames = {};
        for (final p in parents) {
          FirebaseFirestore.instance.collection('users').doc(p).get().then((s) {
            if (s.exists) {
              parentNames[p] = (s.data()?['fullName'] ?? p).toString();
            }
          });
        }
        List<Map<String, String>> allParentsList = [];
        bool allParentsLoaded = false;
        String currentClassId = classId;
        String currentFullName = fullName;
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
                                          return;
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
                      if (msg != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildDialogStatusBanner(msg!, msgIsError),
                          ),
                        ),
                      Flexible(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(32, 20, 16, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
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
                                              enabled: !busy,
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
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
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
                                            final ok =
                                                await _showDeleteUserConfirmationDialog(
                                                  context: ctx,
                                                  barrierLabel:
                                                      'Confirmare stergere elev',
                                                  title: 'Sterge elev',
                                                  description:
                                                      'Confirmarea este permanenta si va sterge contul elevului si datele asociate acestuia.',
                                                  selectedLabel:
                                                      'Elev selectat',
                                                  selectedName: currentFullName,
                                                  selectedSubtitle: username,
                                                  confirmLabel: 'Sterge elev',
                                                );
                                            if (ok != true) {
                                              return;
                                            }
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

  Future<void> _openTeacherDialog(
    BuildContext context, {
    required String uid,
    required String username,
    required String fullName,
    required String classId,
    required String status,
    required bool onboardingComplete,
    required String? email,
    required String photoUrl,
  }) async {
    final renameC = TextEditingController(text: fullName);

    await _showBlurDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        bool busy = false;
        String? msg;
        bool msgIsError = false;
        String currentFullName = fullName;
        String currentClassId = classId;
        List<Map<String, String>> allClassesList = [];
        bool allClassesLoaded = false;

        return StatefulBuilder(
          builder: (ctx, setS) => PopScope(
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
                                        return;
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
                    if (msg != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(32, 16, 32, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: _buildDialogStatusBanner(msg!, msgIsError),
                        ),
                      ),
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(32, 20, 36, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Text(
                                            'Detalii Diriginte',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w800,
                                              color: Color(0xFF1A2E1A),
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: onboardingComplete
                                                  ? const Color(0xFFE6EFE8)
                                                  : const Color(0xFFFFEBEB),
                                              border: Border.all(
                                                color: onboardingComplete
                                                    ? const Color(0xFFC6DAC9)
                                                    : const Color(0xFFE8AAAA),
                                                width: 1.5,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  onboardingComplete
                                                      ? 'CONT CONFIGURAT'
                                                      : 'CONT NECONFIGURAT',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                    color: onboardingComplete
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: renameC,
                                          enabled: !busy,
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
                                            final newName = val.trim();
                                            if (newName.isEmpty ||
                                                newName == currentFullName) {
                                              return;
                                            }
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
                                        ),
                                      ),
                                      const SizedBox(height: 16),
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
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1,
                                                    color: Color(0xFF2A5C30),
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
                                                      color: Color(0xFF555555),
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
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1,
                                                    color: Color(0xFF2A5C30),
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
                                                      color: Color(0xFF555555),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
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
                                        builder: (_, snap) {
                                          if (!allClassesLoaded &&
                                              snap.connectionState ==
                                                  ConnectionState.done &&
                                              snap.hasData) {
                                            allClassesLoaded = true;
                                            allClassesList =
                                                snap.data!.docs.map((d) {
                                                  final data =
                                                      d.data()
                                                          as Map<
                                                            String,
                                                            dynamic
                                                          >;
                                                  return {
                                                    'id': d.id,
                                                    'teacherUsername':
                                                        (data['teacherUsername'] ??
                                                                '')
                                                            .toString()
                                                            .trim()
                                                            .toLowerCase(),
                                                  };
                                                }).toList()..sort(
                                                  (a, b) => a['id']!.compareTo(
                                                    b['id']!,
                                                  ),
                                                );
                                          }

                                          final availableClassIds =
                                              allClassesList
                                                  .where((c) {
                                                    final classTeacher =
                                                        (c['teacherUsername'] ??
                                                                '')
                                                            .trim()
                                                            .toLowerCase();
                                                    final classDocId =
                                                        c['id'] ?? '';
                                                    return classTeacher
                                                            .isEmpty ||
                                                        classDocId ==
                                                            currentClassId ||
                                                        classTeacher ==
                                                            username
                                                                .trim()
                                                                .toLowerCase();
                                                  })
                                                  .map((c) => c['id']!)
                                                  .toList();

                                          return Container(
                                            width: double.infinity,
                                            height: 48,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFEBEFE5),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: DropdownButtonHideUnderline(
                                              child: DropdownButton<String>(
                                                value:
                                                    availableClassIds.contains(
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
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF000000),
                                                  ),
                                                ),
                                                icon: const Icon(
                                                  Icons
                                                      .keyboard_arrow_down_rounded,
                                                  size: 20,
                                                  color: Color(0xFF9AB88A),
                                                ),
                                                items: availableClassIds
                                                    .map(
                                                      (c) => DropdownMenuItem(
                                                        value: c,
                                                        child: Text(
                                                          _formatClassName(c),
                                                          style:
                                                              const TextStyle(
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
                                                                username,
                                                                val,
                                                              );
                                                          setS(() {
                                                            busy = false;
                                                            currentClassId =
                                                                val;
                                                            msg =
                                                                'Dirigintele a fost mutat în clasa $val.';
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
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Column(
                                  children: [
                                    const SizedBox(height: 8),
                                    CircleAvatar(
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
                                                fontSize: 32,
                                              ),
                                            )
                                          : null,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 72),
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
                                            final sheet = excel['Diriginte'];
                                            sheet.appendRow([
                                              xls.TextCellValue('Nume Complet'),
                                              xls.TextCellValue('Username'),
                                              xls.TextCellValue('Email'),
                                              xls.TextCellValue('Clasă'),
                                              xls.TextCellValue('Parolă Nouă'),
                                            ]);
                                            sheet.appendRow([
                                              xls.TextCellValue(
                                                currentFullName,
                                              ),
                                              xls.TextCellValue(username),
                                              xls.TextCellValue(email ?? '-'),
                                              xls.TextCellValue(
                                                currentClassId.isNotEmpty
                                                    ? _formatClassName(
                                                        currentClassId,
                                                      )
                                                    : '-',
                                              ),
                                              xls.TextCellValue(newPass),
                                            ]);
                                            final bytes = excel.encode();
                                            if (bytes != null) {
                                              await FileSaver.instance.saveFile(
                                                name: 'diriginte_$username',
                                                bytes: Uint8List.fromList(
                                                  bytes,
                                                ),
                                                ext: 'xlsx',
                                                mimeType:
                                                    MimeType.microsoftExcel,
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
                            const Divider(height: 1, color: Color(0xFFEEEEEE)),
                            const SizedBox(height: 18),
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
                                    elevation: const WidgetStatePropertyAll(0),
                                    padding: const WidgetStatePropertyAll(
                                      EdgeInsets.symmetric(
                                        horizontal: 24,
                                        vertical: 18,
                                      ),
                                    ),
                                    shape: WidgetStatePropertyAll(
                                      RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
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
                                          final ok = await _showDeleteUserConfirmationDialog(
                                            context: ctx,
                                            barrierLabel:
                                                'Confirmare stergere diriginte',
                                            title: 'Sterge diriginte',
                                            description:
                                                'Confirmarea este permanenta si va sterge contul dirigintelui si datele asociate acestuia.',
                                            selectedLabel: 'Diriginte selectat',
                                            selectedName: currentFullName,
                                            selectedSubtitle: username,
                                            confirmLabel: 'Sterge diriginte',
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
          ),
        );
      },
    );

    renameC.dispose();
  }

  Future<void> _deleteSelectedClass({
    required String classId,
    required String className,
  }) async {
    final confirmed = await _showBlurDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDEBEB),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFFD92D20),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sterge clasa',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A2E1A),
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Confirmarea este permanenta si va sterge si datele asociate clasei.',
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: Color(0xFF7B8A77),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FBF6),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE1ECDB)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Clasa selectata',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: Color(0xFF6D7B6A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE9E7),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          className,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFB42318),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Actiunea va elimina clasa din lista si va sterge datele asociate acesteia.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF667466),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: Color(0xFFD7E5D2)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Anuleaza'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD92D20),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('Sterge clasa'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmed != true) return;

    final previousSelectedClassId = selectedClassId;
    final previousSelectedClassData = selectedClassData == null
        ? null
        : Map<String, dynamic>.from(selectedClassData!);

    if (mounted) {
      setState(() {
        _optimisticDeletedClassIds.add(classId);
        _optimisticClassIds.remove(classId);
        if (selectedClassId == classId) {
          selectedClassId = null;
          selectedClassData = null;
        }
      });
    }

    try {
      await api.deleteClassCascade(classId: classId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Clasa $className a fost stearsa.')),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _optimisticDeletedClassIds.remove(classId);
        selectedClassId = previousSelectedClassId;
        selectedClassData = previousSelectedClassData;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Nu am putut sterge clasa selectata.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _optimisticDeletedClassIds.remove(classId);
        selectedClassId = previousSelectedClassId;
        selectedClassData = previousSelectedClassData;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Nu am putut sterge clasa: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text('Acces interzis (doar admin).')),
      );
    }

    final body = Container(
      color: const Color(0xFFF8FFF5),
      child: Column(
        children: [
          if (!widget.embedded) const _ClassesTopBar(),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('classes')
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Center(
                    child: SelectableText('Eroare clase:\n${snap.error}'),
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = [...snap.data!.docs]
                  ..sort(
                    (a, b) => _compareClassLabels(
                      _classLabelFromDoc(a),
                      _classLabelFromDoc(b),
                    ),
                  );

                final snapshotIds = docs.map((doc) => doc.id).toSet();
                _optimisticDeletedClassIds.removeWhere(
                  (id) => !snapshotIds.contains(id),
                );

                final visibleDocs = docs
                    .where(
                      (doc) => !_optimisticDeletedClassIds.contains(doc.id),
                    )
                    .toList();

                final classOptions =
                    <String>{
                          ...visibleDocs.map((doc) => doc.id),
                          ..._optimisticClassIds,
                        }
                        .where(
                          (classId) =>
                              !_optimisticDeletedClassIds.contains(classId),
                        )
                        .toList()
                      ..sort(_compareClassLabels);

                _syncSelectedClass(visibleDocs);

                final selectedId = selectedClassId;
                QueryDocumentSnapshot? selectedDoc;
                for (final d in visibleDocs) {
                  if (d.id == selectedId) {
                    selectedDoc = d;
                    break;
                  }
                }

                final activeClassId = selectedDoc?.id;
                final activeClassData =
                    selectedDoc?.data() as Map<String, dynamic>?;
                final activeClassName = selectedDoc == null
                    ? null
                    : _classLabelFromDoc(selectedDoc);
                final displayedClassId = selectedClassId;
                final displayedClassData = activeClassData ?? selectedClassData;
                final displayedClassName =
                    (displayedClassData?['name'] ?? displayedClassId)
                        ?.toString()
                        .trim();

                if (classOptions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Nu exista clase configurate.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF5B6B58),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _showCreateClassDialog,
                          icon: const Icon(
                            Icons.add_circle_outline_rounded,
                            size: 22,
                          ),
                          label: const Text('Creează Clasă Nouă'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E6B2E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final vertical = constraints.maxWidth < 1080;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (vertical) ...[
                            const Text(
                              'Gestiune Clase',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF223624),
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Administrarea elevilor si configurarea programului operational.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF5A8040),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ] else
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Gestiune Clase',
                                        style: TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF223624),
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Administrarea elevilor si configurarea programului operational.',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF5A8040),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _showCreateClassDialog,
                                      icon: const Icon(
                                        Icons.add_circle_outline_rounded,
                                        size: 22,
                                      ),
                                      label: const Text('Creează Clasă Nouă'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0F7422,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 22,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                ),
                              ],
                            ),
                          const SizedBox(height: 12),
                          if (vertical) ...[
                            _ClassSelectorCard(
                              selectedClassId: selectedClassId,
                              classOptions: classOptions,
                              onDelete: activeClassId == null
                                  ? null
                                  : () => _deleteSelectedClass(
                                      classId: activeClassId,
                                      className:
                                          activeClassName ?? activeClassId,
                                    ),
                              onChanged: (newClassId) {
                                QueryDocumentSnapshot? doc;
                                for (final d in visibleDocs) {
                                  if (d.id == newClassId) {
                                    doc = d;
                                    break;
                                  }
                                }
                                setState(() {
                                  selectedClassId = doc?.id;
                                  selectedClassData = doc == null
                                      ? (newClassId == null
                                            ? null
                                            : <String, dynamic>{
                                                'name': newClassId,
                                              })
                                      : Map<String, dynamic>.from(
                                          doc.data() as Map<String, dynamic>,
                                        );
                                });
                              },
                            ),
                            const SizedBox(height: 14),
                            _ClassTeacherCard(
                              classId: displayedClassId,
                              teacherUsername:
                                  (displayedClassData?['teacherUsername'] ?? '')
                                      .toString(),
                              onOpenTeacherDialog: _openTeacherDialog,
                            ),
                            const SizedBox(height: 14),
                            _ClassStudentsCard(
                              classId: displayedClassId,
                              className: displayedClassName,
                              onOpenStudentDialog: _openStudentDialog,
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: _showCreateClassDialog,
                              icon: const Icon(
                                Icons.add_circle_outline_rounded,
                                size: 22,
                              ),
                              label: const Text('Creează Clasă Nouă'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F7422),
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(56),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 22,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            _ScheduleCard(
                              key: ValueKey('schedule-$displayedClassId'),
                              classId: displayedClassId,
                              selectedClassData: displayedClassData,
                              dayNames: _dayNames,
                              scheduleBuilder: _existingSchedule,
                              onSave: displayedClassId == null
                                  ? null
                                  : (schedule) => _saveSchedule(
                                      classId: displayedClassId,
                                      schedule: schedule,
                                    ),
                            ),
                            const SizedBox(height: 14),
                            _ExportBar(
                              enabled: displayedClassId != null,
                              busy: _exportBusy,
                              onExport: _exportSelectedClassStudentsReport,
                            ),
                          ] else ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: Column(
                                    children: [
                                      _ClassSelectorCard(
                                        selectedClassId: selectedClassId,
                                        classOptions: classOptions,
                                        onDelete: activeClassId == null
                                            ? null
                                            : () => _deleteSelectedClass(
                                                classId: activeClassId,
                                                className:
                                                    activeClassName ??
                                                    activeClassId,
                                              ),
                                        onChanged: (newClassId) {
                                          QueryDocumentSnapshot? doc;
                                          for (final d in visibleDocs) {
                                            if (d.id == newClassId) {
                                              doc = d;
                                              break;
                                            }
                                          }
                                          setState(() {
                                            selectedClassId = doc?.id;
                                            selectedClassData = doc == null
                                                ? (newClassId == null
                                                      ? null
                                                      : <String, dynamic>{
                                                          'name': newClassId,
                                                        })
                                                : Map<String, dynamic>.from(
                                                    doc.data()
                                                        as Map<String, dynamic>,
                                                  );
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 14),
                                      _ClassTeacherCard(
                                        classId: displayedClassId,
                                        teacherUsername:
                                            (displayedClassData?['teacherUsername'] ??
                                                    '')
                                                .toString(),
                                        onOpenTeacherDialog: _openTeacherDialog,
                                      ),
                                      const SizedBox(height: 14),
                                      _ClassStudentsCard(
                                        classId: displayedClassId,
                                        className: displayedClassName,
                                        onOpenStudentDialog: _openStudentDialog,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  flex: 5,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _ScheduleCard(
                                        key: ValueKey(
                                          'schedule-desktop-$displayedClassId',
                                        ),
                                        classId: displayedClassId,
                                        selectedClassData: displayedClassData,
                                        dayNames: _dayNames,
                                        scheduleBuilder: _existingSchedule,
                                        onSave: displayedClassId == null
                                            ? null
                                            : (schedule) => _saveSchedule(
                                                classId: displayedClassId,
                                                schedule: schedule,
                                              ),
                                      ),
                                      const SizedBox(height: 14),
                                      _ExportBar(
                                        enabled: displayedClassId != null,
                                        busy: _exportBusy,
                                        onExport:
                                            _exportSelectedClassStudentsReport,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FFF5),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox.expand(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ClassesSidebar(
                    onMenuTap: () => Navigator.of(context).pop(),
                    onStudentsTap: () =>
                        _replacePage(const AdminStudentsPage()),
                    onPersonalTap: () =>
                        _replacePage(const AdminTeachersPage()),
                    onTurnichetiTap: () => _replacePage(AdminTurnstilesPage()),
                    onClaseTap: () {},
                    onVacanteTap: () =>
                        _replacePage(const admin_vacante.AdminClassesPage()),
                    onParintiTap: () => _replacePage(const AdminParentsPage()),
                    onLogoutTap: _showLogoutDialog,
                  ),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> createUser({
    required String username,
    required String password,
    required String role,
    String? classId,
    required String fullName,
  }) async {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'adminCreateUser',
    );

    await callable.call({
      'username': username,
      'password': password,
      'role': role,
      'classId': classId,
      'fullName': fullName,
    });
  }
}

class _ClassesTopBar extends StatelessWidget {
  const _ClassesTopBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A7A21), Color(0xFF07681C)],
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Clase & Elevi',
            style: TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF228A37),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: const Row(
                    children: [
                      Icon(Icons.search, color: Color(0xFF9FDCAD), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Cauta inregistrari...',
                          style: TextStyle(
                            color: Color(0xFF9FDCAD),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const AdminNotificationBell(),
        ],
      ),
    );
  }
}

class _ClassesSidebar extends StatelessWidget {
  final VoidCallback onMenuTap;
  final VoidCallback onStudentsTap;
  final VoidCallback onPersonalTap;
  final VoidCallback onTurnichetiTap;
  final VoidCallback onClaseTap;
  final VoidCallback onVacanteTap;
  final VoidCallback onParintiTap;
  final VoidCallback onLogoutTap;

  const _ClassesSidebar({
    required this.onMenuTap,
    required this.onStudentsTap,
    required this.onPersonalTap,
    required this.onTurnichetiTap,
    required this.onClaseTap,
    required this.onVacanteTap,
    required this.onParintiTap,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = (AppSession.fullName?.isNotEmpty ?? false)
        ? AppSession.fullName!
        : (AppSession.username ?? 'Admin');

    return Container(
      width: 240,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0B7A21), Color(0xFF0C651D)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Text(
              'Secretariat',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _SidebarTile(
            label: 'Meniu',
            icon: Icons.grid_view_rounded,
            onTap: onMenuTap,
          ),
          _SidebarTile(
            label: 'Elevi',
            icon: Icons.school_rounded,
            onTap: onStudentsTap,
          ),
          _SidebarTile(
            label: 'Personal',
            icon: Icons.badge_rounded,
            onTap: onPersonalTap,
          ),
          _SidebarTile(
            label: 'Parinti',
            icon: Icons.family_restroom_rounded,
            onTap: onParintiTap,
          ),
          _SidebarTile(
            label: 'Clase',
            icon: Icons.table_chart_rounded,
            selected: true,
            onTap: onClaseTap,
          ),
          _SidebarTile(
            label: 'Vacante',
            icon: Icons.event_available_rounded,
            onTap: onVacanteTap,
          ),
          _SidebarTile(
            label: 'Turnicheti',
            icon: Icons.door_front_door_rounded,
            onTap: onTurnichetiTap,
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0A4A16),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: onLogoutTap,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Delogheaza-te'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7E2C5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF7A4A10),
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const Text(
                        'Liceul Central',
                        style: TextStyle(
                          color: Color(0xFFC9E6CE),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? Colors.white.withValues(alpha: 0.17)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, color: const Color(0xFFCEF0D8), size: 18),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFE6F6EA),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClassSelectorCard extends StatelessWidget {
  final String? selectedClassId;
  final List<String> classOptions;
  final Future<void> Function()? onDelete;
  final ValueChanged<String?> onChanged;

  const _ClassSelectorCard({
    required this.selectedClassId,
    required this.classOptions,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedValue =
        selectedClassId != null && classOptions.contains(selectedClassId)
        ? selectedClassId
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SELECTEAZA CLASA',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF6D7B6A),
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              IconButton.filled(
                tooltip: 'Sterge clasa selectata',
                onPressed: onDelete == null ? null : () => onDelete!(),
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFFFE3E3),
                  disabledBackgroundColor: const Color(0xFFFFF1F1),
                  foregroundColor: const Color(0xFFD24545),
                  disabledForegroundColor: const Color(0xFFE2A7A7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    '${selectedClassId ?? 'none'}|${classOptions.join(',')}',
                  ),
                  initialValue: selectedValue,
                  onChanged: onChanged,
                  hint: const Text(
                    'Alege o clasă',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7B8A77),
                    ),
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF5F8F2),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFDAE8D0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFDAE8D0)),
                    ),
                  ),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: classOptions
                      .map(
                        (classId) => DropdownMenuItem<String>(
                          value: classId,
                          child: Text(
                            classId,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatefulWidget {
  final String? classId;
  final Map<String, dynamic>? selectedClassData;
  final Map<String, String> dayNames;
  final Map<String, Map<String, String>> Function(Map<String, dynamic>?)
  scheduleBuilder;
  final Future<void> Function(Map<String, Map<String, String>> schedule)?
  onSave;

  const _ScheduleCard({
    super.key,
    required this.classId,
    required this.selectedClassData,
    required this.dayNames,
    required this.scheduleBuilder,
    required this.onSave,
  });

  @override
  State<_ScheduleCard> createState() => _ScheduleCardState();
}

class _ScheduleCardState extends State<_ScheduleCard> {
  late Map<String, Map<String, String>> _draftSchedule;
  late Set<String> _selectedDays;
  bool _editing = false;
  bool _saving = false;
  bool _isPickingTime = false;

  @override
  void initState() {
    super.initState();
    _resetDraft();
  }

  @override
  void didUpdateWidget(covariant _ScheduleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSchedule = oldWidget.scheduleBuilder(
      oldWidget.selectedClassData?['schedule'] as Map<String, dynamic>?,
    );
    final newSchedule = widget.scheduleBuilder(
      widget.selectedClassData?['schedule'] as Map<String, dynamic>?,
    );
    if (oldWidget.classId != widget.classId ||
        (!_editing && !_sameSchedule(oldSchedule, newSchedule))) {
      _resetDraft();
    }
  }

  bool _sameSchedule(
    Map<String, Map<String, String>> a,
    Map<String, Map<String, String>> b,
  ) {
    if (a.length != b.length) return false;
    for (final dayKey in widget.dayNames.keys) {
      final dayA = a[dayKey];
      final dayB = b[dayKey];
      if (dayA == null && dayB == null) {
        continue;
      }
      if (dayA == null || dayB == null) {
        return false;
      }
      if (dayA['start'] != dayB['start'] || dayA['end'] != dayB['end']) {
        return false;
      }
    }
    return true;
  }

  void _resetDraft() {
    final base = widget.scheduleBuilder(
      widget.selectedClassData?['schedule'] as Map<String, dynamic>?,
    );
    _draftSchedule = {
      for (final entry in base.entries)
        entry.key: Map<String, String>.from(entry.value),
    };
    _selectedDays = base.keys.toSet();
    _editing = false;
    _saving = false;
  }

  Map<String, Map<String, String>> get _savedSchedule => widget.scheduleBuilder(
    widget.selectedClassData?['schedule'] as Map<String, dynamic>?,
  );

  String _fmtTime(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  int _minutesOf(String value) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
    if (match == null) return -1;
    final hour = int.tryParse(match.group(1) ?? '0') ?? 0;
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    return hour * 60 + minute;
  }

  Future<void> _pickTime({
    required String dayKey,
    required String field,
  }) async {
    if (_isPickingTime) return;
    _isPickingTime = true;
    try {
      final currentValue =
          _draftSchedule[dayKey]?[field] ??
          (field == 'start' ? '08:00' : '14:00');

      final match = RegExp(
        r'^(\d{1,2}):(\d{2})$',
      ).firstMatch(currentValue.trim());
      final initHour = int.tryParse(match?.group(1) ?? '8') ?? 8;
      final initMinute = int.tryParse(match?.group(2) ?? '0') ?? 0;

      final hourCtrl = TextEditingController(
        text: initHour.toString().padLeft(2, '0'),
      );
      final minCtrl = TextEditingController(
        text: initMinute.toString().padLeft(2, '0'),
      );

      final result = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) {
          String? error;
          return StatefulBuilder(
            builder: (ctx, setS) {
              return AlertDialog(
                title: Text(
                  field == 'start' ? 'Ora de intrare' : 'Ora de ieșire',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A2E1A),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: hourCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 2,
                            decoration: const InputDecoration(
                              labelText: 'Ora',
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            ':',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: minCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            maxLength: 2,
                            decoration: const InputDecoration(
                              labelText: 'Min',
                              counterText: '',
                              border: OutlineInputBorder(),
                            ),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        error!,
                        style: const TextStyle(
                          color: Color(0xFFD32F2F),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Anul'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E6B2E),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      final h = int.tryParse(hourCtrl.text.trim());
                      final m = int.tryParse(minCtrl.text.trim());
                      if (h == null || h < 0 || h > 23) {
                        setS(() => error = 'Ora trebuie sa fie intre 0 si 23.');
                        return;
                      }
                      if (m == null || m < 0 || m > 59) {
                        setS(
                          () => error = 'Minutul trebuie sa fie intre 0 si 59.',
                        );
                        return;
                      }
                      Navigator.of(ctx).pop(_fmtTime(h, m));
                    },
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        },
      );

      hourCtrl.dispose();
      minCtrl.dispose();

      if (result == null || !mounted) return;

      setState(() {
        final day = Map<String, String>.from(
          _draftSchedule[dayKey] ??
              const <String, String>{'start': '08:00', 'end': '14:00'},
        );
        day[field] = result;
        _draftSchedule[dayKey] = day;
      });
    } finally {
      if (mounted) _isPickingTime = false;
    }
  }

  void _toggleDay(String dayKey, bool selected) {
    setState(() {
      if (selected) {
        _selectedDays.add(dayKey);
        _draftSchedule.putIfAbsent(
          dayKey,
          () => <String, String>{'start': '08:00', 'end': '14:00'},
        );
      } else {
        _selectedDays.remove(dayKey);
        _draftSchedule.remove(dayKey);
      }
    });
  }

  Future<void> _saveDraft() async {
    if (widget.classId == null ||
        widget.onSave == null ||
        _selectedDays.isEmpty) {
      return;
    }

    final schedule = <String, Map<String, String>>{};
    for (final key in widget.dayNames.keys) {
      if (!_selectedDays.contains(key)) continue;
      final day = _draftSchedule[key];
      if (day == null) continue;
      final start = (day['start'] ?? '').trim();
      final end = (day['end'] ?? '').trim();
      if (start.isEmpty || end.isEmpty) continue;
      if (_minutesOf(end) <= _minutesOf(start)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Interval invalid pentru ${widget.dayNames[key]}. Ora de iesire trebuie sa fie dupa ora de intrare.',
            ),
          ),
        );
        return;
      }
      schedule[key] = {'start': start, 'end': end};
    }

    if (schedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecteaza cel putin o zi pentru orar.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.onSave!(schedule);
      if (!mounted) return;
      setState(() {
        _editing = false;
        _saving = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final savedSchedule = _savedSchedule;
    final hasSchedule = savedSchedule.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Interval Operational',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1B2819),
              ),
            ),
          ),
          const SizedBox(height: 4),
          if (widget.classId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                hasSchedule
                    ? 'Poti modifica zilele si intervalele orare, apoi salvezi.'
                    : 'Clasa nu are orar. Creeaza unul pentru a-l putea modifica.',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B7868),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (widget.classId == null)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Text(
                'Alege mai intai o clasa din lista din stanga.',
                style: _ClassTeacherCard._emptyStateTextStyle,
              ),
            )
          else if (!_editing && !hasSchedule)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: () => setState(() => _editing = true),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                  label: const Text('Creeaza orar'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0F7422),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _editing ? 'Selecteaza zilele si orele' : 'Orarul clasei',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6D7B6A),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (!_editing)
                    OutlinedButton.icon(
                      onPressed: () => setState(() => _editing = true),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Modifica'),
                    ),
                ],
              ),
            ),
            const Divider(height: 16, thickness: 1, color: Color(0xFFE2EBDD)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.dayNames.entries.map((entry) {
                  final selected = _selectedDays.contains(entry.key);
                  return FilterChip(
                    selected: selected,
                    label: Text(entry.value),
                    onSelected: _editing
                        ? (value) => _toggleDay(entry.key, value)
                        : null,
                    selectedColor: const Color(0xFFDFF0D5),
                    checkmarkColor: const Color(0xFF1B5E20),
                    labelStyle: TextStyle(
                      color: selected
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF5D6D59),
                      fontWeight: FontWeight.w700,
                    ),
                    side: const BorderSide(color: Color(0xFFCFDFCC)),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedDays.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  'Selecteaza cel putin o zi pentru orar.',
                  style: TextStyle(
                    color: Color(0xFF667466),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              ...() {
                final todayKey = DateTime.now().weekday.toString();
                final widgets = <Widget>[];
                final selectedEntries = widget.dayNames.entries
                    .where((entry) => _selectedDays.contains(entry.key))
                    .toList();
                for (var i = 0; i < selectedEntries.length; i++) {
                  final entry = selectedEntries[i];
                  final isToday = entry.key == todayKey;
                  final start = _draftSchedule[entry.key]?['start'] ?? '08:00';
                  final end = _draftSchedule[entry.key]?['end'] ?? '14:00';
                  widgets.add(
                    Container(
                      decoration: isToday
                          ? const BoxDecoration(color: Color(0xFFE8F5E9))
                          : null,
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 16,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            child: isToday
                                ? const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 14,
                                    color: Color(0xFF2E7D32),
                                  )
                                : null,
                          ),
                          Expanded(
                            flex: 5,
                            child: Text(
                              entry.value,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 4,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: _editing
                                    ? () => _pickTime(
                                        dayKey: entry.key,
                                        field: 'start',
                                      )
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F4EE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        start,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF0D0D0D),
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 14,
                                        color: Color(0xFF0D0D0D),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 4,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: GestureDetector(
                                onTap: _editing
                                    ? () => _pickTime(
                                        dayKey: entry.key,
                                        field: 'end',
                                      )
                                    : null,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF0F4EE),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        end,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF0D0D0D),
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(
                                        Icons.access_time_rounded,
                                        size: 14,
                                        color: Color(0xFF0D0D0D),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                  if (i < selectedEntries.length - 1) {
                    widgets.add(
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFE2EBDD),
                      ),
                    );
                  }
                }
                return widgets;
              }(),
            if (_editing)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Row(
                  children: [
                    OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => setState(() => _resetDraft()),
                      child: const Text('Anuleaza'),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveDraft,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                hasSchedule
                                    ? Icons.save_outlined
                                    : Icons.calendar_month_outlined,
                                size: 18,
                              ),
                        label: Text(
                          _saving
                              ? 'Se salveaza...'
                              : hasSchedule
                              ? 'Salveaza orarul'
                              : 'Creeaza orar',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F7422),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ClassTeacherCard extends StatelessWidget {
  final String? classId;
  final String teacherUsername;
  final Future<void> Function(
    BuildContext context, {
    required String uid,
    required String username,
    required String fullName,
    required String classId,
    required String status,
    required bool onboardingComplete,
    required String? email,
    required String photoUrl,
  })
  onOpenTeacherDialog;

  const _ClassTeacherCard({
    required this.classId,
    required this.teacherUsername,
    required this.onOpenTeacherDialog,
  });

  static const TextStyle _emptyStateTextStyle = TextStyle(
    fontSize: 14,
    color: Color(0xFF9BAA97),
    fontStyle: FontStyle.italic,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DIRIGINTELE CLASEI',
            style: TextStyle(
              fontSize: 10,
              color: Color(0xFF6D7B6A),
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          if (classId == null)
            const Text(
              'Selecteaza o clasa pentru a vedea dirigintele.',
              style: _emptyStateTextStyle,
            )
          else if (teacherUsername.isEmpty)
            const Text('Clasa nu are diriginte.', style: _emptyStateTextStyle)
          else
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('username', isEqualTo: teacherUsername.toLowerCase())
                  .limit(1)
                  .snapshots(),
              builder: (context, snap) {
                final teacherDoc = snap.hasData && snap.data!.docs.isNotEmpty
                    ? snap.data!.docs.first
                    : null;
                String fullName = teacherUsername;
                if (teacherDoc != null) {
                  final u = teacherDoc.data() as Map<String, dynamic>;
                  final fn = (u['fullName'] ?? '').toString().trim();
                  if (fn.isNotEmpty) fullName = fn;
                }

                final initials = fullName
                    .trim()
                    .split(RegExp(r'\s+'))
                    .where((p) => p.isNotEmpty)
                    .take(2)
                    .map((p) => p[0].toUpperCase())
                    .join();

                return Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFFDFF0D5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        initials.isEmpty ? '?' : initials,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2C6E30),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fullName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1F2F1E),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Username: $teacherUsername',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6A7B68),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.settings_outlined,
                        color: Color(0xFF424242),
                        size: 22,
                      ),
                      onPressed: teacherDoc == null
                          ? null
                          : () {
                              final data =
                                  teacherDoc.data() as Map<String, dynamic>;
                              onOpenTeacherDialog(
                                context,
                                uid: teacherDoc.id,
                                username: (data['username'] ?? teacherUsername)
                                    .toString(),
                                fullName: fullName,
                                classId: (data['classId'] ?? classId ?? '')
                                    .toString(),
                                status: (data['status'] ?? 'active').toString(),
                                onboardingComplete:
                                    data['onboardingComplete'] as bool? ??
                                    false,
                                email: (data['personalEmail'] ?? data['email'])
                                    ?.toString(),
                                photoUrl:
                                    (data['photoUrl'] ??
                                            data['avatarUrl'] ??
                                            '')
                                        .toString(),
                              );
                            },
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ClassStudentsCard extends StatelessWidget {
  final String? classId;
  final String? className;
  final Future<void> Function(
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
    required String photoUrl,
  })
  onOpenStudentDialog;

  const _ClassStudentsCard({
    required this.classId,
    required this.className,
    required this.onOpenStudentDialog,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBDD)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Lista Elevi',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1B2819),
                  ),
                ),
                const Spacer(),
                if (className != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6E0),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFC9E1B8)),
                    ),
                    child: Text(
                      className!,
                      style: const TextStyle(
                        color: Color(0xFF2C6E30),
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _ClassStudentsList(
              classId: classId,
              onOpenStudentDialog: onOpenStudentDialog,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassStudentsList extends StatelessWidget {
  final String? classId;
  final Future<void> Function(
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
    required String photoUrl,
  })
  onOpenStudentDialog;

  const _ClassStudentsList({
    required this.classId,
    required this.onOpenStudentDialog,
  });

  @override
  Widget build(BuildContext context) {
    if (classId == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Text(
            'Selecteaza o clasa pentru a vedea elevii.',
            style: _ClassTeacherCard._emptyStateTextStyle,
          ),
        ),
      );
    }

    return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
      key: ValueKey(classId),
      stream: FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'student')
          .where('classId', isEqualTo: classId)
          .snapshots()
          .map((snapshot) => snapshot.docs),
      initialData: const <QueryDocumentSnapshot<Map<String, dynamic>>>[],
      builder: (context, snap) {
        if (snap.hasError) {
          return SelectableText('Eroare elevi:\n${snap.error}');
        }
        final docs = [...?snap.data];
        docs.sort((a, b) {
          final an = (a.data()['fullName'] ?? '').toString().toLowerCase();
          final bn = (b.data()['fullName'] ?? '').toString().toLowerCase();
          return an.compareTo(bn);
        });

        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 26),
            child: Center(
              child: Text(
                'Nu exista elevi in aceasta clasa.',
                style: _ClassTeacherCard._emptyStateTextStyle,
              ),
            ),
          );
        }

        return Column(
          children: docs.map((d) {
            final data = d.data();
            final username = (data['username'] ?? d.id).toString();
            final fullName = (data['fullName'] ?? username).toString();
            final inSchool = data['inSchool'] as bool? ?? false;
            final status = (data['status'] ?? '').toString();
            final onboardingComplete =
                data['onboardingComplete'] as bool? ?? false;
            final emailVerified = data['emailVerified'] as bool? ?? false;
            final passwordChanged = data['passwordChanged'] as bool? ?? false;
            final email = data['email']?.toString();
            final parentUsernames = ((data['parents'] as List?) ?? const [])
                .map((parent) => parent.toString())
                .toList();
            final photoUrl = (data['photoUrl'] ?? '').toString();

            final initials = fullName
                .trim()
                .split(RegExp(r'\s+'))
                .where((p) => p.isNotEmpty)
                .take(2)
                .map((p) => p[0].toUpperCase())
                .join();

            return Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FBF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4EEDE)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFC4EEA9),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      initials.isEmpty ? '?' : initials,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3F1E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1F2F1E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Username: $username',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6A7B68),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: inSchool
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: inSchool
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFF44336),
                      ),
                    ),
                    child: Text(
                      inSchool ? 'In incinta' : 'In afara incintei',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: inSchool
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFC62828),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => onOpenStudentDialog(
                      context,
                      uid: d.id,
                      username: username,
                      fullName: fullName,
                      classId: classId!,
                      inSchool: inSchool,
                      status: status,
                      onboardingComplete: onboardingComplete,
                      emailVerified: emailVerified,
                      passwordChanged: passwordChanged,
                      email: email,
                      parentUsernames: parentUsernames,
                      photoUrl: photoUrl,
                    ),
                    icon: const Icon(Icons.settings, size: 16),
                    color: const Color(0xFF7D8E79),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
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

class _ExportBar extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final Future<void> Function() onExport;

  const _ExportBar({
    required this.enabled,
    required this.busy,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: !enabled || busy ? null : onExport,
          icon: busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.description_outlined, size: 18),
          label: Text(busy ? 'Export...' : 'Exportă conturi elevi'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF0F7422),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFDDE8D7),
            disabledForegroundColor: const Color(0xFF8B9486),
            padding: const EdgeInsets.symmetric(vertical: 28),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Exportă lista completă a elevilor, inclusiv username-urile și parolele generate pentru accesul în aplicație.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF7A8F77)),
        ),
      ],
    );
  }
}
