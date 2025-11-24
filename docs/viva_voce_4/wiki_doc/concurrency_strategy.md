# Multi-threading/concurrency strategy

## Flutter

The **Hot Items** calculation relies on Dart's **asynchronous concurrency model** (Futures and Streams) to aggregate data from multiple sources (Firestore collections or local cache) without blocking the UI thread. Although the heavy mathematical logic runs on the main isolate, all I/O operations are offloaded to the event loop.

## Futures and Coordinated Aggregation

The `SimilarProductsService` employs a **sequential asynchronous pipeline** to gather the necessary signals for the algorithm. By using `await` on independent data sources, the service ensures that the "hotness" calculation only begins once all datasets (active posts, click history, and sales records) are fully available, maintaining data consistency.

```dart
// lib/services/similar_products_service.dart

Future<List<Post>> getSimilarHotProducts(...) async {
  // ...
  try {
    // 1. Fetch active posts (Async I/O)
    final postsSnapshot = await _db.collection('posts')...get();

    // 2. Fetch engagement signals (Async I/O)
    final clicksSnapshot = await _db.collection('product_click_events')...get();
    final salesSnapshot = await _db.collection('sales')...get();

    // 3. Process and Sort (CPU bound, runs after I/O completes)
    // ... calculate scores ...
    categoryPosts.sort((a, b) {
      // ... sorting logic ...
    });

    return result;
  } catch (e) {
    // Fallback logic
  }
}
```

## Offline Data Recovery

When the device is offline, the concurrency model shifts to retrieving data from the local **Hive** storage. The service performs multiple asynchronous reads to the local file system to reconstruct the datasets. This ensures that the user interface remains responsive (showing a loading state or skeleton) while the file system operations complete in the background.

```dart
// lib/services/similar_products_service.dart

if (isOffline) {
  // Parallel-like retrieval of local datasets
  // Note: These run on the event loop, preventing UI freeze
  final cachedPostsData = await _cacheService.getCachedPosts();
  final cachedClicks = await _cacheService.getCachedProductClickEvents();
  final cachedSales = await _cacheService.getCachedSalesData();
  
  // Recalculate hotness using local data
  // ...
}
```

