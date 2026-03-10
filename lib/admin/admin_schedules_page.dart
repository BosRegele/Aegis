import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminSchedulesPage extends StatefulWidget {
  const AdminSchedulesPage({super.key});

  @override
  State<AdminSchedulesPage> createState() => _AdminSchedulesPageState();
}

class _AdminSchedulesPageState extends State<AdminSchedulesPage> {
  final Color primaryGreen = const Color(0xFF5EB84E);
  final Color darkGreen = const Color(0xFF5ECA36);
  final Color lightGreen = const Color(0xFFF0F4E8);
  String? selectedClassId;
  final _classSearchC = TextEditingController();
  String _classQuery = "";

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
            SnackBar(content: Text('Error deleting schedule: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: lightGreen,
      appBar: AppBar(
        backgroundColor: primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Orar Clasa',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('classes')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allDocs = snapshot.data?.docs ?? [];
          final classesWithSchedule = allDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return data.containsKey('schedule') &&
                (data['schedule'] as Map?)?.isNotEmpty == true;
          }).toList();

          // Set first class as selected if none selected
          if (selectedClassId == null && classesWithSchedule.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  selectedClassId = classesWithSchedule.first.id;
                });
              }
            });
          }

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
                color: darkGreen,
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
                            color: Colors.white.withOpacity(0.6),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.white.withOpacity(0.6),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.1),
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
                          final classId = doc.id;
                          final isSelected = selectedClassId == classId;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                selectedClassId = classId;
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    classId,
                                    style: TextStyle(
                                      color: isSelected
                                          ? darkGreen
                                          : Colors.white,
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // RIGHT CONTENT AREA
              Expanded(
                child: selectedClassId == null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.schedule,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Select a class to view schedule',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
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
      ),
    );
  }

  Widget _buildScheduleDetail(
    String classId,
    List<QueryDocumentSnapshot> allDocs,
  ) {
    final classDoc = allDocs.firstWhere((doc) => doc.id == classId);
    final classData = classDoc.data() as Map<String, dynamic>;
    final schedule = classData['schedule'] as Map<String, dynamic>? ?? {};

    const dayNames = {
      '1': 'Luni (Monday)',
      '2': 'Marți (Tuesday)',
      '3': 'Miercuri (Wednesday)',
      '4': 'Joi (Thursday)',
      '5': 'Vineri (Friday)',
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Clasa: $classId',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (schedule.isNotEmpty)
                      Text(
                        'Orar configurar',
                        style: TextStyle(
                          fontSize: 15,
                          color: primaryGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _deleteSchedule(classId),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.delete,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Schedule Title
          const Text(
            'Program zilei',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          // Schedule Items
          if (schedule.isEmpty)
            Center(
              child: Text(
                'No schedule data',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
            )
          else
            Column(
              children: (schedule.keys.toList()..sort()).map((dayNum) {
                final dayName = dayNames[dayNum] ?? 'Day $dayNum';
                final start = schedule[dayNum]['start'] ?? '--:--';
                final end = schedule[dayNum]['end'] ?? '--:--';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: primaryGreen.withOpacity(0.2)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: primaryGreen.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
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
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
