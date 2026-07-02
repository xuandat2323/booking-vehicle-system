import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/dio_provider.dart';
import 'auth_tokens.dart';

class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<AuthTokens> login({required String phone, required String password}) async {
    final data = await _postAuth('/api/auth/login', {'phone': phone, 'password': password});
    return _toTokens(data);
  }

  Future<AuthTokens> register({required String phone, required String password, required String otp}) async {
    final data = await _postAuth('/api/auth/register', {'phone': phone, 'password': password, 'otp': otp});
    return _toTokens(data);
  }

  Future<void> sendOtp({required String phone}) async {
    await _dio.post('/api/auth/phone/send-otp', data: {'phone': phone});
  }

  Future<void> forgotPassword({required String email}) async {
    await _dio.post('/api/auth/forgot-password', data: {'email': email});
  }

  Future<void> resetPassword({required String email, required String otp, required String newPassword}) async {
    await _dio.post('/api/auth/reset-password', data: {'email': email, 'otp': otp, 'newPassword': newPassword});
  }

  Future<AuthTokens> refresh({required String refreshToken}) async {
    final data = await _postAuth('/api/auth/refresh', {'refreshToken': refreshToken});
    return _toTokens(data);
  }

  Future<void> saveTokens(AuthTokens tokens) async {
    await _storage.write(key: accessTokenKey, value: tokens.accessToken);
    await _storage.write(key: refreshTokenKey, value: tokens.refreshToken);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: accessTokenKey);
    await _storage.delete(key: refreshTokenKey);
  }

  Future<String?> readRefreshToken() => _storage.read(key: refreshTokenKey);

  Future<Map<String, dynamic>> _postAuth(String path, Map<String, dynamic> body) async {
    final response = await _dio.post(path, data: body);
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final payload = data['data'];
      if (payload is Map<String, dynamic>) return payload;
    }
    throw DioException(
      requestOptions: response.requestOptions,
      error: 'Unexpected auth response format',
      type: DioExceptionType.badResponse,
    );
  }

  AuthTokens _toTokens(Map<String, dynamic> data) {
    return AuthTokens(
      accessToken: (data['token'] ?? data['accessToken']) as String,
      refreshToken: data['refreshToken'] as String,
    );
  }
}
