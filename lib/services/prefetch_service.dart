import 'package:flutter/material.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/wish_list_repository.dart';
import '../data/repositories/category_repository.dart';
import '../models/post_model.dart';
import '../services/recommendation_service.dart';
import '../services/major_recommendations_service.dart';
import '../services/firestore_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';
import 'image_cache_service.dart';

/// Service to pre-fetch and cache all data at app startup
class PrefetchService {
  static final PrefetchService _instance = PrefetchService._internal();
  factory PrefetchService() => _instance;
  PrefetchService._internal();

  final PostRepository _postRepository = PostRepository();
  final WishListRepository _wishListRepository = WishListRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final RecommendationService _recService = RecommendationService();
  final MajorRecommendationsService _majorRecService =
      MajorRecommendationsService();
  final CacheService _cache = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();
  final ImageCacheService _imageCache = ImageCacheService();

  bool _isPrefetching = false;
  bool _isPrefetched = false;

  bool get isPrefetching => _isPrefetching;
  bool get isPrefetched => _isPrefetched;

  /// Pre-fetch all data in background
  Future<void> prefetchAll() async {
    if (_isPrefetching || _isPrefetched) return;
    if (!_connectivity.isConnected) {
      debugPrint('[Prefetch] ⚠️ Offline - skipping prefetch');
      return;
    }

    _isPrefetching = true;
    debugPrint('[Prefetch] 🚀 Starting background prefetch...');

    try {
      // Run all prefetch operations in parallel
      await Future.wait([
        _prefetchNewPosts(),
        _prefetchRecommendedProducts(),
        _prefetchMajorBasedProducts(),
        _prefetchWishList(),
        _prefetchUserPosts(),
        _prefetchCategories(),
      ]);

      _isPrefetched = true;
      debugPrint('[Prefetch] ✅ All data prefetched successfully');
    } catch (e) {
      debugPrint('[Prefetch] ❌ Error during prefetch: $e');
    } finally {
      _isPrefetching = false;
    }
  }

  Future<void> _prefetchNewPosts() async {
    try {
      debugPrint('[Prefetch] 📥 Fetching new posts...');
      final posts = await _postRepository.getNewPosts();
      await _cache.cachePosts(posts.map((p) => p.toJson()).toList());
      debugPrint('[Prefetch] ✓ Cached ${posts.length} new posts');

      // Pre-cache images (first image only from each post)
      await _preCachePostImages(posts, 'new posts');
    } catch (e) {
      debugPrint('[Prefetch] ✗ Failed to prefetch new posts: $e');
    }
  }

  Future<void> _prefetchRecommendedProducts() async {
    try {
      debugPrint('[Prefetch] 🎯 Fetching recommended products...');
      final recommended = await _recService.fetchRecommendations(
        limit: 10,
        windowDays: 30,
        debug: false,
      );
      if (recommended.isNotEmpty) {
        await _cache.cacheRecommendedProducts(
          recommended.map((p) => p.toJson()).toList(),
        );
        debugPrint(
            '[Prefetch] ✓ Cached ${recommended.length} recommended products');

        // Pre-cache images
        await _preCachePostImages(recommended, 'recommended');
      }
    } catch (e) {
      debugPrint('[Prefetch] ✗ Failed to prefetch recommended products: $e');
    }
  }

  Future<void> _prefetchMajorBasedProducts() async {
    try {
      debugPrint('[Prefetch] 🎓 Fetching major-based products...');
      final majorBased = await _majorRecService.getPostsByMajor(
        limit: 10,
        windowDays: 30,
        debug: false,
      );
      if (majorBased.isNotEmpty) {
        await _cache.cacheMajorBasedProducts(
          majorBased.map((p) => p.toJson()).toList(),
        );
        debugPrint(
            '[Prefetch] ✓ Cached ${majorBased.length} major-based products');

        // Pre-cache images
        await _preCachePostImages(majorBased, 'major-based');
      }
    } catch (e) {
      debugPrint('[Prefetch] ✗ Failed to prefetch major-based products: $e');
    }
  }

  Future<void> _prefetchWishList() async {
    try {
      debugPrint('[Prefetch] ⭐ Fetching wish list...');
      final wishList = await _wishListRepository.getWishListItems();
      // Always cache, even if empty (so offline knows it was fetched)
      await _cache.cacheWishList(
          wishList.map((item) => item.toJsonForCache()).toList());
      debugPrint('[Prefetch] ✓ Cached ${wishList.length} wish list items');
    } catch (e) {
      debugPrint('[Prefetch] ✗ Failed to prefetch wish list: $e');
    }
  }

  Future<void> _prefetchUserPosts() async {
    try {
      debugPrint('[Prefetch] 👤 Fetching user posts...');
      final currentUser = await FirestoreService.getCurrentUser();
      if (currentUser != null) {
        final userPosts = await FirestoreService.getUserPosts(currentUser.id);
        await _cache.cacheUserPosts(
          currentUser.id,
          userPosts.map((p) => p.toJson()).toList(),
        );
        debugPrint('[Prefetch] ✓ Cached ${userPosts.length} user posts');
      } else {
        debugPrint('[Prefetch] ⚠️ No current user to fetch posts for');
      }
    } catch (e) {
      debugPrint('[Prefetch] ✗ Failed to prefetch user posts: $e');
    }
  }

  Future<void> _prefetchCategories() async {
    try {
      debugPrint('[Prefetch] 📂 Fetching categories...');
      final categories = await _categoryRepository.getCategories();
      if (categories.isNotEmpty) {
        await _cache.cacheCategories(
          categories.map((c) => c.toJson()).toList(),
        );
        debugPrint('[Prefetch] ✓ Cached ${categories.length} categories');
      }
    } catch (e) {
      debugPrint('[Prefetch] ✗ Failed to prefetch categories: $e');
    }
  }

  /// Reset prefetch state (for testing or manual refresh)
  void reset() {
    _isPrefetched = false;
    _isPrefetching = false;
  }

  /// Pre-cache first image from each post (async)
  Future<void> _preCachePostImages(List<Post> posts, String label) async {
    try {
      final imageUrls = <String>{};

      for (final post in posts) {
        for (final image in post.images) {
          if (image.isNotEmpty) {
            imageUrls.add(image);
          }
        }
      }

      if (imageUrls.isEmpty) {
        debugPrint('[Prefetch] 🖼️  No images to cache for $label');
        return;
      }

      int cached = 0;
      final total = imageUrls.length;

      await Future.wait(imageUrls.map((imageUrl) async {
        final success = await _imageCache.preCacheImage(imageUrl);
        if (success) {
          cached++;
        }
      }));

      debugPrint('[Prefetch] 🖼️  Cached $cached/$total images for $label');
    } catch (e) {
      debugPrint('[Prefetch] ✗ Failed to pre-cache images for $label: $e');
    }
  }
}
