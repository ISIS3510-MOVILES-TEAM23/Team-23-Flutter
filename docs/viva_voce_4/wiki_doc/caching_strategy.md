# Caching Strategy

## Flutter

For the **Hot Items** feature, we implemented a **Dual-Layer Caching Strategy** that combines the speed of in-memory access with the resilience of persistent storage. This ensures that the "Similar Products" section loads instantly during navigation while remaining fully functional during extended offline periods.

- **Layer 1 – In-Memory LRU (`LruCacheService`)**
  Uses a Least Recently Used algorithm to keep the most visited categories in RAM.
  - **Capacity:** 100 Categories.
  - **TTL:** 30 minutes.
  - **Benefit:** Instant navigation (<1ms) between products of the same category.

- **Layer 2 – Persistent Storage (`Hive`)**
  Serializes raw data (Posts + Clicks + Sales) to the local file system.
  - **TTL:** 7 days.
  - **Benefit:** Allows the "Hotness" algorithm to run offline using cached raw data.

### Hybrid Implementation

The `SimilarProductsService` acts as the arbiter between these layers. It first checks the LRU cache for an immediate hit. If missed, it checks connectivity. If online, it fetches fresh data and populates both caches. If offline, it retrieves raw data from Hive and performs the calculation locally.

```dart
// lib/services/similar_products_service.dart

// 1. Try LRU Cache (Memory)
if (!forceRefresh) {
  final cached = _similarCache.get(normalizedCategoryId);
  if (cached != null) {
    return cached; // Instant return
  }
}

// 2. If Offline, use Persistent Cache (Hive)
if (isOffline) {
  // Retrieve raw inputs instead of static list
  final cachedClicks = await _cacheService.getCachedProductClickEvents();
  final cachedSales = await _cacheService.getCachedSalesData();
  
  // Dynamic recalculation happens here
  // ...
  return calculatedResult;
}

// 3. If Online, fetch and update both layers
final result = await fetchAndCalculate();
_similarCache.put(normalizedCategoryId, result); // Update RAM
await _cacheService.cacheSimilarProducts(...);   // Update Disk
```

### Raw Data vs. Result Caching

Unlike simple caching strategies that store the final HTML/List, we cache the **input signals** (Clicks and Sales). This enables **"Smart Offline Mode"**:

1.  **Flexibility**: The app can recalculate rankings offline if the weighting algorithm changes or if new local events occur.
2.  **Consistency**: The same sorting logic applies whether the data comes from Firestore (Online) or Hive (Offline).
3.  **Resilience**: Even if a specific category wasn't cached as a list, if the raw posts and sales data exist, the list can be generated on the fly.

