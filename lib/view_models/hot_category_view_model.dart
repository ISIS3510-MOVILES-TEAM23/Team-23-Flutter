import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/similar_products_service.dart';
import '../services/connectivity_service.dart';

/// ViewModel for the Hot Category screen
///
/// Manages the state and business logic for displaying all hot products
/// from a specific category. Supports both online and offline modes using
/// the same dual-layer caching strategy as the similar products feature.
class HotCategoryViewModel extends ChangeNotifier {
  final SimilarProductsService _similarProductsService = SimilarProductsService();
  final ConnectivityService _connectivity = ConnectivityService();

  // State
  List<Post> _products = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFromCache = false;
  String? _categoryId;

  // Getters
  List<Post> get products => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isFromCache => _isFromCache;
  bool get isEmpty => !_isLoading && _products.isEmpty;
  bool get hasError => _errorMessage != null;
  bool get isOfflineMode => !_connectivity.isConnected;

  /// Load hot products for a specific category
  ///
  /// Parameters:
  /// - [categoryId]: The category ID (e.g., "categories/electronics")
  /// - [limit]: Maximum number of products to fetch (default: 50)
  /// - [forceRefresh]: Bypass cache and fetch fresh data (default: false)
  Future<void> loadHotProducts({
    required String categoryId,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    try {
      _categoryId = categoryId;
      _isLoading = true;
      _errorMessage = null;
      _isFromCache = false;
      notifyListeners();

      // Check if we're offline before making the request
      final wasOffline = !_connectivity.isConnected;

      // Fetch hot products using the similar products service
      // We pass an empty excludePostId since we want all products
      final fetchedProducts = await _similarProductsService.getSimilarHotProducts(
        categoryId: categoryId,
        excludePostId: '', // No exclusion, we want all hot products
        limit: limit,
        windowDays: 30,
        forceRefresh: forceRefresh,
        debug: true,
      );

      _products = fetchedProducts;

      // Set cache flag based on connectivity
      // If we were offline and got results, they must be from cache
      if (wasOffline && fetchedProducts.isNotEmpty) {
        _isFromCache = true;
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[HotCategoryViewModel] Error loading hot products: $e');
      _errorMessage = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh the products list
  Future<void> refresh() async {
    if (_categoryId == null) return;

    await loadHotProducts(
      categoryId: _categoryId!,
      forceRefresh: true,
    );
  }

  /// Clear error message
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get user-friendly error message
  String _getErrorMessage(dynamic error) {
    if (!_connectivity.isConnected) {
      return 'No internet connection. Showing cached data if available.';
    }
    return 'Failed to load products. Please try again.';
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    return _similarProductsService.getCacheStats();
  }
}
