# Eventual Connectivity Design - Campus Marketplace

## Overview

This document describes the eventual connectivity scenarios for the Campus Marketplace app, detailing how each screen behaves under different connectivity conditions.

---

## Login Screen

### Scenario 1: User Opens App Without Internet (Already Logged In)

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user has previously logged in successfully and opens the app without internet connection. |
| **System Response** | The system automatically bypasses the login screen and loads the Home Screen using the cached authentication token stored in SharedPreferences. The user can browse cached products, view cached chats, and use all offline features without re-authentication. A banner shows: "Offline mode - Some features limited." |
| **Possible Antipatterns** | #1 Blocked application, #4 Lost content |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #1 Cache falling back to network |
| **Storage Type** | 3. SharedPreferences (for auth token), 2. Local database (Hive for user data) |
| **Stored Data Type** | Firebase Auth Token (JWT), User Document (id, email, name, major), Session metadata (lastLogin, tokenExpiry) |
| **Rationale** | Firebase Authentication generates a persistent session token upon successful login that remains valid for extended periods (typically 1 hour, with automatic refresh when online). By storing this token in SharedPreferences, the app can validate the user's session locally without requiring internet connection for every app launch. This prevents the "blocked application" antipattern where users cannot access any functionality offline. The token is securely stored and automatically refreshed when the user goes online. If the token expires (after extended offline period), the app gracefully handles by showing login screen with message: "Session expired. Please log in when online." This approach balances security (tokens do expire) with usability (users can access the app offline for reasonable periods). Once online, Firebase Auth automatically validates and refreshes the token in the background. |

### Scenario 1b: First-Time Login Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user has never logged in before and tries to log in without internet connection. |
| **System Response** | The system displays a message: "Internet connection required for first-time login. Please connect and try again." Login button is disabled. |
| **Possible Antipatterns** | #3 Non-informative message, #1 Blocked application |
| **Caching + Retrieving Strategy** | N/A |
| **Storage Type** | N/A |
| **Stored Data Type** | N/A |
| **Rationale** | Initial login requires real-time server validation to verify credentials and generate the authentication token that will be cached. Without internet, Firebase Authentication cannot validate credentials or generate tokens. Clear messaging informs users this is a one-time requirement. After successful first login with internet, subsequent app launches work offline using the cached token from Scenario 1. |

---

## Signup Screen

### Scenario 2: Register Without Internet Connection

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user wants to create an account but has no internet connection. |
| **System Response** | The system will display a message: "Internet connection required to create account. Please connect and try again." Signup button is disabled. |
| **Possible Antipatterns** | #3 Non-informative message |
| **Caching + Retrieving Strategy** | N/A |
| **Storage Type** | N/A |
| **Stored Data Type** | N/A |
| **Rationale** | Since sign-up is a one-time action that requires stable connection to authenticate and save user data securely in Firebase, it's essential that it occurs online. Without internet access, the system avoids caching any credentials to prevent incomplete or failed sign-up attempts. This approach ensures a smooth onboarding process when connectivity is available and maintains security standards. |

---

## Home Screen

### Scenario 3: Browse Products Without Internet (Previously Loaded)

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user wants to browse products (Featured, New Posts, Recommendations) but has no internet connection. The user has previously opened the app with internet. |
| **System Response** | The system will display products using the last locally saved data with a banner: "Offline - Showing cached products. Last updated: 2 hours ago." |
| **Possible Antipatterns** | #4 Lost content, #2 Stuck progress bar, #3 Non-informative message |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #4 Cached on network response, #1 Cache falling back to network |
| **Storage Type** | 2. Local database (Hive) + 1.e. Firestore cache |
| **Stored Data Type** | Post Documents (id, title, description, price, images URLs, categoryId, userId, createdAt), cached images via cached_network_image |
| **Rationale** | Given that product listings are unlikely to change rapidly and the information rarely expires in short periods, it is logical to display this locally saved data when there is no connectivity. This maintains user engagement and allows browsing even offline. Cache expires after 7 days to prevent excessive stale data. Images are cached automatically by the cached_network_image package already implemented. |

