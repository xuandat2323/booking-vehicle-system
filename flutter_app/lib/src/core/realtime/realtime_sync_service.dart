import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/admin/admin_bookings_screen.dart';
import '../../features/admin/admin_dashboard_screen.dart';
import '../../features/bookings/booking_detail_screen.dart';
import '../../features/bookings/booking_history_screen.dart';
import '../../features/cars/car_list_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/invoices/invoice_detail_screen.dart';
import '../../features/invoices/invoice_list_screen.dart';
import '../../features/notifications/notification_screen.dart';
import '../auth/auth_provider.dart';
import '../network/dio_provider.dart';
import '../storage/secure_storage_provider.dart';

/// Kết nối SSE `/api/realtime/stream` và invalidate Riverpod khi có sự kiện.
class RealtimeSyncService {
  RealtimeSyncService(this._ref);

  final Ref _ref;

  StreamSubscription<List<int>>? _subscription;
  CancelToken? _cancelToken;
  Timer? _reconnectTimer;
  bool _disposed = false;
  bool _connecting = false;
  int _backoffSeconds = 2;

  Future<void> start() async {
    _disposed = false;
    await _connect();
  }

  Future<void> stop() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cancelToken?.cancel('realtime stopped');
    _cancelToken = null;
    await _subscription?.cancel();
    _subscription = null;
    _connecting = false;
  }

  Future<void> _connect() async {
    if (_disposed || _connecting) return;
    final auth = _ref.read(authControllerProvider);
    if (!auth.isAuthenticated) return;

    _connecting = true;
    _cancelToken?.cancel('reconnect');
    await _subscription?.cancel();

    try {
      final storage = _ref.read(secureStorageProvider);
      final token = await storage.read(key: accessTokenKey);
      if (token == null || token.isEmpty) {
        _connecting = false;
        return;
      }

      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
          'Authorization': 'Bearer $token',
          if (baseUrl.contains('ngrok')) 'ngrok-skip-browser-warning': 'true',
        },
        responseType: ResponseType.stream,
        receiveTimeout: null,
        sendTimeout: const Duration(seconds: 20),
        connectTimeout: const Duration(seconds: 20),
      ));

      _cancelToken = CancelToken();
      final response = await dio.get<ResponseBody>(
        '/api/realtime/stream',
        cancelToken: _cancelToken,
      );

      final body = response.data;
      if (body == null) {
        throw StateError('SSE body null');
      }

      _backoffSeconds = 2;
      debugPrint('[Realtime] connected');

      final buffer = StringBuffer();
      _subscription = body.stream.listen(
        (chunk) {
          buffer.write(utf8.decode(chunk, allowMalformed: true));
          _drainSseBuffer(buffer);
        },
        onError: (Object e, StackTrace st) {
          debugPrint('[Realtime] stream error: $e');
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('[Realtime] stream closed');
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (e) {
      debugPrint('[Realtime] connect failed: $e');
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  void _drainSseBuffer(StringBuffer buffer) {
    final text = buffer.toString().replaceAll('\r\n', '\n');
    final parts = text.split('\n\n');
    buffer
      ..clear()
      ..write(parts.isEmpty ? '' : parts.last);

    for (var i = 0; i < parts.length - 1; i++) {
      final block = parts[i].trim();
      if (block.isEmpty) continue;
      _handleSseBlock(block);
    }
  }

  void _handleSseBlock(String block) {
    String event = 'message';
    final dataLines = <String>[];
    for (final rawLine in block.split('\n')) {
      final line = rawLine.trimRight();
      if (line.isEmpty || line.startsWith(':')) continue;
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trimLeft());
      }
    }
    if (dataLines.isEmpty) return;
    _onEvent(event, dataLines.join('\n'));
  }

  void _onEvent(String event, String data) {
    if (event == 'heartbeat' || event == 'connected') return;

    final payload = _parsePayload(data);
    if (payload == null) {
      debugPrint('[Realtime] skip unparsed event=$event data=$data');
      return;
    }

    final type = payload['type']?.toString();
    debugPrint('[Realtime] event=$event type=$type payload=$payload');

    if (type == 'BOOKING_UPDATED') {
      final bookingId = payload['bookingId']?.toString();
      final status = payload['status']?.toString();
      if (bookingId != null &&
          bookingId.isNotEmpty &&
          status != null &&
          status.isNotEmpty) {
        final current = Map<String, String>.from(
          _ref.read(bookingRealtimeStatusProvider),
        );
        current[bookingId] = status;
        _ref.read(bookingRealtimeStatusProvider.notifier).state = current;
      }
      _ref.read(bookingRealtimeRevisionProvider.notifier).state =
          _ref.read(bookingRealtimeRevisionProvider) + 1;
      _refreshBookingRelated(bookingId);
    } else if (type == 'NOTIFICATION_CREATED') {
      _ref.invalidate(notificationListProvider);
      _ref.invalidate(unreadCountProvider);
    }
  }

  Map<String, dynamic>? _parsePayload(String data) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      if (decoded is String) {
        final nested = jsonDecode(decoded);
        if (nested is Map) return Map<String, dynamic>.from(nested);
      }
    } catch (_) {}
    return null;
  }

  void _refreshBookingRelated(String? bookingId) {
    _ref.invalidate(bookingHistoryProvider);
    _ref.invalidate(invoiceListProvider);
    _ref.invalidate(carListProvider);
    _ref.invalidate(dashboardStatsProvider);
    _ref.invalidate(adminDashboardStatsProvider);
    _ref.invalidate(adminBookingsProvider);
    _ref.invalidate(notificationListProvider);
    _ref.invalidate(unreadCountProvider);
    _ref.invalidate(invoiceDetailProvider);
    // Family + instance cụ thể để màn chi tiết chắc chắn refetch.
    _ref.invalidate(bookingDetailProvider);
    if (bookingId != null && bookingId.isNotEmpty) {
      _ref.invalidate(bookingDetailProvider(bookingId));
    }
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _subscription = null;
    _reconnectTimer?.cancel();
    final wait = _backoffSeconds;
    _backoffSeconds = (_backoffSeconds * 2).clamp(2, 30);
    _reconnectTimer = Timer(Duration(seconds: wait), () {
      if (!_disposed) {
        _connect();
      }
    });
  }
}

final realtimeSyncServiceProvider = Provider<RealtimeSyncService>((ref) {
  final service = RealtimeSyncService(ref);
  ref.onDispose(() {
    unawaited(service.stop());
  });
  return service;
});
