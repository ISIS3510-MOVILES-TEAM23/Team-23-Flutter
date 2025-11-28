import 'dart:collection';

class LruCache<K, V> {
  final int maxSize;
  final LinkedHashMap<K, V> _map;

  LruCache(this.maxSize) : _map = LinkedHashMap<K, V>();

  /// Get a value from the cache, moving it to the most recently used position.
  V? get(K key) {
    final value = _map.remove(key);
    if (value != null) {
      _map[key] = value; // Re-insert to make it MRU
    }
    return value;
  }

  /// Put a value into the cache. If the cache is full, evicts the LRU item.
  void put(K key, V value) {
    _map.remove(key); // Remove if exists to update order
    _map[key] = value;

    if (_map.length > maxSize) {
      // Remove the first (LRU) item
      final lruKey = _map.keys.first;
      _map.remove(lruKey);
    }
  }

  /// Remove a key from the cache.
  void remove(K key) {
    _map.remove(key);
  }

  /// Clear the entire cache.
  void clear() {
    _map.clear();
  }

  /// Get the current size of the cache.
  int get size => _map.length;

  /// Check if the cache contains a key.
  bool containsKey(K key) => _map.containsKey(key);

  /// Get all keys in order of most recently used to least recently used.
  Iterable<K> get keys => _map.keys;

  /// Get all values in order of most recently used to least recently used.
  Iterable<V> get values => _map.values;
}