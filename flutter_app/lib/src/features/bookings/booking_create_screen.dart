import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';
import '../booking/location_picker_dialog.dart';

class BookingCreateScreen extends ConsumerStatefulWidget {
  const BookingCreateScreen({super.key, required this.carId});

  final String carId;

  @override
  ConsumerState<BookingCreateScreen> createState() => _BookingCreateScreenState();
}

class _BookingCreateScreenState extends ConsumerState<BookingCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  DateTimeRange? _selectedRange;
  bool _loading = false;

  PickedLocation? _pickupLocation;
  PickedLocation? _dropoffLocation;


  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _selectedRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: Theme.of(context).colorScheme.primary,
                  onPrimary: Colors.white,
                  surface: Theme.of(context).colorScheme.surfaceContainerLowest,
                  onSurface: Theme.of(context).colorScheme.onSurface,
                ),
          ),
          child: child!,
        );
      },
    );
    if (range != null) {
      setState(() => _selectedRange = range);
    }
  }

  Future<void> _submit() async {
    if (_selectedRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ngày thuê')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      final dio = ref.read(dioProvider);
      final bookingResponse = await dio.post('/api/bookings', data: {
        'carId': int.parse(widget.carId),
        'startDate': _selectedRange!.start.toIso8601String().split('T').first,
        'endDate': _selectedRange!.end.toIso8601String().split('T').first,
        if (_pickupLocation != null) ...{
          'pickupAddress': _pickupLocation!.address,
          'pickupLatitude': _pickupLocation!.lat,
          'pickupLongitude': _pickupLocation!.lng,
        },
        if (_dropoffLocation != null) ...{
          'dropoffAddress': _dropoffLocation!.address,
          'dropoffLatitude': _dropoffLocation!.lat,
          'dropoffLongitude': _dropoffLocation!.lng,
        },
      });

      final bookingData = bookingResponse.data['data'];
      final bookingId = bookingData['bookingId'];

      // Fetch payment URL for the deposit
      final paymentUrlResponse = await dio.post('/api/payments/vnpay/create/$bookingId');
      final paymentUrl = paymentUrlResponse.data['data'] as String;

      if (mounted) {
        // Navigate to payment webview
        final success = await context.push<bool>('/payment-webview', extra: paymentUrl);
        if (mounted) {
          if (success == true) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đặt cọc giữ xe thành công! 🎉')));
          } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Đã tạo đơn đặt xe, vui lòng hoàn tất đặt cọc sau trong chi tiết chuyến đi.'),
              duration: Duration(seconds: 4),
            ));
          }
          context.go('/bookings');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể tạo đơn thuê: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangeText = _selectedRange == null
        ? 'Chưa chọn'
        : '${_selectedRange!.start.toLocal().toString().split(' ').first} → ${_selectedRange!.end.toLocal().toString().split(' ').first}';
    
    final days = _selectedRange != null
        ? _selectedRange!.end.difference(_selectedRange!.start).inDays + 1
        : 0;

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ─── Hero Gradient Header ───
            Container(
              width: double.infinity,
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 16,
                bottom: 48,
              ),
              decoration: const BoxDecoration(
                gradient: AppTheme.heroGradient,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Đặt xe',
                    style: tt.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Xe #${widget.carId}',
                    style: tt.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Content Form ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Transform.translate(
                offset: const Offset(0, -24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          boxShadow: [AppTheme.ambientShadow],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Thời gian thuê xe',
                              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Chọn ngày nhận và trả xe',
                              style: tt.bodyMedium,
                            ),
                            const SizedBox(height: 24),
                            
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer.withValues(alpha: 0.2),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(Icons.date_range_rounded, color: cs.primary, size: 24),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rangeText,
                                          style: tt.titleMedium?.copyWith(
                                            color: _selectedRange == null ? cs.outline : cs.onSurface,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (days > 0) ...[
                                          const SizedBox(height: 2),
                                          Text('Tổng: $days ngày', style: tt.bodySmall?.copyWith(color: cs.primary)),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _pickDates,
                                child: Text(_selectedRange == null ? 'Chọn ngày' : 'Thay đổi ngày'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ─── Location Section ───
                      Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                          boxShadow: [AppTheme.ambientShadow],
                        ),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Địa điểm giao nhận xe',
                              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Nhấn để chọn trực tiếp trên bản đồ',
                              style: tt.bodyMedium,
                            ),
                            const SizedBox(height: 20),
                            _LocationRow(
                              icon: Icons.my_location_rounded,
                              label: 'Điểm đón',
                              address: _pickupLocation?.address,
                              color: cs.secondaryContainer,
                              onTap: () async {
                                final result = await LocationPickerDialog.show(
                                  context,
                                  title: 'Chọn điểm đón',
                                  initialLocation: _pickupLocation,
                                  accentColor: cs.secondaryContainer,
                                );
                                if (result != null) setState(() => _pickupLocation = result);
                              },
                            ),
                            const SizedBox(height: 12),
                            _LocationRow(
                              icon: Icons.flag_rounded,
                              label: 'Điểm trả',
                              address: _dropoffLocation?.address,
                              color: cs.tertiary,
                              onTap: () async {
                                final result = await LocationPickerDialog.show(
                                  context,
                                  title: 'Chọn điểm trả',
                                  initialLocation: _dropoffLocation,
                                  accentColor: cs.tertiary,
                                );
                                if (result != null) setState(() => _dropoffLocation = result);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      GradientButton(
                        onPressed: _loading ? null : _submit,
                        isLoading: _loading,
                        child: const Text('Gửi yêu cầu thuê xe',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            )),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    this.address,
  });

  final IconData icon;
  final String label;
  final String? address;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasLocation = address != null && address!.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasLocation ? color.withValues(alpha: 0.4) : cs.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: tt.labelMedium?.copyWith(color: cs.outline)),
                  const SizedBox(height: 2),
                  Text(
                    hasLocation ? address! : 'Nhấn để chọn trên bản đồ',
                    style: tt.bodyMedium?.copyWith(
                      color: hasLocation ? cs.onSurface : cs.outline,
                      fontWeight: hasLocation ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: cs.outline, size: 20),
          ],
        ),
      ),
    );
  }
}
