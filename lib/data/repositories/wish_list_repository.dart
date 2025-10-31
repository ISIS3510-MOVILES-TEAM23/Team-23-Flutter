import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../models/post_model.dart';
import '../../models/wish_list_model.dart';
import '../../services/connectivity_service.dart';
import '../../services/hive_service.dart';
import '../../services/wishlist_sync_service.dart';

class WishListRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ConnectivityService _connectivityService;
  final WishlistSyncService _syncService;

  WishListRepository({
    ConnectivityService? connectivityService,
    WishlistSyncService? syncService,
  })  : _connectivityService = connectivityService ?? ConnectivityService(),
        _syncService = syncService ?? WishlistSyncService();

  // Get current user ID
  String? getCurrentUserId() {
    return auth.FirebaseAuth.instance.currentUser?.uid;
  }

  // Get user's wish list items with offline support
  Future<List<WishListItem>> getWishListItems() async {
    final userId = getCurrentUserId();
    debugPrint('🔍 [WishListRepo] Getting wishlist for user: ${userId ?? "null (not authenticated)"}');
    
    if (userId == null) {
      debugPrint('⚠️ [WishListRepo] No user ID - user not authenticated');
      return [];
    }

    // Check connectivity
    final hasConnection = await _connectivityService.checkConnectivity();
    debugPrint('🌐 [WishListRepo] Connection status: ${hasConnection ? "Online" : "Offline"}');

    try {
      if (hasConnection) {
        // Online: Fetch from Firestore
        debugPrint('📡 [WishListRepo] Fetching from Firestore...');
        final snapshot = await _firestore
            .collection('wish_list')
            .where('user_id', isEqualTo: userId)
            .get();

        debugPrint('📦 [WishListRepo] Received ${snapshot.docs.length} documents from Firestore');

        final items = snapshot.docs.map((doc) {
          final data = doc.data();
          data['_id'] = doc.id;
          debugPrint('  - Document ${doc.id}: ${data['product_title']}');
          return WishListItem.fromJson(data);
        }).toList();

        // Sort locally by added_at descending
        items.sort((a, b) => b.addedAt.compareTo(a.addedAt));

        // Cache the items
        final itemsJson = items.map((item) => item.toJson()).toList();
        await HiveService.cacheWishlistItems(userId, itemsJson);
        
        debugPrint('✅ [WishListRepo] Fetched ${items.length} items from Firestore and cached');
        return items;
      } else {
        // Offline: Return cached items
        debugPrint('📱 [WishListRepo] Loading from cache (offline)...');
        final cachedJson = HiveService.getCachedWishlistItems(userId);
        final items = cachedJson.map((json) => WishListItem.fromJson(json)).toList();
        
        debugPrint('📦 [WishListRepo] Loaded ${items.length} items from cache (offline)');
        return items;
      }
    } catch (e) {
      debugPrint('⚠️ [WishListRepo] Error getting wishlist, falling back to cache: $e');
      
      // Fallback to cache on error
      final cachedJson = HiveService.getCachedWishlistItems(userId);
      final items = cachedJson.map((json) => WishListItem.fromJson(json)).toList();
      
      debugPrint('📦 [WishListRepo] Fallback: Loaded ${items.length} items from cache');
      return items;
    }
  }

  // Add item to wish list with offline support
  Future<bool> addToWishList(Post product, {String? notes}) async {
    final userId = getCurrentUserId();
    if (userId == null) return false;

    final hasConnection = await _connectivityService.checkConnectivity();

    try {
      if (hasConnection) {
        // Online: Add to Firestore directly
        final existing = await _firestore
            .collection('wish_list')
            .where('user_id', isEqualTo: userId)
            .where('product_id', isEqualTo: product.id)
            .limit(1)
            .get();

        if (existing.docs.isNotEmpty) {
          debugPrint('ℹ️ [WishListRepo] Item already in wishlist');
          return false; // Already in wish list
        }

        await _firestore.collection('wish_list').add({
          'user_id': userId,
          'product_id': product.id,
          'product_title': product.title,
          'product_description': product.description,
          'product_price': product.price,
          'product_images': product.images,
          'added_at': FieldValue.serverTimestamp(),
          if (notes != null) 'notes': notes,
        });

        debugPrint('✅ [WishListRepo] Added to wishlist online');
        return true;
      } else {
        // Offline: Optimistic update to cache and queue for sync
        
        // Generate temporary ID
        final tempId = 'temp_${const Uuid().v4()}';
        
        // Add to local cache (optimistic UI)
        final itemJson = {
          '_id': tempId,
          'user_id': userId,
          'product_id': product.id,
          'product_title': product.title,
          'product_description': product.description,
          'product_price': product.price,
          'product_images': product.images,
          'added_at': DateTime.now().toIso8601String(),
          if (notes != null) 'notes': notes,
        };
        await HiveService.addToCachedWishlist(userId, itemJson);

        // Queue operation for sync
        await _syncService.queueAddOperation(
          productId: product.id,
          productTitle: product.title,
          productDescription: product.description,
          productPrice: product.price,
          productImages: product.images,
          notes: notes,
        );

        debugPrint('📤 [WishListRepo] Added to wishlist offline (queued)');
        return true;
      }
    } catch (e) {
      debugPrint('❌ [WishListRepo] Error adding to wishlist: $e');
      return false;
    }
  }

  // Remove item from wish list with offline support
  Future<bool> removeFromWishList(String wishListItemId, String productId) async {
    final userId = getCurrentUserId();
    if (userId == null) return false;

    final hasConnection = await _connectivityService.checkConnectivity();

    try {
      // Optimistically remove from cache (works online and offline)
      await HiveService.removeFromCachedWishlist(userId, wishListItemId);

      if (hasConnection) {
        // Online: Delete from Firestore
        await _firestore.collection('wish_list').doc(wishListItemId).delete();
        debugPrint('✅ [WishListRepo] Removed from wishlist online');
      } else {
        // Offline: Queue operation for sync
        await _syncService.queueRemoveOperation(
          wishListItemId: wishListItemId,
          productId: productId,
        );
        debugPrint('📤 [WishListRepo] Removed from wishlist offline (queued)');
      }

      return true;
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('UNAVAILABLE')) {
        print('⚠️ Cannot add to wish list (offline)');
      } else {
        print('Error adding to wish list: $e');
      }
      debugPrint('❌ [WishListRepo] Error removing from wishlist: $e');
      return false;
    }
  }

  // Remove item from wish list
  Future<bool> removeFromWishList(String wishListItemId) async {
    try {
      await _firestore.collection('wish_list').doc(wishListItemId).delete();
      return true;
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('UNAVAILABLE')) {
        print('⚠️ Cannot remove from wish list (offline)');
      } else {
        print('Error removing from wish list: $e');
      }
      return false;
    }
  }

  // Update notes for wish list item
  // Update notes for wish list item with offline support
  Future<bool> updateNotes(String wishListItemId, String notes) async {
    final userId = getCurrentUserId();
    if (userId == null) return false;

    final hasConnection = await _connectivityService.checkConnectivity();

    try {
      // Optimistically update cache (works online and offline)
      await HiveService.updateCachedWishlistNotes(userId, wishListItemId, notes);

      if (hasConnection) {
        // Online: Update Firestore
        await _firestore.collection('wish_list').doc(wishListItemId).update({
          'notes': notes,
        });
        debugPrint('✅ [WishListRepo] Updated notes online');
      } else {
        // Offline: Queue operation for sync
        await _syncService.queueUpdateNotesOperation(
          wishListItemId: wishListItemId,
          notes: notes,
        );
        debugPrint('📤 [WishListRepo] Updated notes offline (queued)');
      }

      return true;
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('UNAVAILABLE')) {
      } else {
        print('Error updating notes: $e');
      }
      debugPrint('❌ [WishListRepo] Error updating notes: $e');
    }

  // Check if product is in wish list
  Future<bool> isInWishList(String productId) async {
    final userId = getCurrentUserId();
    if (userId == null) return false;

    try {
      final snapshot = await _firestore
          .collection('wish_list')
          .where('user_id', isEqualTo: userId)
          .where('product_id', isEqualTo: productId)
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      final errorMsg = e.toString();
      if (!errorMsg.contains('UNAVAILABLE')) {
        print('Error checking wish list: $e');
      }
      return false;
    }
  }

  // Get wish list item by product ID
  Future<WishListItem?> getWishListItemByProductId(String productId) async {
    final userId = getCurrentUserId();
    if (userId == null) return null;

    try {
      final snapshot = await _firestore
          .collection('wish_list')
          .where('user_id', isEqualTo: userId)
          .where('product_id', isEqualTo: productId)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) return null;

      final doc = snapshot.docs.first;
      final data = doc.data();
      data['_id'] = doc.id;
      return WishListItem.fromJson(data);
    } catch (e) {
      final errorMsg = e.toString();
      if (!errorMsg.contains('UNAVAILABLE')) {
        print('Error getting wish list item: $e');
      }
      return null;
    }
  }
}
