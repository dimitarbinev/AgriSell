import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {/* TODO: mark all read */},
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _notifications.length,
        itemBuilder: (ctx, i) {
          final n = _notifications[i];
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: glassDecoration().copyWith(
              border: n.read
                  ? null
                  : Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _getNotifColor(n.type).withValues(alpha: 0.15),
                  ),
                  child: Icon(_getNotifIcon(n.type), size: 20, color: _getNotifColor(n.type)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.title, style: TextStyle(
                        fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                        color: AppTheme.textPrimary,
                      )),
                      const SizedBox(height: 4),
                      Text(n.body, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.3)),
                      const SizedBox(height: 6),
                      Text(_timeAgo(n.createdAt), style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
                    ],
                  ),
                ),
                if (!n.read)
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentGreen),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  IconData _getNotifIcon(String type) {
    switch (type) {
      case 'reservation': return Icons.receipt_long;
      case 'go': return Icons.check_circle;
      case 'cancel': return Icons.cancel;
      default: return Icons.notifications;
    }
  }

  Color _getNotifColor(String type) {
    switch (type) {
      case 'reservation': return AppTheme.statusActive;
      case 'go': return AppTheme.statusGoConfirmed;
      case 'cancel': return AppTheme.statusCancelled;
      default: return AppTheme.accentGreen;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

final _notifications = [
  AppNotification(id: '1', userId: 'u1', title: 'New Reservation', body: 'Maria Ivanova reserved 10 kg of Fresh Tomatoes for your Sofia listing.', type: 'reservation', read: false, createdAt: DateTime.now().subtract(const Duration(minutes: 15))),
  AppNotification(id: '2', userId: 'u1', title: 'GO Confirmed!', body: 'Seller Ivan Petrov confirmed GO for Fresh Tomatoes listing in Sofia. See you there!', type: 'go', read: false, createdAt: DateTime.now().subtract(const Duration(hours: 2))),
  AppNotification(id: '3', userId: 'u1', title: 'Listing Cancelled', body: 'Unfortunately, the Organic Apples listing in Ruse has been cancelled due to low demand.', type: 'cancel', read: true, createdAt: DateTime.now().subtract(const Duration(days: 1))),
  AppNotification(id: '4', userId: 'u1', title: 'New Reservation', body: 'Georgi Dimitrov reserved 25 kg for your Plovdiv listing.', type: 'reservation', read: true, createdAt: DateTime.now().subtract(const Duration(days: 2))),
];
