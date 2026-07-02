import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/dio_provider.dart';
import '../../core/theme/app_theme.dart';
import '../verification/verification_provider.dart';

final carDetailProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, carId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/cars/$carId');
  final data = response.data['data'] as Map<String, dynamic>;
  return data;
});

final carTrackingProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, carId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/cars/$carId/tracking');
  final data = response.data['data'] as Map<String, dynamic>;
  return data;
});

final carReviewsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, carId) async {
  final dio = ref.read(dioProvider);
  final response = await dio.get('/api/reviews/car/$carId', queryParameters: {'page': 0, 'size': 10});
  final data = response.data['data'] as Map<String, dynamic>;
  final content = data['content'] as List<dynamic>;
  return content.cast<Map<String, dynamic>>();
});

class CarDetailScreen extends ConsumerWidget {
  const CarDetailScreen({super.key, required this.carId});

  final String carId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final carAsync = ref.watch(carDetailProvider(carId));
    final trackingAsync = ref.watch(carTrackingProvider(carId));
    final verifyStatus = ref.watch(verificationStatusProvider).valueOrNull;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: carAsync.when(
        data: (car) {
          final location = car['location'] ?? 'Chưa cập nhật';
          final imageUrl = car['imageUrl'];
          final priceStr = car['pricePerDay']?.toString() ?? '0';

          int? priceInt = int.tryParse(priceStr.split('.').first);
          String formattedPrice = priceStr;
          if (priceInt != null && priceInt >= 1000) {
            formattedPrice = '${priceInt ~/ 1000}k';
          }

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  // ─── Hero Image App Bar ───
                  SliverAppBar(
                    expandedHeight: 280,
                    pinned: true,
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => context.pop(),
                        ),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: _buildHeroImage(context, imageUrl),
                    ),
                  ),

