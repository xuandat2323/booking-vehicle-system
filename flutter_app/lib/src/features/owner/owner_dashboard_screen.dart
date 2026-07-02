import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

final ownerDashboardProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/owner/dashboard');
  return response.data['data'] as Map<String, dynamic>;
});

class OwnerDashboardScreen extends ConsumerWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(ownerDashboardProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(ownerDashboardProvider),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 170,
              pinned: true,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                  padding: const EdgeInsets.fromLTRB(24, 88, 24, 24),
                  child: dashAsync.maybeWhen(
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Xin chào, ${data['ownerName'] ?? 'Chủ xe'}!',
                          style: tt.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Bảng điều khiển kênh cho thuê xe',
                          style: tt.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                    orElse: () => const SizedBox(),
                  ),
                ),
              ),
              title: const Text('Kênh cho thuê'),
            ),

            dashAsync.when(
              data: (data) => SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Stats row
                    Row(
                      children: [
                        _StatCard(
                          icon: Icons.directions_car_rounded,
                          label: 'Xe của tôi',
                          value: '${data['totalCars'] ?? 0}',
                          color: cs.primary,
                        ),
                        const SizedBox(width: 12),
                        _StatCard(
                          icon: Icons.receipt_long_rounded,
                          label: 'Tổng đơn',
                          value: '${data['totalBookings'] ?? 0}',
                          color: cs.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Revenue card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: AppTheme.heroGradient,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tổng doanh thu',
                            style: tt.labelLarge?.copyWith(color: Colors.white70),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatCurrency(data['totalEarnings']),
                            style: tt.headlineMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'từ các chuyến hoàn thành',
                            style: tt.bodySmall?.copyWith(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Quick actions
                    Text(
                      'Quản lý',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    _ActionTile(
                      icon: Icons.add_circle_rounded,
                      title: 'Đăng xe mới',
                      subtitle: 'Thêm xe lên GoRento để kiếm thêm thu nhập',
                      onTap: () => context.push('/owner/cars/add'),
                      accent: true,
                    ),
                    const SizedBox(height: 12),
                    _ActionTile(
                      icon: Icons.directions_car_rounded,
                      title: 'Xe của tôi',
                      subtitle: 'Xem và quản lý danh sách xe đang cho thuê',
                      onTap: () => context.push('/owner/cars'),
                    ),
                    const SizedBox(height: 12),
                    _ActionTile(
                      icon: Icons.receipt_long_rounded,
                      title: 'Đơn đặt xe',
                      subtitle: 'Duyệt và theo dõi các đơn thuê xe của bạn',
                      onTap: () => context.push('/owner/bookings'),
                    ),
                  ]),
                ),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48),
                      const SizedBox(height: 12),
                      Text('Không tải được dữ liệu', textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => ref.invalidate(ownerDashboardProvider),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '0 đ';
    final n = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0.0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M đ';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k đ';
    return '${n.toStringAsFixed(0)} đ';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: [AppTheme.softShadow],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: tt.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(label, style: tt.labelSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final iconColor = accent ? cs.primary : cs.secondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accent
              ? cs.primaryContainer.withValues(alpha: 0.15)
              : cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: [AppTheme.softShadow],
          border: accent
              ? Border.all(color: cs.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.outline),
          ],
        ),
      ),
    );
  }
}
