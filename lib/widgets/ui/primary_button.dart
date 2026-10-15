import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Main call-to-action button: gradient fill with a gloss highlight and a
/// soft coloured glow, so it looks gently raised. Disabled (onPressed null)
/// it goes flat grey like the theme's ElevatedButton.
class PrimaryButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final bool isLoading;
  final Color color;
  final double height;

  const PrimaryButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.icon,
    this.isLoading = false,
    this.color = AppColors.primary,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final radius = BorderRadius.circular(AppRadius.md);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: enabled || isLoading ? AppGradients.of(color) : null,
        color: enabled || isLoading ? null : AppColors.hairline,
        boxShadow: enabled ? AppShadows.glow(color) : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onPressed : null,
          child: Stack(
            children: [
              if (enabled || isLoading)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                        borderRadius: radius, gradient: AppGradients.gloss),
                  ),
                ),
              Center(
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : DefaultTextStyle.merge(
                        style: AppText.subtitle.copyWith(
                            color: enabled
                                ? Colors.white
                                : AppColors.inkTertiary),
                        child: IconTheme.merge(
                          data: IconThemeData(
                              color: enabled
                                  ? Colors.white
                                  : AppColors.inkTertiary,
                              size: 19),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (icon != null) ...[
                                Icon(icon),
                                const SizedBox(width: 8),
                              ],
                              child,
                            ],
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
