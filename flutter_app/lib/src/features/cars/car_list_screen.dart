import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import '../../core/utils/shimmer_utils.dart';
import '../../core/widgets/app_ui.dart';
import '../branches/branch_list_screen.dart';

final carListParamsProvider = StateProvider<CarListParams>((ref) => const CarListParams());

final nearbyLocationProvider = StateProvider<({double lat, double lng})?>((ref) => null);

final carListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dio = ref.read(dioProvider);
  final params = ref.watch(carListParamsProvider);
  final nearbyLoc = ref.watch(nearbyLocationProvider);

  if (nearbyLoc != null) {
    final nearbyQuery = <String, dynamic>{
      'lat': nearbyLoc.lat,
      'lng': nearbyLoc.lng,
      'radius': 10,
      'onlyAvailable': params.onlyAvailable,
    };
    if (params.branchId != null) nearbyQuery['branchId'] = params.branchId;

    final response = await dio.get('/api/cars/nearby', queryParameters: nearbyQuery);
    final content = response.data['data'] as List<dynamic>;
    return content.cast<Map<String, dynamic>>();
  }

  final queryParameters = <String, dynamic>{
    'onlyAvailable': params.onlyAvailable,
    'page': 0,
    'size': 20,
  };
  if (params.brand.trim().isNotEmpty) queryParameters['brand'] = params.brand.trim();
  if (params.name.trim().isNotEmpty) queryParameters['name'] = params.name.trim();
  if (params.location.trim().isNotEmpty) queryParameters['location'] = params.location.trim();
  if (params.minPrice != null) queryParameters['minPrice'] = params.minPrice;
  if (params.maxPrice != null) queryParameters['maxPrice'] = params.maxPrice;
  if (params.seats.isNotEmpty) queryParameters['seats'] = params.seats;
  if (params.branchId != null) queryParameters['branchId'] = params.branchId;

  final response = await dio.get('/api/cars', queryParameters: queryParameters);
  final data = response.data['data'] as Map<String, dynamic>;
  final content = data['content'] as List<dynamic>;
  return content.cast<Map<String, dynamic>>();
});

const _brandOptions = [
  'Tất cả',
  'Toyota',
  'VinFast',
  'Honda',
  'Mazda',
  'Hyundai',
  'Kia',
  'Mercedes',
  'BMW',
  'Ford',
  'Mitsubishi',
];

class CarListParams {
  final String brand;
  final String name;
  final String location;
  final bool onlyAvailable;
  final double? minPrice;
  final double? maxPrice;
  final List<int> seats;
  final int? branchId;

  const CarListParams({
    this.brand = '',
    this.name = '',
    this.location = '',
    this.onlyAvailable = true,
    this.minPrice,
    this.maxPrice,
    this.seats = const [],
    this.branchId,
  });

  CarListParams copyWith({
    String? brand,
    String? name,
    String? location,
    bool? onlyAvailable,
    double? minPrice,
    double? maxPrice,
    List<int>? seats,
    int? branchId,
    bool clearBranchId = false,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return CarListParams(
      brand: brand ?? this.brand,
      name: name ?? this.name,
      location: location ?? this.location,
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
      seats: seats ?? this.seats,
      branchId: clearBranchId ? null : (branchId ?? this.branchId),
    );
  }
}

String carDisplayTitle(String? brand, String? name) {
  final b = (brand ?? '').trim();
  final n = (name ?? '').trim();
  if (n.isEmpty) return b;
  if (b.isEmpty) return n;
  if (n.toLowerCase().contains(b.toLowerCase())) return n;
  return '$b $n'.trim();
}

class CarListScreen extends ConsumerStatefulWidget {
  final String? branchId;
  const CarListScreen({super.key, this.branchId});

  @override
  ConsumerState<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends ConsumerState<CarListScreen> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  String _sheetBrand = 'Tất cả';
  final _priceFormatter = NumberFormat('#,###', 'vi_VN');

