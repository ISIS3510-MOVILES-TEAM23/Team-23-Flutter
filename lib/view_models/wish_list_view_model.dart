import 'package:flutter/material.dart';

import '../data/repositories/wish_list_repository.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../models/models.dart';

class WishListViewModel extends ChangeNotifier {
  final WishListRepository _repository;
  final CacheService _cache = CacheService();
  final ConnectivityService _connectivity;

  WishListViewModel({
    WishListRepository? repository,
    ConnectivityService? connectivityService,
  })  : _repository = repository ?? WishListRepository(),
        _connectivity = connectivityService ?? ConnectivityService();

  List<WishListItem> _items = [];
  bool _isLoading = true;
  String? _error;
  bool _isLoadedFromCache = false;
  bool _isOffline = false;
  DateTime? _lastSyncTime;

  List<WishListItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty && !_isLoading;
  bool get isLoadedFromCache => _isLoadedFromCache;
  bool get isOffline => _isOffline;
  DateTime? get lastSyncTime => _lastSyncTime;

  // Load wish list items with connectivity awareness
  Future<void> loadWishList() async {
    try {
      debugPrint('🔄 [WishListVM] Starting to load wishlist...');
      _isLoading = true;
      _error = null;
      
      // Check connectivity
      _isOffline = !(await _connectivity.checkConnectivity());
      debugPrint('🌐 [WishListVM] Offline mode: $_isOffline');
      
      notifyListeners();

      List<WishListItem> wishItems = [];
      _items = await _repository.getWishListItems();
      debugPrint('✅ [WishListVM] Loaded ${_items.length} items');

      // Get last sync time from cache metadata
      final userId = _repository.getCurrentUserId();
      if (userId != null) {
        _lastSyncTime = HiveService.getWishlistLastSyncTime(userId);
        debugPrint('🕒 [WishListVM] Last sync time: $_lastSyncTime');
      }

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
      debugPrint('❌ [WishListVM] Error loading wish list: $e');
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

  // Remove item from wish list with optimistic UI
  Future<bool> removeFromWishList(String wishListItemId) async {
    try {
      // Find the product ID before removing
      final item = _items.firstWhere((item) => item.id == wishListItemId);
      final productId = item.productId;

      // Optimistically remove from UI
      _items.removeWhere((item) => item.id == wishListItemId);
      notifyListeners();

      final success = await _repository.removeFromWishList(wishListItemId);
      
      if (success) {
        _items.removeWhere((item) => item.id == wishListItemId);
        // Update cache
        await _cache.cacheWishList(_items.map((item) => item.toJsonForCache()).toList());
        notifyListeners();
      }else {
        // Revert on failure
        await loadWishList();
      }
      
      return success;
    } catch (e) {
      debugPrint('Error removing from wish list: $e');
      // Reload to ensure consistency
      await loadWishList();
      return false;
    }
  }

  // Update notes for wish list item with optimistic UI
  Future<bool> updateNotes(String wishListItemId, String notes) async {
    try {
      // Optimistically update in UI
      final index = _items.indexWhere((item) => item.id == wishListItemId);
      if (index != -1) {
        final oldNotes = _items[index].notes;
        _items[index] = _items[index].copyWith(notes: notes);
        notifyListeners();

        final success = await _repository.updateNotes(wishListItemId, notes);
        
        if (!success) {
          // Revert on failure
          _items[index] = _items[index].copyWith(notes: oldNotes);
          notifyListeners();
        }
        
        return success;
      }
      return false;
    } catch (e) {
      debugPrint('Error updating notes: $e');
      // Reload to ensure consistency
      await loadWishList();
      return false;
    }
  }

  // Get formatted last sync time for display
  String getLastSyncTimeText() {
    if (_lastSyncTime == null) return 'Never synced';
    
    final now = DateTime.now();
    final difference = now.difference(_lastSyncTime!);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
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
