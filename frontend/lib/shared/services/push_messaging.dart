import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../../firebase_options.dart';

bool _tokenRefreshSubscribed = false;

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

/// Registers for push, saves FCM token on `users/{uid}` for backend campaigns.
Future<void> syncPushTokenToProfile() async {
  try {
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    final settings = await messaging.getNotificationSettings();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await messaging.getToken();
    await _persistFcmToken(token);

    if (!_tokenRefreshSubscribed) {
      _tokenRefreshSubscribed = true;
      FirebaseMessaging.instance.onTokenRefresh.listen(_persistFcmToken);
    }
  } catch (e, st) {
    debugPrint('FCM sync skipped: $e\n$st');
  }
}

Future<void> _persistFcmToken(String? token) async {
  if (token == null || token.isEmpty) return;
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
    {
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    },
    SetOptions(merge: true),
  );
}
