import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firster/StudentInterface/cereri.dart';
import 'package:firster/StudentInterface/inbox.dart';
import 'package:firster/StudentInterface/orar.dart';
import 'package:firster/StudentInterface/paginaqr.dart';
import 'package:firster/session.dart';
import 'package:flutter/material.dart';

class MeniuScreen extends StatelessWidget {
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onOpenOrar;

  const MeniuScreen({
    super.key,
    this.onNavigateTab,
    this.onOpenOrar,
  });

  @override
  Widget build(BuildContext context) {
    final fallbackName =
        (AppSession.username?.trim().isNotEmpty ?? false)
            ? AppSession.username!.trim()
            : 'Elev';

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color.fromRGBO(122, 175, 91, 1),
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: _Body(
                user: user,
                fallbackName: fallbackName,
                onNavigateTab: onNavigateTab,
                onOpenOrar: onOpenOrar,
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      color: const Color(0xFF7AAF5B),
      child: Center(
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
    );
  }
}

class _Body extends StatelessWidget {
  final User? user;
  final String fallbackName;
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onOpenOrar;

  const _Body({
    required this.user,
    required this.fallbackName,
    required this.onNavigateTab,
    required this.onOpenOrar,
  });

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Center(child: Text("Utilizator inexistent"));
    }

    final userStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: userStream,
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};

        final fullName = (data['fullName'] ?? '').toString().trim();

        final displayName =
            fullName.isNotEmpty ? fullName : fallbackName;

        final lastOpenedAt =
            (data['inboxLastOpenedAt'] as Timestamp?)?.toDate();

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
          decoration: const BoxDecoration(
            color: Color(0xFFD8DDD8),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              Text(
                'Bun venit, $displayName!',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2E3B4E),
                ),
              ),

              const SizedBox(height: 24),

              _MenuGrid(
                userId: user!.uid,
                lastOpenedAt: lastOpenedAt,
                onNavigateTab: onNavigateTab,
                onOpenOrar: onOpenOrar,
              ),

              const SizedBox(height: 16),

              _StatusCard(userId: user!.uid),

              const Spacer()
            ],
          ),
        );
      },
    );
  }
}

class _MenuGrid extends StatelessWidget {
  final String userId;
  final DateTime? lastOpenedAt;
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onOpenOrar;

