import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_ui.dart';
import '../branches/branch_list_screen.dart';

/// Admin xem / quản lý 3 chi nhánh (danh sách active từ API).
class AdminBranchesScreen extends ConsumerWidget {
  const AdminBranchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(branchListProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi nhánh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(branchListProvider),
          ),
        ],
      ),
      body: async.when(
        data: (branches) {
          if (branches.isEmpty) {
            return const Center(child: Text('Chưa có chi nhánh'));
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(branchListProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.page),
              itemCount: branches.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final b = branches[i];
                final branchId = (b['branchId'] as num?)?.toInt();
                final total = (b['totalCarCount'] as num?)?.toInt() ?? 0;

                return AppSurface(
                  color: cs.surfaceContainerLowest,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b['name']?.toString() ?? '', style: tt.titleMedium),
                      const SizedBox(height: 6),
                      Text(b['address']?.toString() ?? '', style: tt.bodyMedium),
                      if ((b['phone']?.toString() ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(b['phone'].toString(), style: tt.bodySmall),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Tổng $total xe · nhấn để xem danh sách',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _CarCountTile(
                            label: 'Xe sẵn',
                            count: (b['availableCarCount'] as num?)?.toInt() ?? 0,
                            color: cs.tertiary,
                            onTap: branchId == null
                                ? null
                                : () => context.push(
                                      '/admin/cars?branchId=$branchId&status=AVAILABLE',
                                    ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _CarCountTile(
                            label: 'Đã thuê',
                            count: (b['rentedCarCount'] as num?)?.toInt() ?? 0,
                            color: cs.primary,
                            onTap: branchId == null
                                ? null
                                : () => context.push(
                                      '/admin/cars?branchId=$branchId&status=BOOKED',
                                    ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          _CarCountTile(
                            label: 'Bảo dưỡng',
                            count: (b['maintenanceCarCount'] as num?)?.toInt() ?? 0,
                            color: cs.secondary,
                            onTap: branchId == null
                                ? null
                                : () => context.push(
                                      '/admin/cars?branchId=$branchId&status=MAINTENANCE',
                                    ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }
}

class _CarCountTile extends StatelessWidget {
  const _CarCountTile({
    required this.label,
    required this.count,
    required this.color,
    this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
            horizontal: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppSpacing.md),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: tt.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: tt.labelSmall?.copyWith(color: color),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
