import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'main_layout.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final Color tealColor = const Color(0xFF10B981); 
  final Color bgColor = const Color(0xFFF8FAFC);
  
  bool _obscureText = true;
  bool _obscureConfirmText = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง')));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน')));
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณายอมรับเงื่อนไขและข้อตกลงการใช้งาน')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(email: email, password: password);

      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
          'user_id': userCredential.user!.uid,
          'email': email,
          'name': name, 
          'bio': '',
          'tel': '',
          'profile_img_url': '',
          'coins_balance': 1000, 
          'created_at': FieldValue.serverTimestamp(),
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const MainLayout()), (route) => false);
      }
    } on FirebaseAuthException catch (e) {
      String message = 'เกิดข้อผิดพลาดในการสมัครสมาชิก';
      if (e.code == 'weak-password') message = 'รหัสผ่านอ่อนเกินไป (ต้อง 6 ตัวอักษรขึ้นไป)';
      else if (e.code == 'email-already-in-use') message = 'อีเมลนี้ถูกใช้งานในระบบแล้ว';
      else if (e.code == 'invalid-email') message = 'รูปแบบอีเมลไม่ถูกต้อง';

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildLabeledTextField({
    required String label,
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    bool isPassword = false,
    bool? obscureState,
    VoidCallback? onToggleObscure,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 0.5)),
        const SizedBox(height: 4), // 🟢 บีบช่องว่าง
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12), // 🟢 ลดความมนลงนิดนึง
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: TextField(
            controller: controller,
            obscureText: isPassword ? (obscureState ?? true) : false,
            keyboardType: isPassword ? TextInputType.text : TextInputType.emailAddress,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 18),
              suffixIcon: isPassword
                  ? IconButton(icon: Icon(obscureState! ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade400, size: 18), onPressed: onToggleObscure)
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12), // 🟢 บีบความอ้วนของช่องกรอก
            ),
          ),
        ),
        const SizedBox(height: 12), // 🟢 บีบช่องว่างระหว่างช่องกรอก
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(), // 🟢 ป้องกันการเด้งยืดหยุ่นตอนสไลด์ ทำให้เหมือนโดนล็อค
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0), // 🟢 บีบขอบด้านข้างและบนล่าง
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // 🟢 ดึงรูปแอปไอคอนของคุณมาใช้ (ครอบให้ขอบมนนิดๆ ให้ดูเป็นโลโก้)
              Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset('assets/logo.png', width: 80, height: 80,color: Color.fromARGB(255, 16, 159, 111), fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Create an Account',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87), // 🟢 ลดขนาดฟอนต์หัวข้อ
              ),
              const SizedBox(height: 4),
              const Text(
                'Join the marketplace. Trade what you have.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.blueGrey), // 🟢 ลดขนาดฟอนต์ซับไตเติ้ล
              ),
              const SizedBox(height: 24), // 🟢 บีบช่องว่างก่อนเข้าฟอร์ม

              _buildLabeledTextField(label: 'FULL NAME', controller: _nameController, hintText: 'John Doe', icon: Icons.person_outline),
              _buildLabeledTextField(label: 'EMAIL ADDRESS', controller: _emailController, hintText: 'email@example.com', icon: Icons.mail_outline),
              _buildLabeledTextField(label: 'PASSWORD', controller: _passwordController, hintText: '••••••••', icon: Icons.lock_outline, isPassword: true, obscureState: _obscureText, onToggleObscure: () => setState(() => _obscureText = !_obscureText)),
              _buildLabeledTextField(label: 'CONFIRM PASSWORD', controller: _confirmPasswordController, hintText: '••••••••', icon: Icons.lock_outline, isPassword: true, obscureState: _obscureConfirmText, onToggleObscure: () => setState(() => _obscureConfirmText = !_obscureConfirmText)),

              // Checkbox 
              Row(
                children: [
                  SizedBox(
                    width: 20, height: 20,
                    child: Checkbox(value: _agreeToTerms, activeColor: tealColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), onChanged: (value) => setState(() => _agreeToTerms = value ?? false)),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        style: TextStyle(fontSize: 12, color: Colors.blueGrey), // 🟢 ลดขนาดฟอนต์
                        children: [
                          TextSpan(text: 'Terms of Service', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          TextSpan(text: ' and '),
                          TextSpan(text: 'Privacy Policy', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ปุ่ม Sign Up
              ElevatedButton(
                onPressed: _isLoading ? null : _register,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tealColor, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14), // 🟢 บีบความอ้วนปุ่ม
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2, shadowColor: tealColor.withOpacity(0.4),
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Sign Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('OR CONTINUE WITH', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black26))),
                  Expanded(child: Divider(color: Colors.grey.shade300)),
                ],
              ),
              const SizedBox(height: 20),

              OutlinedButton.icon(
                onPressed: () {},
                icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent)), 
                label: const Text('Google', style: TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12), // 🟢 บีบปุ่ม Google
                  backgroundColor: Colors.white, side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ', style: TextStyle(color: Colors.blueGrey, fontSize: 13)),
                  GestureDetector(
                    onTap: () => Navigator.pop(context), 
                    child: Text('Log In', style: TextStyle(color: tealColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}