import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/models.dart';
import 'lru_cache_service.dart';
import 'local_storage_service.dart';

/// Sales Cache Service using LRU for in-memory caching
/// 
/// Scenario 12: View Sales Status Without Internet
/// 
/// Strategy:
/// - LRU cache (max 50 sales) for frequently accessed recent sales
/// - Hive backup for persistence across app restarts
/// - Cache expiration: 10 minutes (sales status can change)
/// 
/// Why LRU for Sales:
/// - Users may have many sales over time (100+)
/// - Only recent/active sales are frequently accessed
/// - Pending sales need fast access (negotiation phase)
/// - Completed/old sales rarely accessed after initial view
class SalesCacheService {
  static final SalesCacheService _instance = SalesCacheService._internal();
  factory SalesCacheService() => _instance;
  SalesCacheService._internal();

  // LRU cache for in-memory quick access (Scenario 12 - LRU requirement)
  final LruCacheService<String, PostWithChat> _lruCache = LruCacheService(
    maxCapacity: 50, // Keep last 50 accessed sales in memory
  );

  // Hive for persistent backup
  final LocalStorageService _storage = LocalStorageService();
  // Use the box name from LocalStorageService
  static final String _salesBoxName = LocalStorageService.salesCacheBoxName;
  static const Duration _cacheTtl = Duration(minutes: 10);

  DateTime? _lastCacheTime;

