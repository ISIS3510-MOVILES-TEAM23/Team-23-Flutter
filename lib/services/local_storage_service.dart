import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/material.dart';

/// Service to manage Hive local database
/// Handles initialization, box management, and CRUD operations
class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();
  factory LocalStorageService() => _instance;
  LocalStorageService._internal();

  bool _isInitialized = false;

  // Box names
  static const String postsBoxName = 'posts';
  static const String messagesBoxName = 'messages';
  static const String categoriesBoxName = 'categories';
  static const String userBoxName = 'user';
  static const String syncQueueBoxName = 'sync_queue'; // Managed by HiveService with typed Box<SyncQueueItem>
  static const String metadataBoxName = 'metadata';
  static const String draftsBoxName = 'drafts'; // Scenario 8
  static const String feedbackDraftsBoxName = 'feedback_drafts'; // Feedback drafts
  static const String salesCacheBoxName = 'sales_cache'; // Scenario 12
  static const String purchasesCacheBoxName = 'purchases_cache'; // Purchases LRU cache

  /// Initialize Hive database
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Note: Hive.initFlutter() should only be called once
      // Check if Hive is already initialized by HiveService
      if (!Hive.isBoxOpen(postsBoxName)) {
        await Hive.initFlutter();
      }

      // Open all boxes (excluding sync_queue which is managed by HiveService)
      // Check if box is already open before opening
      final boxesToOpen = <Future>[];
      
      if (!Hive.isBoxOpen(postsBoxName)) {
        boxesToOpen.add(Hive.openBox(postsBoxName));
      }
      if (!Hive.isBoxOpen(messagesBoxName)) {
        boxesToOpen.add(Hive.openBox(messagesBoxName));
      }
      if (!Hive.isBoxOpen(categoriesBoxName)) {
        boxesToOpen.add(Hive.openBox(categoriesBoxName));
      }
      if (!Hive.isBoxOpen(userBoxName)) {
        boxesToOpen.add(Hive.openBox(userBoxName));
      }
      if (!Hive.isBoxOpen(metadataBoxName)) {
        boxesToOpen.add(Hive.openBox(metadataBoxName));
      }
      if (!Hive.isBoxOpen(draftsBoxName)) {
        boxesToOpen.add(Hive.openBox(draftsBoxName));
      }
      if (!Hive.isBoxOpen(feedbackDraftsBoxName)) {
        boxesToOpen.add(Hive.openBox(feedbackDraftsBoxName));
      }
      if (!Hive.isBoxOpen(salesCacheBoxName)) {
        boxesToOpen.add(Hive.openBox(salesCacheBoxName));
      }
      if (!Hive.isBoxOpen(purchasesCacheBoxName)) {
        boxesToOpen.add(Hive.openBox(purchasesCacheBoxName));
      }
      
      if (boxesToOpen.isNotEmpty) {
        await Future.wait(boxesToOpen);
      }

      _isInitialized = true;
      debugPrint('[LocalStorage] ✓ Initialized all boxes successfully');
    } catch (e) {
      debugPrint('[LocalStorage] ✗ Initialization failed: $e');
      rethrow;
    }
  }

  /// Get a box by name
  Box getBox(String boxName) {
    if (!_isInitialized) {
      throw Exception('LocalStorageService not initialized. Call initialize() first.');
    }
    
    // sync_queue is managed by HiveService as a typed Box<SyncQueueItem>
    // Don't allow access through LocalStorageService to avoid type conflicts
    if (boxName == syncQueueBoxName) {
      throw Exception('sync_queue box is managed by HiveService. Use HiveService methods instead.');
    }
    
    return Hive.box(boxName);
  }

  /// Save data to a box
  Future<void> save(String boxName, String key, dynamic value) async {
    try {
      final box = getBox(boxName);
      await box.put(key, value);
    } catch (e) {
      debugPrint('[LocalStorage] ✗ Save failed for $boxName/$key: $e');
      rethrow;
    }
  }

  /// Get data from a box
  dynamic get(String boxName, String key, {dynamic defaultValue}) {
    try {
      final box = getBox(boxName);
      return box.get(key, defaultValue: defaultValue);
    } catch (e) {
      debugPrint('[LocalStorage] ✗ Get failed for $boxName/$key: $e');
      return defaultValue;
    }
  }

  /// Delete data from a box
  Future<void> delete(String boxName, String key) async {
    try {
      final box = getBox(boxName);
      await box.delete(key);
    } catch (e) {
      debugPrint('[LocalStorage] ✗ Delete failed for $boxName/$key: $e');
      rethrow;
    }
  }

  /// Clear all data in a box
  Future<void> clearBox(String boxName) async {
    try {
      final box = getBox(boxName);
      await box.clear();
      debugPrint('[LocalStorage] ✓ Cleared box: $boxName');
    } catch (e) {
      debugPrint('[LocalStorage] ✗ Clear failed for $boxName: $e');
      rethrow;
    }
  }

  /// Get all values from a box
  List<dynamic> getAll(String boxName) {
    try {
      final box = getBox(boxName);
      return box.values.toList();
    } catch (e) {
      debugPrint('[LocalStorage] ✗ GetAll failed for $boxName: $e');
      return [];
    }
  }

  /// Get all keys from a box
  List<dynamic> getAllKeys(String boxName) {
    try {
      final box = getBox(boxName);
      return box.keys.toList();
    } catch (e) {
      debugPrint('[LocalStorage] ✗ GetAllKeys failed for $boxName: $e');
      return [];
    }
  }

  /// Save metadata (last sync time, cache timestamp, etc.)
  Future<void> saveMetadata(String key, dynamic value) async {
    await save(metadataBoxName, key, value);
  }

  /// Get metadata
  dynamic getMetadata(String key, {dynamic defaultValue}) {
    return get(metadataBoxName, key, defaultValue: defaultValue);
  }

  /// Check if box contains key
  bool contains(String boxName, String key) {
    try {
      final box = getBox(boxName);
      return box.containsKey(key);
    } catch (e) {
      debugPrint('[LocalStorage] ✗ Contains check failed for $boxName/$key: $e');
      return false;
    }
  }

  /// Get box size
  int getBoxSize(String boxName) {
    try {
      final box = getBox(boxName);
      return box.length;
    } catch (e) {
      debugPrint('[LocalStorage] ✗ GetBoxSize failed for $boxName: $e');
      return 0;
    }
  }

  /// Compact all boxes (optimize storage)
  Future<void> compactAll() async {
    try {
      final boxNames = [
        postsBoxName,
        messagesBoxName,
        categoriesBoxName,
        userBoxName,
        metadataBoxName,
        draftsBoxName, // Scenario 8
        feedbackDraftsBoxName, // Feedback drafts
        salesCacheBoxName, // Scenario 12
        purchasesCacheBoxName, // Purchases cache
      ];
      for (final boxName in boxNames) {
        try {
          await Hive.box(boxName).compact();
        } catch (e) {
          debugPrint('[LocalStorage] ✗ Compact failed for $boxName: $e');
        }
      }
      debugPrint('[LocalStorage] ✓ Compacted all boxes');
    } catch (e) {
      debugPrint('[LocalStorage] ✗ Compact failed: $e');
    }
  }

  /// Close all boxes and dispose
  Future<void> dispose() async {
    try {
      await Hive.close();
      _isInitialized = false;
      debugPrint('[LocalStorage] ✓ Closed all boxes');
    } catch (e) {
      debugPrint('[LocalStorage] ✗ Close failed: $e');
    }
  }
}
