import '../../models/models.dart';
import '../../services/firestore_service.dart';

class UserRepository {
  UserRepository();

  // Get current user
  Future<User?> getCurrentUser() async {
    return await FirestoreService.getCurrentUser();
  }

  // Create user
  Future<User?> createUser() async {
    return await FirestoreService.createUser();
  }

  // Get user by ID
  Future<User> getUserById(String userId) async {
    return await FirestoreService.getUserById(userId);
  }

  // Update user profile
  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String email,
    String? password,
  }) async {
    await FirestoreService.updateUserProfile(
      userId: userId,
      name: name,
      email: email,
      password: password,
    );
  }

  // Get user posts
  Future<List<Post>> getUserPosts(String userId) async {
    return await FirestoreService.getUserPosts(userId);
  }

  // Get user purchases
  Future<List<Post>> getUserPurchases(String userId) async {
    return await FirestoreService.getUserPurchases(userId);
  }

  // Get user favorites
  Future<List<Post>> getUserFavorites(String userId) async {
    return await FirestoreService.getUserFavorites(userId);
  }
}

