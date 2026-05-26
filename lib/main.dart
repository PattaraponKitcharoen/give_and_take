import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/main_layout.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const GiveAndTakeApp());
}

class GiveAndTakeApp extends StatelessWidget {
  const GiveAndTakeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Give & Take',
      debugShowCheckedModeBanner: false, // เอาป้ายแดง DEBUG มุมขวาบนออก
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF008080)),
        useMaterial3: true,
      ),
      home: const LoginScreen(), // เปลี่ยนให้หน้าแรกวิ่งมาที่ศูนย์บัญชาการ
    );
  }
}