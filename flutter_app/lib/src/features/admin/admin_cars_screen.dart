import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/toast_utils.dart';
import '../../core/widgets/app_ui.dart';
import '../branches/branch_list_screen.dart';
import '../cars/car_list_screen.dart';

final adminCarsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get(
    '/api/admin/cars',
    queryParameters: {'page': 0, 'size': 100},
  );
  final data = response.data['data'] as Map<String, dynamic>;
  return (data['content'] as List<dynamic>).cast<Map<String, dynamic>>();
});

class AdminCarsScreen extends ConsumerStatefulWidget {
  const AdminCarsScreen({super.key, this.initialStatus, this.initialBranchId});

  final String? initialStatus;
  final String? initialBranchId;

  @override
  ConsumerState<AdminCarsScreen> createState() => _AdminCarsScreenState();
}

class _AdminCarsScreenState extends ConsumerState<AdminCarsScreen> {
  late String _statusFilter;
  int? _branchFilter;

  /// BOOKED = đang có đơn thuê, PENDING = khách vừa đặt chờ cọc.
  static const _filters = [
    ('Tất cả', ''),
    ('Sẵn sàng', 'AVAILABLE'),
    ('Đang thuê', 'BOOKED'),
    ('Chờ cọc', 'PENDING'),
    ('Bảo dưỡng', 'MAINTENANCE'),
  ];

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatus?.toUpperCase() ?? '';
    _branchFilter = int.tryParse(widget.initialBranchId ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(adminCarsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý xe')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCarForm(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm xe'),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (label, value) = _filters[i];
                final isSelected = _statusFilter == value;
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _statusFilter = value),
                  labelStyle: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant,
                  ),
                  selectedColor: cs.primary.withValues(alpha: 0.12),
                  showCheckmark: false,
                  side: isSelected
                      ? BorderSide(color: cs.primary.withValues(alpha: 0.4))
                      : BorderSide.none,
                  backgroundColor: cs.surfaceContainerLow,
                );
              },
            ),
          ),
          ref.watch(branchListProvider).maybeWhen(
                data: (branches) => Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    0,
                    AppSpacing.page,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.store_rounded, size: 18, color: cs.onSurfaceVariant),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: _branchFilter,
                            isExpanded: true,
                            isDense: true,
                            hint: const Text('Tất cả chi nhánh'),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Tất cả chi nhánh'),
                              ),
                              ...branches.map(
                                (b) => DropdownMenuItem<int?>(
                                  value: (b['branchId'] as num?)?.toInt(),
                                  child: Text(
                                    b['name']?.toString() ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _branchFilter = v),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminCarsProvider),
              child: carsAsync.when(
                data: (cars) {
                  final filtered = cars.where((c) {
                    final statusOk = _statusFilter.isEmpty ||
                        (c['status']?.toString() ?? '') == _statusFilter;
                    final branchOk = _branchFilter == null ||
                        (c['branchId'] as num?)?.toInt() == _branchFilter;
                    return statusOk && branchOk;
                  }).toList();
                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.45,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_car_outlined,
                                    size: 64, color: cs.outlineVariant),
                                const SizedBox(height: AppSpacing.md),
                                Text('Không có xe nào', style: tt.titleMedium),
                                const SizedBox(height: 8),
                                Text(
                                  'Thử chọn bộ lọc khác',
                                  style: tt.bodyMedium
                                      ?.copyWith(color: cs.outline),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      AppSpacing.md,
                      AppSpacing.page,
                      AppSpacing.xxl + 56,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, i) {
                      final car = filtered[i];
                      return FadeSlideIn(
                        delay: Duration(milliseconds: 30 * i),
                        child: _CarCard(
                          car: car,
                          onEdit: () => _showCarForm(context, ref, car: car),
                          onDelete: () => _confirmDelete(context, ref, car),
                          onChangeStatus: (status) =>
                              _changeStatus(context, car, status),
                          onViewReviews: () => _showCarReviews(context, car),
                          onManageImages: () => _showCarImages(context, car),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.xxl),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline_rounded,
                                  size: 48, color: cs.error),
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                ToastUtils.mapError(e),
                                textAlign: TextAlign.center,
                                style: tt.bodyMedium?.copyWith(color: cs.error),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              OutlinedButton(
                                onPressed: () =>
                                    ref.invalidate(adminCarsProvider),
                                child: const Text('Thử lại'),
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
        ],
      ),
    );
  }

  Future<void> _showCarForm(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? car,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (_) => _CarFormDialog(car: car),
    );
    if (saved == true) ref.invalidate(adminCarsProvider);
  }

  /// Đổi nhanh trạng thái xe (sẵn sàng <-> bảo dưỡng) mà không cần mở form sửa.
  Future<void> _changeStatus(
    BuildContext context,
    Map<String, dynamic> car,
    String status,
  ) async {
    final carName = carDisplayTitle(car['brand']?.toString(), car['name']?.toString());
    try {
      await ref.read(dioProvider).put(
            '/api/admin/cars/${car['id']}',
            data: {'status': status},
          );
      ref.invalidate(adminCarsProvider);
      ref.invalidate(branchListProvider);
      if (context.mounted) {
        ToastUtils.showSuccess(
          context,
          status == 'MAINTENANCE'
              ? 'Đã chuyển "$carName" sang bảo dưỡng'
              : 'Đã đưa "$carName" về sẵn sàng cho thuê',
        );
      }
    } catch (e) {
      if (context.mounted) ToastUtils.showError(context, e);
    }
  }

  Future<void> _showCarReviews(
    BuildContext context,
    Map<String, dynamic> car,
  ) async {
    final carId = car['id']?.toString();
    if (carId == null || carId.isEmpty) return;
    final carName = carDisplayTitle(
      car['brand']?.toString(),
      car['name']?.toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return _AdminCarReviewsSheet(
              carId: carId,
              carName: carName,
              scrollController: scrollController,
            );
          },
        );
      },
    );
  }

  /// Upload ảnh lên Cloudinary qua BE: POST /api/admin/cars/{id}/images (field `file`).
  Future<void> _showCarImages(
    BuildContext context,
    Map<String, dynamic> car,
  ) async {
    final carId = car['id']?.toString();
    if (carId == null || carId.isEmpty) return;
    final carName = carDisplayTitle(
      car['brand']?.toString(),
      car['name']?.toString(),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      showDragHandle: true,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return _AdminCarImagesSheet(
              carId: carId,
              carName: carName,
              scrollController: scrollController,
              onChanged: () => ref.invalidate(adminCarsProvider),
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> car,
  ) async {
    final carName = carDisplayTitle(car['brand']?.toString(), car['name']?.toString());
    final carId = car['id'];

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa xe'),
        content: Text(
            'Bạn có chắc muốn xóa xe "$carName"?\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(dioProvider).delete('/api/admin/cars/$carId');
      ref.invalidate(adminCarsProvider);
      if (context.mounted) {
        ToastUtils.showSuccess(context, 'Đã xóa xe "$carName"');
      }
    } catch (e) {
      if (context.mounted) {
        ToastUtils.showError(context, e);
      }
    }
  }
}

class _CarFormDialog extends ConsumerStatefulWidget {
  const _CarFormDialog({this.car});
  final Map<String, dynamic>? car;

  bool get isEdit => car != null;

  @override
  ConsumerState<_CarFormDialog> createState() => _CarFormDialogState();
}

class _CarFormDialogState extends ConsumerState<_CarFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _licensePlateController;
  late final TextEditingController _priceController;
  late final TextEditingController _locationController;
  late final TextEditingController _seatsController;

  String _transmission = 'AUTOMATIC';
  String _fuelType = 'GASOLINE';
  String _status = 'AVAILABLE';
  int? _branchId;
  bool _saving = false;

  /// Chỉ cho đổi tay giữa 2 trạng thái này; BOOKED/PENDING do luồng đơn thuê quyết định.
  static const _manualStatuses = ['AVAILABLE', 'MAINTENANCE'];
  final _priceFormatter = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    final car = widget.car;
    _nameController = TextEditingController(text: car?['name']?.toString() ?? '');
    _brandController = TextEditingController(text: car?['brand']?.toString() ?? '');
    _modelController = TextEditingController(text: car?['model']?.toString() ?? '');
    _licensePlateController = TextEditingController(text: car?['licensePlate']?.toString() ?? '');
    final price = car?['pricePerDay'];
    final priceNum = price is num ? price.toDouble() : double.tryParse('$price');
    _priceController = TextEditingController(
      text: priceNum != null ? _priceFormatter.format(priceNum.round()) : '',
    );
    _locationController = TextEditingController(text: car?['location']?.toString() ?? '');
    _seatsController = TextEditingController(text: car?['seats']?.toString() ?? '');
    _transmission = car?['transmission']?.toString() ?? 'AUTOMATIC';
    _fuelType = car?['fuelType']?.toString() ?? 'GASOLINE';
    _status = car?['status']?.toString() ?? 'AVAILABLE';
    _branchId = (car?['branchId'] as num?)?.toInt();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _licensePlateController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    _seatsController.dispose();
    super.dispose();
  }

  void _formatPriceField() {
    final parsed = FormatUtils.parsePrice(_priceController.text);
    if (parsed == null) return;
    final formatted = _priceFormatter.format(parsed.round());
    _priceController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final price = FormatUtils.parsePrice(_priceController.text);
    final seats = int.tryParse(_seatsController.text.trim());

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'brand': _brandController.text.trim(),
      'model': _modelController.text.trim().isEmpty ? null : _modelController.text.trim(),
      'licensePlate': _licensePlateController.text.trim(),
      'pricePerDay': price,
      'seats': seats,
      'transmission': _transmission,
      'fuelType': _fuelType,
      'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
      'branchId': _branchId,
      // API tạo xe nhận "carStatus", API sửa xe nhận "status".
      if (widget.isEdit) 'status': _status else 'carStatus': _status,
    };

    try {
      final dio = ref.read(dioProvider);
      if (widget.isEdit) {
        await dio.put('/api/admin/cars/${widget.car!['id']}', data: payload);
      } else {
        await dio.post('/api/admin/cars', data: payload);
      }
      if (mounted) {
        ToastUtils.showSuccess(
          context,
          widget.isEdit ? 'Cập nhật xe thành công' : 'Thêm xe thành công',
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ToastUtils.showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final branchesAsync = ref.watch(branchListProvider);
    final tt = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(widget.isEdit ? 'Sửa xe' : 'Thêm xe'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Tên xe *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _brandController,
                  decoration: const InputDecoration(labelText: 'Hãng xe *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _modelController,
                  decoration: const InputDecoration(labelText: 'Model'),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _licensePlateController,
                  decoration: const InputDecoration(labelText: 'Biển số *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Bắt buộc' : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _priceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Giá/ngày *'),
                  onChanged: (_) => _formatPriceField(),
                  validator: (v) {
                    final p = FormatUtils.parsePrice(v ?? '');
                    if (p == null || p <= 0) return 'Nhập giá hợp lệ';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _seatsController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Số chỗ'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _transmission,
                  decoration: const InputDecoration(labelText: 'Hộp số'),
                  items: const [
                    DropdownMenuItem(value: 'AUTOMATIC', child: Text('Tự động')),
                    DropdownMenuItem(value: 'MANUAL', child: Text('Số sàn')),
                  ],
                  onChanged: (v) => setState(() => _transmission = v ?? 'AUTOMATIC'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _fuelType,
                  decoration: const InputDecoration(labelText: 'Nhiên liệu'),
                  items: const [
                    DropdownMenuItem(value: 'GASOLINE', child: Text('Xăng')),
                    DropdownMenuItem(value: 'DIESEL', child: Text('Dầu')),
                    DropdownMenuItem(value: 'ELECTRIC', child: Text('Điện')),
                    DropdownMenuItem(value: 'HYBRID', child: Text('Hybrid')),
                  ],
                  onChanged: (v) => setState(() => _fuelType = v ?? 'GASOLINE'),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _manualStatuses.contains(_status) ? _status : null,
                  decoration: InputDecoration(
                    labelText: 'Trạng thái',
                    helperText: _manualStatuses.contains(_status)
                        ? null
                        : 'Xe đang trong đơn thuê, không đổi tay được',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'AVAILABLE', child: Text('Sẵn sàng cho thuê')),
                    DropdownMenuItem(value: 'MAINTENANCE', child: Text('Bảo dưỡng')),
                  ],
                  onChanged: _manualStatuses.contains(_status)
                      ? (v) => setState(() => _status = v ?? 'AVAILABLE')
                      : null,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(labelText: 'Khu vực'),
                ),
                const SizedBox(height: AppSpacing.sm),
                branchesAsync.when(
                  data: (branches) => DropdownButtonFormField<int?>(
                    value: _branchId,
                    decoration: const InputDecoration(labelText: 'Cơ sở'),
                    items: [
                      const DropdownMenuItem<int?>(value: null, child: Text('Không chọn')),
                      ...branches.map(
                        (b) => DropdownMenuItem<int?>(
                          value: (b['branchId'] as num?)?.toInt(),
                          child: Text(b['name']?.toString() ?? ''),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _branchId = v),
                  ),
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => Text('Không tải cơ sở', style: tt.bodySmall),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isEdit ? 'Lưu' : 'Thêm'),
        ),
      ],
    );
  }
}

class _CarCard extends StatelessWidget {
  const _CarCard({
    required this.car,
    required this.onEdit,
    required this.onDelete,
    required this.onChangeStatus,
    required this.onViewReviews,
    required this.onManageImages,
  });

  final Map<String, dynamic> car;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onChangeStatus;
  final VoidCallback onViewReviews;
  final VoidCallback onManageImages;

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label, {
    bool isDanger = false,
  }) {
    final color = isDanger ? Colors.red : null;
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              label,
              style: TextStyle(color: color),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final title = carDisplayTitle(car['brand']?.toString(), car['name']?.toString());
    final licensePlate = car['licensePlate']?.toString() ?? '';
    final status = car['status']?.toString() ?? '';
    final location = car['location']?.toString() ?? '';
    final imageUrl = car['imageUrl']?.toString();

    final (statusLabel, statusColor) = switch (status) {
      'AVAILABLE' => ('Sẵn sàng', cs.tertiary),
      'BOOKED' => ('Đang thuê', cs.primary),
      'MAINTENANCE' => ('Bảo dưỡng', cs.secondary),
      'INACTIVE' => ('Không hoạt động', cs.outline),
      _ => (status, cs.outline),
    };

    return Dismissible(
      key: ValueKey(car['id']),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.page),
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        child: Icon(Icons.delete_rounded, color: cs.error, size: 28),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: AppSurface(
        padding: EdgeInsets.zero,
        color: cs.surfaceContainerLowest,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(AppTheme.radiusCard),
                bottomLeft: Radius.circular(AppTheme.radiusCard),
              ),
              child: imageUrl != null && imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => _PlaceholderImage(cs: cs),
                    )
                  : _PlaceholderImage(cs: cs),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: title,
                      child: Text(
                        title,
                        style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _StatusBadge(label: statusLabel, color: statusColor),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      licensePlate,
                      style: tt.bodySmall?.copyWith(color: cs.outline, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        location,
                        style: tt.bodySmall?.copyWith(color: cs.outline),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            FormatUtils.vndPerDay(car['pricePerDay']),
                            style: tt.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Thêm thao tác',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          iconSize: 20,
                          splashRadius: 18,
                          icon: Icon(Icons.more_vert_rounded, color: cs.onSurfaceVariant),
                          onSelected: (value) {
                            if (value == 'images') {
                              onManageImages();
                            } else if (value == 'reviews') {
                              onViewReviews();
                            } else if (value == 'edit') {
                              onEdit();
                            } else if (value == 'delete') {
                              onDelete();
                            } else if (value == 'maintenance') {
                              onChangeStatus('MAINTENANCE');
                            } else if (value == 'available') {
                              onChangeStatus('AVAILABLE');
                            }
                          },
                          itemBuilder: (context) => [
                            _menuItem('images', Icons.photo_library_outlined, 'Quản lý ảnh'),
                            _menuItem('reviews', Icons.rate_review_outlined, 'Xem đánh giá'),
                            _menuItem('edit', Icons.edit_outlined, 'Sửa xe'),
                            if (status == 'AVAILABLE')
                              _menuItem('maintenance', Icons.build_outlined, 'Chuyển bảo dưỡng'),
                            if (status == 'MAINTENANCE')
                              _menuItem('available', Icons.play_circle_outline_rounded, 'Đưa về sẵn sàng'),
                            _menuItem('delete', Icons.delete_outline_rounded, 'Xóa xe', isDanger: true),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderImage extends StatelessWidget {
  const _PlaceholderImage({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 100,
      height: 100,
      color: cs.surfaceContainerLow,
      child: Icon(Icons.directions_car_rounded, size: 36, color: cs.outlineVariant),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _AdminCarReviewsSheet extends ConsumerStatefulWidget {
  const _AdminCarReviewsSheet({
    required this.carId,
    required this.carName,
    required this.scrollController,
  });

  final String carId;
  final String carName;
  final ScrollController scrollController;

  @override
  ConsumerState<_AdminCarReviewsSheet> createState() =>
      _AdminCarReviewsSheetState();
}

class _AdminCarReviewsSheetState extends ConsumerState<_AdminCarReviewsSheet> {
  late Future<List<Map<String, dynamic>>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = _loadReviews();
  }

  Future<List<Map<String, dynamic>>> _loadReviews() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get(
      '/api/reviews/car/${widget.carId}',
      queryParameters: {'page': 0, 'size': 50},
    );
    final data = response.data['data'];
    if (data is Map<String, dynamic>) {
      final content = data['content'];
      if (content is List) {
        return content.cast<Map<String, dynamic>>();
      }
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.page,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Đánh giá xe',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.carName,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _reviewsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      ToastUtils.mapError(snapshot.error!),
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.error),
                    ),
                  );
                }
                final reviews = snapshot.data ?? [];
                if (reviews.isEmpty) {
                  return Center(
                    child: Text(
                      'Chưa có đánh giá nào cho xe này.',
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                final avg = reviews
                        .map((r) => (r['rating'] as num?)?.toDouble() ?? 0)
                        .fold<double>(0, (a, b) => a + b) /
                    reviews.length;

                return ListView.separated(
                  controller: widget.scrollController,
                  itemCount: reviews.length + 1,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return AppSurface(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        color: cs.primaryContainer.withValues(alpha: 0.25),
                        child: Row(
                          children: [
                            Icon(Icons.star_rounded, color: Colors.orange.shade700),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              '${avg.toStringAsFixed(1)} / 5',
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                '(${reviews.length} đánh giá)',
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final review = reviews[index - 1];
                    final rating = review['rating'] as int? ?? 0;
                    final date =
                        review['createdAt']?.toString().split('T').first ?? '';
                    final userName =
                        review['userName']?.toString() ?? 'Khách hàng';
                    final bookingId = review['bookingId'];

                    return AppSurface(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      color: cs.surfaceContainerLowest,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundColor:
                                    cs.primary.withValues(alpha: 0.12),
                                child: Text(
                                  userName.isNotEmpty
                                      ? userName[0].toUpperCase()
                                      : 'K',
                                  style: TextStyle(
                                    color: cs.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      userName,
                                      style: tt.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (bookingId != null)
                                      Text(
                                        'Đơn #$bookingId',
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Flexible(
                                child: Text(
                                  date,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Row(
                            children: List.generate(5, (i) {
                              return Icon(
                                i < rating
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: Colors.orange.shade700,
                                size: 18,
                              );
                            }),
                          ),
                          if (review['comment'] != null &&
                              review['comment'].toString().isNotEmpty) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              review['comment'].toString(),
                              style: tt.bodyMedium,
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Quản lý ảnh xe: upload JPEG/PNG lên Cloudinary qua BE (tối đa 5 ảnh).
class _AdminCarImagesSheet extends ConsumerStatefulWidget {
  const _AdminCarImagesSheet({
    required this.carId,
    required this.carName,
    required this.scrollController,
    required this.onChanged,
  });

  final String carId;
  final String carName;
  final ScrollController scrollController;
  final VoidCallback onChanged;

  @override
  ConsumerState<_AdminCarImagesSheet> createState() =>
      _AdminCarImagesSheetState();
}

class _AdminCarImagesSheetState extends ConsumerState<_AdminCarImagesSheet> {
  static const _maxImages = 5;
  late Future<List<Map<String, dynamic>>> _imagesFuture;
  bool _uploading = false;
  String? _statusText;
  bool _statusIsError = false;

  @override
  void initState() {
    super.initState();
    _imagesFuture = _loadImages();
  }

  Future<List<Map<String, dynamic>>> _loadImages() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/admin/cars/${widget.carId}/images');
    final data = response.data['data'];
    if (data is! List) return [];
    return data.cast<Map<String, dynamic>>();
  }

  void _reload() {
    // Không dùng `=>` vì _loadImages() trả Future — setState sẽ hiểu callback trả Future.
    final next = _loadImages();
    setState(() {
      _imagesFuture = next;
    });
    widget.onChanged();
  }

  void _setStatus(String text, {required bool isError}) {
    setState(() {
      _statusText = text;
      _statusIsError = isError;
    });
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final mime = _resolveImageMime(picked);
    if (mime == null) {
      _setStatus('Chỉ hỗ trợ ảnh JPEG hoặc PNG', isError: true);
      return;
    }

    setState(() {
      _uploading = true;
      _statusText = 'Đang tải lên Cloudinary...';
      _statusIsError = false;
    });
    try {
      final bytes = await picked.readAsBytes();
      if (bytes.isEmpty) {
        throw 'File ảnh trống';
      }

      final filename = _ensureImageFilename(picked.name, mime);
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          bytes,
          filename: filename,
          contentType: DioMediaType.parse(mime),
        ),
      });

      await ref.read(dioProvider).post(
            '/api/admin/cars/${widget.carId}/images',
            data: form,
            options: Options(
              sendTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
              contentType: null,
            ),
          );
      if (!mounted) return;
      _setStatus('Tải ảnh thành công', isError: false);
      _reload();
    } catch (e) {
      if (mounted) {
        _setStatus(ToastUtils.mapError(e), isError: true);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// Android/iOS đôi khi trả name không có đuôi hoặc mime null.
  String? _resolveImageMime(XFile picked) {
    final mime = (picked.mimeType ?? '').toLowerCase().trim();
    if (mime == 'image/jpeg' || mime == 'image/jpg' || mime == 'image/png') {
      return mime == 'image/jpg' ? 'image/jpeg' : mime;
    }
    final name = picked.name.toLowerCase();
    final path = picked.path.toLowerCase();
    if (name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (name.endsWith('.png') || path.endsWith('.png')) {
      return 'image/png';
    }
    if (!name.contains('.') && (mime.startsWith('image/') || mime.isEmpty)) {
      return 'image/jpeg';
    }
    return null;
  }

  String _ensureImageFilename(String original, String mime) {
    final lower = original.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png')) {
      return original;
    }
    return mime == 'image/png' ? 'car.png' : 'car.jpg';
  }

  Future<void> _setPrimary(Map<String, dynamic> image) async {
    final imageId = image['id'];
    if (imageId == null) return;
    try {
      await ref.read(dioProvider).patch(
            '/api/admin/cars/${widget.carId}/images/$imageId/primary',
          );
      if (mounted) {
        ToastUtils.showSuccess(context, 'Đã đặt ảnh đại diện');
        _reload();
      }
    } catch (e) {
      if (mounted) ToastUtils.showError(context, e);
    }
  }

  Future<void> _deleteImage(Map<String, dynamic> image) async {
    final imageId = image['id'];
    if (imageId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa ảnh?'),
        content: const Text('Ảnh sẽ bị xóa khỏi Cloudinary và danh sách xe.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(dioProvider).delete(
            '/api/admin/cars/${widget.carId}/images/$imageId',
          );
      if (mounted) {
        ToastUtils.showSuccess(context, 'Đã xóa ảnh');
        _reload();
      }
    } catch (e) {
      if (mounted) ToastUtils.showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.page,
        0,
        AppSpacing.page,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ảnh xe',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            widget.carName,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            'JPEG/PNG · tối đa $_maxImages ảnh · ảnh đầu là đại diện',
            style: tt.bodySmall?.copyWith(color: cs.outline),
          ),
          if (_statusText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _statusText!,
              style: tt.bodySmall?.copyWith(
                color: _statusIsError ? cs.error : cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _imagesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      ToastUtils.mapError(snapshot.error!),
                      textAlign: TextAlign.center,
                      style: tt.bodyMedium?.copyWith(color: cs.error),
                    ),
                  );
                }

                final images = snapshot.data ?? [];
                final canUpload = images.length < _maxImages;

                return Column(
                  children: [
                    Expanded(
                      child: images.isEmpty
                          ? ListView(
                              controller: widget.scrollController,
                              children: [
                                const SizedBox(height: 48),
                                Icon(
                                  Icons.photo_outlined,
                                  size: 56,
                                  color: cs.outlineVariant,
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Chưa có ảnh',
                                  textAlign: TextAlign.center,
                                  style: tt.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Thêm ảnh để khách thấy xe trên danh sách và chi tiết',
                                  textAlign: TextAlign.center,
                                  style: tt.bodySmall?.copyWith(color: cs.outline),
                                ),
                              ],
                            )
                          : GridView.builder(
                              controller: widget.scrollController,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                childAspectRatio: 0.85,
                              ),
                              itemCount: images.length,
                              itemBuilder: (context, index) {
                                final image = images[index];
                                final url = image['imageUrl']?.toString() ?? '';
                                final isPrimary = image['isPrimary'] == true;
                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.radiusInput,
                                    ),
                                    border: Border.all(
                                      color: isPrimary
                                          ? cs.primary
                                          : cs.outlineVariant.withValues(
                                              alpha: 0.4,
                                            ),
                                      width: isPrimary ? 2 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: url.isEmpty
                                            ? ColoredBox(
                                                color: cs.surfaceContainerLow,
                                                child: Icon(
                                                  Icons.broken_image_outlined,
                                                  color: cs.outline,
                                                ),
                                              )
                                            : Image.network(
                                                url,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, _, _) =>
                                                    ColoredBox(
                                                  color: cs.surfaceContainerLow,
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: cs.outline,
                                                  ),
                                                ),
                                              ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        child: Row(
                                          children: [
                                            if (isPrimary)
                                              Expanded(
                                                child: Text(
                                                  'Đại diện',
                                                  style: tt.labelSmall?.copyWith(
                                                    color: cs.primary,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              )
                                            else
                                              Expanded(
                                                child: TextButton(
                                                  onPressed: () =>
                                                      _setPrimary(image),
                                                  style: TextButton.styleFrom(
                                                    padding: EdgeInsets.zero,
                                                    visualDensity:
                                                        VisualDensity.compact,
                                                  ),
                                                  child: const Text(
                                                    'Đặt đại diện',
                                                    style: TextStyle(fontSize: 12),
                                                  ),
                                                ),
                                              ),
                                            IconButton(
                                              tooltip: 'Xóa ảnh',
                                              visualDensity:
                                                  VisualDensity.compact,
                                              icon: Icon(
                                                Icons.delete_outline_rounded,
                                                size: 18,
                                                color: cs.error,
                                              ),
                                              onPressed: () =>
                                                  _deleteImage(image),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    FilledButton.icon(
                      onPressed: (!canUpload || _uploading)
                          ? null
                          : _pickAndUpload,
                      icon: _uploading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.cloud_upload_outlined),
                      label: Text(
                        canUpload
                            ? (_uploading
                                ? 'Đang tải lên Cloudinary...'
                                : 'Thêm ảnh từ thư viện')
                            : 'Đã đủ $_maxImages ảnh',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
