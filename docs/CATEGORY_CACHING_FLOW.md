# 📂 Category Caching Flow - Scenario 8

## Overview

This document explains how categories are cached to ensure they're available offline for draft creation.

---

## 🔄 Complete Flow

### 1️⃣ **App Startup (With Internet)**

```
User opens app
    ↓
main.dart → runApp()
    ↓
PrefetchService().prefetchAll()
    ↓
Checks connectivity ✓
    ↓
_prefetchCategories()
    ↓
CategoryRepository.getCategories()
    ↓
FirestoreService.getCategories()
    ├─ Fetches from Firestore
    ├─ Maps documents to Category objects
    └─ Calls CacheService().cacheCategories()
        ↓
    Saves to Hive box 'categories'
    Key: 'all_categories'
    Value: { data: [...], timestamp: "2025-..." }
    ↓
✅ Categories cached for offline use
```

**Log Output:**
```
[Prefetch] 📂 Fetching categories...
[Cache] ✓ Cached 8 categories
[Prefetch] ✓ Cached 8 categories
```

---

### 2️⃣ **User Opens Create Post Screen (Online)**

```
User navigates to Create Post
    ↓
CreatePostViewModel.initState()
    ↓
loadCategories()
    ↓
CategoryRepository.getCategories()
    ↓
FirestoreService.getCategories()
    ├─ Fetches from Firestore ✓
    ├─ AUTO-CACHES to Hive (every time)
    └─ Returns fresh data
    ↓
UI displays dropdown with categories ✓
```

**Log Output:**
```
[CreatePostVM] 🔄 Loading categories...
[CreatePostVM] ✓ Loaded 8 categories
[CreatePostVM] ✓ Selected default category: Books
[Firestore] ⚠️ Failed to cache categories: (optional warning)
```

---

### 3️⃣ **User Opens Create Post Screen (Offline)**

```
User navigates to Create Post (no internet)
    ↓
CreatePostViewModel.initState()
    ↓
loadCategories()
    ↓
CategoryRepository.getCategories()
    ↓
FirestoreService.getCategories()
    ├─ Tries Firestore ❌ (fails - offline)
    └─ Catches error → Fallback to cache
        ↓
    CacheService().getCachedCategories()
        ↓
    Reads from Hive box 'categories'
    Key: 'all_categories'
        ↓
    Checks TTL (30 days)
        ↓
    Maps JSON to Category objects
        ↓
    ✅ Returns cached categories
    ↓
UI displays dropdown with cached categories ✓
```

**Log Output:**
```
[CreatePostVM] 🔄 Loading categories...
[Firestore] ⚠️ Failed to fetch categories from Firestore, trying cache: [Exception]
[Firestore] ✓ Loaded 8 categories from cache
[CreatePostVM] ✓ Loaded 8 categories
[CreatePostVM] ✓ Selected default category: Books
```

---

### 4️⃣ **Edge Case: First App Launch (Offline)**

```
User installs app + opens without internet
    ↓
PrefetchService skips (offline) ❌
    ↓
User opens Create Post
    ↓
loadCategories() fails (no cache exists)
    ↓
UI shows warning message:
"Categories not available. Please connect to internet to load categories."
    ↓
User can still create draft without category ✓
    ↓
When online:
    ├─ PrefetchService caches categories
    └─ User can edit draft and add category
```

**Log Output:**
```
[Prefetch] ⚠️ Offline - skipping prefetch
[CreatePostVM] 🔄 Loading categories...
[CreatePostVM] ❌ Failed to load categories: [Exception]
[CreatePostVM] ℹ️  Categories will be available after connecting to internet once
```

---

## 🔧 Implementation Details

### Files Involved

1. **`lib/services/prefetch_service.dart`**
   - Pre-fetches categories on app startup
   - Only runs when online

2. **`lib/services/firestore_service.dart`**
   - `getCategories()` method
   - Auto-caches on every online fetch
   - Falls back to cache when offline

3. **`lib/services/cache_service.dart`**
   - `cacheCategories()`: Saves to Hive
   - `getCachedCategories()`: Loads from Hive with TTL check (30 days)

4. **`lib/services/local_storage_service.dart`**
   - Opens Hive box `'categories'`
   - Provides CRUD operations

