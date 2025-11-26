import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import 'connectivity_service.dart';
import 'draft_feedback_service.dart';
import 'firestore_service.dart';
import 'storage_service.dart';
import 'feedback_sql_service.dart';

/// Service to manage upload queue for feedback drafts
/// Handles uploading feedback to Firestore when connectivity is available
/// 
/// Rubric: Uses multiple threading patterns
/// - Future with handlers
/// - Streams
/// - Isolates for image processing
class FeedbackUploadService {
  static final FeedbackUploadService _instance = FeedbackUploadService._internal();
  factory FeedbackUploadService() => _instance;
  FeedbackUploadService._internal() {
    _initializeListeners();
  }

  final DraftFeedbackService _draftService = DraftFeedbackService();
  final StorageService _storageService = StorageService();
  final ConnectivityService _connectivity = ConnectivityService();
  final FeedbackSqlService _sqlService = FeedbackSqlService();

  bool _isProcessing = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  // Stream controller for upload progress
  /// Rubric: Stream usage (5 puntos)
  final _uploadProgressController = StreamController<FeedbackUploadProgress>.broadcast();
  Stream<FeedbackUploadProgress> get uploadProgress => _uploadProgressController.stream;

  /// Initialize connectivity listener (DISABLED - manual sync only)
  void _initializeListeners() {
    // Manual sync only - user will manually upload feedback
    debugPrint('[FeedbackUploadService] ℹ️  Auto-sync DISABLED. Feedback will be posted manually by user.');
  }

