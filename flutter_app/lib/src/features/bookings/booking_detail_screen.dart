import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';
import 'payment_webview_screen.dart';
import 'review_dialog.dart';

final bookingDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, bookingId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/bookings/$bookingId');
  final data = response.data['data'] as Map<String, dynamic>;
  return data;
});

final bookingReviewProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, bookingId) async {
  final dio = ref.read(dioProvider);
  try {
    final response = await dio.get('/api/reviews/booking/$bookingId');
    final data = response.data['data'];
    return data as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
});

class BookingDetailScreen extends ConsumerWidget {
  const BookingDetailScreen({super.key, required this.bookingId});

  final String bookingId;

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/bookings/$bookingId/cancel');
      ref.invalidate(bookingDetailProvider(bookingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã hủy chuyến đi')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể hủy chuyến đi: $e')));
      }
    }
  }

  Future<void> _pay(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post('/api/payments/vnpay/create/$bookingId');
      final paymentUrl = response.data['data']?.toString();
      if (paymentUrl == null || paymentUrl.isEmpty) {
        throw Exception('Không tạo được link thanh toán');
      }

      if (context.mounted) {
        final success = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (context) => PaymentWebviewScreen(paymentUrl: paymentUrl),
          ),
        );

        if (success == true) {
          ref.invalidate(bookingDetailProvider(bookingId));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thanh toán thành công!')),
            );
          }
        } else if (success == false) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thanh toán thất bại hoặc đã bị hủy')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tạo thanh toán VNPay: $e')),
        );
      }
    }
  }

  Future<void> _returnCar(BuildContext context, WidgetRef ref) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.put('/api/bookings/$bookingId/return');
      ref.invalidate(bookingDetailProvider(bookingId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gửi yêu cầu trả xe thành công!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không thể trả xe: $e')),
        );
      }
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'PENDING': return 'Chờ đặt cọc';
      case 'DEPOSIT_PAID': return 'Đã đặt cọc (Chờ duyệt)';
      case 'CONFIRMED': return 'Đã xác nhận';
      case 'RENTING': return 'Đang thuê';
      case 'RETURNED': return 'Đã trả xe';
      case 'COMPLETED': return 'Hoàn thành';
      case 'CANCELLED': return 'Đã hủy';
      default: return status;
    }
  }

  Color _statusColor(String status, ColorScheme cs) {
    switch (status) {
      case 'PENDING': return cs.secondary;
      case 'DEPOSIT_PAID': return Colors.orange;
      case 'CONFIRMED': return cs.primary;
      case 'RENTING': return const Color(0xFF6750A4);
      case 'RETURNED': return Colors.teal;
      case 'COMPLETED': return cs.tertiaryContainer;
      case 'CANCELLED': return cs.error;
      default: return cs.outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingAsync = ref.watch(bookingDetailProvider(bookingId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết đơn thuê')),
      body: bookingAsync.when(
        data: (booking) {
          final status = booking['status']?.toString() ?? '';
          final statusColor = _statusColor(status, cs);
          
          final priceStr = booking['totalPrice']?.toString() ?? '0';
          int? priceInt = int.tryParse(priceStr.split('.').first);
          String formattedPrice = priceStr;
          if (priceInt != null && priceInt >= 1000) {
            formattedPrice = '${priceInt ~/ 1000}k';
          }

          final depositStr = booking['depositAmount']?.toString() ?? '0';
          int? depositInt = int.tryParse(depositStr.split('.').first);
          String formattedDeposit = depositStr;
          if (depositInt != null && depositInt >= 1000) {
            formattedDeposit = '${depositInt ~/ 1000}k';
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    boxShadow: [AppTheme.ambientShadow],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.directions_car_rounded, size: 32, color: cs.primary),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${booking['carBrand']} ${booking['carName']}',
                                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 20),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.pin_rounded, size: 14, color: cs.outline),
                                    const SizedBox(width: 4),
                                    Text(
                                      booking['carLicensePlate'] ?? 'Đang cập nhật',
                                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                  ],
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
                              style: tt.labelSmall?.copyWith(color: statusColor, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Divider(color: cs.outlineVariant.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      _buildInfoRow(context, Icons.event_note_rounded, 'Thời gian', '${booking['startDate']} → ${booking['endDate']}'),
                      const SizedBox(height: 16),
                      _buildInfoRow(context, Icons.receipt_long_rounded, 'Mã hóa đơn', booking['invoiceId']?.toString() ?? 'Chưa tạo'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payment_rounded, size: 20, color: cs.onSurfaceVariant),
                              const SizedBox(width: 12),
                              Text('Tiền cọc giữ xe (30%)', style: tt.bodyMedium),
                            ],
                          ),
                          Text(
                            '$formattedDeposit vnđ',
                            style: tt.titleMedium?.copyWith(color: cs.secondary, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.payments_rounded, size: 20, color: cs.onSurfaceVariant),
                              const SizedBox(width: 12),
                              Text('Tổng tiền', style: tt.bodyMedium),
                            ],
                          ),
                          Text(
                            '$formattedPrice vnđ',
                            style: tt.titleLarge?.copyWith(color: cs.primary, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Location Details
                Text('Điểm giao nhận', style: tt.titleLarge),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    boxShadow: [AppTheme.ambientShadow],
                  ),
                  child: Column(
                    children: [
                      _buildLocationItem(context, Icons.my_location_rounded, 'Điểm đón', booking['pickupAddress'] ?? 'Chưa chọn', cs.secondaryContainer),
                      const SizedBox(height: 16),
                      Divider(color: cs.outlineVariant.withValues(alpha: 0.2)),
                      const SizedBox(height: 16),
                      _buildLocationItem(context, Icons.flag_rounded, 'Điểm trả', booking['dropoffAddress'] ?? 'Chưa chọn', cs.tertiaryContainer),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Actions
                if (status == 'PENDING' || status == 'CONFIRMED') ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final updated = await context.push<bool>('/bookings/$bookingId/pickup-dropoff');
                        if (updated == true) ref.invalidate(bookingDetailProvider(bookingId));
                      },
                      icon: const Icon(Icons.edit_location_alt_rounded),
                      label: const Text('Thay đổi điểm đón/trả'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                
                if (status == 'PENDING') ...[
                  GradientButton(
                    onPressed: () => _pay(context, ref),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.payment_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Đặt cọc giữ xe (VNPay)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _cancel(context, ref),
                      icon: const Icon(Icons.cancel_rounded),
                      label: const Text('Hủy chuyến đi'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
                      ),
                    ),
                  ),
                ],

                if (status == 'DEPOSIT_PAID') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.hourglass_empty_rounded, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Bạn đã đặt cọc thành công. Vui lòng chờ Admin phê duyệt hồ sơ lái xe của bạn.',
                            style: tt.bodyMedium?.copyWith(color: Colors.orange.shade900, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                if (status == 'CONFIRMED' || status == 'RENTING' || status == 'IN_PROGRESS') ...[
                  GradientButton(
                    onPressed: () => context.push('/cars/${booking['carId']}/tracking'),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.explore_rounded, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Định vị xe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (status == 'RENTING' || status == 'IN_PROGRESS') ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _returnCar(context, ref),
                      icon: const Icon(Icons.keyboard_return_rounded),
                      label: const Text('Trả xe'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.primary,
                        side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],

                if (status == 'COMPLETED') ...[
                  ref.watch(bookingReviewProvider(bookingId)).when(
                    data: (review) {
                      if (review == null) {
                        return GradientButton(
                          onPressed: () async {
                            final success = await showDialog<bool>(
                              context: context,
                              builder: (context) => ReviewDialog(bookingId: bookingId),
                            );
                            if (success == true) {
                              ref.invalidate(bookingReviewProvider(bookingId));
                              ref.invalidate(bookingDetailProvider(bookingId));
                            }
                          },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.rate_review_rounded, color: Colors.white),
                              SizedBox(width: 8),
                              Text('Đánh giá chuyến đi', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                            ],
                          ),
                        );
                      }
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          border: Border.all(color: cs.tertiaryContainer.withValues(alpha: 0.3)),
                          boxShadow: [AppTheme.softShadow],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.verified_rounded, color: cs.tertiaryContainer, size: 20),
                                const SizedBox(width: 8),
                                Text('Đánh giá của bạn', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: List.generate(5, (index) {
                                return Icon(
                                  index < (review['rating'] as int? ?? 0) ? Icons.star_rounded : Icons.star_border_rounded,
                                  color: Colors.orange.shade700,
                                  size: 20,
                                );
                              }),
                            ),
                            if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(review['comment'].toString(), style: tt.bodyMedium),
                            ],
                          ],
                        ),
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stack) => const SizedBox.shrink(),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Không tải được chi tiết đơn thuê: $e')),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: cs.onSurfaceVariant),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: Text(label, style: tt.bodyMedium),
        ),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600, color: cs.onSurface),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationItem(BuildContext context, IconData icon, String label, String value, Color color) {
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.bodySmall),
              const SizedBox(height: 2),
              Text(value, style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
