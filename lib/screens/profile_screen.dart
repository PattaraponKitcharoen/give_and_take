import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'login_screen.dart'; 
import 'edit_profile_screen.dart'; // 🟢 อย่าลืม Import ไฟล์แก้ไข
import 'wallet_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF8FAFC);
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) return const Scaffold(body: Center(child: Text('กรุณาล็อกอิน')));

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text('โปรไฟล์ของฉัน', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        actions: [
          // 🟢 ปุ่มแก้ไขมุมขวาบน
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
            builder: (context, snapshot) {
              Map<String, dynamic> userData = {};
              if (snapshot.hasData && snapshot.data!.exists) {
                userData = snapshot.data!.data() as Map<String, dynamic>;
              }
              return IconButton(
                icon: const Icon(Icons.edit, color: Colors.black87),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => EditProfileScreen(currentData: userData)));
                },
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        // 🟢 วิ่งไปดึงข้อมูลจาก Schema users
        stream: FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

          // ถ้ายังไม่มีเอกสาร (เพิ่งสมัครใหม่) ให้ใช้ค่าว่างไปก่อน
          Map<String, dynamic> userData = {};
          if (snapshot.hasData && snapshot.data!.exists) {
            userData = snapshot.data!.data() as Map<String, dynamic>;
          }

          final String name = userData['name'] ?? 'ผู้ใช้ใหม่ (ยังไม่ตั้งชื่อ)';
          final String email = currentUser!.email ?? '';
          final String bio = userData['bio'] ?? 'ยังไม่มีคำอธิบายตัวเอง';
          final String tel = userData['tel'] ?? 'ยังไม่ระบุเบอร์โทร';
          final int coins = userData['coins_balance'] ?? 0;
          final String profileImg = userData['profile_img_url'] ?? '';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // รูปโปรไฟล์
                CircleAvatar(
                  radius: 50,
                  backgroundColor: tealColor.withOpacity(0.1),
                  backgroundImage: profileImg.isNotEmpty ? NetworkImage(profileImg) : null,
                  child: profileImg.isEmpty ? Icon(Icons.person, size: 50, color: tealColor) : null,
                ),
                const SizedBox(height: 16),
                
                // ชื่อ และ อีเมล
                Text(name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 4),
                Text(email, style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 24),

                // กล่องโชว์ยอดเหรียญ Coins (อัปเดตให้กดได้)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const WalletHistoryScreen()),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [tealColor, tealColor.withOpacity(0.8)]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: tealColor.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet, color: Colors.white, size: 40),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('กระเป๋าเหรียญ (Coins)', style: TextStyle(color: Colors.white70)),
                            Text('$coins', style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16), // เพิ่มไอคอนลูกศรให้รู้ว่ากดได้
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ข้อมูลส่วนตัวอื่นๆ (Bio, Tel)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('เกี่ยวกับฉัน', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(bio, style: const TextStyle(color: Colors.black87, height: 1.5)),
                      const Divider(height: 32),
                      
                      const Text('เบอร์โทรศัพท์', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      Text(tel, style: const TextStyle(color: Colors.black87)),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // ปุ่มล็อกเอาต์
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text('ออกจากระบบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                    ),
                  ),
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}