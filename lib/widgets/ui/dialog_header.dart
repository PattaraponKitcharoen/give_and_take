import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Shared dialog title: a raised gradient icon badge above a centred title,
/// so every dialog in the app opens with the same look.
class DialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const DialogHeader({
    super.key,
    required this.icon,
    required this.title,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.of(color),
            boxShadow: AppShadows.glow(color),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 14),
        Text(title, textAlign: TextAlign.center, style: AppText.title),
      ],
    );
  }
}
