import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

final carTrackingHistoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, carId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/cars/$carId/tracking/history');
  final data = response.data['data'] as List<dynamic>;
  return data.cast<Map<String, dynamic>>();
});

class CarTrackingScreen extends ConsumerWidget {
  const CarTrackingScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(carTrackingHistoryProvider(carId));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Định vị xe trực tuyến')),
      body: historyAsync.when(
        data: (history) {
          if (history.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_off_rounded, size: 64, color: cs.outlineVariant),
                  const SizedBox(height: 16),
                  Text('Chưa có dữ liệu định vị cho xe này', style: tt.titleMedium),
                ],
              ),
            );
          }

          final pointsList = history.map((item) {
            final lat = double.tryParse(item['latitude']?.toString() ?? '0') ?? 0.0;
            final lng = double.tryParse(item['longitude']?.toString() ?? '0') ?? 0.0;
            return LatLng(lat, lng);
          }).where((p) => p.latitude != 0.0 && p.longitude != 0.0).toList();

          final currentItem = history.firstWhere(
            (item) => item['current'] == true,
            orElse: () => history.first,
          );
          final currentLat = double.tryParse(currentItem['latitude']?.toString() ?? '0') ?? 21.0285;
          final currentLng = double.tryParse(currentItem['longitude']?.toString() ?? '0') ?? 105.8542;
          final currentLatLng = LatLng(currentLat, currentLng);

          final markers = <Marker>[];
          // Current location marker
          markers.add(
            Marker(
              point: currentLatLng,
              width: 60,
              height: 60,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Icon(Icons.directions_car_rounded, color: cs.primary, size: 32),
                ],
              ),
            ),
          );

          // History points
          for (var i = 1; i < pointsList.length; i++) {
            markers.add(
              Marker(
                point: pointsList[i],
                width: 16,
                height: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.secondaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                flex: 12,
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: currentLatLng,
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.gorento.app',
                        ),
                        if (pointsList.length > 1)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: pointsList,
                                color: cs.primary.withValues(alpha: 0.8),
                                strokeWidth: 5,
                              ),
                            ],
                          ),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          shape: BoxShape.circle,
                          boxShadow: [AppTheme.softShadow],
                        ),
                        child: IconButton(
                          icon: Icon(Icons.refresh_rounded, color: cs.primary),
                          onPressed: () => ref.invalidate(carTrackingHistoryProvider(carId)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 9,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, color: cs.primary),
                            const SizedBox(width: 8),
                            Text(
                              'Lịch sử di chuyển',
                              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: history.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = history[index];
                            final isCurrent = item['current'] == true;
                            
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isCurrent ? cs.primaryContainer.withValues(alpha: 0.3) : cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                border: isCurrent ? Border.all(color: cs.primary.withValues(alpha: 0.5)) : null,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: isCurrent ? cs.primary : cs.surfaceContainerHighest,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      isCurrent ? Icons.my_location_rounded : Icons.location_on_rounded,
                                      color: isCurrent ? cs.onPrimary : cs.onSurfaceVariant,
                                      size: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['address']?.toString() ?? 'Không có địa chỉ',
                                          style: tt.titleMedium?.copyWith(
                                            fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                                            color: isCurrent ? cs.primary : cs.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.schedule_rounded, size: 14, color: cs.outline),
                                            const SizedBox(width: 4),
                                            Text(
                                              item['updatedAt'] ?? '-',
                                              style: tt.bodySmall?.copyWith(color: cs.outline),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Row(
                                          children: [
                                            Icon(Icons.gps_fixed_rounded, size: 14, color: cs.outline),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${item['latitude'] ?? '-'}, ${item['longitude'] ?? '-'}',
                                              style: tt.labelSmall?.copyWith(color: cs.outline),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isCurrent)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: cs.primary,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                      ),
                                      child: Text(
                                        'Hiện tại',
                                        style: tt.labelSmall?.copyWith(color: cs.onPrimary, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: cs.error, size: 48),
              const SizedBox(height: 16),
              Text('Không tải được lịch sử tracking', style: tt.titleMedium),
              const SizedBox(height: 8),
              Text(e.toString(), style: tt.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
