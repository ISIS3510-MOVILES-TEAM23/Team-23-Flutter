import 'package:flutter/material.dart';
import '../models/wish_list_model.dart';
import '../models/post_model.dart';
import '../data/repositories/wish_list_repository.dart';

class WishListViewModel extends ChangeNotifier {
  final WishListRepository _repository;

  WishListViewModel({WishListRepository? repository})
      : _repository = repository ?? WishListRepository();

  List<WishListItem> _items = [];
  bool _isLoading = true;
  String? _error;

  List<WishListItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isEmpty => _items.isEmpty && !_isLoading;

  // Load wish list items
  Future<void> loadWishList() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _items = await _repository.getWishListItems();

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Failed to load wish list';
      _isLoading = false;
      notifyListeners();
      debugPrint('Error loading wish list: $e');
    }
  }

  // Add item to wish list
  Future<bool> addToWishList(Post product, {String? notes}) async {
    try {
      final success = await _repository.addToWishList(product, notes: notes);
      if (success) {
        await loadWishList();
      }
      return success;
    } catch (e) {
      debugPrint('Error adding to wish list: $e');
      return false;
    }
  }

  // Remove item from wish list
  Future<bool> removeFromWishList(String wishListItemId) async {
    try {
      final success = await _repository.removeFromWishList(wishListItemId);
      if (success) {
        _items.removeWhere((item) => item.id == wishListItemId);
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('Error removing from wish list: $e');
      return false;
    }
  }

  // Update notes for wish list item
  Future<bool> updateNotes(String wishListItemId, String notes) async {
    try {
      final success = await _repository.updateNotes(wishListItemId, notes);
      if (success) {
        final index = _items.indexWhere((item) => item.id == wishListItemId);
        if (index != -1) {
          _items[index] = _items[index].copyWith(notes: notes);
          notifyListeners();
        }
      }
      return success;
    } catch (e) {
      debugPrint('Error updating notes: $e');
      return false;
    }
  }

  // Check if product is in wish list
  Future<bool> isInWishList(String productId) async {
    return await _repository.isInWishList(productId);
  }

  // Format price
  String formatPrice(int cents) {
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  // Get total items count
  int get totalItems => _items.length;

  // Get total value
  int get totalValue => _items.fold(0, (sum, item) => sum + item.productPrice);

  String get formattedTotalValue => formatPrice(totalValue);
}
