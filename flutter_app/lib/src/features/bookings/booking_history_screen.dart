import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';

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
    case 'DEPOSIT_PAID':
      return cs.onSurfaceVariant;
    case 'CONFIRMED':
    case 'RENTING':
    case 'IN_PROGRESS':
      return cs.primary;
    case 'RETURNED':
    case 'COMPLETED':
      return cs.tertiary;
    case 'CANCELLED':
      return cs.error;
    default:
      return cs.outline;
  }
}

String _loadErrorMessage(Object error) {
  if (error is DioException && error.response?.statusCode == 403) {
    return 'Tài khoản admin không xem đơn cá nhân — dùng tab Quản trị.';
  }
  return ToastUtils.mapError(error);
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
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.receipt_long_rounded, size: 64, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      'Chưa có chuyến đi nào',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Bắt đầu thuê xe để khám phá những hành trình mới.',
                      style: tt.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.lg,
              ),
              itemCount: bookings.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
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

                return FadeSlideIn(
                  delay: Duration(milliseconds: index * 50),
                  child: AppSurface(
                    onTap: () => context.push('/bookings/${booking['bookingId']}'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm + 4),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainer,
                                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                              ),
                              child: Icon(Icons.directions_car_rounded, color: cs.primary, size: 24),
                            ),
                            const SizedBox(width: AppSpacing.md),
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
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    formattedPrice,
                                    style: tt.titleSmall?.copyWith(color: cs.primary, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm + 4,
                                vertical: AppSpacing.sm - 2,
                              ),
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
                        const SizedBox(height: AppSpacing.lg),
                        Row(
                          children: [
                            Icon(Icons.event_note_rounded, size: 16, color: cs.onSurfaceVariant),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                '${booking['startDate']} → ${booking['endDate']}',
                                style: tt.bodyMedium,
                              ),
                            ),
                          ],
                        ),
                        if (booking['pickupAddress'] != null && booking['pickupAddress'].toString().isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Icon(Icons.location_on_rounded, size: 16, color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(width: AppSpacing.sm),
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
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline_rounded, size: 64, color: cs.error),
                const SizedBox(height: AppSpacing.lg),
                Text('Không tải được đơn thuê', style: tt.titleLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _loadErrorMessage(e),
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
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
