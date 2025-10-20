import '../../models/models.dart';
import '../../services/firestore_service.dart';

class PostRepository {
  PostRepository();

  // Get highlighted posts
  Future<List<Post>> getHighlightedPosts() async {
    return await FirestoreService.getHighlightedPosts();
  }

  // Get new posts
  Future<List<Post>> getNewPosts() async {
    return await FirestoreService.getNewPosts();
  }

  // Get posts by category
  Future<List<Post>> getPostsByCategory(
    String categoryId, {
    FilterOptions? filters,
  }) async {
    return await FirestoreService.getPostsByCategory(
      categoryId,
      filters: filters,
    );
  }

  // Get post by ID
  Future<Post?> getPostById(String postId) async {
    return await FirestoreService.getPostById(postId);
  }

  // Create post
  Future<bool> createPost(
    Map<String, dynamic> postData, {
    String? forceId,
  }) async {
    return await FirestoreService.createPost(
      postData,
      forceId: forceId,
    );
  }

  // Generate post ID
  String generatePostId() {
    return FirestoreService.generatePostId();
  }

  // Log product search event
  Future<void> logProductSearchEvent({
    required String source,
    String? query,
    String? selectedCategory,
    List<String>? suggestedCategories,
  }) async {
    await FirestoreService.logProductSearchEvent(
      source: source,
      query: query,
      selectedCategory: selectedCategory,
      suggestedCategories: suggestedCategories,
    );
  }

  // Log product click event
  Future<void> logProductClickEvent({
    required String postId,
    String? category,
    String? source,
  }) async {
    await FirestoreService.logProductClickEvent(
      postId: postId,
      category: category,
      source: source,
    );
  }

  // Get current user
  Future<User?> getCurrentUser() async {
    return await FirestoreService.getCurrentUser();
  }

  // Get user posts with chats
  Future<List<PostWithChat>> getUserPostsWithChats(String userId) async {
    return await FirestoreService.getUserPostsWithChats(userId);
  }
}

