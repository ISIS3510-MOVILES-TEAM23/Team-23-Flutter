import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/cache_service.dart';
import '../services/comments_local_service.dart';
import '../services/connectivity_service.dart';
import '../services/firestore_service.dart';
import '../services/hive_service.dart';

class CommentsViewModel extends ChangeNotifier {
  final String productId;
  bool _isLoading = false;
  String? _error;
  List<Comment> _pendingComments = [];
  StreamSubscription? _connectivitySubscription;
  StreamSubscription? _firestoreSubscription;
  final StreamController<List<Comment>> _commentsController = StreamController<List<Comment>>.broadcast();
  List<Comment> _lastFirestoreComments = [];
  final ConnectivityService _connectivityService = ConnectivityService();
  final CommentsLocalService _localService = CommentsLocalService();
  final CacheService _cacheService = CacheService();

  bool get isLoading => _isLoading;
  String? get error => _error;
  int get pendingCount => _pendingComments.length;
  List<Comment> get pendingComments => _pendingComments;
  Stream<List<Comment>> get commentsStream => _commentsController.stream;

  CommentsViewModel(this.productId) {
    _init();
  }

  void _init() {
    // Load pending comments
    _loadPendingComments();
    
    // Listen to connectivity changes for auto-sync
    _connectivitySubscription = _connectivityService.connectionStream.listen((isConnected) {
      if (isConnected && _pendingComments.isNotEmpty) {
        debugPrint('[CommentsViewModel] 🌐 Connection restored, auto-syncing pending comments...');
        syncPendingComments();
      }
      _updateCommentsStream();
    });
  }

  void _updateCommentsStream() {
    final isOnline = _connectivityService.isConnected;
    if (isOnline) {
      _firestoreSubscription?.cancel();
      _firestoreSubscription = FirestoreService.getComments(productId).listen((firestoreComments) {
        _lastFirestoreComments = firestoreComments;
        // Cache in LRU for quick access
        _cacheService.putCommentsInLru(productId, firestoreComments);
        final merged = _mergeComments(firestoreComments, _pendingComments);
        _commentsController.add(merged);
      }, onError: (e) {
        debugPrint('[CommentsViewModel] ⚠️ Firestore error, falling back to cache: $e');
        _loadFromCacheOnce().then((cached) => _commentsController.add(cached));
      });
    } else {
      _firestoreSubscription?.cancel();
      _loadFromCacheOnce().then((cached) => _commentsController.add(cached));
    }
  }

  void _emitCurrent() {
    final isOnline = _connectivityService.isConnected;
    if (isOnline) {
      final merged = _mergeComments(_lastFirestoreComments, _pendingComments);
      _commentsController.add(merged);
    } else {
      _loadFromCacheOnce().then((cached) => _commentsController.add(cached));
    }
  }

  /// Load pending comments from local storage
  Future<void> _loadPendingComments() async {
    try {
      _pendingComments = await _localService.getPendingComments(productId);
      debugPrint('[CommentsViewModel] 📋 Loaded ${_pendingComments.length} pending comments');
      _updateCommentsStream();
    } catch (e) {
      debugPrint('[CommentsViewModel] ❌ Error loading pending comments: $e');
    }
  }



  /// Load comments from cache (helper for offline mode and error fallback)
  Future<List<Comment>> _loadFromCacheOnce() async {
    debugPrint('[CommentsViewModel] 📴 Loading from cache');
    
    try {
      // First, check LRU cache
      final lruComments = _cacheService.getCommentsFromLru(productId);
      if (lruComments != null) {
        final merged = _mergeComments(lruComments, _pendingComments);
        debugPrint('[CommentsViewModel] ✅ Loaded ${lruComments.length} LRU cached + ${_pendingComments.length} pending comments');
        return merged;
      }

      // Fallback to persistent cache
      final cachedMaps = await _cacheService.getCachedComments(productId);
      final cachedComments = cachedMaps?.map((map) => Comment.fromJson(map)).toList() ?? [];
      
      final merged = _mergeComments(cachedComments, _pendingComments);
      
      debugPrint('[CommentsViewModel] ✅ Loaded ${cachedComments.length} persistent cached + ${_pendingComments.length} pending comments');
      return merged;
    } catch (e) {
      debugPrint('[CommentsViewModel] ❌ Error loading cached comments: $e');
      return _pendingComments; // At least show pending comments
    }
  }

  /// Merge Firestore/cached comments with pending comments
  List<Comment> _mergeComments(List<Comment> syncedComments, List<Comment> pendingComments) {
    final merged = <Comment>[...syncedComments];
    
    // Add pending comments that aren't already synced
    for (final pending in pendingComments) {
      // Check if this pending comment was already synced (shouldn't happen, but safety check)
      final alreadySynced = syncedComments.any((c) => c.localId == pending.localId);
      if (!alreadySynced) {
        merged.add(pending);
      }
    }
    
    // Sort by creation date (newest first)
    merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    
    return merged;
  }

