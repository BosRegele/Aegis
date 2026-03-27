import 'package:flutter/material.dart';
import 'package:firster/common/unified_messages_page.dart';

class MesajeDirPage extends StatefulWidget {
  const MesajeDirPage({super.key});

  @override
  State<MesajeDirPage> createState() => _MesajeDirPageState();
}

class _MesajeDirPageState extends State<MesajeDirPage> {
  @override
  Widget build(BuildContext context) {
    return const UnifiedMessagesPage(role: UnifiedInboxRole.teacher);
  }
}
