import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../widgets/product_card.dart';
import '../view_models/home_view_model.dart';

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

    // 👇 NUEVO: inic. de recomendaciones (con logs internos activados)
    _recsFuture = RecommendationService()
        .fetchRecommendations(limit: 5, windowDays: 30, debug: true);
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
          body: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  // 👇 NUEVO: refresca productos y recomendaciones
                  onRefresh: () async {
                    await viewModel.loadProducts();
                    setState(() {
                      _recsFuture = RecommendationService()
                          .fetchRecommendations(
                              limit: 5, windowDays: 30, debug: true);
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
                        onPressed: () => context.go('/home/notifications'),
                        icon: const Icon(Icons.notifications_outlined),
                      ),
                    ],
                    backgroundColor:
                        Theme.of(context).appBarTheme.backgroundColor,
                  ),
                  // Search Bar
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
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
                                  hintText: 'Search for products...',
                                  hintStyle: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                  border: InputBorder
                                      .none, // no underline or divider
                                ),
                                textInputAction: TextInputAction.search,
                                onChanged: _onSearchChanged,
                                onSubmitted: _onSearchSubmitted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Highlighted Products Section
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Highlighted Products for you!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 240,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: viewModel.highlightedProducts.length,
                        itemBuilder: (context, index) {
                          final product = viewModel.highlightedProducts[index];
                          return Container(
                            width: 180,
                            margin: const EdgeInsets.only(right: 16),
                            child: ProductCard(
                              product: product,
                              onTap: () {
                                viewModel.logProductClick(
                                  productId: product.id,
                                  categoryId: product.categoryId,
                                  source: 'highlighted_carousel',
                                );
                                context.go('/home/product/${product.id}');
                              },
                            ),
                          );
                        },
                      ),
                        ),
                      ],
                    ),
                  ),

                  // 🔻 NUEVO: Recommended for you (usa _recsFuture)
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Text(
                        'Recommended for you',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 240,
                      child: FutureBuilder<List<Post>>(
                        future: _recsFuture,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return const Center(
                                child: Text('Error loading recommendations'));
                          }
                          final items = snapshot.data ?? const <Post>[];

                          // Log simple de IDs finales (además del debug interno del service)
                          if (items.isNotEmpty) {
                            debugPrint('[Reco] final ids: '
                                '${items.map((p) => p.id).join(', ')}');
                          }

                          if (items.isEmpty) {
                            return const Center(
                              child: Text('No recommendations yet'),
                            );
                          }

                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: items.length,
                            itemBuilder: (context, index) {
                              final product = items[index];
                              return Container(
                                width: 180,
                                margin: const EdgeInsets.only(right: 16),
                                child: ProductCard(
                                  product: product,
                                  onTap: () {
                                    // Log para analytics y navegación
                                    viewModel.logProductClick(
                                      productId: product.id,
                                      categoryId: product.categoryId,
                                      source: 'recommended',
                                    );
                                    context
                                        .go('/home/product/${product.id}');
                                  },
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 30)),
                  // 🔺 FIN Recommended

                  // New Products Section
                  SliverToBoxAdapter(
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
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
                    itemCount: viewModel.filteredNewProducts.length,
                    itemBuilder: (context, index) {
                      final product = viewModel.filteredNewProducts[index];
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
                            searchQuery: viewModel.lastSearchQuery,
                          );
                          context.go('/home/product/${product.id}');
                        },
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(12),
                            // Remove border to keep it minimal
                          ),
                          child: Row(
                            children: [
                              // Text section 2/3
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      product.title,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      product.description,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textPrimary
                                            .withOpacity(0.8),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      viewModel.formatDollars(product.price),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
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
                                  borderRadius: BorderRadius.circular(8),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Image.network(
                                      imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                        return Container(
                                          color: Colors.grey.withOpacity(0.1),
                                          child: Icon(
                                            Icons.image_outlined,
                                            size: 32,
                                            color: AppColors.textSecondary
                                                .withOpacity(0.3),
                                          ),
                                        );
                                      },
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
        );
      },
    );
  }
}
