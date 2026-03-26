import 'package:flutter/material.dart';
import '../../core/theme.dart';

class RatingStars extends StatelessWidget {
  final double rating;
  final double size;
  final bool interactive;
  final ValueChanged<double>? onRatingChanged;
  final Color? color;

  const RatingStars({
    super.key,
    required this.rating,
    this.size = 18,
    this.interactive = false,
    this.onRatingChanged,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final starColor = color ?? AppTheme.statusThresholdReached;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        IconData icon;
        if (rating >= starIndex) {
          icon = Icons.star_rounded;
        } else if (rating >= starIndex - 0.5) {
          icon = Icons.star_half_rounded;
        } else {
          icon = Icons.star_border_rounded;
        }

        final star = Icon(
          icon,
          size: size,
          color: rating >= starIndex - 0.5 ? starColor : AppTheme.textTertiary,
        );

        if (interactive) {
          return GestureDetector(
            onTap: () => onRatingChanged?.call(starIndex.toDouble()),
            child: star,
          );
        }
        return star;
      }),
    );
  }
}
