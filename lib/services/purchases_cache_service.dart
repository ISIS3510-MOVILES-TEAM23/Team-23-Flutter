import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'lru_cache_service.dart';
import 'local_storage_service.dart';

/// Purchases Cache Service using LRU for in-memory caching
/// 
/// Similar to SalesCacheService but for user purchases
/// 
/// Strategy:
/// - LRU cache (max 5 purchases) for recently viewed purchases
/// - Hive backup for persistence across app restarts
/// - Cache expiration: 10 minutes
/// 
/// Why LRU for Purchases:
/// - Users typically have fewer purchases than sellers have sales
/// - Most recent purchases are accessed more frequently (to leave feedback)
/// - Older purchases rarely accessed after feedback is given
class PurchasesCacheService {
  static final PurchasesCacheService _instance = PurchasesCacheService._internal();
  factory PurchasesCacheService() => _instance;
  PurchasesCacheService._internal();

  // LRU cache for in-memory quick access (Scenario 12 - LRU requirement)
  final LruCacheService<String, PostWithChat> _lruCache = LruCacheService(
    maxCapacity: 5, // Keep last 5 accessed purchases in memory
  );

  // Hive for persistent backup
  final LocalStorageService _storage = LocalStorageService();
  static const String _purchasesBoxName = 'purchases_cache';
  static const Duration _cacheTtl = Duration(minutes: 10);

  DateTime? _lastCacheTime;

  /// Cache purchases data (stores in both LRU and Hive)
  Future<void> cachePurchases(String userId, List<PostWithChat> purchases) async {
    try {
      debugPrint('[PurchasesCache] 💾 Caching ${purchases.length} purchases for user: $userId');

      // Store in LRU (only most recent 5)
      for (final purchase in purchases.take(5)) {
        final key = '${userId}_${purchase.post.id}';
        _lruCache.put(key, purchase, ttl: _cacheTtl);
      }

      // Store full list in Hive for persistence
      final cacheData = {
        'purchases': purchases.map((p) => _serializePurchase(p)).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _storage.save(
        _purchasesBoxName,
        'purchases_$userId',
        jsonEncode(cacheData),
      );

      _lastCacheTime = DateTime.now();
      debugPrint('[PurchasesCache] ✅ Cached ${purchases.length} purchases (${_lruCache.size} in LRU)');
    } catch (e) {
      debugPrint('[PurchasesCache] ❌ Failed to cache purchases: $e');
    }
  }

  /// Get cached purchases (tries LRU first, then Hive)
  Future<List<PostWithChat>?> getCachedPurchases(String userId) async {
    try {
      debugPrint('[PurchasesCache] 🔍 Getting cached purchases for user: $userId');

      // Try Hive for full list
      final cached = _storage.get(_purchasesBoxName, 'purchases_$userId');
      if (cached == null) {
        debugPrint('[PurchasesCache] ⚠️ No cached purchases found');
        return null;
      }

      final purchasesData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(purchasesData['timestamp'] as String);

      // Check if expired
      if (DateTime.now().difference(timestamp) > _cacheTtl) {
        debugPrint('[PurchasesCache] ⏰ Cache expired (age: ${DateTime.now().difference(timestamp).inMinutes}min)');
        return null;
      }

      debugPrint('[PurchasesCache] 🔄 Deserializing ${(purchasesData['purchases'] as List).length} purchases...');
      
      final purchasesList = (purchasesData['purchases'] as List)
          .map((json) => _deserializePurchase(json as Map<String, dynamic>))
          .toList();

      // Populate LRU cache with retrieved purchases (only first 5)
      for (final purchase in purchasesList.take(5)) {
        final key = '${userId}_${purchase.post.id}';
        if (!_lruCache.containsKey(key)) {
          _lruCache.put(key, purchase, ttl: _cacheTtl);
        }
      }

      _lastCacheTime = timestamp;
      debugPrint('[PurchasesCache] ✅ Retrieved ${purchasesList.length} purchases from cache');
      
      return purchasesList;
    } catch (e, stackTrace) {
      debugPrint('[PurchasesCache] ❌ Failed to get cached purchases: $e');
      debugPrint('[PurchasesCache] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get a specific purchase by ID (from LRU or Hive)
  Future<PostWithChat?> getCachedPurchase(String userId, String postId) async {
    try {
      final key = '${userId}_$postId';
      
      // Try LRU first (fastest)
      final cached = _lruCache.get(key);
      if (cached != null) {
        debugPrint('[PurchasesCache] 🎯 Purchase found in LRU: $postId');
        return cached;
      }

      // Fall back to Hive
      final allPurchases = await getCachedPurchases(userId);
      if (allPurchases != null) {
        final purchase = allPurchases.cast<PostWithChat?>().firstWhere(
          (p) => p?.post.id == postId,
          orElse: () => null,
        );
        
        if (purchase != null) {
          // Add to LRU for future access
          _lruCache.put(key, purchase, ttl: _cacheTtl);
          debugPrint('[PurchasesCache] 📦 Purchase found in Hive and added to LRU: $postId');
        }
        
        return purchase;
      }

      debugPrint('[PurchasesCache] ❌ Purchase not found: $postId');
      return null;
    } catch (e) {
      debugPrint('[PurchasesCache] ❌ Error getting cached purchase: $e');
      return null;
    }
  }

  /// Clear all caches
  Future<void> clearCache(String userId) async {
    try {
      _lruCache.clear();
      await _storage.delete(_purchasesBoxName, 'purchases_$userId');
      _lastCacheTime = null;
      debugPrint('[PurchasesCache] ✅ Cache cleared for user: $userId');
    } catch (e) {
      debugPrint('[PurchasesCache] ❌ Failed to clear cache: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'lru_size': _lruCache.size,
      'lru_max_capacity': _lruCache.maxCapacity,
      'last_cache_time': _lastCacheTime?.toIso8601String(),
      'cache_age_minutes': _lastCacheTime != null
          ? DateTime.now().difference(_lastCacheTime!).inMinutes
          : null,
    };
  }

  // Serialization helpers
  Map<String, dynamic> _serializePurchase(PostWithChat purchase) {
    return {
      'post': purchase.post.toJson(),
      'chatId': purchase.chatId,
      'buyer': purchase.buyer?.toJson(), // In purchases context, this is the seller
      'sale': purchase.sale?.toJson(),
    };
  }

  PostWithChat _deserializePurchase(Map<String, dynamic> json) {
    return PostWithChat(
      post: Post.fromJson(json['post'] as Map<String, dynamic>),
      chatId: json['chatId'] as String?,
      buyer: json['buyer'] != null 
          ? User.fromJson(json['buyer'] as Map<String, dynamic>)
          : null,
      sale: json['sale'] != null
          ? Sale.fromJson(json['sale'] as Map<String, dynamic>)
          : null,
    );
  }
}

