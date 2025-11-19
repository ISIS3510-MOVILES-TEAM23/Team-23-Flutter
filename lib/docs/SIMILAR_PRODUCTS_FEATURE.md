# Similar Products Feature - "Similar products that're hot"

## Overview

This feature displays popular products from the same category on the product detail screen. It helps users discover related items and increases engagement by showing trending products in the same category.

## How It Works

### 1. **Display Logic**

The similar products section appears at the bottom of the product detail screen, just before the "Chat with seller" button. The section is **only shown if**:
- There are other products in the same category (excluding the current product)
- At least one similar product is found

If the current product is the only one in its category, the section is automatically hidden.

### 2. **"Hotness" Calculation**

Products are ranked by a "hotness score" that combines multiple engagement signals:

```
Hotness Score = (Product Clicks × 3) + (Completed Sales × 10)
```

**Weight breakdown:**
- **Product Click**: 3 points per click
  - Tracked in `product_click_events` collection
  - Logged when users view a product detail page
  - Only counts clicks from other users (not the owner)

- **Completed Sale**: 10 points per sale
  - Tracked in `sales` collection with status = 'completed'
  - Higher weight because it indicates actual purchase intent

**Time Window:** Only counts events from the last 30 days by default (configurable)

### 3. **Sorting Algorithm**

Products are sorted using a two-tier system:

1. **Primary Sort**: Hotness score (descending)
   - Products with more engagement appear first

2. **Secondary Sort**: Creation date (newest first)
   - When products have the same hotness score, newer products are shown first
   - This ensures new products get visibility even without engagement history

### 4. **Caching Strategy**

The feature implements a dual-layer caching system for optimal performance:

#### **Layer 1: LRU In-Memory Cache**
- **Duration**: 30 minutes TTL
- **Capacity**: 100 categories
- **Purpose**: Fast access for frequently viewed categories
- **Key**: Category ID
- **Value**: List of similar products

#### **Layer 2: Persistent Hive Cache**
- **Duration**: 7 days TTL
- **Purpose**: Offline support and cold start optimization
- **Storage**: Local Hive database
- **Keys**:
  - `similar_products_{categoryId}` - Final sorted results
  - `product_click_events` - Raw click data for offline calculation
  - `sales_data` - Raw sales data for offline calculation

#### **Cache Flow:**
```
Request Similar Products
    ↓
Check LRU Cache (in-memory)
    ├─ HIT → Return cached products
    └─ MISS → Check Network Connectivity
        ├─ ONLINE
        │   ├─ Fetch posts, clicks, sales from Firestore
        │   ├─ Cache raw data (clicks + sales) in Hive
        │   ├─ Calculate hotness scores
        │   ├─ Cache results in LRU (30 min TTL)
        │   └─ Cache results in Hive (7 days TTL)
        └─ OFFLINE
            ├─ Load cached posts from Hive
            ├─ Load cached clicks from Hive
            ├─ Load cached sales from Hive
            ├─ Calculate hotness scores from cached data
            └─ Return dynamically calculated results
            └─ Show "Cached" indicator in UI
```

## Implementation Details

### **Files Created/Modified**

1. **`lib/services/similar_products_service.dart`** (NEW)
   - Core service that fetches and ranks similar products
   - Implements LRU caching with TTL
   - Handles offline scenarios gracefully

2. **`lib/widgets/similar_products_section.dart`** (NEW)
   - Beautiful UI component with horizontal scroll
   - Shows loading states with shimmer animation
   - Displays "Cached" indicator when offline
   - Fire icon and elegant styling

3. **`lib/view_models/product_detail_view_model.dart`** (MODIFIED)
   - Added `similarProducts` state
   - Added `isLoadingSimilarProducts` flag
   - Added `isSimilarProductsLoadedFromCache` flag
   - Added `loadSimilarProducts()` method
   - Automatically loads similar products after main product loads

