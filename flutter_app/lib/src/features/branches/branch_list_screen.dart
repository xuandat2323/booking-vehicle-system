import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_ui.dart';

final branchListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/branches');
  final data = response.data['data'] as List;
  return data.cast<Map<String, dynamic>>();
});

class BranchListScreen extends ConsumerWidget {
  const BranchListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchListProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Chọn cơ sở')),
      body: branchAsync.when(
        data: (branches) {
          if (branches.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.store_outlined, size: 64, color: cs.outline),
                    const SizedBox(height: AppSpacing.lg),
                    Text('Chưa có cơ sở nào', style: tt.titleMedium),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.page),
            itemCount: branches.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
            itemBuilder: (context, index) {
              return FadeSlideIn(
                delay: Duration(milliseconds: 40 * index),
                child: _BranchCard(branch: branches[index]),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: AppSpacing.md),
                Text('Lỗi tải dữ liệu', style: tt.titleMedium),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: () => ref.invalidate(branchListProvider),
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

class _BranchCard extends StatelessWidget {
  final Map<String, dynamic> branch;
  const _BranchCard({required this.branch});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final name = branch['name'] ?? '';
    final address = branch['address'] ?? '';
    final phone = branch['phone'] ?? '';
    final availableCount = branch['availableCarCount'] ?? 0;

    return AppSurface(
      onTap: () {
        final branchId = branch['branchId'];
        context.push('/cars?branchId=$branchId');
      },
      color: cs.surfaceContainerLowest,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.storefront_outlined, color: cs.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: tt.titleSmall),
                const SizedBox(height: 6),
                Text(
                  address,
                  style: tt.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(phone, style: tt.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            children: [
              Text(
                '$availableCount',
                style: tt.titleMedium?.copyWith(color: cs.primary),
              ),
              Text(
                'xe',
                style: tt.labelSmall?.copyWith(color: cs.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
