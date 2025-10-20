import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/post_repository.dart';
import '../services/recommendation_service.dart';
import '../services/major_recommendations_service.dart';

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

  // --- Recommendations state ---
  final RecommendationService _recService = RecommendationService();
  final MajorRecommendationsService _majorRecService = MajorRecommendationsService();
  List<Post> recommendedProducts = [];
  List<Post> majorBasedProducts = [];
  bool isLoadingRecommendations = false;
  bool isLoadingMajorBased = false;
  String? majorBasedTitle; // Título dinámico para la sección

  Future<void> loadProducts() async {
    try {
      isLoading = true;
      notifyListeners();

      final newProds = await _postRepository.getNewPosts();

      newProducts = newProds;
      filteredNewProducts = List<Post>.from(newProds);
      
      // Cargar productos basados en major
      await loadMajorBasedProducts();
      
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  // Load products viewed by people with the same major
  Future<void> loadMajorBasedProducts({int limit = 4, int windowDays = 30}) async {
    isLoadingMajorBased = true;
    notifyListeners();
    try {
      // Get current user's major
      final userMajor = await _majorRecService.getCurrentUserMajor();
      
      majorBasedProducts = await _majorRecService.getPostsByMajor(
        limit: limit,
        windowDays: windowDays,
        debug: true,
      );
      
      // Determine dynamic title based on major and if there are products
      if (userMajor != null && userMajor.isNotEmpty) {
        // Shorten major if too long (keep in Spanish as requested)
        final shortMajor = userMajor.length > 30 ? '${userMajor.substring(0, 30)}...' : userMajor;
        majorBasedTitle = 'Popular in $shortMajor';
      } else if (majorBasedProducts.isNotEmpty) {
        majorBasedTitle = 'Featured';
      } else {
        majorBasedTitle = 'Featured';
      }
    } catch (e) {
      print('Error loading major-based products: $e');
      majorBasedProducts = [];
      majorBasedTitle = 'Featured';
    } finally {
      isLoadingMajorBased = false;
      notifyListeners();
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
    String? ownerId,
  }) async {
    final categoryName = resolveCategoryName(categoryId);
    
    // Registrar en product_search_events (para analytics)
    _postRepository.logProductSearchEvent(
      source: source,
      query: searchQuery,
      selectedCategory: categoryName,
      suggestedCategories:
          categoryName != null ? <String>[categoryName] : <String>[],
    );
    
    // Registrar en product_click_events (para recomendaciones basadas en major)
    // SOLO si NO es mi propio producto
    try {
      final currentUser = await _postRepository.getCurrentUser();
      if (currentUser != null && ownerId != null && currentUser.id != ownerId) {
        await _postRepository.logProductClickEvent(
          postId: productId,
          category: categoryName,
          source: source,
        );
      }
    } catch (e) {
      // Error silencioso, no afectar la navegación
      print('Error logging product click event: $e');
    }
  }

  String formatDollars(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
}

