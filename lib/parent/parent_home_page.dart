import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../Auth/login_page_firestore.dart';
import 'parent_students_page.dart';
import 'parent_requests_page.dart';
import 'parent_inbox_page.dart';
import '../session.dart';

class ParentHomePage extends StatefulWidget {
  const ParentHomePage({super.key});

  @override
  State<ParentHomePage> createState() => _ParentHomePageState();
}

class _ParentHomePageState extends State<ParentHomePage> {
  String? _fullName;
  List<String> _childrenUids = [];

  @override
  void initState() {
    super.initState();
    _loadParentName();
  }

  Future<void> _loadParentName() async {
    final uid = AppSession.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() => _fullName = data['fullName'] as String?);
        final children = data['children'];
        if (children is List) {
          setState(() => _childrenUids = List<String>.from(children));
        }
      }
    } catch (_) {}
  }

  Future<void> _signOut() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF7AAF5B), // Verdele de pe pagina principala
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Deconectare',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.white)), // Text alb
          content: const Text('Esti sigur ca vrei sa te deconectezi?',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white)), // Text alb
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            Container(
              width: double.maxFinite,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                children: [
                  Expanded(
                    child: _BouncingButton( // Buton Anulare (Dialog)
                      onTap: () => Navigator.pop(context, false),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Anulează',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _BouncingButton( // Buton Deconectare (Dialog)
                      onTap: () => Navigator.pop(context, true),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Deconectare',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPageFirestore()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF7AAF5B),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 110,
              color: const Color(0xFF7AAF5B),
              child: Stack(
                children: [
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          bottom: 8,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.22),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.shield_rounded,
                          size: 72,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 20,
                    right: 20,
                    child: _BouncingButton( // Buton Deconectare (Header)
                      onTap: _signOut,
                      borderRadius: BorderRadius.circular(30),
                      child: const SizedBox(
                        width: 52,
                        height: 52,
                        child: Icon(Icons.logout, color: Colors.white, size: 30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F7FA), // Background nou
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 26.0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 26.0),
                          child: Text(
                            'Bine ai venit,\n${_fullName ?? AppSession.username ?? "Părinte"}!',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 32,
                              color: Color(0xFF1F252B),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      // Ascultăm profilul utilizatorului pentru a vedea când a deschis ultima oară meniurile
                      StreamBuilder<DocumentSnapshot>(
                        stream: AppSession.uid != null
                            ? FirebaseFirestore.instance
                                .collection('users')
                                .doc(AppSession.uid)
                                .snapshots()
                            : null,
                        builder: (context, userSnap) {
                          final userData = userSnap.data?.data() as Map<String, dynamic>? ?? {};
                          final requestsLastOpened = (userData['requestsLastOpenedAt'] as Timestamp?)?.toDate();
                          final inboxLastOpened = (userData['inboxLastOpenedAt'] as Timestamp?)?.toDate();

                          return Column(
                            children: [
                              _buildMenuButton(
                                context,
                                title: "Elevi",
                                icon: Icons.people_outline,
                                // Elevi - Portocaliu
                                colors: const [Color(0xFFF0B15A), Color(0xFFE47E2D)],
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const ParentStudentsPage(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              _buildMenuButton(
                                context,
                                title: "Cereri de învoire",
                                icon: Icons.mail_outline,
                                // Cereri - Turcoaz
                                colors: const [Color(0xFF17B5A8), Color(0xFF0C8D80)],
                                badgeStream: _childrenUids.isNotEmpty
                                    ? FirebaseFirestore.instance
                                        .collection('leaveRequests')
                                        .where('studentUid', whereIn: _childrenUids)
                                    .where('targetRole', isEqualTo: 'parent')
                                        .where('status', isEqualTo: 'pending')
                                        .snapshots()
                                    : null,
                                countPredicate: (data) => data['viewedByParent'] != true,
                                onTap: () {
                                  // Marcam notificarile ca citite inainte de navigare
                                  if (AppSession.uid != null) {
                                    FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(AppSession.uid)
                                        .update({
                                      'requestsLastOpenedAt':
                                          FieldValue.serverTimestamp(),
                                    });
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ParentRequestsPage()),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              _buildMenuButton(
                                context,
                                title: "Mesaje",
                                icon: Icons.inbox_outlined,
                                // Mesaje - Albastru
                                colors: const [Color(0xFF4B78D2), Color(0xFF304EAF)],
                                badgeStream: _childrenUids.isNotEmpty
                                    ? FirebaseFirestore.instance
                                        .collection('leaveRequests')
                                        .where('studentUid', whereIn: _childrenUids)
                                        .snapshots()
                                    : null,
                                statusWhitelist: const ['approved', 'rejected'],
                                lastViewed: inboxLastOpened,
                                timestampField: 'reviewedAt',
                                onTap: () {
                                  // Marcam notificarile ca citite inainte de navigare
                                  if (AppSession.uid != null) {
                                    FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(AppSession.uid)
                                        .update({
                                      'inboxLastOpenedAt': FieldValue.serverTimestamp(),
                                    });
                                  }
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ParentInboxPage()),
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                            ],
                          );
                        }
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onTap,
    Stream<QuerySnapshot>? badgeStream,
    DateTime? lastViewed,
    String? timestampField,
    List<String>? statusWhitelist,
    bool Function(Map<String, dynamic>)? countPredicate,
  }) {
    // Folosim _BouncingButton in loc de InkWell pentru efectul cerut
    return _BouncingButton(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
          borderRadius: BorderRadius.circular(24),
          // Less intense shadow to match clean student look
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, size: 48, color: Colors.white),
                if (badgeStream != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: badgeStream,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return const SizedBox();
                        }
                        
                        // Calculam cate sunt necitite
                        int count = 0;
                        if (countPredicate != null) {
                          count = snapshot.data!.docs.where((doc) => countPredicate(doc.data() as Map<String, dynamic>)).length;
                        } else if (lastViewed == null) {
                          count = snapshot.data!.docs.length;
                        } else {
                          var docs = snapshot.data!.docs;
                          if (statusWhitelist != null) {
                            docs = docs.where((d) => statusWhitelist.contains(d['status'])).toList();
                          }
                          count = docs.where((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final ts = (data[timestampField] as Timestamp?)?.toDate();
                            return ts != null && ts.isAfter(lastViewed);
                          }).length;
                        }

                        if (count == 0) return const SizedBox();

                        return Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '$count',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BouncingButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final BorderRadius borderRadius;

  const _BouncingButton({
    required this.child,
    required this.onTap,
    required this.borderRadius,
  });

  @override
  State<_BouncingButton> createState() => _BouncingButtonState();
}

class _BouncingButtonState extends State<_BouncingButton> {
  double _scale = 1.0;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() {
        _scale = 0.95;
        _isPressed = true;
      }),
      onTapUp: (_) {
        setState(() {
          _scale = 1.0;
          _isPressed = false;
        });
        Future.delayed(const Duration(milliseconds: 100), widget.onTap);
      },
      onTapCancel: () => setState(() {
        _scale = 1.0;
        _isPressed = false;
      }),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: Stack(
          children: [
            widget.child,
            // Overlay negru pentru efectul de "nuanta mai inchisa"
            Positioned.fill(
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
                opacity: _isPressed ? 0.2 : 0.0, // transparenta neagra cand e apasat
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: widget.borderRadius,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
