import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

final bookingHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/bookings/my-bookings', queryParameters: {'page': 0, 'size': 50});
  final data = response.data['data'] as Map<String, dynamic>;
  final content = data['content'] as List<dynamic>;
  return content.cast<Map<String, dynamic>>();
});

Color _statusColor(String status, ColorScheme cs) {
  switch (status) {
    case 'PENDING':
      return cs.secondary;
    case 'DEPOSIT_PAID':
      return Colors.orange;
    case 'CONFIRMED':
      return cs.primary;
    case 'RENTING':
    case 'IN_PROGRESS':
      return const Color(0xFF6750A4);
    case 'RETURNED':
      return Colors.teal;
    case 'COMPLETED':
      return cs.tertiaryContainer;
    case 'CANCELLED':
      return cs.error;
    default:
      return cs.outline;
  }
}

String _statusLabel(String status) {
  switch (status) {
    case 'PENDING':
      return 'Chờ đặt cọc';
    case 'DEPOSIT_PAID':
      return 'Đã đặt cọc (Chờ duyệt)';
    case 'CONFIRMED':
      return 'Đã xác nhận';
    case 'RENTING':
    case 'IN_PROGRESS':
      return 'Đang thuê';
    case 'RETURNED':
      return 'Đã trả xe';
    case 'COMPLETED':
      return 'Hoàn thành';
    case 'CANCELLED':
      return 'Đã hủy';
    default:
      return status;
  }
}

class BookingHistoryScreen extends ConsumerWidget {
  const BookingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(bookingHistoryProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đơn thuê xe của bạn'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(bookingHistoryProvider),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: bookingsAsync.when(
        data: (bookings) {
          if (bookings.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.receipt_long_rounded, size: 64, color: cs.outlineVariant),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Chưa có chuyến đi nào',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Bắt đầu thuê xe để khám phá những hành trình mới.',
                      style: tt.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    GradientButton(
                      onPressed: () => context.push('/cars'),
                      width: 200,
                      child: const Text('Tìm xe ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(bookingHistoryProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final booking = bookings[index];
                final status = booking['status']?.toString() ?? '';
                final statusColor = _statusColor(status, cs);
                
                final priceStr = booking['totalPrice']?.toString() ?? '0';
                int? priceInt = int.tryParse(priceStr.split('.').first);
                String formattedPrice = priceStr;
                if (priceInt != null && priceInt >= 1000) {
                  formattedPrice = '${priceInt ~/ 1000}k';
                }

                return Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    boxShadow: [AppTheme.ambientShadow],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      onTap: () => context.push('/bookings/${booking['bookingId']}'),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Car name & Status
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(Icons.directions_car_rounded, color: statusColor, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${booking['carBrand'] ?? ''} ${booking['carName'] ?? ''}',
                                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        formattedPrice,
                                        style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                  ),
                                  child: Text(
                                    _statusLabel(status),
                                    style: tt.labelSmall?.copyWith(
                                      color: statusColor,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Divider(color: cs.outlineVariant.withValues(alpha: 0.15)),
                            const SizedBox(height: 16),
                            
                            // Details
                            Row(
                              children: [
                                Icon(Icons.event_note_rounded, size: 16, color: cs.outline),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${booking['startDate']} → ${booking['endDate']}',
                                    style: tt.bodyMedium,
                                  ),
                                ),
                              ],
                            ),
                            if (booking['pickupAddress'] != null && booking['pickupAddress'].toString().isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 2),
                                    child: Icon(Icons.location_on_rounded, size: 16, color: cs.outline),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      booking['pickupAddress'].toString(),
                                      style: tt.bodyMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: cs.error),
                const SizedBox(height: 16),
                Text('Lỗi kết nối', style: tt.titleLarge),
                const SizedBox(height: 8),
                Text('$e', textAlign: TextAlign.center, style: tt.bodyMedium),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(bookingHistoryProvider),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
