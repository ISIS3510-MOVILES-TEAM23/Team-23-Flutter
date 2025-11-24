# Local Storage Strategy

What is saved? | Why is it saved? | Where is it saved?
-- | -- | --
**Raw Product Clicks** (`product_click_events`) | To allow offline recalculation of the "hotness" score based on user engagement history. | Hive box `posts_box` (key: `product_click_events`) via `CacheService`.
**Raw Sales Data** (`sales_data`) | To weigh completed purchases in the hotness algorithm even without internet connection. | Hive box `posts_box` (key: `sales_data`) via `CacheService`.
**Similar Products Results** (`similar_products_$id`) | To provide an instant fallback for previously visited categories, avoiding recalculation. | Hive box `posts_box` (key: `similar_products_$id`) via `CacheService`.

## Flutter

In the **Hot Items** feature, we extended the existing **Hive-based storage** strategy to support the offline-first requirement of the popularity algorithm. Instead of only caching the final UI state, we persist the **raw statistical data** (clicks and sales) locally. This allows the application to dynamically recalculate rankings even when offline, rather than displaying a stale static list.

### Key Components

- **`CacheService` extensions**: New methods were added to serialize and store raw engagement metrics.
- **`SimilarProductsService`**: Orchestrates the retrieval of this local data when connectivity is lost.

```dart
// lib/services/cache_service.dart

/// Cache product click events for offline hotness calculation
Future<void> cacheProductClickEvents(List<Map<String, dynamic>> clicks) async {
  try {
    final cacheData = {
      'data': clicks,
      'timestamp': DateTime.now().toIso8601String(),
    };
    await _storage.save(
      LocalStorageService.postsBoxName,
      'product_click_events',
      jsonEncode(cacheData),
    );
  } catch (e) {
    debugPrint('[Cache] ✗ Failed to cache product click events: $e');
  }
}
```

### Data Scope & Location

- **What we store:** Lists of raw JSON objects representing `click_events` and `sales`.
- **Where it lives:** The app's local storage directory managed by Hive.
- **Why Hive:** It allows storing structured JSON data efficiently with fast read/write access, which is crucial when aggregating thousands of data points for the hotness score calculation on mobile devices.