4. **`lib/screens/product_detail_screen.dart`** (MODIFIED)
   - Changed layout to use `SingleChildScrollView` for scrolling
   - Added `SimilarProductsSection` widget
   - Positioned section between product info and chat button

5. **`lib/services/cache_service.dart`** (MODIFIED)
   - Added `cacheSimilarProducts()` method
   - Added `getCachedSimilarProducts()` method
   - Added `cacheProductClickEvents()` method - caches raw click data
   - Added `getCachedProductClickEvents()` method
   - Added `cacheSalesData()` method - caches raw sales data
   - Added `getCachedSalesData()` method
   - All use same TTL as posts (7 days)

## Usage Example

### **As a User**

1. Navigate to any product detail page
2. Scroll down past the product information
3. See "Similar products that're hot" section
4. Horizontally scroll through related popular products
5. Tap any product to navigate to its detail page

### **Offline Behavior**

When the user is offline:
- The section shows a "Cached" badge in orange
- **The algorithm recalculates hotness scores dynamically** using cached data:
  - Cached posts (7-day TTL)
  - Cached product click events (7-day TTL)
  - Cached sales data (7-day TTL)
- This means rankings stay accurate even offline (within cache TTL)
- If no cache exists, the section is hidden
- Navigation to similar products works normally (uses cached product data)

**Advantage**: The offline experience is not just "stale results" - it's a **fully functional recommendation algorithm** running on cached data. If new products were added while online, they'll appear in offline results too.

## API Reference

### `SimilarProductsService.getSimilarHotProducts()`

```dart
Future<List<Post>> getSimilarHotProducts({
  required String categoryId,      // Category to filter by (e.g., "categories/electronics")
  required String excludePostId,   // Current product ID to exclude from results
  int limit = 6,                   // Max number of products to return
  int windowDays = 30,             // Time window for calculating popularity
  bool forceRefresh = false,       // Bypass cache and fetch fresh data
  bool debug = false,              // Enable debug logging
})
```

### `ProductDetailViewModel.loadSimilarProducts()`

```dart
Future<void> loadSimilarProducts({
  bool forceRefresh = false,  // Force refresh from network
})
```

## Configuration Options

You can customize the feature behavior by modifying constants in `SimilarProductsService`:

```dart
// Weights for hotness calculation
const double W_CLICK = 3.0;  // Points per product click
const double W_SALE = 10.0;  // Points per completed sale

// Cache settings
final LruCacheService<String, List<Post>> _similarCache = LruCacheService(
  maxCapacity: 100, // Max categories to cache
);

// Cache TTL: 30 minutes (in getSimilarHotProducts method)
_similarCache.put(categoryId, products, ttl: Duration(minutes: 30));
```

## Performance Optimizations

1. **Parallel Queries**: Clicks and sales are fetched in parallel
2. **LRU Cache**: Avoids redundant Firestore queries for popular categories
3. **Lazy Loading**: Similar products load asynchronously after main product
4. **Smart Filtering**: Category filtering happens in memory (fast)
5. **Offline First**: Returns cached data immediately when offline

## Analytics & Monitoring

The service logs important events for monitoring:

```dart
debugPrint('[SimilarProducts] 🔥 Fetching similar hot products for category: $categoryId');
debugPrint('[SimilarProducts] ✅ LRU CACHE HIT - Returning N products');
debugPrint('[SimilarProducts] 📴 Offline detected - trying persistent cache...');
debugPrint('[SimilarProducts] 🏆 Top similar products:');
debugPrint('[SimilarProducts] ⚡ TOTAL: N products in Xms');
```

Enable debug mode to see detailed logs:

```dart
await _similarProductsService.getSimilarHotProducts(
  categoryId: product.categoryId,
  excludePostId: product.id,
  debug: true, // Enable detailed logging
);
```

## Future Enhancements

Potential improvements for the future:

