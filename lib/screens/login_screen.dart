import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/auth/auth_state.dart';
import '../repositories/auth_repository.dart';
import '../widgets/google_sign_in_button.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/primary_button.dart';
import 'main_layout.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _obscureText = true;
  bool _isLoading = false;
  bool _isGoogleLoading = false;

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
        const SnackBar(
            content: Text('กรุณากรอกอีเมลและรหัสผ่านให้ครบถ้วน'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await context.read<AuthRepository>().signInWithEmailAndPassword(
            email,
            password,
          );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Login failed: code=${e.code}, message=${e.message}');
      String message = 'เกิดข้อผิดพลาดในการเข้าสู่ระบบ';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        // Current Firebase Auth backends return 'invalid-credential' for both
        // a wrong password and a non-existent account (to avoid leaking which
        // one it is), instead of the older 'user-not-found'/'wrong-password'.
        message = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
      } else if (e.code == 'invalid-email') {
        message = 'รูปแบบอีเมลไม่ถูกต้อง';
      } else if (e.code == 'user-disabled') {
        message =
            'บัญชีนี้ถูกระงับการใช้งานถาวร หากคิดว่าเป็นความผิดพลาด กรุณาติดต่อผู้ดูแลระบบ';
      } else if (e.code == 'too-many-requests') {
        message = 'พยายามเข้าสู่ระบบบ่อยเกินไป กรุณาลองใหม่ภายหลัง';
      } else if (e.code == 'network-request-failed') {
        message = 'ไม่สามารถเชื่อมต่ออินเทอร์เน็ตได้ กรุณาตรวจสอบการเชื่อมต่อ';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() => _isGoogleLoading = true);
    final authCubit = context.read<AuthCubit>();
    await authCubit.signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    final state = authCubit.state;
    if (state is AuthError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(state.message), behavior: SnackBarBehavior.floating),
      );
    }
    if (context.read<AuthRepository>().currentUser != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainLayout()),
      );
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final resetEmailController =
        TextEditingController(text: _emailController.text.trim());
    final authRepository = context.read<AuthRepository>();

    final email = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('รีเซ็ตรหัสผ่าน'),
        content: TextField(
          controller: resetEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Email address',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, resetEmailController.text.trim()),
            child: const Text('ส่งลิงก์รีเซ็ต'),
          ),
        ],
      ),
    );

    resetEmailController.dispose();
    if (email == null || email.isEmpty) return;

    try {
      await authRepository.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'ส่งลิงก์รีเซ็ตรหัสผ่านไปที่ $email แล้ว กรุณาตรวจสอบอีเมล'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Password reset failed: code=${e.code}, message=${e.message}');
      String message = 'ไม่สามารถส่งอีเมลรีเซ็ตรหัสผ่านได้';
      if (e.code == 'user-not-found') {
        message = 'ไม่พบบัญชีผู้ใช้ที่ใช้อีเมลนี้';
      } else if (e.code == 'invalid-email') {
        message = 'รูปแบบอีเมลไม่ถูกต้อง';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // 🟢 ใช้ LayoutBuilder เพื่อให้เช็คความสูงหน้าจอได้
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              // 🟢 เปลี่ยนเพื่อให้หน้าจอเลื่อนหลบคีย์บอร์ดได้
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28.0, vertical: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),

                        // โลโก้แอป
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 76,
                            height: 76,
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              gradient: AppGradients.primary,
                              borderRadius: BorderRadius.circular(AppRadius.xl),
                              boxShadow: AppShadows.glow(AppColors.primary),
                            ),
                            child: Image.asset(
                              'assets/logo.png',
                              color: Colors.white,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        const Text(
                          'Give & Take',
                          textAlign: TextAlign.center,
                          style: AppText.display,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'แลกเปลี่ยนสิ่งที่คุณมี กับสิ่งที่คุณต้องการ',
                          textAlign: TextAlign.center,
                          style: AppText.bodySecondary,
                        ),
                        const SizedBox(height: 44),

                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: AppText.body,
                          decoration: const InputDecoration(
                            hintText: 'Email address',
                            prefixIcon: Icon(Icons.mail_outline_rounded,
                                color: AppColors.inkSecondary, size: 21),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscureText,
                          style: AppText.body,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                color: AppColors.inkSecondary, size: 21),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.inkSecondary,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscureText = !_obscureText),
                            ),
                          ),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: const Text('Forgot password?'),
                          ),
                        ),
                        const SizedBox(height: 12),

                        PrimaryButton(
                          onPressed: _login,
                          isLoading: _isLoading,
                          child: const Text('Login'),
                        ),

                        const SizedBox(height: 28),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text('or continue with',
                                  style: AppText.caption
                                      .copyWith(color: AppColors.inkTertiary)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 28),

                        GoogleSignInButton(
                          onPressed: _isLoading ? null : _loginWithGoogle,
                          isLoading: _isGoogleLoading,
                        ),

                        const SizedBox(height: 28),

                        // ส่วนสมัครสมาชิกด้านล่างสุด
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account? ",
                                style: AppText.bodySecondary),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const RegisterScreen()));
                              },
                              child: Text('Sign up',
                                  style: AppText.label.copyWith(
                                      color: AppColors.primary, fontSize: 14)),
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
    );
  }
}
