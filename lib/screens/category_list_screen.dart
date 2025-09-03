import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/data.dart';
import 'package:myapp/models.dart';

class CategoryListScreen extends StatelessWidget {
  final String categoryId;

  const CategoryListScreen({super.key, required this.categoryId});

  @override
  Widget build(BuildContext context) {
    final category = kCategories.firstWhere((c) => c.id == categoryId);
    final products = kProducts.where((p) => p.categoryId == categoryId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return GestureDetector(
            onTap: () =>
                context.go('/categories/$categoryId/product/${product.id}'),
            child: Card(
              child: Column(
                children: [
                  Expanded(
                    child: Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Text(product.name),
                  Text('\$${product.price}'),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
