import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../services/mock_service.dart';
import '../theme/app_colors.dart';

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
  
  // Filter variables
  RangeValues priceRange = const RangeValues(0, 1000);
  String sortBy = 'newest';
  
  String _formatDollars(int cents) => '\$' + (cents / 100).toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final cats = await MockService.getCategories();
      final prods = await MockService.getPostsByCategory(
        widget.categoryId,
        filters: FilterOptions(
          minPrice: priceRange.start,
          maxPrice: priceRange.end,
          sortBy: sortBy,
        ),
      );
      
      setState(() {
        categories = cats;
        products = prods;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showPriceRangeDialog() {
    RangeValues tempRange = priceRange;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Price Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RangeSlider(
                values: tempRange,
                min: 0,
                max: 1000,
                divisions: 20,
                activeColor: AppColors.primaryColor,
                labels: RangeLabels(
                  '\$${tempRange.start.round()}',
                  '\$${tempRange.end.round()}',
                ),
                onChanged: (values) {
                  setDialogState(() {
                    tempRange = values;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '\$${tempRange.start.round()}',
                    style: const TextStyle(fontSize: 14),
                  ),
                  Text(
                    '\$${tempRange.end.round()}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  priceRange = tempRange;
                });
                Navigator.pop(context);
                _loadData();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = categories.firstWhere(
      (c) => c.id == widget.categoryId,
      orElse: () => const Category(id: '', name: 'Products', description: ''),
    );

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
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // Price Range Filter
                      Expanded(
                        child: InkWell(
                          onTap: _showPriceRangeDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.attach_money,
                                  size: 18,
                                  color: AppColors.textPrimary.withOpacity(0.7),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  priceRange.start == 0 && priceRange.end == 1000
                                      ? 'Price'
                                      : '\$${priceRange.start.round()}-\$${priceRange.end.round()}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      
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
                                value: 'newest',
                                child: Text('Newest'),
                              ),
                              DropdownMenuItem(
                                value: 'price_low',
                                child: Text('Price ↑'),
                              ),
                              DropdownMenuItem(
                                value: 'price_high',
                                child: Text('Price ↓'),
                              ),
                              DropdownMenuItem(
                                value: 'popular',
                                child: Text('Popular'),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                sortBy = value!;
                              });
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
                            priceRange = const RangeValues(0, 1000);
                            sortBy = 'newest';
                          });
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
                                  color: AppColors.textSecondary.withOpacity(0.7),
                                ),
                              ),
                            ],
                          ),
                        )
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
                                context.go('/categories/${widget.categoryId}/product/${product.id}');
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
                                        borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(12),
                                        ),
                                        child: Container(
                                          width: double.infinity,
                                          color: Colors.grey.withOpacity(0.1),
                                          child: Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: Colors.grey.withOpacity(0.1),
                                                child: Icon(
                                                  Icons.image_outlined,
                                                  size: 40,
                                                  color: AppColors.textSecondary.withOpacity(0.3),
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
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                                color: AppColors.textPrimary.withOpacity(0.9),
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