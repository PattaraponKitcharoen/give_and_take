import 'package:flutter/material.dart';

/// Five stars filled to the exact [rating] — 4.7 shows four full stars and
/// the fifth filled 70%, instead of rounding down to four.
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;

  const StarRating({
    super.key,
    required this.rating,
    this.size = 14,
    this.color = Colors.orange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final fill = (rating - index).clamp(0.0, 1.0);
        return Stack(
          children: [
            Icon(Icons.star_border, color: color, size: size),
            ClipRect(
              clipper: _FractionClipper(fill),
              child: Icon(Icons.star, color: color, size: size),
            ),
          ],
        );
      }),
    );
  }
}

class _FractionClipper extends CustomClipper<Rect> {
  final double fraction;

  _FractionClipper(this.fraction);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * fraction, size.height);

  @override
  bool shouldReclip(_FractionClipper oldClipper) =>
      oldClipper.fraction != fraction;
}
