import 'package:flutter/material.dart';
import 'package:myapp/data.dart';

class ProductDetailScreen extends StatelessWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  @override
  Widget build(BuildContext context) {
    final product = kProducts.firstWhere((p) => p.id == productId);

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
      ),
      body: Column(
        children: [
          Image.network(product.imageUrl),
          Text(product.name, style: Theme.of(context).textTheme.headlineMedium),
          Text('\$${product.price}', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {},
            child: const Text('Add to Cart'),
          ),
        ],
      ),
    );
  }
}
