import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';
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
    final statsAsync = ref.watch(dashboardStatsProvider);
    final unreadAsync = ref.watch(unreadCountProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: CustomScrollView(
        slivers: [
          // ─── Hero App Bar ───
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: cs.primary,
            actions: [
              Stack(
                children: [
                  IconButton(
                    onPressed: () => context.push('/notifications'),
                    icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                  ),
                  if (unreadAsync.valueOrNull != null && unreadAsync.valueOrNull! > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cs.error,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${unreadAsync.valueOrNull}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              IconButton(
                onPressed: () => context.push('/profile'),
                icon: const Icon(Icons.account_circle_outlined, color: Colors.white),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.heroGradient,
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Text(
                          'Xin chào 👋',
                          style: tt.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'GoRento — Khám phá xe',
                          style: tt.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ─── Content ───
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -24), // Pull up content slightly
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats card
                    statsAsync.when(
                      data: (stats) => _StatsRow(totalBookings: stats['totalBookings'] as int),
                      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                      error: (_, _) => const SizedBox.shrink(),
                    ),
                    const SizedBox(height: 16),

                    // Verification banner (hidden when verified)
                    _VerificationBanner(
                      status: ref.watch(verificationStatusProvider).valueOrNull?['status']?.toString(),
                    ),

                    // Quick actions
                    Text(
                      'Thao tác nhanh',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    _QuickActionsGrid(),
                    const SizedBox(height: 24),

                    // Branches Section
                    const _BranchesSection(),
                    const SizedBox(height: 24),

                    // Recent bookings shortcut
                    Text(
                      'Hoạt động gần đây',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    _RecentBookingCard(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.totalBookings});

  final int totalBookings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [AppTheme.ambientShadow],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
            icon: Icons.directions_car_rounded,
            label: 'Đơn thuê',
            value: totalBookings.toString(),
            color: Theme.of(context).colorScheme.primary,
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _StatItem(
            icon: Icons.verified_user_rounded,
            label: 'Trạng thái',
            value: 'Hoạt động',
            color: Theme.of(context).colorScheme.tertiaryContainer,
          ),
          Container(
            width: 1,
            height: 40,
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.3),
          ),
          _StatItem(
            icon: Icons.star_rounded,
            label: 'Thành viên',
            value: 'Cơ bản',
            color: Theme.of(context).colorScheme.secondaryContainer,
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
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
    final tt = Theme.of(context).textTheme;
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: tt.titleMedium?.copyWith(color: color, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: tt.bodySmall),
      ],
    );
  }
}

class _QuickActionsGrid extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    
    final actions = [
      _QuickAction(
        icon: Icons.search_rounded,
        label: 'Tìm xe',
        subtitle: 'Khám phá xe',
        color: cs.primary,
        route: '/cars',
      ),
      _QuickAction(
        icon: Icons.receipt_long_rounded,
        label: 'Lịch sử',
        subtitle: 'Đơn thuê của bạn',
        color: cs.tertiaryContainer,
        route: '/bookings',
      ),
      _QuickAction(
        icon: Icons.store_rounded,
        label: 'Cơ sở',
        subtitle: 'Chọn điểm nhận xe',
        color: cs.secondary,
        route: '/branches',
      ),
      _QuickAction(
        icon: Icons.person_outline_rounded,
        label: 'Tài khoản',
        subtitle: 'Thông tin cá nhân',
        color: cs.onSurfaceVariant,
        route: '/profile',
      ),
    ];

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.4,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      itemBuilder: (context, index) {
        final action = actions[index];
        return Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push(action.route),
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: action.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(action.icon, color: action.color, size: 24),
                    ),
                    const Spacer(),
                    Text(
                      action.label,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      action.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecentBookingCard extends StatelessWidget {
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/bookings'),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.history_rounded, color: cs.primary),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Quản lý đơn thuê xe',
                          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('Xem chi tiết các chuyến đi của bạn',
                          style: tt.bodyMedium),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Verification banner ───────────────────────────────────────────────────

class _VerificationBanner extends StatelessWidget {
  const _VerificationBanner({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    if (status == 'VERIFIED') return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isPending = status == 'PENDING';
    final color = isPending ? Colors.blue : Colors.orange;
    final icon = isPending ? Icons.pending_rounded : Icons.shield_outlined;
    final title = isPending ? 'Hoàn tất xác minh danh tính' : 'Xác minh để thuê xe';
    final subtitle = isPending
        ? 'Bạn đã xác minh một phần — hoàn tất các bước còn lại'
        : 'Upload CCCD & bằng lái để có thể đặt xe';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () => context.push('/verification'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title,
                    style: tt.titleSmall?.copyWith(
                        color: color, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
          ]),
        ),
      ),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final String route;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.route,
  });
}

class _BranchesSection extends ConsumerWidget {
  const _BranchesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchListProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Cơ sở GoRento',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(
              onPressed: () => context.push('/branches'),
              child: const Text('Xem tất cả'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: branchAsync.when(
            data: (branches) {
              if (branches.isEmpty) {
                return const Center(child: Text('Chưa có cơ sở nào'));
              }
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: branches.length,
                separatorBuilder: (context, index) => const SizedBox(width: 14),
                itemBuilder: (context, index) {
                  final branch = branches[index];
                  final name = branch['name'] ?? '';
                  final availableCount = branch['availableCarCount'] ?? 0;
                  return GestureDetector(
                    onTap: () => context.push('/cars?branchId=${branch['branchId']}'),
                    child: Container(
                      width: 180,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        boxShadow: [AppTheme.softShadow],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            name,
                            style: tt.titleSmall?.copyWith(fontSize: 13, fontWeight: FontWeight.bold),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Row(
                            children: [
                              Icon(Icons.directions_car, size: 14, color: cs.primary),
                              const SizedBox(width: 4),
                              Text(
                                '$availableCount xe sẵn sàng',
                                style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
