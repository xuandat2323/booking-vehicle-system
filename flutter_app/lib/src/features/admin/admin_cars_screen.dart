import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    queryParameters: {'page': 0, 'size': 50},
  );
  final data = response.data['data'] as Map<String, dynamic>;
  return (data['content'] as List<dynamic>).cast<Map<String, dynamic>>();
});

class AdminCarsScreen extends ConsumerWidget {
  const AdminCarsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminCarsProvider),
        child: carsAsync.when(
          data: (cars) => cars.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.5,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.directions_car_outlined,
                                size: 64, color: cs.outlineVariant),
                            const SizedBox(height: AppSpacing.md),
                            Text('Chưa có xe nào', style: tt.titleMedium),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.page,
                    AppSpacing.md,
                    AppSpacing.page,
                    AppSpacing.xxl + 56,
                  ),
                  itemCount: cars.length,
                  separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, i) {
                    final car = cars[i];
                    return FadeSlideIn(
                      delay: Duration(milliseconds: 30 * i),
                      child: _CarCard(
                        car: car,
                        onEdit: () => _showCarForm(context, ref, car: car),
                        onDelete: () => _confirmDelete(context, ref, car),
                      ),
                    );
                  },
                ),
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
                        Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          ToastUtils.mapError(e),
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(color: cs.error),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        OutlinedButton(
                          onPressed: () => ref.invalidate(adminCarsProvider),
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
    );
  }

  Future<void> _showCarForm(
    BuildContext context,
    WidgetRef ref, {
    Map<String, dynamic>? car,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CarFormDialog(car: car),
    );
    if (saved == true) ref.invalidate(adminCarsProvider);
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
      builder: (_) => AlertDialog(
        title: const Text('Xóa xe'),
        content: Text(
            'Bạn có chắc muốn xóa xe "$carName"?\nHành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
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

  String _transmission = 'AUTO';
  String _fuelType = 'GASOLINE';
  int? _branchId;
  bool _saving = false;
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
    _transmission = car?['transmission']?.toString() ?? 'AUTO';
    _fuelType = car?['fuelType']?.toString() ?? 'GASOLINE';
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
                    DropdownMenuItem(value: 'AUTO', child: Text('Tự động')),
                    DropdownMenuItem(value: 'MANUAL', child: Text('Số sàn')),
                  ],
                  onChanged: (v) => setState(() => _transmission = v ?? 'AUTO'),
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
  });

  final Map<String, dynamic> car;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

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
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        _StatusBadge(label: statusLabel, color: statusColor),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      licensePlate,
                      style: tt.bodySmall?.copyWith(color: cs.outline, fontWeight: FontWeight.w600),
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        location,
                        style: tt.bodySmall?.copyWith(color: cs.outline),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          FormatUtils.vndPerDay(car['pricePerDay']),
                          style: tt.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.edit_outlined, size: 20, color: cs.primary),
                              onPressed: onEdit,
                              tooltip: 'Sửa xe',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.delete_outline_rounded, size: 20, color: cs.error),
                              onPressed: onDelete,
                              tooltip: 'Xóa xe',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
