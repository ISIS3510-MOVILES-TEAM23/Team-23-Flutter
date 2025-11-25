import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../view_models/product_detail_view_model.dart';
import '../widgets/offline_network_image.dart';
import '../widgets/rating_widget.dart';
import '../widgets/similar_products_section.dart';
import '../services/connectivity_service.dart';

class ProductDetailScreen extends StatefulWidget {
  final String productId;

  const ProductDetailScreen({
    super.key,
    required this.productId,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late ProductDetailViewModel viewModel;
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  void initState() {
    super.initState();
    viewModel = ProductDetailViewModel();
    viewModel.loadProduct(widget.productId);
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  Future<void> _initiateChat() async {
    if (viewModel.product == null || viewModel.seller == null) return;

    // You can't chat with yourself
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser?.uid == viewModel.seller!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You cannot chat with yourself')),
      );
      return;
    }

    // Scenario 10: Check if offline and no existing chat
    if (!_connectivity.isConnected && !viewModel.hasExistingChat) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Cannot start new chat while offline. Please connect to internet to contact this seller.'),
          backgroundColor: Colors.orange.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      final chatId = await viewModel.initiateChat();
      if (mounted) {
        context.push(
          '/chat',
          extra: {
            'chatId': chatId,
            'productId': viewModel.product!.id,
            'sellerId': viewModel.seller!.id,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting chat: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        if (viewModel.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (viewModel.product == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(
              child: Text('Product not found'),
            ),
          );
        }

        final product = viewModel.product!;
        final seller = viewModel.seller;

        final currentUser = auth.FirebaseAuth.instance.currentUser;
        final isOwnProduct = currentUser?.uid == product.userId;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Product Detail'),
            elevation: 0,
            actions: [
              if (!isOwnProduct)
                IconButton(
                  onPressed: () async {
                    final success = await viewModel.toggleWishList();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            success
                                ? (viewModel.isInWishList
                                    ? 'Added to wish list'
                                    : 'Removed from wish list')
                                : 'Failed to update wish list',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    viewModel.isInWishList
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: viewModel.isInWishList ? Colors.red : null,
                  ),
                ),
            ],
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image carousel
                        if (product.images.isNotEmpty) ...[
                          SizedBox(
                            height: 260,
                            width: double.infinity,
                            child: Stack(
                              children: [
                                PageView.builder(
                                  itemCount: product.images.length,
                                  onPageChanged: viewModel.setCurrentImageIndex,
                                  itemBuilder: (context, index) => ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: OfflineNetworkImage(
                                      imageUrl: product.images[index],
                                      width: double.infinity,
                                      height: 260,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                if (product.images.length > 1)
                                  Positioned(
                                    bottom: 12,
                                    left: 0,
                                    right: 0,
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: List.generate(
                                        product.images.length,
                                        (i) => AnimatedContainer(
                                          duration:
                                              const Duration(milliseconds: 200),
                                          margin: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          width:
                                              viewModel.currentImageIndex == i
                                                  ? 10
                                                  : 8,
                                          height:
                                              viewModel.currentImageIndex == i
                                                  ? 10
                                                  : 8,
                                          decoration: BoxDecoration(
                                            color:
                                                viewModel.currentImageIndex == i
                                                    ? Colors.white
                                                    : Colors.white
                                                        .withOpacity(0.6),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black
                                                    .withOpacity(0.2),
                                                blurRadius: 3,
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        // Title
                        Text(
                          product.title,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Description (no label)
                        Text(
                          product.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary.withOpacity(0.87),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Price label and value
                        const Text(
                          'Price',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          viewModel.formatDollars(product.price),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Seller section
                        const Text(
                          'Seller',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundImage: NetworkImage(
                                'https://picsum.photos/seed/${seller?.id ?? product.userId}/100/100',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    seller?.name ?? product.userId,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (seller?.hasRating ?? false) ...[
                                    const SizedBox(height: 4),
                                    RatingWidget(
                                      rating: seller!.score!,
                                      totalRatings: seller.numberOfReviews!,
                                      size: 14,
                                      showText: true,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),

                  // Similar products section
                  SimilarProductsSection(
                    products: viewModel.similarProducts,
                    isLoading: viewModel.isLoadingSimilarProducts,
                    isLoadedFromCache:
                        viewModel.isSimilarProductsLoadedFromCache,
                    onProductTap: (product) {
                      context.push('/home/product/${product.id}');
                    },
                    onSeeAllTap: viewModel.product != null
                        ? () {
                            // Navigate to hot products screen with category info
                            final categoryId = viewModel.product!.categoryId;
                            // Encode categoryId to handle special characters and slashes
                            final encodedCategoryId = Uri.encodeComponent(categoryId);
                            context.push(
                              '/home/hot-products/$encodedCategoryId',
                            );
                          }
                        : null,
                  ),

                  // Chat button (fixed at bottom)
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: product.status == 'active' &&
                                (_connectivity.isConnected ||
                                    viewModel.hasExistingChat)
                            ? _initiateChat
                            : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: product.status == 'active' &&
                                  (_connectivity.isConnected ||
                                      viewModel.hasExistingChat)
                              ? AppColors.primaryColor
                              : AppColors.textSecondary,
                        ),
                        child: Text(
                          product.status != 'active'
                              ? 'Not available'
                              : (!_connectivity.isConnected &&
                                      !viewModel.hasExistingChat)
                                  ? 'Offline - Cannot start chat'
                                  : 'Chat with seller',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
