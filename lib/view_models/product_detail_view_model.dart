import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/chat_repository.dart';
import '../data/repositories/wish_list_repository.dart';
import '../services/firestore_service.dart';

class ProductDetailViewModel extends ChangeNotifier {
  final PostRepository _postRepository;
  final UserRepository _userRepository;
  final ChatRepository _chatRepository;
  final WishListRepository _wishListRepository;

  ProductDetailViewModel({
    PostRepository? postRepository,
    UserRepository? userRepository,
    ChatRepository? chatRepository,
    WishListRepository? wishListRepository,
  })  : _postRepository = postRepository ?? PostRepository(),
        _userRepository = userRepository ?? UserRepository(),
        _chatRepository = chatRepository ?? ChatRepository(),
        _wishListRepository = wishListRepository ?? WishListRepository();

  Post? product;
  User? seller;
  bool isLoading = true;
  bool isInWishList = false;
  int currentImageIndex = 0;

  Future<void> loadProduct(String productId) async {
    try {
      isLoading = true;
      notifyListeners();

      final prod = await _postRepository.getPostById(productId);
      User? user;
      if (prod != null) {
        user = await _userRepository.getUserById(prod.userId);

        // Registrar click del producto SOLO si NO es propio
        final currentUserId = await _userRepository.getCurrentUserId();
        if (currentUserId != null && prod.userId != currentUserId) {
          _logProductClick(prod);
        }

        // Check if product is in wish list
        isInWishList = await _wishListRepository.isInWishList(productId);
      }

      product = prod;
      seller = user;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
  
  // Registrar click de producto en product_click_events (solo para productos de otros)
  void _logProductClick(Post post) {
    try {
      final categoryName = _resolveCategoryName(post.categoryId);
      FirestoreService.logProductClickEvent(
        postId: post.id,
        category: categoryName,
        source: 'product_detail_view',
      );
    } catch (e) {
      // Error silencioso, no afectar la carga del producto
      print('Error logging product click: $e');
    }
  }
  
  String? _resolveCategoryName(String? rawCategory) {
    if (rawCategory == null) return null;
    final trimmed = rawCategory.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('/')) return trimmed;
    final parts = trimmed.split('/');
    return parts.isNotEmpty ? parts.last : trimmed;
  }

  Future<String> initiateChat() async {
    if (product == null || seller == null) {
      throw Exception('Product or seller not loaded');
    }

    try {
      final chatId = await _chatRepository.getOrCreateProductChat(
        product!.id,
        seller!.id,
      );
      return chatId;
    } catch (e) {
      rethrow;
    }
  }

  void setCurrentImageIndex(int index) {
    currentImageIndex = index;
    notifyListeners();
  }

  String formatDollars(int cents) {
    return '\$${(cents / 100).toStringAsFixed(2)}';
  }

  Future<bool> toggleWishList() async {
    if (product == null) return false;

    try {
      if (isInWishList) {
        // Remove from wish list
        final wishListItem = await _wishListRepository.getWishListItemByProductId(product!.id);
        if (wishListItem != null) {
          final success = await _wishListRepository.removeFromWishList(wishListItem.id);
          if (success) {
            isInWishList = false;
            notifyListeners();
          }
          return success;
        }
        return false;
      } else {
        // Add to wish list
        final success = await _wishListRepository.addToWishList(product!);
        if (success) {
          isInWishList = true;
          notifyListeners();
        }
        return success;
      }
    } catch (e) {
      debugPrint('Error toggling wish list: $e');
      return false;
    }
  }
}

