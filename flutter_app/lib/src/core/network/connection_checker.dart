import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dio_provider.dart';

final connectionStatusProvider = FutureProvider.autoDispose<bool>((ref) async {
  final dio = ref.read(rawDioProvider);
  try {
    final response = await dio.get('/actuator/health').timeout(const Duration(seconds: 5));
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
});

class ConnectionChecker {
  static Future<bool> checkConnection(Dio dio) async {
    try {
      final response = await dio.get('/actuator/health').timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
