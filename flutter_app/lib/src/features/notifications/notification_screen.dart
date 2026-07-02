import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';

final notificationListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/notifications', queryParameters: {'page': 0, 'size': 30});
  final data = response.data['data'] as Map<String, dynamic>;
  final content = data['content'] as List<dynamic>;
  return content.cast<Map<String, dynamic>>();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/notifications/unread-count');
  return (response.data['data'] as num).toInt();
});

IconData _notifIcon(String? type) {
  switch (type) {
    case 'BOOKING_CREATED':
      return Icons.directions_car;
    case 'BOOKING_CONFIRMED':
      return Icons.check_circle;
    case 'BOOKING_CANCELLED':
      return Icons.cancel;
    case 'BOOKING_COMPLETED':
      return Icons.flag;
    case 'PAYMENT_SUCCESS':
      return Icons.payment;
    case 'PAYMENT_FAILED':
      return Icons.money_off;
    default:
      return Icons.notifications;
  }
}

Color _notifColor(String? type) {
  switch (type) {
    case 'BOOKING_CREATED':
      return Colors.blue;
    case 'BOOKING_CONFIRMED':
      return Colors.green;
    case 'BOOKING_CANCELLED':
      return Colors.red;
    case 'BOOKING_COMPLETED':
      return Colors.teal;
    case 'PAYMENT_SUCCESS':
      return Colors.green;
    case 'PAYMENT_FAILED':
      return Colors.red;
    default:
      return Colors.grey;
  }
}

class NotificationScreen extends ConsumerWidget {
  const NotificationScreen({super.key});

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/notifications/read-all');
      ref.invalidate(notificationListProvider);
      ref.invalidate(unreadCountProvider);
    } catch (_) {}
  }

  Future<void> _markRead(WidgetRef ref, int id) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/notifications/$id/read');
      ref.invalidate(notificationListProvider);
      ref.invalidate(unreadCountProvider);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thông báo'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(context, ref),
            child: const Text('Đọc tất cả'),
          ),
        ],
      ),
      body: notifAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Chưa có thông báo nào', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(notificationListProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notif = notifications[index];
                final isRead = notif['isRead'] == true;
                final type = notif['type']?.toString();
                final color = _notifColor(type);
                final referenceId = notif['referenceId'];

                return InkWell(
                  onTap: () {
                    _markRead(ref, notif['id'] as int);
                    if (referenceId != null && (type?.startsWith('BOOKING') ?? false)) {
                      context.push('/bookings/$referenceId');
                    }
                  },
                  child: Container(
                    color: isRead ? null : color.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_notifIcon(type), color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      notif['title']?.toString() ?? '',
                                      style: TextStyle(
                                        fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  if (!isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif['message']?.toString() ?? '',
                                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                notif['createdAt']?.toString().split('T').first ?? '',
                                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Không tải được thông báo: $e')),
      ),
    );
  }
}
