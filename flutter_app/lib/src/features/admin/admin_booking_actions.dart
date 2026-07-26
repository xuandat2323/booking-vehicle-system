import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';
import 'admin_bookings_provider.dart';

/// Panel thao tác admin theo trạng thái đơn (dùng ở list + chi tiết).
class AdminBookingActionsPanel extends ConsumerWidget {
  const AdminBookingActionsPanel({
    super.key,
    required this.bookingId,
    required this.status,
    required this.carName,
    this.fullWidth = false,
    this.onDone,
  });

  final dynamic bookingId;
  final String status;
  final String carName;
  final bool fullWidth;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showConfirm = status == 'DEPOSIT_PAID';
    final showCancel =
        status == 'PENDING' || status == 'DEPOSIT_PAID' || status == 'CONFIRMED';
    final showHandover = status == 'CONFIRMED';
    final showReturn = status == 'RENTING' || status == 'IN_PROGRESS';
    final showComplete = status == 'RETURNED';
    final hasActions =
        showConfirm || showCancel || showHandover || showReturn || showComplete;

    if (!hasActions) return const SizedBox.shrink();

    Future<void> run(String action) => performAdminBookingAction(
          context: context,
          ref: ref,
          bookingId: bookingId,
          carName: carName,
          action: action,
          onDone: onDone,
        );

    final buttons = <Widget>[
      if (showConfirm)
        _AdminActionButton(
          label: 'Duyệt cọc',
          icon: Icons.check_circle_outline_rounded,
          color: Colors.blue,
          fullWidth: fullWidth,
          onPressed: () => run('confirm'),
        ),
      if (showHandover)
        _AdminActionButton(
          label: 'Bàn giao',
          icon: Icons.vpn_key_rounded,
          color: Colors.indigo,
          fullWidth: fullWidth,
          onPressed: () => run('handover'),
        ),
      if (showReturn)
        _AdminActionButton(
          label: 'Nhận trả',
          icon: Icons.keyboard_return_rounded,
          color: Colors.teal,
          fullWidth: fullWidth,
          onPressed: () => run('return'),
        ),
      if (showComplete)
        _AdminActionButton(
          label: 'Hoàn thành',
          icon: Icons.task_alt_rounded,
          color: Colors.green,
          fullWidth: fullWidth,
          onPressed: () => run('complete'),
        ),
      if (showCancel)
        _AdminActionButton(
          label: 'Hủy đơn',
          icon: Icons.cancel_outlined,
          color: Colors.red,
          fullWidth: fullWidth,
          onPressed: () => run('cancel'),
        ),
    ];

    if (fullWidth) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < buttons.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            buttons[i],
          ],
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }
}

Future<void> performAdminBookingAction({
  required BuildContext context,
  required WidgetRef ref,
  required dynamic bookingId,
  required String carName,
  required String action,
  VoidCallback? onDone,
}) async {
  if (action == 'cancel') {
    final result = await showDialog<({String reason, String handling})>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AdminCancelBookingDialog(carName: carName),
    );
    if (result == null || !context.mounted) return;
    await _runAdminAction(
      context: context,
      ref: ref,
      endpoint: '/api/admin/bookings/$bookingId/cancel',
      successLabel: 'hủy',
      carName: carName,
      body: {
        'reason': result.reason,
        'handling': result.handling,
      },
      onDone: onDone,
    );
    return;
  }

  final (title, endpoint, confirmMsg, successLabel) = switch (action) {
    'confirm' => (
        'Duyệt đơn cọc',
        '/api/admin/bookings/$bookingId/confirm',
        'Xác nhận đã nhận cọc và duyệt đơn giữ xe "$carName"?',
        'duyệt cọc',
      ),
    'handover' => (
        'Bàn giao xe',
        '/api/admin/bookings/$bookingId/handover',
        'Tiến hành bàn giao xe "$carName" cho khách hàng bắt đầu thuê?',
        'bàn giao',
      ),
    'return' => (
        'Nhận trả xe',
        '/api/admin/bookings/$bookingId/return',
        'Xác nhận khách hàng đã trả xe "$carName"?',
        'nhận trả',
      ),
    'complete' => (
        'Hoàn thành đơn',
        '/api/admin/bookings/$bookingId/complete',
        'Xác nhận hoàn tất đơn "$carName", thanh toán nốt và trả cọc?',
        'hoàn thành',
      ),
    _ => ('', '', '', ''),
  };

  if (endpoint.isEmpty) return;

  final confirmed = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(confirmMsg),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(title),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;
  await _runAdminAction(
    context: context,
    ref: ref,
    endpoint: endpoint,
    successLabel: successLabel,
    carName: carName,
    onDone: onDone,
  );
}

Future<void> _runAdminAction({
  required BuildContext context,
  required WidgetRef ref,
  required String endpoint,
  required String successLabel,
  required String carName,
  Map<String, dynamic>? body,
  VoidCallback? onDone,
}) async {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    await ref.read(dioProvider).put(endpoint, data: body);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    ref.invalidate(adminBookingsProvider);
    onDone?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã $successLabel đơn "$carName"')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }
}

class AdminCancelBookingDialog extends StatefulWidget {
  const AdminCancelBookingDialog({super.key, required this.carName});

  final String carName;

  @override
  State<AdminCancelBookingDialog> createState() =>
      _AdminCancelBookingDialogState();
}

class _AdminCancelBookingDialogState extends State<AdminCancelBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reasonCtrl = TextEditingController();
  final _handlingCtrl = TextEditingController();

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _handlingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    // Dialog đã tự cộng viewInsets — chỉ giới hạn chiều cao còn lại trên bàn phím.
    final availableHeight = media.size.height
        - media.viewInsets.bottom
        - media.padding.vertical
        - 120;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      title: const Text('Hủy đơn thuê'),
      content: SizedBox(
        width: 420,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: availableHeight.clamp(140.0, 360.0),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: media.viewInsets.bottom > 0 ? 8 : 0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Hủy đơn "${widget.carName}". Chỉ hủy trước khi bàn giao xe.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _reasonCtrl,
                    maxLines: 2,
                    maxLength: 500,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Lý do hủy *',
                      hintText: 'VD: Khách yêu cầu hủy, xe hỏng, trùng lịch...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Nhập lý do hủy' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _handlingCtrl,
                    maxLines: 2,
                    maxLength: 500,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Hướng xử lý *',
                      hintText: 'VD: Hoàn cọc 100%, giữ 30% phí hủy...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nhập hướng xử lý'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Đóng'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: cs.error),
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop((
              reason: _reasonCtrl.text.trim(),
              handling: _handlingCtrl.text.trim(),
            ));
          },
          child: const Text('Xác nhận hủy'),
        ),
      ],
    );
  }
}

class _AdminActionButton extends StatelessWidget {
  const _AdminActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
    this.fullWidth = false,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final button = OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: fullWidth ? 20 : 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: EdgeInsets.symmetric(
          horizontal: fullWidth ? 16 : 14,
          vertical: fullWidth ? 14 : 8,
        ),
        textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: fullWidth ? 14 : null,
            ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        minimumSize: fullWidth ? const Size.fromHeight(48) : Size.zero,
        tapTargetSize: fullWidth
            ? MaterialTapTargetSize.padded
            : MaterialTapTargetSize.shrinkWrap,
      ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}
