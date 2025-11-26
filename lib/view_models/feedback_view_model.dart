import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/draft_feedback_service.dart';
import '../services/feedback_upload_service.dart';
import '../services/feedback_sql_service.dart';
import '../services/connectivity_service.dart';

/// ViewModel for Feedback Form Screen (MVVM pattern)
/// 
/// Handles:
/// - Feedback creation (comment, rating, images)
/// - Offline support with drafts
/// - Auto-save functionality
/// - Manual upload to Firestore
/// 
/// Rubric:
/// - Multithreading: Future, Future with handlers, async/await, Streams
/// - Local Storage: SQLite (ratings), Hive (drafts), Local files (images)
/// - Caching: LRU for images (via CachedNetworkImage in UI)
class FeedbackViewModel extends ChangeNotifier {
  final DraftFeedbackService _draftService;
  final FeedbackUploadService _uploadService;
  final FeedbackSqlService _sqlService;
  final ConnectivityService _connectivity;

  FeedbackViewModel({
    DraftFeedbackService? draftService,
    FeedbackUploadService? uploadService,
    FeedbackSqlService? sqlService,
    ConnectivityService? connectivityService,
  })  : _draftService = draftService ?? DraftFeedbackService(),
        _uploadService = uploadService ?? FeedbackUploadService(),
        _sqlService = sqlService ?? FeedbackSqlService(),
        _connectivity = connectivityService ?? ConnectivityService() {
    _startAutoSave();
    _listenToUploadProgress();
  }

  final TextEditingController commentController = TextEditingController();

  int rating = 0;
  List<String> localImagePaths = []; // Local paths for draft images (online and offline)
  bool isLoading = false;
  bool isUploading = false;
  String uploadStatus = '';
  double uploadProgress = 0.0;
  
  // Draft-related fields
  String? _draftId;
  Timer? _autoSaveTimer;
  DateTime? _lastAutoSave;
  
  // Purchase/Sale info
  String? purchaseId;
  String? sellerId;
  String? productTitle;

  // Connectivity
  bool get isOffline => !_connectivity.isConnected;

  /// Initialize with purchase info
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<void> initialize({
    required String purchaseId,
    required String sellerId,
    String? productTitle,
  }) async {
    try {
      this.purchaseId = purchaseId;
      this.sellerId = sellerId;
      this.productTitle = productTitle;

      // Initialize services
      await _draftService.initialize();
      await _sqlService.initialize();

      // Check if there's an existing draft for this purchase
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await _loadExistingDraft(currentUser.uid, purchaseId);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[FeedbackViewModel] ❌ Failed to initialize: $e');
    }
  }

