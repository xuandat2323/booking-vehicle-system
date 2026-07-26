import 'package:flutter/foundation.dart';

import 'auth_repository.dart';
import 'firebase_phone_service.dart';

class AuthController extends ChangeNotifier {
  AuthController(this._repo) {
    _restore();
  }

  final AuthRepository _repo;

  bool _isAuthenticated = false;
  bool get isAuthenticated => _isAuthenticated;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _verificationId;
  bool _useFirebase = false;

  String? get verificationId => _verificationId;
  bool get useFirebase => _useFirebase;

  Future<void> _restore() async {
    final refreshToken = await _repo.readRefreshToken();
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _isAuthenticated = true;
      try {
        await refreshIfNeeded();
      } catch (_) {
        await logout();
      }
    }
    notifyListeners();
  }

  Future<void> login(String phone, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final tokens = await _repo.login(phone: phone, password: password);
      await _repo.saveTokens(tokens);
      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(
    String phone,
    String password,
    String otp, {
    required String email,
    String? name,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final tokens = await _repo.register(
        phone: phone,
        password: password,
        otp: otp,
        email: email,
        name: name,
      );
      await _repo.saveTokens(tokens);
      _isAuthenticated = true;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendEmailOtp(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repo.sendEmailOtp(email: email);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> sendOtp(
    String phone, {
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final phoneService = FirebasePhoneService();
      await phoneService.verifyPhone(
        phoneNumber: phone,
        onCodeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _useFirebase = true;
          _isLoading = false;
          notifyListeners();
          onCodeSent(verificationId);
        },
        onFailed: (e) async {
          debugPrint('Firebase verification failed, falling back to Mock: ${e.message}');
          try {
            await _repo.sendOtp(phone: phone);
            _useFirebase = false;
            _verificationId = null;
            _isLoading = false;
            notifyListeners();
            onCodeSent("MOCK");
          } catch (err) {
            _isLoading = false;
            notifyListeners();
            onError(err.toString());
          }
        },
        onAutoVerified: (credential) {
          // Automatic verification callback
        },
        onTimeout: (verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      debugPrint('Firebase verifyPhone threw error, falling back to Mock: $e');
      try {
        await _repo.sendOtp(phone: phone);
        _useFirebase = false;
        _verificationId = null;
        _isLoading = false;
        notifyListeners();
        onCodeSent("MOCK");
      } catch (err) {
        _isLoading = false;
        notifyListeners();
        onError(err.toString());
      }
    }
  }

  Future<void> forgotPassword(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repo.forgotPassword(email: email);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetPassword({required String email, required String otp, required String newPassword}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repo.resetPassword(email: email, otp: otp, newPassword: newPassword);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void>? _refreshInFlight;

  Future<void> logout() async {
    await _repo.clearTokens();
    _isAuthenticated = false;
    notifyListeners();
  }

  /// Nhiều API 401 cùng lúc chỉ được refresh 1 lần (tránh race → token cũ bị xóa → 500/logout).
  Future<void> refreshIfNeeded() async {
    if (_refreshInFlight != null) {
      return _refreshInFlight!;
    }
    _refreshInFlight = _doRefresh();
    try {
      await _refreshInFlight!;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> _doRefresh() async {
    final refreshToken = await _repo.readRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return;
    final tokens = await _repo.refresh(refreshToken: refreshToken);
    await _repo.saveTokens(tokens);
    _isAuthenticated = true;
    notifyListeners();
  }
}
