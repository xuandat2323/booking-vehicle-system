import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/current_user_provider.dart';
import '../../core/network/dio_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/shimmer_utils.dart';
import '../../core/widgets/app_ui.dart';
import '../notifications/notification_screen.dart';
import '../verification/verification_provider.dart';
import '../branches/branch_list_screen.dart';

final dashboardStatsProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  try {
    final bookingsRes = await dio.get('/api/bookings/my-bookings', queryParameters: {'page': 0, 'size': 1});
    final total = bookingsRes.data['data']['totalElements'] ?? 0;
    return {'totalBookings': total};
  } catch (_) {
    return {'totalBookings': 0};
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    final unreadAsync = ref.watch(unreadCountProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;

    if (isAdmin) {
      return _AdminHome(top: top);
    }

    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.pageAtmosphere),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.page,
                  top + AppSpacing.lg,
                  AppSpacing.page,
                  AppSpacing.xl,
                ),
                decoration: const BoxDecoration(gradient: AppTheme.heroGradient),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: FadeSlideIn(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GoRento',
                                  style: tt.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.6,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Thuê xe tự lái, linh hoạt mỗi ngày',
                                  style: tt.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.78),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        _HeroIconButton(
                          icon: Icons.notifications_outlined,
                          badge: unreadAsync.valueOrNull,
                          onTap: () => context.push('/notifications'),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        _HeroIconButton(
                          icon: Icons.person_outline_rounded,
                          onTap: () => context.push('/profile'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FadeSlideIn(
                      delay: const Duration(milliseconds: 80),
                      child: FilledButton.icon(
                        onPressed: () => context.push('/cars'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: cs.primary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 14,
                          ),
                        ),
                        icon: const Icon(Icons.search_rounded, size: 20),
                        label: const Text('Tìm xe ngay'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Soft curve into content — no overlapping pull-up
            SliverToBoxAdapter(
              child: Transform.translate(
                offset: const Offset(0, -1),
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.page,
                0,
                AppSpacing.page,
                AppSpacing.xxl,
              ),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 100),
                    child: statsAsync.when(
                      data: (stats) => _StatsStrip(
                        totalBookings: stats['totalBookings'] as int,
                      ),
                      loading: () => const ShimmerLoading(
                        width: double.infinity,
                        height: 88,
                        borderRadius: AppTheme.radiusCard,
                      ),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 140),
                    child: _VerificationBanner(
                      status: ref.watch(verificationStatusProvider).valueOrNull?['status']?.toString(),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 180),
                    child: SectionHeader(
                      title: 'Thao tác nhanh',
                      subtitle: 'Điểm đến thường dùng',
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 200),
                    child: const _QuickActionsList(),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 240),
                    child: SectionHeader(
                      title: 'Cơ sở GoRento',
                      actionLabel: 'Xem tất cả',
                      onAction: () => context.push('/branches'),
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 260),
                    child: const _BranchesCarousel(),
                  ),
                  const SizedBox(height: AppSpacing.section),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 300),
                    child: const SectionHeader(
                      title: 'Hoạt động',
                      subtitle: 'Theo dõi đơn thuê của bạn',
                    ),
                  ),
                  FadeSlideIn(
                    delay: const Duration(milliseconds: 320),
                    child: AppSurface(
                      onTap: () => context.push('/bookings'),
                      color: cs.surfaceContainerLowest,
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: cs.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(Icons.history_rounded, color: cs.primary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quản lý đơn thuê',
                                  style: tt.titleMedium,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Xem chi tiết chuyến đi gần đây',
                                  style: tt.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right_rounded, color: cs.outline),
                        ],
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIconButton extends StatelessWidget {
  const _HeroIconButton({
    required this.icon,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              if (badge != null && badge! > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.totalBookings});

  final int totalBookings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppSurface(
      color: cs.surfaceContainerLowest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatCell(
              value: '$totalBookings',
              label: 'Đơn thuê',
              style: tt,
              valueColor: cs.primary,
            ),
          ),
          Container(width: 1, height: 36, color: cs.outlineVariant.withValues(alpha: 0.45)),
          Expanded(
            child: _StatCell(
              value: 'Active',
              label: 'Trạng thái',
              style: tt,
              valueColor: cs.tertiary,
            ),
          ),
          Container(width: 1, height: 36, color: cs.outlineVariant.withValues(alpha: 0.45)),
          Expanded(
            child: _StatCell(
              value: 'Member',
              label: 'Hạng',
              style: tt,
              valueColor: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    required this.style,
    required this.valueColor,
  });

  final String value;
  final String label;
  final TextTheme style;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: style.titleMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: style.bodySmall),
      ],
    );
  }
}

