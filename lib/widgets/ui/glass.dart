import 'dart:ui';
import 'package:flutter/material.dart';

/// Frosted-glass surface in the style of iOS "Liquid Glass": blurs whatever
/// scrolls underneath, tints it white, and draws a bright top-edge rim so
/// the panel reads as a raised piece of glass.
///
/// Only use it on things that float over content (nav bar, overlays on
/// photos) — on a plain background there is nothing to blur and it just
/// looks grey.
class Glass extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final double blur;

  /// 0..1 — how milky the glass is. Lower shows more of what's behind.
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;
  final Color tint;

  const Glass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(999)),
    this.blur = 20,
    this.opacity = 0.72,
    this.padding,
    this.shadows,
    this.tint = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: borderRadius, boxShadow: shadows),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  tint.withOpacity((opacity + 0.12).clamp(0, 1)),
                  tint.withOpacity(opacity),
                ],
              ),
              border: Border.all(
                  color: Colors.white.withOpacity(0.55), width: 0.8),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
