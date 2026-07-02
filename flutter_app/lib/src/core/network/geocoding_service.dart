import 'package:dio/dio.dart';

import 'dio_provider.dart';

class GeocodingResult {
  final String address;
  final double lat;
  final double lng;
  final String? refId;

  const GeocodingResult({
    required this.address,
    required this.lat,
    required this.lng,
    this.refId,
  });
}

class GeocodingService {
  // All geo calls proxy through the backend → no CORS, no token exposure.
  static final _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  /// Reverse geocode lat/lng → human-readable address string.
  static Future<String> reverseGeocode(double lat, double lng) async {
    try {
      final resp = await _dio.get(
        '/api/geo/reverse',
        queryParameters: {'lat': lat, 'lng': lng},
      );
      final data = resp.data;
      if (data is Map) {
        // Mapbox returns {display_name: "..."}
        return data['display_name']?.toString() ??
            '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
  }

  /// Search by text → suggestions with coordinates included.
  /// Backend flattens Mapbox GeoJSON to [{place_name, lat, lon, id}].
  static Future<List<GeocodingResult>> search(String query) async {
    if (query.trim().isEmpty) return [];
    try {
      final resp = await _dio.get(
        '/api/geo/search',
        queryParameters: {'text': query.trim()},
      );
      final data = resp.data as List<dynamic>;
      return data.map((item) {
        final lat = (item['lat'] as num?)?.toDouble() ?? 0.0;
        final lng = (item['lon'] as num?)?.toDouble() ?? 0.0;
        return GeocodingResult(
          address: item['place_name']?.toString() ?? '',
          lat: lat,
          lng: lng,
          refId: item['id']?.toString(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<GeocodingResult?> resolvePlace(String placeId) async {
    try {
      final resp = await _dio.get('/api/geo/place', queryParameters: {'placeId': placeId});
      final data = resp.data;
      if (data is Map && data['lat'] != null && data['lon'] != null) {
        return GeocodingResult(
          address: data['place_name']?.toString() ?? '',
          lat: (data['lat'] as num).toDouble(),
          lng: (data['lon'] as num).toDouble(),
          refId: placeId,
        );
      }
    } catch (_) {}
    return null;
  }
}
