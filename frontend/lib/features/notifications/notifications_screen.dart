import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../shared/models/models.dart';
import '../../shared/providers/providers.dart';
import '../../shared/widgets/nature_scaffold.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    return NatureScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            final role = ref.read(userRoleProvider);
            if (role == 'seller') {
              context.go('/seller/dashboard');
            } else {
              context.go('/buyer/home');
            }
          },
        ),
        title: const Text('Известия', style: TextStyle(color: Colors.white)),
        actions: [
          if (user != null)
            TextButton(
              onPressed: () => _markAllRead(context, ref, user.uid),
              child: const Text('Маркирай всички', style: TextStyle(color: AppTheme.accentGreen)),
            ),
        ],
      ),
      body: user == null
          ? const Center(
              child: Text('Влезте, за да виждате известията си.', style: TextStyle(color: Colors.white70)),
            )
          : ref.watch(notificationsProvider(user.uid)).when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Text(
                        'Няма известия.\nЩе се показват тук при резервации и промени по поръчки.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), height: 1.4),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: list.length,
                    itemBuilder: (ctx, i) {
                      final n = list[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                          onTap: () => _tapNotification(context, ref, user.uid, n),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(16),
                            decoration: glassDecoration().copyWith(
                              border: n.read
                                  ? null
                                  : Border.all(
                                      color: AppTheme.primaryGreen.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: notifColor(n.type).withValues(alpha: 0.15),
                                  ),
                                  child: Icon(notifIcon(n.type), size: 20, color: notifColor(n.type)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.title,
                                        style: TextStyle(
                                          fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        n.body,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppTheme.textSecondary,
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        timeAgo(n.createdAt),
                                        style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!n.read)
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.accentGreen,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.accentGreen)),
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Грешка при зареждане: $e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.statusCancelled),
                    ),
                  ),
                ),
              ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref, String userId) async {
    final fs = ref.read(firestoreProvider);
    try {
      final snap = await fs.collection('notifications').where('userId', isEqualTo: userId).get();
      WriteBatch batch = fs.batch();
      var n = 0;
      for (final d in snap.docs) {
        final read = d.data()['read'] as bool? ?? false;
        if (read) continue;
        batch.update(d.reference, {'read': true});
        n++;
        if (n >= 450) {
          await batch.commit();
          batch = fs.batch();
          n = 0;
        }
      }
      if (n > 0) await batch.commit();
      ref.invalidate(notificationsProvider(userId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Всички известия са маркирани като прочетени.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Грешка: $e')),
        );
      }
    }
  }

  Future<void> _tapNotification(
    BuildContext context,
    WidgetRef ref,
    String userId,
    AppNotification n,
  ) async {
    if (!n.read) {
      try {
        await ref.read(firestoreProvider).collection('notifications').doc(n.id).update({'read': true});
        ref.invalidate(notificationsProvider(userId));
      } catch (_) {/* ignore */}
    }
  }
}

IconData notifIcon(String type) {
  switch (type) {
    case 'reservation':
      return Icons.receipt_long;
    case 'go':
      return Icons.check_circle;
    case 'cancel':
      return Icons.cancel;
    default:
      return Icons.notifications;
  }
}

Color notifColor(String type) {
  switch (type) {
    case 'reservation':
      return AppTheme.statusActive;
    case 'go':
      return AppTheme.statusGoConfirmed;
    case 'cancel':
      return AppTheme.statusCancelled;
    default:
      return AppTheme.accentGreen;
  }
}

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'Току-що';
  if (diff.inMinutes < 60) return 'Преди ${diff.inMinutes} мин.';
  if (diff.inHours < 24) return 'Преди ${diff.inHours} ч.';
  return 'Преди ${diff.inDays} дни';
}
