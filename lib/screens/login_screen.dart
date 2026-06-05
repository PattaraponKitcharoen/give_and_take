import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'main_layout.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 🟢 ปรับเฉดสีให้ตรงกับธีมแอปและเรฟเฟอเรนซ์
  final Color primaryTeal = const Color(0xFF008080);
  final Color lightTeal = const Color(0xFF20C997);
  
  bool _obscureText = true;
  bool _isLoading = false;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกอีเมลและรหัสผ่านให้ครบถ้วน')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ';
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
        setState(() => _isLoading = false);
      }
    }
  }

  // 🟢 Widget ตัวช่วยสร้างป้ายความน่าเชื่อถือด้านล่าง
  Widget _buildTrustBadge(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 12, color: Colors.blueGrey.shade400, fontWeight: FontWeight.w500)),
      ],
    );
  }

@override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [primaryTeal.withOpacity(0.15), Colors.white],
            stops: const [0.0, 1.0],
          ),
        ),
        child: SafeArea(
          // 🟢 ใช้ LayoutBuilder เพื่อให้เช็คความสูงหน้าจอได้
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                // 🟢 ล็อคไม่ให้เลื่อน โดยใช้ NeverScrollableScrollPhysics
                physics: const NeverScrollableScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center, // จัดให้อยู่กลางหน้าจอ
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      const SizedBox(height: 40),
                      
                      // 🟢 โลโก้แอปพร้อมเอฟเฟกต์กล่องเรืองแสง
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 85,
                          height: 85,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primaryTeal, lightTeal],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: primaryTeal.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          // 🟢 ใส่รูปโลโก้ของคุณตรงนี้
                          child: Image.asset(
                            'assets/logo.png', 
                            color: Colors.white, // หากต้องการให้โลโก้เป็นสีขาว (ลบออกได้ถ้าโลโก้มีสีอยู่แล้ว)
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        'Give & Take',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          color: primaryTeal,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'แลกเปลี่ยนสิ่งที่คุณมี กับสิ่งที่คุณต้องการ',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade600, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 40),

                      // 🟢 ช่องกรอก Email (ดีไซน์ขอบมน มินิมอล)
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email address',
                          hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontWeight: FontWeight.w500),
                          prefixIcon: Icon(Icons.email_outlined, color: Colors.blueGrey.shade400, size: 22),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: primaryTeal, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🟢 ช่องกรอก Password
                      TextField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          hintStyle: TextStyle(color: Colors.blueGrey.shade300, fontWeight: FontWeight.w500),
                          prefixIcon: Icon(Icons.lock_outline, color: Colors.blueGrey.shade400, size: 22),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: Colors.blueGrey.shade400,
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: Colors.grey.shade200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide(color: primaryTeal, width: 2),
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 20),
                        ),
                      ),
                      
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () {},
                          child: Text('Forgot password?', style: TextStyle(color: primaryTeal, fontSize: 13, fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 🟢 ปุ่มเข้าสู่ระบบแบบมีเงาเรืองแสง (Glow Effect)
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: lightTeal.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: lightTeal, // สีเขียวสว่างตามเรฟเฟอเรนซ์
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0, 
                          ),
                          child: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Login', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(child: Divider(thickness: 1, color: Colors.grey.shade200)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text('or continue with', style: TextStyle(color: Colors.blueGrey.shade400, fontSize: 13)),
                          ),
                          Expanded(child: Divider(thickness: 1, color: Colors.grey.shade200)),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // 🟢 ปุ่ม Google (ใช้ไอคอนที่มีสีสันเพื่อให้ดูเป็นทางการ)
                      OutlinedButton(
                        onPressed: () {},
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade200),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // คุณสามารถเปลี่ยนเป็น Image.asset('assets/google_logo.png') ได้ถ้ามีไฟล์
                            const Icon(Icons.g_mobiledata_rounded, size: 32, color: Colors.redAccent),
                            const SizedBox(width: 8),
                            Text('Continue with Google', style: TextStyle(fontSize: 15, color: Colors.blueGrey.shade800, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      
                      // 🟢 ส่วนสมัครสมาชิกด้านล่างสุด
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Don't have an account? ", style: TextStyle(color: Colors.blueGrey.shade500, fontSize: 14)),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
                            },
                            child: Text('Sign up', style: TextStyle(color: primaryTeal, fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ],
                      ),
                    ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}