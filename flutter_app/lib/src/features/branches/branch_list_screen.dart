import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.store_outlined, size: 64, color: cs.outline),
                  const SizedBox(height: AppTheme.spacingMd),
                  Text('Chưa có cơ sở nào', style: tt.bodyLarge),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppTheme.spacingMd),
            itemCount: branches.length,
            separatorBuilder: (context, index) => const SizedBox(height: AppTheme.spacingSm),
            itemBuilder: (context, index) {
              final branch = branches[index];
              return _BranchCard(branch: branch);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Lỗi tải dữ liệu', style: tt.bodyLarge),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () => ref.invalidate(branchListProvider),
                child: const Text('Thử lại'),
              ),
            ],
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

    return Card(
      child: InkWell(
        onTap: () {
          final branchId = branch['branchId'];
          context.push('/cars?branchId=$branchId');
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          child: Row(
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AppTheme.heroGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.store_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: AppTheme.spacingMd),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: tt.titleSmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 14, color: cs.outline),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            address,
                            style: tt.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.phone_outlined, size: 14, color: cs.outline),
                          const SizedBox(width: 4),
                          Text(phone, style: tt.bodySmall),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Car count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                ),
                child: Column(
                  children: [
                    Text(
                      '$availableCount',
                      style: tt.titleMedium?.copyWith(color: cs.primary),
                    ),
                    Text(
                      'xe',
                      style: tt.bodySmall?.copyWith(color: cs.primary, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
