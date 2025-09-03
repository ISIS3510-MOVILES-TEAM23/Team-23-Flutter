import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:myapp/data.dart';

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
      ),
      body: ListView.builder(
        itemCount: kCategories.length,
        itemBuilder: (context, index) {
          final category = kCategories[index];
          return ListTile(
            title: Text(category.name),
            onTap: () => context.go('/categories/${category.id}'),
          );
        },
      ),
    );
  }
}
