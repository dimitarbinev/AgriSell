import 'package:flutter/material.dart';
import '../../core/theme.dart';

class QuantityProgressBar extends StatelessWidget {
  final double current;
  final double target;
  final String? label;
  final double height;

  const QuantityProgressBar({
    super.key,
    required this.current,
    required this.target,
    this.label,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    final reached = current >= target;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null || true)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label ?? '${current.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} kg',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: reached ? AppTheme.accentGreen : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(height / 2),
            color: AppTheme.cardSurfaceLight,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    width: constraints.maxWidth * progress,
                    height: height,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height / 2),
                      gradient: reached
                          ? const LinearGradient(
                              colors: [AppTheme.accentGreen, Color(0xFF81C784)],
                            )
                          : AppTheme.progressGradient,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
