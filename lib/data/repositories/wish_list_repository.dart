import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../../models/wish_list_model.dart';
import '../../models/post_model.dart';

class WishListRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user ID
  String? getCurrentUserId() {
    return auth.FirebaseAuth.instance.currentUser?.uid;
  }

  // Get user's wish list items
  Future<List<WishListItem>> getWishListItems() async {
    final userId = getCurrentUserId();
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection('wish_list')
          .where('user_id', isEqualTo: userId)
          .get();

      final items = snapshot.docs.map((doc) {
        final data = doc.data();
        data['_id'] = doc.id;
        return WishListItem.fromJson(data);
      }).toList();

      // Sort locally by added_at descending
      items.sort((a, b) => b.addedAt.compareTo(a.addedAt));

      return items;
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('UNAVAILABLE')) {
        print('⚠️ Wish list unavailable (offline)');
      } else {
        print('Error getting wish list: $e');
      }
      return [];
    }
  }

  // Add item to wish list
  Future<bool> addToWishList(Post product, {String? notes}) async {
    final userId = getCurrentUserId();
    if (userId == null) return false;

    try {
      // Check if item already exists
      final existing = await _firestore
          .collection('wish_list')
          .where('user_id', isEqualTo: userId)
          .where('product_id', isEqualTo: product.id)
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        return false; // Already in wish list
      }

      // Add new item
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

      return true;
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('UNAVAILABLE')) {
        print('⚠️ Cannot add to wish list (offline)');
      } else {
        print('Error adding to wish list: $e');
      }
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
  Future<bool> updateNotes(String wishListItemId, String notes) async {
    try {
      await _firestore.collection('wish_list').doc(wishListItemId).update({
        'notes': notes,
      });
      return true;
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('UNAVAILABLE')) {
        print('⚠️ Cannot update notes (offline)');
      } else {
        print('Error updating notes: $e');
      }
      return false;
    }
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
