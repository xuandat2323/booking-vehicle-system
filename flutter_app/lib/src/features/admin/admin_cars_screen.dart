import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

final adminCarsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get(
    '/api/admin/cars',
    queryParameters: {'page': 0, 'size': 50},
  );
  final data = response.data['data'] as Map<String, dynamic>;
  return (data['content'] as List<dynamic>).cast<Map<String, dynamic>>();
});

class AdminCarsScreen extends ConsumerWidget {
  const AdminCarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carsAsync = ref.watch(adminCarsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý xe')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminCarsProvider),
        child: carsAsync.when(
          data: (cars) => cars.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions_car_outlined,
                          size: 64, color: cs.outlineVariant),
                      const SizedBox(height: 16),
                      Text('Chưa có xe nào', style: tt.titleMedium),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  itemCount: cars.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, i) {
                    final car = cars[i];
                    return _CarCard(
                      car: car,
                      onDelete: () => _confirmDelete(context, ref, car),
                    );
                  },
                ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text('Lỗi: $e',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: cs.error)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(adminCarsProvider),
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
    final carName =
        '${car['brand'] ?? ''} ${car['name'] ?? ''}'.trim();
    final carId = car['carId'];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa xe'),
        content: Text(
            'Bạn có chắc muốn xóa xe "$carName"?\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(dioProvider).delete('/api/admin/cars/$carId');
      ref.invalidate(adminCarsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã xóa xe "$carName"')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({required this.car, required this.onDelete});
  final Map<String, dynamic> car;
  final VoidCallback onDelete;

  String _formatPrice(dynamic value) {
    if (value == null) return '0';
    final n = (value is num)
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0.0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k';
    return n.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final name = car['name']?.toString() ?? '';
    final brand = car['brand']?.toString() ?? '';
    final licensePlate = car['licensePlate']?.toString() ?? '';
    final status = car['status']?.toString() ?? '';
    final pricePerDay = car['pricePerDay'];
    final location = car['location']?.toString() ?? '';
    final imageUrl = car['primaryImageUrl']?.toString();

    final (statusLabel, statusColor) = switch (status) {
      'AVAILABLE' => ('Sẵn sàng', Colors.green),
      'BOOKED' => ('Đang thuê', Colors.blue),
      'MAINTENANCE' => ('Bảo dưỡng', Colors.orange),
      'INACTIVE' => ('Không hoạt động', Colors.grey),
      _ => (status, Colors.grey),
    };

    return Dismissible(
      key: ValueKey(car['carId']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        child: Icon(Icons.delete_rounded, color: cs.error, size: 28),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: [AppTheme.softShadow],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Car image ──
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusCard),
                bottomLeft: Radius.circular(AppTheme.radiusCard),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _PlaceholderImage(cs: cs),
                    )
                  : _PlaceholderImage(cs: cs),
            ),

            // ── Car details ──
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            '$brand $name',
                            style: tt.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        _StatusBadge(
                            label: statusLabel, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.credit_card_rounded,
                            size: 12, color: cs.outline),
                        const SizedBox(width: 4),
                        Text(
                          licensePlate,
                          style: tt.bodySmall?.copyWith(
                              color: cs.outline,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 12, color: cs.outline),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              location,
                              style:
                                  tt.bodySmall?.copyWith(color: cs.outline),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_formatPrice(pricePerDay)} đ/ngày',
                          style: tt.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(Icons.delete_outline_rounded,
                              size: 20, color: cs.error),
                          onPressed: onDelete,
                          tooltip: 'Xóa xe',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      color: cs.surfaceContainerLow,
      child: Icon(Icons.directions_car_rounded,
          size: 36, color: cs.outlineVariant),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
