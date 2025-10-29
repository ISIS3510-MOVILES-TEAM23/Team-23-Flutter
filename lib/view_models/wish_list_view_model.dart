import 'package:flutter/material.dart';
import '../models/wish_list_model.dart';
import '../models/post_model.dart';
import '../data/repositories/wish_list_repository.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';

class WishListViewModel extends ChangeNotifier {
  final WishListRepository _repository;
  final CacheService _cache = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();

  WishListViewModel({WishListRepository? repository})
      : _repository = repository ?? WishListRepository();

  List<WishListItem> _items = [];
  bool _isLoading = true;
  String? _error;
  bool _isLoadedFromCache = false;

  List<WishListItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty && !_isLoading;
  bool get isLoadedFromCache => _isLoadedFromCache;

  // Load wish list items
  Future<void> loadWishList() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      List<WishListItem> wishItems = [];

      // Try network first if online
      if (_connectivity.isConnected) {
        try {
          debugPrint('[WishList] ✅ Online - fetching from network');
          wishItems = await _repository.getWishListItems();
          debugPrint('[WishList] 📥 Received ${wishItems.length} items from network');

          // Cache wish list (always cache, even if empty)
          await _cache.cacheWishList(wishItems.map((item) => item.toJsonForCache()).toList());
          debugPrint('[WishList] 💾 Cached ${wishItems.length} items');
          _isLoadedFromCache = false;
        } catch (e) {
          debugPrint('[WishList] ❌ Network failed, trying cache: $e');
          // Fallback to cache
          final cached = await _cache.getCachedWishList();
          debugPrint('[WishList] 📦 Cache result: ${cached == null ? "NULL" : "${cached.length} items"}');
          if (cached != null) {
            wishItems = cached.map((json) => WishListItem.fromJson(json)).toList();
            _isLoadedFromCache = true;
            debugPrint('[WishList] ✓ Loaded ${wishItems.length} items from cache');
          }
        }
      } else {
        // Offline - load from cache
        debugPrint('[WishList] 📴 Offline - loading from cache');
        final cached = await _cache.getCachedWishList();
        debugPrint('[WishList] 📦 Cache result: ${cached == null ? "NULL" : "${cached.length} items"}');
        if (cached != null) {
          wishItems = cached.map((json) => WishListItem.fromJson(json)).toList();
          _isLoadedFromCache = true;
          debugPrint('[WishList] ✓ Loaded ${wishItems.length} items from cache');
        } else {
          debugPrint('[WishList] ⚠️ No cached wish list (open app online first to cache)');
        }
      }

      _items = wishItems;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load wish list';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading wish list: $e');
    }
  }

  // Add item to wish list
  Future<bool> addToWishList(Post product, {String? notes}) async {
    try {
      final success = await _repository.addToWishList(product, notes: notes);
      if (success) {
        await loadWishList(); // This will re-cache
      }
      return success;
    } catch (e) {
      debugPrint('Error adding to wish list: $e');
      return false;
    }
  }

  // Remove item from wish list
  Future<bool> removeFromWishList(String wishListItemId) async {
    try {
      final success = await _repository.removeFromWishList(wishListItemId);
      if (success) {
        _items.removeWhere((item) => item.id == wishListItemId);
        // Update cache
        await _cache.cacheWishList(_items.map((item) => item.toJsonForCache()).toList());
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error removing from wish list: $e');
      return false;
    }
  }

  // Update notes for wish list item
  Future<bool> updateNotes(String wishListItemId, String notes) async {
    try {
      final success = await _repository.updateNotes(wishListItemId, notes);
      if (success) {
        final index = _items.indexWhere((item) => item.id == wishListItemId);
        if (index != -1) {
          _items[index] = _items[index].copyWith(notes: notes);
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      debugPrint('Error updating notes: $e');
      return false;
    }
  }

  // Check if product is in wish list
  Future<bool> isInWishList(String productId) async {
    return await _repository.isInWishList(productId);
  }

  // Format price
  String formatPrice(int cents) {
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  // Get total items count
  int get totalItems => _items.length;

  // Get total value
  int get totalValue => _items.fold(0, (sum, item) => sum + item.productPrice);

  String get formattedTotalValue => formatPrice(totalValue);
}
