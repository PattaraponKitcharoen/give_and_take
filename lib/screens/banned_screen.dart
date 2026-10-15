import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/user_model.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// Shown instead of the app while the account is banned. The block itself
/// is enforced by Firestore rules and the Cloud Functions; this screen
/// tells the user why and until when.
class BannedScreen extends StatelessWidget {
  final UserModel user;
  const BannedScreen({super.key, required this.user});

  String _formatDate(DateTime d) {
    const months = [
      'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.',
      'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'
    ];
    final local = d.toLocal();
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '${local.day} ${months[local.month - 1]} ${local.year + 543} เวลา $time น.';
  }

  Future<void> _logout(BuildContext context) async {
    await context.read<AuthRepository>().signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final until = user.bannedUntil;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.of(AppColors.danger),
                  boxShadow: AppShadows.glow(AppColors.danger),
                ),
                child: const Icon(Icons.block_rounded,
                    color: Colors.white, size: 40),
              ),
              const SizedBox(height: 24),
              const Text('บัญชีของคุณถูกระงับ',
                  style: AppText.display, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                until == null
                    ? 'ระงับถาวร'
                    : 'ใช้งานได้อีกครั้งหลัง ${_formatDate(until)}',
                style: AppText.bodySecondary,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.raised,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เหตุผล', style: AppText.overline),
                    const SizedBox(height: 6),
                    Text(
                        user.banReason.isNotEmpty
                            ? user.banReason
                            : 'ละเมิดข้อกำหนดการใช้งาน',
                        style: AppText.body),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'ระหว่างนี้คุณจะลงของ ยื่นข้อเสนอ หรือส่งข้อความไม่ได้ ประกาศของคุณถูกซ่อนไว้และจะกลับมาเมื่อพ้นการระงับ\nหากคิดว่าเป็นความผิดพลาด กรุณาติดต่อผู้ดูแลระบบ',
                style: AppText.caption,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _logout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.ink,
                    minimumSize: const Size.fromHeight(52),
                    side: const BorderSide(color: AppColors.hairline),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                  child: const Text('ออกจากระบบ'),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