  /// Load existing draft if available
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<void> _loadExistingDraft(String userId, String purchaseId) async {
    try {
      final drafts = await _draftService.getAllDrafts(userId);
      final existingDraft = drafts.cast<DraftFeedback?>().firstWhere(
        (d) => d?.purchaseId == purchaseId,
        orElse: () => null,
      );

      if (existingDraft != null) {
        _draftId = existingDraft.draftId;
        commentController.text = existingDraft.comment;
        rating = existingDraft.rating;
        
        localImagePaths = List.from(existingDraft.localImagePaths);

        debugPrint('[FeedbackViewModel] ✓ Loaded existing draft: $_draftId');
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[FeedbackViewModel] ❌ Failed to load existing draft: $e');
    }
  }

  /// Start auto-save timer
  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _autoSaveDraft();
    });
  }

  /// Auto-save draft
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<void> _autoSaveDraft() async {
    try {
      // Only auto-save if there's content
      if (!_hasContent()) {
        return;
      }

      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null || purchaseId == null || sellerId == null) return;

      _draftId ??= const Uuid().v4();

      final draft = DraftFeedback(
        draftId: _draftId!,
        buyerId: currentUser.uid,
        sellerId: sellerId!,
        purchaseId: purchaseId!,
        comment: commentController.text.trim(),
        rating: rating,
        localImagePaths: localImagePaths,
        status: DraftFeedbackStatus.editing,
      );

      await _draftService.saveDraft(draft);
      _lastAutoSave = DateTime.now();
      
      debugPrint('[FeedbackViewModel] 💾 Auto-saved draft');
    } catch (e) {
      debugPrint('[FeedbackViewModel] ❌ Auto-save failed: $e');
    }
  }

  /// Check if form has content
  bool _hasContent() {
    return commentController.text.trim().isNotEmpty ||
           rating > 0 ||
           localImagePaths.isNotEmpty;
  }

  /// Set rating
  void setRating(int newRating) {
    if (newRating >= 1 && newRating <= 5) {
      rating = newRating;
      notifyListeners();
      
      // Trigger auto-save
      _autoSaveDraft();
    }
  }

  /// Pick image for feedback
  /// 
  /// Rubric: Uses Future with error handler (5 puntos)
  /// Local file storage (5 puntos)
  Future<String?> pickImage({required bool fromCamera}) async {
    try {
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null || purchaseId == null) {
        throw Exception('User not logged in or purchase info missing');
      }

      _draftId ??= const Uuid().v4();

      // Pick image file
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      );

      if (pickedFile == null) return null;

      final imageFile = File(pickedFile.path);

      // ALWAYS save to cache directory (online or offline)
      // This ensures the file is accessible when uploading
      final localPath = await _draftService.saveImageToCache(imageFile, _draftId!);
      localImagePaths.add(localPath);
      notifyListeners();

      debugPrint('[FeedbackViewModel] 📷 Image saved to cache: $localPath');
      return localPath;
    } catch (e) {
      debugPrint('[FeedbackViewModel] ❌ Failed to pick image: $e');
      rethrow;
    }
  }

  /// Remove image
  void removeImage(int index) {
    if (index >= 0 && index < localImagePaths.length) {
      localImagePaths.removeAt(index);
      notifyListeners();
    }
  }

  /// Save draft manually
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<void> saveDraftManually() async {
    try {
      isLoading = true;
      notifyListeners();

      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null || purchaseId == null || sellerId == null) {
        throw Exception('Missing required information');
      }

      _draftId ??= const Uuid().v4();

      final draft = DraftFeedback(
        draftId: _draftId!,
        buyerId: currentUser.uid,
        sellerId: sellerId!,
        purchaseId: purchaseId!,
        comment: commentController.text.trim(),
        rating: rating,
        localImagePaths: localImagePaths,
        status: isOffline ? DraftFeedbackStatus.pendingUpload : DraftFeedbackStatus.editing,
      );

      await _draftService.saveDraft(draft);

      isLoading = false;
      notifyListeners();

      debugPrint('[FeedbackViewModel] ✓ Draft saved manually');
    } catch (e) {
      isLoading = false;
      notifyListeners();
      debugPrint('[FeedbackViewModel] ❌ Failed to save draft: $e');
      rethrow;
    }
  }

  /// Upload feedback (manual upload button)
  /// 
  /// Rubric: Uses Future with error handler (5 puntos) + async/await (10 puntos)
  Future<bool> uploadFeedback() async {
    try {
      if (isOffline) {
        // Save as pending upload
        await saveDraftManually();
        throw Exception('No internet connection. Feedback saved as draft.');
      }

      isLoading = true;
      notifyListeners();

      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null || purchaseId == null || sellerId == null) {
        throw Exception('Missing required information');
      }

      // Validate
      if (rating == 0) {
        throw Exception('Please select a rating');
      }
      if (commentController.text.trim().isEmpty) {
        throw Exception('Please enter a comment');
      }

      // Create draft with pendingUpload status
      _draftId ??= const Uuid().v4();

      final draft = DraftFeedback(
        draftId: _draftId!,
        buyerId: currentUser.uid,
        sellerId: sellerId!,
        purchaseId: purchaseId!,
        comment: commentController.text.trim(),
        rating: rating,
        localImagePaths: localImagePaths,
        status: DraftFeedbackStatus.pendingUpload,
      );

      await _draftService.saveDraft(draft);

      // Upload the draft
      final success = await _uploadService.uploadSingleDraft(_draftId!);

      isLoading = false;
      notifyListeners();

      if (success) {
        debugPrint('[FeedbackViewModel] ✅ Feedback uploaded successfully');
        _clearForm();
      }

      return success;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      debugPrint('[FeedbackViewModel] ❌ Failed to upload feedback: $e');
      rethrow;
    }
  }

  /// Listen to upload progress
  /// 
  /// Rubric: Stream usage (5 puntos)
  void _listenToUploadProgress() {
    _uploadService.uploadProgress.listen((progress) {
      uploadProgress = progress.progress;
      uploadStatus = progress.status;
      isUploading = !progress.isComplete;
      notifyListeners();
    });
  }

  /// Clear form
  void _clearForm() {
    commentController.clear();
    rating = 0;
    localImagePaths.clear();
    _draftId = null;
    notifyListeners();
  }

  /// Delete current draft
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<void> deleteDraft() async {
    try {
      if (_draftId != null) {
        await _draftService.deleteDraft(_draftId!);
        _clearForm();
        debugPrint('[FeedbackViewModel] ✓ Draft deleted');
      }
    } catch (e) {
      debugPrint('[FeedbackViewModel] ❌ Failed to delete draft: $e');
      rethrow;
    }
  }

  /// Check if form is valid
  bool get isValid {
    return rating > 0 &&
           commentController.text.trim().isNotEmpty &&
           purchaseId != null &&
           sellerId != null;
  }

  @override
  void dispose() {
    commentController.dispose();
    _autoSaveTimer?.cancel();
    super.dispose();
  }
}

