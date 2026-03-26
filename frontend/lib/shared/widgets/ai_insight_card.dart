import 'package:flutter/material.dart';
import '../../core/theme.dart';

class AIInsightCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String? confidenceLabel;
  final double? confidenceValue;

  const AIInsightCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.confidenceLabel,
    this.confidenceValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: glassDecoration().copyWith(
        border: Border.all(
          color: AppTheme.accentGreen.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Icon(icon, size: 20, color: AppTheme.accentGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (confidenceLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor().withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
                  ),
                  child: Text(
                    confidenceLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _getConfidenceColor(),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor() {
    if (confidenceValue == null) return AppTheme.accentGreen;
    if (confidenceValue! >= 0.7) return AppTheme.statusGoConfirmed;
    if (confidenceValue! >= 0.4) return AppTheme.statusThresholdReached;
    return AppTheme.statusCancelled;
  }
}
