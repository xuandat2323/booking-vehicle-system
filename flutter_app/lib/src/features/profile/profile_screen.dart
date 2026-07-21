import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/auth_provider.dart';
import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';
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
                      top: MediaQuery.of(context).padding.top + 24,
                      bottom: 48,
                    ),
                    decoration: const BoxDecoration(
                      gradient: AppTheme.heroGradient,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
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
                        const SizedBox(height: 16),
                        Text(
                          name,
                          style: tt.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  sliver: SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                              boxShadow: [AppTheme.ambientShadow],
                            ),
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              children: [
                                _buildInfoRow(context, Icons.phone_iphone_rounded, 'Số điện thoại', phone),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
                                ),
                                _buildInfoRow(context, Icons.email_rounded, 'Email liên hệ', email),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
                                ),
                                _buildInfoRow(context, Icons.badge_rounded, 'Bằng lái xe', license),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Verification entry
                          InkWell(
                            onTap: () => context.push('/verification'),
                            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
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
                                      color: Colors.green.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.verified_user_rounded,
                                        color: Colors.green, size: 22),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Text('Xác minh danh tính',
                                              style: tt.titleMedium
                                                  ?.copyWith(fontWeight: FontWeight.w600)),
                                          const SizedBox(width: 8),
                                          if (verifyStatus != null)
                                            _VerifyBadge(status: verifyStatus),
                                        ]),
                                        Text(
                                          'Upload CCCD & Bằng lái để thuê xe dễ dàng hơn',
                                          style: tt.bodySmall?.copyWith(color: cs.outline),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: cs.outline),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Admin panel entry (only for ADMIN role)
                          if (role.toUpperCase() == 'ADMIN') ...[
                            InkWell(
                              onTap: () => context.push('/admin'),
                              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text('Bảng quản trị',
                                              style: tt.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
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
                            const SizedBox(height: 16),
                          ],

                          OutlinedButton.icon(
                            onPressed: () => context.push('/change-password'),
                            icon: const Icon(Icons.lock_reset_rounded),
                            label: const Text('Đổi mật khẩu'),
                          ),
                          const SizedBox(height: 16),
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: cs.error, size: 48),
              const SizedBox(height: 16),
              Text('Không tải được thông tin cá nhân', style: tt.titleMedium),
              const SizedBox(height: 8),
              Text(e.toString(), style: tt.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: () => ref.invalidate(userProfileProvider),
                child: const Text('Thử lại'),
              ),
            ],
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
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: cs.primary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: tt.bodySmall),
              const SizedBox(height: 2),
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
    final (label, color) = switch (status) {
      'VERIFIED' => ('Đã xác minh', Colors.green),
      'PENDING'  => ('Đang xử lý', Colors.orange),
      'REJECTED' => ('Bị từ chối', Colors.red),
      _          => ('Chưa xác minh', Theme.of(context).colorScheme.outline),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
