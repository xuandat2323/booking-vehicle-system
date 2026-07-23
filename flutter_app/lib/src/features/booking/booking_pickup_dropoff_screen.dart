import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/dio_provider.dart';
import '../../core/network/geocoding_service.dart';
import '../../core/theme/app_theme.dart';
import 'location_picker_dialog.dart';

class BookingPickupDropoffScreen extends ConsumerStatefulWidget {
  const BookingPickupDropoffScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingPickupDropoffScreen> createState() => _BookingPickupDropoffScreenState();
}

class _BookingPickupDropoffScreenState extends ConsumerState<BookingPickupDropoffScreen> {
  final _pickupController = TextEditingController();
  final _dropoffController = TextEditingController();
  
  LatLng? _pickupLatLng;
  LatLng? _dropoffLatLng;
  
  bool _isPickupTab = true; // true: Pickup, false: Dropoff
  bool _loadingData = true;
  bool _saving = false;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocations();
  }

  @override
  void dispose() {
    _pickupController.dispose();
    _dropoffController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchCurrentLocations() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/bookings/${widget.bookingId}');
      final booking = response.data['data'] as Map<String, dynamic>;

      if (mounted) {
        setState(() {
          _pickupController.text = booking['pickupAddress']?.toString() ?? '';
          _dropoffController.text = booking['dropoffAddress']?.toString() ?? '';

          final pLat = double.tryParse(booking['pickupLatitude']?.toString() ?? '');
          final pLng = double.tryParse(booking['pickupLongitude']?.toString() ?? '');
          if (pLat != null && pLng != null) {
            _pickupLatLng = LatLng(pLat, pLng);
          }

          final dLat = double.tryParse(booking['dropoffLatitude']?.toString() ?? '');
          final dLng = double.tryParse(booking['dropoffLongitude']?.toString() ?? '');
          if (dLat != null && dLng != null) {
            _dropoffLatLng = LatLng(dLat, dLng);
          }

          _loadingData = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final center = _pickupLatLng ?? _dropoffLatLng ?? const LatLng(21.0285, 105.8542);
          _mapController.move(center, 14.5);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loadingData = false);
      }
    }
  }

  Future<void> _save() async {
    if (_pickupLatLng == null && _dropoffLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chạm ghim vị trí trên bản đồ')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      
      if (_pickupLatLng != null) {
        final address = _pickupController.text.trim();
        await dio.put(
          '/api/bookings/${widget.bookingId}/pickup-location',
          data: {
            'address': address,
            'latitude': _pickupLatLng!.latitude,
            'longitude': _pickupLatLng!.longitude,
          },
        );
      }

      if (_dropoffLatLng != null) {
        final address = _dropoffController.text.trim();
        await dio.put(
          '/api/bookings/${widget.bookingId}/dropoff-location',
          data: {
            'address': address,
            'latitude': _dropoffLatLng!.latitude,
            'longitude': _dropoffLatLng!.longitude,
          },
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cập nhật địa điểm đón/trả thành công')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu vị trí: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _onMapTap(TapPosition tapPosition, LatLng point) async {
    setState(() {
      if (_isPickupTab) {
        _pickupLatLng = point;
        _pickupController.text = 'Đang lấy địa chỉ...';
      } else {
        _dropoffLatLng = point;
        _dropoffController.text = 'Đang lấy địa chỉ...';
      }
    });
    final address = await GeocodingService.reverseGeocode(point.latitude, point.longitude);
    if (!mounted) return;
    setState(() {
      if (_isPickupTab) {
        _pickupController.text = address;
      } else {
        _dropoffController.text = address;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final markers = <Marker>[];
    if (_pickupLatLng != null) {
      markers.add(
        Marker(
          point: _pickupLatLng!,
          width: 50,
          height: 50,
          child: Icon(Icons.location_on_rounded, color: cs.secondaryContainer, size: 48),
        ),
      );
    }
    if (_dropoffLatLng != null) {
      markers.add(
        Marker(
          point: _dropoffLatLng!,
          width: 50,
          height: 50,
          child: Icon(Icons.flag_rounded, color: cs.tertiaryContainer, size: 48),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thiết lập điểm đón/trả'),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // ─── Custom Tab Bar ───
                Container(
                  color: cs.surfaceContainerLowest,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPickupTab = true),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _isPickupTab ? cs.surfaceContainerLowest : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                boxShadow: _isPickupTab
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Điểm đón',
                                  style: tt.labelLarge?.copyWith(
                                    color: _isPickupTab ? cs.secondaryContainer : cs.onSurfaceVariant,
                                    fontWeight: _isPickupTab ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isPickupTab = false),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: !_isPickupTab ? cs.surfaceContainerLowest : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                                boxShadow: !_isPickupTab
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  'Điểm trả',
                                  style: tt.labelLarge?.copyWith(
                                    color: !_isPickupTab ? cs.tertiaryContainer : cs.onSurfaceVariant,
                                    fontWeight: !_isPickupTab ? FontWeight.w700 : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // ─── Map Area ───
                Expanded(
                  flex: 12,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _pickupLatLng ?? _dropoffLatLng ?? const LatLng(21.0285, 105.8542),
                          initialZoom: 14.5,
                          onTap: _onMapTap,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                            subdomains: const ['a', 'b', 'c', 'd'],
                            userAgentPackageName: 'com.gorento.app',
                          ),
                          MarkerLayer(markers: markers),
                        ],
                      ),
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: cs.inverseSurface.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                            boxShadow: [AppTheme.softShadow],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.touch_app_rounded, color: cs.onInverseSurface, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Chạm trên bản đồ để ghim vị trí',
                                style: tt.labelMedium?.copyWith(color: cs.onInverseSurface),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // ─── Control Form ───
                Container(
                  padding: const EdgeInsets.all(24),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _isPickupTab ? 'Địa chỉ đón xe' : 'Địa chỉ trả xe',
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: _isPickupTab ? cs.secondaryContainer : cs.tertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _isPickupTab ? _pickupController : _dropoffController,
                        decoration: InputDecoration(
                          labelText: 'Nhập địa chỉ chi tiết',
                          hintText: 'Tòa nhà, số nhà, ngõ...',
                          prefixIcon: Icon(
                            _isPickupTab ? Icons.my_location_rounded : Icons.flag_rounded,
                            color: _isPickupTab ? cs.secondaryContainer : cs.tertiaryContainer,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.map_rounded),
                            tooltip: 'Chọn địa điểm nâng cao',
                            onPressed: () async {
                              final currentLatLng = _isPickupTab ? _pickupLatLng : _dropoffLatLng;
                              final currentAddress = _isPickupTab ? _pickupController.text : _dropoffController.text;
                              final res = await LocationPickerDialog.show(
                                context,
                                title: _isPickupTab ? 'Chọn điểm đón' : 'Chọn điểm trả',
                                initialLocation: currentLatLng != null
                                    ? PickedLocation(
                                        address: currentAddress,
                                        lat: currentLatLng.latitude,
                                        lng: currentLatLng.longitude,
                                      )
                                    : null,
                                accentColor: _isPickupTab ? cs.secondaryContainer : cs.tertiaryContainer,
                              );
                              if (res != null) {
                                setState(() {
                                  if (_isPickupTab) {
                                    _pickupLatLng = LatLng(res.lat, res.lng);
                                    _pickupController.text = res.address;
                                    _mapController.move(_pickupLatLng!, 15.0);
                                  } else {
                                    _dropoffLatLng = LatLng(res.lat, res.lng);
                                    _dropoffController.text = res.address;
                                    _mapController.move(_dropoffLatLng!, 15.0);
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.gps_fixed_rounded, size: 16, color: cs.outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isPickupTab
                                  ? (_pickupLatLng != null
                                      ? 'Tọa độ: ${_pickupLatLng!.latitude.toStringAsFixed(6)}, ${_pickupLatLng!.longitude.toStringAsFixed(6)}'
                                      : 'Chưa chọn tọa độ trên bản đồ')
                                  : (_dropoffLatLng != null
                                      ? 'Tọa độ: ${_dropoffLatLng!.latitude.toStringAsFixed(6)}, ${_dropoffLatLng!.longitude.toStringAsFixed(6)}'
                                      : 'Chưa chọn tọa độ trên bản đồ'),
                              style: tt.bodySmall,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      GradientButton(
                        onPressed: _saving ? null : _save,
                        isLoading: _saving,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Lưu thông tin vị trí', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
