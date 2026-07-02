import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';

final invoiceDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, invoiceId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/invoices/$invoiceId');
  return response.data['data'] as Map<String, dynamic>;
});

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  final String invoiceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoiceAsync = ref.watch(invoiceDetailProvider(invoiceId));
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết hoá đơn')),
      body: invoiceAsync.when(
        data: (invoice) {
          final status = invoice['status']?.toString() ?? '';
          final isPaid = status == 'PAID';
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isPaid
                        ? [Colors.green.shade400, Colors.green.shade700]
                        : [Colors.orange.shade400, Colors.orange.shade700],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(
                      isPaid ? Icons.check_circle : Icons.pending,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isPaid ? 'Đã thanh toán' : 'Chưa thanh toán',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      invoice['invoiceNumber']?.toString() ?? '',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${invoice['totalAmount'] ?? ''} ₫',
                      style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Car info
              _SectionCard(
                title: 'Thông tin xe',
                icon: Icons.directions_car,
                rows: [
                  _InfoRow(label: 'Xe', value: '${invoice['carBrand'] ?? ''} ${invoice['carName'] ?? ''}'),
                  _InfoRow(label: 'Biển số', value: invoice['carLicensePlate']?.toString() ?? ''),
                ],
              ),
              const SizedBox(height: 12),

              // Rental period
              _SectionCard(
                title: 'Thời gian thuê',
                icon: Icons.calendar_month,
                rows: [
                  _InfoRow(label: 'Ngày bắt đầu', value: invoice['startDate']?.toString() ?? ''),
                  _InfoRow(label: 'Ngày kết thúc', value: invoice['endDate']?.toString() ?? ''),
                ],
              ),
              const SizedBox(height: 12),

              // Payment info
              _SectionCard(
                title: 'Thanh toán',
                icon: Icons.payment,
                rows: [
                  _InfoRow(label: 'Phương thức', value: invoice['paymentMethod']?.toString() ?? 'VNPay'),
                  _InfoRow(label: 'Trạng thái', value: isPaid ? 'Đã thanh toán' : 'Chưa thanh toán'),
                  _InfoRow(label: 'Tổng tiền', value: '${invoice['totalAmount'] ?? ''} ₫'),
                ],
              ),
              const SizedBox(height: 12),

              // Customer info
              _SectionCard(
                title: 'Thông tin khách hàng',
                icon: Icons.person,
                rows: [
                  _InfoRow(label: 'Tên', value: invoice['userName']?.toString() ?? ''),
                  _InfoRow(label: 'Số điện thoại', value: invoice['userPhone']?.toString() ?? ''),
                ],
              ),
              const SizedBox(height: 24),

              // Navigate to booking
              OutlinedButton.icon(
                onPressed: () => context.push('/bookings/${invoice['bookingId']}'),
                icon: const Icon(Icons.receipt_long),
                label: const Text('Xem chi tiết booking'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Không tải được hoá đơn: $e')),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.rows});

  final String title;
  final IconData icon;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(height: 20),
            ...rows.map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(row.label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                      ),
                      Expanded(
                        child: Text(
                          row.value,
                          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _InfoRow {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});
}
