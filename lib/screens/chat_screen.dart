import 'package:flutter/material.dart';
import '../l10n/strings.dart';
import '../widgets/top_bar.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MenyaAppBar(title: tr('chat')),
      body: Center(child: Text(tr('chat_soon'))),
    );
  }
}