import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart'; // ไฟล์นี้ FlutterFire สร้างให้เราตอน configure

void main() async {
  // คำสั่งนี้บอกให้ Flutter รอจัดการระบบหลังบ้านให้เสร็จก่อนค่อยวาดหน้าจอ
  WidgetsFlutterBinding.ensureInitialized();
  
  // ปลุกเสก Firebase
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF008080)), // สี Deep Teal ของเรา!
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Text('Firebase พร้อมลุย! 🚀'),
        ),
      ),
    );
  }
}