class _QuickActionsList extends StatelessWidget {
  const _QuickActionsList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final actions = [
      (Icons.search_rounded, 'Tìm xe', 'Khám phá xe sẵn sàng', '/cars'),
      (Icons.receipt_long_rounded, 'Lịch sử', 'Đơn thuê của bạn', '/bookings'),
      (Icons.storefront_outlined, 'Cơ sở', 'Chọn điểm nhận xe', '/branches'),
      (Icons.person_outline_rounded, 'Tài khoản', 'Thông tin cá nhân', '/profile'),
    ];

    return Column(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          AppSurface(
            onTap: () => context.push(actions[i].$4),
            color: cs.surfaceContainerLowest,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md + 2,
            ),
            child: Row(
              children: [
                Icon(actions[i].$1, color: cs.primary, size: 22),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actions[i].$2,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        actions[i].$3,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 14, color: cs.outline),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    if (status == 'VERIFIED') return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isPending = status == 'PENDING';
    final title = isPending ? 'Hoàn tất xác minh danh tính' : 'Xác minh để thuê xe';
    final subtitle = isPending
        ? 'Bạn đã xác minh một phần — hoàn tất các bước còn lại'
        : 'Upload CCCD & bằng lái để có thể đặt xe';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.section),
      child: AppSurface(
        onTap: () => context.push('/verification'),
        color: cs.secondaryContainer.withValues(alpha: 0.45),
        child: Row(
          children: [
            Icon(
              isPending ? Icons.pending_rounded : Icons.verified_user_outlined,
              color: cs.secondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(color: cs.secondary),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: tt.bodySmall, maxLines: 2),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.secondary),
          ],
        ),
      ),
    );
  }
}

class _BranchesCarousel extends ConsumerWidget {
  const _BranchesCarousel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchListProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SizedBox(
      height: 148,
      child: branchAsync.when(
        data: (branches) {
          if (branches.isEmpty) {
            return Center(
              child: Text('Chưa có cơ sở nào', style: tt.bodyMedium),
            );
          }
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: branches.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
            itemBuilder: (context, index) {
              final branch = branches[index];
              final name = branch['name'] ?? '';
              final availableCount = branch['availableCarCount'] ?? 0;
              return AppSurface(
                onTap: () => context.push('/cars?branchId=${branch['branchId']}'),
                color: cs.surfaceContainerLowest,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: SizedBox(
                  width: 176,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: tt.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      Text(
                        '$availableCount xe sẵn sàng',
                        style: tt.bodySmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.md),
          itemBuilder: (_, _) => const ShimmerLoading(
            width: 176,
            height: 148,
            borderRadius: AppTheme.radiusCard,
          ),
        ),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }
}

class _AdminHome extends ConsumerWidget {
  const _AdminHome({required this.top});
  final double top;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final tiles = [
      ('Người dùng', 'Quản lý tài khoản hệ thống', Icons.people_outline_rounded, '/admin/users'),
      ('Xe', 'Thêm / sửa / xóa xe', Icons.directions_car_outlined, '/admin/cars'),
      ('Đơn đặt xe', 'Duyệt và theo dõi chuyến đi', Icons.receipt_long_outlined, '/admin/bookings'),
      ('Dashboard', 'Thống kê hệ thống', Icons.insights_outlined, '/admin'),
    ];

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppTheme.pageAtmosphere),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.page,
            top + AppSpacing.lg,
            AppSpacing.page,
            AppSpacing.xxl,
          ),
          children: [
            Text('GoRento Admin', style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: AppSpacing.sm),
            Text('Quản trị hệ thống thuê xe', style: tt.bodyMedium),
            const SizedBox(height: AppSpacing.section),
            for (final t in tiles) ...[
              AppSurface(
                onTap: () => context.go(t.$4),
                color: cs.surfaceContainerLowest,
                child: Row(
                  children: [
                    Icon(t.$3, color: cs.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.$1, style: tt.titleSmall),
                          const SizedBox(height: 4),
                          Text(t.$2, style: tt.bodySmall),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: cs.outline),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
