import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/models.dart';

/// Service to manage Hive local database operations
class HiveService {
  static const String _syncQueueBoxName = 'sync_queue';
  static const String _userCacheBoxName = 'user_cache';
  static const String _wishlistCacheBoxName = 'wishlist_cache';
  static const String _wishlistMetaBoxName = 'wishlist_meta';
  
  static Box<SyncQueueItem>? _syncQueueBox;
  static Box<Map>? _userCacheBox;
  static Box<Map>? _wishlistCacheBox;
  static Box<Map>? _wishlistMetaBox;

  /// Initialize Hive and open boxes
  static Future<void> initialize() async {
    try {
      debugPrint('🗄️ [HiveService] Initializing Hive...');
      await Hive.initFlutter();
      
      // Register adapters
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(SyncQueueItemAdapter());
      }
      
      // Open boxes
      _syncQueueBox = await Hive.openBox<SyncQueueItem>(_syncQueueBoxName);
      _userCacheBox = await Hive.openBox<Map>(_userCacheBoxName);
      _wishlistCacheBox = await Hive.openBox<Map>(_wishlistCacheBoxName);
      _wishlistMetaBox = await Hive.openBox<Map>(_wishlistMetaBoxName);
      
      debugPrint('🗄️ [HiveService] Hive initialized successfully');
      debugPrint('🗄️ [HiveService] Sync queue items: ${_syncQueueBox?.length ?? 0}');
      debugPrint('🗄️ [HiveService] Cached users: ${_userCacheBox?.length ?? 0}');
      debugPrint('🗄️ [HiveService] Cached wishlist items: ${_wishlistCacheBox?.length ?? 0}');
    } catch (e, stackTrace) {
      debugPrint('❌ [HiveService] Error initializing Hive: $e');
      debugPrint('❌ [HiveService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  // ==================== Sync Queue Operations ====================

  /// Add item to sync queue
  static Future<void> addToSyncQueue(SyncQueueItem item) async {
    try {
      await _syncQueueBox?.put(item.operationId, item);
      debugPrint('✅ [HiveService] Added to sync queue: ${item.type} (${item.operationId})');
    } catch (e) {
      debugPrint('❌ [HiveService] Error adding to sync queue: $e');
      rethrow;
    }
  }

  /// Get all items from sync queue
  static List<SyncQueueItem> getAllSyncQueueItems() {
    try {
      final items = _syncQueueBox?.values.toList() ?? [];
      debugPrint('📋 [HiveService] Retrieved ${items.length} sync queue items');
      return items;
    } catch (e) {
      debugPrint('❌ [HiveService] Error getting sync queue items: $e');
      return [];
    }
  }

  /// Get sync queue items by type
  static List<SyncQueueItem> getSyncQueueItemsByType(String type) {
    try {
      final items = _syncQueueBox?.values
          .where((item) => item.type == type)
          .toList() ?? [];
      debugPrint('📋 [HiveService] Retrieved ${items.length} sync queue items of type: $type');
      return items;
    } catch (e) {
      debugPrint('❌ [HiveService] Error getting sync queue items by type: $e');
      return [];
    }
  }

  /// Update sync queue item (for retry count, error message, etc.)
  static Future<void> updateSyncQueueItem(SyncQueueItem item) async {
    try {
      await _syncQueueBox?.put(item.operationId, item);
      debugPrint('🔄 [HiveService] Updated sync queue item: ${item.operationId}');
    } catch (e) {
      debugPrint('❌ [HiveService] Error updating sync queue item: $e');
      rethrow;
    }
  }

  /// Remove item from sync queue
  static Future<void> removeFromSyncQueue(String operationId) async {
    try {
      await _syncQueueBox?.delete(operationId);
      debugPrint('🗑️ [HiveService] Removed from sync queue: $operationId');
    } catch (e) {
      debugPrint('❌ [HiveService] Error removing from sync queue: $e');
      rethrow;
    }
  }

  /// Clear all sync queue items
  static Future<void> clearSyncQueue() async {
    try {
      await _syncQueueBox?.clear();
      debugPrint('🧹 [HiveService] Cleared sync queue');
    } catch (e) {
      debugPrint('❌ [HiveService] Error clearing sync queue: $e');
      rethrow;
    }
  }

  /// Get sync queue count
  static int getSyncQueueCount() {
    return _syncQueueBox?.length ?? 0;
  }

  // ==================== User Cache Operations ====================

  /// Cache user data locally
  static Future<void> cacheUser(User user) async {
    try {
      await _userCacheBox?.put(user.id, user.toJson());
      debugPrint('💾 [HiveService] Cached user: ${user.id} (${user.name})');
    } catch (e) {
      debugPrint('❌ [HiveService] Error caching user: $e');
      rethrow;
    }
  }

  /// Get cached user by ID
  static User? getCachedUser(String userId) {
    try {
      final userMap = _userCacheBox?.get(userId);
      if (userMap != null) {
        debugPrint('📦 [HiveService] Retrieved cached user: $userId');
        return User.fromJson(Map<String, dynamic>.from(userMap));
      }
      debugPrint('🔍 [HiveService] No cached user found: $userId');
      return null;
    } catch (e) {
      debugPrint('❌ [HiveService] Error getting cached user: $e');
      return null;
    }
  }

  /// Update cached user (for optimistic UI)
  static Future<void> updateCachedUser(String userId, Map<String, dynamic> updates) async {
    try {
      final userMap = _userCacheBox?.get(userId);
      if (userMap != null) {
        final updatedMap = Map<String, dynamic>.from(userMap);
        updatedMap.addAll(updates);
        await _userCacheBox?.put(userId, updatedMap);
        debugPrint('🔄 [HiveService] Updated cached user: $userId');
      } else {
        debugPrint('⚠️ [HiveService] Cannot update non-existent cached user: $userId');
      }
    } catch (e) {
      debugPrint('❌ [HiveService] Error updating cached user: $e');
      rethrow;
    }
  }

  /// Remove cached user
  static Future<void> removeCachedUser(String userId) async {
    try {
      await _userCacheBox?.delete(userId);
      debugPrint('🗑️ [HiveService] Removed cached user: $userId');
    } catch (e) {
      debugPrint('❌ [HiveService] Error removing cached user: $e');
      rethrow;
    }
  }

  /// Clear all cached users
  static Future<void> clearUserCache() async {
    try {
      await _userCacheBox?.clear();
      debugPrint('🧹 [HiveService] Cleared user cache');
    } catch (e) {
      debugPrint('❌ [HiveService] Error clearing user cache: $e');
      rethrow;
    }
  }

  // ==================== Wishlist Cache Operations ====================

  /// Cache wishlist items for a user
  static Future<void> cacheWishlistItems(String userId, List<Map<String, dynamic>> items) async {
    try {
      await _wishlistCacheBox?.put(userId, {'items': items});
      await _wishlistMetaBox?.put(userId, {
        'last_synced': DateTime.now().toIso8601String(),
        'item_count': items.length,
      });
      debugPrint('💾 [HiveService] Cached ${items.length} wishlist items for user: $userId');
    } catch (e) {
      debugPrint('❌ [HiveService] Error caching wishlist items: $e');
      rethrow;
    }
  }

  /// Get cached wishlist items for a user
  static List<Map<String, dynamic>> getCachedWishlistItems(String userId) {
    try {
      final data = _wishlistCacheBox?.get(userId);
      if (data != null && data['items'] != null) {
        final items = (data['items'] as List)
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
        debugPrint('📦 [HiveService] Retrieved ${items.length} cached wishlist items for user: $userId');
        return items;
      }
      debugPrint('🔍 [HiveService] No cached wishlist items found for user: $userId');
      return [];
    } catch (e) {
      debugPrint('❌ [HiveService] Error getting cached wishlist items: $e');
      return [];
    }
  }

  /// Add item to cached wishlist (optimistic update)
  static Future<void> addToCachedWishlist(String userId, Map<String, dynamic> item) async {
    try {
      final items = getCachedWishlistItems(userId);
      
      // Check if already exists
      final exists = items.any((i) => i['product_id'] == item['product_id']);
      if (exists) {
        debugPrint('ℹ️ [HiveService] Item already in cached wishlist');
        return;
      }
      
      items.insert(0, item); // Add to beginning (newest first)
      await cacheWishlistItems(userId, items);
      debugPrint('✅ [HiveService] Added item to cached wishlist');
    } catch (e) {
      debugPrint('❌ [HiveService] Error adding to cached wishlist: $e');
      rethrow;
    }
  }

  /// Remove item from cached wishlist (optimistic update)
  static Future<void> removeFromCachedWishlist(String userId, String wishlistItemId) async {
    try {
      final items = getCachedWishlistItems(userId);
      items.removeWhere((item) => item['_id'] == wishlistItemId);
      await cacheWishlistItems(userId, items);
      debugPrint('🗑️ [HiveService] Removed item from cached wishlist');
    } catch (e) {
      debugPrint('❌ [HiveService] Error removing from cached wishlist: $e');
      rethrow;
    }
  }

  /// Update notes in cached wishlist item
  static Future<void> updateCachedWishlistNotes(String userId, String wishlistItemId, String notes) async {
    try {
      final items = getCachedWishlistItems(userId);
      final index = items.indexWhere((item) => item['_id'] == wishlistItemId);
      if (index != -1) {
        items[index]['notes'] = notes;
        await cacheWishlistItems(userId, items);
        debugPrint('🔄 [HiveService] Updated notes in cached wishlist');
      }
    } catch (e) {
      debugPrint('❌ [HiveService] Error updating cached wishlist notes: $e');
      rethrow;
    }
  }

  /// Get wishlist last sync time
  static DateTime? getWishlistLastSyncTime(String userId) {
    try {
      final meta = _wishlistMetaBox?.get(userId);
      if (meta != null && meta['last_synced'] != null) {
        return DateTime.parse(meta['last_synced']);
      }
      return null;
    } catch (e) {
      debugPrint('❌ [HiveService] Error getting wishlist last sync time: $e');
      return null;
    }
  }

  /// Clear cached wishlist for a user
  static Future<void> clearCachedWishlist(String userId) async {
    try {
      await _wishlistCacheBox?.delete(userId);
      await _wishlistMetaBox?.delete(userId);
      debugPrint('🧹 [HiveService] Cleared cached wishlist for user: $userId');
    } catch (e) {
      debugPrint('❌ [HiveService] Error clearing cached wishlist: $e');
      rethrow;
    }
  }

  // ==================== General Operations ====================

  /// Close all boxes
  static Future<void> close() async {
    try {
      await _syncQueueBox?.close();
      await _userCacheBox?.close();
      await _wishlistCacheBox?.close();
      await _wishlistMetaBox?.close();
      debugPrint('🔒 [HiveService] Closed all boxes');
    } catch (e) {
      debugPrint('❌ [HiveService] Error closing boxes: $e');
    }
  }

  /// Dispose and close Hive
  static Future<void> dispose() async {
    try {
      await close();
      await Hive.close();
      debugPrint('👋 [HiveService] Disposed Hive');
    } catch (e) {
      debugPrint('❌ [HiveService] Error disposing Hive: $e');
    }
  }
}