  /// Cache sales data (stores in both LRU and Hive)
  Future<void> cacheSales(String userId, List<PostWithChat> sales) async {
    try {
      debugPrint('[SalesCache] 💾 Caching ${sales.length} sales for user: $userId');

      // Save to LRU cache (most recently accessed)
      for (final sale in sales) {
        final key = '${userId}_${sale.post.id}';
        _lruCache.put(key, sale, ttl: _cacheTtl);
      }

      // Save full list to Hive for persistence
      final salesData = {
        'userId': userId,
        'sales': sales.map((s) => _serializeSale(s)).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _storage.save(
        _salesBoxName,
        'sales_$userId',
        jsonEncode(salesData),
      );

      _lastCacheTime = DateTime.now();
      _lruCache.printStats();
      
      debugPrint('[SalesCache] ✅ Cached ${sales.length} sales');
    } catch (e) {
      debugPrint('[SalesCache] ❌ Failed to cache sales: $e');
    }
  }

  /// Get cached sales (tries LRU first, then Hive)
  Future<List<PostWithChat>?> getCachedSales(String userId) async {
    try {
      debugPrint('[SalesCache] 🔍 Getting cached sales for user: $userId');

      // Try Hive for full list
      final cached = _storage.get(_salesBoxName, 'sales_$userId');
      if (cached == null) {
        debugPrint('[SalesCache] ⚠️ No cached sales found');
        return null;
      }

      debugPrint('[SalesCache] 📦 Cached data type: ${cached.runtimeType}');
      debugPrint('[SalesCache] 📦 Cached data preview: ${cached.toString().substring(0, min(200, cached.toString().length))}...');

      final salesData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(salesData['timestamp'] as String);

      // Check if expired (10 minutes)
      if (DateTime.now().difference(timestamp) > _cacheTtl) {
        debugPrint('[SalesCache] ⏰ Cache expired (age: ${DateTime.now().difference(timestamp).inMinutes}min)');
        return null;
      }

      debugPrint('[SalesCache] 🔄 Deserializing ${(salesData['sales'] as List).length} sales...');
      
      final salesList = (salesData['sales'] as List)
          .map((json) => _deserializeSale(json as Map<String, dynamic>))
          .toList();

      // Populate LRU cache with retrieved sales
      for (final sale in salesList) {
        final key = '${userId}_${sale.post.id}';
        if (!_lruCache.containsKey(key)) {
          _lruCache.put(key, sale, ttl: _cacheTtl);
        }
      }

      _lastCacheTime = timestamp;
      debugPrint('[SalesCache] ✅ Retrieved ${salesList.length} sales from cache');
      
      return salesList;
    } catch (e, stackTrace) {
      debugPrint('[SalesCache] ❌ Failed to get cached sales: $e');
      debugPrint('[SalesCache] Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get a specific sale by ID (from LRU or Hive)
  Future<PostWithChat?> getCachedSale(String userId, String postId) async {
    try {
      final key = '${userId}_$postId';
      
      // Try LRU first (fast)
      final fromLru = _lruCache.get(key);
      if (fromLru != null) {
        debugPrint('[SalesCache] ✅ Sale found in LRU: $postId');
        return fromLru;
      }

      // Fallback to Hive
      final allSales = await getCachedSales(userId);
      if (allSales != null) {
        final sale = allSales.firstWhere(
          (s) => s.post.id == postId,
          orElse: () => throw Exception('Sale not found'),
        );
        
        // Add to LRU for next access
        _lruCache.put(key, sale, ttl: _cacheTtl);
        
        return sale;
      }

      return null;
    } catch (e) {
      debugPrint('[SalesCache] ❌ Sale not found: $postId');
      return null;
    }
  }

  /// Clear sales cache
  Future<void> clearCache(String userId) async {
    try {
      _lruCache.clear();
      await _storage.delete(_salesBoxName, 'sales_$userId');
      _lastCacheTime = null;
      debugPrint('[SalesCache] 🧹 Cache cleared for user: $userId');
    } catch (e) {
      debugPrint('[SalesCache] ❌ Failed to clear cache: $e');
    }
  }

  /// Get cache age in minutes
  int? get cacheAgeMinutes {
    if (_lastCacheTime == null) return null;
    return DateTime.now().difference(_lastCacheTime!).inMinutes;
  }

  /// Get cache age as human-readable string
  String? get cacheAgeString {
    final age = cacheAgeMinutes;
    if (age == null) return null;
    
    if (age < 1) return 'Just now';
    if (age == 1) return '1 minute ago';
    if (age < 60) return '$age minutes ago';
    
    final hours = (age / 60).floor();
    if (hours == 1) return '1 hour ago';
    return '$hours hours ago';
  }

  /// Get LRU cache statistics
  Map<String, dynamic> getStats() {
    return _lruCache.getStats();
  }

  /// Serialize PostWithChat to JSON
  Map<String, dynamic> _serializeSale(PostWithChat sale) {
    return {
      'post': sale.post.toJson(),
      'chatId': sale.chatId,
      'sale': sale.sale?.toJson(),
    };
  }

  /// Deserialize PostWithChat from JSON
  PostWithChat _deserializeSale(Map<String, dynamic> json) {
    try {
      // Handle both Map and already-parsed objects
      final postData = json['post'];
      final saleData = json['sale'];
      
      debugPrint('[SalesCache] 🔍 Deserializing sale...');
      debugPrint('[SalesCache]   postData type: ${postData.runtimeType}');
      debugPrint('[SalesCache]   postData keys: ${postData is Map ? (postData as Map).keys.toList() : 'N/A'}');
      
      if (postData is! Map<String, dynamic>) {
        debugPrint('[SalesCache] ❌ postData is not Map<String, dynamic>: $postData');
        throw Exception('Invalid post data type: ${postData.runtimeType}');
      }
      
      return PostWithChat(
        post: Post.fromJson(postData),
        chatId: json['chatId'] as String?,
        sale: saleData != null && saleData is Map<String, dynamic>
            ? Sale.fromJson(saleData)
            : null,
      );
    } catch (e, stackTrace) {
      debugPrint('[SalesCache] ❌ Failed to deserialize sale: $e');
      debugPrint('[SalesCache] Stack trace: $stackTrace');
      debugPrint('[SalesCache] JSON: $json');
      rethrow;
    }
  }
}

