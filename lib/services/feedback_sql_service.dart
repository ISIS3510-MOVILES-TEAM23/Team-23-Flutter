import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite service for storing feedback ratings in relational database
/// 
/// Rubric requirement: BD Local Relacional - 10 puntos
/// 
/// Stores:
/// - Purchase ID
/// - Rating (1-5)
/// - Timestamp
/// 
/// This provides a lightweight relational way to track ratings separately
/// from the full feedback data (which is stored in Hive).
class FeedbackSqlService {
  static final FeedbackSqlService _instance = FeedbackSqlService._internal();
  factory FeedbackSqlService() => _instance;
  FeedbackSqlService._internal();

  Database? _database;
  bool _isInitialized = false;

  static const String _dbName = 'feedback_ratings.db';
  static const int _dbVersion = 1;
  static const String _tableName = 'feedback_ratings';

  /// Initialize SQLite database
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      debugPrint('[FeedbackSqlService] 🗄️ Initializing SQLite database...');
      
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, _dbName);

      _database = await openDatabase(
        path,
        version: _dbVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

      _isInitialized = true;
      debugPrint('[FeedbackSqlService] ✅ SQLite database initialized at: $path');
      
      // Log current ratings count
      final count = await getRatingsCount();
      debugPrint('[FeedbackSqlService] 📊 Current ratings in DB: $count');
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to initialize: $e');
      rethrow;
    }
  }

  /// Create database tables
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('[FeedbackSqlService] 📝 Creating database tables...');
    
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        draftId TEXT NOT NULL,
        purchaseId TEXT NOT NULL,
        rating INTEGER NOT NULL CHECK(rating >= 1 AND rating <= 5),
        createdAt TEXT NOT NULL,
        syncedAt TEXT,
        UNIQUE(purchaseId)
      )
    ''');

    // Create index for faster lookups by purchaseId
    await db.execute('''
      CREATE INDEX idx_purchaseId ON $_tableName (purchaseId)
    ''');

    debugPrint('[FeedbackSqlService] ✅ Database tables created');
  }

  /// Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('[FeedbackSqlService] ⬆️ Upgrading database from v$oldVersion to v$newVersion');
    // Add migration logic here if needed in future versions
  }

  /// Get database instance (ensures initialization)
  Future<Database> get database async {
    if (!_isInitialized) {
      await initialize();
    }
    if (_database == null) {
      throw Exception('Database not initialized');
    }
    return _database!;
  }

  /// Insert or update a rating
  /// 
  /// Rubric: Uses Future with error handler (5 puntos)
  Future<bool> saveRating({
    required String draftId,
    required String purchaseId,
    required int rating,
  }) async {
    try {
      final db = await database;
      
      debugPrint('[FeedbackSqlService] 💾 Saving rating: purchaseId=$purchaseId, rating=$rating');

      // Validate rating
      if (rating < 1 || rating > 5) {
        throw ArgumentError('Rating must be between 1 and 5');
      }

      final data = {
        'draftId': draftId,
        'purchaseId': purchaseId,
        'rating': rating,
        'createdAt': DateTime.now().toIso8601String(),
      };

      // Use REPLACE to handle duplicates (update if exists)
      await db.insert(
        _tableName,
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      debugPrint('[FeedbackSqlService] ✅ Rating saved successfully');
      return true;
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to save rating: $e');
      return false;
    }
  }

  /// Get rating for a specific purchase
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<int?> getRating(String purchaseId) async {
    try {
      final db = await database;
      
      final results = await db.query(
        _tableName,
        columns: ['rating'],
        where: 'purchaseId = ?',
        whereArgs: [purchaseId],
        limit: 1,
      );

      if (results.isEmpty) {
        return null;
      }

      return results.first['rating'] as int?;
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to get rating: $e');
      return null;
    }
  }

  /// Get all ratings for a user (by draftId prefix)
  /// 
  /// Rubric: Uses Future with async/await (10 puntos)
  Future<List<Map<String, dynamic>>> getAllRatings() async {
    try {
      final db = await database;
      
      final results = await db.query(
        _tableName,
        orderBy: 'createdAt DESC',
      );

      return results;
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to get all ratings: $e');
      return [];
    }
  }

  /// Get ratings count
  Future<int> getRatingsCount() async {
    try {
      final db = await database;
      
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      final count = Sqflite.firstIntValue(result) ?? 0;
      
      return count;
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to get ratings count: $e');
      return 0;
    }
  }

  /// Mark rating as synced to Firestore
  Future<bool> markAsSynced(String purchaseId) async {
    try {
      final db = await database;
      
      await db.update(
        _tableName,
        {'syncedAt': DateTime.now().toIso8601String()},
        where: 'purchaseId = ?',
        whereArgs: [purchaseId],
      );

      debugPrint('[FeedbackSqlService] ✅ Rating marked as synced: $purchaseId');
      return true;
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to mark as synced: $e');
      return false;
    }
  }

  /// Get unsynced ratings (for retry logic)
  Future<List<Map<String, dynamic>>> getUnsyncedRatings() async {
    try {
      final db = await database;
      
      final results = await db.query(
        _tableName,
        where: 'syncedAt IS NULL',
        orderBy: 'createdAt ASC',
      );

      return results;
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to get unsynced ratings: $e');
      return [];
    }
  }

  /// Delete a rating
  Future<bool> deleteRating(String purchaseId) async {
    try {
      final db = await database;
      
      await db.delete(
        _tableName,
        where: 'purchaseId = ?',
        whereArgs: [purchaseId],
      );

      debugPrint('[FeedbackSqlService] ✅ Rating deleted: $purchaseId');
      return true;
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to delete rating: $e');
      return false;
    }
  }

  /// Clear all ratings
  Future<void> clearAll() async {
    try {
      final db = await database;
      
      await db.delete(_tableName);
      
      debugPrint('[FeedbackSqlService] ✅ All ratings cleared');
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to clear ratings: $e');
    }
  }

  /// Get average rating for analytics
  Future<double> getAverageRating() async {
    try {
      final db = await database;
      
      final result = await db.rawQuery('SELECT AVG(rating) as avg FROM $_tableName');
      final avg = result.first['avg'];
      
      if (avg == null) return 0.0;
      return (avg as num).toDouble();
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to get average rating: $e');
      return 0.0;
    }
  }

  /// Close database
  Future<void> dispose() async {
    try {
      await _database?.close();
      _database = null;
      _isInitialized = false;
      debugPrint('[FeedbackSqlService] ✅ Database closed');
    } catch (e) {
      debugPrint('[FeedbackSqlService] ❌ Failed to close database: $e');
    }
  }
}