### Scenario 4: Browse Products Without Internet (First Time)

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user opens the app for the first time and wants to browse products but has no internet connection. |
| **System Response** | The system will show a generic fallback message: "Internet connection required. Please connect to start exploring products." with a retry button. |
| **Possible Antipatterns** | #2 Stuck progress bar, #4 Lost content, #3 Non-informative message |
| **Caching + Retrieving Strategy** | #6 Generic fallback |
| **Storage Type** | 1.d. App's stored files with texts and icons |
| **Stored Data Type** | Strings and XML |
| **Rationale** | At this point, no data has been retrieved or cached, making it impossible to show content. A friendly message with a clear solution (connect to internet) is shown. This prevents the stuck progress bar antipattern and provides clear feedback to the user about what action to take. |

### Scenario 5: Connection Restored After Generic Fallback

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user sees the generic fallback on Home Screen but then the device recovers connection. |
| **System Response** | The system will automatically reload the screen when detecting connectivity, fetching and displaying products. |
| **Possible Antipatterns** | #7 Unavailable functionality after connection recovery |
| **Caching + Retrieving Strategy** | #2 Network only |
| **Storage Type** | 1.e. Firestore NoSQL Document DB, cached_network_image |
| **Stored Data Type** | Post Documents, image files |
| **Rationale** | When the device recovers connection, the screen reloads automatically because the user has solved the problem, so the information should be shown. Otherwise, the user will think there are more problems and that the app isn't properly handling connectivity recovery. This prevents frustration and ensures smooth transition back to online mode. |

---

## Chat Screen

### Scenario 6: Send Message Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user sends a message to a seller/buyer but has no internet connection. |
| **System Response** | The system displays the message immediately with a "Queued" badge and paper plane icon (📤). Message is stored locally in a sync queue. A toast notification shows: "Message will be sent when online." When connection is restored, the message syncs automatically and badge changes to checkmark (✓). |
| **Possible Antipatterns** | #4 Lost content, #5 Unavailable functionality after connection recovery, #2 Stuck progress bar |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #5 Queue and sync on reconnect |
| **Storage Type** | 2. Local database (Hive) with sync queue |
| **Stored Data Type** | Message Documents (clientId: UUID, chatId, senderId, content, sentAt, syncStatus: pending/synced/failed, retryCount) |
| **Rationale** | Messages are critical for buyer-seller negotiation and contain important purchase information that cannot be lost. Queuing with optimistic UI (showing message immediately) provides better UX than blocking send functionality. Client-generated UUID prevents duplicate messages on sync. Exponential backoff retry (3 attempts: 0s, 5s, 15s) handles temporary network issues gracefully. This is one of the most important offline features for user satisfaction. |

### Scenario 7: View Chat History Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user opens a chat to view conversation history but has no internet connection. |
| **System Response** | The system displays the last 100 cached messages with a banner: "Offline - Showing cached messages. New messages will appear when online." |
| **Possible Antipatterns** | #4 Lost content, #3 Non-informative message |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #1 Cache falling back to network |
| **Storage Type** | 2. Local database (Hive) + 1.e. Firestore cache |
| **Stored Data Type** | Message Documents, Chat metadata |
| **Rationale** | Users need to reference previous conversation history for context during negotiations even when offline. Caching the last 100 messages per chat (or last 30 days, whichever is smaller) provides sufficient context while managing storage efficiently. When connectivity returns, new messages are fetched and merged with local cache using timestamp ordering. |

---

## Create Post Screen

### Scenario 8: Create Post Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user fills out the post creation form but has no internet connection. |
| **System Response** | Form fields work normally with auto-save every 5 seconds. Categories dropdown works (pre-cached). "Sell" button changes to "Save Draft". AI Analysis button is disabled with message: "AI features require internet." When tapping "Save Draft", notification shows: "Post saved as draft. It will be published when you're online." Draft appears in a "Drafts" section accessible from profile. |
| **Possible Antipatterns** | #4 Lost content, #5 Unavailable functionality after connection recovery, #3 Non-informative message |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #5 Queue and sync on reconnect |
| **Storage Type** | 2. Local database (Hive) + App cache directory (for images) |
| **Stored Data Type** | DraftPost Documents (draftId: UUID, title, description, price, categoryId, localImagePaths, status: editing/pending_upload/uploading/failed, createdAt, lastModified) |
| **Rationale** | Users invest significant time creating posts with detailed descriptions and images. Losing this data due to connectivity issues creates terrible UX and user frustration. Auto-save every 5 seconds prevents data loss from unexpected app closures. Images are stored in app cache directory. When online, upload queue processes drafts: first uploads images to Firebase Storage, then creates Firestore post document with image URLs, finally deletes local draft. Cannot complete submission without internet because Firebase Storage upload requires connectivity. |