  const _MenuGrid({
    required this.userId,
    required this.lastOpenedAt,
    required this.onNavigateTab,
    required this.onOpenOrar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [

        Row(
          children: [
            Expanded(
              child: MenuTile(
                label: "Acces\nQR",
                icon: Icons.qr_code_2_rounded,
                colors: const [Color(0xFF4B78D2), Color(0xFF304EAF)],
                onTap: () {
                  if (onNavigateTab != null) {
                    onNavigateTab!(1);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TeodorScreen(),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MenuTile(
                label: "Orar",
                icon: Icons.calendar_month_rounded,
                colors: const [Color(0xFFF0B15A), Color(0xFFE47E2D)],
                onTap: () {
                  if (onOpenOrar != null) {
                    onOpenOrar!();
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OrarScreen(),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: MenuTile(
                label: "Cereri\nÎnvoire",
                icon: Icons.article,
                colors: const [Color(0xFF17B5A8), Color(0xFF0C8D80)],
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CereriScreen(),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: UnreadMessagesTile(
                userId: userId,
                lastOpenedAt: lastOpenedAt,
              ),
            ),
          ],
        )
      ],
    );
  }
}

class MenuTile extends StatefulWidget {
  final String label;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback? onTap;
  final int? badge;

  const MenuTile({
    super.key,
    required this.label,
    required this.icon,
    required this.colors,
    this.onTap,
    this.badge,
  });

  @override
  State<MenuTile> createState() => _MenuTileState();
}

class _MenuTileState extends State<MenuTile> {

  bool hover=false;

  @override
  Widget build(BuildContext context) {

    return MouseRegion(

      onEnter:(_)=>setState(()=>hover=true),

      onExit:(_)=>setState(()=>hover=false),

      child:GestureDetector(

        onTap:widget.onTap,

        child:AnimatedContainer(

          duration:const Duration(milliseconds:180),

          height:104,

          decoration:BoxDecoration(

            gradient:LinearGradient(

              begin:Alignment.topLeft,

              end:Alignment.bottomRight,

              colors:hover
                  ?widget.colors.map((c)=>c.withOpacity(0.85)).toList()
                  :widget.colors,

            ),

            borderRadius:BorderRadius.circular(18),

            boxShadow:[
              BoxShadow(
                color:Colors.black.withOpacity(0.15),
                blurRadius:8,
                offset:const Offset(0,3),
              )
            ],

          ),

          child:Padding(

            padding:const EdgeInsets.symmetric(horizontal:14),

            child:Row(

              children:[

                Stack(

                  clipBehavior:Clip.none,

                  children:[

                    Icon(widget.icon,color:Colors.white,size:44),

                    if(widget.badge!=null && widget.badge!>0)

                      Positioned(

                        right:-8,

                        top:-8,

                        child:Container(

                          padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),

                          decoration:BoxDecoration(

                            color:Colors.red,

                            borderRadius:BorderRadius.circular(12),

                          ),

                          child:Text(

                            widget.badge.toString(),

                            style:const TextStyle(

                              color:Colors.white,

                              fontWeight:FontWeight.bold,

                            ),

                          ),

                        ),

                      )

                  ],

                ),

                const SizedBox(width:12),

                Expanded(

                  child:Text(

                    widget.label,

                    style:const TextStyle(

                      color:Colors.white,

                      fontSize:24,

                      fontWeight:FontWeight.w700,

                    ),

                  ),

                )

              ],

            ),

          ),

        ),

      ),

    );

  }

}

class UnreadMessagesTile extends StatelessWidget {

  final String userId;

  final DateTime? lastOpenedAt;

  const UnreadMessagesTile({

    super.key,

    required this.userId,

    required this.lastOpenedAt,

  });

  @override

  Widget build(BuildContext context) {

    final leaveRequests = FirebaseFirestore.instance
        .collection('leaveRequests')
        .where('studentUid', isEqualTo: userId)
        .snapshots();

    return StreamBuilder<QuerySnapshot>(

      stream: leaveRequests,

      builder: (context, snap) {

        int unread = 0;

        if (snap.hasData) {

          for (var doc in snap.data!.docs) {

            final ts = (doc['requestedAt'] as Timestamp?)?.toDate();

            if (ts != null &&
                (lastOpenedAt == null || ts.isAfter(lastOpenedAt!))) {
              unread++;
            }
          }
        }

        return MenuTile(
          label: "Mesaje",
          icon: Icons.chat_bubble_rounded,
          colors: const [Color(0xFF9C84E0), Color(0xFF6E46C2)],
          badge: unread,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InboxScreen(),
              ),
            );
          },
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {

  final String userId;

  const _StatusCard({required this.userId});

  @override
  Widget build(BuildContext context) {

    final userStream =
        FirebaseFirestore.instance.collection('users').doc(userId).snapshots();

    return StreamBuilder<DocumentSnapshot>(

      stream: userStream,

      builder: (context, snap) {

        final data = snap.data?.data() as Map<String, dynamic>? ?? {};

        final inSchool = data['inSchool'] == true;

        return Container(

          width: double.infinity,

          padding: const EdgeInsets.all(20),

          decoration: BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.circular(22),

            border: Border.all(color: Colors.black12),

          ),

          child: Row(

            children: [

              const Text(
                "Status elev:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(width: 10),

              Text(
                inSchool ? "În școală" : "În afara incintei",
                style: TextStyle(
                  color: inSchool ? Colors.green : Colors.red,
                ),
              )
            ],
          ),
        );
      },
    );
  }
}