import 'package:flutter/material.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import 'offline_network_image.dart';

// MICRO-OPTIMIZATION: Static color constants to avoid allocation on every build
class _SimilarProductsColors {
  // Colors for fire icon gradient
  static final fireGradientColors = [
    Colors.orange.shade400,
    Colors.red.shade400,
  ];

  // Shadow and overlay colors (pre-calculated opacity)
  static const fireShadowColor = Color(0x4DFF9800); // Colors.orange.withOpacity(0.3)
  static const cardShadowColor = Color(0x14000000); // Colors.black.withOpacity(0.08)
  static const imageOverlayColor = Color(0x4D000000); // Colors.black.withOpacity(0.3)
  static const imageBackgroundColor = Color(0x1A9E9E9E); // Colors.grey.withOpacity(0.1)

  // Cached badge colors
  static final cachedBadgeBackground = Colors.orange.shade100;
  static final cachedBadgeBorder = Colors.orange.shade300;
  static final cachedBadgeText = Colors.orange.shade700;
  static final cachedIconColor = Colors.orange.shade700;

  // Subtitle color (pre-calculated opacity)
  static final subtitleColor = AppColors.textPrimary.withOpacity(0.6);

  // Price badge color (pre-calculated opacity)
  static final priceBadgeBackground = AppColors.primaryColor.withOpacity(0.1);

  // Shimmer colors for loading state
  static final shimmerGrey1 = Colors.grey.shade300;
  static final shimmerGrey2 = Colors.grey.shade200;
}

/// Widget that displays a section of similar hot products
///
/// This widget shows products from the same category that are "hot"
/// (have high engagement through clicks and sales).
///
/// Features:
/// - Horizontal scrollable list of product cards
/// - Loading state with shimmer effect
/// - Offline indicator when loaded from cache
/// - Empty state when no similar products exist
/// - Elegant design with fire icon and styled title
class SimilarProductsSection extends StatelessWidget {
  final List<Post> products;
  final bool isLoading;
  final bool isLoadedFromCache;
  final Function(Post) onProductTap;

  const SimilarProductsSection({
    super.key,
    required this.products,
    required this.isLoading,
    required this.isLoadedFromCache,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    // Don't show section if loading and no products yet, or if no products at all
    if (isLoading && products.isEmpty) {
      return const SizedBox.shrink();
    }

    if (!isLoading && products.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Row(
              children: [
                // Fire icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _SimilarProductsColors.fireGradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: const [
                      BoxShadow(
                        color: _SimilarProductsColors.fireShadowColor,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Title
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Similar products that're hot",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Popular in this category',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: _SimilarProductsColors.subtitleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                // Offline indicator
                if (isLoadedFromCache)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _SimilarProductsColors.cachedBadgeBackground,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _SimilarProductsColors.cachedBadgeBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_off,
                          size: 12,
                          color: _SimilarProductsColors.cachedIconColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cached',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _SimilarProductsColors.cachedBadgeText,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Products horizontal list
          SizedBox(
            height: 240,
            child: isLoading
                ? _buildLoadingState()
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: products.length,
                    itemBuilder: (context, index) {
                      final product = products[index];
                      // MICRO-OPTIMIZATION: RepaintBoundary isolates repaints
                      return RepaintBoundary(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: _SimilarProductCard(
                            product: product,
                            onTap: () => onProductTap(product),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 3,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: _LoadingProductCard(),
        );
      },
    );
  }
}

/// Individual product card for similar products
class _SimilarProductCard extends StatelessWidget {
  final Post product;
  final VoidCallback onTap;

  const _SimilarProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            // MICRO-OPTIMIZATION: const BoxShadow with pre-calculated color
            BoxShadow(
              color: _SimilarProductsColors.cardShadowColor,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: const BoxDecoration(
                  // MICRO-OPTIMIZATION: const color
                  color: _SimilarProductsColors.imageBackgroundColor,
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    OfflineNetworkImage(
                      imageUrl: product.images.isNotEmpty
                          ? product.images.first
                          : 'https://picsum.photos/seed/${product.id}/400/400',
                      fit: BoxFit.cover,
                    ),
                    // Gradient overlay for better text readability
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: const BoxDecoration(
                          // MICRO-OPTIMIZATION: const gradient with pre-calculated colors
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              _SimilarProductsColors.imageOverlayColor,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Product info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product title
                    Text(
                      product.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    // Price
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        // MICRO-OPTIMIZATION: pre-calculated color
                        color: _SimilarProductsColors.priceBadgeBackground,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '\$${(product.price / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading skeleton for similar product card
class _LoadingProductCard extends StatefulWidget {
  @override
  State<_LoadingProductCard> createState() => _LoadingProductCardState();
}

class _LoadingProductCardState extends State<_LoadingProductCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MICRO-OPTIMIZATION: Extract static content as child to prevent rebuilds
    return AnimatedBuilder(
      animation: _controller,
      child: _buildStaticSkeletonContent(),
      builder: (context, staticContent) {
        return Container(
          width: 160,
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D000000), // black.withOpacity(0.05)
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image skeleton with animated shimmer
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _SimilarProductsColors.shimmerGrey1,
                        _SimilarProductsColors.shimmerGrey2,
                        _SimilarProductsColors.shimmerGrey1,
                      ],
                      stops: [
                        (_controller.value - 0.3).clamp(0.0, 1.0),
                        _controller.value.clamp(0.0, 1.0),
                        (_controller.value + 0.3).clamp(0.0, 1.0),
                      ],
                    ),
                  ),
                ),
              ),
              // Static content (text placeholders) - reused without rebuilding
              Expanded(child: staticContent!),
            ],
          ),
        );
      },
    );
  }

  // MICRO-OPTIMIZATION: Build static skeleton elements once
  Widget _buildStaticSkeletonContent() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title lines
          Container(
            height: 14,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _SimilarProductsColors.shimmerGrey1,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 14,
            width: 100,
            decoration: BoxDecoration(
              color: _SimilarProductsColors.shimmerGrey1,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          // Price skeleton
          Container(
            height: 24,
            width: 60,
            decoration: BoxDecoration(
              color: _SimilarProductsColors.shimmerGrey1,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
