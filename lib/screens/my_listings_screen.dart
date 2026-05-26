import 'package:flutter/material.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('หน้า My Listings (คลังสมบัติของฉัน)', style: TextStyle(fontSize: 20)),
      ),
    );
  }
}