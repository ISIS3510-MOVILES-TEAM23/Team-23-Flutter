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
  static const String syncQueueBoxName = 'sync_queue';
  static const String metadataBoxName = 'metadata';

  /// Initialize Hive database
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await Hive.initFlutter();

      // Open all boxes
      await Future.wait([
        Hive.openBox(postsBoxName),
        Hive.openBox(messagesBoxName),
        Hive.openBox(categoriesBoxName),
        Hive.openBox(userBoxName),
        Hive.openBox(syncQueueBoxName),
        Hive.openBox(metadataBoxName),
      ]);

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
        syncQueueBoxName,
        metadataBoxName,
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
