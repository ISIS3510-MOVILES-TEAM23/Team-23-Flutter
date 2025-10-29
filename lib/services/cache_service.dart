import 'dart:convert';
import 'package:flutter/material.dart';
import 'local_storage_service.dart';

/// Service to manage caching strategy with TTL (Time To Live)
/// Implements cache fallback pattern with expiration
class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  final LocalStorageService _storage = LocalStorageService();

  // Cache durations
  static const Duration postsCacheDuration = Duration(days: 7);
  static const Duration categoriesCacheDuration = Duration(days: 30);
  static const Duration userCacheDuration = Duration(days: 7);
  static const Duration messagesCacheDuration = Duration(days: 30);

  /// Save posts to cache with timestamp
  Future<void> cachePosts(List<Map<String, dynamic>> posts) async {
    try {
      debugPrint('[Cache] 💾 Saving ${posts.length} posts to Hive...');
      debugPrint(
          '[Cache] 📍 Box: ${LocalStorageService.postsBoxName}, Key: all_posts');

      final cacheData = {
        'data': posts,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final jsonString = jsonEncode(cacheData);
      debugPrint('[Cache] 📦 JSON size: ${jsonString.length} bytes');

      await _storage.save(
        LocalStorageService.postsBoxName,
        'all_posts',
        jsonString,
      );

      for (final post in posts) {
        await _cacheSinglePostMap(post);
      }

      // Verify it was saved
      final verification =
          _storage.get(LocalStorageService.postsBoxName, 'all_posts');
      if (verification != null) {
        debugPrint('[Cache] ✅ VERIFIED: Cache saved successfully');
      } else {
        debugPrint('[Cache] ❌ VERIFICATION FAILED: Cache not found after save');
      }

      debugPrint('[Cache] ✓ Cached ${posts.length} posts');
    } catch (e) {
      debugPrint('[Cache] ❌ Failed to cache posts: $e');
      debugPrint('[Cache] Stack trace: ${StackTrace.current}');
    }
  }

  /// Get cached posts if not expired
  Future<List<Map<String, dynamic>>?> getCachedPosts() async {
    try {
      debugPrint('[Cache] 🔍 Looking for cached posts in Hive...');
      debugPrint(
          '[Cache] 📍 Box: ${LocalStorageService.postsBoxName}, Key: all_posts');

      // Check if box contains the key
      final hasKey =
          _storage.contains(LocalStorageService.postsBoxName, 'all_posts');
      debugPrint('[Cache] 🔑 Box contains key "all_posts": $hasKey');

      // Check box size
      final boxSize = _storage.getBoxSize(LocalStorageService.postsBoxName);
      debugPrint('[Cache] 📊 Box size: $boxSize items');

      final cached = _storage.get(
        LocalStorageService.postsBoxName,
        'all_posts',
      );

      if (cached == null) {
        debugPrint('[Cache] ❌ No cached data found (returned NULL)');

        // Debug: List all keys in box
        final allKeys = _storage.getAllKeys(LocalStorageService.postsBoxName);
        debugPrint('[Cache] 🗝️ All keys in box: $allKeys');

        return null;
      }

      debugPrint(
          '[Cache] 📦 Found cached data, size: ${cached.toString().length} bytes');
      debugPrint('[Cache] 🔓 Decoding JSON...');

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);
      final age = DateTime.now().difference(timestamp);

      debugPrint('[Cache] ⏰ Cache timestamp: $timestamp');
      debugPrint(
          '[Cache] 📅 Cache age: ${age.inHours}h ${age.inMinutes % 60}m');

      // Check if cache is expired
      if (age > postsCacheDuration) {
        debugPrint(
            '[Cache] ⏱ Posts cache EXPIRED (>${postsCacheDuration.inDays} days)');
        return null;
      }

      final posts = (cacheData['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      debugPrint(
          '[Cache] ✅ Retrieved ${posts.length} cached posts (age: ${age.inHours}h)');
      return posts;
    } catch (e) {
      debugPrint('[Cache] ❌ Failed to get cached posts: $e');
      debugPrint('[Cache] Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Cache a single post
  Future<void> cachePost(String postId, Map<String, dynamic> post) async {
    try {
      final cacheData = {
        'data': post,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _storage.save(
        LocalStorageService.postsBoxName,
        'post_$postId',
        jsonEncode(cacheData),
      );
      debugPrint('[Cache] ✓ Cached post: $postId');
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to cache post $postId: $e');
    }
  }

  /// Get single cached post
  Future<Map<String, dynamic>?> getCachedPost(String postId) async {
    try {
      final cached = _storage.get(
        LocalStorageService.postsBoxName,
        'post_$postId',
      );

      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);

      if (DateTime.now().difference(timestamp) > postsCacheDuration) {
        return null;
      }

      return Map<String, dynamic>.from(cacheData['data'] as Map);
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to get cached post $postId: $e');
      return null;
    }
  }

  /// Cache categories
  Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    try {
      final cacheData = {
        'data': categories,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _storage.save(
        LocalStorageService.categoriesBoxName,
        'all_categories',
        jsonEncode(cacheData),
      );
      debugPrint('[Cache] ✓ Cached ${categories.length} categories');
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to cache categories: $e');
    }
  }

  /// Get cached categories
  Future<List<Map<String, dynamic>>?> getCachedCategories() async {
    try {
      final cached = _storage.get(
        LocalStorageService.categoriesBoxName,
        'all_categories',
      );

      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);

      if (DateTime.now().difference(timestamp) > categoriesCacheDuration) {
        return null;
      }

      return (cacheData['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to get cached categories: $e');
      return null;
    }
  }

  /// Cache user data
  Future<void> cacheUser(String userId, Map<String, dynamic> userData) async {
    try {
      final cacheData = {
        'data': userData,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _storage.save(
        LocalStorageService.userBoxName,
        'user_$userId',
        jsonEncode(cacheData),
      );
      debugPrint('[Cache] ✓ Cached user: $userId');
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to cache user $userId: $e');
    }
  }

  /// Get cached user
  Future<Map<String, dynamic>?> getCachedUser(String userId) async {
    try {
      final cached = _storage.get(
        LocalStorageService.userBoxName,
        'user_$userId',
      );

      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);

      if (DateTime.now().difference(timestamp) > userCacheDuration) {
        return null;
      }

      return Map<String, dynamic>.from(cacheData['data'] as Map);
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to get cached user $userId: $e');
      return null;
    }
  }

  /// Get cache age for display
  String? getCacheAge(String boxName, String key) {
    try {
      final cached = _storage.get(boxName, key);
      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);
      final age = DateTime.now().difference(timestamp);

      if (age.inDays > 0) {
        return '${age.inDays} day${age.inDays > 1 ? 's' : ''} ago';
      } else if (age.inHours > 0) {
        return '${age.inHours} hour${age.inHours > 1 ? 's' : ''} ago';
      } else if (age.inMinutes > 0) {
        return '${age.inMinutes} minute${age.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return null;
    }
  }

  /// Cache wish list items
  Future<void> cacheWishList(List<Map<String, dynamic>> items) async {
    try {
      debugPrint(
          '[Cache] 💾 Saving ${items.length} wish list items to Hive...');
      final cacheData = {
        'data': items,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _storage.save(
        LocalStorageService.postsBoxName,
        'wish_list',
        jsonEncode(cacheData),
      );
      debugPrint('[Cache] ✓ Cached ${items.length} wish list items');
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to cache wish list: $e');
    }
  }

  /// Get cached wish list items
  Future<List<Map<String, dynamic>>?> getCachedWishList() async {
    try {
      final cached = _storage.get(
        LocalStorageService.postsBoxName,
        'wish_list',
      );

      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);

      // Wish list cache doesn't expire (or use a long duration)
      if (DateTime.now().difference(timestamp) > const Duration(days: 365)) {
        return null;
      }

      return (cacheData['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to get cached wish list: $e');
      return null;
    }
  }

  /// Cache recommended products
  Future<void> cacheRecommendedProducts(
      List<Map<String, dynamic>> products) async {
    try {
      debugPrint(
          '[Cache] 💾 Saving ${products.length} recommended products...');
      final cacheData = {
        'data': products,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _storage.save(
        LocalStorageService.postsBoxName,
        'recommended_products',
        jsonEncode(cacheData),
      );

      for (final product in products) {
        await _cacheSinglePostMap(product);
      }
      debugPrint('[Cache] ✓ Cached ${products.length} recommended products');
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to cache recommended products: $e');
    }
  }

  /// Get cached recommended products
  Future<List<Map<String, dynamic>>?> getCachedRecommendedProducts() async {
    try {
      final cached = _storage.get(
        LocalStorageService.postsBoxName,
        'recommended_products',
      );

      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);

      // Use same TTL as posts
      if (DateTime.now().difference(timestamp) > postsCacheDuration) {
        return null;
      }

      return (cacheData['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to get cached recommended products: $e');
      return null;
    }
  }

  /// Cache major-based products
  Future<void> cacheMajorBasedProducts(
      List<Map<String, dynamic>> products) async {
    try {
      debugPrint(
          '[Cache] 💾 Saving ${products.length} major-based products...');
      final cacheData = {
        'data': products,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _storage.save(
        LocalStorageService.postsBoxName,
        'major_based_products',
        jsonEncode(cacheData),
      );

      for (final product in products) {
        await _cacheSinglePostMap(product);
      }
      debugPrint('[Cache] ✓ Cached ${products.length} major-based products');
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to cache major-based products: $e');
    }
  }

  /// Get cached major-based products
  Future<List<Map<String, dynamic>>?> getCachedMajorBasedProducts() async {
    try {
      final cached = _storage.get(
        LocalStorageService.postsBoxName,
        'major_based_products',
      );

      if (cached == null) return null;

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);

      // Use same TTL as posts
      if (DateTime.now().difference(timestamp) > postsCacheDuration) {
        return null;
      }

      return (cacheData['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to get cached major-based products: $e');
      return null;
    }
  }

  /// Cache user's own posts
  Future<void> cacheUserPosts(
      String userId, List<Map<String, dynamic>> posts) async {
    try {
      debugPrint(
          '[Cache] 💾 Saving ${posts.length} user posts for userId=$userId...');
      final cacheData = {
        'data': posts,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await _storage.save(
        LocalStorageService.postsBoxName,
        'user_posts_$userId',
        jsonEncode(cacheData),
      );
      for (final post in posts) {
        await _cacheSinglePostMap(post);
      }
      debugPrint('[Cache] ✓ Cached ${posts.length} user posts');
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to cache user posts: $e');
    }
  }

  /// Get cached user posts
  Future<List<Map<String, dynamic>>?> getCachedUserPosts(String userId) async {
    try {
      final cached = _storage.get(
        LocalStorageService.postsBoxName,
        'user_posts_$userId',
      );

      if (cached == null) {
        debugPrint('[Cache] ⚠️ No cached user posts for userId=$userId');
        return null;
      }

      final cacheData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(cacheData['timestamp'] as String);

      // Use same TTL as posts (7 days)
      if (DateTime.now().difference(timestamp) > postsCacheDuration) {
        debugPrint('[Cache] ⏰ User posts cache expired');
        return null;
      }

      final posts = (cacheData['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      debugPrint('[Cache] ✅ Retrieved ${posts.length} cached user posts');
      return posts;
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to get cached user posts: $e');
      return null;
    }
  }

  Future<void> _cacheSinglePostMap(Map<String, dynamic> rawPost) async {
    try {
      final postId = (rawPost['_id'] ?? rawPost['id'] ?? '').toString();
      if (postId.isEmpty) return;

      await cachePost(postId, rawPost);
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to cache single post map: $e');
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    try {
      await _storage.clearBox(LocalStorageService.postsBoxName);
      await _storage.clearBox(LocalStorageService.categoriesBoxName);
      await _storage.clearBox(LocalStorageService.userBoxName);
      debugPrint('[Cache] ✓ Cleared all caches');
    } catch (e) {
      debugPrint('[Cache] ✗ Failed to clear caches: $e');
    }
  }
}
