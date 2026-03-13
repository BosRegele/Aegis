import 'package:flutter/material.dart';
import '../session.dart';

class OrarDirPage extends StatefulWidget {
  const OrarDirPage({super.key});

  @override
  State<OrarDirPage> createState() => _OrarDirPageState();
}

class _OrarDirPageState extends State<OrarDirPage> {
  @override
  Widget build(BuildContext context) {
    // schedule screen with profile header
    final displayName = (AppSession.username?.trim().isNotEmpty ?? false)
        ? AppSession.username!.trim()
        : 'Elev';
    final studentId = (AppSession.uid?.isNotEmpty ?? false)
        ? AppSession.uid!.substring(
            0,
            AppSession.uid!.length >= 6 ? 6 : AppSession.uid!.length,
          )
        : 'N/A';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromRGBO(122, 175, 91, 1),
        title: const Text('Profil', style: TextStyle(color: Colors.white)),
      ),
      bottomNavigationBar: Container(
        height: 56,
        color: const Color.fromRGBO(122, 175, 91, 1),
      ),
      body: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color.fromRGBO(122, 175, 91, 1),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F2),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 98,
                                height: 106,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDCEED5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 56,
                                  color: Color(0xFF6C7D62),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      displayName,
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                        color: Color(0xFF171717),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Diriginte',
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: Color(0xFF303030),
                                      ),
                                    ),
                                    const Text(
                                      'Clasa 11 I',
                                      style: TextStyle(
                                        fontSize: 22,
                                        color: Color(0xFF303030),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(height: 1, color: const Color(0xFFB8B8B8)),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Professor ID: $studentId',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF333333),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Orar',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF161616),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const _OrarRow(day: 'Luni', interval: '07:30 - 12:30'),
                  const SizedBox(height: 10),
                  const _OrarRow(day: 'Marti', interval: '07:30 - 12:30'),
                  const SizedBox(height: 10),
                  const _OrarRow(day: 'Miercuri', interval: '07:30 - 12:30'),
                  const SizedBox(height: 10),
                  const _OrarRow(day: 'Joi', interval: '07:30 - 12:30'),
                  const SizedBox(height: 10),
                  const _OrarRow(day: 'Vineri', interval: '07:30 - 12:30'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// simple row widget used by the schedule screen
class _OrarRow extends StatelessWidget {
  final String day;
  final String interval;

  const _OrarRow({required this.day, required this.interval});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Text(
            day,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1C1C1C),
            ),
          ),
          const Spacer(),
          Text(
            interval,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1C1C1C),
            ),
          ),
        ],
      ),
    );
  }
}