---

## Product Detail Screen

### Scenario 9: View Product Details Without Internet (Previously Viewed)

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user taps on a product to see details but has no internet connection. The product was previously viewed. |
| **System Response** | The system displays cached product details with banner: "Offline - Showing cached information." Images load from cached_network_image cache. "Contact Seller" button works if chat already exists (cached). |
| **Possible Antipatterns** | #4 Lost content, #3 Non-informative message |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache |
| **Storage Type** | 2. Local database (Hive) + cached_network_image cache |
| **Stored Data Type** | Post Documents (full details), cached image files |
| **Rationale** | Products viewed recently are likely to be viewed again during comparison shopping. Caching prevents repeated data loss and improves performance. Images use cached_network_image package already implemented. Cache duration of 7 days balances freshness with offline availability. If product was never viewed before, shows message: "This product requires internet connection to load." |

### Scenario 10: Start New Chat Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user wants to contact a seller from Product Detail but has no internet connection and no existing chat. |
| **System Response** | The system displays a message: "Cannot start new chat while offline. Please connect to internet to contact this seller." "Contact Seller" button is disabled with gray appearance. |
| **Possible Antipatterns** | #3 Non-informative message, #6 Redirection without connectivity check |
| **Caching + Retrieving Strategy** | N/A |
| **Storage Type** | N/A |
| **Stored Data Type** | N/A |
| **Rationale** | Creating a new chat requires creating a Firestore document with participant IDs, product reference, and initial metadata. This operation cannot be queued because chat creation is a prerequisite for sending messages - the chatId must exist before messages can be associated with it. Clear messaging prevents user confusion about why the button is disabled. If chat already exists (cached), user can open it and send queued messages. |

---

## Categories Screen

### Scenario 11: Browse Categories Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user wants to browse product categories but has no internet connection. |
| **System Response** | The system displays cached categories with banner: "Offline - Showing cached categories." Tapping a category shows cached products in that category. |
| **Possible Antipatterns** | #4 Lost content, #3 Non-informative message |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #4 Cached on network response |
| **Storage Type** | 1.e. Firestore cache + 2. Local database (Hive) |
| **Stored Data Type** | Category Documents (id, name, icon), Post Documents filtered by categoryId |
| **Rationale** | Categories are essentially static data that rarely changes (admin-managed). Long cache duration (30 days) is appropriate. Products per category are also cached from previous browsing sessions. This allows full offline browsing experience for previously loaded content. Category structure is loaded once and persists, making it ideal for aggressive caching. |

---

## Sales Screen

### Scenario 12: View Sales Status Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user (seller) wants to check sale status but has no internet connection. |
| **System Response** | The system displays last known sale status from cache with disclaimer: "Offline - Last updated: 10 minutes ago. Status may have changed." Status badges (Pending/Completed) show cached values. Pull-to-refresh shows message: "Cannot refresh while offline." |
| **Possible Antipatterns** | #4 Lost content, #3 Non-informative message, #2 Stuck progress bar |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache |
| **Storage Type** | 2. Local database (Hive) |
| **Stored Data Type** | Sale Documents (id, postRef, buyerRef, sellerRef, price, status, createdAt, updatedAt) |
| **Rationale** | Sale status is critical financial information that users need to reference. Current implementation uses 3-second polling which is inefficient and fails completely offline. Cached status with clear "last updated" timestamp prevents confusion while offline. When online, should ideally migrate from polling to FCM (Firebase Cloud Messaging) push notifications for real-time updates without battery drain. Caching prevents complete loss of functionality during connectivity issues. |

