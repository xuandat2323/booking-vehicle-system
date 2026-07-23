import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }

  static Widget carCardPlaceholder(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ShimmerLoading(width: double.infinity, height: 180, borderRadius: 16),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ShimmerLoading(width: 150, height: 24),
                    ShimmerLoading(width: 60, height: 24),
                  ],
                ),
                const SizedBox(height: 8),
                ShimmerLoading(width: 100, height: 16),
                const SizedBox(height: 16),
                Row(
                  children: List.generate(3, (index) =>
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ShimmerLoading(width: 70, height: 28, borderRadius: 8),
                    )
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
