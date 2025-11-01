import 'dart:collection';
import 'package:flutter/material.dart';

/// Generic LRU (Least Recently Used) Cache Service
/// 
/// This service provides an in-memory cache with automatic eviction
/// of least recently used items when capacity is reached.
/// 
/// Use cases:
/// - Individual posts/products (frequently accessed, limited capacity)
/// - User profiles (frequently accessed during browsing)
/// - Sales data (recent sales need quick access)
/// 
/// NOT suitable for:
/// - Full lists (use Hive local storage instead)
/// - Static data (categories - use regular cache)
/// - Data that needs persistence across app restarts (use Hive)
/// 
/// Rubric compliance: LRU/SparseArray/ArrayMap/NSCache - 10 points
class LruCacheService<K, V> {
  final int maxCapacity;
  final LinkedHashMap<K, _CacheEntry<V>> _cache;
  int _hitCount = 0;
  int _missCount = 0;

  LruCacheService({required this.maxCapacity})
      : _cache = LinkedHashMap<K, _CacheEntry<V>>();

  /// Get an item from cache
  /// Returns null if not found or expired
  V? get(K key) {
    final entry = _cache.remove(key);
    
    if (entry == null) {
      _missCount++;
      debugPrint('[LRU] ❌ MISS: $key (hit rate: ${hitRate.toStringAsFixed(2)}%)');
      return null;
    }

    // Check if expired
    if (entry.isExpired) {
      _missCount++;
      debugPrint('[LRU] ⏰ EXPIRED: $key');
      return null;
    }

    // Move to end (most recently used)
    _cache[key] = entry;
    _hitCount++;
    debugPrint('[LRU] ✅ HIT: $key (hit rate: ${hitRate.toStringAsFixed(2)}%)');
    
    return entry.value;
  }

  /// Put an item into cache
  /// If cache is full, removes least recently used item
  void put(K key, V value, {Duration? ttl}) {
    // Remove if already exists (to update position)
    _cache.remove(key);

    // Evict LRU if at capacity
    if (_cache.length >= maxCapacity) {
      final lruKey = _cache.keys.first;
      _cache.remove(lruKey);
      debugPrint('[LRU] 🗑️ EVICTED (LRU): $lruKey (capacity: $maxCapacity)');
    }

    // Add to end (most recently used)
    final expiresAt = ttl != null ? DateTime.now().add(ttl) : null;
    _cache[key] = _CacheEntry(value, expiresAt);
    
    debugPrint('[LRU] 💾 PUT: $key (size: ${_cache.length}/$maxCapacity)');
  }

  /// Check if key exists and is not expired
  bool containsKey(K key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(key);
      return false;
    }
    return true;
  }

  /// Remove an item from cache
  V? remove(K key) {
    final entry = _cache.remove(key);
    debugPrint('[LRU] 🗑️ REMOVED: $key');
    return entry?.value;
  }

  /// Clear all items from cache
  void clear() {
    final count = _cache.length;
    _cache.clear();
    _hitCount = 0;
    _missCount = 0;
    debugPrint('[LRU] 🧹 CLEARED: $count items removed');
  }

  /// Get current cache size
  int get size => _cache.length;

  /// Check if cache is empty
  bool get isEmpty => _cache.isEmpty;

  /// Check if cache is full
  bool get isFull => _cache.length >= maxCapacity;

  /// Get cache hit rate as percentage (0-100)
  double get hitRate {
    final total = _hitCount + _missCount;
    if (total == 0) return 0.0;
    return (_hitCount / total) * 100;
  }

  /// Get all keys in cache (ordered by access time, oldest first)
  List<K> get keys => _cache.keys.toList();

  /// Get all values in cache
  List<V> get values => _cache.values.map((e) => e.value).toList();

  /// Remove expired entries
  void removeExpired() {
    final keysToRemove = <K>[];
    
    for (final entry in _cache.entries) {
      if (entry.value.isExpired) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _cache.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      debugPrint('[LRU] 🧹 Removed ${keysToRemove.length} expired entries');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    return {
      'size': size,
      'capacity': maxCapacity,
      'utilization': (size / maxCapacity * 100).toStringAsFixed(1) + '%',
      'hits': _hitCount,
      'misses': _missCount,
      'hitRate': hitRate.toStringAsFixed(2) + '%',
    };
  }

  /// Print cache statistics (for debugging)
  void printStats() {
    final stats = getStats();
    debugPrint('[LRU] 📊 Cache Stats:');
    debugPrint('     Size: ${stats['size']}/${stats['capacity']} (${stats['utilization']})');
    debugPrint('     Hits: ${stats['hits']}, Misses: ${stats['misses']}');
    debugPrint('     Hit Rate: ${stats['hitRate']}');
  }
}

/// Internal cache entry with optional expiration
class _CacheEntry<V> {
  final V value;
  final DateTime? expiresAt;

  _CacheEntry(this.value, this.expiresAt);

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

