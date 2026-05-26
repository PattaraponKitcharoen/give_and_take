import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_screen.dart'; // Import หน้า Login เพื่อใช้เป็นปลายทางตอนกดออก

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF8FAFC);

  // ดึงข้อมูลผู้ใช้ที่กำลังล็อกอินอยู่ปัจจุบันจาก Firebase
  final User? currentUser = FirebaseAuth.instance.currentUser;

  // ฟังก์ชันสำหรับออกจากระบบ
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut(); // สั่งตัดการเชื่อมต่อกับ Firebase
    
    if (mounted) {
      // พากลับไปหน้า Login และล้างประวัติหน้าจอทั้งหมดทิ้ง (ไม่ให้กด Back กลับมาได้)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'โปรไฟล์ของฉัน',
          style: TextStyle(color: tealColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // รูปโปรไฟล์จำลอง (แบบมินิมอล)
            CircleAvatar(
              radius: 60,
              backgroundColor: tealColor.withOpacity(0.1),
              child: Icon(Icons.person, size: 60, color: tealColor),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'เข้าสู่ระบบด้วยอีเมล:',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 8),
            
            // แสดงอีเมลของผู้ใช้ หรือแสดงข้อความถ้าหาไม่เจอ
            Text(
              currentUser?.email ?? 'ไม่พบข้อมูลอีเมล',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 40),
            
            // ปุ่มออกจากระบบ (ใช้สีแดงให้ดูชัดเจนว่าเป็น Action เชิงลบ)
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout, color: Colors.white),
              label: const Text('ออกจากระบบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}