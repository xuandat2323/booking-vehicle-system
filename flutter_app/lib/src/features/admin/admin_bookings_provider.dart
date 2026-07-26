import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';

final adminBookingsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, statusFilter) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get(
    '/api/admin/bookings',
    queryParameters: {'page': 0, 'size': 50},
  );
  final data = response.data['data'] as Map<String, dynamic>;
  final all =
      (data['content'] as List<dynamic>).cast<Map<String, dynamic>>();
  if (statusFilter.isEmpty) return all;
  final wanted = statusFilter == 'IN_PROGRESS' ? 'RENTING' : statusFilter;
  return all.where((b) {
    final s = b['status']?.toString() ?? '';
    if (wanted == 'RENTING') return s == 'RENTING' || s == 'IN_PROGRESS';
    return s == wanted;
  }).toList();
});
