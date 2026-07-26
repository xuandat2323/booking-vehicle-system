import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/auth/auth_provider.dart';
import 'core/fcm/fcm_service.dart';
import 'core/realtime/realtime_sync_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/bookings/booking_detail_screen.dart';
import 'features/bookings/booking_history_screen.dart';
import 'features/cars/car_list_screen.dart';
import 'features/invoices/invoice_list_screen.dart';
import 'features/notifications/notification_screen.dart';

class VehicleBookingApp extends ConsumerStatefulWidget {
  const VehicleBookingApp({super.key});

  @override
  ConsumerState<VehicleBookingApp> createState() => _VehicleBookingAppState();
}

class _VehicleBookingAppState extends ConsumerState<VehicleBookingApp>
    with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenForegroundMessages();
    _listenAuthForRealtimeAndFcm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        ref.read(authControllerProvider).isAuthenticated) {
      // Khi mở lại app: refresh nhanh + đảm bảo SSE còn sống.
      _softRefresh();
      ref.read(realtimeSyncServiceProvider).start();
    }
  }

  void _softRefresh() {
    ref.invalidate(bookingHistoryProvider);
    ref.invalidate(invoiceListProvider);
    ref.invalidate(carListProvider);
    ref.invalidate(notificationListProvider);
    ref.invalidate(unreadCountProvider);
    ref.invalidate(bookingDetailProvider);
  }

  void _listenForegroundMessages() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      // FCM cũng kích hoạt refresh (phòng khi SSE tạm mất).
      _softRefresh();
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

  void _listenAuthForRealtimeAndFcm() {
    ref.listenManual(authControllerProvider, (previous, next) {
      final wasAuth = previous?.isAuthenticated ?? false;
      if (next.isAuthenticated && !wasAuth) {
        ref.read(fcmServiceProvider).register();
        ref.read(realtimeSyncServiceProvider).start();
      } else if (!next.isAuthenticated && wasAuth) {
        ref.read(realtimeSyncServiceProvider).stop();
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    // Giữ SSE sống suốt phiên đăng nhập.
    ref.watch(realtimeSyncServiceProvider);
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