  /// Add a comment (handles both online and offline modes)
  Future<bool> addComment(String content) async {
    if (content.trim().isEmpty) return false;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final user = auth.FirebaseAuth.instance.currentUser;
      if (user == null) {
        _error = 'User not logged in';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Get user name - try Firestore first, fall back to HiveService cached user
      String userName;
      try {
        final userDoc = await FirestoreService.getUserById(user.uid);
        userName = userDoc.name;
      } catch (e) {
        // Firestore unavailable - use HiveService cached user (primary cache)
        debugPrint('[CommentsViewModel] ⚠️ Firestore unavailable for user, using HiveService cache: $e');
        final cachedUser = HiveService.getCachedUser(user.uid);
        userName = cachedUser?.name ?? user.displayName ?? 'Anonymous';
        debugPrint('[CommentsViewModel] ℹ️ Using cached user name: $userName');
      }

      final comment = Comment(
        id: '', // Will be generated by Firestore or remain empty for pending
        productId: productId,
        userId: user.uid,
        userName: userName,
        content: content.trim(),
        createdAt: DateTime.now(),
        isSynced: false, // Start as unsynced
      );

      final isOnline = _connectivityService.isConnected;

      if (isOnline) {
        // ONLINE: Post to Firestore
        debugPrint('[CommentsViewModel] 🌐 Online - posting comment to Firestore');
        final firestoreId = await FirestoreService.addComment(comment);
        
        if (firestoreId != null) {
          debugPrint('[CommentsViewModel] ✅ Comment posted successfully');
          _isLoading = false;
          notifyListeners();
          return true;
        } else {
          throw Exception('Failed to post comment to Firestore');
        }
      } else {
        // OFFLINE: Save to pending queue
        debugPrint('[CommentsViewModel] 📴 Offline - saving comment to pending queue');
        final pendingComment = await _localService.addPendingComment(comment);
        
        // Add to local pending list for immediate UI update
        _pendingComments.add(pendingComment);
        _emitCurrent();
        
        // Invalidate LRU cache since we have pending changes
        _cacheService.removeCommentsFromLru(productId);
        
        debugPrint('[CommentsViewModel] ✅ Comment saved to pending queue');
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      debugPrint('[CommentsViewModel] ❌ Error adding comment: $e');
      return false;
    }
  }

  /// Sync all pending comments to Firestore
  Future<void> syncPendingComments() async {
    if (_pendingComments.isEmpty) {
      debugPrint('[CommentsViewModel] ℹ️ No pending comments to sync');
      return;
    }

    if (!_connectivityService.isConnected) {
      debugPrint('[CommentsViewModel] ⚠️ Cannot sync - no internet connection');
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      debugPrint('[CommentsViewModel] 🔄 Syncing ${_pendingComments.length} pending comments...');
      
      final pendingCopy = List<Comment>.from(_pendingComments);
      int syncedCount = 0;

      for (final comment in pendingCopy) {
        final firestoreId = await FirestoreService.syncPendingComment(comment);
        
        if (firestoreId != null && comment.localId != null) {
          // Remove from pending queue
          await _localService.markCommentAsSynced(productId, comment.localId!, firestoreId);
          _pendingComments.removeWhere((c) => c.localId == comment.localId);
          syncedCount++;
        }
      }

      debugPrint('[CommentsViewModel] ✅ Synced $syncedCount/${pendingCopy.length} comments');
      
      // Invalidate LRU cache after syncing to ensure fresh data on next load
      _cacheService.removeCommentsFromLru(productId);
      
      _emitCurrent();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[CommentsViewModel] ❌ Error syncing comments: $e');
      _error = 'Failed to sync comments: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Retry a single failed comment
  Future<bool> retryFailedComment(String localId) async {
    if (!_connectivityService.isConnected) {
      _error = 'No internet connection';
      notifyListeners();
      return false;
    }

    try {
      final comment = _pendingComments.firstWhere((c) => c.localId == localId);
      
      final firestoreId = await FirestoreService.syncPendingComment(comment);
      
      if (firestoreId != null) {
        await _localService.markCommentAsSynced(productId, localId, firestoreId);
        _pendingComments.removeWhere((c) => c.localId == localId);
        // Invalidate LRU cache after retry success
        _cacheService.removeCommentsFromLru(productId);
        _emitCurrent();
        notifyListeners();
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('[CommentsViewModel] ❌ Error retrying comment: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _firestoreSubscription?.cancel();
    _commentsController.close();
    super.dispose();
  }
}
