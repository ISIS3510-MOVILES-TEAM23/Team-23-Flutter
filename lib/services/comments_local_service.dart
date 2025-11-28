import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/cache_service.dart';
import 'package:uuid/uuid.dart';

/// Service to manage offline comment operations
/// Handles pending comments that need to be synced to Firestore
class CommentsLocalService {
  static final CommentsLocalService _instance = CommentsLocalService._internal();
  factory CommentsLocalService() => _instance;
  CommentsLocalService._internal();

  final CacheService _cache = CacheService();
  final Uuid _uuid = const Uuid();

  /// Add a pending comment to local storage (for offline posting)
  Future<Comment> addPendingComment(Comment comment) async {
    try {
      // Generate a local ID if not provided
      final localId = comment.localId ?? _uuid.v4();
      
      // Create comment with pending status
      final pendingComment = comment.copyWith(
        isSynced: false,
        localId: localId,
      );

      debugPrint('[CommentsLocal] 💾 Adding pending comment: $localId');
      
      // Save to cache
      await _cache.cachePendingComment(
        comment.productId,
        pendingComment.toJson(),
      );

      debugPrint('[CommentsLocal] ✅ Pending comment added successfully');
      return pendingComment;
    } catch (e) {
      debugPrint('[CommentsLocal] ❌ Error adding pending comment: $e');
      rethrow;
    }
  }

  /// Get all pending comments for a specific product
  Future<List<Comment>> getPendingComments(String productId) async {
    try {
      final pendingMaps = await _cache.getPendingComments(productId);
      final comments = pendingMaps
          .map((map) => Comment.fromJson(map))
          .toList();
      
      debugPrint('[CommentsLocal] 📋 Retrieved ${comments.length} pending comments for product $productId');
      return comments;
    } catch (e) {
      debugPrint('[CommentsLocal] ❌ Error getting pending comments: $e');
      return [];
    }
  }

  /// Get all pending comments across all products (for background sync)
  Future<List<Comment>> getAllPendingComments() async {
    try {
      final pendingMaps = await _cache.getAllPendingComments();
      final comments = pendingMaps
          .map((map) => Comment.fromJson(map))
          .toList();
      
      debugPrint('[CommentsLocal] 📋 Retrieved ${comments.length} total pending comments');
      return comments;
    } catch (e) {
      debugPrint('[CommentsLocal] ❌ Error getting all pending comments: $e');
      return [];
    }
  }

  /// Mark a comment as synced and remove from pending queue
  Future<void> markCommentAsSynced(String productId, String localId, String firestoreId) async {
    try {
      debugPrint('[CommentsLocal] 🔄 Marking comment as synced: $localId -> $firestoreId');
      
      // Remove from pending queue
      await _cache.removePendingComment(productId, localId);
      
      debugPrint('[CommentsLocal] ✅ Comment marked as synced');
    } catch (e) {
      debugPrint('[CommentsLocal] ❌ Error marking comment as synced: $e');
      rethrow;
    }
  }

  /// Remove a pending comment from local storage
  Future<void> removePendingComment(String productId, String localId) async {
    try {
      debugPrint('[CommentsLocal] 🗑️ Removing pending comment: $localId');
      await _cache.removePendingComment(productId, localId);
      debugPrint('[CommentsLocal] ✅ Pending comment removed');
    } catch (e) {
      debugPrint('[CommentsLocal] ❌ Error removing pending comment: $e');
      rethrow;
    }
  }

  /// Get count of pending comments for a product
  Future<int> getPendingCommentCount(String productId) async {
    try {
      final pending = await getPendingComments(productId);
      return pending.length;
    } catch (e) {
      debugPrint('[CommentsLocal] ❌ Error getting pending comment count: $e');
      return 0;
    }
  }

  /// Get total count of all pending comments
  Future<int> getTotalPendingCommentCount() async {
    try {
      final pending = await getAllPendingComments();
      return pending.length;
    } catch (e) {
      debugPrint('[CommentsLocal] ❌ Error getting total pending comment count: $e');
      return 0;
    }
  }
}
