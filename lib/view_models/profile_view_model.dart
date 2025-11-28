import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../services/cache_service.dart';
import '../services/firestore_service.dart';

class ProfileViewModel extends ChangeNotifier {
  final UserRepository _userRepository;
  final AuthRepository _authRepository;

  ProfileViewModel({UserRepository? userRepository, AuthRepository? authRepository})
      : _userRepository = userRepository ?? UserRepository(),
        _authRepository = authRepository ?? AuthRepository();

  User? currentUser;
  List<Post> myProducts = [];
  bool isLoading = true;

  Future<void> loadUserData() async {
    try {
      isLoading = true;
      notifyListeners();

      final user = await _userRepository.getCurrentUser();
      List<Post> products = [];
      if (user != null) {
        products = await _userRepository.getUserPosts(user.id);
      }

      currentUser = user;
      myProducts = products;
      isLoading = false;
      notifyListeners();

      // Preload comments for recent products into LRU cache
      _preloadCommentsForProducts(products);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateProfile(
    String? name,
    String? email,
    String? password,
  ) async {
    if (currentUser == null) return;

    try {
      await _userRepository.updateUserProfile(
        userId: currentUser!.id,
        name: name ?? currentUser!.name,
        email: email ?? currentUser!.email,
        password: password,
      );
      // Reload user data
      await loadUserData();
    } catch (e) {
      rethrow;
    }
  }

  /// Preload comments for user's products into LRU cache (top 10 most recent)
  void _preloadCommentsForProducts(List<Post> products) {
    if (products.isEmpty) return;

    // Sort by created_at descending (most recent first)
    final sortedProducts = List<Post>.from(products)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    // Take top 10
    final topProducts = sortedProducts.take(10).toList();

    for (final product in topProducts) {
      // Fetch comments once and cache in LRU
      FirestoreService.getComments(product.id).first.then((comments) {
        CacheService().putCommentsInLru(product.id, comments);
      }).catchError((e) {
        debugPrint('[ProfileViewModel] Failed to preload comments for product ${product.id}: $e');
      });
    }
  }

  Future<void> logout() async {
    await _authRepository.signOut();
  }
}

