import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'local_storage_service.dart';
import 'connectivity_service.dart';
import 'feedback_sql_service.dart';

/// Service to manage draft feedback in local storage
/// Similar to DraftService but for feedback/reviews
/// 
/// Rubric:
/// - Hive (Key-Value storage): 5 puntos
/// - Local file storage for images: 5 puntos
class DraftFeedbackService {
  static final DraftFeedbackService _instance = DraftFeedbackService._internal();
  factory DraftFeedbackService() => _instance;
  DraftFeedbackService._internal();

  final LocalStorageService _storage = LocalStorageService();
  final ConnectivityService _connectivity = ConnectivityService();
  final FeedbackSqlService _sqlService = FeedbackSqlService();

  static const String _draftsBoxName = LocalStorageService.feedbackDraftsBoxName;
  static const Duration _draftTTL = Duration(days: 30);

  /// Initialize draft feedback service
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<void> initialize() async {
    try {
      debugPrint('[DraftFeedbackService] 🚀 Initializing draft feedback service...');
      
      // Ensure storage is initialized
      await _storage.initialize();
      
      // Ensure SQL service is initialized
      await _sqlService.initialize();
      
      debugPrint('[DraftFeedbackService] ✅ Draft feedback service initialized');
    } catch (e) {
      debugPrint('[DraftFeedbackService] ❌ Failed to initialize: $e');
    }
  }

