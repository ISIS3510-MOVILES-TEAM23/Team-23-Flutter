import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/post_repository.dart';

class CategoryProductsViewModel extends ChangeNotifier {
  final PostRepository _postRepository;

  CategoryProductsViewModel({PostRepository? postRepository})
      : _postRepository = postRepository ?? PostRepository();

  List<Post> products = [];
  bool isLoading = true;

  Future<void> loadProducts(String categoryId) async {
    try {
      isLoading = true;
      notifyListeners();

      final prods = await _postRepository.getPostsByCategory(categoryId);

      products = prods;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  String formatDollars(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
}