                  // ─── Content ───
                  SliverToBoxAdapter(
                    child: Transform.translate(
                      offset: const Offset(0, -32),
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 32, 20, 100), // Bottom padding for CTA
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title & Price Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${car['brand']} ${car['name']}',
                                          style: tt.headlineMedium?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.star_rounded, color: Colors.orange.shade700, size: 20),
                                            const SizedBox(width: 4),
                                            Text(
                                              '${car['averageRating'] ?? 'Mới'}',
                                              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                            ),
                                            Text(
                                              ' (${car['reviewCount'] ?? 0} đánh giá)',
                                              style: tt.bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: cs.primaryContainer.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Column(
                                      children: [
                                        Text(
                                          formattedPrice,
                                          style: tt.titleLarge?.copyWith(
                                            color: cs.primary,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text('vnđ / ngày', style: tt.labelSmall),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),

                              // Specs
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _SpecTag(icon: Icons.airline_seat_recline_normal_rounded, label: '${car['seats']} chỗ'),
                                  _SpecTag(icon: Icons.settings_rounded, label: '${car['transmission'] ?? 'Khác'}'),
                                  _SpecTag(icon: Icons.local_gas_station_rounded, label: '${car['fuelType'] ?? 'Khác'}'),
                                  _SpecTag(
                                    icon: Icons.info_outline_rounded,
                                    label: '${car['status'] ?? ''}',
                                    color: car['status'] == 'AVAILABLE' ? cs.tertiaryContainer : cs.error,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Location Card
                              Text('Địa điểm giao xe', style: tt.titleLarge),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLowest,
                                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                  boxShadow: [AppTheme.ambientShadow],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: cs.secondaryContainer.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(Icons.location_on_rounded, color: cs.secondaryContainer),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            location.toString(),
                                            style: tt.titleMedium,
                                          ),
                                          if (car['latitude'] != null && car['longitude'] != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Tọa độ: ${car['latitude']}, ${car['longitude']}',
                                              style: tt.bodySmall,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Tracking Card (if available)
                              trackingAsync.when(
                                data: (tracking) => Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Vị trí thực tế (GPS)', style: tt.titleLarge),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(20),
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerLowest,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                        boxShadow: [AppTheme.ambientShadow],
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.gps_fixed_rounded, size: 20, color: cs.primary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  tracking['address']?.toString() ?? 'Chưa cập nhật',
                                                  style: tt.titleMedium,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          Divider(color: cs.outlineVariant.withValues(alpha: 0.2)),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              _buildTrackingInfo(context, Icons.speed_rounded, '${tracking['speedKmh'] ?? '-'} km/h', 'Tốc độ'),
                                              _buildTrackingInfo(context, Icons.update_rounded, tracking['updatedAt']?.toString().split('T').last.substring(0,5) ?? '-', 'Cập nhật'),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 32),
                                  ],
                                ),
                                loading: () => const SizedBox.shrink(),
                                error: (e, _) => const SizedBox.shrink(),
                              ),

                              // Reviews Section
                              Text('Đánh giá từ khách hàng', style: tt.titleLarge),
                              const SizedBox(height: 16),
                              ref.watch(carReviewsProvider(carId)).when(
                                data: (reviews) {
                                  if (reviews.isEmpty) {
                                    return Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2), style: BorderStyle.solid),
                                      ),
                                      child: Center(
                                        child: Text('Chưa có đánh giá nào cho xe này.', style: tt.bodyMedium),
                                      ),
                                    );
                                  }
                                  return Column(
                                    children: reviews.map((review) {
                                      final rating = review['rating'] as int? ?? 5;
                                      final date = review['createdAt']?.toString().split('T').first ?? '';
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 16),
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          color: cs.surfaceContainerLowest,
                                          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                                          boxShadow: [AppTheme.softShadow],
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    CircleAvatar(
                                                      radius: 16,
                                                      backgroundColor: cs.primaryContainer.withValues(alpha: 0.2),
                                                      child: Text(
                                                        (review['userName']?.toString() ?? 'K')[0].toUpperCase(),
                                                        style: TextStyle(color: cs.primary, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Text(
                                                      review['userName']?.toString() ?? 'Khách hàng',
                                                      style: tt.titleMedium,
                                                    ),
                                                  ],
                                                ),
                                                Text(date, style: tt.bodySmall),
                                              ],
                                            ),
                                            const SizedBox(height: 12),
                                            Row(
                                              children: List.generate(5, (index) {
                                                return Icon(
                                                  index < rating ? Icons.star_rounded : Icons.star_border_rounded,
                                                  color: Colors.orange.shade700,
                                                  size: 16,
                                                );
                                              }),
                                            ),
                                            if (review['comment'] != null && review['comment'].toString().isNotEmpty) ...[
                                              const SizedBox(height: 8),
                                              Text(
                                                review['comment'].toString(),
                                                style: tt.bodyMedium,
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                },
                                loading: () => const Center(child: CircularProgressIndicator()),
                                error: (e, _) => Text('Không tải được đánh giá: $e', style: tt.bodyMedium?.copyWith(color: cs.error)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              // ─── Sticky Bottom CTA ───
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(20).copyWith(bottom: MediaQuery.of(context).padding.bottom + 20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLowest,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, -10),
                      ),
                    ],
                  ),
                  child: GradientButton(
                    onPressed: () {
                      if (verifyStatus?['status'] == 'VERIFIED') {
                        context.push('/cars/$carId/book');
                      } else {
                        _showVerifyRequired(context);
                      }
                    },
                    child: const Text('Tiếp tục đặt xe', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Không tải được chi tiết xe: $e')),
      ),
    );
  }

  Widget _buildHeroImage(BuildContext context, dynamic imageUrl) {
    if (imageUrl != null && imageUrl.toString().isNotEmpty) {
      return Image.network(
        imageUrl,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _placeholderImage(context),
      );
    }
    return _placeholderImage(context);
  }

  Widget _placeholderImage(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.directions_car_rounded, size: 80, color: Theme.of(context).colorScheme.outlineVariant),
      ),
    );
  }

  Widget _buildTrackingInfo(BuildContext context, IconData icon, String value, String label) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: cs.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: tt.titleSmall),
            Text(label, style: tt.bodySmall),
          ],
        ),
      ],
    );
  }
}

void _showVerifyRequired(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.verified_user_rounded,
                  color: Colors.orange, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Cần xác minh danh tính',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              'Bạn cần hoàn tất xác minh CCCD & bằng lái trước khi đặt xe.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.outline),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/verification');
                },
                icon: const Icon(Icons.badge_rounded),
                label: const Text('Xác minh ngay'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Để sau'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SpecTag extends StatelessWidget {
  const _SpecTag({
    required this.icon,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fgColor = color ?? cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: fgColor),
          const SizedBox(width: 8),
          Text(label, style: tt.titleSmall?.copyWith(color: fgColor)),
        ],
      ),
    );
  }
}
