import 'package:flutter/material.dart';
import 'package:shopxy_customer/shared/theme/app_colors.dart';

/// Static 5-star row rendered from a 0..5 double. Renders half-stars
/// when the fraction is between 0.25 and 0.75. Reused everywhere we
/// show a review (review cards, summary, sheet preview).
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.rating,
    this.size = 14,
    this.color = AppColors.success,
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final delta = rating - i;
        IconData icon;
        if (delta >= 0.75) {
          icon = Icons.star_rounded;
        } else if (delta >= 0.25) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_outline_rounded;
        }
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}
