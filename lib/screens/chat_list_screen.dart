import 'package:flutter/material.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('หน้า Chat (กล่องข้อความ)', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}