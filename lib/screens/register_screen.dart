import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/auth/auth_cubit.dart';
import '../cubits/auth/auth_state.dart';
import '../repositories/auth_repository.dart';
import '../repositories/user_repository.dart';
import '../models/user_model.dart';
import '../widgets/google_sign_in_button.dart';
import 'main_layout.dart';
import 'package:flutter/gestures.dart';
import '../constants/app_terms.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/primary_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final Color tealColor = AppColors.primary;
  final Color bgColor = AppColors.background;

  bool _obscureText = true;
  bool _obscureConfirmText = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;
  bool _isGoogleLoading = false;

  // 🟢 1. ตัวแปรเก็บสถานะว่าอ่านจบหรือยัง
  bool _hasReadTerms = false;
  bool _hasReadPrivacy = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final ScrollController _termsScrollController = ScrollController();
  final ScrollController _privacyScrollController = ScrollController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _termsScrollController.dispose();
    _privacyScrollController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (name.isEmpty ||
        email.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('กรุณากรอกข้อมูลให้ครบทุกช่อง')));
      return;
    }

    if (password != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('รหัสผ่านและการยืนยันรหัสผ่านไม่ตรงกัน')));
      return;
    }

    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณายอมรับเงื่อนไขและข้อตกลงการใช้งาน')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRepo = context.read<AuthRepository>();
      final userRepo = context.read<UserRepository>();

      final userCredential = await authRepo.createUserWithEmailAndPassword(
          email: email, password: password);

      if (userCredential.user != null) {
        final userModel = UserModel(
          uid: userCredential.user!.uid,
          email: email,
          name: name,
          bio: '',
          tel: '',
          role: 'user',
          status: 'active',
          profileImgUrl: '',
          coinsBalance: 1000,
          isEmailVerified: false,
          isPhoneVerified: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          faculty: '',
          academicYear: '',
          isStudent: false,
        );
        await userRepo.createUser(userModel);
      }

      if (mounted) {
        Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const MainLayout()),
            (route) => false);
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
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🟢 อัปเดตฟังก์ชัน Dialog บังคับอ่านให้จบ ปุ่มปิดถึงจะเปิดใช้งาน
  void _showTermsDialog(String title, String content, bool isTerms) {
    ScrollController scrollController =
        isTerms ? _termsScrollController : _privacyScrollController;

    showDialog(
      context: context,
      barrierDismissible:
          false, // 🟢 1. บังคับห้ามกดพื้นที่ว่างรอบๆ เพื่อปิด ป้องกันการลักไก่ข้ามขั้นตอน
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // ตรวจจับการเลื่อนหน้าจอ
            scrollController.addListener(() {
              if (scrollController.position.pixels >=
                  scrollController.position.maxScrollExtent - 10) {
                if (isTerms && !_hasReadTerms) {
                  setState(() => _hasReadTerms = true);
                  setDialogState(() {}); // อัปเดต UI ภายใน Dialog ทันที
                } else if (!isTerms && !_hasReadPrivacy) {
                  setState(() => _hasReadPrivacy = true);
                  setDialogState(() {}); // อัปเดต UI ภายใน Dialog ทันที
                }
              }
            });

            // ตรวจสอบกรณีที่หน้าจอใหญ่หรือข้อความสั้นจนไม่ต้องเลื่อน
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (scrollController.hasClients &&
                  scrollController.position.maxScrollExtent <= 0) {
                if (isTerms && !_hasReadTerms) {
                  setState(() => _hasReadTerms = true);
                  setDialogState(() {});
                } else if (!isTerms && !_hasReadPrivacy) {
                  setState(() => _hasReadPrivacy = true);
                  setDialogState(() {});
                }
              }
            });

            bool currentReadStatus = isTerms ? _hasReadTerms : _hasReadPrivacy;

            return AlertDialog(
              title: Text(title, style: AppText.title),
              content: SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: scrollController,
                        child: Text(content,
                            style: AppText.body.copyWith(fontSize: 14)),
                      ),
                    ),
                    if (!currentReadStatus)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.warning, size: 16),
                            const SizedBox(width: 4),
                            Text('เลื่อนลงเพื่ออ่านให้จบก่อนปิด',
                                style: AppText.caption.copyWith(
                                    color: AppColors.warning,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppColors.success, size: 16),
                            const SizedBox(width: 4),
                            Text('อ่านจบเรียบร้อย ปลดล็อคปุ่มปิดแล้ว',
                                style: AppText.caption.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  // 🟢 2. เช็กสถานะการอ่าน ถ้าอ่านจบ (true) ให้กดปิดได้ ถ้ายังไม่จบส่งค่า null ปุ่มจะเทาจางทันที
                  onPressed:
                      currentReadStatus ? () => Navigator.pop(context) : null,
                  style: TextButton.styleFrom(
                    foregroundColor: tealColor,
                    disabledForegroundColor: AppColors
                        .inkTertiary, // 🟢 3. บังคับสีเทาจางตอนที่ยังกดไม่ได้
                  ),
                  child: const Text('ปิด'),
                ),
              ],
            );
          },
        );
      },
    );
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
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(label, style: AppText.overline),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword ? (obscureState ?? true) : false,
          keyboardType:
              isPassword ? TextInputType.text : TextInputType.emailAddress,
          style: AppText.body,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: AppColors.inkSecondary, size: 20),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                        obscureState!
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppColors.inkSecondary,
                        size: 20),
                    onPressed: onToggleObscure)
                : null,
          ),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  // Same terms gate as email sign-up: a first Google sign-in creates the
  // account, so the user has to accept the terms first.
  Future<void> _signUpWithGoogle() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณายอมรับเงื่อนไขและข้อตกลงการใช้งาน')));
      return;
    }
    setState(() => _isGoogleLoading = true);
    await context.read<AuthCubit>().signInWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);
    final state = context.read<AuthCubit>().state;
    if (state is AuthError) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(state.message)));
    }
    if (context.read<AuthRepository>().currentUser != null) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainLayout()),
          (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              Center(
                child: Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                    boxShadow: AppShadows.glow(AppColors.primary),
                  ),
                  child: Image.asset('assets/logo.png',
                      color: Colors.white, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Create an Account',
                textAlign: TextAlign.center,
                style: AppText.display,
              ),
              const SizedBox(height: 6),
              const Text(
                'Join the marketplace. Trade what you have.',
                textAlign: TextAlign.center,
                style: AppText.bodySecondary,
              ),
              const SizedBox(height: 28),

              _buildLabeledTextField(
                  label: 'FULL NAME',
                  controller: _nameController,
                  hintText: 'John Doe',
                  icon: Icons.person_outline),
              _buildLabeledTextField(
                  label: 'EMAIL ADDRESS',
                  controller: _emailController,
                  hintText: 'email@example.com',
                  icon: Icons.mail_outline),
              _buildLabeledTextField(
                  label: 'PASSWORD',
                  controller: _passwordController,
                  hintText: '••••••••',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureState: _obscureText,
                  onToggleObscure: () =>
                      setState(() => _obscureText = !_obscureText)),
              _buildLabeledTextField(
                  label: 'CONFIRM PASSWORD',
                  controller: _confirmPasswordController,
                  hintText: '••••••••',
                  icon: Icons.lock_outline,
                  isPassword: true,
                  obscureState: _obscureConfirmText,
                  onToggleObscure: () => setState(
                      () => _obscureConfirmText = !_obscureConfirmText)),

              // Checkbox
              Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                        value: _agreeToTerms,
                        activeColor: tealColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4)),
                        // 🟢 3. ดักจับการกดติ๊กถูก
                        onChanged: (value) {
                          if (!_hasReadTerms || !_hasReadPrivacy) {
                            // ถ้ายังอ่านไม่ครบ โชว์ SnackBar แจ้งเตือนและเด้งออก
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'กรุณากดเข้าไปอ่าน Terms of Service และ Privacy Policy ให้จบก่อนกดยอมรับ'),
                                backgroundColor: AppColors.warning,
                              ),
                            );
                            return;
                          }
                          setState(() => _agreeToTerms = value ?? false);
                        }),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: 'I agree to the ',
                        style: AppText.caption.copyWith(fontSize: 13),
                        children: [
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: _hasReadTerms
                                  ? AppColors.primary
                                  : AppColors.warning, // เปลี่ยนสีถ้าอ่านแล้ว
                              fontWeight: FontWeight.w600,
                              decoration: _hasReadTerms
                                  ? null
                                  : TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showTermsDialog(
                                  'Terms of Service',
                                  AppTerms.termsOfService,
                                  true // ส่ง true บอกว่าเป็นไฟล์ Terms
                                  ),
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: _hasReadPrivacy
                                  ? AppColors.primary
                                  : AppColors.warning, // เปลี่ยนสีถ้าอ่านแล้ว
                              fontWeight: FontWeight.w600,
                              decoration: _hasReadPrivacy
                                  ? null
                                  : TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () => _showTermsDialog(
                                  'Privacy Policy',
                                  AppTerms.privacyPolicy,
                                  false // ส่ง false บอกว่าเป็นไฟล์ Privacy
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ปุ่ม Sign Up
              PrimaryButton(
                onPressed: _register,
                isLoading: _isLoading,
                child: const Text('Sign Up'),
              ),
              const SizedBox(height: 24),

              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Text('OR CONTINUE WITH',
                          style: AppText.caption
                              .copyWith(color: AppColors.inkTertiary))),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 24),

              GoogleSignInButton(
                onPressed: _isLoading ? null : _signUpWithGoogle,
                isLoading: _isGoogleLoading,
                label: 'Sign up with Google',
              ),
              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ',
                      style: AppText.bodySecondary),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text('Log In',
                        style: AppText.label
                            .copyWith(color: AppColors.primary, fontSize: 14)),
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
