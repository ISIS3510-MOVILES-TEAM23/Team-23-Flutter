import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/data.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
        ),
        itemCount: kProducts.length,
        itemBuilder: (context, index) {
          final product = kProducts[index];
          return GestureDetector(
            onTap: () => context.go('/home/product/${product.id}'),
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
