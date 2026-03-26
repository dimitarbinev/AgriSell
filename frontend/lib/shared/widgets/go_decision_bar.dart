import 'package:flutter/material.dart';
import '../../core/theme.dart';

class GoDecisionBar extends StatelessWidget {
  final VoidCallback onGo;
  final VoidCallback onCancel;
  final bool enabled;

  const GoDecisionBar({
    super.key,
    required this.onGo,
    required this.onCancel,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardSurface,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: _DecisionButton(
                label: 'CANCEL',
                icon: Icons.close_rounded,
                color: AppTheme.statusCancelled,
                onPressed: enabled
                    ? () => _showConfirmation(
                          context,
                          'Cancel Listing',
                          'Are you sure you want to cancel this listing? Buyers will be notified.',
                          onCancel,
                          isDestructive: true,
                        )
                    : null,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _DecisionButton(
                label: 'GO',
                icon: Icons.check_rounded,
                color: AppTheme.statusGoConfirmed,
                isPrimary: true,
                onPressed: enabled
                    ? () => _showConfirmation(
                          context,
                          'Confirm GO',
                          'Confirm that you will travel to sell at this location. All buyers will be notified.',
                          onGo,
                        )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmation(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm, {
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          message,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Back'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDestructive ? AppTheme.statusCancelled : AppTheme.statusGoConfirmed,
            ),
            child: Text(title),
          ),
        ],
      ),
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isPrimary;
  final VoidCallback? onPressed;

  const _DecisionButton({
    required this.label,
    required this.icon,
    required this.color,
    this.isPrimary = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? color : Colors.transparent,
          foregroundColor: isPrimary ? Colors.white : color,
          elevation: 0,
          side: isPrimary ? null : BorderSide(color: color, width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          ),
        ),
      ),
    );
  }
}
