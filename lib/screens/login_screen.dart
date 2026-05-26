import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart'; // 🟢 1. Import หลังบ้าน Firebase Auth
import 'main_layout.dart'; // Import หน้าหลักไว้สำหรับเปลี่ยนหน้าหลังจากล็อกอินสำเร็จ

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF8FAFC);
  
  bool _obscureText = true;
  bool _isLoading = false; // ตัวแปรสำหรับเช็คสถานะการโหลด

  // 🟢 2. สร้าง Controller สำหรับดึงข้อความจากช่องกรอกข้อมูล
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    // ล้างหน่วยความจำเมื่อไม่ได้ใช้หน้าจอนี้แล้ว
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // 🟢 3. ฟังก์ชันสำหรับส่งข้อมูลไปเช็คกับฐานข้อมูล Firebase
  Future<void> _login() async {
    // ดึงค่าข้อความและตัดช่องว่างหัวท้ายออก
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    // เช็คกรณีปล่อยว่าง
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกอีเมลและรหัสผ่านให้ครบถ้วน')),
      );
      return;
    }

    setState(() {
      _isLoading = true; // เปิดเอฟเฟกต์กำลังโหลดบนปุ่ม
    });

    try {
      // ส่งคำสั่งเข้าสู่ระบบไปที่ Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        // ล็อกอินสำเร็จ เปลี่ยนหน้าไปยัง MainLayout ทันที
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ';
      
      // คัดกรองโค้ด Error ยอดฮิตเพื่อแจ้งเตือนผู้ใช้ให้ตรงจุด
      if (e.code == 'user-not-found') {
        message = 'ไม่พบบัญชีผู้ใช้นี้ในระบบ';
      } else if (e.code == 'wrong-password') {
        message = 'รหัสผ่านไม่ถูกต้อง';
      } else if (e.code == 'invalid-email') {
        message = 'รูปแบบอีเมลไม่ถูกต้อง';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // ปิดเอฟเฟกต์กำลังโหลด
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.handshake_rounded, size: 72, color: tealColor),
                const SizedBox(height: 16),
                Text(
                  'Give & Take',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: tealColor,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'เข้าสู่ระบบเพื่อเริ่มแลกเปลี่ยนสิ่งของ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
                const SizedBox(height: 50),

                // ช่องกรอก Email (ผูก Controller เข้าไป)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _emailController, // ผูกกับตัวแปรคอนโทรลเลอร์
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'อีเมล',
                      hintStyle: const TextStyle(color: Colors.black38),
                      prefixIcon: Icon(Icons.email_outlined, color: tealColor, size: 22),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // ช่องกรอก Password (ผูก Controller เข้าไป)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _passwordController, // ผูกกับตัวแปรคอนโทรลเลอร์
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      hintText: 'รหัสผ่าน',
                      hintStyle: const TextStyle(color: Colors.black38),
                      prefixIcon: Icon(Icons.lock_outline, color: tealColor, size: 22),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_off : Icons.visibility,
                          color: Colors.black38,
                          size: 20,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('ลืมรหัสผ่าน?', style: TextStyle(color: tealColor, fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 24),

                // ปุ่มเข้าสู่ระบบ (ผูกฟังก์ชัน _login และแสดงผลปุ่มโหลดตามสถานะ)
                ElevatedButton(
                  onPressed: _isLoading ? null : _login, // ถ้ากำลังโหลดอยู่จะกดปุ่มซ้ำไม่ได้
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tealColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    elevation: 3,
                    shadowColor: tealColor.withOpacity(0.5),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
                
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('หรือ', style: TextStyle(color: Colors.black45, fontSize: 13)),
                    ),
                    Expanded(child: Divider(thickness: 1, color: Colors.grey.shade300)),
                  ],
                ),
                const SizedBox(height: 32),

                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.g_mobiledata_rounded, size: 28, color: Colors.black87),
                  label: const Text(
                    'ดำเนินการต่อด้วย Google',
                    style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('ยังไม่มีบัญชี?', style: TextStyle(color: Colors.black54, fontSize: 14)),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: () {
                        // TODO: ไปหน้า Register ชั่วคราว
                      },
                      child: Text('สมัครสมาชิก', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}