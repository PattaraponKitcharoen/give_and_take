import 'package:flutter/material.dart';

/// "Continue with Apple" button following Apple's Human Interface
/// Guidelines (black style): black fill, white Apple logo and label, same
/// height and shape as [GoogleSignInButton] so the two sit together.
class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;
  final String label;

  const AppleSignInButton({
    super.key,
    required this.onPressed,
    this.isLoading = false,
    this.label = 'Continue with Apple',
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.black,
          disabledBackgroundColor: Colors.black.withValues(alpha: 0.6),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: isLoading
                  ? const CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white)
                  : const Icon(Icons.apple, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.25),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