5. **`lib/view_models/create_post_view_model.dart`**
   - `loadCategories()`: Loads categories
   - Handles errors gracefully (shows empty state)

6. **`lib/screens/create_post_screen.dart`**
   - Shows warning UI when `categories.isEmpty`
   - Allows draft creation without category

---

## 📊 Cache Storage Structure

### Hive Box: `'categories'`

**Key:** `'all_categories'`

**Value (JSON string):**
```json
{
  "data": [
    {
      "id": "electronics",
      "name": "Electronics",
      "description": "Devices and gadgets",
      "_id": "electronics"
    },
    {
      "id": "books",
      "name": "Books",
      "description": "Textbooks, novels, academic material",
      "_id": "books"
    }
    // ... more categories
  ],
  "timestamp": "2025-10-30T11:10:59.902659"
}
```

---

## ⏰ Cache TTL (Time To Live)

- **Duration:** 30 days
- **Location:** `cache_service.dart` → `getCachedCategories()`
- **Logic:**
  ```dart
  final timestamp = DateTime.parse(cacheData['timestamp']);
  final age = DateTime.now().difference(timestamp);
  
  if (age.inDays > 30) {
    debugPrint('[Cache] ⚠️ Categories cache expired');
    return null;
  }
  ```

---

## 🎯 Key Design Decisions

### ✅ **Multiple Cache Points**

Categories are cached in **TWO places:**

1. **App Startup** (`PrefetchService`)
   - Ensures fresh cache at app launch
   - Background operation (doesn't block UI)

2. **Every Online Fetch** (`FirestoreService.getCategories()`)
   - Updates cache whenever categories are fetched
   - Ensures cache is always up-to-date

**Why?** This ensures maximum availability:
- If user skips app startup, categories still cache when they open Create Post
- If categories change in Firestore, cache updates automatically

---

### ✅ **Graceful Degradation**

When categories are not available:

1. **UI shows informative message** (not just empty dropdown)
2. **Draft can still be saved** (category is optional for drafts)
3. **User is informed** about needing internet connection
4. **Category can be added later** when editing draft online

**Why?** Prevents data loss and frustration. User can create draft offline and complete it later.

---

### ✅ **No Forced Category Requirement**

Drafts can be saved **without a category**:

```dart
// create_post_screen.dart
Future<void> _saveDraft() async {
  // Basic validation - just check if there's some content
  if (title.isEmpty && description.isEmpty && images.isEmpty) {
    // Show error
    return;
  }
  
  // Save draft even without category ✓
  await viewModel.saveDraftManually();
}
```

**Why?** Categories might not be available offline on first app launch. User shouldn't lose their work.

---

## 🚀 Testing the Flow

### Test Case 1: Normal Flow (Online)

1. Open app with internet ✓
2. Wait for prefetch logs
3. Navigate to Create Post
4. Verify dropdown shows categories ✓

**Expected Logs:**
```
[Prefetch] 📂 Fetching categories...
[Cache] ✓ Cached 8 categories
[CreatePostVM] ✓ Loaded 8 categories
```

---

### Test Case 2: Offline with Cache

1. Open app with internet (cache categories)
2. Turn off internet
3. Navigate to Create Post
4. Verify dropdown shows cached categories ✓

**Expected Logs:**
```
[Firestore] ⚠️ Failed to fetch categories from Firestore, trying cache
[Firestore] ✓ Loaded 8 categories from cache
```

---

### Test Case 3: First Launch Offline

1. Clear app data (delete cache)
2. Turn off internet
3. Open app
4. Navigate to Create Post
5. Verify warning message shows ✓
6. Create draft without category ✓
7. Turn on internet
8. Verify categories load ✓

**Expected Logs:**
```
[Prefetch] ⚠️ Offline - skipping prefetch
[CreatePostVM] ❌ Failed to load categories
[CreatePostVM] ℹ️  Categories will be available after connecting to internet once
```

---

## 📝 Summary

**Categories are cached automatically** at two points:

1. ✅ **App startup** (via `PrefetchService`)
2. ✅ **Every time categories are fetched online** (via `FirestoreService`)

**Offline behavior:**

- ✅ Shows cached categories if available
- ✅ Shows informative message if not available
- ✅ Allows draft creation without category
- ✅ User can add category later when online

**No manual intervention needed** - the caching happens automatically! 🎉

