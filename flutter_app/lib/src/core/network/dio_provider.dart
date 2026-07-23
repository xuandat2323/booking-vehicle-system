import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_provider.dart';
import '../storage/secure_storage_provider.dart';

const _definedBaseUrl = String.fromEnvironment('BASE_URL');

final String baseUrl = () {
  if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
  if (kIsWeb) return 'http://localhost:8080';
  if (kDebugMode) {
    return defaultTargetPlatform == TargetPlatform.android
        ? 'http://10.0.2.2:8080'
        : 'http://localhost:8080';
  }
  return 'http://localhost:8080';
}();

const accessTokenKey = 'access_token';
const refreshTokenKey = 'refresh_token';

const goongMapKey = String.fromEnvironment('GOONG_MAP_KEY');
const goongApiKey = String.fromEnvironment('GOONG_API_KEY');

Map<String, String> _defaultHeaders() => {
      'Accept': 'application/json',
      if (baseUrl.contains('ngrok')) 'ngrok-skip-browser-warning': 'true',
    };

final rawDioProvider = Provider<Dio>((ref) {
  return Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: _defaultHeaders(),
    contentType: Headers.jsonContentType,
  ));
});

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.read(secureStorageProvider);
  final authController = ref.read(authControllerProvider);
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: _defaultHeaders(),
    contentType: Headers.jsonContentType,
  ));

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.read(key: accessTokenKey);
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        // Let Dio set multipart boundary — forced JSON Content-Type breaks eKYC uploads.
        if (options.data is FormData) {
          options.headers.remove(Headers.contentTypeHeader);
          options.contentType = null;
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final is401 = error.response?.statusCode == 401;
        final alreadyRetried = error.requestOptions.extra['retried'] == true;
        if (!is401 || alreadyRetried) {
          return handler.next(error);
        }

        try {
          await authController.refreshIfNeeded();
          final newToken = await storage.read(key: accessTokenKey);
          if (newToken == null || newToken.isEmpty) {
            await authController.logout();
            return handler.next(error);
          }

          final requestOptions = error.requestOptions;
          requestOptions.extra['retried'] = true;
          requestOptions.headers['Authorization'] = 'Bearer $newToken';

          final response = await dio.fetch(requestOptions);
          return handler.resolve(response);
        } catch (_) {
          await authController.logout();
          return handler.next(error);
        }
      },
    ),
  );

  return dio;
});
