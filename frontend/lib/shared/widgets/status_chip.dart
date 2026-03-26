import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/constants.dart';

class StatusChip extends StatelessWidget {
  final String status;
  final bool small;

  const StatusChip({super.key, required this.status, this.small = false});

  @override
  Widget build(BuildContext context) {
    final config = _getConfig(status);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 12,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusXLarge),
        border: Border.all(color: config.color.withValues(alpha: 0.4), width: 1),
      ),
      child: Text(
        config.label,
        style: TextStyle(
          fontSize: small ? 10 : 12,
          fontWeight: FontWeight.w600,
          color: config.color,
        ),
      ),
    );
  }

  _StatusConfig _getConfig(String status) {
    switch (status) {
      case AppConstants.statusDraft:
        return _StatusConfig('Draft', AppTheme.statusDraft);
      case AppConstants.statusActive:
        return _StatusConfig('Active', AppTheme.statusActive);
      case AppConstants.statusThresholdReached:
        return _StatusConfig('Threshold Reached', AppTheme.statusThresholdReached);
      case AppConstants.statusGoConfirmed:
      case 'confirmed':
        return _StatusConfig('GO Confirmed', AppTheme.statusGoConfirmed);
      case AppConstants.statusCancelled:
        return _StatusConfig('Cancelled', AppTheme.statusCancelled);
      case AppConstants.statusCompleted:
        return _StatusConfig('Completed', AppTheme.statusCompleted);
      default:
        return _StatusConfig(status, AppTheme.statusDraft);
    }
  }
}

class _StatusConfig {
  final String label;
  final Color color;
  _StatusConfig(this.label, this.color);
}