---

## Confirm Purchase Screen

### Scenario 13: Complete Transaction Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The buyer/seller is on the confirmation screen but has no internet connection. |
| **System Response** | The system displays a message: "Internet connection required to complete transaction. Please connect for security." "Confirm Purchase" button is disabled. Previous transaction data (price, seller info) is shown from cache. |
| **Possible Antipatterns** | #3 Non-informative message, #6 Redirection without connectivity check |
| **Caching + Retrieving Strategy** | N/A |
| **Storage Type** | N/A |
| **Stored Data Type** | N/A |
| **Rationale** | Financial transactions require real-time verification and cannot be queued offline for critical security and data integrity reasons. Transactions must be atomic and immediately confirmed by the server to prevent: duplicate payments, race conditions between buyer/seller, status inconsistencies, and fraud. Clear messaging explains why this feature requires internet. This is a trade-off between functionality and security where security must win. |

---

## Profile Screen

### Scenario 14: Edit Profile Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user edits their profile (name, major, contact preferences) but has no internet connection. |
| **System Response** | Form allows editing. When saving, system stores changes locally and shows notification: "Profile changes saved. Will sync when online." Profile displays updated values immediately (optimistic UI). When connection restored, changes sync automatically in background. |
| **Possible Antipatterns** | #4 Lost content, #5 Unavailable functionality after connection recovery |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #5 Queue and sync on reconnect |
| **Storage Type** | 2. Local database (Hive) |
| **Stored Data Type** | SyncQueue (operationId, type: profile_update, payload: {name, major, contactPreferences}, retryCount), User Document |
| **Rationale** | Profile updates are low-priority but should not be lost, as users expect their changes to persist. Queue-based sync with optimistic UI provides good UX - user sees changes immediately and system handles sync transparently. Last-write-wins conflict resolution is acceptable for profile data (unlikely to be edited from multiple devices simultaneously). Changes are non-critical so eventual consistency is fine. |

---

## Wishlist Screen

### Scenario 15: Add/Remove Products from Wishlist Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user wants to add or remove products from their wishlist but has no internet connection. |
| **System Response** | System allows adding/removing products with immediate UI update (optimistic UI). Shows toast notification: "Wishlist updated. Changes will sync when online." Heart icon toggles instantly. Changes are queued locally. When connection restored, wishlist syncs automatically with Firestore. If conflicts occur (same product modified on different device), last-write-wins. |
| **Possible Antipatterns** | #4 Lost content, #5 Unavailable functionality after connection recovery |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #5 Queue and sync on reconnect |
| **Storage Type** | 2. Local database (Hive) with sync queue + App cache directory (for images) |
| **Stored Data Type** | WishlistItem Documents (userId, postId, addedAt, syncStatus: pending/synced), SyncQueue (operationId, type: wishlist_add/wishlist_remove, payload: {postId}, retryCount) + cached image files |
| **Rationale** | Wishlist is a personal collection that users frequently modify while browsing. Blocking this functionality offline would frustrate users and lose valuable intent data. Optimistic UI provides instant feedback. Queue-based sync ensures no changes are lost. Wishlist operations are idempotent (adding twice = added once, removing non-existent = no-op), making them safe for offline queuing. Last-write-wins conflict resolution is acceptable since wishlist is personal and conflicts are rare. When online, sync happens in background with exponential backoff (3 retries: 0s, 5s, 15s). This feature enables continuous browsing and curation even offline. |

### Scenario 16: View Wishlist Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user wants to view their saved wishlist products but has no internet connection. |
| **System Response** | System displays cached wishlist with banner: "Offline - Showing your saved wishlist. Last synced: 30 minutes ago." Shows product thumbnails from cached_network_image, title, and price. Tapping a product opens cached Product Detail screen (Scenario 9). Pull-to-refresh shows message: "Cannot refresh while offline." |
| **Possible Antipatterns** | #4 Lost content, #3 Non-informative message |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #1 Cache falling back to network |
| **Storage Type** | 2. Local database (Hive) + cached_network_image |
| **Stored Data Type** | WishlistItem Documents with embedded Post data (postId, title, price, imageUrl, availability), cached image files |
| **Rationale** | Wishlist is a frequently accessed collection that users reference during comparison shopping. Full offline access is essential. Cached wishlist includes embedded product data (title, price, images) to avoid additional lookups. When products in wishlist are updated online (price change, sold), changes sync next time user goes online. Clear "last synced" timestamp manages expectations. Images use cached_network_image for automatic caching. If wishlist is empty on first load offline, shows message: "Connect to internet to load your wishlist." This maintains engagement and allows users to review saved items anytime. |

