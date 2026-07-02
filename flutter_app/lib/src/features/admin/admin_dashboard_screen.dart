import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

final adminDashboardStatsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/admin/dashboard/stats');
  return (response.data['data'] as Map<String, dynamic>);
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bảng điều khiển Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(adminDashboardStatsProvider),
            tooltip: 'Làm mới',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminDashboardStatsProvider),
        child: statsAsync.when(
          data: (stats) => _DashboardBody(stats: stats),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text('Lỗi: $e',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(color: cs.error)),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => ref.invalidate(adminDashboardStatsProvider),
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

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.stats});
  final Map<String, dynamic> stats;

  int _int(String key) {
    final v = stats[key];
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  double _double(String key) {
    final v = stats[key];
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }

  String _formatRevenue(double value) {
    if (value >= 1000000000) return '${(value / 1000000000).toStringAsFixed(1)} tỷ';
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)} tr';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final totalUsers = _int('totalUsers');
    final totalCars = _int('totalCars');
    final totalBookings = _int('totalBookings');
    final totalRevenue = _double('totalRevenue');
    final pendingBookings = _int('pendingBookings');
    final confirmedBookings = _int('confirmedBookings');
    final inProgressBookings = _int('inProgressBookings');
    final completedBookings = _int('completedBookings');
    final cancelledBookings = _int('cancelledBookings');
    final availableCars = _int('availableCars');
    final bookedCars = _int('bookedCars');
    final totalCarsForBar = availableCars + bookedCars;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        // ── Overview stat cards ──
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.55,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _StatCard(
              label: 'Người dùng',
              value: totalUsers.toString(),
              icon: Icons.people_rounded,
              color: const Color(0xFF3B6FE8),
            ),
            _StatCard(
              label: 'Tổng xe',
              value: totalCars.toString(),
              icon: Icons.directions_car_rounded,
              color: const Color(0xFF2E9E6B),
            ),
            _StatCard(
              label: 'Tổng đơn',
              value: totalBookings.toString(),
              icon: Icons.receipt_long_rounded,
              color: const Color(0xFF9C4FE8),
            ),
            _StatCard(
              label: 'Doanh thu',
              value: _formatRevenue(totalRevenue),
              icon: Icons.payments_rounded,
              color: const Color(0xFFE85C30),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Booking status breakdown ──
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            boxShadow: [AppTheme.softShadow],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trạng thái đơn đặt xe',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              _BookingStatusRow(
                label: 'Chờ duyệt',
                count: pendingBookings,
                total: totalBookings,
                color: Colors.orange,
                icon: Icons.hourglass_empty_rounded,
              ),
              const SizedBox(height: 10),
              _BookingStatusRow(
                label: 'Đã xác nhận',
                count: confirmedBookings,
                total: totalBookings,
                color: Colors.blue,
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(height: 10),
              _BookingStatusRow(
                label: 'Đang thuê',
                count: inProgressBookings,
                total: totalBookings,
                color: const Color(0xFF9C4FE8),
                icon: Icons.directions_car_rounded,
              ),
              const SizedBox(height: 10),
              _BookingStatusRow(
                label: 'Hoàn thành',
                count: completedBookings,
                total: totalBookings,
                color: Colors.green,
                icon: Icons.task_alt_rounded,
              ),
              const SizedBox(height: 10),
              _BookingStatusRow(
                label: 'Đã hủy',
                count: cancelledBookings,
                total: totalBookings,
                color: Colors.red,
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // ── Cars availability bar ──
        Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            boxShadow: [AppTheme.softShadow],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tình trạng xe',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('Sẵn sàng', style: tt.bodySmall),
                            const Spacer(),
                            Text(
                              availableCars.toString(),
                              style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('Đang thuê', style: tt.bodySmall),
                            const Spacer(),
                            Text(
                              bookedCars.toString(),
                              style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (totalCarsForBar > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Container(
                        height: 12,
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                      FractionallySizedBox(
                        widthFactor: availableCars / totalCarsForBar,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Navigation buttons ──
        Text('Quản lý hệ thống',
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _NavButton(
                label: 'Người dùng',
                icon: Icons.people_rounded,
                color: const Color(0xFF3B6FE8),
                onTap: () => context.push('/admin/users'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NavButton(
                label: 'Xe',
                icon: Icons.directions_car_rounded,
                color: const Color(0xFF2E9E6B),
                onTap: () => context.push('/admin/cars'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _NavButton(
                label: 'Đơn đặt xe',
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFF9C4FE8),
                onTap: () => context.push('/admin/bookings'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [AppTheme.softShadow],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: color,
                ),
              ),
              Text(
                label,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingStatusRow extends StatelessWidget {
  const _BookingStatusRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final fraction = total > 0 ? count / total : 0.0;

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 90,
          child: Text(label, style: tt.bodySmall),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 28,
          child: Text(
            count.toString(),
            style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w700, color: color),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: [AppTheme.softShadow],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
