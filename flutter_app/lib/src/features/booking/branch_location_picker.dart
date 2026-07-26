import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_ui.dart';
import '../branches/branch_list_screen.dart';
import 'location_picker_dialog.dart';

/// Chọn điểm đón/trả chỉ từ danh sách chi nhánh GoRento (không free-map).
class BranchLocationPicker {
  static Future<PickedLocation?> show(
    BuildContext context, {
    required String title,
    PickedLocation? initialLocation,
  }) {
    return showModalBottomSheet<PickedLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BranchPickerSheet(
        title: title,
        initialLocation: initialLocation,
      ),
    );
  }
}

class _BranchPickerSheet extends ConsumerWidget {
  const _BranchPickerSheet({
    required this.title,
    this.initialLocation,
  });

  final String title;
  final PickedLocation? initialLocation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final branchesAsync = ref.watch(branchListProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Chỉ nhận/trả xe tại 3 chi nhánh GoRento.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: branchesAsync.when(
                  data: (branches) {
                    if (branches.isEmpty) {
                      return const Center(child: Text('Chưa có chi nhánh'));
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: branches.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final b = branches[index];
                        final name = b['name']?.toString() ?? '';
                        final address = b['address']?.toString() ?? '';
                        final lat = (b['latitude'] as num?)?.toDouble() ?? 0;
                        final lng = (b['longitude'] as num?)?.toDouble() ?? 0;
                        final branchId = (b['branchId'] as num?)?.toInt();
                        final selected = initialLocation != null &&
                            initialLocation!.address.contains(name);

                        return AppSurface(
                          onTap: () {
                            Navigator.pop(
                              context,
                              PickedLocation(
                                address: address.isNotEmpty ? '$name — $address' : name,
                                lat: lat,
                                lng: lng,
                                branchId: branchId,
                              ),
                            );
                          },
                          color: selected
                              ? cs.primaryContainer.withValues(alpha: 0.45)
                              : cs.surfaceContainerLowest,
                          child: Row(
                            children: [
                              Icon(Icons.storefront_rounded, color: cs.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: tt.titleSmall),
                                    const SizedBox(height: 4),
                                    Text(
                                      address,
                                      style: tt.bodySmall,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: cs.outline),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Lỗi: $e')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
