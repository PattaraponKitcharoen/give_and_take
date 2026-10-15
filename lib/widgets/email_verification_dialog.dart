import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repositories/auth_repository.dart';
import '../theme/app_theme.dart';
import 'ui/dialog_header.dart';

/// The "you must verify your email before doing X" dialog, shown before
/// gated actions (posting a listing, submitting an offer). Previously
/// duplicated verbatim in `add_post_screen.dart` and `item_detail_screen.dart`
/// — including the same async/`mounted`-guard bug, fixed in only one of the
/// two copies until this extraction. [message] is the action-specific body
/// text; [themeColor] matches the calling screen's accent color.
void showEmailVerificationDialog(
  BuildContext context, {
  required String message,
  required Color themeColor,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: DialogHeader(
            icon: Icons.mark_email_unread_outlined,
            title: 'ยืนยันอีเมลของคุณ',
            color: themeColor),
        content: Text(message, textAlign: TextAlign.center),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('ปิด',
                style: TextStyle(color: AppColors.inkSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<AuthRepository>().sendEmailVerification();
                // `context` is the caller's own context (the screen behind
                // the dialog), not `dialogContext` — guard each on its own
                // `mounted` instead of using dialogContext.mounted as a
                // stand-in for both.
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('ส่งอีเมลยืนยันใหม่อีกครั้งแล้ว'),
                      backgroundColor: themeColor,
                      behavior: SnackBarBehavior.floating));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: AppColors.danger,
                      behavior: SnackBarBehavior.floating));
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: themeColor, minimumSize: const Size(0, 44)),
            child: const Text('ส่งอีเมลอีกครั้ง'),
          ),
        ],
      );
    },
  );
}
