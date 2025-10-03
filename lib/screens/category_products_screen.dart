import 'package:campus_marketplace/services/product_filters_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart';
import '../services/filters_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_colors.dart';

const double kNoMaxUsd = 100000000;

class CategoryProductsScreen extends StatefulWidget {
  final String categoryId;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  List<Post> products = [];
  List<Category> categories = [];
  bool isLoading = true;
  bool _categoryLogged = false;

  // Filter variables
  RangeValues priceRange = const RangeValues(0, kNoMaxUsd);
  String sortBy = 'newest';
  String statusFilter = 'active';

  // Filters service
  late FiltersContext filtersContext;

  String _formatDollars(int cents) => '\$' + (cents / 100).toStringAsFixed(2);
  String get categoryName => widget.categoryId;

  @override
  void initState() {
    super.initState();
    filtersContext = FiltersContext(categoryId: widget.categoryId);
    _loadData();
  }

  void _setFilterService() {
    switch (sortBy) {
      case 'price_low':
        filtersContext.setFilterService(PriceAscendingFilterService());
        break;
      case 'price_high':
        filtersContext.setFilterService(PriceDescendingFilterService());
        break;
      case 'newest':
      case 'popular':
      default:
        filtersContext.setFilterService(NoFilterService());
        break;
    }
  }

