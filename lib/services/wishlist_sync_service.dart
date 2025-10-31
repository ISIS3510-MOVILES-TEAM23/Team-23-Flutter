import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'connectivity_service.dart';
import 'hive_service.dart';

/// Service to handle wishlist synchronization with offline support
class WishlistSyncService {
  final ConnectivityService _connectivityService;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<bool>? _connectivitySubscription;
  
  WishlistSyncService({ConnectivityService? connectivityService})
      : _connectivityService = connectivityService ?? ConnectivityService();

  /// Start monitoring connectivity and sync when online
  void startMonitoring() {
    _connectivitySubscription = _connectivityService.connectionStream.listen((hasConnection) {
      if (hasConnection) {
        debugPrint('📡 [WishlistSync] Connection restored, syncing wishlist...');
        // Run sync in background without blocking
        syncPendingOperations().catchError((e) {
          debugPrint('⚠️ [WishlistSync] Error during background sync: $e');
        });
      }
    });
  }

  /// Stop monitoring
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
  }

  /// Add wishlist operation to sync queue
  Future<void> queueAddOperation({
    required String productId,
    required String productTitle,
    required String productDescription,
    required int productPrice,
    required List<String> productImages,
    String? notes,
  }) async {
    final userId = _getCurrentUserId();
    if (userId == null) return;

    final operationId = const Uuid().v4();
    final syncItem = SyncQueueItem(
      operationId: operationId,
      type: 'wishlist_add',
      payload: {
        'user_id': userId,
        'product_id': productId,
        'product_title': productTitle,
        'product_description': productDescription,
        'product_price': productPrice,
        'product_images': productImages,
        if (notes != null) 'notes': notes,
        'added_at': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
    );

    await HiveService.addToSyncQueue(syncItem);
    debugPrint('📤 [WishlistSync] Queued add operation: $productTitle');
  }

  /// Remove wishlist operation to sync queue
  Future<void> queueRemoveOperation({
    required String wishListItemId
  }) async {
    final operationId = const Uuid().v4();
    final syncItem = SyncQueueItem(
      operationId: operationId,
      type: 'wishlist_remove',
      payload: {
        'wishlist_item_id': wishListItemId,
      },
      createdAt: DateTime.now(),
    );

    await HiveService.addToSyncQueue(syncItem);
    debugPrint('📤 [WishlistSync] Queued remove operation: $wishListItemId');
  }

  /// Update notes operation to sync queue
  Future<void> queueUpdateNotesOperation({
    required String wishListItemId,
    required String notes,
  }) async {
    final operationId = const Uuid().v4();
    final syncItem = SyncQueueItem(
      operationId: operationId,
      type: 'wishlist_update_notes',
      payload: {
        'wishlist_item_id': wishListItemId,
        'notes': notes,
      },
      createdAt: DateTime.now(),
    );

    await HiveService.addToSyncQueue(syncItem);
    debugPrint('📤 [WishlistSync] Queued update notes operation');
  }

  /// Sync all pending wishlist operations
  Future<void> syncPendingOperations() async {
    final addItems = HiveService.getSyncQueueItemsByType('wishlist_add');
    final removeItems = HiveService.getSyncQueueItemsByType('wishlist_remove');
    final updateItems = HiveService.getSyncQueueItemsByType('wishlist_update_notes');

    debugPrint('🔄 [WishlistSync] Syncing ${addItems.length} adds, ${removeItems.length} removes, ${updateItems.length} updates');

    // Process adds
    for (final item in addItems) {
      await _syncAddOperation(item);
    }

    // Process removes
    for (final item in removeItems) {
      await _syncRemoveOperation(item);
    }

    // Process updates
    for (final item in updateItems) {
      await _syncUpdateNotesOperation(item);
    }
  }

  /// Sync a single add operation
  Future<void> _syncAddOperation(SyncQueueItem item) async {
    if (item.retryCount >= 3) {
      debugPrint('❌ [WishlistSync] Max retries reached for add operation: ${item.operationId}');
      await HiveService.removeFromSyncQueue(item.operationId);
      return;
    }

    try {
      final payload = item.payload;
      
      // Check if item already exists (idempotency)
      final existing = await _firestore
          .collection('wish_list')
          .where('user_id', isEqualTo: payload['user_id'])
          .where('product_id', isEqualTo: payload['product_id'])
          .limit(1)
          .get();

      if (existing.docs.isEmpty) {
        // Add new item
        await _firestore.collection('wish_list').add({
          'user_id': payload['user_id'],
          'product_id': payload['product_id'],
          'product_title': payload['product_title'],
          'product_description': payload['product_description'],
          'product_price': payload['product_price'],
          'product_images': payload['product_images'],
          'added_at': FieldValue.serverTimestamp(),
          if (payload['notes'] != null) 'notes': payload['notes'],
        });
        debugPrint('✅ [WishlistSync] Successfully synced add operation');
      } else {
        debugPrint('ℹ️ [WishlistSync] Item already exists, skipping add');
      }

      // Remove from queue
      await HiveService.removeFromSyncQueue(item.operationId);
    } catch (e) {
      debugPrint('⚠️ [WishlistSync] Error syncing add operation: $e');
      
      // Update retry count with exponential backoff
      final updatedItem = item.copyWith(
        retryCount: item.retryCount + 1,
        lastAttemptAt: DateTime.now(),
        errorMessage: e.toString(),
      );
      await HiveService.updateSyncQueueItem(updatedItem);

      // Schedule retry with exponential backoff: 5s, 15s, 45s
      final delay = Duration(seconds: 5 * (item.retryCount + 1) * (item.retryCount + 1));
      Timer(delay, () => _syncAddOperation(updatedItem));
    }
  }

  /// Sync a single remove operation
  Future<void> _syncRemoveOperation(SyncQueueItem item) async {
    if (item.retryCount >= 3) {
      debugPrint('❌ [WishlistSync] Max retries reached for remove operation: ${item.operationId}');
      await HiveService.removeFromSyncQueue(item.operationId);
      return;
    }

    try {
      final payload = item.payload;
      final wishlistItemId = payload['wishlist_item_id'];
      
      // Check if document exists before deleting (idempotency)
      final doc = await _firestore.collection('wish_list').doc(wishlistItemId).get();
      if (doc.exists) {
        await _firestore.collection('wish_list').doc(wishlistItemId).delete();
        debugPrint('✅ [WishlistSync] Successfully synced remove operation');
      } else {
        debugPrint('ℹ️ [WishlistSync] Item already removed, skipping delete');
      }

      // Remove from queue
      await HiveService.removeFromSyncQueue(item.operationId);
    } catch (e) {
      debugPrint('⚠️ [WishlistSync] Error syncing remove operation: $e');
      
      final updatedItem = item.copyWith(
        retryCount: item.retryCount + 1,
        lastAttemptAt: DateTime.now(),
        errorMessage: e.toString(),
      );
      await HiveService.updateSyncQueueItem(updatedItem);

      final delay = Duration(seconds: 5 * (item.retryCount + 1) * (item.retryCount + 1));
      Timer(delay, () => _syncRemoveOperation(updatedItem));
    }
  }

  /// Sync a single update notes operation
  Future<void> _syncUpdateNotesOperation(SyncQueueItem item) async {
    if (item.retryCount >= 3) {
      debugPrint('❌ [WishlistSync] Max retries reached for update operation: ${item.operationId}');
      await HiveService.removeFromSyncQueue(item.operationId);
      return;
    }

    try {
      final payload = item.payload;
      final wishlistItemId = payload['wishlist_item_id'];
      final notes = payload['notes'];
      
      // Check if document exists before updating
      final doc = await _firestore.collection('wish_list').doc(wishlistItemId).get();
      if (doc.exists) {
        await _firestore.collection('wish_list').doc(wishlistItemId).update({
          'notes': notes,
        });
        debugPrint('✅ [WishlistSync] Successfully synced update notes operation');
      } else {
        debugPrint('⚠️ [WishlistSync] Item not found, cannot update notes');
      }

      // Remove from queue
      await HiveService.removeFromSyncQueue(item.operationId);
    } catch (e) {
      debugPrint('⚠️ [WishlistSync] Error syncing update operation: $e');
      
      final updatedItem = item.copyWith(
        retryCount: item.retryCount + 1,
        lastAttemptAt: DateTime.now(),
        errorMessage: e.toString(),
      );
      await HiveService.updateSyncQueueItem(updatedItem);

      final delay = Duration(seconds: 5 * (item.retryCount + 1) * (item.retryCount + 1));
      Timer(delay, () => _syncUpdateNotesOperation(updatedItem));
    }
  }

  /// Get current user ID
  String? _getCurrentUserId() {
    return auth.FirebaseAuth.instance.currentUser?.uid;
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
  }
}
