import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';
import '../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Post> highlightedProducts = [];
  List<Post> newProducts = [];
  bool isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  String? _lastSearchQuery;
  List<Post> filteredNewProducts = [];

  bool get _hasSearchQuery => (_lastSearchQuery?.isNotEmpty ?? false);

  String _formatDollars(int cents) => '\$' + (cents / 100).toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchSubmitted(String value) {
    _applySearch(value);
  }

  void _onSearchChanged(String value) {
    if (value.isEmpty && _hasSearchQuery) {
      setState(() {
        _lastSearchQuery = null;
        filteredNewProducts = List<Post>.from(newProducts);
      });
    }
  }

  void _applySearch(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _lastSearchQuery = null;
        filteredNewProducts = List<Post>.from(newProducts);
      });
      return;
    }

    setState(() {
      _lastSearchQuery = trimmed;
      filteredNewProducts = _filterProducts(trimmed);
    });
  }

  List<Post> _filterProducts(String query) {
    final lowerQuery = query.toLowerCase();
    return newProducts.where((post) {
      final titleMatches = post.title.toLowerCase().contains(lowerQuery);
      final descriptionMatches =
          post.description.toLowerCase().contains(lowerQuery);
      return titleMatches || descriptionMatches;
    }).toList();
  }

  String? _resolveCategoryName(String? rawCategory) {
    if (rawCategory == null) return null;
    final trimmed = rawCategory.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('/')) return trimmed;
    final parts = trimmed.split('/');
    return parts.isNotEmpty ? parts.last : trimmed;
  }

  void _logProductClick({
    required String productId,
    required String categoryId,
    required String source,
    String? searchQuery,
  }) {
    final categoryName = _resolveCategoryName(categoryId);
    FirestoreService.logProductSearchEvent(
      source: source,
      query: searchQuery,
      selectedCategory: categoryName,
      suggestedCategories:
          categoryName != null ? <String>[categoryName] : <String>[],
    );
  }

  Future<void> _loadProducts() async {
    try {
      final highlighted = await FirestoreService.getHighlightedPosts();
      final newProds = await FirestoreService.getNewPosts();

      setState(() {
        highlightedProducts = highlighted;
        newProducts = newProds;
        filteredNewProducts = List<Post>.from(newProds);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadProducts,
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
                            itemCount: highlightedProducts.length,
                            itemBuilder: (context, index) {
                              final product = highlightedProducts[index];
                              return Container(
                                width: 180,
                                margin: const EdgeInsets.only(right: 16),
                                child: ProductCard(
                                  product: product,
                                  onTap: () {
                                    print(
                                        'Navigating to highlighted product: ID=${product.id}');
                                    _logProductClick(
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

                  const SliverToBoxAdapter(
                    child: SizedBox(height: 30),
                  ),

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
                    itemCount: filteredNewProducts.length,
                    itemBuilder: (context, index) {
                      final product = filteredNewProducts[index];
                      final imageUrl = product.images.isNotEmpty
                          ? product.images.first
                          : 'https://picsum.photos/seed/${product.id}/300/200';
                      return InkWell(
                        onTap: () {
                          print('Navigating to product: ID=${product.id}');
                          _logProductClick(
                            productId: product.id,
                            categoryId: product.categoryId,
                            source: _lastSearchQuery != null
                                ? 'search_bar'
                                : 'home_feed',
                            searchQuery: _lastSearchQuery,
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
                                      _formatDollars(product.price),
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
  }
}
