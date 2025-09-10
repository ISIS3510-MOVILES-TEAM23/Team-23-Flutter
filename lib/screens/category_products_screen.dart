import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../services/mock_service.dart';
import '../theme/app_colors.dart';
import '../widgets/product_card.dart';

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
  List<Product> products = [];
  List<Category> categories = [];
  bool isLoading = true;
  
  // Filter variables
  RangeValues priceRange = const RangeValues(0, 1000);
  String? selectedCondition;
  String sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final cats = await MockService.getCategories();
      final prods = await MockService.getProductsByCategory(
        widget.categoryId,
        filters: FilterOptions(
          minPrice: priceRange.start,
          maxPrice: priceRange.end,
          condition: selectedCondition,
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

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.textSecondary.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Price Range
                  const Text(
                    'Price Range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RangeSlider(
                    values: priceRange,
                    min: 0,
                    max: 1000,
                    divisions: 20,
                    activeColor: AppColors.primaryColor,
                    labels: RangeLabels(
                      '\$${priceRange.start.round()}',
                      '\$${priceRange.end.round()}',
                    ),
                    onChanged: (values) {
                      setModalState(() {
                        priceRange = values;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('\$${priceRange.start.round()}'),
                      Text('\$${priceRange.end.round()}'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Condition
                  const Text(
                    'Condition',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('New'),
                        selected: selectedCondition == 'new',
                        onSelected: (selected) {
                          setModalState(() {
                            selectedCondition = selected ? 'new' : null;
                          });
                        },
                        selectedColor: AppColors.primaryColor.withOpacity(0.2),
                      ),
                      FilterChip(
                        label: const Text('Like New'),
                        selected: selectedCondition == 'like_new',
                        onSelected: (selected) {
                          setModalState(() {
                            selectedCondition = selected ? 'like_new' : null;
                          });
                        },
                        selectedColor: AppColors.primaryColor.withOpacity(0.2),
                      ),
                      FilterChip(
                        label: const Text('Good'),
                        selected: selectedCondition == 'good',
                        onSelected: (selected) {
                          setModalState(() {
                            selectedCondition = selected ? 'good' : null;
                          });
                        },
                        selectedColor: AppColors.primaryColor.withOpacity(0.2),
                      ),
                      FilterChip(
                        label: const Text('Fair'),
                        selected: selectedCondition == 'fair',
                        onSelected: (selected) {
                          setModalState(() {
                            selectedCondition = selected ? 'fair' : null;
                          });
                        },
                        selectedColor: AppColors.primaryColor.withOpacity(0.2),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Sort By
                  const Text(
                    'Sort By',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: sortBy,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'newest',
                        child: Text('Newest First'),
                      ),
                      DropdownMenuItem(
                        value: 'price_low',
                        child: Text('Price: Low to High'),
                      ),
                      DropdownMenuItem(
                        value: 'price_high',
                        child: Text('Price: High to Low'),
                      ),
                      DropdownMenuItem(
                        value: 'popular',
                        child: Text('Most Popular'),
                      ),
                    ],
                    onChanged: (value) {
                      setModalState(() {
                        sortBy = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              priceRange = const RangeValues(0, 1000);
                              selectedCondition = null;
                              sortBy = 'newest';
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              // Apply filters
                            });
                            Navigator.pop(context);
                            _loadData();
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final category = categories.firstWhere(
      (c) => c.id == widget.categoryId,
      orElse: () => Category(id: '', name: 'Products', icon: '📦'),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('${category.icon} ${category.name}'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilterBottomSheet,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No products found',
                        style: TextStyle(
                          fontSize: 18,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
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
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return ProductCard(
                      product: product,
                      onTap: () {
                        context.go('/categories/${widget.categoryId}/product/${product.id}');
                      },
                    );
                  },
                ),
    );
  }
}