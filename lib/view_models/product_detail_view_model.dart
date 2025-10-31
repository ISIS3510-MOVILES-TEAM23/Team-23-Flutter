import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/wish_list_repository.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';

class ProductDetailViewModel extends ChangeNotifier {
  final PostRepository _postRepository;
  final UserRepository _userRepository;
  final ChatRepository _chatRepository;
  final WishListRepository _wishListRepository;
  final CacheService _cache = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();

  ProductDetailViewModel({
    PostRepository? postRepository,
    UserRepository? userRepository,
    ChatRepository? chatRepository,
    WishListRepository? wishListRepository,
  })  : _postRepository = postRepository ?? PostRepository(),
        _userRepository = userRepository ?? UserRepository(),
        _chatRepository = chatRepository ?? ChatRepository(),
        _wishListRepository = wishListRepository ?? WishListRepository();

  Post? product;
  User? seller;
  bool isLoading = true;
  bool isInWishList = false;
  int currentImageIndex = 0;
  bool isLoadedFromCache = false;
  bool hasExistingChat = false;

  Future<void> loadProduct(String productId) async {
    try {
      isLoading = true;
      notifyListeners();

      Post? prod;
      User? user;

      // Try network first if online
      if (_connectivity.isConnected) {
        try {
          prod = await _postRepository.getPostById(productId);
          if (prod != null) {
            // Cache the product
            await _cache.cachePost(productId, prod.toJson());
            user = await _userRepository.getUserById(prod.userId);
            if (user != null) {
              await _cache.cacheUser(prod.userId, user.toJson());
            }
            isLoadedFromCache = false;

            // Registrar click del producto SOLO si NO es propio
            final currentUserId = await _userRepository.getCurrentUserId();
            if (currentUserId != null && prod.userId != currentUserId) {
              _logProductClick(prod);
            }

            // Check if product is in wish list
            isInWishList = await _wishListRepository.isInWishList(productId);

            // Scenario 10: Check if chat already exists
            if (prod.userId != null) {
              hasExistingChat = await _checkExistingChat(productId, prod.userId);
            }
          }
        } catch (e) {
          debugPrint('[ProductDetail] Network failed, trying cache: $e');
          // Fallback to cache
          final cached = await _getCachedPostData(productId);
          if (cached != null) {
            prod = Post.fromJson(cached);
            final cachedUser = await _cache.getCachedUser(prod.userId);
            if (cachedUser != null) {
              user = User.fromJson(cachedUser);
            }
            isLoadedFromCache = true;

            // Check for existing chat (can work offline if cached)
            if (prod.userId != null) {
              hasExistingChat = await _checkExistingChat(productId, prod.userId);
            }
          }
        }
      } else {
        // Offline - load from cache
        debugPrint('[ProductDetail] Offline - loading from cache');
        final cached = await _getCachedPostData(productId);
        if (cached != null) {
          prod = Post.fromJson(cached);
          final cachedUser = await _cache.getCachedUser(prod.userId);
          if (cachedUser != null) {
            user = User.fromJson(cachedUser);
          }
          isLoadedFromCache = true;
          // Can't check wish list offline - skip
          isInWishList = false;

          // Scenario 10: Check for existing chat (can work offline if cached)
          if (prod.userId != null) {
            hasExistingChat = await _checkExistingChat(productId, prod.userId);
          }
        }
      }

      product = prod;
      seller = user;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // Registrar click de producto en product_click_events (solo para productos de otros)
  void _logProductClick(Post post) {
    try {
      final categoryName = _resolveCategoryName(post.categoryId);
      FirestoreService.logProductClickEvent(
        postId: post.id,
        category: categoryName,
        source: 'product_detail_view',
      );
    } catch (e) {
      // Error silencioso, no afectar la carga del producto
      print('Error logging product click: $e');
    }
  }

  String? _resolveCategoryName(String? rawCategory) {
    if (rawCategory == null) return null;
    final trimmed = rawCategory.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('/')) return trimmed;
    final parts = trimmed.split('/');
    return parts.isNotEmpty ? parts.last : trimmed;
  }

  Future<String> initiateChat() async {
    if (product == null || seller == null) {
      throw Exception('Product or seller not loaded');
    }

    try {
      final chatId = await _chatRepository.getOrCreateProductChat(
        product!.id,
        seller!.id,
      );
      return chatId;
    } catch (e) {
      rethrow;
    }
  }

  void setCurrentImageIndex(int index) {
    currentImageIndex = index;
    notifyListeners();
  }

  String formatDollars(int cents) {
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  Future<bool> toggleWishList() async {
    if (product == null) return false;

    try {
      if (isInWishList) {
        // Remove from wish list
        final wishListItem =
            await _wishListRepository.getWishListItemByProductId(product!.id);
        if (wishListItem != null) {
          final success = await _wishListRepository.removeFromWishList(wishListItem.id, product!.id);
          if (success) {
            isInWishList = false;
            notifyListeners();
          }
          return success;
        }
        return false;
      } else {
        // Add to wish list
        final success = await _wishListRepository.addToWishList(product!);
        if (success) {
          isInWishList = true;
          notifyListeners();
        }
        return success;
      }
    } catch (e) {
      debugPrint('Error toggling wish list: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> _getCachedPostData(String productId) async {
    final direct = await _cache.getCachedPost(productId);
    if (direct != null) return direct;

    final cachedLists = await Future.wait<List<Map<String, dynamic>>?>([
      _cache.getCachedPosts(),
      _cache.getCachedRecommendedProducts(),
      _cache.getCachedMajorBasedProducts(),
    ]);

    for (final list in cachedLists) {
      final match = _matchPostInList(list, productId);
      if (match != null) return match;
    }

    final currentUserId = await _userRepository.getCurrentUserId();
    if (currentUserId != null) {
      final userPosts = await _cache.getCachedUserPosts(currentUserId);
      final match = _matchPostInList(userPosts, productId);
      if (match != null) return match;
    }

    return null;
  }

  Map<String, dynamic>? _matchPostInList(
    List<Map<String, dynamic>>? posts,
    String productId,
  ) {
    if (posts == null) return null;
    for (final raw in posts) {
      final id = (raw['_id'] ?? raw['id'] ?? '').toString();
      if (id == productId) {
        return raw;
      }
    }
    return null;
  }

  /// Check if a chat already exists for this product (Scenario 10)
  Future<bool> _checkExistingChat(String productId, String sellerId) async {
    try {
      final currentUserId = await _userRepository.getCurrentUserId();
      if (currentUserId == null || currentUserId == sellerId) {
        return false;
      }

      // Try to get existing chat ID
      final chatId = await _chatRepository.getExistingProductChat(
        productId,
        sellerId,
      );

      return chatId != null;
    } catch (e) {
      debugPrint('[ProductDetail] Error checking existing chat: $e');
      return false;
    }
  }
}
