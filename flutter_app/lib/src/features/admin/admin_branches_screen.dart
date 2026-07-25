import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.page),
            itemCount: branches.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, i) {
              final b = branches[i];
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
                    const SizedBox(height: 8),
                    Text(
                      'Xe sẵn: ${b['availableCarCount'] ?? 0}',
                      style: tt.labelLarge?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
      ),
    );
  }
}
