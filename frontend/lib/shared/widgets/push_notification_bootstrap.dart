import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/providers.dart';
import '../services/push_messaging.dart';

/// Requests notification permission and stores FCM token after login.
class PushNotificationBootstrap extends ConsumerStatefulWidget {
  const PushNotificationBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushNotificationBootstrap> createState() =>
      _PushNotificationBootstrapState();
}

class _PushNotificationBootstrapState extends ConsumerState<PushNotificationBootstrap> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = ref.read(authStateProvider).value;
      if (user != null) syncPushTokenToProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (previous, next) {
      next.whenData((user) {
        if (user != null) syncPushTokenToProfile();
      });
    });

    return widget.child;
  }
}
