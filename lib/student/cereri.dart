import 'package:firster/student/meniu.dart';
import 'package:firster/core/session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

const _primary = Color(0xFF0D631B);
const _surface = Color(0xFFECEFE6);
const _card = Color(0xFFF7F8F3);
const _cardMuted = Color(0xFFE8ECE3);
const _textDark = Color(0xFF131A14);
const _textMuted = Color(0xFF4A5750);

class CereriScreen extends StatefulWidget {
  final ValueChanged<int>? onNavigateTab;

  const CereriScreen({super.key, this.onNavigateTab});

  @override
  State<CereriScreen> createState() => _CereriScreenState();
}

class _CereriScreenState extends State<CereriScreen> {
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _submitting = false;

  // Schedule for the selected day (fetched from Firestore)
  TimeOfDay? _scheduleStart;
  TimeOfDay? _scheduleEnd;
  bool _loadingSchedule = false;
  bool _targetTeacher = true;
  bool _targetParent = false;

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();

    // Skip weekends when setting the initial date
    DateTime initialDate = _selectedDate ?? now;
    if (initialDate.weekday == DateTime.saturday) {
      initialDate = initialDate.add(const Duration(days: 2));
    } else if (initialDate.weekday == DateTime.sunday) {
      initialDate = initialDate.add(const Duration(days: 1));
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      helpText: 'Selecteaza data',
      fieldHintText: 'ZZ/LL/AAAA',
      fieldLabelText: 'Data',
      cancelText: 'Anuleaza',
      confirmText: 'OK',
      selectableDayPredicate: (day) =>
          day.weekday != DateTime.saturday && day.weekday != DateTime.sunday,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _primary,
              onPrimary: Colors.white,
              surface: _card,
              onSurface: _textDark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: _primary),
            ),
            dialogTheme: const DialogThemeData(backgroundColor: _card),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: _cardMuted,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _primary, width: 1.4),
              ),
            ),
            datePickerTheme: DatePickerThemeData(
              backgroundColor: _card,
              headerBackgroundColor: _primary,
              headerForegroundColor: Colors.white,
              headerHeadlineStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
              dayStyle: const TextStyle(
                color: _textDark,
                fontWeight: FontWeight.w600,
              ),
              weekdayStyle: const TextStyle(
                color: _textMuted,
                fontWeight: FontWeight.w700,
              ),
              dayForegroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.white;
                }
                if (states.contains(WidgetState.disabled)) {
                  return _textMuted.withValues(alpha: 0.35);
                }
                return _textDark;
              }),
              dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return _primary;
                }
                return Colors.transparent;
              }),
              todayBorder: const BorderSide(color: _primary, width: 1.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (pickedDate == null) {
      return;
    }

    setState(() {
      _selectedDate = pickedDate;
      _dateController.text = _formatDateMmDdYyyy(pickedDate);
      // Reset time and cached schedule when date changes
      _selectedTime = null;
      _timeController.clear();
      _scheduleStart = null;
      _scheduleEnd = null;
    });
  }

  TimeOfDay _parseHHmm(String s) {
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  String _formatDateMmDdYyyy(DateTime dt) {
    final mm = dt.month.toString().padLeft(2, '0');
    final dd = dt.day.toString().padLeft(2, '0');
    return '$dd/$mm/${dt.year}';
  }

  String _formatTime12h(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<Map<String, dynamic>> _loadCurrentUserData() async {
    final uid = AppSession.uid ?? '';
    if (uid.isEmpty) {
      return const <String, dynamic>{};
    }

    final userSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    return userSnap.data() ?? const <String, dynamic>{};
  }

  Future<bool> _fetchDaySchedule(int weekday) async {
    final classId = AppSession.classId;
    if (classId == null || classId.isEmpty) return false;

    setState(() => _loadingSchedule = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classId)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() ?? {};
      final schedule = data['schedule'] as Map<String, dynamic>?;
      if (schedule == null) return false;

      // Firestore key matches Flutter weekday: 1=Mon..5=Fri
      final dayData = schedule[weekday.toString()] as Map<String, dynamic>?;
      if (dayData == null) return false;

      final startStr = dayData['start'] as String?;
      final endStr = dayData['end'] as String?;
      if (startStr == null || endStr == null) return false;

      if (mounted) {
        setState(() {
          _scheduleStart = _parseHHmm(startStr);
          _scheduleEnd = _parseHHmm(endStr);
        });
      }
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _loadingSchedule = false);
    }
  }

  Future<void> _pickTime() async {
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecteaza mai intai data invoirii.')),
      );
      return;
    }

    // Fetch schedule for this weekday if not already cached
    if (_scheduleStart == null || _scheduleEnd == null) {
      final ok = await _fetchDaySchedule(_selectedDate!.weekday);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Orarul clasei tale nu este setat pentru ziua selectata.',
            ),
          ),
        );
        return;
      }
    }

    final rangeStart = _scheduleStart!;
    final rangeEnd = _scheduleEnd!;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? rangeStart,
      initialEntryMode: TimePickerEntryMode.input,
      helpText: 'Selecteaza ora',
      cancelText: 'Anuleaza',
      confirmText: 'OK',
      hourLabelText: 'Ora',
      minuteLabelText: 'Minute',
      builder: (context, child) {
        return Localizations.override(
          context: context,
          delegates: const [_RomanianTimePickerLocalizationsDelegate()],
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: _primary,
                  onPrimary: Colors.white,
                  surface: _card,
                  onSurface: _textDark,
                ),
                textButtonTheme: TextButtonThemeData(
                  style: TextButton.styleFrom(foregroundColor: _primary),
                ),
                timePickerTheme: TimePickerThemeData(
                  backgroundColor: _card,
                  hourMinuteColor: _cardMuted,
                  hourMinuteTextColor: _textDark,
                  dayPeriodColor: _cardMuted,
                  dayPeriodTextColor: _textDark,
                  dialBackgroundColor: _cardMuted,
                  dialHandColor: _primary,
                  dialTextColor: _textDark,
                  entryModeIconColor: _primary,
                  hourMinuteShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(
                      color: Color(0xFFCAD5C5),
                      width: 1.2,
                    ),
                  ),
                  dayPeriodShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(
                      color: Color(0xFFCAD5C5),
                      width: 1.2,
                    ),
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );

    if (pickedTime == null) {
      return;
    }

    final pickedMin = _toMinutes(pickedTime);
    final startMin = _toMinutes(rangeStart);
    final endMin = _toMinutes(rangeEnd);

    if (pickedMin < startMin || pickedMin > endMin) {
      if (!mounted) return;
      String fmt(TimeOfDay t) =>
          '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ora trebuie sa fie intre ${fmt(rangeStart)} si ${fmt(rangeEnd)} (orarul clasei tale).',
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedTime = pickedTime;
      _timeController.text = _formatTime12h(pickedTime);
    });
  }

  Future<Map<String, String>> _resolveTeacher() async {
    final uid = AppSession.uid ?? '';
    if (uid.isEmpty) return const <String, String>{};
    final userData = await _loadCurrentUserData();
    final classId = (userData['classId'] ?? AppSession.classId ?? '')
        .toString()
        .trim();
    if (classId.isEmpty) return const <String, String>{};
    final classSnap = await FirebaseFirestore.instance
        .collection('classes')
        .doc(classId)
        .get();
    final classData = classSnap.data() ?? const <String, dynamic>{};
    String teacherUid = (classData['teacherUid'] ?? '').toString().trim();
    String teacherUsername = (classData['teacherUsername'] ?? '')
        .toString()
        .trim();
    String teacherName = '';
    if (teacherUid.isNotEmpty) {
      final teacherSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(teacherUid)
          .get();
      final teacherData = teacherSnap.data() ?? const <String, dynamic>{};
      teacherUsername = (teacherData['username'] ?? teacherUsername)
          .toString()
          .trim();
      teacherName = (teacherData['fullName'] ?? teacherUsername)
          .toString()
          .trim();
    }
    return <String, String>{
      'uid': teacherUid,
      'name': teacherName.isNotEmpty ? teacherName : 'Diriginte',
      'username': teacherUsername,
    };
  }

  Future<Map<String, String>> _resolveParent() async {
    final uid = AppSession.uid ?? '';
    if (uid.isEmpty) return const <String, String>{};
    final userData = await _loadCurrentUserData();
    final parents = List<String>.from(userData['parents'] ?? const <String>[]);
    if (parents.isEmpty) return const <String, String>{};
    final parentUid = parents.first;
    final parentSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(parentUid)
        .get();
    final parentData = parentSnap.data() ?? const <String, dynamic>{};
    return <String, String>{
      'uid': parentUid,
      'name': (parentData['fullName'] ?? parentData['username'] ?? '')
          .toString()
          .trim(),
      'username': (parentData['username'] ?? '').toString().trim(),
    };
  }

  Future<void> _submitRequest() async {
    final message = _messageController.text.trim();

    if (_selectedDate == null || _selectedTime == null || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completeaza data, ora si mesajul cererii.'),
        ),
      );
      return;
    }

    if (!_targetTeacher && !_targetParent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecteaza cel putin un destinatar.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    final studentUid = AppSession.uid;
    if (studentUid == null || studentUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sesiune invalida. Reautentifica-te.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final userData = await _loadCurrentUserData();
      final classId = (userData['classId'] ?? AppSession.classId ?? '')
          .toString()
          .trim();
      final studentUsername =
          (userData['username'] ?? AppSession.username ?? '').toString().trim();
      final studentName =
          (userData['fullName'] ?? AppSession.fullName ?? studentUsername)
              .toString()
              .trim();

      if (classId.isEmpty) {
        throw Exception('Elevul nu are clasa setata in profil.');
      }

      final baseDoc = {
        'studentUid': studentUid,
        'studentUsername': studentUsername,
        'studentName': studentName,
        'classId': classId,
        'dateText': _dateController.text,
        'timeText': _timeController.text,
        'message': message,
        'status': 'pending',
        'requestedAt': Timestamp.now(),
        'requestedForDate': Timestamp.fromDate(
          DateTime(
            _selectedDate!.year,
            _selectedDate!.month,
            _selectedDate!.day,
            _selectedTime!.hour,
            _selectedTime!.minute,
          ),
        ),
        'reviewedAt': null,
        'reviewedByUid': null,
        'reviewedByName': null,
        'viewedByParent': false,
      };

      final futures = <Future>[];

      if (_targetTeacher) {
        final teacher = await _resolveTeacher();
        futures.add(
          FirebaseFirestore.instance.collection('leaveRequests').add({
            ...baseDoc,
            'targetRole': 'teacher',
            'targetUid': (teacher['uid'] ?? '').trim(),
            'targetName': (teacher['name'] ?? 'Diriginte').trim(),
            'targetUsername': (teacher['username'] ?? '').trim(),
          }),
        );
      }

      if (_targetParent) {
        final parent = await _resolveParent();
        if (parent['uid']?.isNotEmpty == true) {
          futures.add(
            FirebaseFirestore.instance.collection('leaveRequests').add({
              ...baseDoc,
              'targetRole': 'parent',
              'targetUid': (parent['uid'] ?? '').trim(),
              'targetName': (parent['name'] ?? '').trim(),
              'targetUsername': (parent['username'] ?? '').trim(),
            }),
          );
        }
      }

      await Future.wait(futures);

      await FirebaseFirestore.instance.collection('users').doc(studentUid).set({
        'unreadCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cererea a fost trimisa cu succes.')),
      );

      setState(() {
        _selectedDate = null;
        _selectedTime = null;
        _scheduleStart = null;
        _scheduleEnd = null;
        _dateController.clear();
        _timeController.clear();
        _messageController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().contains('Exception:')
                ? e.toString().replaceFirst('Exception: ', '')
                : 'Eroare la trimiterea cererii.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedDate = null;
      _selectedTime = null;
      _scheduleStart = null;
      _scheduleEnd = null;
      _dateController.clear();
      _timeController.clear();
      _messageController.clear();
    });
  }

  bool get _hasUnsavedData =>
      _selectedDate != null ||
      _selectedTime != null ||
      _messageController.text.trim().isNotEmpty;

  Future<void> _goBack() async {
    if (_hasUnsavedData) {
      final confirmed = await showDialog<bool>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.4),
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24000000),
                  blurRadius: 32,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0EBE1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: _primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Renunți la cerere?',
                        style: TextStyle(
                          color: _textDark,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Cererea nu a fost trimisă și datele vor fi șterse.',
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 13.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        style: TextButton.styleFrom(
                          backgroundColor: const Color(0xFFFFEAEA),
                          foregroundColor: const Color(0xFFB71C1C),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Renunț',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        style: TextButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: const Text(
                          'Rămân',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      if (confirmed != true) return;
    }

    if (!mounted) return;

    _resetForm();

    if (widget.onNavigateTab != null) {
      widget.onNavigateTab!(0);
      return;
    }

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const MeniuScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final headerHeight = compact ? 138.0 : 146.0;
    final titleSize = compact ? 29.0 : 33.0;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: Scaffold(
        backgroundColor: _surface,
        body: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(54),
                      bottomRight: Radius.circular(54),
                    ),
                    child: Container(
                      height: headerHeight,
                      width: double.infinity,
                      color: _primary,
                      child: Stack(
                        children: [
                          Positioned(
                            top: -72,
                            right: -52,
                            child: _HeaderCircle(size: 220, opacity: 0.08),
                          ),
                          Positioned(
                            top: 44,
                            right: 34,
                            child: _HeaderCircle(size: 72, opacity: 0.07),
                          ),
                          Positioned(
                            left: 156,
                            bottom: -28,
                            child: _HeaderCircle(size: 82, opacity: 0.08),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 18),
                            child: Center(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  _HeaderIconButton(
                                    icon: Icons.arrow_back_rounded,
                                    onTap: _goBack,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Text(
                                      'Cereri de invoire',
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
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _RecipientCard(
                                  selected: _targetTeacher,
                                  icon: Icons.school_rounded,
                                  title: 'Diriginte',
                                  onTap: () => setState(
                                    () => _targetTeacher = !_targetTeacher,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _RecipientCard(
                                  selected: _targetParent,
                                  icon: Icons.family_restroom,
                                  title: 'Parinte',
                                  onTap: () => setState(
                                    () => _targetParent = !_targetParent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 34),
                          const Text(
                            'DATA',
                            style: TextStyle(
                              color: _primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _LabeledInputBox(
                            controller: _dateController,
                            hintText: 'ZZ/LL/AAAA',
                            icon: Icons.calendar_month_rounded,
                            onTap: _pickDate,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'ORA DE INCEPUT',
                            style: TextStyle(
                              color: _primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _LabeledInputBox(
                            controller: _timeController,
                            hintText: '08:00',
                            icon: Icons.access_time_filled_rounded,
                            onTap: _loadingSchedule ? null : _pickTime,
                          ),
                          if (_loadingSchedule)
                            const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(color: _primary),
                            )
                          else if (_scheduleStart != null &&
                              _scheduleEnd != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Interval valid: '
                                '${_scheduleStart!.hour.toString().padLeft(2, '0')}:${_scheduleStart!.minute.toString().padLeft(2, '0')}'
                                ' - '
                                '${_scheduleEnd!.hour.toString().padLeft(2, '0')}:${_scheduleEnd!.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: _primary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          const Text(
                            'MOTIVUL ABSENTEI',
                            style: TextStyle(
                              color: _primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ReasonBox(controller: _messageController),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _submitting ? null : _submitRequest,
                              icon: _submitting
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 30),
                              label: const Text(
                                'Trimite Cererea',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: _primary,
                                disabledForegroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(74),
                                elevation: 6,
                                shadowColor: const Color(0x660D631B),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 34),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            decoration: BoxDecoration(
                              color: _card,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 6),
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Color(0xFFF3D0DD),
                                  child: Icon(
                                    Icons.alarm_rounded,
                                    color: Color(0xFF8A2D52),
                                    size: 24,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Cererile trimise expira automat dupa ora 00:00 in ziua respectiva.',
                                    style: TextStyle(
                                      color: Color(0xFF283028),
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                      height: 1.38,
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
                ],
              ),
              if (_submitting)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.62),
                      child: Center(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 28),
                          padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x16000000),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: _primary,
                                ),
                              ),
                              SizedBox(width: 14),
                              Flexible(
                                child: Text(
                                  'Se trimite cererea...',
                                  style: TextStyle(
                                    color: _textDark,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecipientCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _RecipientCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        height: 150,
        decoration: BoxDecoration(
          color: selected ? _card : _cardMuted,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _primary : Colors.transparent,
            width: selected ? 3 : 0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFD5E1D4),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected ? _primary : const Color(0xFF3D493E),
                size: 38,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: selected ? _textDark : _textMuted,
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledInputBox extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final VoidCallback? onTap;

  const _LabeledInputBox({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: IgnorePointer(
        child: TextField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(
            fontSize: 18,
            color: _textDark,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontSize: 18,
              color: Color(0xFFA8B0A4),
              fontWeight: FontWeight.w500,
            ),
            filled: true,
            fillColor: _cardMuted,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFCED8C8),
                width: 1.2,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFCED8C8),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _primary, width: 1.6),
            ),
            suffixIcon: Container(
              margin: const EdgeInsets.all(8),
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFAED2AD),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: _primary, size: 21),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonBox extends StatelessWidget {
  final TextEditingController controller;

  const _ReasonBox({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 4,
      maxLines: 4,
      style: const TextStyle(fontSize: 18, color: _textDark, height: 1.2),
      decoration: InputDecoration(
        hintText: 'Introduceti motivul cererii de invoire...',
        hintStyle: const TextStyle(fontSize: 18, color: Color(0xFFA2AAA0)),
        filled: true,
        fillColor: _cardMuted,
        contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCED8C8), width: 1.2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFCED8C8), width: 1.2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary, width: 1.6),
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

class _HeaderCircle extends StatelessWidget {
  final double size;
  final double opacity;

  const _HeaderCircle({required this.size, required this.opacity});

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

// ---------------------------------------------------------------------------
// Delegate pentru traducerea tooltip-urilor din TimePicker în română
// ---------------------------------------------------------------------------
class _RomanianTimePickerLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _RomanianTimePickerLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<MaterialLocalizations> load(Locale locale) async =>
      const _RomanianMaterialLocalizations();

  @override
  bool shouldReload(_RomanianTimePickerLocalizationsDelegate old) => false;
}

class _RomanianMaterialLocalizations extends DefaultMaterialLocalizations {
  const _RomanianMaterialLocalizations();

  String get switchToInputModeLabel => 'Comută la mod text';

  String get switchToCalendarModeLabel => 'Comută la calendar';

  @override
  String get dialModeButtonLabel => 'Comută la selectorul cu cadran';

  @override
  String get inputTimeModeButtonLabel => 'Comută la mod text';
}
