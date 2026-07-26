import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

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
  // Map legacy IN_PROGRESS → RENTING for filter chips
  final wanted = statusFilter == 'IN_PROGRESS' ? 'RENTING' : statusFilter;
  return all.where((b) {
    final s = b['status']?.toString() ?? '';
    if (wanted == 'RENTING') return s == 'RENTING' || s == 'IN_PROGRESS';
    return s == wanted;
  }).toList();
});

class AdminBookingsScreen extends ConsumerStatefulWidget {
  const AdminBookingsScreen({super.key});

  @override
  ConsumerState<AdminBookingsScreen> createState() =>
      _AdminBookingsScreenState();
}

class _AdminBookingsScreenState extends ConsumerState<AdminBookingsScreen> {
  String _selectedStatus = '';

  static const _filters = [
    ('Tất cả', ''),
    ('Chờ cọc', 'PENDING'),
    ('Chờ duyệt cọc', 'DEPOSIT_PAID'),
    ('Đã xác nhận', 'CONFIRMED'),
    ('Đang thuê', 'RENTING'),
    ('Hoàn thành', 'COMPLETED'),
    ('Đã hủy', 'CANCELLED'),
  ];

  @override
  Widget build(BuildContext context) {
    final bookingsAsync = ref.watch(adminBookingsProvider(_selectedStatus));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Quản lý đơn đặt xe')),
      body: Column(
        children: [
          // ── Filter chips ──
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final (label, value) = _filters[i];
                final isSelected = _selectedStatus == value;
                final chipColor = _statusColor(value, cs);
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() => _selectedStatus = value);
                  },
                  labelStyle: tt.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? (value.isEmpty ? cs.primary : chipColor)
                        : cs.onSurfaceVariant,
                  ),
                  selectedColor: (value.isEmpty ? cs.primary : chipColor)
                      .withValues(alpha: 0.12),
                  checkmarkColor: value.isEmpty ? cs.primary : chipColor,
                  showCheckmark: false,
                  side: isSelected
                      ? BorderSide(
                          color: (value.isEmpty ? cs.primary : chipColor)
                              .withValues(alpha: 0.4))
                      : BorderSide.none,
                  backgroundColor: cs.surfaceContainerLow,
                );
              },
            ),
          ),

          // ── Booking list ──
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(adminBookingsProvider(_selectedStatus)),
              child: bookingsAsync.when(
                data: (bookings) => bookings.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: cs.outlineVariant),
                            const SizedBox(height: 16),
                            Text('Không có đơn nào', style: tt.titleMedium),
                            const SizedBox(height: 8),
                            Text(
                              'Thử chọn bộ lọc khác',
                              style: tt.bodyMedium
                                  ?.copyWith(color: cs.outline),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding:
                            const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        itemCount: bookings.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, i) {
                          return _BookingCard(
                            booking: bookings[i],
                            onAction: (action) => _handleAction(
                                context, bookings[i], action),
                          );
                        },
                      ),
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 48, color: cs.error),
                      const SizedBox(height: 12),
                      Text('Lỗi: $e',
                          textAlign: TextAlign.center,
                          style: tt.bodyMedium?.copyWith(color: cs.error)),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => ref
                            .invalidate(adminBookingsProvider(_selectedStatus)),
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status, ColorScheme cs) {
    return switch (status) {
      'PENDING' => Colors.orange,
      'DEPOSIT_PAID' => Colors.amber.shade800,
      'CONFIRMED' => Colors.blue,
      'RENTING' || 'IN_PROGRESS' => const Color(0xFF9C4FE8),
      'COMPLETED' => Colors.green,
      'CANCELLED' => Colors.red,
      _ => cs.primary,
    };
  }

  Future<void> _handleAction(
    BuildContext context,
    Map<String, dynamic> booking,
    String action,
  ) async {
    final bookingId = booking['bookingId'];
    final carName = booking['carName']?.toString() ?? '';

    if (action == 'cancel') {
      await _handleCancel(context, bookingId, carName);
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
    await _runAdminAction(context, endpoint, successLabel, carName);
  }

  Future<void> _handleCancel(
    BuildContext context,
    dynamic bookingId,
    String carName,
  ) async {
    final result = await showDialog<({String reason, String handling})>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => _CancelBookingDialog(carName: carName),
    );
    if (result == null || !context.mounted) return;

    await _runAdminAction(
      context,
      '/api/admin/bookings/$bookingId/cancel',
      'hủy',
      carName,
      body: {
        'reason': result.reason,
        'handling': result.handling,
      },
    );
  }

  Future<void> _runAdminAction(
    BuildContext context,
    String endpoint,
    String successLabel,
    String carName, {
    Map<String, dynamic>? body,
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
        Navigator.of(context, rootNavigator: true).pop(); // loading
      }
      ref.invalidate(adminBookingsProvider(_selectedStatus));
      ref.invalidate(adminBookingsProvider(''));
      if (_selectedStatus != 'DEPOSIT_PAID') {
        ref.invalidate(adminBookingsProvider('DEPOSIT_PAID'));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã $successLabel đơn "$carName"')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // loading
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }
}

class _BookingCard extends StatefulWidget {
  const _BookingCard({required this.booking, required this.onAction});
  final Map<String, dynamic> booking;
  final void Function(String action) onAction;

  @override
  State<_BookingCard> createState() => _BookingCardState();
}

class _BookingCardState extends State<_BookingCard> {
  String _formatPrice(dynamic value) {
    if (value == null) return '0 đ';
    final n = (value is num)
        ? value.toDouble()
        : double.tryParse(value.toString()) ?? 0.0;
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M đ';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}k đ';
    return '${n.toStringAsFixed(0)} đ';
  }

