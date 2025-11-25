import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../view_models/hot_category_view_model.dart';
import '../widgets/offline_network_image.dart';

/// Screen that displays all hot products from a specific category
///
/// Features:
/// - Grid layout for products
/// - Offline support with cached data
/// - Loading, error, and empty states
/// - Pull-to-refresh
/// - Performance optimizations with RepaintBoundary
class HotCategoryScreen extends StatefulWidget {
  final String categoryId;
  final String? categoryName;

  const HotCategoryScreen({
    super.key,
    required this.categoryId,
    this.categoryName,
  });

  @override
  State<HotCategoryScreen> createState() => _HotCategoryScreenState();
}

class _HotCategoryScreenState extends State<HotCategoryScreen> {
  late HotCategoryViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = HotCategoryViewModel();
    // Load products after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _viewModel.loadHotProducts(categoryId: widget.categoryId);
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.local_fire_department,
                    color: Colors.orange.shade600,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Hot Trends',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Text(
                _getCategoryDisplayName(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textPrimary.withOpacity(0.6),
                ),
              ),
            ],
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => context.pop(),
          ),
        ),
        body: Consumer<HotCategoryViewModel>(
          builder: (context, viewModel, child) {
            // Use global offline banner instead of local one
            return _buildBody(viewModel);
          },
        ),
      ),
    );
  }

  Widget _buildBody(HotCategoryViewModel viewModel) {
    if (viewModel.isLoading && viewModel.products.isEmpty) {
      return _buildLoadingState();
    }

    if (viewModel.hasError) {
      return _buildErrorState(viewModel);
    }

    if (viewModel.isEmpty) {
      return _buildEmptyState();
    }

    return _buildProductGrid(viewModel);
  }

  Widget _buildLoadingState() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return _LoadingProductCard();
      },
    );
  }

  Widget _buildErrorState(HotCategoryViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Oops!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => viewModel.refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.local_fire_department_outlined,
              size: 64,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No Hot Products Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Products in this category haven\'t gained popularity yet. Check back later!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductGrid(HotCategoryViewModel viewModel) {
    return RefreshIndicator(
      onRefresh: () => viewModel.refresh(),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: viewModel.products.length,
        itemBuilder: (context, index) {
          final product = viewModel.products[index];
          // OPTIMIZATION: RepaintBoundary isolates repaints
          return RepaintBoundary(
            child: _HotProductCard(
              product: product,
              rank: index + 1,
              onTap: () => _navigateToProduct(product.id),
            ),
          );
        },
      ),
    );
  }

  void _navigateToProduct(String productId) {
    context.push('/home/product/$productId');
  }

  String _getCategoryDisplayName() {
    if (widget.categoryName != null && widget.categoryName!.isNotEmpty) {
      return widget.categoryName!;
    }

    // Extract name from path (e.g., "categories/electronics" -> "Electronics")
    final parts = widget.categoryId.split('/');
    final name = parts.isNotEmpty ? parts.last : widget.categoryId;
    return name.substring(0, 1).toUpperCase() + name.substring(1);
  }
}

/// Individual product card for hot products grid
class _HotProductCard extends StatelessWidget {
  final Post product;
  final int rank;
  final VoidCallback onTap;

  const _HotProductCard({
    required this.product,
    required this.rank,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product image with rank badge
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: Stack(
                children: [
                  Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.grey.withOpacity(0.1),
                    child: OfflineNetworkImage(
                      imageUrl: product.images.isNotEmpty
                          ? product.images.first
                          : 'https://picsum.photos/seed/${product.id}/400/400',
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Rank badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.orange.shade400,
                            Colors.red.shade400,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department,
                            color: Colors.white,
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '#$rank',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Bottom gradient overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.3),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
                        color: AppColors.primaryColor.withOpacity(0.1),
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

/// Loading skeleton for product card
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
    return AnimatedBuilder(
      animation: _controller,
      child: _buildStaticContent(),
      builder: (context, staticContent) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                  height: 160,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.grey.shade300,
                        Colors.grey.shade200,
                        Colors.grey.shade300,
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
              // Static content
              Expanded(child: staticContent!),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaticContent() {
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
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 14,
            width: 100,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          // Price skeleton
          Container(
            height: 24,
            width: 60,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ],
      ),
    );
  }
}
