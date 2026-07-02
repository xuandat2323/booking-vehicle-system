import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';

/// Background message handler — must be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  // Firebase is already initialized by main.dart before this is called.
  debugPrint('[FCM background] ${message.notification?.title}: ${message.notification?.body}');
}

class FcmService {
  FcmService(this._ref);

  final Ref _ref;

  /// Call once after successful login to request permission + register token.
  Future<void> register() async {
    try {
      final messaging = FirebaseMessaging.instance;

      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await messaging.getToken();
      if (token == null) return;

      await _sendTokenToServer(token);

      // Re-register when token rotates
      messaging.onTokenRefresh.listen(_sendTokenToServer);
    } catch (e) {
      debugPrint('[FCM] register failed: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      final dio = _ref.read(dioProvider);
      await dio.put('/api/user/fcm-token', data: {'token': token});
      debugPrint('[FCM] token registered');
    } catch (e) {
      debugPrint('[FCM] token upload failed: $e');
    }
  }
}

final fcmServiceProvider = Provider<FcmService>((ref) => FcmService(ref));
