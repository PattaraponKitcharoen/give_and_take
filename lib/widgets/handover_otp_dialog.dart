import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HandoverOtpDialog extends StatelessWidget {
  final Function(String) onSubmit;
  const HandoverOtpDialog({super.key, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final TextEditingController otpController = TextEditingController();
    return AlertDialog(
      title: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppGradients.primary,
              boxShadow: AppShadows.glow(AppColors.primary),
            ),
            child: const Icon(Icons.lock_open_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(height: 14),
          const Text('ยืนยันการรับของ', style: AppText.title),
        ],
      ),
      content: TextField(
        controller: otpController,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 8,
            color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'กรอกรหัส 6 หลักของอีกฝ่าย',
          hintStyle: AppText.bodySecondary
              .copyWith(color: AppColors.inkTertiary, letterSpacing: 0),
          fillColor: AppColors.surfaceMuted,
          counterText: '',
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ยกเลิก')),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    onSubmit(otpController.text.trim());
                  },
                  style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                  child: const Text('ยืนยัน')),
            ),
          ],
        ),
      ],
    );
  }
}
