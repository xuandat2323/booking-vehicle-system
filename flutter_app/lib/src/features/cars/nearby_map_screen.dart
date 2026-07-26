import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/format_utils.dart';
import 'car_list_screen.dart';

/// Bản đồ hiển thị các xe quanh vị trí người dùng, dùng chung dữ liệu với
/// chế độ "Gần tôi" của màn danh sách xe.
class NearbyMapScreen extends ConsumerStatefulWidget {
  const NearbyMapScreen({super.key});

  @override
  ConsumerState<NearbyMapScreen> createState() => _NearbyMapScreenState();
}

class _NearbyMapScreenState extends ConsumerState<NearbyMapScreen> {
  final _mapController = MapController();
  Map<String, dynamic>? _selectedCar;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  /// Zoom sao cho vòng tròn bán kính vừa khung nhìn.
  double _zoomForRadius(double radiusKm) =>
      (14.5 - math.log(radiusKm) / math.ln2).clamp(8.0, 15.0);

  void _setRadius(double radiusKm, LatLng center) {
    if (ref.read(nearbyRadiusProvider) == radiusKm) return;
    ref.read(nearbyRadiusProvider.notifier).state = radiusKm;
    ref.invalidate(carListProvider);
    setState(() => _selectedCar = null);
    _mapController.move(center, _zoomForRadius(radiusKm));
  }

  static String _formatKm(double value) =>
      value == value.roundToDouble() ? value.toInt().toString() : value.toString();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final location = ref.watch(nearbyLocationProvider);
    final radiusKm = ref.watch(nearbyRadiusProvider);

    if (location == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Xe gần bạn')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xxl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.location_off_rounded, size: 64, color: cs.outlineVariant),
                const SizedBox(height: AppSpacing.lg),
                Text('Chưa xác định được vị trí của bạn', style: tt.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Hãy bật chế độ "Gần tôi" ở danh sách xe để lấy vị trí.',
                  style: tt.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    final center = LatLng(location.lat, location.lng);
    final carsAsync = ref.watch(carListProvider);
    final cars = carsAsync.valueOrNull ?? const <Map<String, dynamic>>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xe gần bạn'),
        actions: [
          IconButton(
            tooltip: 'Về vị trí của tôi',
            onPressed: () => _mapController.move(center, _zoomForRadius(radiusKm)),
            icon: const Icon(Icons.my_location_rounded),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: _zoomForRadius(radiusKm),
              onTap: (tapPosition, point) => setState(() => _selectedCar = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.gorento.app',
              ),
              CircleLayer(
                circles: [
                  CircleMarker(
                    point: center,
                    radius: radiusKm * 1000,
                    useRadiusInMeter: true,
                    color: cs.primary.withValues(alpha: 0.08),
                    borderColor: cs.primary.withValues(alpha: 0.4),
                    borderStrokeWidth: 2,
                  ),
                ],
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (final car in cars)
                    if (_carLatLng(car) != null)
                      Marker(
                        point: _carLatLng(car)!,
                        width: 112,
                        height: 56,
                        alignment: Alignment.bottomCenter,
                        child: _CarMarker(
                          label: _markerLabel(car),
                          selected: car['id'] == _selectedCar?['id'],
                          onTap: () => setState(() => _selectedCar = car),
                        ),
                      ),
                ],
              ),
            ],
          ),
          Positioned(
            top: AppSpacing.md,
            left: 0,
            right: 0,
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  for (final option in nearbyRadiusOptions)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        label: Text('${_formatKm(option)} km'),
                        selected: radiusKm == option,
                        showCheckmark: false,
                        visualDensity: VisualDensity.compact,
                        backgroundColor: cs.surfaceContainerLowest,
                        onSelected: (_) => _setRadius(option, center),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: AppSpacing.md,
            child: SafeArea(
              top: false,
              child: _selectedCar != null
                  ? _SelectedCarCard(
                      car: _selectedCar!,
                      onClose: () => setState(() => _selectedCar = null),
                      onOpen: () => context.push('/cars/${_selectedCar!['id']}'),
                    )
                  : _SummaryBar(
                      loading: carsAsync.isLoading,
                      count: cars.length,
                      radiusLabel: _formatKm(radiusKm),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  LatLng? _carLatLng(Map<String, dynamic> car) {
    final lat = (car['latitude'] as num?)?.toDouble();
    final lng = (car['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  String _markerLabel(Map<String, dynamic> car) {
    final distance = (car['distanceKm'] as num?)?.toDouble();
    if (distance != null) return '${_formatKm(distance)} km';
    return car['brand']?.toString() ?? 'Xe';
  }
}

class _CarMarker extends StatelessWidget {
  const _CarMarker({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 112,
        height: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: selected ? cs.primary : cs.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                border: Border.all(color: cs.primary, width: selected ? 0 : 1.5),
                boxShadow: [AppTheme.softShadow],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_car_rounded,
                    size: 14,
                    color: selected ? cs.onPrimary : cs.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelSmall?.copyWith(
                        color: selected ? cs.onPrimary : cs.primary,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_drop_down_rounded,
              size: 16,
              color: selected ? cs.primary : cs.outline,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({
    required this.loading,
    required this.count,
    required this.radiusLabel,
  });

  final bool loading;
  final int count;
  final String radiusLabel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [AppTheme.softShadow],
      ),
      child: Row(
        children: [
          Icon(Icons.place_rounded, color: cs.primary, size: 20),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              loading
                  ? 'Đang tìm xe quanh bạn…'
                  : 'Có $count xe trong bán kính $radiusLabel km. Chạm vào điểm trên bản đồ để xem xe.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedCarCard extends StatelessWidget {
  const _SelectedCarCard({
    required this.car,
    required this.onClose,
    required this.onOpen,
  });

  final Map<String, dynamic> car;
  final VoidCallback onClose;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final title = carDisplayTitle(car['brand']?.toString(), car['name']?.toString());
    final distance = (car['distanceKm'] as num?)?.toDouble();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [AppTheme.softShadow],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusInput),
            child: CachedNetworkImage(
              imageUrl: car['imageUrl']?.toString() ?? '',
              width: 88,
              height: 76,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) => Container(
                width: 88,
                height: 76,
                color: cs.surfaceContainerHigh,
                child: Icon(Icons.directions_car_rounded, color: cs.outlineVariant),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  distance != null
                      ? 'Cách bạn ${distance.toStringAsFixed(1)} km'
                      : (car['location']?.toString() ?? 'Chưa cập nhật vị trí'),
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        FormatUtils.vndPerDay(car['pricePerDay']),
                        style: tt.labelLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton(
                      onPressed: onOpen,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Xem xe'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}
