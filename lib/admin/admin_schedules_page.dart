import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../core/session.dart';

class AdminSchedulesPage extends StatefulWidget {
  const AdminSchedulesPage({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<AdminSchedulesPage> createState() => _AdminSchedulesPageState();
}

class _AdminSchedulesPageState extends State<AdminSchedulesPage> {
  final Color primaryGreen = const Color(0xFF7AAF5B);
  final Color darkGreen = const Color(0xFF5C8B42);
  final Color lightGreen = const Color(0xFFF8FFF5);
  String? selectedClassId;
  final _classSearchC = TextEditingController();
  String _classQuery = "";

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

  @override
  void dispose() {
    _classSearchC.dispose();
    super.dispose();
  }

  Future<void> _deleteSchedule(String classId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: Text(
          'Are you sure you want to delete the schedule for $classId?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .update({'schedule': FieldValue.delete()});
        if (mounted) {
          setState(() {
            selectedClassId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Schedule deleted for $classId')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Eroare la ștergerea programului: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppSession.isAdmin) {
      return const Scaffold(
        body: Center(child: Text("Acces interzis (doar admin).")),
      );
    }

    final body = StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('classes').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final allDocs = snapshot.data?.docs ?? [];
        final classesWithSchedule =
            allDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data.containsKey('schedule') &&
                  (data['schedule'] as Map?)?.isNotEmpty == true;
            }).toList()..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              final aLabel = (aData['name'] ?? a.id).toString();
              final bLabel = (bData['name'] ?? b.id).toString();
              return _compareClassLabels(aLabel, bLabel);
            });

        // Filter classes based on search query
        final filteredClasses = classesWithSchedule.where((doc) {
          final classId = doc.id.toLowerCase();
          return classId.contains(_classQuery);
        }).toList();

        return Row(
          children: [
            // LEFT SIDEBAR - Classes List
            Container(
              width: 280,
              color: const Color(0xFF5C8B42),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      controller: _classSearchC,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Caută clasă...',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.60),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Colors.white.withValues(alpha: 0.60),
                        ),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _classQuery = value.toLowerCase().trim();
                        });
                      },
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredClasses.length,
                      itemBuilder: (context, index) {
                        final doc = filteredClasses[index];
                        final data = doc.data() as Map<String, dynamic>;
                        final classId = doc.id;
                        final teacherU = (data['teacherUsername'] ?? '')
                            .toString()
                            .trim()
                            .toLowerCase();
                        final isSelected = selectedClassId == classId;

                        return Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  selectedClassId = classId;
                                });
                              },
                              borderRadius: BorderRadius.circular(18),
                              hoverColor: Colors.white.withValues(alpha: 0.05),
                              splashColor: Colors.white.withValues(alpha: 0.04),
                              highlightColor: Colors.white.withValues(
                                alpha: 0.03,
                              ),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEAF6DE)
                                      : Colors.white.withValues(alpha: 0.03),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFFB6D89B)
                                        : Colors.white.withValues(alpha: 0.07),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      classId,
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF40632D)
                                            : Colors.white,
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                      ),
                                    ),
                                    teacherU.isEmpty
                                        ? Text(
                                            'Diriginte: (nepus)',
                                            style: TextStyle(
                                              color: isSelected
                                                  ? const Color(0xFF355126)
                                                  : Colors.white.withValues(
                                                      alpha: 0.70,
                                                    ),
                                              fontSize: 11,
                                            ),
                                          )
                                        : StreamBuilder<QuerySnapshot>(
                                            stream: FirebaseFirestore.instance
                                                .collection('users')
                                                .where(
                                                  'username',
                                                  isEqualTo: teacherU,
                                                )
                                                .limit(1)
                                                .snapshots(),
                                            builder: (context, snap) {
                                              String displayName = teacherU;
                                              if (snap.hasData &&
                                                  snap.data!.docs.isNotEmpty) {
                                                final u =
                                                    snap.data!.docs.first.data()
                                                        as Map<String, dynamic>;
                                                final fn = (u['fullName'] ?? '')
                                                    .toString()
                                                    .trim();
                                                if (fn.isNotEmpty) {
                                                  displayName = fn;
                                                }
                                              }
                                              return Text(
                                                'Diriginte: $displayName',
                                                style: TextStyle(
                                                  color: isSelected
                                                      ? const Color(0xFF355126)
                                                      : Colors.white.withValues(
                                                          alpha: 0.70,
                                                        ),
                                                  fontSize: 11,
                                                ),
                                              );
                                            },
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            // RIGHT CONTENT AREA
            Expanded(
              child: selectedClassId == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              color: primaryGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: Icon(
                              Icons.schedule,
                              size: 50,
                              color: primaryGreen.withValues(alpha: 0.50),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Selectează o clasă din stânga',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Alege o clasă din lista din stânga pentru\na vedea orarul.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF777777),
                            ),
                          ),
                        ],
                      ),
                    )
                  : _buildScheduleDetail(selectedClassId!, allDocs),
            ),
          ],
        );
      },
    );

    if (widget.embedded) return body;

    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7AAF5B), Color(0xFF5A9641)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Orar Clasă',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: body,
    );
  }

  Widget _buildScheduleDetail(
    String classId,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    final classDoc = allDocs.firstWhere((doc) => doc.id == classId);
    final classData = classDoc.data() as Map<String, dynamic>;
    final schedule = classData['schedule'] as Map<String, dynamic>? ?? {};
    final teacherU = (classData['teacherUsername'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    const dayNames = {
      '1': 'Luni',
      '2': 'Marți',
      '3': 'Miercuri',
      '4': 'Joi',
      '5': 'Vineri',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with class info and delete button
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: teacherU.isEmpty
                    ? Text(
                        'Clasa: $classId  |  Diriginte: (nepus)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222222),
                        ),
                      )
                    : StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .where('username', isEqualTo: teacherU)
                            .limit(1)
                            .snapshots(),
                        builder: (context, snap) {
                          String fullName = teacherU;
                          if (snap.hasData && snap.data!.docs.isNotEmpty) {
                            final u =
                                snap.data!.docs.first.data()
                                    as Map<String, dynamic>;
                            final fn = (u['fullName'] ?? '').toString().trim();
                            if (fn.isNotEmpty) fullName = fn;
                          }
                          return Text(
                            'Clasa: $classId  |  Diriginte: $fullName | $teacherU',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222222),
                            ),
                          );
                        },
                      ),
              ),
              GestureDetector(
                onTap: () => _deleteSchedule(classId),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.red.withValues(alpha: 0.30),
                    ),
                  ),
                  child: const Icon(Icons.delete, color: Colors.red, size: 18),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Schedule Items List
        Expanded(
          child: schedule.isEmpty
              ? Center(
                  child: Text(
                    'Nu există date pentru orar',
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                )
              : ListView.builder(
                  itemCount: schedule.keys.length,
                  itemBuilder: (context, index) {
                    final dayNum = (schedule.keys.toList()..sort())[index];
                    final dayName = dayNames[dayNum] ?? 'Ziua $dayNum';
                    final start = schedule[dayNum]['start'] ?? '--:--';
                    final end = schedule[dayNum]['end'] ?? '--:--';

                    return Container(
                      margin: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: primaryGreen.withValues(alpha: 0.20),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        title: Text(
                          dayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF444444),
                          ),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: primaryGreen.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$start - $end',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