---

## User Ranking Screen

### Scenario 17: View User Rankings Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user wants to check seller/buyer reputation rankings but has no internet connection. |
| **System Response** | System displays cached user ratings with banner: "Offline - Showing last known ratings. Last updated: 2 hours ago." Shows star rating, total reviews count, and cached review comments. User profile includes cached reputation badge (Gold Seller, Verified Buyer, etc.). "Submit Review" button is disabled with message: "Connect to internet to submit reviews." |
| **Possible Antipatterns** | #4 Lost content, #3 Non-informative message, #2 Stuck progress bar |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #1 Cache falling back to network |
| **Storage Type** | 2. Local database (Hive) + 1.e. Firestore cache |
| **Stored Data Type** | UserRating Documents (userId, averageRating, totalReviews, reputationScore, badgeLevel, lastUpdated), Review Documents (reviewId, reviewerId, rating, comment, createdAt) - cached last 20 reviews per user |
| **Rationale** | User reputation is critical trust signal for marketplace transactions. Users check seller ratings before contacting or purchasing. Caching ratings prevents loss of this important decision-making data offline. Ratings change slowly (accumulate over time), making them ideal for caching with 24-hour expiration. Clear "last updated" timestamp helps users assess freshness. Cannot submit new reviews offline because reputation calculations require server-side aggregation to prevent tampering and ensure fairness. Cached reviews provide sufficient context for trust decisions. When online, ratings refresh automatically in background. This balances transparency (show cached data with timestamp) with security (reviews must be validated online). |

### Scenario 18: Submit Review Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user wants to submit a review/rating for a seller/buyer but has no internet connection. |
| **System Response** | Review form works normally (star selection, comment text). When tapping "Submit Review", system saves review as draft with notification: "Review saved. Will be submitted when online." Draft appears in "Pending Reviews" section. When connection restored, review submits automatically with background notification: "Your review has been posted." Review requires transaction verification server-side before posting. |
| **Possible Antipatterns** | #4 Lost content, #5 Unavailable functionality after connection recovery |
| **Caching + Retrieving Strategy** | #5 Queue and sync on reconnect |
| **Storage Type** | 2. Local database (Hive) with sync queue |
| **Stored Data Type** | DraftReview Documents (draftId: UUID, revieweeId, transactionId, rating, comment, createdAt, syncStatus: pending/syncing/failed, retryCount), SyncQueue (operationId, type: review_submit, payload) |
| **Rationale** | Reviews contain valuable user feedback that should never be lost. Users invest emotional energy writing reviews, especially negative ones about bad experiences. Losing this content creates frustration and looks unprofessional. Draft + queue approach preserves content while preventing fake reviews. Server-side validation checks: (1) transaction actually occurred between users, (2) no duplicate reviews for same transaction, (3) review timing is reasonable (within 30 days of transaction). Cannot post review immediately offline because these validations require database queries. When online, reviews sync with exponential backoff (3 retries). Failed reviews (e.g., invalid transaction) show error: "Review could not be posted. Transaction not found." This protects reputation system integrity while maximizing content preservation. |

---

## Search Screen