  @override
  void initState() {
    super.initState();
    if (widget.branchId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(carListParamsProvider.notifier).state = CarListParams(
          branchId: int.tryParse(widget.branchId!),
        );
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _syncSheetFromParams(CarListParams params) {
    _sheetBrand = params.brand.isEmpty ? 'Tất cả' : params.brand;
    _nameController.text = params.name;
    _locationController.text = params.location;
    _minPriceController.text = params.minPrice != null
        ? _priceFormatter.format(params.minPrice!.round())
        : '';
    _maxPriceController.text = params.maxPrice != null
        ? _priceFormatter.format(params.maxPrice!.round())
        : '';
  }

  void _formatPriceField(TextEditingController controller) {
    final parsed = FormatUtils.parsePrice(controller.text);
    if (parsed == null) return;
    final formatted = _priceFormatter.format(parsed.round());
    controller.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  Future<void> _searchNearby() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng bật dịch vụ vị trí')),
          );
        }
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không có quyền truy cập vị trí')),
            );
          }
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition();
      ref.read(nearbyLocationProvider.notifier).state = (lat: pos.latitude, lng: pos.longitude);
      ref.invalidate(carListProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lấy vị trí: $e')));
      }
    }
  }

  void _clearNearby() {
    ref.read(nearbyLocationProvider.notifier).state = null;
    ref.invalidate(carListProvider);
  }

  void _toggleNearby() {
    if (ref.read(nearbyLocationProvider) != null) {
      _clearNearby();
    } else {
      _searchNearby();
    }
  }

  void _applyFilters() {
    _clearNearby();
    final brand = _sheetBrand == 'Tất cả' ? '' : _sheetBrand;
    final minPrice = FormatUtils.parsePrice(_minPriceController.text);
    final maxPrice = FormatUtils.parsePrice(_maxPriceController.text);
    ref.read(carListParamsProvider.notifier).state = ref.read(carListParamsProvider).copyWith(
      brand: brand,
      name: _nameController.text,
      location: _locationController.text,
      minPrice: minPrice,
      maxPrice: maxPrice,
      clearMinPrice: minPrice == null,
      clearMaxPrice: maxPrice == null,
    );
    ref.invalidate(carListProvider);
  }

  void _resetFilters() {
    _sheetBrand = 'Tất cả';
    _nameController.clear();
    _locationController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();
    _clearNearby();
    ref.read(carListParamsProvider.notifier).state = const CarListParams();
    ref.invalidate(carListProvider);
  }

  void _toggleSeatFilter(int seat) {
    final params = ref.read(carListParamsProvider);
    final current = List<int>.from(params.seats);
    if (current.contains(seat)) {
      current.remove(seat);
    } else {
      current.add(seat);
    }
    if (ref.read(nearbyLocationProvider) != null) {
      _clearNearby();
    }
    ref.read(carListParamsProvider.notifier).state = params.copyWith(seats: current);
    ref.invalidate(carListProvider);
  }

  void _setBranchFilter(int? branchId) {
    ref.read(carListParamsProvider.notifier).state = ref.read(carListParamsProvider).copyWith(
      branchId: branchId,
      clearBranchId: branchId == null,
    );
    ref.invalidate(carListProvider);
  }

  void _showFilterBottomSheet() {
    _syncSheetFromParams(ref.read(carListParamsProvider));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final params = ref.watch(carListParamsProvider);
          final tt = Theme.of(context).textTheme;

          return Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.page,
              AppSpacing.lg,
              AppSpacing.page,
              MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bộ lọc nâng cao', style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  DropdownButtonFormField<String>(
                    value: _brandOptions.contains(_sheetBrand) ? _sheetBrand : 'Tất cả',
                    decoration: const InputDecoration(labelText: 'Hãng xe'),
                    items: _brandOptions
                        .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                        .toList(),
                    onChanged: (value) => setState(() => _sheetBrand = value ?? 'Tất cả'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Tên xe'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _locationController,
                    decoration: const InputDecoration(labelText: 'Khu vực'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _searchNearby();
                    },
                    child: const Text('Vị trí hiện tại'),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Giá từ'),
                          onChanged: (_) => _formatPriceField(_minPriceController),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Đến'),
                          onChanged: (_) => _formatPriceField(_maxPriceController),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text('Số chỗ', style: tt.labelLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [2, 4, 5, 7].map((seat) {
                      final selected = params.seats.contains(seat);
                      return FilterChip(
                        label: Text('$seat chỗ'),
                        selected: selected,
                        showCheckmark: false,
                        onSelected: (value) {
                          final current = List<int>.from(params.seats);
                          if (value) {
                            current.add(seat);
                          } else {
                            current.remove(seat);
                          }
                          ref.read(carListParamsProvider.notifier).state = params.copyWith(seats: current);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            _resetFilters();
                            Navigator.pop(context);
                          },
                          child: const Text('Mặc định'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            _applyFilters();
                            Navigator.pop(context);
                          },
                          child: const Text('Áp dụng'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(carListProvider);
    final params = ref.watch(carListParamsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final branchesAsync = ref.watch(branchListProvider);

    final isNearbyMode = ref.watch(nearbyLocationProvider) != null;
    final hasActiveFilters = params.brand.isNotEmpty ||
        params.name.isNotEmpty ||
        params.location.isNotEmpty ||
        params.seats.isNotEmpty ||
        params.minPrice != null ||
        params.maxPrice != null ||
        params.branchId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thuê xe tự lái'),
        actions: [
          IconButton(
            onPressed: _showFilterBottomSheet,
            icon: Badge(
              isLabelVisible: hasActiveFilters,
              child: const Icon(Icons.filter_list_rounded),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.page),
              children: [
                for (final seat in [4, 5, 7])
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: FilterChip(
                      label: Text('$seat chỗ'),
                      selected: params.seats.contains(seat),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => _toggleSeatFilter(seat),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: FilterChip(
                    label: const Text('Gần tôi'),
                    selected: isNearbyMode,
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => _toggleNearby(),
                  ),
                ),
                branchesAsync.maybeWhen(
                  data: (branches) {
                    if (branches.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: params.branchId,
                          hint: const Text('Cơ sở'),
                          isDense: true,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Tất cả cơ sở'),
                            ),
                            ...branches.map(
                              (b) => DropdownMenuItem<int?>(
                                value: (b['branchId'] as num?)?.toInt(),
                                child: Text(
                                  b['name']?.toString() ?? 'Cơ sở',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: _setBranchFilter,
                        ),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          if (isNearbyMode)
            AppSurface(
              color: cs.primaryContainer.withValues(alpha: 0.08),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.page,
                vertical: AppSpacing.sm,
              ),
              child: Text(
                'Đang tìm xe trong bán kính 10 km',
                style: tt.bodySmall?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: carsAsync.when(
              data: (cars) {
                if (cars.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.directions_car_outlined, size: 64, color: cs.outlineVariant),
                          const SizedBox(height: AppSpacing.lg),
                          Text('Không tìm thấy xe nào phù hợp', style: tt.titleMedium),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Thử điều chỉnh bộ lọc hoặc tìm xe gần bạn.',
                            style: tt.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          TextButton(onPressed: _resetFilters, child: const Text('Xoá tất cả bộ lọc')),
                        ],
                      ),
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(carListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.page,
                      vertical: AppSpacing.md,
                    ),
                    itemCount: cars.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final car = cars[index];
                      final title = carDisplayTitle(
                        car['brand']?.toString(),
                        car['name']?.toString(),
                      );
                      final location = car['location']?.toString() ?? 'Chưa cập nhật';
                      final seats = car['seats']?.toString() ?? '-';
                      final priceText = FormatUtils.vndPerDay(car['pricePerDay']);

                      return FadeSlideIn(
                        delay: Duration(milliseconds: index * 40),
                        child: AppSurface(
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          onTap: () => context.push('/cars/${car['id']}'),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                                child: CachedNetworkImage(
                                  imageUrl: car['imageUrl']?.toString() ?? '',
                                  width: 112,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => ShimmerLoading(
                                    width: 112,
                                    height: 96,
                                    borderRadius: AppTheme.radiusInput,
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    width: 112,
                                    height: 96,
                                    color: cs.surfaceContainerHigh,
                                    child: Icon(
                                      Icons.directions_car_rounded,
                                      size: 36,
                                      color: cs.outlineVariant,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      location,
                                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Text(
                                      priceText,
                                      style: tt.labelLarge?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    _TextChip(label: '$seats chỗ'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
              loading: () => ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.page),
                itemCount: 4,
                itemBuilder: (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AppSurface(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Row(
                      children: [
                        ShimmerLoading(width: 112, height: 96, borderRadius: AppTheme.radiusInput),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ShimmerLoading(width: double.infinity, height: 16),
                              const SizedBox(height: AppSpacing.sm),
                              ShimmerLoading(width: 120, height: 12),
                              const SizedBox(height: AppSpacing.sm),
                              ShimmerLoading(width: 90, height: 14),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(AppSpacing.xxl),
                child: Center(
                  child: Text('Không tải được danh sách xe', textAlign: TextAlign.center, style: tt.bodyLarge),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextChip extends StatelessWidget {
  const _TextChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusInput),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }
}
