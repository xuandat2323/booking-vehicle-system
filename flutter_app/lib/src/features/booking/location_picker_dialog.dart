import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../core/network/dio_provider.dart';
import '../../core/network/geocoding_service.dart';
import '../../core/theme/app_theme.dart';

class PickedLocation {
  final String address;
  final double lat;
  final double lng;

  const PickedLocation({required this.address, required this.lat, required this.lng});
}

class LocationPickerDialog extends StatefulWidget {
  const LocationPickerDialog({
    super.key,
    this.title = 'Chọn địa điểm',
    this.initialLocation,
    this.accentColor,
  });

  final String title;
  final PickedLocation? initialLocation;
  final Color? accentColor;

  static Future<PickedLocation?> show(
    BuildContext context, {
    String title = 'Chọn địa điểm',
    PickedLocation? initialLocation,
    Color? accentColor,
  }) {
    return showModalBottomSheet<PickedLocation>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LocationPickerDialog(
        title: title,
        initialLocation: initialLocation,
        accentColor: accentColor,
      ),
    );
  }

  @override
  State<LocationPickerDialog> createState() => _LocationPickerDialogState();
}

class _LocationPickerDialogState extends State<LocationPickerDialog> {
  final _searchController = TextEditingController();
  final _mapController = MapController();
  final _searchFocus = FocusNode();

  LatLng? _selected;
  String _selectedAddress = '';
  bool _isGeocoding = false;
  bool _showSuggestions = false;
  List<GeocodingResult> _suggestions = [];
  Timer? _debounce;
  bool _useSatellite = false;
  bool _isLocating = false;

  static const LatLng _defaultCenter = LatLng(21.0285, 105.8542); // Hà Nội

