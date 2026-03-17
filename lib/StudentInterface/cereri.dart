import 'package:firster/StudentInterface/meniu.dart';
import 'package:firster/session.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
      selectableDayPredicate: (day) =>
          day.weekday != DateTime.saturday && day.weekday != DateTime.sunday,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7AAF5B), // accent verde
              onPrimary: Colors.white,
              surface: Color(0xFFE6EBEE),
              onSurface: Color(0xFF223127),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF5D8A43),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: const Color(0xFFE6EBEE),
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
      _dateController.text =
          '${pickedDate.day.toString().padLeft(2, '0')}.${pickedDate.month.toString().padLeft(2, '0')}.${pickedDate.year}';
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

  int _toMinutes(TimeOfDay t) => t.hour * 60 + t.minute;

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
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF7AAF5B),
                onPrimary: Colors.white,
                surface: Color(0xFFE6EBEE),
                onSurface: Color(0xFF223127),
              ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF5D8A43),
                ),
              ),
              dialogTheme: DialogThemeData(
                backgroundColor: const Color(0xFFE6EBEE),
              ),
            ),
            child: child ?? const SizedBox.shrink(),
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
      final fmt = (TimeOfDay t) =>
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
      _timeController.text =
          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}';
    });
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
      final classId = AppSession.classId ?? '';
      final studentName = (AppSession.fullName?.isNotEmpty == true)
          ? AppSession.fullName!
          : (AppSession.username ?? '');

      await FirebaseFirestore.instance.collection('leaveRequests').add({
        'studentUid': studentUid,
        'studentUsername': (AppSession.username ?? '').toString(),
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
          ),
        ),
        'reviewedAt': null,
        'reviewedByUid': null,
        'reviewedByName': null,
      });

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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Eroare la trimiterea cererii.')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _goBack() {
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
    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF7AAF5B),
        toolbarHeight: 68,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: _goBack,
        ),
        title: const Text(
          'Cerere Invoire',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 32,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Color(0xFFE7EDF0),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 26, 16, 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 22),
                        child: Text(
                          'Trimite o cerere catre parinte sau diriginte pentru a obtine permisiunea de iesire in timpul programului scolar.',
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: 24,
                            color: Color(0xFF1F252B),
                            height: 1.28,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Data invoire:',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D2D2D),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _ReadOnlyInput(
                                controller: _dateController,
                                hintText: 'Selecteaza data',
                                trailingIcon: Icons.calendar_today_outlined,
                                onTap: _pickDate,
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'De la ora:',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D2D2D),
                                ),
                              ),
                              const SizedBox(height: 6),
                              _ReadOnlyInput(
                                controller: _timeController,
                                hintText: 'Selecteaza ora',
                                trailingIcon: Icons.chevron_right_rounded,
                                onTap: _loadingSchedule ? null : _pickTime,
                              ),
                              if (_loadingSchedule)
                                const Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: LinearProgressIndicator(),
                                )
                              else if (_scheduleStart != null &&
                                  _scheduleEnd != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 4,
                                  ),
                                  child: Text(
                                    'Interval valid: '
                                    '${_scheduleStart!.hour.toString().padLeft(2, '0')}:${_scheduleStart!.minute.toString().padLeft(2, '0')}'
                                    ' – '
                                    '${_scheduleEnd!.hour.toString().padLeft(2, '0')}:${_scheduleEnd!.minute.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontSize: 20,
                                      color: Color(0xFF5D8A43),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              const Text(
                                'Mesaj cerere:',
                                style: TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2D2D2D),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF6F6F6),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFFDCDCDC),
                                  ),
                                ),
                                child: TextField(
                                  controller: _messageController,
                                  minLines: 4,
                                  maxLines: 5,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    height: 1.0,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Scrie motivul invoiri',
                                    hintStyle: TextStyle(fontSize: 30),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.fromLTRB(
                                      12,
                                      10,
                                      12,
                                      10,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _submitting
                                      ? null
                                      : _submitRequest,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: const Color(0xFFB8C4B2),
                                    foregroundColor: const Color(0xFF303530),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                  ),
                                  child: const Text(
                                    'Trimitere cerere',
                                    style: TextStyle(
                                      fontSize: 35,
                                      fontWeight: FontWeight.w700,
                                    ),
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
            },
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData trailingIcon;
  final VoidCallback? onTap;

  const _ReadOnlyInput({
    required this.controller,
    required this.hintText,
    required this.trailingIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: IgnorePointer(
        child: TextField(
          controller: controller,
          readOnly: true,
          style: const TextStyle(fontSize: 34, height: 1.0),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 30),
            filled: true,
            fillColor: const Color(0xFFF6F6F6),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCDCDC)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFDCDCDC)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF9BB38A)),
            ),
            suffixIcon: Icon(trailingIcon, color: const Color(0xFF75808A)),
          ),
        ),
      ),
    );
  }
}
