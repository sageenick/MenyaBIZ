import 'package:flutter/material.dart';
import '../widgets/top_bar.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: MenyaAppBar(title: 'Chat'),
      body: Center(child: Text('Chat tab')),
    );
  }
}