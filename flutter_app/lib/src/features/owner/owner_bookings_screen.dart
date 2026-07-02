import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

final ownerBookingsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/owner/bookings', queryParameters: {'page': 0, 'size': 50});
  final data = response.data['data'] as Map<String, dynamic>;
  return (data['content'] as List<dynamic>).cast<Map<String, dynamic>>();
});

class OwnerBookingsScreen extends ConsumerWidget {
  const OwnerBookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(ownerBookingsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Đơn đặt xe của tôi')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ownerBookingsProvider),
        child: bookingsAsync.when(
          data: (bookings) => bookings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined, size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text('Chưa có đơn nào', style: tt.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Đơn đặt xe sẽ xuất hiện khi khách thuê xe của bạn',
                        style: tt.bodyMedium?.copyWith(color: cs.outline),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: bookings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final b = bookings[i];
                    final status = b['status']?.toString() ?? '';
                    final isPending = status == 'PENDING';

                    return Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        boxShadow: [AppTheme.softShadow],
                        border: isPending
                            ? Border.all(color: Colors.orange.withValues(alpha: 0.4))
                            : null,
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${b['brand'] ?? ''} ${b['carName'] ?? ''}',
                                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      b['licensePlate']?.toString() ?? '',
                                      style: tt.bodySmall?.copyWith(color: cs.outline),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusChip(status: status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 14, color: cs.outline),
                              const SizedBox(width: 6),
                              Text(
                                '${b['startDate']} → ${b['endDate']}',
                                style: tt.bodyMedium,
                              ),
                              const Spacer(),
                              Text(
                                _formatCurrency(b['totalPrice']),
                                style: tt.titleSmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (isPending) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _reject(context, ref, b['bookingId']),
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    label: const Text('Từ chối'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: cs.error,
                                      side: BorderSide(color: cs.error),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () => _confirm(context, ref, b['bookingId']),
                                    icon: const Icon(Icons.check_rounded, size: 18),
                                    label: const Text('Xác nhận'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 12),
                Text('Lỗi: $e', textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(ownerBookingsProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref, dynamic bookingId) async {
    try {
      await ref.read(dioProvider).put('/api/owner/bookings/$bookingId/confirm');
      ref.invalidate(ownerBookingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã xác nhận đơn đặt xe')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, dynamic bookingId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Từ chối đơn?'),
        content: const Text('Đơn đặt xe sẽ bị hủy và xe sẽ trở về trạng thái sẵn sàng.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Không')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Từ chối'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(dioProvider).put('/api/owner/bookings/$bookingId/reject');
      ref.invalidate(ownerBookingsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã từ chối đơn đặt xe')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0 đ';
    final n = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M đ';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k đ';
    return '${n.toStringAsFixed(0)} đ';
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      'PENDING' => ('Chờ duyệt', Colors.orange),
      'CONFIRMED' => ('Đã xác nhận', Colors.green),
      'IN_PROGRESS' => ('Đang thuê', cs.primary),
      'COMPLETED' => ('Hoàn thành', Colors.teal),
      'CANCELLED' => ('Đã hủy', cs.error),
      _ => (status, cs.outline),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
