import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:shared_preferences/shared_preferences.dart';
import '../data/repositories/auth_repository.dart';
import '../services/connectivity_service.dart';
import '../services/cache_service.dart';

class LoginViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;
  final ConnectivityService _connectivity = ConnectivityService();
  final CacheService _cache = CacheService();

  LoginViewModel({AuthRepository? authRepository})
      : _authRepository = authRepository ?? AuthRepository();

  String email = '';
  String password = '';
  bool isLoading = false;
  String? errorMessage;
  bool isOffline = false;

  void setEmail(String value) {
    email = value;
  }

  void setPassword(String value) {
    password = value;
  }

  /// Check if user has cached auth session (Scenario 1)
  Future<bool> checkCachedAuth() async {
    try {
      final user = firebase_auth.FirebaseAuth.instance.currentUser;

      if (user != null) {
        // User has valid Firebase session
        debugPrint('[Auth] ✓ Found cached session for: ${user.email}');

        // Cache user data for offline access
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_id', user.uid);
        await prefs.setString('cached_user_email', user.email ?? '');
        await prefs.setInt('last_login_timestamp', DateTime.now().millisecondsSinceEpoch);

        return true;
      }

      // Check if we have a cached session from previous login
      final prefs = await SharedPreferences.getInstance();
      final cachedUserId = prefs.getString('cached_user_id');
      final lastLogin = prefs.getInt('last_login_timestamp');

      if (cachedUserId != null && lastLogin != null) {
        final sessionAge = DateTime.now().millisecondsSinceEpoch - lastLogin;
        final maxAge = const Duration(days: 30).inMilliseconds;

        if (sessionAge < maxAge) {
          debugPrint('[Auth] ✓ Valid cached session (age: ${Duration(milliseconds: sessionAge).inDays} days)');
          return true;
        } else {
          debugPrint('[Auth] ⏱ Cached session expired');
          await _clearCachedAuth();
        }
      }

      return false;
    } catch (e) {
      debugPrint('[Auth] ✗ Error checking cached auth: $e');
      return false;
    }
  }

  /// Clear cached authentication data
  Future<void> _clearCachedAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user_id');
    await prefs.remove('cached_user_email');
    await prefs.remove('last_login_timestamp');
  }

  /// Login with email and password (Scenario 1b - requires internet)
  Future<firebase_auth.UserCredential?> logIn() async {
    try {
      // Check connectivity for first-time login
      isOffline = !_connectivity.isConnected;

      if (isOffline) {
        errorMessage = 'Internet connection required for login. Please connect and try again.';
        notifyListeners();
        throw Exception(errorMessage);
      }

      isLoading = true;
      errorMessage = null;
      notifyListeners();

      final userCredential = await _authRepository.signInWithEmailAndPassword(
        email,
        password,
      );

      // Cache auth data on successful login
      if (userCredential?.user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_user_id', userCredential!.user!.uid);
        await prefs.setString('cached_user_email', userCredential.user!.email ?? '');
        await prefs.setInt('last_login_timestamp', DateTime.now().millisecondsSinceEpoch);
        await prefs.setBool('has_logged_in_before', true);

        debugPrint('[Auth] ✓ Login successful, session cached');
      }

      isLoading = false;
      notifyListeners();

      return userCredential;
    } catch (e) {
      isLoading = false;
      errorMessage = _getErrorMessage(e);
      notifyListeners();
      rethrow;
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is firebase_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Incorrect password.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'network-request-failed':
          return 'Network error. Please check your connection.';
        default:
          return 'Login failed. Please try again.';
      }
    }
    return error.toString();
  }

  // ========== GOOGLE SIGN IN - COMMENTED OUT ==========
  // Future<firebase_auth.UserCredential?> signInWithGoogle() async {
  //   try {
  //     isLoading = true;
  //     notifyListeners();

  //     final userCredential = await _authRepository.signInWithGoogle();

  //     isLoading = false;
  //     notifyListeners();

  //     return userCredential;
  //   } catch (e) {
  //     isLoading = false;
  //     notifyListeners();
  //     rethrow;
  //   }
  // }
  // ========== END GOOGLE SIGN IN ==========
}

