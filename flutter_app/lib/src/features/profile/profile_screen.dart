import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/network/dio_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_ui.dart';
import '../verification/verification_provider.dart';

final userProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/user/me');
  final data = response.data['data'] as Map<String, dynamic>;
  return data;
});

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final verifyStatus = ref.watch(verificationStatusProvider).valueOrNull?['status']?.toString();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: profileAsync.when(
        data: (user) {
          final name = user['name'] ?? 'Chưa cập nhật';
          final email = user['email'] ?? 'Chưa cập nhật';
          final phone = user['phone'] ?? 'Chưa cập nhật';
          final license = user['driveLicense'] ?? 'Chưa cập nhật';
          final role = user['role'] ?? 'USER';
          final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

          return RefreshIndicator(
            onRefresh: () => ref.refresh(userProfileProvider.future),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top + AppSpacing.lg,
                      bottom: AppSpacing.xxl,
                    ),
                    decoration: const BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(AppSpacing.xl)),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [AppTheme.ambientShadow],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            initial,
                            style: tt.displaySmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          name,
                          style: tt.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm + 4,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                          ),
                          child: Text(
                            role.toUpperCase() == 'ADMIN'
                                ? 'Quản trị viên'
                                : 'Khách hàng thành viên',
                            style: tt.labelMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.xl,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FadeSlideIn(
                            child: AppSurface(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SectionHeader(title: 'Thông tin cá nhân'),
                                  _buildInfoRow(context, Icons.phone_iphone_rounded, 'Số điện thoại', phone),
                                  const SizedBox(height: AppSpacing.lg),
                                  _buildInfoRow(context, Icons.email_rounded, 'Email liên hệ', email),
                                  const SizedBox(height: AppSpacing.lg),
                                  _buildInfoRow(context, Icons.badge_rounded, 'Bằng lái xe', license),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.section),

                          FadeSlideIn(
                            delay: const Duration(milliseconds: 80),
                            child: AppSurface(
                              onTap: () => context.push('/verification'),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.sm + 2),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer.withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.verified_user_rounded, color: cs.primary, size: 22),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Text('Xác minh danh tính',
                                              style: tt.titleMedium
                                                  ?.copyWith(fontWeight: FontWeight.w600)),
                                          const SizedBox(width: AppSpacing.sm),
                                          if (verifyStatus != null)
                                            _VerifyBadge(status: verifyStatus),
                                        ]),
                                        const SizedBox(height: AppSpacing.xs),
                                        Text(
                                          'Upload CCCD & Bằng lái để thuê xe dễ dàng hơn',
                                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),

                          if (role.toUpperCase() == 'ADMIN') ...[
                            const SizedBox(height: AppSpacing.lg),
                            FadeSlideIn(
                              delay: const Duration(milliseconds: 120),
                              child: AppSurface(
                                color: cs.primary,
                                onTap: () => context.go('/admin'),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(AppSpacing.sm + 2),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Bảng quản trị',
                                              style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                                          const SizedBox(height: AppSpacing.xs),
                                          Text('Quản lý người dùng, xe và đơn đặt',
                                              style: tt.bodySmall?.copyWith(color: Colors.white70)),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, color: Colors.white),
                                  ],
                                ),
                              ),
                            ),
                          ],

                          const SizedBox(height: AppSpacing.section),
                          const SectionHeader(title: 'Tài khoản'),
                          OutlinedButton.icon(
                            onPressed: () => context.push('/change-password'),
                            icon: const Icon(Icons.lock_reset_rounded),
                            label: const Text('Đổi mật khẩu'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await ref.read(authControllerProvider).logout();
                              if (context.mounted) context.go('/login');
                            },
                            icon: const Icon(Icons.logout_rounded),
                            label: const Text('Đăng xuất an toàn'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: cs.error,
                              side: BorderSide(color: cs.error.withValues(alpha: 0.3)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
                Icon(Icons.error_outline_rounded, color: cs.error, size: 48),
                const SizedBox(height: AppSpacing.lg),
                Text('Không tải được thông tin cá nhân', style: tt.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(e.toString(), style: tt.bodySmall, textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xl),
                OutlinedButton(
                  onPressed: () => ref.invalidate(userProfileProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm + 2),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xs),
              Text(value, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _VerifyBadge extends StatelessWidget {
  const _VerifyBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = switch (status) {
      'VERIFIED' => ('Đã xác minh', cs.tertiary),
      'PENDING'  => ('Đang xử lý', cs.onSurfaceVariant),
      'REJECTED' => ('Bị từ chối', cs.error),
      _          => ('Chưa xác minh', cs.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm - 1, vertical: AppSpacing.xs - 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.sm - 2),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
