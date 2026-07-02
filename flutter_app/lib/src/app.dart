import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_provider.dart';
import 'core/fcm/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class VehicleBookingApp extends ConsumerStatefulWidget {
  const VehicleBookingApp({super.key});

  @override
  ConsumerState<VehicleBookingApp> createState() => _VehicleBookingAppState();
}

class _VehicleBookingAppState extends ConsumerState<VehicleBookingApp> {
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _listenForegroundMessages();
    _listenAuthForFcmRegistration();
  }

  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      _scaffoldKey.currentState?.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(notification.title ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
              if ((notification.body ?? '').isNotEmpty) Text(notification.body!),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    });
  }

  void _listenAuthForFcmRegistration() {
    // Register FCM token whenever user becomes authenticated
    ref.listenManual(authControllerProvider, (previous, next) {
      if (next.isAuthenticated && !(previous?.isAuthenticated ?? false)) {
        ref.read(fcmServiceProvider).register();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'GoRento — Thuê xe tự lái',
      theme: AppTheme.theme,
      routerConfig: router,
      scaffoldMessengerKey: _scaffoldKey,
    );
  }
}
