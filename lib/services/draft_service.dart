import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';
import 'local_storage_service.dart';
import 'connectivity_service.dart';

/// Service to manage draft posts in local storage (Scenario 8)
class DraftService {
  static final DraftService _instance = DraftService._internal();
  factory DraftService() => _instance;
  DraftService._internal();

  final LocalStorageService _storage = LocalStorageService();
  final ConnectivityService _connectivity = ConnectivityService();

  static const String _draftsBoxName = 'drafts';
  static const Duration _draftTTL = Duration(days: 30);

  /// Initialize draft service
  Future<void> initialize() async {
    try {
      debugPrint('[DraftService] 🚀 Initializing draft service...');
      // Ensure storage is initialized
      await _storage.initialize();
      debugPrint('[DraftService] ✅ Draft service initialized');
    } catch (e) {
      debugPrint('[DraftService] ❌ Failed to initialize: $e');
    }
  }

  /// Save a draft (auto-save or manual)
  Future<void> saveDraft(DraftPost draft) async {
    try {
      debugPrint('[DraftService] 💾 Saving draft: ${draft.draftId}');
      
      final draftData = {
        'data': draft.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _storage.save(
        _draftsBoxName,
        'draft_${draft.draftId}',
        jsonEncode(draftData),
      );

      debugPrint('[DraftService] ✓ Draft saved: ${draft.title.isEmpty ? "(untitled)" : draft.title}');
    } catch (e) {
      debugPrint('[DraftService] ✗ Failed to save draft: $e');
      rethrow;
    }
  }

  /// Get a specific draft by ID
  Future<DraftPost?> getDraft(String draftId) async {
    try {
      final cached = _storage.get(_draftsBoxName, 'draft_$draftId');
      if (cached == null) {
        debugPrint('[DraftService] ⚠️ Draft not found: $draftId');
        return null;
      }

      final draftData = jsonDecode(cached) as Map<String, dynamic>;
      final timestamp = DateTime.parse(draftData['timestamp'] as String);

      // Check if expired
      if (DateTime.now().difference(timestamp) > _draftTTL) {
        debugPrint('[DraftService] ⏰ Draft expired: $draftId');
        await deleteDraft(draftId);
        return null;
      }

      final draft = DraftPost.fromJson(draftData['data'] as Map<String, dynamic>);
      debugPrint('[DraftService] ✓ Draft loaded: ${draft.title}');
      return draft;
    } catch (e) {
      debugPrint('[DraftService] ✗ Failed to load draft: $e');
      return null;
    }
  }

  /// Get all drafts for a user
  Future<List<DraftPost>> getUserDrafts(String userId) async {
    try {
      debugPrint('[DraftService] 🔍 Loading drafts for user: $userId');
      
      final allKeys = _storage.getAllKeys(_draftsBoxName);
      final drafts = <DraftPost>[];

      for (final key in allKeys) {
        if (!key.startsWith('draft_')) continue;

        try {
          final cached = _storage.get(_draftsBoxName, key);
          if (cached == null) continue;

          final draftData = jsonDecode(cached) as Map<String, dynamic>;
          final timestamp = DateTime.parse(draftData['timestamp'] as String);

          // Check if expired
          if (DateTime.now().difference(timestamp) > _draftTTL) {
            final draftId = key.replaceFirst('draft_', '');
            await deleteDraft(draftId);
            continue;
          }

          final draft = DraftPost.fromJson(draftData['data'] as Map<String, dynamic>);
          
          // Filter by user
          if (draft.userId == userId) {
            drafts.add(draft);
          }
        } catch (e) {
          debugPrint('[DraftService] ⚠️ Failed to parse draft $key: $e');
        }
      }

      // Sort by last modified (newest first)
      drafts.sort((a, b) => b.lastModified.compareTo(a.lastModified));

      debugPrint('[DraftService] ✓ Loaded ${drafts.length} drafts');
      return drafts;
    } catch (e) {
      debugPrint('[DraftService] ✗ Failed to load user drafts: $e');
      return [];
    }
  }

  /// Get all drafts (for admin/upload service)
  Future<List<DraftPost>> getAllDrafts() async {
    try {
      debugPrint('[DraftService] 🔍 Loading all drafts');
      
      final allKeys = _storage.getAllKeys(_draftsBoxName);
      final drafts = <DraftPost>[];

      for (final key in allKeys) {
        if (!key.startsWith('draft_')) continue;

        try {
          final cached = _storage.get(_draftsBoxName, key);
          if (cached == null) continue;

          final draftData = jsonDecode(cached) as Map<String, dynamic>;
          final timestamp = DateTime.parse(draftData['timestamp'] as String);

          // Check if expired
          if (DateTime.now().difference(timestamp) > _draftTTL) {
            final draftId = key.replaceFirst('draft_', '');
            await deleteDraft(draftId);
            continue;
          }

          final draft = DraftPost.fromJson(draftData['data'] as Map<String, dynamic>);
          drafts.add(draft);
        } catch (e) {
          debugPrint('[DraftService] ⚠️ Failed to parse draft $key: $e');
        }
      }

      // Sort by last modified (newest first)
      drafts.sort((a, b) => b.lastModified.compareTo(a.lastModified));

      debugPrint('[DraftService] ✓ Loaded ${drafts.length} drafts');
      return drafts;
    } catch (e) {
      debugPrint('[DraftService] ✗ Failed to load all drafts: $e');
      return [];
    }
  }

  /// Delete a draft
  Future<void> deleteDraft(String draftId) async {
    try {
      debugPrint('[DraftService] 🗑️ Deleting draft: $draftId');
      
      // Get draft to clean up images
      final draft = await getDraft(draftId);
      if (draft != null) {
        await _cleanupDraftImages(draft);
      }

      await _storage.delete(_draftsBoxName, 'draft_$draftId');
      debugPrint('[DraftService] ✓ Draft deleted');
    } catch (e) {
      debugPrint('[DraftService] ✗ Failed to delete draft: $e');
      rethrow;
    }
  }

  /// Update draft status
  Future<void> updateDraftStatus(String draftId, DraftStatus status, {String? errorMessage}) async {
    try {
      final draft = await getDraft(draftId);
      if (draft == null) {
        debugPrint('[DraftService] ⚠️ Draft not found for status update: $draftId');
        return;
      }

      final updatedDraft = draft.copyWith(
        status: status,
        lastModified: DateTime.now(),
        errorMessage: errorMessage,
      );

      await saveDraft(updatedDraft);
      debugPrint('[DraftService] ✓ Draft status updated to: ${status.name}');
    } catch (e) {
      debugPrint('[DraftService] ✗ Failed to update draft status: $e');
      rethrow;
    }
  }

  /// Save image to cache directory for draft
  Future<String> saveImageToCache(File imageFile, String draftId) async {
    try {
      debugPrint('[DraftService] 📷 Saving image to cache for draft: $draftId');
      debugPrint('[DraftService]   Source: ${imageFile.path}');
      
      // Validate source file
      if (!await imageFile.exists()) {
        throw Exception('Source image file does not exist: ${imageFile.path}');
      }
      
      final sourceSize = await imageFile.length();
      debugPrint('[DraftService]   Source size: $sourceSize bytes');
      
      if (sourceSize == 0) {
        throw Exception('Source image file is empty (0 bytes)');
      }
      
      final directory = await getApplicationCacheDirectory();
      final draftImagesDir = Directory('${directory.path}/draft_images/$draftId');
      
      // Create directory if it doesn't exist
      if (!await draftImagesDir.exists()) {
        await draftImagesDir.create(recursive: true);
        debugPrint('[DraftService]   ✓ Created directory: ${draftImagesDir.path}');
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = imageFile.path.split('.').last;
      final fileName = 'img_$timestamp.$extension';
      final localPath = '${draftImagesDir.path}/$fileName';

      debugPrint('[DraftService]   Copying to: $localPath');
      
      // Copy image to cache directory
      final copiedFile = await imageFile.copy(localPath);
      
      // Verify the copy was successful
      if (!await copiedFile.exists()) {
        throw Exception('File copy failed - destination file does not exist');
      }
      
      final copiedSize = await copiedFile.length();
      debugPrint('[DraftService] ✅ Image cached successfully!');
      debugPrint('[DraftService]   📍 Path: $localPath');
      debugPrint('[DraftService]   📦 Size: $copiedSize bytes (source: $sourceSize bytes)');
      debugPrint('[DraftService]   ✓ File verified and accessible');
      
      // Final verification
      if (copiedSize != sourceSize) {
        debugPrint('[DraftService] ⚠️  WARNING: Size mismatch - copied: $copiedSize, source: $sourceSize');
      }
      
      if (copiedSize == 0) {
        throw Exception('Copied file is empty (0 bytes) - copy failed');
      }
      
      return localPath;
    } catch (e) {
      debugPrint('[DraftService] ❌ Failed to save image: $e');
      rethrow;
    }
  }

  /// Clean up draft images from cache
  Future<void> _cleanupDraftImages(DraftPost draft) async {
    try {
      debugPrint('[DraftService] 🧹 Cleaning up images for draft: ${draft.draftId}');
      
      for (final imagePath in draft.localImagePaths) {
        try {
          final file = File(imagePath);
          if (await file.exists()) {
            await file.delete();
            debugPrint('[DraftService] ✓ Deleted image: $imagePath');
          }
        } catch (e) {
          debugPrint('[DraftService] ⚠️ Failed to delete image $imagePath: $e');
        }
      }

      // Delete draft images directory if empty
      final directory = await getApplicationCacheDirectory();
      final draftImagesDir = Directory('${directory.path}/draft_images/${draft.draftId}');
      
      if (await draftImagesDir.exists()) {
        try {
          await draftImagesDir.delete(recursive: true);
          debugPrint('[DraftService] ✓ Deleted draft images directory');
        } catch (e) {
          debugPrint('[DraftService] ⚠️ Failed to delete directory: $e');
        }
      }
    } catch (e) {
      debugPrint('[DraftService] ✗ Failed to cleanup images: $e');
    }
  }

  /// Get drafts pending upload
  Future<List<DraftPost>> getPendingDrafts(String userId) async {
    try {
      final allDrafts = await getUserDrafts(userId);
      return allDrafts.where((draft) => 
        draft.status == DraftStatus.pendingUpload ||
        draft.status == DraftStatus.failed
      ).toList();
    } catch (e) {
      debugPrint('[DraftService] ✗ Failed to get pending drafts: $e');
      return [];
    }
  }

  /// Check if we should process upload queue (online + has pending drafts)
  Future<bool> shouldProcessUploads(String userId) async {
    if (!_connectivity.isConnected) {
      return false;
    }

    final pending = await getPendingDrafts(userId);
    return pending.isNotEmpty;
  }

  /// Clear all drafts (for testing/cleanup)
  Future<void> clearAllDrafts() async {
    try {
      debugPrint('[DraftService] 🗑️ Clearing all drafts...');
      await _storage.clearBox(_draftsBoxName);
      
      // Clean up all draft images
      final directory = await getApplicationCacheDirectory();
      final draftImagesDir = Directory('${directory.path}/draft_images');
      
      if (await draftImagesDir.exists()) {
        await draftImagesDir.delete(recursive: true);
      }
      
      debugPrint('[DraftService] ✓ All drafts cleared');
    } catch (e) {
      debugPrint('[DraftService] ✗ Failed to clear drafts: $e');
    }
  }

  /// Get draft count for user
  Future<int> getDraftCount(String userId) async {
    final drafts = await getUserDrafts(userId);
    return drafts.length;
  }
}

