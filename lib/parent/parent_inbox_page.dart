import 'package:flutter/material.dart';
import 'package:firster/common/unified_messages_page.dart';

class ParentInboxPage extends StatelessWidget {
  const ParentInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const UnifiedMessagesPage(role: UnifiedInboxRole.parent);
  }
}
