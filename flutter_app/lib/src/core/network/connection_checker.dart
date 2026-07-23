import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dio_provider.dart';

final connectionStatusProvider = FutureProvider.autoDispose<bool>((ref) async {
  final dio = ref.read(rawDioProvider);
  try {
    final response = await dio.get('/actuator/health').timeout(const Duration(seconds: 8));
    final ok = response.statusCode == 200;
    if (kDebugMode) {
      debugPrint('[connection] baseUrl=$baseUrl status=${response.statusCode} ok=$ok');
    }
    return ok;
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[connection] baseUrl=$baseUrl FAILED: $e');
      debugPrint('$st');
    }
    return false;
  }
});

class ConnectionChecker {
  static Future<bool> checkConnection(Dio dio) async {
    try {
      final response = await dio.get('/actuator/health').timeout(const Duration(seconds: 8));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
