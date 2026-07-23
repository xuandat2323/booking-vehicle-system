import 'package:flutter/material.dart';

class ToastUtils {
  ToastUtils._();

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, Colors.green[700]!, Icons.check_circle_outline);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, Theme.of(context).colorScheme.error, Icons.error_outline);
  }

  static void showWarning(BuildContext context, String message) {
    _show(context, message, Colors.orange[800]!, Icons.warning_amber_rounded);
  }

  static void showInfo(BuildContext context, String message) {
    _show(context, message, Theme.of(context).colorScheme.primary, Icons.info_outline);
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
