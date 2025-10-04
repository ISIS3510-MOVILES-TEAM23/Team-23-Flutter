import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/post_repository.dart';
import '../services/recommendation_service.dart'; // <-- ADD THIS

class HomeViewModel extends ChangeNotifier {
  final PostRepository _postRepository;

  HomeViewModel({PostRepository? postRepository})
      : _postRepository = postRepository ?? PostRepository();

  List<Post> highlightedProducts = [];
  List<Post> newProducts = [];
  List<Post> filteredNewProducts = [];
  bool isLoading = true;
  String? _lastSearchQuery;

  bool get hasSearchQuery => (_lastSearchQuery?.isNotEmpty ?? false);
  String? get lastSearchQuery => _lastSearchQuery;

  // --- Recommendations state ---  // <-- ADD THIS
  final RecommendationService _recService = RecommendationService();
  List<Post> recommendedProducts = [];
  bool isLoadingRecommendations = false;

  Future<void> loadProducts() async {
    try {
      isLoading = true;
      notifyListeners();

      final highlighted = await _postRepository.getHighlightedPosts();
      final newProds = await _postRepository.getNewPosts();

      highlightedProducts = highlighted;
      newProducts = newProds;
      filteredNewProducts = List<Post>.from(newProds);
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Cargar recomendaciones basadas en product_search_events  // <-- ADD THIS
  Future<void> loadRecommendations({int limit = 5, int windowDays = 30}) async {
    isLoadingRecommendations = true;
    notifyListeners();
    try {
      recommendedProducts = await _recService.fetchRecommendations(
        limit: limit,
        windowDays: windowDays,
      );
    } finally {
      isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  void applySearch(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _lastSearchQuery = null;
      filteredNewProducts = List<Post>.from(newProducts);
    } else {
      _lastSearchQuery = trimmed;
      filteredNewProducts = _filterProducts(trimmed);
    }
    notifyListeners();
  }

  void clearSearch() {
    if (hasSearchQuery) {
      _lastSearchQuery = null;
      filteredNewProducts = List<Post>.from(newProducts);
      notifyListeners();
    }
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

  String? resolveCategoryName(String? rawCategory) {
    if (rawCategory == null) return null;
    final trimmed = rawCategory.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('/')) return trimmed;
    final parts = trimmed.split('/');
    return parts.isNotEmpty ? parts.last : trimmed;
  }

  void logProductClick({
    required String productId,
    required String categoryId,
    required String source,
    String? searchQuery,
  }) {
    final categoryName = resolveCategoryName(categoryId);
    _postRepository.logProductSearchEvent(
      source: source,
      query: searchQuery,
      selectedCategory: categoryName,
      suggestedCategories:
          categoryName != null ? <String>[categoryName] : <String>[],
    );
  }

  String formatDollars(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
}

