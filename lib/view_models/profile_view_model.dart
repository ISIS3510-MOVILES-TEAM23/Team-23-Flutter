import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/auth_repository.dart';

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

  Future<void> logout() async {
    await _authRepository.signOut();
  }
}

