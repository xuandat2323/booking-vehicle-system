import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import 'admin_booking_actions.dart';
import 'admin_bookings_provider.dart';
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
                          return _BookingCard(booking: bookings[i]);
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
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});
  final Map<String, dynamic> booking;

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
    final b = booking;

    final status = b['status']?.toString() ?? '';
    final (statusLabel, statusColor) = _statusInfo(status);
    final carName = b['carName']?.toString() ?? '';

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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tooltip(
                            message: carName,
                            child: Text(
                              carName,
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
                    Flexible(
                        child: _StatusChip(
                            label: statusLabel, color: statusColor)),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(color: cs.outlineVariant.withValues(alpha: 0.3)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 13, color: cs.outline),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${b['startDate'] ?? ''} → ${b['endDate'] ?? ''}',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
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
                        (b['cancelHandling']?.toString().isNotEmpty ??
                            false))) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (b['cancelReason']?.toString().isNotEmpty ?? false)
                          Text(
                            'Lý do hủy: ${b['cancelReason']}',
                            style: tt.bodySmall
                                ?.copyWith(color: Colors.red.shade800),
                          ),
                        if (b['cancelHandling']?.toString().isNotEmpty ??
                            false) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Hướng xử lý: ${b['cancelHandling']}',
                            style: tt.bodySmall
                                ?.copyWith(color: Colors.red.shade800),
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
                    Icon(Icons.open_in_new_rounded,
                        size: 14, color: cs.outline),
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
          const SizedBox(height: 8),
          AdminBookingActionsPanel(
            bookingId: b['bookingId'],
            status: status,
            carName: carName,
          ),
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
