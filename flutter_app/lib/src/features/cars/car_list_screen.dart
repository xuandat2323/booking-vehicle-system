import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

final carListParamsProvider = StateProvider<CarListParams>((ref) => const CarListParams());

// null = normal mode, non-null = nearby mode with (lat, lng)
final nearbyLocationProvider = StateProvider<({double lat, double lng})?> ((ref) => null);

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
  }) {
    return CarListParams(
      brand: brand ?? this.brand,
      name: name ?? this.name,
      location: location ?? this.location,
      onlyAvailable: onlyAvailable ?? this.onlyAvailable,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      seats: seats ?? this.seats,
      branchId: branchId ?? this.branchId,
    );
  }
}

class CarListScreen extends ConsumerStatefulWidget {
  final String? branchId;
  const CarListScreen({super.key, this.branchId});

  @override
  ConsumerState<CarListScreen> createState() => _CarListScreenState();
}

class _CarListScreenState extends ConsumerState<CarListScreen> {
  final _brandController = TextEditingController();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

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
    _brandController.dispose();
    _nameController.dispose();
    _locationController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _searchNearby() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Vui lòng bật dịch vụ vị trí')),
          );
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
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

  void _applyFilters() {
    final minPrice = double.tryParse(_minPriceController.text.trim());
    final maxPrice = double.tryParse(_maxPriceController.text.trim());
    ref.read(carListParamsProvider.notifier).state = CarListParams(
      brand: _brandController.text,
      name: _nameController.text,
      location: _locationController.text,
      minPrice: minPrice,
      maxPrice: maxPrice,
    );
    ref.invalidate(carListProvider);
  }

  void _resetFilters() {
    _brandController.clear();
    _nameController.clear();
    _locationController.clear();
    _minPriceController.clear();
    _maxPriceController.clear();
    ref.read(carListParamsProvider.notifier).state = const CarListParams();
    ref.invalidate(carListProvider);
  }

  @override
  Widget build(BuildContext context) {
    final carsAsync = ref.watch(carListProvider);
    final params = ref.watch(carListParamsProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    _brandController.text = params.brand;
    _nameController.text = params.name;
    _locationController.text = params.location;
    _minPriceController.text = params.minPrice?.toString() ?? '';
    _maxPriceController.text = params.maxPrice?.toString() ?? '';

    final isNearbyMode = ref.watch(nearbyLocationProvider) != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thuê xe tự lái'),
        actions: [
          if (isNearbyMode)
            TextButton.icon(
              onPressed: _clearNearby,
              icon: const Icon(Icons.location_off_rounded, size: 18),
              label: const Text('Xoá vị trí'),
              style: TextButton.styleFrom(foregroundColor: cs.error),
            )
          else
            IconButton(
              onPressed: _searchNearby,
              icon: const Icon(Icons.my_location_rounded),
              tooltip: 'Tìm xe gần tôi (10 km)',
            ),
        ],
      ),
      body: Column(
        children: [
          // ─── Filter Bar ───
          if (isNearbyMode)
            Container(
              width: double.infinity,
              color: cs.primaryContainer.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: cs.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Đang tìm xe trong bán kính 10 km',
                      style: tt.bodyMedium?.copyWith(color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                  GestureDetector(
                    onTap: _clearNearby,
                    child: Icon(Icons.close_rounded, color: cs.primary, size: 20),
                  ),
                ],
              ),
            ),
          
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              title: Text('Bộ lọc nâng cao', style: tt.titleMedium),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              children: [
                TextField(controller: _brandController, decoration: const InputDecoration(labelText: 'Hãng xe')),
                const SizedBox(height: 12),
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Tên xe')),
                const SizedBox(height: 12),
                TextField(controller: _locationController, decoration: const InputDecoration(labelText: 'Khu vực')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: _minPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giá từ'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: _maxPriceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Đến'))),
                  ],
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Số chỗ', style: tt.labelLarge),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [2, 4, 5, 7].map((seat) {
                    final params = ref.watch(carListParamsProvider);
                    final selected = params.seats.contains(seat);
                    return FilterChip(
                      label: Text('$seat chỗ'),
                      selected: selected,
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
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _resetFilters,
                        child: const Text('Mặc định'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: _applyFilters,
                        child: const Text('Tìm xe'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.2)),

          // ─── Car List ───
          Expanded(
            child: carsAsync.when(
              data: (cars) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(carListProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                  itemCount: cars.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 28),
                  itemBuilder: (context, index) {
                    final car = cars[index];
                    final priceStr = car['pricePerDay']?.toString() ?? '0';
                    final location = car['location']?.toString() ?? 'Chưa có vị trí cập nhật';
                    final seats = car['seats']?.toString() ?? '-';
                    final transmission = car['transmission']?.toString() ?? 'Khác';
                    
                    // Format price: e.g. 650000 -> 650k
                    int? priceInt = int.tryParse(priceStr.split('.').first);
                    String formattedPrice = priceStr;
                    if (priceInt != null && priceInt >= 1000) {
                      formattedPrice = '${priceInt ~/ 1000}k';
                    }

                    return Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        boxShadow: [AppTheme.softShadow],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push('/cars/${car['id']}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Car image (Cloudinary URL or placeholder)
                            Builder(builder: (_) {
                              final imageUrl = car['imageUrl']?.toString();
                              if (imageUrl != null && imageUrl.isNotEmpty) {
                                return Image.network(
                                  imageUrl,
                                  height: 180,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    height: 180,
                                    color: cs.surfaceContainerHigh,
                                    child: Center(child: Icon(Icons.directions_car_rounded, size: 64, color: cs.outlineVariant)),
                                  ),
                                  loadingBuilder: (_, child, progress) => progress == null
                                      ? child
                                      : Container(
                                          height: 180,
                                          color: cs.surfaceContainerHigh,
                                          child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: cs.outlineVariant)),
                                        ),
                                );
                              }
                              return Container(
                                height: 180,
                                color: cs.surfaceContainerHigh,
                                child: Center(child: Icon(Icons.directions_car_rounded, size: 64, color: cs.outlineVariant)),
                              );
                            }),
                            
                            // Content
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${car['brand'] ?? ''} ${car['name'] ?? ''}',
                                              style: tt.headlineSmall?.copyWith(fontSize: 20),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.location_on_rounded, size: 14, color: cs.outline),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    location,
                                                    style: tt.bodyMedium,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Price
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            formattedPrice,
                                            style: tt.titleLarge?.copyWith(color: cs.primary),
                                          ),
                                          Text('/ngày', style: tt.labelMedium),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Spec tags
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _SpecTag(icon: Icons.airline_seat_recline_normal_rounded, label: '$seats chỗ'),
                                      _SpecTag(icon: Icons.settings_rounded, label: transmission),
                                      _SpecTag(icon: Icons.star_rounded, label: '${car['averageRating'] ?? 'Mới'}', color: Colors.orange.shade700),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Không tải được danh sách xe\n$e', textAlign: TextAlign.center)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecTag extends StatelessWidget {
  const _SpecTag({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fgColor = color ?? cs.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fgColor)),
        ],
      ),
    );
  }
}
