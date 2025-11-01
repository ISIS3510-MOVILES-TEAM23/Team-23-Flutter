import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'connectivity_service.dart';
import 'draft_service.dart';
import 'firestore_service.dart';
import 'storage_service.dart';

/// Service to manage upload queue for drafts (Scenario 8)
/// Handles uploading drafts to Firestore when connectivity is restored
class DraftUploadService {
  static final DraftUploadService _instance = DraftUploadService._internal();
  factory DraftUploadService() => _instance;
  DraftUploadService._internal() {
    _initializeListeners();
  }

  final DraftService _draftService = DraftService();
  final StorageService _storageService = StorageService();
  final ConnectivityService _connectivity = ConnectivityService();

  bool _isProcessing = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  /// Initialize connectivity listener (DISABLED - manual sync only)
  void _initializeListeners() {
    // Scenario 8 - MANUAL SYNC: User manually posts drafts, no auto-sync
    // _connectivitySubscription = _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
    debugPrint('[DraftUploadService] ℹ️  Auto-sync DISABLED. Drafts will be posted manually by user.');
  }

  /// Called when connectivity changes (DISABLED - kept for reference)
  void _onConnectivityChanged(ConnectivityResult result) {
    // AUTO-SYNC DISABLED
    // User will manually post drafts by clicking "Post Draft" button
    debugPrint('[DraftUploadService] 🌐 Connectivity changed to: $result (auto-sync disabled)');
  }

  /// Process all pending drafts and upload them
  Future<void> processUploadQueue({String? userId}) async {
    if (_isProcessing) {
      debugPrint('[DraftUploadService] ⚠️ Already processing queue');
      return;
    }

    if (!_connectivity.isConnected) {
      debugPrint('[DraftUploadService] ⚠️ No connectivity. Skipping queue processing.');
      return;
    }

    try {
      _isProcessing = true;
      debugPrint('[DraftUploadService] 🚀 Starting upload queue processing...');

      // Get all drafts
      final drafts = userId != null
          ? await _draftService.getUserDrafts(userId)
          : await _draftService.getAllDrafts();

      // Filter drafts that need uploading
      final pendingDrafts = drafts.where((draft) =>
          draft.status == DraftStatus.editing ||
          draft.status == DraftStatus.pendingUpload ||
          draft.status == DraftStatus.failed).toList();

      if (pendingDrafts.isEmpty) {
        debugPrint('[DraftUploadService] ✓ No pending drafts to upload');
        _isProcessing = false;
        return;
      }

      debugPrint('[DraftUploadService] 📦 Found ${pendingDrafts.length} drafts to upload');

      // Process each draft
      for (final draft in pendingDrafts) {
        await _uploadDraft(draft);
      }

      debugPrint('[DraftUploadService] ✅ Upload queue processing complete');
    } catch (e) {
      debugPrint('[DraftUploadService] ❌ Error processing upload queue: $e');
    } finally {
      _isProcessing = false;
    }
  }

