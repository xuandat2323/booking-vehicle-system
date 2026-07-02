import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';

final adminBookingsProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>(
        (ref, statusFilter) async {
  final dio = ref.read(dioProvider);
  final queryParams = <String, dynamic>{'page': 0, 'size': 50};
  if (statusFilter.isNotEmpty) queryParams['status'] = statusFilter;
  final response =
      await dio.get('/api/admin/bookings', queryParameters: queryParams);
  final data = response.data['data'] as Map<String, dynamic>;
  return (data['content'] as List<dynamic>).cast<Map<String, dynamic>>();
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
    ('Chờ duyệt', 'PENDING'),
    ('Đã xác nhận', 'CONFIRMED'),
    ('Đang thuê', 'IN_PROGRESS'),
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
      'CONFIRMED' => Colors.blue,
      'IN_PROGRESS' => const Color(0xFF9C4FE8),
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

    final (actionLabel, endpoint, confirmMsg) = switch (action) {
      'confirm' => (
          'xác nhận',
          '/api/admin/bookings/$bookingId/confirm',
          'Xác nhận đơn đặt xe "$carName"?'
        ),
      'cancel' => (
          'hủy',
          '/api/admin/bookings/$bookingId/cancel',
          'Hủy đơn đặt xe "$carName"? Hành động này không thể hoàn tác.'
        ),
      'complete' => (
          'hoàn thành',
          '/api/admin/bookings/$bookingId/complete',
          'Đánh dấu đơn "$carName" là hoàn thành?'
        ),
      _ => ('', '', ''),
    };

    if (endpoint.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
            '${actionLabel[0].toUpperCase()}${actionLabel.substring(1)} đơn'),
        content: Text(confirmMsg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            style: action == 'cancel'
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error)
                : null,
            onPressed: () => Navigator.pop(context, true),
            child: Text(
                '${actionLabel[0].toUpperCase()}${actionLabel.substring(1)}'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(dioProvider).put(endpoint);
      ref.invalidate(adminBookingsProvider(_selectedStatus));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Đã $actionLabel đơn đặt xe "${booking['carName']}"')),
        );
      }
    } catch (e) {
      if (context.mounted) {
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
  bool _expanded = false;

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
      'PENDING' => ('Chờ duyệt', Colors.orange),
      'CONFIRMED' => ('Đã xác nhận', Colors.blue),
      'IN_PROGRESS' => ('Đang thuê', const Color(0xFF9C4FE8)),
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

    final showConfirm = status == 'PENDING';
    final showCancel = status == 'PENDING' || status == 'CONFIRMED';
    final showComplete = status == 'IN_PROGRESS';
    final hasActions = showConfirm || showCancel || showComplete;

    return GestureDetector(
      onTap: hasActions ? () => setState(() => _expanded = !_expanded) : null,
      child: Container(
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
            // ── Header row ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b['carName']?.toString() ?? '',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.person_outline_rounded,
                              size: 13, color: cs.outline),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              b['renterName']?.toString() ?? '',
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
                _StatusChip(label: statusLabel, color: statusColor),
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
                  ),
                ),
                Text(
                  _formatPrice(b['totalPrice']),
                  style: tt.titleSmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),

            // ── Expandable action buttons ──
            if (hasActions && _expanded) ...[
              const SizedBox(height: 12),
              Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (showConfirm)
                    _ActionButton(
                      label: 'Xác nhận',
                      icon: Icons.check_circle_outline_rounded,
                      color: Colors.blue,
                      onPressed: () => widget.onAction('confirm'),
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

            // ── Tap hint ──
            if (hasActions && !_expanded) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.expand_more_rounded,
                      size: 16, color: cs.outline),
                  const SizedBox(width: 4),
                  Text(
                    'Nhấn để xem thao tác',
                    style: tt.labelSmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            ],
          ],
        ),
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
