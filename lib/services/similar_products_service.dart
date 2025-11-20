// similar_products_service.dart
// Service to fetch "hot" similar products from the same category
// Uses a combination of product clicks and sales to determine popularity

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'lru_cache_service.dart';
import 'cache_service.dart';
import 'connectivity_service.dart';

/// Service to fetch similar "hot" products based on category
///
/// How it works:
/// 1. Finds all products in the same category as the current product
/// 2. Calculates "hotness" score for each product based on:
///    - Product clicks from product_click_events (weight: 3.0)
///    - Completed sales from sales collection (weight: 10.0)
/// 3. Sorts by hotness score descending, then by creation date (newest first)
/// 4. Excludes the current product from results
///
/// Caching strategy:
/// - LRU in-memory cache: 30 minutes TTL, 100 category capacity
/// - Persistent Hive cache: 7 days TTL for offline support
///
/// Offline support:
/// - When offline, returns cached results from Hive
/// - Shows offline indicator in UI (handled by ViewModel)
class SimilarProductsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // LRU Cache for similar products
  // Key: categoryId, Value: List<Post>
  final LruCacheService<String, List<Post>> _similarCache = LruCacheService(
    maxCapacity: 100, // Cache for 100 different categories
  );

  final CacheService _cacheService = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();

  /// Fetch similar "hot" products from the same category
  ///
  /// Parameters:
  /// - [categoryId]: The category path (e.g., "categories/electronics")
  /// - [excludePostId]: The current product ID to exclude from results
  /// - [limit]: Maximum number of products to return (default: 6)
  /// - [windowDays]: Time window for calculating popularity (default: 30 days)
  /// - [forceRefresh]: Bypass cache and fetch fresh data (default: false)
  /// - [debug]: Enable debug logging (default: false)
  ///
  /// Returns:
  /// - List of similar hot products, sorted by popularity and recency
  /// - Empty list if no similar products found or only one product in category
  Future<List<Post>> getSimilarHotProducts({
    required String categoryId,
    required String excludePostId,
    int limit = 6,
    int windowDays = 30,
    bool forceRefresh = false,
    bool debug = false,
  }) async {
    void dlog(String msg) {
      if (debug) debugPrint('[SimilarProducts] $msg');
    }

    final stopwatch = Stopwatch()..start();
    dlog('🔥 Fetching similar hot products for category: $categoryId');
    dlog('   Excluding product: $excludePostId');

    // Weights for different signals (used in both online and offline modes)
    const double wClick = 3.0;  // Each click = 3 points
    const double wSale = 10.0;  // Each completed sale = 10 points

    // Normalize category ID (remove leading slash if present)
    final normalizedCategoryId = categoryId.startsWith('/')
        ? categoryId.substring(1)
        : categoryId;

    // Try LRU cache first (unless force refresh)
    if (!forceRefresh) {
      final cached = _similarCache.get(normalizedCategoryId);
      if (cached != null) {
        // Filter out excluded product and apply limit
        final filtered = cached
            .where((p) => p.id != excludePostId)
            .take(limit)
            .toList();

        stopwatch.stop();
        dlog('✅ LRU CACHE HIT - Returning ${filtered.length} products (${stopwatch.elapsedMilliseconds}ms)');
        return filtered;
      }
      dlog('❌ LRU CACHE MISS');
    } else {
      dlog('🔄 FORCE REFRESH - Bypassing cache');
    }

    // Check connectivity
    final isOffline = !_connectivity.isConnected;

    // If offline, calculate from cached data
    if (isOffline) {
      dlog('📴 OFFLINE - Using cached data to calculate hotness...');
      try {
        // Try to get cached posts
        final cachedPostsData = await _cacheService.getCachedPosts();
        if (cachedPostsData == null || cachedPostsData.isEmpty) {
          dlog('⚠️ No cached posts available offline');
          return [];
        }

        // Filter posts by category
        final categoryPosts = <Post>[];
        for (final data in cachedPostsData) {
          final post = Post.fromJson(data);
          final postCategoryNormalized = post.categoryId.startsWith('/')
              ? post.categoryId.substring(1)
              : post.categoryId;

          if (postCategoryNormalized == normalizedCategoryId &&
              post.status == 'active' &&
              post.id != excludePostId) {
            categoryPosts.add(post);
          }
        }

        if (categoryPosts.isEmpty) {
          dlog('ℹ️ No products in category (offline)');
          return [];
        }

        dlog('📊 Found ${categoryPosts.length} cached products in category');

        // Get cached engagement data (clicks and sales)
        final cachedClicks = await _cacheService.getCachedProductClickEvents();
        final cachedSales = await _cacheService.getCachedSalesData();

        dlog('📊 Cached clicks: ${cachedClicks?.length ?? 0}, sales: ${cachedSales?.length ?? 0}');

        // Calculate hotness scores from cached data
        final since = DateTime.now().subtract(Duration(days: windowDays));
        final Map<String, double> hotnessScores = {};

        // Process cached clicks
        if (cachedClicks != null) {
          for (final click in cachedClicks) {
            final timestamp = click['timestamp'];
            DateTime? clickDate;

            if (timestamp is String) {
              try {
                clickDate = DateTime.parse(timestamp);
              } catch (_) {}
            }

            if (clickDate != null && clickDate.isAfter(since)) {
              final postId = click['postId'] as String?;
              if (postId != null) {
                hotnessScores[postId] = (hotnessScores[postId] ?? 0) + wClick;
              }
            }
          }
        }

        // Process cached sales
        if (cachedSales != null) {
          for (final sale in cachedSales) {
            final status = sale['status'] as String?;
            if (status != 'completed') continue;

            final createdAt = sale['created_at'];
            DateTime? saleDate;

            if (createdAt is String) {
              try {
                saleDate = DateTime.parse(createdAt);
              } catch (_) {}
            }

            if (saleDate != null && saleDate.isAfter(since)) {
              String? postId;
              final postRef = sale['post_ref'];
              if (postRef is String) {
                postId = postRef.split('/').last;
              }

              if (postId != null) {
                hotnessScores[postId] = (hotnessScores[postId] ?? 0) + wSale;
              }
            }
          }
        }

        // Sort by hotness
        categoryPosts.sort((a, b) {
          final scoreA = hotnessScores[a.id] ?? 0;
          final scoreB = hotnessScores[b.id] ?? 0;

          if (scoreA != scoreB) {
            return scoreB.compareTo(scoreA);
          }

          return b.createdAt.compareTo(a.createdAt);
        });

        final result = categoryPosts.take(limit).toList();
        stopwatch.stop();
        dlog('✅ OFFLINE - Calculated ${result.length} hot products from cache (${stopwatch.elapsedMilliseconds}ms)');
        return result;
      } catch (e) {
        dlog('❌ Failed to calculate from cache: $e');
        return [];
      }
    }

    // ONLINE: Fetch from Firestore
    try {
      // Step 1: Fetch all active posts in the same category
      dlog('📂 Fetching posts from Firestore...');
      final postsSnapshot = await _db
          .collection('posts')
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .get();

      // Filter by category
      final categoryPosts = <Post>[];
      for (final doc in postsSnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['_id'] = doc.id;

        final post = Post.fromJson(data);

        // Match category (handle different formats)
        final postCategoryNormalized = post.categoryId.startsWith('/')
            ? post.categoryId.substring(1)
            : post.categoryId;

        if (postCategoryNormalized == normalizedCategoryId &&
            post.status == 'active' &&
            post.id != excludePostId) {
          categoryPosts.add(post);
        }
      }

      dlog('📊 Found ${categoryPosts.length} products in category');

      // If no other products in category, return empty
      if (categoryPosts.isEmpty) {
        dlog('ℹ️ No other products in this category');
        stopwatch.stop();
        return [];
      }

      // Step 2: Calculate hotness scores
      dlog('🔥 Calculating hotness scores...');
      final since = Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: windowDays)),
      );

      final Map<String, double> hotnessScores = {};

      // 2a. Count product clicks
      final clicksSnapshot = await _db
          .collection('product_click_events')
          .where('timestamp', isGreaterThanOrEqualTo: since)
          .get();

      // Cache clicks data for offline use
      final clicksData = clicksSnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        return data;
      }).toList();

      try {
        await _cacheService.cacheProductClickEvents(clicksData);
      } catch (e) {
        dlog('⚠️ Failed to cache clicks: $e');
      }

      for (final doc in clicksSnapshot.docs) {
        final data = doc.data();
        final postId = data['postId'] as String?;
        if (postId != null) {
          hotnessScores[postId] = (hotnessScores[postId] ?? 0) + wClick;
        }
      }

      dlog('📊 Processed ${clicksSnapshot.docs.length} click events');

      // 2b. Count completed sales
      // Note: Query without compound filter to avoid index requirement
      // We'll filter by date and status in the client
      final salesSnapshot = await _db
          .collection('sales')
          .orderBy('created_at', descending: true)
          .limit(1000) // Get last 1000 sales to process
          .get();

      // Cache sales data for offline use
      final salesData = salesSnapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        // Convert Timestamp to ISO8601 string for JSON serialization
        if (data['created_at'] is Timestamp) {
          data['created_at'] = (data['created_at'] as Timestamp).toDate().toIso8601String();
        }
        // Convert DocumentReference to String for JSON serialization
        if (data['post_ref'] is DocumentReference) {
          data['post_ref'] = (data['post_ref'] as DocumentReference).path;
        }
        return data;
      }).toList();

      try {
        await _cacheService.cacheSalesData(salesData);
      } catch (e) {
        dlog('⚠️ Failed to cache sales: $e');
      }

      int validSalesCount = 0;
      for (final doc in salesSnapshot.docs) {
        final data = doc.data();

        // Filter by status and date in client
        final status = data['status'] as String?;
        if (status != 'completed') continue;

        // Check created_at is within window
        final createdAt = data['created_at'];
        if (createdAt is Timestamp) {
          if (createdAt.compareTo(since) < 0) continue; // Too old
        }

        // Extract postId from post_ref (could be DocumentReference or String)
        String? postId;
        final postRef = data['post_ref'];
        if (postRef is DocumentReference) {
          postId = postRef.id;
        } else if (postRef is String) {
          postId = postRef.split('/').last;
        }

        if (postId != null) {
          hotnessScores[postId] = (hotnessScores[postId] ?? 0) + wSale;
          validSalesCount++;
        }
      }

      dlog('📊 Processed $validSalesCount completed sales (from ${salesSnapshot.docs.length} total)');

      // Step 3: Sort products by hotness score and then by date
      categoryPosts.sort((a, b) {
        final scoreA = hotnessScores[a.id] ?? 0;
        final scoreB = hotnessScores[b.id] ?? 0;

        // First sort by hotness score (descending)
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA);
        }

        // If scores are equal, sort by creation date (newest first)
        return b.createdAt.compareTo(a.createdAt);
      });

      // Debug: Print top products with scores
      if (debug) {
        dlog('🏆 Top similar products:');
        for (final post in categoryPosts.take(5)) {
          final score = hotnessScores[post.id] ?? 0;
          dlog('   - ${post.title}: ${score.toStringAsFixed(1)} points');
        }
      }

      // Step 4: Take top N products
      final result = categoryPosts.take(limit).toList();

      // Step 5: Cache results
      // LRU cache (30 minutes)
      _similarCache.put(
        normalizedCategoryId,
        categoryPosts, // Cache all, filter on retrieval
        ttl: Duration(minutes: 30),
      );

      // Persistent cache (7 days)
      try {
        await _cacheService.cacheSimilarProducts(
          normalizedCategoryId,
          categoryPosts.map((p) => p.toJson()).toList(),
        );
        dlog('💾 Cached ${categoryPosts.length} products for offline use');
      } catch (e) {
        dlog('⚠️ Failed to cache similar products: $e');
      }

      stopwatch.stop();
      dlog('⚡ TOTAL: ${result.length} products in ${stopwatch.elapsedMilliseconds}ms');

      return result;

    } catch (e) {
      dlog('❌ Error fetching similar products: $e');

      // On error, try to return cached data
      try {
        final cached = await _cacheService.getCachedSimilarProducts(normalizedCategoryId);
        if (cached != null && cached.isNotEmpty) {
          final posts = cached.map((json) => Post.fromJson(json)).toList();
          final filtered = posts
              .where((p) => p.id != excludePostId)
              .take(limit)
              .toList();

          dlog('⚠️ Returning ${filtered.length} cached products after error');
          return filtered;
        }
      } catch (cacheError) {
        dlog('❌ Cache fallback failed: $cacheError');
      }

      return [];
    }
  }

  /// Clear all caches (LRU and persistent)
  void clearCache() {
    _similarCache.clear();
    debugPrint('[SimilarProducts] 🗑️ All caches cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return _similarCache.getStats();
  }
}
