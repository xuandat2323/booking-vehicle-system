import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

class OwnerCarFormScreen extends ConsumerStatefulWidget {
  const OwnerCarFormScreen({super.key, this.carId});

  final String? carId;

  @override
  ConsumerState<OwnerCarFormScreen> createState() => _OwnerCarFormScreenState();
}

class _OwnerCarFormScreenState extends ConsumerState<OwnerCarFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _brandCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  String _transmission = 'AUTOMATIC';
  String _fuelType = 'GASOLINE';
  int _seats = 5;
  bool _loading = false;
  bool _fetchingCar = false;

  // After car is created/saved we get the carId for image management
  String? _savedCarId;

  // Images loaded from server
  List<Map<String, dynamic>> _serverImages = [];
  bool _loadingImages = false;
  // Images being uploaded (show local preview while uploading)
  final List<_PendingImage> _pendingUploads = [];

  bool get _isEdit => widget.carId != null;
  String? get _activeCarId => _savedCarId ?? widget.carId;
  bool get _canManageImages => _activeCarId != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _fetchCar();
      _fetchImages();
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _brandCtrl, _modelCtrl, _plateCtrl, _priceCtrl, _locationCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchCar() async {
    setState(() => _fetchingCar = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/cars/${widget.carId}');
      final car = response.data['data'] as Map<String, dynamic>;
      _nameCtrl.text = car['name']?.toString() ?? '';
      _brandCtrl.text = car['brand']?.toString() ?? '';
      _modelCtrl.text = car['model']?.toString() ?? '';
      _plateCtrl.text = car['licensePlate']?.toString() ?? '';
      _priceCtrl.text = car['pricePerDay']?.toString().split('.').first ?? '';
      _locationCtrl.text = car['location']?.toString() ?? '';
      setState(() {
        _transmission = car['transmission']?.toString() ?? 'AUTOMATIC';
        _fuelType = car['fuelType']?.toString() ?? 'GASOLINE';
        _seats = (car['seats'] as num?)?.toInt() ?? 5;
      });
    } catch (_) {}
    finally {
      if (mounted) setState(() => _fetchingCar = false);
    }
  }

  Future<void> _fetchImages() async {
    final carId = _activeCarId;
    if (carId == null) return;
    setState(() => _loadingImages = true);
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/owner/cars/$carId/images');
      final list = response.data['data'] as List<dynamic>;
      if (mounted) setState(() => _serverImages = list.cast<Map<String, dynamic>>());
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loadingImages = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final data = {
        'name': _nameCtrl.text.trim(),
        'brand': _brandCtrl.text.trim(),
        'model': _modelCtrl.text.trim(),
        'licensePlate': _plateCtrl.text.trim(),
        'pricePerDay': double.parse(_priceCtrl.text.trim()),
        'location': _locationCtrl.text.trim(),
        'transmission': _transmission,
        'fuelType': _fuelType,
        'seats': _seats,
      };

      if (_isEdit) {
        await dio.put('/api/owner/cars/${widget.carId}', data: data);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cập nhật xe thành công')));
        }
      } else {
        final response = await dio.post('/api/owner/cars', data: data);
        final created = response.data['data'] as Map<String, dynamic>;
        final newId = created['carId']?.toString() ?? created['id']?.toString();
        if (mounted) {
          setState(() => _savedCarId = newId);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đăng xe thành công — Thêm ảnh xe bên dưới')),
          );
          // Scroll down to image section after car is created
          await Future.delayed(const Duration(milliseconds: 300));
          _scrollToImages();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  final _scrollController = ScrollController();

  void _scrollToImages() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  Future<void> _pickAndUpload() async {
    final carId = _activeCarId;
    if (carId == null) return;
    if (_serverImages.length + _pendingUploads.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 5 ảnh cho mỗi xe')),
      );
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final pending = _PendingImage(bytes: bytes, name: picked.name);
    setState(() => _pendingUploads.add(pending));

    try {
      final dio = ref.read(dioProvider);
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: picked.name),
      });
      await dio.post('/api/owner/cars/$carId/images', data: formData);
      if (mounted) {
        setState(() => _pendingUploads.remove(pending));
        await _fetchImages();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pendingUploads.remove(pending));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload thất bại: $e')));
      }
    }
  }

  Future<void> _deleteImage(Map<String, dynamic> image) async {
    final carId = _activeCarId;
    if (carId == null) return;
    final imageId = image['carImageId']?.toString() ?? image['id']?.toString();
    if (imageId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa ảnh'),
        content: const Text('Bạn có chắc muốn xóa ảnh này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Hủy')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('/api/owner/cars/$carId/images/$imageId');
      if (mounted) await _fetchImages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi xóa ảnh: $e')));
    }
  }

  Future<void> _setPrimary(Map<String, dynamic> image) async {
    final carId = _activeCarId;
    if (carId == null) return;
    final imageId = image['carImageId']?.toString() ?? image['id']?.toString();
    if (imageId == null) return;
    try {
      final dio = ref.read(dioProvider);
      await dio.patch('/api/owner/cars/$carId/images/$imageId/primary');
      if (mounted) await _fetchImages();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_fetchingCar) {
      return Scaffold(
        appBar: AppBar(title: Text(_isEdit ? 'Chỉnh sửa xe' : 'Đăng xe mới')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Chỉnh sửa xe' : 'Đăng xe mới')),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(
                title: 'Thông tin cơ bản',
                children: [
                  _Field(ctrl: _nameCtrl, label: 'Tên xe', icon: Icons.directions_car_rounded, required: true),
                  const SizedBox(height: 16),
                  _Field(ctrl: _brandCtrl, label: 'Hãng xe', icon: Icons.business_rounded, required: true),
                  const SizedBox(height: 16),
                  _Field(ctrl: _modelCtrl, label: 'Phiên bản / Model', icon: Icons.info_outline_rounded),
                  const SizedBox(height: 16),
                  _Field(
                    ctrl: _plateCtrl,
                    label: 'Biển số xe',
                    icon: Icons.pin_rounded,
                    required: true,
                    hint: 'VD: 30K-123.45',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Giá & Vị trí',
                children: [
                  _Field(
                    ctrl: _priceCtrl,
                    label: 'Giá thuê / ngày (VNĐ)',
                    icon: Icons.payments_rounded,
                    required: true,
                    numeric: true,
                    hint: 'VD: 800000',
                  ),
                  const SizedBox(height: 16),
                  _Field(
                    ctrl: _locationCtrl,
                    label: 'Khu vực giao xe',
                    icon: Icons.location_on_rounded,
                    required: true,
                    hint: 'VD: Hà Nội, Quận Đống Đa',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Section(
                title: 'Thông số kỹ thuật',
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _transmission,
                    decoration: const InputDecoration(
                      labelText: 'Hộp số',
                      prefixIcon: Icon(Icons.settings_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'AUTOMATIC', child: Text('Số tự động')),
                      DropdownMenuItem(value: 'MANUAL', child: Text('Số sàn')),
                    ],
                    onChanged: (v) => setState(() => _transmission = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: _fuelType,
                    decoration: const InputDecoration(
                      labelText: 'Nhiên liệu',
                      prefixIcon: Icon(Icons.local_gas_station_rounded),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GASOLINE', child: Text('Xăng')),
                      DropdownMenuItem(value: 'DIESEL', child: Text('Dầu diesel')),
                      DropdownMenuItem(value: 'ELECTRIC', child: Text('Điện')),
                      DropdownMenuItem(value: 'HYBRID', child: Text('Hybrid')),
                    ],
                    onChanged: (v) => setState(() => _fuelType = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    initialValue: _seats,
                    decoration: const InputDecoration(
                      labelText: 'Số chỗ ngồi',
                      prefixIcon: Icon(Icons.airline_seat_recline_normal_rounded),
                    ),
                    items: [4, 5, 7, 8, 9]
                        .map((s) => DropdownMenuItem(value: s, child: Text('$s chỗ')))
                        .toList(),
                    onChanged: (v) => setState(() => _seats = v!),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              GradientButton(
                onPressed: _loading ? null : _submit,
                isLoading: _loading,
                child: Text(
                  _isEdit ? 'Lưu thay đổi' : 'Đăng xe',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // ── Image section — visible after car exists ──
              if (_canManageImages) ...[
                _ImageSection(
                  images: _serverImages,
                  pendingUploads: _pendingUploads,
                  loadingImages: _loadingImages,
                  onAdd: _pickAndUpload,
                  onDelete: _deleteImage,
                  onSetPrimary: _setPrimary,
                  canAdd: _serverImages.length + _pendingUploads.length < 5,
                ),
                const SizedBox(height: 32),
              ] else if (!_isEdit) ...[
                // Teaser — disabled until car is saved
                Opacity(
                  opacity: 0.4,
                  child: _Section(
                    title: 'Ảnh xe (tối đa 5)',
                    children: [
                      Row(
                        children: [
                          Icon(Icons.photo_library_rounded, color: Colors.grey.shade400, size: 32),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Đăng xe trước, rồi thêm ảnh',
                              style: TextStyle(color: Colors.grey.shade500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Image section widget ──────────────────────────────────────────────────────

class _PendingImage {
  _PendingImage({required this.bytes, required this.name});
  final Uint8List bytes;
  final String name;
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.images,
    required this.pendingUploads,
    required this.loadingImages,
    required this.onAdd,
    required this.onDelete,
    required this.onSetPrimary,
    required this.canAdd,
  });

  final List<Map<String, dynamic>> images;
  final List<_PendingImage> pendingUploads;
  final bool loadingImages;
  final VoidCallback onAdd;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final Future<void> Function(Map<String, dynamic>) onSetPrimary;
  final bool canAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [AppTheme.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Ảnh xe (${images.length}/5)',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              if (canAdd)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_photo_alternate_rounded, size: 18),
                  label: const Text('Thêm ảnh'),
                ),
            ],
          ),
          if (loadingImages)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (images.isEmpty && pendingUploads.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.photo_library_outlined, size: 48, color: cs.outlineVariant),
                    const SizedBox(height: 8),
                    Text('Chưa có ảnh — nhấn "Thêm ảnh" để tải lên',
                        style: tt.bodySmall?.copyWith(color: cs.outline)),
                  ],
                ),
              ),
            )
          else ...[
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: [
                for (final img in images) _ServerImageTile(image: img, onDelete: onDelete, onSetPrimary: onSetPrimary),
                for (final p in pendingUploads) _PendingImageTile(pending: p),
              ],
            ),
          ],
          if (images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Nhấn giữ ảnh để đặt làm ảnh đại diện',
                style: tt.labelSmall?.copyWith(color: cs.outline),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServerImageTile extends StatelessWidget {
  const _ServerImageTile({required this.image, required this.onDelete, required this.onSetPrimary});

  final Map<String, dynamic> image;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final Future<void> Function(Map<String, dynamic>) onSetPrimary;

  @override
  Widget build(BuildContext context) {
    final isPrimary = image['primary'] == true || image['isPrimary'] == true;
    final url = image['imageUrl']?.toString() ?? '';

    return GestureDetector(
      onLongPress: () => onSetPrimary(image),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
              ),
            ),
          ),
          if (isPrimary)
            Positioned(
              top: 4, left: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Chính', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
              ),
            ),
          Positioned(
            top: 2, right: 2,
            child: GestureDetector(
              onTap: () => onDelete(image),
              child: Container(
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                padding: const EdgeInsets.all(3),
                child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingImageTile extends StatelessWidget {
  const _PendingImageTile({required this.pending});
  final _PendingImage pending;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(pending.bytes, fit: BoxFit.cover),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        ),
      ],
    );
  }
}

// ── Reusable form widgets ─────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [AppTheme.softShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.ctrl,
    required this.label,
    required this.icon,
    this.required = false,
    this.numeric = false,
    this.hint,
  });

  final TextEditingController ctrl;
  final String label;
  final IconData icon;
  final bool required;
  final bool numeric;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: ctrl,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
      ),
      validator: required
          ? (v) => (v?.trim().isEmpty ?? true) ? 'Vui lòng nhập $label' : null
          : null,
    );
  }
}