  @override
  void initState() {
    super.initState();
    if (widget.initialLocation != null) {
      _selected = LatLng(widget.initialLocation!.lat, widget.initialLocation!.lng);
      _selectedAddress = widget.initialLocation!.address;
      _searchController.text = widget.initialLocation!.address;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLocating = true);
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
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ứng dụng cần quyền truy cập vị trí')),
          );
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final point = LatLng(pos.latitude, pos.longitude);
      _mapController.move(point, 16.0);
      setState(() {
        _selected = point;
        _isGeocoding = true;
      });
      final address = await GeocodingService.reverseGeocode(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() {
          _selectedAddress = address;
          _isGeocoding = false;
          _searchController.text = address;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể lấy vị trí hiện tại')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), () async {
      final results = await GeocodingService.search(value);
      if (mounted) {
        setState(() {
          _suggestions = results;
          _showSuggestions = results.isNotEmpty;
        });
      }
    });
  }

  Future<void> _onMapTap(TapPosition _, LatLng point) async {
    setState(() {
      _selected = point;
      _isGeocoding = true;
      _showSuggestions = false;
    });
    final address = await GeocodingService.reverseGeocode(point.latitude, point.longitude);
    if (mounted) {
      setState(() {
        _selectedAddress = address;
        _isGeocoding = false;
        _searchController.text = address;
      });
    }
  }

  Future<void> _selectSuggestion(GeocodingResult result) async {
    final LatLng point;
    final String address;

    if (result.lat == 0.0 || result.lng == 0.0) {
      if (result.refId == null || result.refId!.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể lấy tọa độ của địa điểm này')),
          );
        }
        return;
      }
      setState(() => _isGeocoding = true);
      final resolved = await GeocodingService.resolvePlace(result.refId!);
      if (mounted) setState(() => _isGeocoding = false);
      if (resolved == null || (resolved.lat == 0.0 && resolved.lng == 0.0)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể lấy tọa độ của địa điểm này')),
          );
        }
        return;
      }
      point = LatLng(resolved.lat, resolved.lng);
      address = resolved.address.isNotEmpty ? resolved.address : result.address;
    } else {
      point = LatLng(result.lat, result.lng);
      address = result.address;
    }

    setState(() {
      _selected = point;
      _selectedAddress = address;
      _searchController.text = address;
      _showSuggestions = false;
      _suggestions = [];
    });
    _searchFocus.unfocus();
    _mapController.move(point, 15.0);
  }

  void _confirm() {
    if (_selected == null) return;
    Navigator.of(context).pop(PickedLocation(
      address: _selectedAddress,
      lat: _selected!.latitude,
      lng: _selected!.longitude,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = widget.accentColor ?? cs.primary;

    return DraggableScrollableSheet(
      initialChildSize: 0.95,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Title
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  onChanged: _onSearchChanged,
                  onTap: () => setState(() => _showSuggestions = _suggestions.isNotEmpty),
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm địa điểm...',
                    prefixIcon: Icon(Icons.search_rounded, color: accent),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _suggestions = [];
                                _showSuggestions = false;
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: cs.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              // Suggestions
              if (_showSuggestions && _suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [AppTheme.softShadow],
                  ),
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _suggestions.length,
                    itemBuilder: (_, i) {
                      final s = _suggestions[i];
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.location_on_outlined, color: accent, size: 20),
                        title: Text(s.address, maxLines: 2, overflow: TextOverflow.ellipsis, style: tt.bodyMedium),
                        onTap: () => _selectSuggestion(s),
                      );
                    },
                  ),
                ),

              // Map
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _selected ?? _defaultCenter,
                        initialZoom: _selected != null ? 15.0 : 12.0,
                        onTap: _onMapTap,
                      ),
                      children: [
                        TileLayer(
                          // Carto Voyager — free for light use, avoids OSM public-tile policy warning.
                          urlTemplate:
                              'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c', 'd'],
                          userAgentPackageName: 'com.gorento.app',
                          maxZoom: 19,
                        ),
                        if (goongMapKey.isNotEmpty && _useSatellite)
                          TileLayer(
                            urlTemplate:
                                'https://maps.goong.io/tiles/satellite/{z}/{x}/{y}.png?api_key=$goongMapKey',
                            userAgentPackageName: 'com.gorento.app',
                          ),
                        if (_selected != null)
                          MarkerLayer(markers: [
                            Marker(
                              point: _selected!,
                              width: 48,
                              height: 48,
                              child: Icon(Icons.location_on_rounded, color: accent, size: 44),
                            ),
                          ]),
                      ],
                    ),
                    Positioned(
                      top: 12,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: cs.inverseSurface.withValues(alpha: 0.88),
                          borderRadius: BorderRadius.circular(AppTheme.radiusInput),
                        ),
                        child: Row(
                          children: [
                            if (_isGeocoding) ...[
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: cs.onInverseSurface),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Đang lấy địa chỉ...',
                                  style: tt.labelMedium?.copyWith(color: cs.onInverseSurface),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ] else ...[
                              Icon(Icons.touch_app_rounded, color: cs.onInverseSurface, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Chạm bản đồ để ghim · hoặc tìm kiếm phía trên',
                                  style: tt.labelMedium?.copyWith(color: cs.onInverseSurface),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                      Positioned(
                        bottom: 72,
                        right: 16,
                        child: FloatingActionButton.small(
                          heroTag: 'my_location',
                          backgroundColor: cs.surfaceContainerLowest,
                          foregroundColor: cs.primary,
                          onPressed: _isLocating ? null : _getCurrentLocation,
                          child: _isLocating
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
                                )
                              : const Icon(Icons.my_location_rounded),
                        ),
                      ),
                      if (goongMapKey.isNotEmpty)
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton.small(
                            heroTag: 'map_style_toggle',
                            backgroundColor: cs.surfaceContainerLowest,
                            foregroundColor: cs.primary,
                            onPressed: () => setState(() => _useSatellite = !_useSatellite),
                            child: Icon(_useSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded),
                          ),
                        ),
                    ],
                  ),
                ),

              // Bottom confirm
              Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLowest,
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -6))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_selected != null) ...[
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: accent, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _selectedAddress,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    GradientButton(
                      onPressed: _selected == null ? null : _confirm,
                      child: Text(
                        _selected == null ? 'Chọn vị trí trên bản đồ' : 'Xác nhận vị trí',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