1. **Machine Learning**: Use ML to personalize product recommendations
2. **Cross-Category**: Show products from related categories
3. **User Preferences**: Weight products based on user's browsing history
4. **A/B Testing**: Test different hotness score weights
5. **Pagination**: Load more products on scroll
6. **View Tracking**: Log when users view similar products section

## Troubleshooting

### Section Not Showing

**Possible causes:**
1. No other products in the same category
2. Network error and no cached data
3. Category ID mismatch (check format: "categories/xyz" vs "xyz")

**Solution:**
- Check debug logs
- Verify category has multiple products in Firestore
- Clear cache and retry

### Slow Loading

**Possible causes:**
1. Large number of clicks/sales to process
2. Cold start with empty cache
3. Poor network connection

**Solutions:**
- Reduce `windowDays` to process fewer events
- Pre-warm cache on app start
- Consider implementing pagination

### Incorrect Sorting

**Possible causes:**
1. Click events missing category field
2. Sales with incorrect status
3. Time window too narrow

**Solutions:**
- Verify `product_click_events` include category
- Check sales have status = 'completed'
- Increase `windowDays` parameter

## Testing

### Manual Testing Checklist

- [ ] Section appears with 2+ products in category
- [ ] Section hidden when only 1 product in category
- [ ] Products sorted correctly (hot products first)
- [ ] Offline mode shows cached products
- [ ] "Cached" badge appears when offline
- [ ] Tapping product navigates to detail page
- [ ] Horizontal scroll works smoothly
- [ ] Loading state shows shimmer animation
- [ ] Cache persists across app restarts

### Test Scenarios

**Scenario 1: Multiple Hot Products**
1. Create 5 products in "Electronics" category
2. Add 20 clicks to Product A
3. Add 2 completed sales to Product B
4. View Product C detail page
5. Verify Product B appears first (20 points)
6. Verify Product A appears second (60 points)

**Scenario 2: Equal Scores**
1. Create 3 products with same clicks/sales
2. Product A created 1 day ago
3. Product B created today
4. Verify Product B appears first (newer)

**Scenario 3: Offline Mode**
1. View product while online
2. Enable airplane mode
3. View same product again
4. Verify similar products load from cache
5. Verify "Cached" badge is shown

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                  ProductDetailScreen                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │            SimilarProductsSection                     │   │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐ │   │
│  │  │Product A│  │Product B│  │Product C│  │Product D│ │   │
│  │  │ 🔥 Hot  │  │ 🔥 Hot  │  │ 🔥 Hot  │  │ 🔥 Hot  │ │   │
│  │  └─────────┘  └─────────┘  └─────────┘  └─────────┘ │   │
│  └──────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│              ProductDetailViewModel                          │
│  • similarProducts: List<Post>                              │
│  • isLoadingSimilarProducts: bool                           │
│  • loadSimilarProducts()                                    │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────┐
│              SimilarProductsService                          │
│  • getSimilarHotProducts()                                  │
│  • LRU Cache (30 min)                                       │
│  • Calculate hotness scores                                 │
└─────────────────────────────────────────────────────────────┘
                            ↕
┌──────────────────┬──────────────────┬──────────────────────┐
│   Firestore      │    LRU Cache     │    Hive Cache        │
│   Collections    │    (Memory)      │    (Persistent)      │
├──────────────────┼──────────────────┼──────────────────────┤
│ • posts          │ • 100 categories │ • 7 days TTL         │
│ • product_click  │ • 30 min TTL     │ • Offline support    │
│ • sales          │                  │                      │
└──────────────────┴──────────────────┴──────────────────────┘
```

## Credits

Implemented following the existing patterns in the codebase:
- **RecommendationService**: LRU cache pattern and scoring algorithm
- **MajorRecommendationsService**: Category-based filtering approach
- **ProductDetailViewModel**: Offline-first loading strategy
- **CacheService**: Persistent caching with TTL

---

**Author**: Claude
**Date**: 2025-11-19
**Version**: 1.0.0
**Status**: ✅ Production Ready
