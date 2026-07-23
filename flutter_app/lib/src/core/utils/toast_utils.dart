import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

class ToastUtils {
  ToastUtils._();

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.green[700]!, Icons.check_circle_outline);
  }

  static void showError(BuildContext context, dynamic error) {
    String message = _mapErrorToMessage(error);
    _show(context, message, Theme.of(context).colorScheme.error, Icons.error_outline);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, Colors.orange[800]!, Icons.warning_amber_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, Theme.of(context).colorScheme.primary, Icons.info_outline);
  }

  static String mapError(dynamic error) => _mapErrorToMessage(error);

  static String _mapErrorToMessage(dynamic error) {
    if (error is String) return error;
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return 'Kết nối quá hạn, vui lòng kiểm tra mạng';
        case DioExceptionType.connectionError:
          return 'Không thể kết nối đến máy chủ. Vui lòng kiểm tra URL hoặc Backend';
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          final data = error.response?.data;
          if (data is Map && data['message'] is String && (data['message'] as String).isNotEmpty) {
            return data['message'] as String;
          }
          if (code == 403) return 'Bạn không có quyền thực hiện thao tác này';
          if (code == 401) return 'Phiên đăng nhập hết hạn, vui lòng đăng nhập lại';
          if (code == 404) return 'Không tìm thấy dữ liệu';
          if (code == 500) return 'Máy chủ gặp lỗi. Vui lòng thử lại sau';
          return 'Lỗi từ máy chủ: $code';
        default:
          return 'Lỗi kết nối: ${error.message}';
      }
    }
    return 'Đã có lỗi xảy ra: $error';
  }

  static void _show(BuildContext context, String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
