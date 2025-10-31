import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'connectivity_service.dart';
import 'firestore_service.dart';
import 'hive_service.dart';

/// Service to handle profile update synchronization with eventual connectivity
class ProfileSyncService {
  static const String _operationType = 'profile_update';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);
  
  final ConnectivityService _connectivityService;
  final Uuid _uuid = const Uuid();
  
  StreamSubscription<bool>? _connectivitySubscription;
  bool _isSyncing = false;

  ProfileSyncService(this._connectivityService);

  /// Initialize the service and start listening for connectivity changes
  void initialize() {
    debugPrint('🔄 [ProfileSyncService] Initializing...');
    _connectivitySubscription = _connectivityService.connectionStream.listen(
      (hasConnection) {
        if (hasConnection) {
          debugPrint('📡 [ProfileSyncService] Connection restored, starting sync...');
          syncPendingUpdates();
        }
      },
    );
    
    // Try to sync on initialization if online
    if (_connectivityService.hasConnection) {
      syncPendingUpdates();
    }
  }

  /// Queue a profile update for syncing
  Future<void> queueProfileUpdate({
    required String userId,
    required String name,
    required String email,
    required String major,
  }) async {
    try {
      final operationId = _uuid.v4();
      final payload = {
        'userId': userId,
        'name': name,
        'email': email,
        'major': major,
      };

      final queueItem = SyncQueueItem(
        operationId: operationId,
        type: _operationType,
        payload: payload,
        createdAt: DateTime.now(),
      );

      await HiveService.addToSyncQueue(queueItem);
      debugPrint('✅ [ProfileSyncService] Queued profile update: $operationId');

      // Update local cache immediately (optimistic UI)
      await HiveService.updateCachedUser(userId, {
        'name': name,
        'email': email,
        'major': major,
      });
      debugPrint('💾 [ProfileSyncService] Updated local cache optimistically');

      // Try to sync immediately if online
      if (_connectivityService.hasConnection) {
        debugPrint('📡 [ProfileSyncService] Online - attempting immediate sync');
        syncPendingUpdates();
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [ProfileSyncService] Error queuing profile update: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Sync all pending profile updates
  Future<void> syncPendingUpdates() async {
    if (_isSyncing) {
      debugPrint('⏸️ [ProfileSyncService] Sync already in progress, skipping...');
      return;
    }

    if (!_connectivityService.hasConnection) {
      debugPrint('📴 [ProfileSyncService] No connection, skipping sync');
      return;
    }

    _isSyncing = true;
    debugPrint('🔄 [ProfileSyncService] Starting sync of pending updates...');

    try {
      final pendingItems = HiveService.getSyncQueueItemsByType(_operationType);
      debugPrint('📋 [ProfileSyncService] Found ${pendingItems.length} pending profile updates');

      for (final item in pendingItems) {
        try {
          await _syncItem(item);
        } catch (e) {
          debugPrint('❌ [ProfileSyncService] Error syncing item ${item.operationId}: $e');
          // Continue with next item
        }
      }

      debugPrint('✅ [ProfileSyncService] Sync completed');
    } catch (e, stackTrace) {
      debugPrint('❌ [ProfileSyncService] Error during sync: $e');
      debugPrint('Stack trace: $stackTrace');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single queue item
  Future<void> _syncItem(SyncQueueItem item) async {
    try {
      debugPrint('🔄 [ProfileSyncService] Syncing item: ${item.operationId}');

      // Check if we've exceeded max retries
      if (item.retryCount >= _maxRetries) {
        debugPrint('⚠️ [ProfileSyncService] Max retries exceeded for ${item.operationId}, removing from queue');
        await HiveService.removeFromSyncQueue(item.operationId);
        return;
      }

      // Extract payload
      final userId = item.payload['userId'] as String;
      final name = item.payload['name'] as String;
      final email = item.payload['email'] as String;
      final major = item.payload['major'] as String;

      // Attempt to update on Firestore
      await FirestoreService.updateUserProfile(
        userId: userId,
        name: name,
        email: email,
        major: major,
      );

      // Success - remove from queue
      await HiveService.removeFromSyncQueue(item.operationId);
      debugPrint('✅ [ProfileSyncService] Successfully synced item: ${item.operationId}');

      // Update cache with server data
      final updatedUser = await FirestoreService.getCurrentUser();
      if (updatedUser != null) {
        await HiveService.cacheUser(updatedUser);
        debugPrint('💾 [ProfileSyncService] Updated cache with server data');
      }
    } catch (e) {
      debugPrint('❌ [ProfileSyncService] Error syncing item: $e');

      // Update retry count and error message
      final updatedItem = item.copyWith(
        retryCount: item.retryCount + 1,
        lastAttemptAt: DateTime.now(),
        errorMessage: e.toString(),
      );
      await HiveService.updateSyncQueueItem(updatedItem);

      // Schedule retry if not exceeded max retries
      if (updatedItem.retryCount < _maxRetries) {
        final delay = _retryDelay * updatedItem.retryCount;
        debugPrint('⏱️ [ProfileSyncService] Scheduling retry in ${delay.inSeconds}s...');
        Future.delayed(delay, () {
          if (_connectivityService.hasConnection) {
            _syncItem(updatedItem);
          }
        });
      }

      rethrow;
    }
  }

  /// Get count of pending profile updates
  int getPendingCount() {
    return HiveService.getSyncQueueItemsByType(_operationType).length;
  }

  /// Check if there are pending updates
  bool hasPendingUpdates() {
    return getPendingCount() > 0;
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('👋 [ProfileSyncService] Disposed');
  }
}
