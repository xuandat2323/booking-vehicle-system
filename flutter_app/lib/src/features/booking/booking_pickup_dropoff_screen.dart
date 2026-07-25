import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/dio_provider.dart';
import 'branch_location_picker.dart';
import 'location_picker_dialog.dart';

/// Đổi điểm đón/trả — chỉ chọn trong 3 chi nhánh.
class BookingPickupDropoffScreen extends ConsumerStatefulWidget {
  const BookingPickupDropoffScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<BookingPickupDropoffScreen> createState() => _BookingPickupDropoffScreenState();
}

class _BookingPickupDropoffScreenState extends ConsumerState<BookingPickupDropoffScreen> {
  PickedLocation? _pickup;
  PickedLocation? _dropoff;
  bool _loadingData = true;
  bool _saving = false;

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
        final pAddr = booking['pickupAddress']?.toString();
        final pLat = double.tryParse(booking['pickupLatitude']?.toString() ?? '');
        final pLng = double.tryParse(booking['pickupLongitude']?.toString() ?? '');
        if (pAddr != null && pAddr.isNotEmpty && pLat != null && pLng != null) {
          _pickup = PickedLocation(address: pAddr, lat: pLat, lng: pLng);
        }
        final dAddr = booking['dropoffAddress']?.toString();
        final dLat = double.tryParse(booking['dropoffLatitude']?.toString() ?? '');
        final dLng = double.tryParse(booking['dropoffLongitude']?.toString() ?? '');
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
    if (_pickup == null && _dropoff == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn chi nhánh đón hoặc trả')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      if (_pickup != null) {
        await dio.put('/api/bookings/${widget.bookingId}/pickup-location', data: {
          'address': _pickup!.address,
          'latitude': _pickup!.lat,
          'longitude': _pickup!.lng,
        });
      }
      if (_dropoff != null) {
        await dio.put('/api/bookings/${widget.bookingId}/dropoff-location', data: {
          'address': _dropoff!.address,
          'latitude': _dropoff!.lat,
          'longitude': _dropoff!.lng,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã cập nhật điểm đón/trả')),
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
      appBar: AppBar(title: const Text('Điểm đón / trả')),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Chỉ nhận và trả xe tại chi nhánh GoRento.',
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 20),
                _BranchRow(
                  label: 'Chi nhánh đón',
                  value: _pickup?.address,
                  onTap: () async {
                    final r = await BranchLocationPicker.show(
                      context,
                      title: 'Chọn chi nhánh đón',
                      initialLocation: _pickup,
                    );
                    if (r != null) setState(() => _pickup = r);
                  },
                ),
                const SizedBox(height: 12),
                _BranchRow(
                  label: 'Chi nhánh trả',
                  value: _dropoff?.address,
                  onTap: () async {
                    final r = await BranchLocationPicker.show(
                      context,
                      title: 'Chọn chi nhánh trả',
                      initialLocation: _dropoff,
                    );
                    if (r != null) setState(() => _dropoff = r);
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Lưu'),
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
  });

  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final has = value != null && value!.isNotEmpty;

    return InkWell(
      onTap: onTap,
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
                  Text(label, style: tt.labelMedium?.copyWith(color: cs.onSurfaceVariant)),
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
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