### Scenario 19: Search Products Without Internet

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user searches for products but has no internet connection. |
| **System Response** | The system searches within cached products and displays results with disclaimer banner: "Offline - Searching cached products only. Connect to internet for latest results and analytics logging." Search events are queued locally and logged to Firestore (product_search_events collection) when connection is restored. |
| **Possible Antipatterns** | #4 Lost content, #3 Non-informative message |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #1 Cache falling back to network, #5 Queue and sync on reconnect (for analytics) |
| **Storage Type** | 2. Local database (Hive) for cached products, SyncQueue for analytics events |
| **Stored Data Type** | Post Documents (searchable fields: title, description, categoryId), SearchEvent Documents (userId, query, timestamp, source: "offline_cache") |
| **Rationale** | Search functionality should not be completely blocked when offline. Users can search their previously loaded/cached products, which is valuable for browsing previously seen items. The search procedure executes over the cached product list stored in local database. Clear messaging informs users they're searching limited cached data, not the full online catalog. Search analytics events are queued locally and synced when online for recommendation engine improvements. This prevents the "lost content" antipattern where search would show nothing, while being transparent about limitations. |

---

## Summary: Connectivity Strategy by Feature

| Feature | Primary Strategy | Offline Capability | Priority |
|---------|------------------|-------------------|----------|
| **App Launch (Logged In)** | #3 Cache fallback (token) | ✅ Full access | Critical |
| **First-Time Login** | N/A (Network only) | ❌ Blocked | N/A |
| **Signup** | N/A (Network only) | ❌ Blocked | N/A |
| **Home Browse** | #3 Cache fallback | ✅ If cached | Critical |
| **Chat Send** | #5 Queue & sync | ✅ Full | Critical |
| **Chat View** | #3 Cache fallback | ✅ Full | Critical |
| **Create Post** | #5 Queue & sync | ✅ Draft mode | High |
| **Product Detail** | #3 Cache fallback | ✅ If cached | High |
| **Start New Chat** | N/A (Network only) | ❌ Blocked | N/A |
| **Categories** | #3 Cache fallback | ✅ Full | Medium |
| **Sales View** | #3 Cache fallback | ✅ View only | Medium |
| **Confirm Purchase** | N/A (Network only) | ❌ Blocked | N/A |
| **Profile Edit** | #5 Queue & sync | ✅ Full | Low |
| **Wishlist Add/Remove** | #5 Queue & sync | ✅ Full | High |
| **Wishlist View** | #3 Cache fallback | ✅ Full | High |
| **User Rankings View** | #3 Cache fallback | ✅ View only | Medium |
| **Submit Review** | #5 Queue & sync | ✅ Draft mode | Medium |
| **Search** | #3 Cache fallback | ✅ Limited | Medium |

---

## Antipattern Prevention Summary

| Antipattern | Prevention Strategy | Affected Scenarios |
|-------------|---------------------|-------------------|
| **#1 Blocked Application** | Cache auth token in SharedPreferences for offline access | 1, 1b |
| **#2 Stuck Progress Bar** | Show cached data immediately OR clear error messages | 3, 4, 6, 7, 12, 17 |
| **#3 Non-informative Message** | Provide context: "Offline - Showing cached products" | All scenarios |
| **#4 Lost Content** | Queue operations, auto-save drafts, cache data, cache auth token | 1, 3, 6, 7, 8, 9, 11, 12, 14, 15, 16, 17, 18, 19 |
| **#5 Unavailable After Recovery** | Automatic background sync with notifications | 5, 6, 8, 14, 15, 18 |
| **#6 Redirection Without Check** | Disable navigation/actions when offline | 10, 13 |
| **#7 Unavailable After Recovery** | Auto-reload screens when connectivity restored | 5 |

---

## Technology Stack

| Component | Package/Technology | Purpose |
|-----------|-------------------|---------|
| **Auth Token Storage** | `shared_preferences` | Store Firebase Auth token for offline app access |
| **Local Database** | `hive` + `hive_flutter` | Persistent storage for cache and sync queues |
| **Connectivity Detection** | `connectivity_plus` | Detect network state changes |
| **Background Sync** | `workmanager` (future) | Sync queued operations when app closed |
| **Image Caching** | `cached_network_image` | Already implemented ✅ |
| **Firebase Cache** | Firestore persistence (built-in) | Automatic offline Firestore cache |
| **BLE Communication** | `flutter_ble_peripheral` + `flutter_reactive_ble` | Already implemented ✅ |

---

**Document Version**: 1.2
**Last Updated**: October 30, 2025
**Total Scenarios**: 19 (Wishlist: 2, User Ranking: 2, Other: 15)
