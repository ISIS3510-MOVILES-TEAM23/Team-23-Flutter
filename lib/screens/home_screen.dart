import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../theme/app_colors.dart';
import '../widgets/product_card.dart';
import '../view_models/home_view_model.dart';
import '../widgets/offline_network_image.dart';

// 👇 NUEVO: para traer las recomendaciones y el tipo Post
import '../services/recommendation_service.dart';
import '../models/models.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  late HomeViewModel viewModel;

  // 👇 NUEVO: future para "Recommended for you"
  Future<List<Post>>? _recsFuture;

  @override
  void initState() {
    super.initState();
    viewModel = HomeViewModel();
    viewModel.loadProducts();
    viewModel.loadNearbyProducts(limit: 10); // Load nearby products

    // 👇 NUEVO: inic. de recomendaciones (con logs internos activados)
    _recsFuture = RecommendationService()
        .fetchRecommendations(limit: 5, windowDays: 30, debug: true);

    // Scenario 5: Listen for connectivity changes and auto-reload
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    viewModel.connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && viewModel.isOffline) {
        // Connection restored - auto reload
        debugPrint('[Home] 🟢 Connection restored - auto-reloading');
        viewModel.loadProducts();
        viewModel.loadNearbyProducts(limit: 10);
        setState(() {
          _recsFuture = RecommendationService()
              .fetchRecommendations(limit: 5, windowDays: 30, debug: true);
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    viewModel.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String value) {
    viewModel.applySearch(value);
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty && viewModel.hasSearchQuery) {
      viewModel.clearSearch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Column(
            children: [
              // Offline banner removed - now global in main.dart
              Expanded(
                child: viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : viewModel.filteredNewProducts.isEmpty &&
                            viewModel.isOffline
                        ? _buildFirstTimeOfflineFallback(context) // Scenario 4
                        : RefreshIndicator(
                            // Refresca productos, major-based, nearby y recomendaciones
                            // forceRefresh: true bypasses LRU cache for fresh data
                            onRefresh: () async {
                              await viewModel.loadProducts();
                              await viewModel.loadMajorBasedProducts(forceRefresh: true); // LRU bypass
                              await viewModel.loadNearbyProducts(
                                  limit: 10); // Refresh nearby products
                              setState(() {
                                _recsFuture = RecommendationService()
                                    .fetchRecommendations(
                                        limit: 5, 
                                        windowDays: 30, 
                                        debug: true,
                                        forceRefresh: true); // LRU bypass
                              });
                              // (opcional) espera a que termine
                              await _recsFuture;
                            },
                            child: CustomScrollView(
                              slivers: [
                                // App header
                                SliverAppBar(
                                  pinned: true,
                                  centerTitle: true,
                                  title: const Text('Marketplace'),
                                  actions: [
                                    IconButton(
                                      onPressed: () =>
                                          context.go('/home/wishlist'),
                                      icon: const Icon(Icons.favorite_border),
                                    ),
                                  ],
                                  backgroundColor: Theme.of(context)
                                      .appBarTheme
                                      .backgroundColor,
                                ),
                                // Search Bar
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        20, 16, 20, 8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 16),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).cardTheme.color,
                                        borderRadius: BorderRadius.circular(12),
                                        // No border for ultra-minimal look
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.search,
                                            color: AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: TextField(
                                              controller: _searchController,
                                              decoration: InputDecoration(
                                                hintText:
                                                    'Search for products...',
                                                hintStyle: TextStyle(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                border: InputBorder
                                                    .none, // no underline or divider
                                              ),
                                              textInputAction:
                                                  TextInputAction.search,
                                              onChanged: _onSearchChanged,
                                              onSubmitted: _onSearchSubmitted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),

                                // Major-Based Products Section (Popular en tu carrera) - Hide when offline
                                if (!viewModel.isOffline)
                                  SliverToBoxAdapter(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.school,
                                                size: 20,
                                                color: AppColors.primaryColor,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  viewModel.majorBasedTitle ??
                                                      'Featured',
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 240,
                                          child: viewModel.isLoadingMajorBased
                                              ? const Center(
                                                  child:
                                                      CircularProgressIndicator())
                                              : viewModel.majorBasedProducts
                                                      .isEmpty
                                                  ? const Center(
                                                      child: Text(
                                                        'No posts available yet',
                                                        style: TextStyle(
                                                            color: AppColors
                                                                .textSecondary),
                                                      ),
                                                    )
                                                  : ListView.builder(
                                                      scrollDirection:
                                                          Axis.horizontal,
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                          horizontal: 20),
                                                      itemCount: viewModel
                                                          .majorBasedProducts
                                                          .length,
                                                      itemBuilder:
                                                          (context, index) {
                                                        final product = viewModel
                                                                .majorBasedProducts[
                                                            index];
                                                        return Container(
                                                          width: 180,
                                                          margin:
                                                              const EdgeInsets
                                                                  .only(
                                                                  right: 16),
                                                          child: ProductCard(
                                                            product: product,
                                                            onTap: () {
                                                              viewModel
                                                                  .logProductClick(
                                                                productId:
                                                                    product.id,
                                                                categoryId: product
                                                                    .categoryId,
                                                                source:
                                                                    'major_based_carousel',
                                                                ownerId: product
                                                                    .userId,
                                                              );
                                                              context.go(
                                                                  '/home/product/${product.id}');
                                                            },
                                                          ),
                                                        );
                                                      },
                                                    ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // 🔻 NUEVO: Created near you
                                if (viewModel.nearbyProducts.isNotEmpty) ...[
                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 24)),
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.location_on,
                                            color: Colors.green.shade600,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          const Text(
                                            'Created near you',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 12)),
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: 240,
                                      child: viewModel.isLoadingNearbyProducts
                                          ? const Center(
                                              child:
                                                  CircularProgressIndicator())
                                          : ListView.builder(
                                              scrollDirection: Axis.horizontal,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 20),
                                              itemCount: viewModel
                                                  .nearbyProducts.length,
                                              itemBuilder: (context, index) {
                                                final product = viewModel
                                                    .nearbyProducts[index];
                                                return Container(
                                                  width: 180,
                                                  margin: const EdgeInsets.only(
                                                      right: 16),
                                                  child: ProductCard(
                                                    product: product,
                                                    onTap: () {
                                                      viewModel.logProductClick(
                                                        productId: product.id,
                                                        categoryId:
                                                            product.categoryId,
                                                        source:
                                                            'nearby_carousel',
                                                        ownerId: product.userId,
                                                      );
                                                      context.go(
                                                          '/home/product/${product.id}');
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                    ),
                                  ),
                                ],
                                // 🔺 FIN Created near you

                                // 🔻 NUEVO: Recommended for you (usa _recsFuture) - Hide when offline
                                if (!viewModel.isOffline) ...[
                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 24)),
                                  SliverToBoxAdapter(
                                    child: const Padding(
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 20),
                                      child: Text(
                                        'Based on your recent activity',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 12)),
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: 240,
                                      child: FutureBuilder<List<Post>>(
                                        future: _recsFuture,
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return const Center(
                                                child:
                                                    CircularProgressIndicator());
                                          }
                                          if (snapshot.hasError) {
                                            return const Center(
                                                child: Text(
                                                    'Error loading recommendations'));
                                          }
                                          final items =
                                              snapshot.data ?? const <Post>[];

                                          // Log simple de IDs finales (además del debug interno del service)
                                          if (items.isNotEmpty) {
                                            debugPrint('[Reco] final ids: '
                                                '${items.map((p) => p.id).join(', ')}');
                                          }

                                          if (items.isEmpty) {
                                            return const Center(
                                              child: Text(
                                                  'No recommendations yet'),
                                            );
                                          }

                                          return ListView.builder(
                                            scrollDirection: Axis.horizontal,
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 20),
                                            itemCount: items.length,
                                            itemBuilder: (context, index) {
                                              final product = items[index];
                                              return Container(
                                                width: 180,
                                                margin: const EdgeInsets.only(
                                                    right: 16),
                                                child: ProductCard(
                                                  product: product,
                                                  onTap: () {
                                                    // Log para analytics y navegación
                                                    viewModel.logProductClick(
                                                      productId: product.id,
                                                      categoryId:
                                                          product.categoryId,
                                                      source: 'recommended',
                                                      ownerId: product.userId,
                                                    );
                                                    context.go(
                                                        '/home/product/${product.id}');
                                                  },
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SliverToBoxAdapter(
                                      child: SizedBox(height: 30)),
                                ],
                                // 🔺 FIN Recommended

                                // New Products Section
                                SliverToBoxAdapter(
                                  child: const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 20),
                                    child: Text(
                                      'New Posts',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 12),
                                ),

                                // New Products List (full width)
                                SliverList.builder(
                                  itemCount:
                                      viewModel.filteredNewProducts.length,
                                  itemBuilder: (context, index) {
                                    final product =
                                        viewModel.filteredNewProducts[index];
                                    final imageUrl = product.images.isNotEmpty
                                        ? product.images.first
                                        : 'https://picsum.photos/seed/${product.id}/300/200';
                                    return InkWell(
                                      onTap: () {
                                        viewModel.logProductClick(
                                          productId: product.id,
                                          categoryId: product.categoryId,
                                          source: viewModel.hasSearchQuery
                                              ? 'search_bar'
                                              : 'home_feed',
                                          searchQuery:
                                              viewModel.lastSearchQuery,
                                          ownerId: product.userId,
                                        );
                                        context
                                            .go('/home/product/${product.id}');
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.fromLTRB(
                                            20, 12, 20, 0),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(context).cardTheme.color,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          // Remove border to keep it minimal
                                        ),
                                        child: Row(
                                          children: [
                                            // Text section 2/3
                                            Expanded(
                                              flex: 2,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    product.title,
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Text(
                                                    product.description,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: AppColors
                                                          .textPrimary
                                                          .withOpacity(0.8),
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    viewModel.formatDollars(
                                                        product.price),
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          AppColors.textPrimary,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Image section 1/3
                                            Expanded(
                                              flex: 1,
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: AspectRatio(
                                                  aspectRatio: 1,
                                                  child: OfflineNetworkImage(
                                                    imageUrl: imageUrl,
                                                    fit: BoxFit.cover,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                                const SliverToBoxAdapter(
                                  child: SizedBox(height: 20),
                                ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Scenario 4: First-time offline fallback
  Widget _buildFirstTimeOfflineFallback(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off,
              size: 80,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Internet connection required',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Please connect to start exploring products.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: viewModel.loadProducts,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
