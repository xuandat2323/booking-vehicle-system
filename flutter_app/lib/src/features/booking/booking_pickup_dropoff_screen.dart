import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import 'branch_location_picker.dart';
import 'location_picker_dialog.dart';

/// Điểm nhận cố định theo xe; chỉ cho đổi điểm trả trong các trạng thái cho phép.
class BookingPickupDropoffScreen extends ConsumerStatefulWidget {
  const BookingPickupDropoffScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingPickupDropoffScreen> createState() =>
      _BookingPickupDropoffScreenState();
}

class _BookingPickupDropoffScreenState
    extends ConsumerState<BookingPickupDropoffScreen> {
  PickedLocation? _pickup;
  PickedLocation? _dropoff;
  String _status = '';
  bool _dropoffChanged = false;
  bool _loadingData = true;
  bool _saving = false;

  bool get _canEditDropoff =>
      _status == 'PENDING' ||
      _status == 'DEPOSIT_PAID' ||
      _status == 'CONFIRMED' ||
      _status == 'RENTING' ||
      _status == 'IN_PROGRESS';

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocations();
  }

  Future<void> _fetchCurrentLocations() async {
    try {
      final dio = ref.read(dioProvider);
      final response = await dio.get('/api/bookings/${widget.bookingId}');
      final booking = response.data['data'] as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _status = booking['status']?.toString() ?? '';
        final pAddr = booking['pickupAddress']?.toString();
        final pLat =
            double.tryParse(booking['pickupLatitude']?.toString() ?? '');
        final pLng =
            double.tryParse(booking['pickupLongitude']?.toString() ?? '');
        if (pAddr != null && pAddr.isNotEmpty && pLat != null && pLng != null) {
          _pickup = PickedLocation(address: pAddr, lat: pLat, lng: pLng);
        }
        final dAddr = booking['dropoffAddress']?.toString();
        final dLat =
            double.tryParse(booking['dropoffLatitude']?.toString() ?? '');
        final dLng =
            double.tryParse(booking['dropoffLongitude']?.toString() ?? '');
        if (dAddr != null && dAddr.isNotEmpty && dLat != null && dLng != null) {
          _dropoff = PickedLocation(address: dAddr, lat: dLat, lng: dLng);
        }
        _loadingData = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _save() async {
    if (!_canEditDropoff) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không thể đổi điểm trả ở trạng thái hiện tại')),
      );
      return;
    }
    if (!_dropoffChanged || _dropoff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn chi nhánh trả xe')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.put(
        '/api/bookings/${widget.bookingId}/dropoff-location',
        data: {
          'address': _dropoff!.address,
          'latitude': _dropoff!.lat,
          'longitude': _dropoff!.lng,
          if (_dropoff!.branchId != null) 'branchId': _dropoff!.branchId,
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật điểm trả')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi lưu: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Điểm nhận / trả')),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Điểm nhận cố định theo chi nhánh của xe. '
                  'Bạn chỉ có thể đổi điểm trả trước khi xác nhận trả xe.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                _BranchRow(
                  label: 'Chi nhánh nhận xe (cố định)',
                  value: _pickup?.address,
                  locked: true,
                  onTap: () {},
                ),
                const SizedBox(height: 12),
                _BranchRow(
                  label: 'Chi nhánh trả',
                  value: _dropoff?.address,
                  locked: !_canEditDropoff,
                  onTap: () async {
                    final r = await BranchLocationPicker.show(
                      context,
                      title: 'Chọn chi nhánh trả',
                      initialLocation: _dropoff,
                    );
                    if (r != null) {
                      setState(() {
                        _dropoff = r;
                        _dropoffChanged = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving || !_canEditDropoff ? null : _save,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Lưu điểm trả'),
                ),
              ],
            ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  const _BranchRow({
    required this.label,
    required this.onTap,
    this.value,
    this.locked = false,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final has = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.storefront_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    has ? value! : 'Chạm để chọn chi nhánh',
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: has ? FontWeight.w600 : FontWeight.w400,
                      color: has ? null : cs.outline,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              locked
                  ? Icons.lock_outline_rounded
                  : Icons.chevron_right_rounded,
            ),
          ],
        ),
      ),
    );
  }
}
