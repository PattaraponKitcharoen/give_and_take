import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final Color tealColor = const Color(0xFF008080);
  final Color bgColor = const Color(0xFFF8FAFC);
  
  bool _obscureText = true;
  bool _obscureConfirmText = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    // 1. ตรวจสอบว่ากรอกข้อมูลครบหรือไม่
    if (email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบถ้วน')),
      );
      return;
    }

    // 2. ตรวจสอบว่ารหัสผ่านตรงกันหรือไม่
    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // 3. ส่งคำสั่งสร้างบัญชีไปที่ Firebase
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        // เมื่อสมัครสำเร็จ ให้พาเข้าสู่หน้าหลักของแอปทันที
        // ใช้ pushAndRemoveUntil เพื่อลบประวัติการย้อนกลับ ไม่ให้กด Back กลับมาหน้า Register ได้อีก
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (route) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'เกิดข้อผิดพลาดในการสมัครสมาชิก';
      
      if (e.code == 'weak-password') {
        message = 'รหัสผ่านอ่อนเกินไป (ต้อง 6 ตัวอักษรขึ้นไป)';
      } else if (e.code == 'email-already-in-use') {
        message = 'อีเมลนี้ถูกใช้งานในระบบแล้ว';
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
          _isLoading = false;
        });
      }
    }
  }

  // ฟังก์ชันช่วยสร้างกล่องกรอกข้อมูลเพื่อลดความซ้ำซ้อนของโค้ด
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool? obscureState,
    VoidCallback? onToggleObscure,
  }) {
    return Container(
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
        controller: controller,
        obscureText: isPassword ? (obscureState ?? true) : false,
        keyboardType: isPassword ? TextInputType.text : TextInputType.emailAddress,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: Colors.black38),
          prefixIcon: Icon(icon, color: tealColor, size: 22),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureState! ? Icons.visibility_off : Icons.visibility,
                    color: Colors.black38,
                    size: 20,
                  ),
                  onPressed: onToggleObscure,
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black87),
          onPressed: () => Navigator.pop(context), // ปุ่มกดย้อนกลับไปหน้า Login
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.person_add_alt_1_rounded, size: 72, color: tealColor),
                const SizedBox(height: 16),
                Text(
                  'สร้างบัญชีใหม่',
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
                  'เข้าร่วมเป็นส่วนหนึ่งของ Give & Take',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.black54),
                ),
                const SizedBox(height: 40),

                _buildTextField(
                  controller: _emailController,
                  hintText: 'อีเมล',
                  icon: Icons.email_outlined,
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _passwordController,
                  hintText: 'รหัสผ่าน (6 ตัวอักษรขึ้นไป)',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureState: _obscureText,
                  onToggleObscure: () => setState(() => _obscureText = !_obscureText),
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  controller: _confirmPasswordController,
                  hintText: 'ยืนยันรหัสผ่าน',
                  icon: Icons.lock_reset_outlined,
                  isPassword: true,
                  obscureState: _obscureConfirmText,
                  onToggleObscure: () => setState(() => _obscureConfirmText = !_obscureConfirmText),
                ),
                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
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
                    : const Text('สมัครสมาชิก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}