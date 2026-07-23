import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_ui.dart';

final invoiceListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/invoices/my-invoices', queryParameters: {'page': 0, 'size': 50});
  final data = response.data['data'] as Map<String, dynamic>;
  final content = data['content'] as List<dynamic>;
  return content.cast<Map<String, dynamic>>();
});

Color _invoiceStatusColor(String status, ColorScheme cs) {
  switch (status) {
    case 'PAID':
      return cs.tertiary;
    case 'UNPAID':
      return cs.secondary;
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

String _invoiceStatusLabel(String status) {
  switch (status) {
    case 'PAID':
      return 'Đã thanh toán';
    case 'UNPAID':
      return 'Chưa thanh toán';
    case 'CANCELLED':
      return 'Đã hủy';
    default:
      return status;
  }
}

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoiceListProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hoá đơn của tôi'),
        actions: [
          IconButton(
            onPressed: () => ref.invalidate(invoiceListProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: invoicesAsync.when(
        data: (invoices) {
          if (invoices.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.receipt_outlined, size: 64, color: cs.outlineVariant),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Chưa có hoá đơn nào', style: tt.titleMedium),
                  ],
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(invoiceListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: invoices.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, index) {
                final invoice = invoices[index];
                final status = invoice['invoiceStatus']?.toString() ?? '';
                final statusColor = _invoiceStatusColor(status, cs);
                return FadeSlideIn(
                  delay: Duration(milliseconds: 40 * index),
                  child: AppSurface(
                    onTap: () => context.push('/invoices/${invoice['invoiceId']}'),
                    color: cs.surfaceContainerLowest,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.receipt_long_rounded, color: statusColor, size: 22),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    invoice['invoiceNumber']?.toString() ?? '',
                                    style: tt.titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    invoice['carName']?.toString() ?? '',
                                    style: tt.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _invoiceStatusLabel(status),
                              style: tt.labelSmall?.copyWith(
                                color: statusColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 14, color: cs.outline),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${invoice['startDate']} → ${invoice['endDate']}',
                                style: tt.bodySmall,
                              ),
                            ),
                            Text(
                              '${invoice['totalAmount'] ?? ''} ₫',
                              style: tt.titleSmall?.copyWith(color: cs.primary),
                            ),
                          ],
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
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: AppSpacing.lg),
                Text('Không tải được hoá đơn', style: tt.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _loadErrorMessage(e),
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => ref.invalidate(invoiceListProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