  (String, Color) _statusInfo(String status) {
    return switch (status) {
      'PENDING' => ('Chờ cọc', Colors.orange),
      'DEPOSIT_PAID' => ('Đã cọc (Chờ duyệt)', Colors.amber.shade800),
      'CONFIRMED' => ('Đã duyệt', Colors.blue),
      'RENTING' => ('Đang thuê', const Color(0xFF9C4FE8)),
      'IN_PROGRESS' => ('Đang thuê', const Color(0xFF9C4FE8)),
      'RETURNED' => ('Đã trả xe', Colors.teal),
      'COMPLETED' => ('Hoàn thành', Colors.green),
      'CANCELLED' => ('Đã hủy', Colors.red),
      _ => (status, Colors.grey),
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final b = widget.booking;

    final status = b['status']?.toString() ?? '';
    final (statusLabel, statusColor) = _statusInfo(status);

    final showConfirm = status == 'DEPOSIT_PAID';
    final showCancel = status == 'PENDING' || status == 'DEPOSIT_PAID' || status == 'CONFIRMED';
    final showHandover = status == 'CONFIRMED';
    final showReturn = status == 'RENTING' || status == 'IN_PROGRESS';
    final showComplete = status == 'RETURNED';
    final hasActions = showConfirm || showCancel || showHandover || showReturn || showComplete;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: [AppTheme.softShadow],
        border: status == 'PENDING'
            ? Border.all(
                color: Colors.orange.withValues(alpha: 0.35), width: 1)
            : null,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () {
              final id = b['bookingId'];
              if (id != null) {
                context.push('/admin/bookings/$id');
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            // ── Header row ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Tooltip(
                        message: b['carName']?.toString() ?? '',
                        child: Text(
                          b['carName']?.toString() ?? '',
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 13, color: cs.outline),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              b['userName']?.toString()
                                  ?? b['renterName']?.toString()
                                  ?? '',
                              style:
                                  tt.bodySmall?.copyWith(color: cs.outline),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(child: _StatusChip(label: statusLabel, color: statusColor)),
              ],
            ),

            const SizedBox(height: 10),
            Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
            const SizedBox(height: 8),

            // ── Dates + price ──
            Row(
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 13, color: cs.outline),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${b['startDate'] ?? ''} → ${b['endDate'] ?? ''}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    _formatPrice(b['totalPrice']),
                    style: tt.titleSmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),

            if (status == 'CANCELLED' &&
                ((b['cancelReason']?.toString().isNotEmpty ?? false) ||
                    (b['cancelHandling']?.toString().isNotEmpty ?? false))) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (b['cancelReason']?.toString().isNotEmpty ?? false)
                      Text(
                        'Lý do hủy: ${b['cancelReason']}',
                        style: tt.bodySmall?.copyWith(color: Colors.red.shade800),
                      ),
                    if (b['cancelHandling']?.toString().isNotEmpty ?? false) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Hướng xử lý: ${b['cancelHandling']}',
                        style: tt.bodySmall?.copyWith(color: Colors.red.shade800),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.open_in_new_rounded, size: 14, color: cs.outline),
                const SizedBox(width: 4),
                Text(
                  'Nhấn để xem chi tiết',
                  style: tt.labelSmall?.copyWith(color: cs.outline),
                ),
              ],
            ),
              ],
            ),
          ),

            // ── Action buttons ──
            if (hasActions) ...[
              const SizedBox(height: 12),
              Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (showConfirm)
                    _ActionButton(
                      label: 'Duyệt cọc',
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.blue,
                      onPressed: () => widget.onAction('confirm'),
                    ),
                  if (showHandover)
                    _ActionButton(
                      label: 'Bàn giao',
                      icon: Icons.vpn_key_rounded,
                      color: Colors.indigo,
                      onPressed: () => widget.onAction('handover'),
                    ),
                  if (showReturn)
                    _ActionButton(
                      label: 'Nhận trả',
                      icon: Icons.keyboard_return_rounded,
                      color: Colors.teal,
                      onPressed: () => widget.onAction('return'),
                    ),
                  if (showComplete)
                    _ActionButton(
                      label: 'Hoàn thành',
                      icon: Icons.task_alt_rounded,
                      color: Colors.green,
                      onPressed: () => widget.onAction('complete'),
                    ),
                  if (showCancel)
                    _ActionButton(
                      label: 'Hủy đơn',
                      icon: Icons.cancel_outlined,
                      color: Colors.red,
                      onPressed: () => widget.onAction('cancel'),
                    ),
                ],
              ),
            ],
          ],
        ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        textStyle: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        ),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _CancelBookingDialog extends StatefulWidget {
  const _CancelBookingDialog({required this.carName});

  final String carName;

  @override
  State<_CancelBookingDialog> createState() => _CancelBookingDialogState();
}

class _CancelBookingDialogState extends State<_CancelBookingDialog> {
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
    return AlertDialog(
      title: const Text('Hủy đơn thuê'),
      content: SizedBox(
        width: 420,
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
                decoration: const InputDecoration(
                  labelText: 'Lý do hủy *',
                  hintText: 'VD: Khách yêu cầu hủy, xe hỏng, trùng lịch...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nhập lý do hủy' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _handlingCtrl,
                maxLines: 2,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Hướng xử lý *',
                  hintText: 'VD: Hoàn cọc 100%, giữ 30% phí hủy...',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Nhập hướng xử lý'
                    : null,
              ),
            ],
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