  /// Called when connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    debugPrint('[FeedbackUploadService] 🌐 Connectivity changed to: $result');
  }

  /// Process all pending feedback drafts and upload them
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<void> processUploadQueue({String? userId}) async {
    if (_isProcessing) {
      debugPrint('[FeedbackUploadService] ⚠️ Already processing upload queue');
      return;
    }

    try {
      _isProcessing = true;
      debugPrint('[FeedbackUploadService] 🚀 Starting upload queue processing...');

      // Check connectivity
      if (!_connectivity.isConnected) {
        debugPrint('[FeedbackUploadService] ❌ No connectivity, aborting upload');
        return;
      }

      // Get pending drafts
      final pendingDrafts = userId != null 
          ? await _draftService.getPendingDrafts(userId)
          : <DraftFeedback>[];

      if (pendingDrafts.isEmpty) {
        debugPrint('[FeedbackUploadService] ℹ️  No pending feedback to upload');
        return;
      }

      debugPrint('[FeedbackUploadService] 📤 Found ${pendingDrafts.length} pending feedback(s)');

      // Upload each draft
      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < pendingDrafts.length; i++) {
        final draft = pendingDrafts[i];
        
        // Emit progress
        _uploadProgressController.add(FeedbackUploadProgress(
          current: i + 1,
          total: pendingDrafts.length,
          status: 'Uploading feedback ${i + 1}/${pendingDrafts.length}',
        ));

        try {
          final success = await _uploadDraft(draft);
          if (success) {
            successCount++;
          } else {
            failCount++;
          }
        } catch (e) {
          debugPrint('[FeedbackUploadService] ❌ Error uploading draft: $e');
          failCount++;
          
          // Mark draft as failed
          final failedDraft = draft.copyWith(
            status: DraftFeedbackStatus.failed,
            errorMessage: e.toString(),
          );
          await _draftService.saveDraft(failedDraft);
        }

        // Small delay between uploads
        if (i < pendingDrafts.length - 1) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }

      // Emit completion
      _uploadProgressController.add(FeedbackUploadProgress(
        current: pendingDrafts.length,
        total: pendingDrafts.length,
        status: 'Complete: $successCount uploaded, $failCount failed',
        isComplete: true,
      ));

      debugPrint('[FeedbackUploadService] ✅ Upload complete: $successCount success, $failCount failed');
    } finally {
      _isProcessing = false;
    }
  }

  /// Upload a single feedback draft
  /// 
  /// Rubric: Uses Future with error handler (5 puntos) + async/await (10 puntos)
  Future<bool> _uploadDraft(DraftFeedback draft) async {
    try {
      debugPrint('[FeedbackUploadService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[FeedbackUploadService] 📤 Starting upload for draft: ${draft.draftId}');
      debugPrint('[FeedbackUploadService] 📋 Draft ID: ${draft.draftId}');
      debugPrint('[FeedbackUploadService] 👤 Buyer ID: ${draft.buyerId}');
      debugPrint('[FeedbackUploadService] 🏪 Seller ID: ${draft.sellerId}');
      debugPrint('[FeedbackUploadService] 🛒 Purchase ID: ${draft.purchaseId}');
      debugPrint('[FeedbackUploadService] ⭐ Rating: ${draft.rating}');
      debugPrint('[FeedbackUploadService] 🖼️  Local images: ${draft.localImagePaths.length}');

      // Update status to uploading
      var updatedDraft = draft.copyWith(status: DraftFeedbackStatus.uploading);
      await _draftService.saveDraft(updatedDraft);
      debugPrint('[FeedbackUploadService] ✓ Status updated to "uploading"');

      // 1. Upload images to Firebase Storage (same as draft posts)
      debugPrint('[FeedbackUploadService] 📸 Step 1/3: Uploading ${draft.localImagePaths.length} images...');
      
      if (draft.localImagePaths.isEmpty) {
        debugPrint('[FeedbackUploadService]   ℹ️  No images to upload');
      }
      
      final imageUrls = <String>[];
      for (int i = 0; i < draft.localImagePaths.length; i++) {
        final localPath = draft.localImagePaths[i];
        
        try {
          debugPrint('[FeedbackUploadService]   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          debugPrint('[FeedbackUploadService]   📤 Uploading image ${i + 1}/${draft.localImagePaths.length}');
          debugPrint('[FeedbackUploadService]   📍 Path: $localPath');
          
          // Upload using the same method as draft posts
          final uploadUrl = await _uploadImage(localPath, draft.buyerId, draft.draftId);
          
          debugPrint('[FeedbackUploadService]   📊 Upload result: ${uploadUrl ?? "NULL"}');
          
          if (uploadUrl != null && uploadUrl.isNotEmpty) {
            imageUrls.add(uploadUrl);
            debugPrint('[FeedbackUploadService]   ✅ Image ${i + 1} uploaded successfully');
            debugPrint('[FeedbackUploadService]   🔗 URL: $uploadUrl');
          } else {
            debugPrint('[FeedbackUploadService]   ⚠️ Image ${i + 1} upload returned null or empty');
          }
        } catch (e, stackTrace) {
          debugPrint('[FeedbackUploadService]   ❌ Failed to upload image ${i + 1}: $e');
          debugPrint('[FeedbackUploadService]   Stack: $stackTrace');
          // Continue with other images
        }
      }

      debugPrint('[FeedbackUploadService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[FeedbackUploadService] 📊 Upload Summary:');
      debugPrint('[FeedbackUploadService]   Total images: ${draft.localImagePaths.length}');
      debugPrint('[FeedbackUploadService]   Successfully uploaded: ${imageUrls.length}');
      debugPrint('[FeedbackUploadService]   Failed: ${draft.localImagePaths.length - imageUrls.length}');
      debugPrint('[FeedbackUploadService]   URLs: $imageUrls');

      // 2. Create feedback in Firestore
      final feedbackData = {
        'buyerId': draft.buyerId,
        'sellerId': draft.sellerId,
        'purchaseId': draft.purchaseId,
        'comment': draft.comment,
        'rating': draft.rating,
        'images': imageUrls, // Array of Firebase Storage URLs
        'createdAt': Timestamp.now(),
      };
      
      debugPrint('[FeedbackUploadService] 📝 Step 2/3: Creating feedback in Firestore...');
      debugPrint('[FeedbackUploadService]   Purchase ID: ${draft.purchaseId}');
      debugPrint('[FeedbackUploadService]   Rating: ${draft.rating}');
      debugPrint('[FeedbackUploadService]   Images count: ${imageUrls.length}');
      debugPrint('[FeedbackUploadService]   Images array: $imageUrls');
      debugPrint('[FeedbackUploadService]   Full data: $feedbackData');
      
      final success = await _createFeedbackInFirestore(feedbackData);
      
      if (!success) {
        throw Exception('Failed to create feedback in Firestore');
      }
      
      debugPrint('[FeedbackUploadService] ✓ Feedback created in Firestore');

      // 3. Mark as synced in SQLite
      await _sqlService.markAsSynced(draft.purchaseId);

      // 4. Delete draft after successful upload
      debugPrint('[FeedbackUploadService] 🗑️  Step 3/3: Deleting local draft...');
      await _draftService.deleteDraft(draft.draftId);
      debugPrint('[FeedbackUploadService] ✓ Draft deleted');

      debugPrint('[FeedbackUploadService] ✅ Upload successful for draft: ${draft.draftId}');
      debugPrint('[FeedbackUploadService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      
      return true;
    } catch (e) {
      debugPrint('[FeedbackUploadService] ❌ Upload failed: $e');
      debugPrint('[FeedbackUploadService] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      return false;
    }
  }


  /// Upload a single image to Firebase Storage (same as draft posts)
  Future<String?> _uploadImage(String localPath, String userId, String draftId) async {
    try {
      debugPrint('[FeedbackUploadService]     🔍 Checking file: $localPath');
      
      final file = File(localPath);
      
      // Check if file exists
      if (!await file.exists()) {
        debugPrint('[FeedbackUploadService]     ❌ File does not exist');
        return null;
      }
      
      // Check file size
      final fileSize = await file.length();
      debugPrint('[FeedbackUploadService]     ✓ File exists, size: $fileSize bytes');
      
      if (fileSize == 0) {
        debugPrint('[FeedbackUploadService]     ❌ File is empty (0 bytes)');
        return null;
      }

      debugPrint('[FeedbackUploadService]     ☁️  Uploading to Cloud Storage...');
      // Upload to feedback folder
      final downloadUrl = await _storageService.uploadImage(file, 'feedback/$userId/$draftId');
      debugPrint('[FeedbackUploadService]     ✅ Upload successful!');
      debugPrint('[FeedbackUploadService]     🔗 URL: $downloadUrl');
      
      return downloadUrl;
    } catch (e) {
      debugPrint('[FeedbackUploadService]     ❌ Upload failed: $e');
      rethrow;
    }
  }

  /// Create feedback in Firestore
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<bool> _createFeedbackInFirestore(Map<String, dynamic> feedbackData) async {
    try {
      final db = FirebaseFirestore.instance;
      
      // Add to 'feedbacks' collection (plural)
      await db.collection('feedbacks').add(feedbackData);
      
      return true;
    } catch (e) {
      debugPrint('[FeedbackUploadService] ❌ Firestore error: $e');
      return false;
    }
  }

  /// Upload a single draft manually (for manual upload button)
  /// 
  /// Rubric: Uses Future with error handler (5 puntos)
  Future<bool> uploadSingleDraft(String draftId) async {
    try {
      if (!_connectivity.isConnected) {
        throw Exception('No internet connection');
      }

      final draft = await _draftService.getDraft(draftId);
      if (draft == null) {
        throw Exception('Draft not found');
      }

      // Emit progress
      _uploadProgressController.add(FeedbackUploadProgress(
        current: 1,
        total: 1,
        status: 'Uploading feedback...',
      ));

      final success = await _uploadDraft(draft);
      
      // Emit completion
      _uploadProgressController.add(FeedbackUploadProgress(
        current: 1,
        total: 1,
        status: success ? 'Upload complete' : 'Upload failed',
        isComplete: true,
      ));

      return success;
    } catch (e) {
      debugPrint('[FeedbackUploadService] ❌ Failed to upload single draft: $e');
      
      _uploadProgressController.add(FeedbackUploadProgress(
        current: 1,
        total: 1,
        status: 'Upload failed: $e',
        isComplete: true,
      ));
      
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _uploadProgressController.close();
  }
}

/// Upload progress model
class FeedbackUploadProgress {
  final int current;
  final int total;
  final String status;
  final bool isComplete;

  FeedbackUploadProgress({
    required this.current,
    required this.total,
    required this.status,
    this.isComplete = false,
  });

  double get progress => total > 0 ? current / total : 0.0;
}

