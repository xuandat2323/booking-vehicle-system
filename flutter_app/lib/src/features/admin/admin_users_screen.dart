import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

final adminUsersProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, search) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get(
    '/api/admin/users',
    queryParameters: {'search': search, 'page': 0, 'size': 50},
  );
  final data = response.data['data'] as Map<String, dynamic>;
  return (data['content'] as List<dynamic>).cast<Map<String, dynamic>>();
});

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value.trim());
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminUsersProvider(_searchQuery));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý người dùng')),
      body: Column(
        children: [
          // ── Search bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm theo tên, email...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── User list ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(adminUsersProvider(_searchQuery)),
              child: usersAsync.when(
                data: (users) => users.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.people_outline_rounded,
                                size: 64, color: cs.outlineVariant),
                            const SizedBox(height: 16),
                            Text('Không tìm thấy người dùng',
                                style: tt.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              'Thử thay đổi từ khóa tìm kiếm',
                              style: tt.bodyMedium
                                  ?.copyWith(color: cs.outline),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: users.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final user = users[i];
                          return _UserCard(
                            user: user,
                            onToggle: () => _toggleUser(context, user),
                          );
                        },
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
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
                        onPressed: () =>
                            ref.invalidate(adminUsersProvider(_searchQuery)),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleUser(
      BuildContext context, Map<String, dynamic> user) async {
    final userId = user['userId'];
    final isEnabled = user['enabled'] != false;
    final newState = !isEnabled;
    final action = newState ? 'kích hoạt' : 'vô hiệu hóa';
    final name = user['name']?.toString() ?? 'người dùng';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('${newState ? 'Kích hoạt' : 'Vô hiệu hóa'} tài khoản?'),
        content: Text(
            'Bạn có chắc muốn $action tài khoản của "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: newState
                ? null
                : FilledButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: Text(newState ? 'Kích hoạt' : 'Vô hiệu hóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(dioProvider).put(
        '/api/admin/users/$userId/toggle',
        queryParameters: {'enabled': newState},
      );
      ref.invalidate(adminUsersProvider(_searchQuery));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Đã $action tài khoản "${user['name']}"')),
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

class _UserCard extends StatelessWidget {
  const _UserCard({required this.user, required this.onToggle});
  final Map<String, dynamic> user;
  final VoidCallback onToggle;

  String _initials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final name = user['name']?.toString() ?? '';
    final email = user['email']?.toString() ?? '';
    final phone = user['phone']?.toString() ?? '';
    final role = user['role']?.toString() ?? 'USER';
    final totalBookings = user['totalBookings'];
    final isEnabled = user['enabled'] != false;

    final (roleLabel, roleColor) = switch (role) {
      'ADMIN' => ('Admin', Colors.red),
      'OWNER' => ('Chủ xe', Colors.orange),
      _ => ('Người dùng', Colors.blue),
    };

    return GestureDetector(
      onLongPress: onToggle,
      child: Container(
        decoration: BoxDecoration(
          color: isEnabled
              ? cs.surfaceContainerLowest
              : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          boxShadow: isEnabled ? [AppTheme.softShadow] : null,
          border: isEnabled
              ? null
              : Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // ── Avatar ──
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isEnabled
                    ? cs.primaryContainer.withValues(alpha: 0.2)
                    : cs.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials(name),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isEnabled ? cs.primary : cs.outline,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isEnabled
                                ? null
                                : cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _RoleBadge(label: roleLabel, color: roleColor),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(email,
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (phone.isNotEmpty) ...[
                        Icon(Icons.phone_outlined,
                            size: 12, color: cs.outline),
                        const SizedBox(width: 4),
                        Text(phone,
                            style:
                                tt.bodySmall?.copyWith(color: cs.outline)),
                        const SizedBox(width: 12),
                      ],
                      if (totalBookings != null) ...[
                        Icon(Icons.receipt_long_outlined,
                            size: 12, color: cs.outline),
                        const SizedBox(width: 4),
                        Text('$totalBookings đơn',
                            style:
                                tt.bodySmall?.copyWith(color: cs.outline)),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // ── Toggle icon ──
            IconButton(
              icon: Icon(
                isEnabled
                    ? Icons.toggle_on_rounded
                    : Icons.toggle_off_rounded,
                size: 32,
                color: isEnabled ? cs.primary : cs.outline,
              ),
              onPressed: onToggle,
              tooltip: isEnabled ? 'Vô hiệu hóa' : 'Kích hoạt',
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label, required this.color});
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
