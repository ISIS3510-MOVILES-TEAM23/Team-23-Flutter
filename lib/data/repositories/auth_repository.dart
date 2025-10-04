import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../../services/auth_service.dart';
import '../../models/models.dart';
import 'user_repository.dart';

class AuthRepository {
  final AuthService _authService;
  final UserRepository _userRepository;

  AuthRepository({
    AuthService? authService,
    UserRepository? userRepository,
  })  : _authService = authService ?? AuthService(),
        _userRepository = userRepository ?? UserRepository();

  // Stream for auth state changes
  Stream<firebase_auth.User?> get authStateChanges => _authService.authStateChanges;

  // Get current Firebase user
  firebase_auth.User? get currentFirebaseUser => _authService.currentUser;

  // Sign up with email and password
  Future<firebase_auth.UserCredential?> signUpWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _authService.signUpWithEmailAndPassword(email, password);
  }

  // Sign in with email and password
  Future<firebase_auth.UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    return await _authService.signInWithEmailAndPassword(email, password);
  }

  // Sign in with Google
  Future<firebase_auth.UserCredential?> signInWithGoogle() async {
    return await _authService.signInWithGoogle();
  }

  // Sign out
  Future<void> signOut() async {
    await _authService.signOut();
  }

  // Get current user (from Firestore)
  Future<User?> getCurrentUser() async {
    return await _userRepository.getCurrentUser();
  }

  // Create user in Firestore
  Future<User?> createUser() async {
    return await _userRepository.createUser();
  }
}

