import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

final ownerCarListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/owner/cars', queryParameters: {'page': 0, 'size': 50});
  final data = response.data['data'] as Map<String, dynamic>;
  return (data['content'] as List<dynamic>).cast<Map<String, dynamic>>();
});

class OwnerCarListScreen extends ConsumerWidget {
  const OwnerCarListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carsAsync = ref.watch(ownerCarListProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Xe của tôi')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/owner/cars/add').then((_) => ref.invalidate(ownerCarListProvider)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Đăng xe mới'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ownerCarListProvider),
        child: carsAsync.when(
          data: (cars) => cars.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car_outlined, size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text('Chưa có xe nào', style: tt.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        'Nhấn "Đăng xe mới" để thêm xe đầu tiên',
                        style: tt.bodyMedium?.copyWith(color: cs.outline),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                  itemCount: cars.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final car = cars[i];
                    final status = car['status']?.toString() ?? '';
                    final isAvailable = status == 'AVAILABLE';
                    final priceStr = car['pricePerDay']?.toString() ?? '0';
                    final priceInt = int.tryParse(priceStr.split('.').first) ?? 0;
                    final formattedPrice = priceInt >= 1000 ? '${priceInt ~/ 1000}k' : priceStr;

                    return Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        boxShadow: [AppTheme.softShadow],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Car icon
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: cs.primaryContainer.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(Icons.directions_car_rounded, color: cs.primary),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${car['brand'] ?? ''} ${car['name'] ?? ''}',
                                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    car['licensePlate']?.toString() ?? '',
                                    style: tt.bodySmall?.copyWith(color: cs.outline),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      _StatusBadge(status: status, isAvailable: isAvailable),
                                      const Spacer(),
                                      Text(
                                        '$formattedPrice đ/ngày',
                                        style: tt.labelMedium?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Actions
                            Column(
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.edit_rounded, size: 20),
                                  onPressed: () => context
                                      .push('/owner/cars/${car['id']}/edit')
                                      .then((_) => ref.invalidate(ownerCarListProvider)),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.error),
                                  onPressed: () => _confirmDelete(context, ref, car),
                                ),
                              ],
                            ),
                          ],
                        ),
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
                  onPressed: () => ref.invalidate(ownerCarListProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> car,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ẩn xe'),
        content: Text(
          'Ẩn xe "${car['brand']} ${car['name']}" khỏi danh sách? '
          'Xe sẽ không còn hiển thị cho khách thuê.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ẩn xe'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await ref.read(dioProvider).delete('/api/owner/cars/${car['id']}');
      ref.invalidate(ownerCarListProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã ẩn xe thành công')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.isAvailable});
  final String status;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = isAvailable ? Colors.green : cs.error;
    final label = switch (status) {
      'AVAILABLE' => 'Sẵn sàng',
      'PENDING' => 'Đang giữ chỗ',
      'BOOKED' => 'Đang cho thuê',
      'MAINTENANCE' => 'Bảo dưỡng',
      'DISABLED' => 'Đã ẩn',
      _ => status,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
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
