import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../numistr_colors.dart';

/// NumisTR Shimmer Loading Widgets
/// Professional loading placeholders for better UX

/// Shimmer loading for list items
class NumListShimmer extends StatelessWidget {
  final int itemCount;
  final double itemHeight;
  final double imageSize;

  const NumListShimmer({
    super.key,
    this.itemCount = 5,
    this.itemHeight = 100,
    this.imageSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: numShimmerBase,
      highlightColor: numShimmerHighlight,
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        padding: const EdgeInsets.all(16),
        itemBuilder: (context, index) {
          return Container(
            height: itemHeight,
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                // Image placeholder
                Container(
                  width: imageSize,
                  height: imageSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 12),
                // Content placeholders
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        height: 16,
                        width: double.infinity,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 150,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 12,
                        width: 100,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer loading for grid items
class NumGridShimmer extends StatelessWidget {
  final int itemCount;
  final int crossAxisCount;
  final double aspectRatio;

  const NumGridShimmer({
    super.key,
    this.itemCount = 6,
    this.crossAxisCount = 2,
    this.aspectRatio = 0.75,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: numShimmerBase,
      highlightColor: numShimmerHighlight,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          childAspectRatio: aspectRatio,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        padding: const EdgeInsets.all(16),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image placeholder
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                  ),
                ),
                // Content placeholder
                Expanded(
                  flex: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          width: 80,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shimmer loading for detail page
class NumDetailShimmer extends StatelessWidget {
  const NumDetailShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: numShimmerBase,
      highlightColor: numShimmerHighlight,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image carousel placeholder
            Container(
              height: 300,
              width: double.infinity,
              color: Colors.white,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title placeholder
                  Container(
                    height: 24,
                    width: double.infinity,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 24,
                    width: 200,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 16),

                  // Badges placeholder
                  Row(
                    children: [
                      Container(
                        height: 28,
                        width: 60,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 28,
                        width: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Info section placeholders
                  for (int i = 0; i < 4; i++) ...[
                    _buildInfoRow(),
                    const SizedBox(height: 16),
                  ],

                  const SizedBox(height: 24),

                  // Description placeholder
                  Container(
                    height: 16,
                    width: 150,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < 3; i++) ...[
                    Container(
                      height: 12,
                      width: double.infinity,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Container(
                    height: 12,
                    width: 200,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 12,
                width: 80,
                color: Colors.white,
              ),
              const SizedBox(height: 4),
              Container(
                height: 14,
                width: 120,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Shimmer loading for card placeholder
class NumCardShimmer extends StatelessWidget {
  final double height;
  final double width;
  final double borderRadius;

  const NumCardShimmer({
    super.key,
    this.height = 200,
    this.width = double.infinity,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: numShimmerBase,
      highlightColor: numShimmerHighlight,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Shimmer loading for horizontal scroll list
class NumHorizontalShimmer extends StatelessWidget {
  final int itemCount;
  final double itemWidth;
  final double itemHeight;

  const NumHorizontalShimmer({
    super.key,
    this.itemCount = 5,
    this.itemWidth = 150,
    this.itemHeight = 200,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemHeight,
      child: Shimmer.fromColors(
        baseColor: numShimmerBase,
        highlightColor: numShimmerHighlight,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemBuilder: (context, index) {
            return Container(
              width: itemWidth,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            );
          },
        ),
      ),
    );
  }
}
