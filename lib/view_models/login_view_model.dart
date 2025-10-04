import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../data/repositories/auth_repository.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  LoginViewModel({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  String email = '';
  String password = '';
  bool isLoading = false;

  void setEmail(String value) {
    email = value;
  }

  void setPassword(String value) {
    password = value;
  }

  Future<firebase_auth.UserCredential?> logIn() async {
    try {
      isLoading = true;
      notifyListeners();

      final userCredential = await _authRepository.signInWithEmailAndPassword(
        email,
        password,
      );

      isLoading = false;
      notifyListeners();

      return userCredential;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<firebase_auth.UserCredential?> signInWithGoogle() async {
    try {
      isLoading = true;
      notifyListeners();

      final userCredential = await _authRepository.signInWithGoogle();

      isLoading = false;
      notifyListeners();

      return userCredential;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }
}

