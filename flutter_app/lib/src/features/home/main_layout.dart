import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth/current_user_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';

class MainLayout extends ConsumerWidget {
  const MainLayout({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _userTabs = [
    _Tab(Icons.home_rounded, Icons.home_outlined, 'Trang chủ', 0),
    _Tab(Icons.directions_car_rounded, Icons.directions_car_outlined, 'Tìm xe', 1),
    _Tab(Icons.receipt_long_rounded, Icons.receipt_long_outlined, 'Chuyến đi', 2),
    _Tab(Icons.receipt_rounded, Icons.receipt_outlined, 'Hóa đơn', 3),
    _Tab(Icons.person_rounded, Icons.person_outlined, 'Tài khoản', 4),
  ];

  /// Shell branch indices: 0 home, 1 cars, 2 bookings, 3 invoices, 4 profile, 5 admin
  static const _adminTabs = [
    _Tab(Icons.home_rounded, Icons.home_outlined, 'Trang chủ', 0),
    _Tab(Icons.admin_panel_settings_rounded, Icons.admin_panel_settings_outlined, 'Quản trị', 5),
    _Tab(Icons.person_rounded, Icons.person_outlined, 'Tài khoản', 4),
  ];

  void _onTap(int shellIndex) {
    navigationShell.goBranch(
      shellIndex,
      initialLocation: shellIndex == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final isAdmin = ref.watch(isAdminProvider);
    final tabs = isAdmin ? _adminTabs : _userTabs;
    final current = navigationShell.currentIndex;

    return Scaffold(
      body: navigationShell,
      floatingActionButton: isAdmin
          ? null
          : FloatingActionButton(
              onPressed: () => context.push('/chatbot'),
              tooltip: 'Trợ lý GoRento',
              child: const Icon(Icons.smart_toy_rounded),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF12181F).withValues(alpha: 0.06),
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: [
                for (final tab in tabs)
                  Expanded(
                    child: InkWell(
                      onTap: () => _onTap(tab.shellIndex),
                      borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: current == tab.shellIndex
                              ? cs.primary.withValues(alpha: 0.08)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              current == tab.shellIndex ? tab.selectedIcon : tab.icon,
                              color: current == tab.shellIndex ? cs.primary : cs.outline,
                              size: 22,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tab.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                letterSpacing: -0.1,
                                fontWeight: current == tab.shellIndex
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: current == tab.shellIndex ? cs.primary : cs.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab {
  const _Tab(this.selectedIcon, this.icon, this.label, this.shellIndex);
  final IconData selectedIcon;
  final IconData icon;
  final String label;
  final int shellIndex;
}