  Future<void> _loadData() async {
    try {
      final cats = await FirestoreService.getCategories();
<<<<<<< Updated upstream

      final prods = await ProductFiltersService.getPostsByCategory(
        widget.categoryId,
        filters: FilterOptions(
          minPrice: priceRange.start,
          maxPrice: priceRange.end,
          sortBy: sortBy, // 'newest' | 'price_low' | 'price_high'
        ),
        statusParam: statusFilter,
      );
=======
      print(
          'CategoryProductsScreen: Loaded ${cats.length} categories'); // Debug

      // Find the actual category document ID
      final category = cats.firstWhere(
        (c) => c.id == widget.categoryId || c.name == widget.categoryId,
        orElse: () => Category(id: widget.categoryId, name: widget.categoryId, description: ''),
      );

      // Update filters context with correct category ID
      filtersContext = FiltersContext(categoryId: category.id);
      
      // Set the appropriate filter service
      _setFilterService();

      // Get filtered posts using the filters service
      List<Post> filteredPosts = await filtersContext.filter();

      // Apply price range filter client-side if not default
      if (priceRange.start > 0 || priceRange.end < 1000) {
        filteredPosts = filteredPosts.where((post) {
          final priceInDollars = post.price / 100.0;
          return priceInDollars >= priceRange.start && priceInDollars <= priceRange.end;
        }).toList();
      }

      // For "newest", sort by created_at descending
      if (sortBy == 'newest') {
        filteredPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }
      // For "popular", we could sort by some popularity metric, but for now keep as is

      print(
          'CategoryProductsScreen: Received ${filteredPosts.length} products'); // Debug
>>>>>>> Stashed changes

      if (!mounted) return;
      setState(() {
        categories = cats;
        products = filteredPosts;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
    }
    if (!_categoryLogged) {
      _categoryLogged = true;
      ProductFiltersService.logFilterUsed('category');
    }
  }

  void _showPriceRangeDialog() {
    final startText =
        (priceRange.start == 0) ? '' : priceRange.start.toStringAsFixed(0);
    final endText =
        (priceRange.end == kNoMaxUsd) ? '' : priceRange.end.toStringAsFixed(0);

    final minCtrl = TextEditingController(text: startText);
    final maxCtrl = TextEditingController(text: endText);
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Price Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Min
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Min',
                        hintText: 'e.g. 10',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Max
                  Expanded(
                    child: TextField(
                      controller: maxCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Max',
                        hintText: 'e.g. 500',
                      ),
                    ),
                  ),
                ],
              ),
              if (errorMsg != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMsg!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                double? minUsd = _parseUsd(minCtrl.text);
                double? maxUsd = _parseUsd(maxCtrl.text);

                // Si ambas cajas vacías → sin filtro
                if (minUsd == null && maxUsd == null) {
                  setState(() {
                    priceRange = const RangeValues(0, kNoMaxUsd);
                  });
                  Navigator.pop(context);
                  _loadData();
                  return;
                }
                minUsd ??= 0;
                maxUsd ??= kNoMaxUsd;
                if (minUsd < 0) minUsd = 0;
                if (maxUsd <= 0) maxUsd = kNoMaxUsd;

                if (minUsd > maxUsd) {
                  final tmp = minUsd;
                  minUsd = maxUsd;
                  maxUsd = tmp;
                }

                setState(() {
                  priceRange = RangeValues(minUsd!, maxUsd!);
                });
                Navigator.pop(context);
                ProductFiltersService.logFilterUsed('price');
                _loadData();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  double? _parseUsd(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    final normalized = t.replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String _rangeLabel() {
    if (priceRange.start == 0 && priceRange.end == kNoMaxUsd) return 'Price';

    String fmt(double v) {
      if (v >= 1000000) return '\$${(v / 1000000).toStringAsFixed(1)}M';
      if (v >= 1000)
        return '\$${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
      return '\$${v.round()}';
    }

    final start = fmt(priceRange.start);
    final end = (priceRange.end == kNoMaxUsd) ? '∞' : fmt(priceRange.end);
    return '$start - $end';
  }

  @override
  Widget build(BuildContext context) {
    print(
        'CategoryProductsScreen: Building with categoryId: ${widget.categoryId}');
    print(
        'CategoryProductsScreen: Available categories: ${categories.map((c) => 'ID:${c.id}, Name:${c.name}').join(', ')}');

    final category = categories.firstWhere(
      (c) => c.id == widget.categoryId || c.name == widget.categoryId,
      orElse: () => Category(
          id: widget.categoryId, name: widget.categoryId, description: ''),
    );

    print(
        'CategoryProductsScreen: Using category - ID: ${category.id}, Name: ${category.name}');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(category.name),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filter Section
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // Price Filter (TextFields dialog)
                      Expanded(
                        child: InkWell(
                          onTap: _showPriceRangeDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.attach_money,
                                    size: 18,
                                    color:
                                        AppColors.textPrimary.withOpacity(0.7)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _rangeLabel(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.textPrimary
                                          .withOpacity(0.8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButton<String>(
                            value: statusFilter,
                            isExpanded: true,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(
                                  value: 'active', child: Text('Active')),
                              DropdownMenuItem(
                                  value: 'sold', child: Text('Sold')),
                              DropdownMenuItem(
                                  value: 'reserved', child: Text('Reserved')),
                              DropdownMenuItem(
                                  value: 'all', child: Text('All')),
                            ],
                            onChanged: (value) {
                              setState(() => statusFilter = value!);
                              ProductFiltersService.logFilterUsed('status');
                              _loadData();
                            },
                          ),
                        ),
                      ),
                      // Sort Filter
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButton<String>(
                            value: sortBy,
                            isExpanded: true,
                            underline: const SizedBox(),
                            icon: Icon(
                              Icons.keyboard_arrow_down,
                              color: AppColors.textPrimary.withOpacity(0.5),
                              size: 20,
                            ),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary.withOpacity(0.8),
                            ),
                            dropdownColor: Theme.of(context).cardTheme.color,
                            items: const [
                              DropdownMenuItem(
                                  value: 'newest', child: Text('Newest')),
                              DropdownMenuItem(
<<<<<<< Updated upstream
                                  value: 'price_low', child: Text('Price ↑')),
                              DropdownMenuItem(
                                  value: 'price_high', child: Text('Price ↓')),
=======
                                value: 'price_low',
                                child: Text('Price low to high'),
                              ),
                              DropdownMenuItem(
                                value: 'price_high',
                                child: Text('Price high to low'),
                              ),
                              DropdownMenuItem(
                                value: 'popular',
                                child: Text('Popular'),
                              ),
>>>>>>> Stashed changes
                            ],
                            onChanged: (value) {
                              setState(() => sortBy = value!);
                              ProductFiltersService.logFilterUsed('sort');
                              _loadData();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Clear Filters Button
                      InkWell(
                        onTap: () {
                          setState(() {
                            priceRange = const RangeValues(0, kNoMaxUsd);
                            sortBy = 'newest';
                            statusFilter = 'active';
                          });
                          ProductFiltersService.logFilterUsed('clear');
                          _loadData();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.clear_all,
                            size: 20,
                            color: AppColors.textPrimary.withOpacity(0.6),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Products Grid
                Expanded(
                  child: products.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: AppColors.textSecondary.withOpacity(0.5),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No products found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Try adjusting your filters',
                                style: TextStyle(
                                  fontSize: 14,
                                  color:
                                      AppColors.textSecondary.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.7,
                          ),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            final imageUrl = product.images.isNotEmpty
                                ? product.images.first
                                : 'https://picsum.photos/seed/${product.id}/300/300';

                            return InkWell(
                              onTap: () {
                                print(
                                    'Navigating to product: ${product.id} from category: ${widget.categoryId}');
                                FirestoreService.logProductSearchEvent(
                                  source: 'category_chip',
                                  selectedCategory: category.name,
                                  suggestedCategories: [category.name],
                                );
                                context.go(
                                    '/categories/${widget.categoryId}/product/${product.id}');
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardTheme.color,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Product Image
                                    Expanded(
                                      flex: 3,
                                      child: ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(12)),
                                        child: Container(
                                          width: double.infinity,
                                          color: Colors.grey.withOpacity(0.1),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey
                                                    .withOpacity(0.1),
                                                child: Icon(
                                                  Icons.image_outlined,
                                                  size: 40,
                                                  color: AppColors.textSecondary
                                                      .withOpacity(0.3),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Product Details
                                    Expanded(
                                      flex: 2,
                                      child: Padding(
                                        padding: const EdgeInsets.all(12),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            // Title
                                            Text(
                                              product.title,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            // Price
                                            Text(
                                              _formatDollars(product.price),
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w300,
                                                color: AppColors.textPrimary
                                                    .withOpacity(0.9),
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
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