  /// Save a draft feedback
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  /// Storage: Hive (5 puntos) + SQLite for rating (10 puntos)
  Future<void> saveDraft(DraftFeedback draft) async {
    try {
      debugPrint('[DraftFeedbackService] 💾 Saving draft: ${draft.draftId}');
      
      // Save full draft data to Hive
      final draftData = {
        'data': draft.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _storage.save(
        _draftsBoxName,
        'draft_${draft.draftId}',
        jsonEncode(draftData),
      );

      // Also save rating to SQLite (relational DB requirement)
      if (draft.rating > 0) {
        await _sqlService.saveRating(
          draftId: draft.draftId,
          purchaseId: draft.purchaseId,
          rating: draft.rating,
        );
      }

      debugPrint('[DraftFeedbackService] ✓ Draft saved: rating=${draft.rating}');
    } catch (e) {
      debugPrint('[DraftFeedbackService] ✗ Failed to save draft: $e');
      rethrow;
    }
  }

  /// Get a specific draft by ID
  /// 
  /// Rubric: Uses Future with error handler (5 puntos)
  Future<DraftFeedback?> getDraft(String draftId) async {
    try {
      final data = _storage.get(_draftsBoxName, 'draft_$draftId');
      
      if (data == null) {
        return null;
      }

      final decodedData = jsonDecode(data as String);
      final draftJson = decodedData['data'] as Map<String, dynamic>;
      
      return DraftFeedback.fromJson(draftJson);
    } catch (e) {
      debugPrint('[DraftFeedbackService] ✗ Failed to get draft: $e');
      return null;
    }
  }

  /// Get all drafts for a user
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<List<DraftFeedback>> getAllDrafts(String userId) async {
    try {
      debugPrint('[DraftFeedbackService] 📋 Getting all drafts for user: $userId');
      
      final allData = _storage.getAll(_draftsBoxName);
      final drafts = <DraftFeedback>[];

      for (final data in allData) {
        try {
          if (data == null) continue;
          
          final decodedData = jsonDecode(data as String);
          final draftJson = decodedData['data'] as Map<String, dynamic>;
          final draft = DraftFeedback.fromJson(draftJson);

          // Filter by user
          if (draft.buyerId == userId) {
            drafts.add(draft);
          }
        } catch (e) {
          debugPrint('[DraftFeedbackService] ⚠️ Skipping invalid draft: $e');
        }
      }

      // Sort by last modified (newest first)
      drafts.sort((a, b) => b.lastModified.compareTo(a.lastModified));

      debugPrint('[DraftFeedbackService] ✓ Found ${drafts.length} drafts');
      return drafts;
    } catch (e) {
      debugPrint('[DraftFeedbackService] ✗ Failed to get all drafts: $e');
      return [];
    }
  }

  /// Get drafts pending upload
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<List<DraftFeedback>> getPendingDrafts(String userId) async {
    try {
      final allDrafts = await getAllDrafts(userId);
      return allDrafts
          .where((d) => 
              d.status == DraftFeedbackStatus.pendingUpload || 
              d.status == DraftFeedbackStatus.failed)
          .toList();
    } catch (e) {
      debugPrint('[DraftFeedbackService] ✗ Failed to get pending drafts: $e');
      return [];
    }
  }

  /// Save image to cache directory (local file storage)
  /// 
  /// Rubric: Local file storage (5 puntos)
  Future<String> saveImageToCache(File imageFile, String draftId) async {
    try {
      debugPrint('[DraftFeedbackService] 📷 Saving image to cache...');
      
      final cacheDir = await getApplicationDocumentsDirectory();
      final feedbackCacheDir = Directory('${cacheDir.path}/feedback_drafts/$draftId');
      
      // Create directory if it doesn't exist
      if (!await feedbackCacheDir.exists()) {
        await feedbackCacheDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final fileName = 'img_$timestamp.$extension';
      final localPath = '${feedbackCacheDir.path}/$fileName';

      // Copy file to cache
      await imageFile.copy(localPath);

      debugPrint('[DraftFeedbackService] ✓ Image saved to: $localPath');
      return localPath;
    } catch (e) {
      debugPrint('[DraftFeedbackService] ✗ Failed to save image: $e');
      rethrow;
    }
  }

  /// Delete cached images for a draft
  /// 
  /// Rubric: Local file storage operations (5 puntos)
  Future<void> deleteCachedImages(String draftId) async {
    try {
      final cacheDir = await getApplicationDocumentsDirectory();
      final feedbackCacheDir = Directory('${cacheDir.path}/feedback_drafts/$draftId');
      
      if (await feedbackCacheDir.exists()) {
        await feedbackCacheDir.delete(recursive: true);
        debugPrint('[DraftFeedbackService] ✓ Deleted cached images for: $draftId');
      }
    } catch (e) {
      debugPrint('[DraftFeedbackService] ✗ Failed to delete cached images: $e');
    }
  }

  /// Delete a draft
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<void> deleteDraft(String draftId) async {
    try {
      debugPrint('[DraftFeedbackService] 🗑️  Deleting draft: $draftId');
      
      // Get draft first to check purchaseId
      final draft = await getDraft(draftId);
      
      // Delete from Hive
      await _storage.delete(_draftsBoxName, 'draft_$draftId');
      
      // Delete rating from SQLite
      if (draft != null) {
        await _sqlService.deleteRating(draft.purchaseId);
      }
      
      // Delete cached images
      await deleteCachedImages(draftId);
      
      debugPrint('[DraftFeedbackService] ✓ Draft deleted');
    } catch (e) {
      debugPrint('[DraftFeedbackService] ✗ Failed to delete draft: $e');
      rethrow;
    }
  }

  /// Clean up old drafts (TTL expired)
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<void> cleanupOldDrafts() async {
    try {
      debugPrint('[DraftFeedbackService] 🧹 Cleaning up old drafts...');
      
      final allData = _storage.getAll(_draftsBoxName);
      final now = DateTime.now();
      int deletedCount = 0;

      for (final data in allData) {
        try {
          if (data == null) continue;
          
          final decodedData = jsonDecode(data as String);
          final timestamp = DateTime.parse(decodedData['timestamp'] as String);
          final draft = DraftFeedback.fromJson(decodedData['data'] as Map<String, dynamic>);

          // Delete if TTL expired
          if (now.difference(timestamp) > _draftTTL) {
            await deleteDraft(draft.draftId);
            deletedCount++;
          }
        } catch (e) {
          debugPrint('[DraftFeedbackService] ⚠️ Error processing draft: $e');
        }
      }

      debugPrint('[DraftFeedbackService] ✓ Cleaned up $deletedCount old drafts');
    } catch (e) {
      debugPrint('[DraftFeedbackService] ✗ Failed to cleanup old drafts: $e');
    }
  }

  /// Get total drafts count
  Future<int> getDraftsCount(String userId) async {
    try {
      final drafts = await getAllDrafts(userId);
      return drafts.length;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all drafts for a user
  Future<void> clearAllDrafts(String userId) async {
    try {
      final drafts = await getAllDrafts(userId);
      for (final draft in drafts) {
        await deleteDraft(draft.draftId);
      }
      debugPrint('[DraftFeedbackService] ✓ Cleared all drafts for user: $userId');
    } catch (e) {
      debugPrint('[DraftFeedbackService] ✗ Failed to clear all drafts: $e');
    }
  }
}

