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

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: const Color(0xFFE6EBEE),
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
    });
  }

  Future<void> _pickTime() async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 30),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogBackgroundColor: const Color(0xFFE6EBEE),
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
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (pickedTime == null) {
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
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(studentUid)
          .get();

      final userData = userSnap.data() ?? <String, dynamic>{};
      final classId = (userData['classId'] ?? '').toString();
      final studentName = (userData['fullName'] ?? AppSession.username ?? '')
          .toString();

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
        'reviewedAt': null,
        'reviewedByUid': null,
        'reviewedByName': null,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cererea a fost trimisa cu succes.')),
      );

      setState(() {
        _selectedDate = null;
        _selectedTime = null;
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
                                onTap: _pickTime,
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
  final VoidCallback onTap;

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
