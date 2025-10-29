import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'local_storage_service.dart';
import 'connectivity_service.dart';

/// Service to manage offline operation queue and sync
/// Implements queue-and-sync pattern for eventual consistency
class SyncQueueService {
  static final SyncQueueService _instance = SyncQueueService._internal();
  factory SyncQueueService() => _instance;
  SyncQueueService._internal();

  final LocalStorageService _storage = LocalStorageService();
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
    final queueItem = {
      'id': clientId,
      'type': 'message',
      'chatId': chatId,
      'senderId': senderId,
      'content': content,
      'timestamp': DateTime.now().toIso8601String(),
      'status': 'pending',
      'retryCount': 0,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };

    await _storage.save(
      LocalStorageService.syncQueueBoxName,
      clientId,
      jsonEncode(queueItem),
    );

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
      final allKeys = _storage.getAllKeys(LocalStorageService.syncQueueBoxName);
      final items = <Map<String, dynamic>>[];

      for (final key in allKeys) {
        final jsonStr = _storage.get(LocalStorageService.syncQueueBoxName, key);
        if (jsonStr != null) {
          final item = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (item['status'] == 'pending') {
            items.add(item);
          }
        }
      }

      // Sort by timestamp
      items.sort((a, b) {
        final aTime = a['createdAt'] as int;
        final bTime = b['createdAt'] as int;
        return aTime.compareTo(bTime);
      });

      return items;
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
    final type = item['type'] as String;

    try {
      if (type == 'message') {
        await _syncMessage(item);
      }
      // Add other types here (profile_update, etc.)

      // Mark as synced and remove from queue
      await _storage.delete(LocalStorageService.syncQueueBoxName, itemId);
      debugPrint('[SyncQueue] ✓ Synced and removed: $itemId');
    } catch (e) {
      // Increment retry count
      final retryCount = (item['retryCount'] as int? ?? 0) + 1;

      if (retryCount >= 3) {
        // Max retries reached - mark as failed
        item['status'] = 'failed';
        item['error'] = e.toString();
        await _storage.save(
          LocalStorageService.syncQueueBoxName,
          itemId,
          jsonEncode(item),
        );
        debugPrint('[SyncQueue] ✗ Max retries reached for: $itemId');
      } else {
        // Update retry count
        item['retryCount'] = retryCount;
        await _storage.save(
          LocalStorageService.syncQueueBoxName,
          itemId,
          jsonEncode(item),
        );
        debugPrint('[SyncQueue] ⚠️ Retry $retryCount/3 for: $itemId');
      }

      rethrow;
    }
  }

  /// Sync a message to Firestore
  Future<void> _syncMessage(Map<String, dynamic> item) async {
    // This will be implemented by ChatViewModel/Repository
    // For now, just mark as synced
    debugPrint('[SyncQueue] 📤 Syncing message: ${item['id']}');

    // Simulate network call
    await Future.delayed(const Duration(milliseconds: 100));

    // In real implementation, this would call:
    // await FirebaseFirestore.instance
    //     .collection('chats')
    //     .doc(item['chatId'])
    //     .collection('messages')
    //     .add({...});
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
    final jsonStr = _storage.get(LocalStorageService.syncQueueBoxName, clientId);
    if (jsonStr == null) return 'synced'; // Not in queue = already synced

    final item = jsonDecode(jsonStr) as Map<String, dynamic>;
    return item['status'] as String?;
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
      final allKeys = _storage.getAllKeys(LocalStorageService.syncQueueBoxName);
      int count = 0;

      for (final key in allKeys) {
        final jsonStr = _storage.get(LocalStorageService.syncQueueBoxName, key);
        if (jsonStr != null) {
          final item = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (item['status'] == 'failed') {
            count++;
          }
        }
      }

      return count;
    } catch (e) {
      return 0;
    }
  }

  /// Clear all failed items
  Future<void> clearFailedItems() async {
    try {
      final allKeys = _storage.getAllKeys(LocalStorageService.syncQueueBoxName);

      for (final key in allKeys) {
        final jsonStr = _storage.get(LocalStorageService.syncQueueBoxName, key);
        if (jsonStr != null) {
          final item = jsonDecode(jsonStr) as Map<String, dynamic>;
          if (item['status'] == 'failed') {
            await _storage.delete(LocalStorageService.syncQueueBoxName, key);
          }
        }
      }

      debugPrint('[SyncQueue] ✓ Cleared all failed items');
    } catch (e) {
      debugPrint('[SyncQueue] ✗ Error clearing failed items: $e');
    }
  }
}
