import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/dio_provider.dart';
import 'auth_provider.dart';

/// Current user profile from `/api/user/me`. Null when logged out / loading failed.
final currentUserProvider = FutureProvider.autoDispose<Map<String, dynamic>?>((ref) async {
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated) return null;
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/user/me');
    return response.data['data'] as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
});

final isAdminProvider = Provider.autoDispose<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return (user?['role']?.toString().toUpperCase() ?? '') == 'ADMIN';
});

final userRoleProvider = Provider.autoDispose<String>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  return user?['role']?.toString().toUpperCase() ?? 'USER';
});
