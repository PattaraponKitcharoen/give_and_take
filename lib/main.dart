import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🟢 1. เพิ่ม Import สำหรับใช้งาน Auth
import 'firebase_options.dart';
import 'screens/main_layout.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await NotificationService().initNotification();
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
      // 🟢 2. เปลี่ยน home เป็น StreamBuilder เพื่อเช็กสถานะการล็อกอิน
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // กรณีที่กำลังรอการเชื่อมต่อกับ Firebase (ใช้เวลาเสี้ยววินาที)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF008080)),
              ),
            );
          }
          
          // ถ้าตรวจพบว่ามีข้อมูล User (เคยล็อกอินค้างไว้) ให้พุ่งไปที่หน้าหลักทันที
          if (snapshot.hasData) {
            return const MainLayout();
          }
          
          // ถ้าไม่มีข้อมูล User (ยังไม่ล็อกอิน หรือเพิ่งโหลดแอป) ให้แสดงหน้า Login
          return const LoginScreen(); 
        },
      ),
    );
  }
}