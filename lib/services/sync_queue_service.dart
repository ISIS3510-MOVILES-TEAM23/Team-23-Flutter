import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'connectivity_service.dart';
import 'chat_service.dart';
import 'hive_service.dart';
import '../models/models.dart';

/// Service to manage offline operation queue and sync
/// Implements queue-and-sync pattern for eventual consistency
class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  final ConnectivityService _connectivity = ConnectivityService();
  final Uuid _uuid = const Uuid();

  bool _isSyncing = false;

  /// Add message to sync queue (Scenario 6)
  Future<String> queueMessage({
    required String chatId,
    required String senderId,
    required String content,
  }) async {
    final clientId = _uuid.v4();
    final syncItem = SyncQueueItem(
      operationId: clientId,
      type: 'message',
      payload: {
        'id': clientId,
        'chatId': chatId,
        'senderId': senderId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
      },
      createdAt: DateTime.now(),
    );

    await HiveService.addToSyncQueue(syncItem);
    debugPrint('[SyncQueue] ✓ Queued message: $clientId');

    // Try to sync immediately if online
    if (_connectivity.isConnected) {
      _syncQueue();
    }

    return clientId;
  }

  /// Get all pending queue items
  Future<List<Map<String, dynamic>>> getPendingItems() async {
    try {
      final items = HiveService.getSyncQueueItemsByType('message');
      return items
          .where((item) => item.retryCount < 3) // Not failed
          .map((item) => item.payload)
          .toList();
    } catch (e) {
      debugPrint('[SyncQueue] ✗ Error getting pending items: $e');
      return [];
    }
  }

  /// Start syncing queue
  Future<void> _syncQueue() async {
    if (_isSyncing) return;
    if (!_connectivity.isConnected) return;

    _isSyncing = true;

    try {
      final pendingItems = await getPendingItems();

      debugPrint('[SyncQueue] 🔄 Starting sync for ${pendingItems.length} items');

      for (final item in pendingItems) {
        try {
          await _syncItem(item);
        } catch (e) {
          debugPrint('[SyncQueue] ✗ Failed to sync item ${item['id']}: $e');
          // Continue with next item
        }
      }

      debugPrint('[SyncQueue] ✓ Sync completed');
    } finally {
      _isSyncing = false;
    }
  }

  /// Sync a single item
  Future<void> _syncItem(Map<String, dynamic> item) async {
    final itemId = item['id'] as String;

    try {
      await _syncMessage(item);

      // Mark as synced and remove from queue
      await HiveService.removeFromSyncQueue(itemId);
      debugPrint('[SyncQueue] ✓ Synced and removed: $itemId');
    } catch (e) {
      // Get the sync item to update retry count
      final items = HiveService.getAllSyncQueueItems();
      final syncItem = items.firstWhere(
        (si) => si.operationId == itemId,
        orElse: () => throw Exception('Item not found in queue'),
      );

      final retryCount = syncItem.retryCount + 1;

      if (retryCount >= 3) {
        // Max retries reached - update with error
        final updatedItem = syncItem.copyWith(
          retryCount: retryCount,
          lastAttemptAt: DateTime.now(),
          errorMessage: e.toString(),
        );
        await HiveService.updateSyncQueueItem(updatedItem);
        debugPrint('[SyncQueue] ✗ Max retries reached for: $itemId');
      } else {
        // Update retry count
        final updatedItem = syncItem.copyWith(
          retryCount: retryCount,
          lastAttemptAt: DateTime.now(),
        );
        await HiveService.updateSyncQueueItem(updatedItem);
        debugPrint('[SyncQueue] ⚠️ Retry $retryCount/3 for: $itemId');
      }

      rethrow;
    }
  }

  /// Sync a message to Firestore
  Future<void> _syncMessage(Map<String, dynamic> item) async {
    debugPrint('[SyncQueue] 📤 Syncing message: ${item['id']}');

    await ChatService.sendMessage(
      chatId: item['chatId'] as String,
      text: item['content'] as String?,
      imageUrl: null,
    );
  }

  /// Listen for connectivity changes and auto-sync
  void startAutoSync() {
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        debugPrint('[SyncQueue] 🟢 Connection restored - starting auto-sync');
        _syncQueue();
      }
    });
  }

  /// Get sync status for a queued item
  Future<String?> getItemStatus(String clientId) async {
    final items = HiveService.getAllSyncQueueItems();
    final item = items.where((i) => i.operationId == clientId).firstOrNull;
    
    if (item == null) return 'synced'; // Not in queue = already synced
    if (item.retryCount >= 3) return 'failed';
    return 'pending';
  }

  /// Manually trigger sync
  Future<void> syncNow() async {
    if (!_connectivity.isConnected) {
      throw Exception('No internet connection');
    }
    await _syncQueue();
  }

  /// Get failed items count
  Future<int> getFailedItemsCount() async {
    try {
      final items = HiveService.getSyncQueueItemsByType('message');
      return items.where((item) => item.retryCount >= 3).length;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all failed items
  Future<void> clearFailedItems() async {
    try {
      final items = HiveService.getSyncQueueItemsByType('message');
      final failedItems = items.where((item) => item.retryCount >= 3);
      
      for (final item in failedItems) {
        await HiveService.removeFromSyncQueue(item.operationId);
      }

      debugPrint('[SyncQueue] ✓ Cleared all failed items');
    } catch (e) {
      debugPrint('[SyncQueue] ✗ Error clearing failed items: $e');
    }
  }
}