  /// Upload a single draft
  Future<bool> _uploadDraft(DraftPost draft) async {
    try {
      debugPrint('[DraftUploadService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[DraftUploadService] 📤 Starting upload for draft: "${draft.title}"');
      debugPrint('[DraftUploadService] 📋 Draft ID: ${draft.draftId}');
      debugPrint('[DraftUploadService] 👤 User ID: ${draft.userId}');
      debugPrint('[DraftUploadService] 💰 Price: \$${draft.price}');
      debugPrint('[DraftUploadService] 📂 Category: ${draft.categoryName ?? "None"}');
      debugPrint('[DraftUploadService] 🖼️  Local images: ${draft.localImagePaths.length}');

      // Update status to uploading
      draft = draft.copyWith(status: DraftStatus.uploading);
      await _draftService.saveDraft(draft);
      debugPrint('[DraftUploadService] ✓ Status updated to "uploading"');

      // 1. Upload images to Firebase Storage
      debugPrint('[DraftUploadService] 📸 Step 1/3: Uploading ${draft.localImagePaths.length} images...');
      
      if (draft.localImagePaths.isEmpty) {
        debugPrint('[DraftUploadService]   ℹ️  No images to upload');
      }
      
      final imageUrls = <String>[];
      for (int i = 0; i < draft.localImagePaths.length; i++) {
        final localPath = draft.localImagePaths[i];
        debugPrint('[DraftUploadService]   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        debugPrint('[DraftUploadService]   📤 Uploading image ${i + 1}/${draft.localImagePaths.length}');
        debugPrint('[DraftUploadService]   📍 Path: $localPath');
        
        try {
          final imageUrl = await _uploadImage(localPath, draft.userId, draft.draftId);
          if (imageUrl != null && imageUrl.isNotEmpty) {
            imageUrls.add(imageUrl);
            debugPrint('[DraftUploadService]   ✅ Image ${i + 1} uploaded successfully');
          } else {
            debugPrint('[DraftUploadService]   ⚠️  Image ${i + 1} returned null/empty URL');
          }
        } catch (e) {
          debugPrint('[DraftUploadService]   ❌ Failed to upload image ${i + 1}: $e');
          // Continue with other images even if one fails
        }
      }

      debugPrint('[DraftUploadService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[DraftUploadService] 📊 Upload Summary:');
      debugPrint('[DraftUploadService]   Total images: ${draft.localImagePaths.length}');
      debugPrint('[DraftUploadService]   Successfully uploaded: ${imageUrls.length}');
      debugPrint('[DraftUploadService]   Failed: ${draft.localImagePaths.length - imageUrls.length}');

      if (imageUrls.isEmpty && draft.localImagePaths.isNotEmpty) {
        throw Exception('Failed to upload any images (0/${draft.localImagePaths.length} succeeded)');
      }
      
      if (imageUrls.length < draft.localImagePaths.length) {
        debugPrint('[DraftUploadService] ⚠️  WARNING: Only ${imageUrls.length}/${draft.localImagePaths.length} images uploaded successfully');
      }

      // 2. Create post in Firestore
      // Convert price from dollars to cents (as integer)
      final priceInCents = (draft.price * 100).round();
      
      final postData = {
        'title': draft.title,
        'description': draft.description,
        'price': priceInCents, // Must be integer (cents)
        'user_id': draft.userId,
        'status': 'active',
        'images': imageUrls.isNotEmpty ? imageUrls : [],
        'created_at': DateTime.now().toIso8601String(),
      };
      
      // Add category as DocumentReference if available
      if (draft.categoryId != null && draft.categoryId!.isNotEmpty) {
        postData['category_id'] = FirebaseFirestore.instance
            .collection('categories')
            .doc(draft.categoryId);
        postData['category_name'] = draft.categoryName ?? '';
      }

      // Add location if available
      if (draft.latitude != null && draft.longitude != null) {
        postData['latitude'] = draft.latitude!;  // Non-null assertion
        postData['longitude'] = draft.longitude!; // Non-null assertion
      }

      debugPrint('[DraftUploadService] 📝 Step 2/3: Creating post in Firestore...');
      debugPrint('[DraftUploadService]   Title: "${draft.title}"');
      debugPrint('[DraftUploadService]   Price: $priceInCents cents (\$${draft.price})');
      debugPrint('[DraftUploadService]   Images: ${imageUrls.length}');
      debugPrint('[DraftUploadService]   Category: ${draft.categoryName ?? "None"}');
      if (draft.latitude != null && draft.longitude != null) {
        debugPrint('[DraftUploadService]   Location: (${draft.latitude}, ${draft.longitude})');
      }
      
      final success = await FirestoreService.createPost(postData);
      
      if (!success) {
        throw Exception('FirestoreService.createPost returned false');
      }
      
      debugPrint('[DraftUploadService] ✓ Post created in Firestore');

      // 3. Delete draft after successful upload
      debugPrint('[DraftUploadService] 🗑️  Step 3/3: Deleting local draft...');
      await _draftService.deleteDraft(draft.draftId);
      debugPrint('[DraftUploadService] ✓ Local draft deleted');

      debugPrint('[DraftUploadService] ✅ UPLOAD COMPLETE: "${draft.title}"');
      debugPrint('[DraftUploadService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return true;
    } catch (e, stackTrace) {
      debugPrint('[DraftUploadService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[DraftUploadService] ❌ UPLOAD FAILED: "${draft.title}"');
      debugPrint('[DraftUploadService] Error: $e');
      debugPrint('[DraftUploadService] Stack trace: $stackTrace');

      // Update status to failed
      try {
        draft = draft.copyWith(status: DraftStatus.failed);
        await _draftService.saveDraft(draft);
        debugPrint('[DraftUploadService] ✓ Status updated to "failed"');
      } catch (saveError) {
        debugPrint('[DraftUploadService] ✗ Failed to update status: $saveError');
      }
      
      debugPrint('[DraftUploadService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return false;
    }
  }

  /// Upload a single image to Firebase Storage
  Future<String?> _uploadImage(String localPath, String userId, String draftId) async {
    try {
      debugPrint('[DraftUploadService]     🔍 Checking file: $localPath');
      
      final file = File(localPath);
      
      // Check if file exists
      if (!await file.exists()) {
        debugPrint('[DraftUploadService]     ❌ File does not exist');
        return null;
      }
      
      // Check file size
      final fileSize = await file.length();
      debugPrint('[DraftUploadService]     ✓ File exists, size: $fileSize bytes');
      
      if (fileSize == 0) {
        debugPrint('[DraftUploadService]     ❌ File is empty (0 bytes)');
        return null;
      }

      debugPrint('[DraftUploadService]     ☁️  Uploading to Cloud Storage...');
      // Use the same path format as existing products: public/products/{ownerUid}/{productId}/{fileName}
      // We use draftId as productId to keep it unique
      final downloadUrl = await _storageService.uploadImage(file, 'products/$userId/$draftId');
      debugPrint('[DraftUploadService]     ✅ Upload successful!');
      debugPrint('[DraftUploadService]     🔗 URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('[DraftUploadService]     ❌ Upload failed: $e');
      rethrow;
    }
  }

  /// Manually post a specific draft (called from UI)
  Future<bool> postDraft(String draftId) async {
    // Check connectivity first
    if (!_connectivity.isConnected) {
      debugPrint('[DraftUploadService] ⚠️ Cannot post draft: No internet connection');
      throw Exception('No internet connection. Please connect to internet to post draft.');
    }

    try {
      debugPrint('[DraftUploadService] 📤 Manual post requested for draft: $draftId');
      
      final draft = await _draftService.getDraft(draftId);
      if (draft == null) {
        debugPrint('[DraftUploadService] ⚠️ Draft not found: $draftId');
        throw Exception('Draft not found');
      }

      return await _uploadDraft(draft);
    } catch (e) {
      debugPrint('[DraftUploadService] ❌ Failed to post draft: $e');
      rethrow;
    }
  }

  /// Retry uploading a failed draft (same as postDraft, kept for compatibility)
  Future<bool> retryUpload(String draftId) async {
    return await postDraft(draftId);
  }

  /// Get all pending drafts for a user (for UI display)
  Future<List<DraftPost>> getPendingDrafts(String userId) async {
    final drafts = await _draftService.getUserDrafts(userId);
    return drafts.where((draft) =>
        draft.status == DraftStatus.pendingUpload ||
        draft.status == DraftStatus.uploading ||
        draft.status == DraftStatus.failed).toList();
  }

  /// Dispose and clean up
  void dispose() {
    _connectivitySubscription?.cancel();
  }
}

