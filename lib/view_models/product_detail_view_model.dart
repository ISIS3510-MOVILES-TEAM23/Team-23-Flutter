import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/chat_repository.dart';

class ProductDetailViewModel extends ChangeNotifier {
  final PostRepository _postRepository;
  final UserRepository _userRepository;
  final ChatRepository _chatRepository;

  ProductDetailViewModel({
    PostRepository? postRepository,
    UserRepository? userRepository,
    ChatRepository? chatRepository,
  })  : _postRepository = postRepository ?? PostRepository(),
        _userRepository = userRepository ?? UserRepository(),
        _chatRepository = chatRepository ?? ChatRepository();

  Post? product;
  User? seller;
  bool isLoading = true;
  int currentImageIndex = 0;

  Future<void> loadProduct(String productId) async {
    try {
      isLoading = true;
      notifyListeners();

      final prod = await _postRepository.getPostById(productId);
      User? user;
      if (prod != null) {
        user = await _userRepository.getUserById(prod.userId);
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
}

