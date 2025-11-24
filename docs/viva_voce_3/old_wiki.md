# Implemented Features
### Sprint 2
1. Use the phone’s **camera** so users can capture item photos directly from the app and attach them to new listings.
1. In the **search screen**, a query field and category chips let users quickly find items by keyword or topic.
1. On the **map/route view**, the app shows the **walking path to the pickup point inside campus**, guiding users to where the exchange happens.
1. A **smart checkout** step uses **Bluetooth** between buyer and seller to confirm the transaction when they meet.
1. **Login and register** screens with institutional email verification so only university members can create accounts and keep their session data.
1. A **home recommendations section** highlights products the user might like based on past clicks and category interactions.
1. **Firebase Firestore** persists users, posts, analytics events, and other app data used to list, filter, and locate items.
1. **Firebase Storage** hosts the images for product listings and user profiles.


### Sprint 3
1. Notification When a New Product is Posted (to the ones who most like thatcategory)
2. Smart auto-completion of create post using IA based on the image uploaded
3. Location in post so you know what posts where created near by
4. Wishlist implementation: users can now use this feature to save products they like.

# Implemented Business Questions

**Type 2: How can the app help users stay updated when new items are added to their favorite category?**

To answer this question, we implemented a real-time notification system using **Firebase Cloud Functions** and **Firebase Cloud Messaging (FCM)**.
Every time a new product document is created in the `posts` collection, a Cloud Function is automatically triggered. This function retrieves the product’s metadata —specifically its `category_name`, `title`, `description`, and `images`— and sends a push notification to all users subscribed to that category topic (e.g., `"furniture"`, `"bikes"`, `"books"`).

On the client side, the Android app registers the user’s **FCM token** and saves it under the `users` collection in Firestore. When users open the app, they are automatically subscribed to their **most viewed or favorite category**, ensuring that notifications remain relevant to their interests.

When a new post is published, the Cloud Function sends a structured payload containing the product title, category, short description, image, and the `postId`. The app’s `MyFirebaseMessagingService` intercepts this payload, builds a **high-priority heads-up notification** using `NotificationCompat` with `IMPORTANCE_HIGH`, and displays it immediately to the user. If the user taps on the notification, the app launches directly into the corresponding product detail screen, thanks to the `postId` included in the message data.

This question is classified as **Type 2** because it focuses on how user-facing mechanisms (notifications) can drive **behavioral engagement** and enhance user experience in real time:

* **For users:** ensures they stay informed about new items in categories they care about, improving perceived app usefulness and retention.
* **For product teams:** demonstrates how real-time updates can re-engage inactive users and encourage exploration of new listings.
* **For analytics:** establishes the foundation for tracking notification performance (delivery, open, and interaction rates) to evaluate communication effectiveness.

---

**Type 1: How many times and when does the app crash across different sessions and devices?**

To answer this question, we integrated Firebase Crashlytics with BigQuery to automatically collect and analyze crash data from our Android application. Crashlytics records every fatal exception with detailed metadata such as the timestamp, device model, app version, and session ID.

By linking Firebase to BigQuery, we created a dataset (firebase_crashlytics) that stores daily export tables (events_YYYYMMDD). Through SQL queries, we can aggregate the number of crashes per day, per device, and per app version, identifying when and how often crashes occur.

This integration allows us to:

Quantify the total number of crashes over time.

Detect patterns across different sessions and device models.

Monitor app stability and prioritize fixes based on affected users or versions.

Even if the first dataset was still synchronizing, the designed pipeline correctly establishes the data flow: Firebase → BigQuery → FastAPI analytics endpoint. Once Crashlytics exports the first event tables, our /crashlytics_summary endpoint will automatically generate aggregated crash reports in JSON format, providing actionable insights for reliability analysis.

---

**Type 3: What percentage of users utilize the wishlist/favorites feature, and how does it impact their purchase behavior?**

To answer this question, we built the `/wishlist_analytics` endpoint that measures how many users actually use the wishlist feature and whether it makes them more likely to buy stuff.

The endpoint pulls data from three places: `wish_list` (saved items), `sales` (completed purchases), and `start-time` (active users). It works across different time windows—7 days, 30 days, 6 months, or all time.

Here's what it does:

1. **Counts active users** in the selected period and splits them into two groups: those who saved items to wishlist and those who didn't.

2. **Calculates wishlist metrics** like how many people use it, how many items they save on average, and what percentage of active users engage with the feature.

3. **Tracks purchases** by matching user IDs from the `sales` collection against both groups, then calculates conversion rates for each.

4. **Measures impact** by comparing the two groups—showing how much more (or less) likely wishlist users are to complete purchases.

The results get cached in the `WishlistAnalytics` SQL table so we can track trends over time without hitting Firestore repeatedly.

This is **Type 3** because it directly connects a product feature to business results:

* **For product teams:** proves whether the wishlist feature actually drives purchases or is just clutter.
* **For marketing:** identifies high-intent users who can be targeted with "items you saved" reminders or special offers.
* **For business leaders:** shows clear ROI with a conversion lift metric—"wishlist users are X times more likely to buy."

Bottom line: this endpoint tells us if building and maintaining the wishlist feature is actually worth it, backed by real conversion data instead of assumptions.

---

**Type 2: What is the average time that products remain in a user's wishlist before being purchased?**

To answer this question, we created the `/wishlist_time_distribution` endpoint that tracks how long items sit in wishlists before users actually buy them.

The system matches wishlist items with completed sales by comparing `(user_id, product_id)` pairs, then calculates the time difference in hours between when something was added and when it was purchased.

Here's the process:

1. **Grabs wishlist items** from the `wish_list` collection with their addition timestamps.

2. **Finds matching purchases** in the `sales` collection (only completed ones), linking products to their buyers.

3. **Calculates waiting time** by subtracting the "added to wishlist" timestamp from the "purchased" timestamp.

4. **Groups results into hour buckets** using a practical rule: items bought in under an hour count as 1 hour, exactly at the same time counts as 0, and everything else rounds up (so 1.2 hours becomes 2 hours).

The response shows both the true average time and a distribution chart of how many products were purchased at each hour mark.

This is **Type 2** because it reveals **timing patterns in user behavior**:

* **For product teams:** shows whether wishlist is a "buy later" tool (days/weeks) or an "almost ready" queue (hours), guiding feature design.
* **For marketing:** reveals the optimal window to send "still interested?" notifications or price drop alerts.
* **For business planning:** helps predict when saved items will convert to sales, supporting inventory and revenue forecasting.

**Technical note:** Since Firestore doesn't support certain combined filters, we filter completed sales in the code rather than in the database query—works perfectly, just a workaround for database limitations.

---
**Type 4: What are the most searcged categories across majors measured by product clicks, and how could this aggregated data be leveraged for partnerships with bookstores or electronics retailers?**

To answer this question, we implemented an **analytics endpoint** that aggregates and analyzes category search behavior segmented by users’ academic majors. Every time a user searches or selects a category in the app, an event is recorded in the `product_search_events` collection in Firestore. Each event contains metadata such as `userId`, `selectedCategory`, `timestamp`, and —after the recent profile update— the user’s associated `major`.

On the backend, the `/top_categories_by_major` endpoint queries all events from Firestore within a defined time window (e.g., 7, 30 days, or all time) and groups them by `major` and `selectedCategory`. Using **pandas**, the system counts how many times each category was searched per major, identifies the **top three most searched categories** for each one, and stores the results in the SQL cache for efficient retrieval.

This question is categorized as **Type 4** because it connects user interaction data with **behavioral insights** that can guide strategic partnerships and improve user engagement:

* **For users:** helps the app surface more relevant listings or discounts aligned with their major.
* **For administrators or partners:** provides actionable intelligence for **targeted collaborations** with campus vendors (e.g., bookstores, tech shops).
* **For analytics teams:** establishes a framework for segment-based insights, revealing how academic backgrounds influence marketplace trends.

Through this implementation, the app transforms raw search data into meaningful behavioral patterns, bridging the gap between **user intent** and **data-driven partnership opportunities**.

---

**Type 2: How does seller rating impact the average time to sell an item?**


# Eventual Connectivity Strategies
## Kotlin

## Login Screen

### Login Without Internet Connection

| Aspect | The user tries to login wwithout Internet Connection |
|--------|-------------|
| **Event Description** | The user wants to log in but has no internet connection. |
| **System Response** | The system will display a message: "Internet connection required to log in. Please connect and try again." |
| **Possible Antipatterns** | #3 Non-informative message, #2 Stuck progress bar |
| **Caching + Retrieving Strategy** | N/A |
| **Storage Type** | N/A |
| **Stored Data Type** | N/A |
| **Rationale** | Firebase Authentication requires real-time server validation to verify user credentials and generate secure tokens, making an internet connection essential. To prevent user frustration from unsuccessful login attempts, the system promptly informs the user to try again when online. This clear messaging reduces confusion and ensures data security. Once logged in successfully, the session persists across app restarts even when offline. |

---

## Signup Screen

### Register Without Internet Connection

| Aspect | The user tries to sign up for the first time without internet connection |
|--------|-------------|
| **Event Description** | The user wants to create an account but has no internet connection. |
| **System Response** | The system will display a message: "Internet connection required to create account. Please connect and try again." |
| **Possible Antipatterns** | #3 Non-informative message |
| **Caching + Retrieving Strategy** | N/A |
| **Storage Type** | N/A |
| **Stored Data Type** | N/A |
| **Rationale** | Since sign-up is a one-time action that requires stable connection to authenticate and save user data securely in Firebase, it's essential that it occurs online. Without internet access, the system avoids caching any credentials to prevent incomplete or failed sign-up attempts. This approach ensures a smooth onboarding process when connectivity is available and maintains security standards. |


## Post Screen
Event Description | The user tries to create a new post but has no internet connection.
-- | --
System Response | The system saves the post as a local draft and shows a message confirming it was stored offline. Once the device reconnects to the internet, the app automatically uploads the pending post to Firestore.
Possible Antipatterns | #2 Silent Data Loss, #4 Lack of Offline Handling
Caching + Retrieving Strategy | Save the post data as a JSON draft file in local storage when offline, and automatically retrieve and upload it when connectivity is restored.
Storage Type | Local file storage (/files/draft_post.json)
Stored Data Type | Post metadata (title, description, price, category ID/name, image URIs)
Rationale | Creating a post requires network access to store data and upload images. To prevent data loss during offline conditions, the app caches the entire post locally and synchronizes it later when connectivity is detected. This ensures a seamless user experience and maintains data consistency without requiring manual re-entry.

## Chat Screen
Event Description | The user sends a message while being offline or with unstable internet.
-- | --
System Response | The message is temporarily stored in Firestore’s local cache and displayed immediately in the chat with the label “🕓 Sending…”. When connectivity is restored, Firestore automatically synchronizes the pending message with the server, and the message state updates to “✔ Sent” in real time.
Possible Antipatterns | #3 Non-Informative Message, #5 No Result Feedback
Caching + Retrieving Strategy | Network-first with Firestore’s built-in offline persistence. Messages are first written to the local cache and then synced to the cloud when available, with live updates provided via snapshot listeners.
Storage Type | Firestore local cache (persistent storage handled by the SDK).
Stored Data Type | Message content (content, sender_id, sent_at, read status).
Rationale | Chat communication requires real-time responsiveness even under intermittent connectivity. By leveraging Firestore’s local writes and metadata (hasPendingWrites), the app provides immediate visual feedback and automatically updates delivery status when the network returns — preventing confusion or silent failures and avoiding antipattern #3 (generic or missing feedback).

Event Description | The user opens a chat conversation for the first time while offline. Firestore has no cached messages, so the UI would normally appear empty.
-- | --
System Response | The app displays a friendly placeholder with a message (“You’re offline. Connect to load your messages.”) and an icon. Once online, messages automatically appear thanks to Firestore’s real-time listener.
Possible Antipatterns | #3 Non-Informative Message, #5 No Result Feedback
Caching + Retrieving Strategy | Firestore local persistence handles message caching after the first load; placeholder UI covers the initial uncached state.
Storage Type | Firestore cache (subcollection messages).
Rationale | Prevents confusion when no data is available by showing a clear, friendly visual state. Enhances offline UX without adding redundant retry buttons or breaking real-time synchronization.


## ChatList Screen

Event Description | The user opens the chat list for the first time while offline. Firestore has no cached conversations, resulting in an empty UI.
-- | --
System Response | Instead of showing a blank screen, the app now displays a friendly placeholder with a chat icon and a message: “No messages yet. Your conversations will appear here once you start chatting.” This gives visual feedback while maintaining layout structure.
Possible Antipatterns | #3 Non-Informative Message, #5 No Result Feedback
Caching + Retrieving Strategy | Firestore local persistence automatically caches chat documents once loaded online. If no cache exists, fallback UI placeholder is shown.
Storage Type | Firestore local cache (for chat summaries).
Rationale | The placeholder provides clear context to the user instead of an empty screen, preventing confusion and creating a polished, friendly offline experience.


## Home Screen
Event Description | The user loses internet while browsing the home feed.
-- | --
System Response | A snackbar informs “Connection lost. Showing saved posts.” The UI displays cached posts. When connectivity returns, another snackbar announces the refresh and the ViewModel pulls the latest data from Firestore.
Possible Antipatterns | #2 Silent Data Loss, #5 No Result Feedback
Caching + Retrieving Strategy | Persist the feed snapshot (active + recent posts) in `SharedPreferences`; on network failure fall back to that snapshot, and replace it after a successful fetch.
Storage Type | `SharedPreferences` (`posts_cache_storage`)
Stored Data Type | `PostEntity` list (id, title, description, price, images, pickup details, seller info).
Rationale | Keeps the feed usable offline and clearly communicates connectivity changes, preventing empty states or silent stale data.

## Product Detail Screen
Event Description | The user opens a previously viewed product detail without internet.
-- | --
System Response | The detail loads fully from the local cache (including seller name). Once the connection is back, the repository refreshes the Firestore data and overwrites the cached entry.
Possible Antipatterns | #4 Lack of Offline Handling, #5 No Result Feedback
Caching + Retrieving Strategy | Store each `PostEntity` detail (plus cached seller name) after every successful fetch and reuse it on errors or offline states.
Storage Type | `SharedPreferences` (`posts_cache_storage`)
Stored Data Type | Full `PostEntity` (copy, media, pricing, category, pickup info, sellerId) and seller display name.
Rationale | Guarantees the product view remains accessible and informative offline, while automatically reconciling with Firestore when connectivity returns.

Event Description | The user opens a product’s details while offline. The map section attempts to fetch location data from Google Directions API and fails silently, leaving the UI stuck on “Loading map…”.
-- | --
System Response | The screen now detects offline mode with NetworkUtils. If no connection is available, it shows a friendly placeholder (“No internet connection. Map unavailable.”) and disables the “Open in Google Maps” button until connectivity is restored.
Possible Antipatterns | #2 Silent Failure, #4 Unresponsive External Services
Caching + Retrieving Strategy | No map cache used — relies on online APIs. Offline fallback handled visually with placeholder and disabled interaction.
Storage Type | None (temporary network state check).
Rationale | Prevents confusion by clarifying why the map isn’t available and avoiding non-functional buttons. Improves resilience and user trust during offline states.

## Categories Screen
Event Description | The user opens the Categories screen without internet connection (or loses it while the list is loading).
-- | --
System Response | The screen shows a cached list of categories from FirestoreCategoriesRepository (stored locally). If no cache exists, it shows the built-in default categories with their local drawable icons. When internet returns and the user manually retries, the screen reloads categories from Firestore.
Possible Antipatterns | #1 Infinite Loading Spinner, #5 No Result Feedback
Caching + Retrieving Strategy | Use local cache from FirestoreCategoriesRepository, which stores the last successful snapshot in local storage (JSON / file). On offline start, categories are loaded from that cache; when a new fetch succeeds, the cache is overwritten.
Storage Type | Local JSON file or SharedPreferences (inside FirestoreCategoriesRepository)
Stored Data Type | CategoryEntity list (id, name, icon) — icons resolved locally from drawable names (ic_books, ic_bikes, etc.)
Rationale | Allows the Categories screen to remain functional offline using previously fetched data, preventing empty states or app crashes when Firestore is unreachable.

## Products Screen
Event Description | The user searches for items from the categories screen while offline.
-- | --
System Response | The app relies on the cached post list to filter and present results locally. When the network recovers, subsequent searches hit Firestore again.
Possible Antipatterns | #3 Non-Informative Message, #4 Lack of Offline Handling
Caching + Retrieving Strategy | Share the home feed cache (active/new posts) and perform client-side filtering whenever remote queries fail.
Storage Type | `SharedPreferences` (`posts_cache_storage`)
Stored Data Type | Cached `PostEntity` list with all fields required for search and display.
Rationale | Prevents empty or broken search results during outages and reuses already downloaded data to maintain continuity.

## Profile Screen
Event Description | The user opens the profile screen for the first time without an internet connection. Since the user’s data has never been loaded before, Firestore has no cached document to display.
-- | --
System Response | The app detects the connectivity issue and shows a friendly message: “You’re offline. Connect to the internet to load your profile.” It also displays a “Retry” button that lets the user try again once connectivity is restored. When the device reconnects, pressing Retry triggers a new Firestore fetch and loads the profile normally.
Possible Antipatterns | #1 Blocked App (frozen loading), #3 Non-Informative Message (technical error), #5 No Result Feedback (no visible action after failure)
Caching + Retrieving Strategy | Network-only first access, with a fallback offline UI. Firestore will automatically cache the data once successfully loaded, enabling future offline access.
Storage Type | Firestore built-in local persistence (automatically enabled by SDK).
Stored Data Type | User profile document (name, email, photoUrl, major, role, products).
Rationale | On first launch, there’s no cached data available. Instead of showing a technical Firebase error, the app informs the user clearly and provides a simple action (“Retry”) to recover once connectivity returns. This ensures transparency, prevents confusion, and avoids the blocked or broken experience typical of antipattern #1 and #3.

Event Description | The user opens the profile screen while offline. Firestore successfully loads cached product data, but some product images cannot be retrieved because they were never downloaded or cached by Coil.
-- | --
System Response | The app displays all text-based information (name, role, major, and product titles) instantly from Firestore’s local cache. For images that are unavailable, a visual placeholder (ic_placeholder) is shown instead of leaving blank or broken spaces. When the device reconnects, Coil automatically loads and replaces the placeholders with the actual images.
Possible Antipatterns | #4 Lost Content, #5 No Result Feedback
Caching + Retrieving Strategy | Firestore local persistence for structured data, combined with Coil’s automatic memory/disk cache for images and placeholder fallback for missing resources.
Storage Type | Firestore built-in cache + Coil memory/disk cache for images.
Stored Data Type | User data (name, email, major, etc.) and product metadata (title, price, imageUrl references).
Rationale | Even under offline conditions, the UI remains consistent and informative. By displaying a default placeholder image, the system avoids the “Lost Content” antipattern and preserves layout stability. This creates a smoother offline experience while ensuring visual feedback and preventing broken UI elements.

## Edit Profile Screen

Event Description | The user edits their profile and tries to save changes while offline. Firestore cannot be reached, so the app would normally remain stuck in a loading state.
-- | --
System Response | Before sending the update request, the app checks for network availability. If no connection is detected, it cancels the operation immediately and shows a friendly message — “No internet connection. Try again when you're online.” The loading spinner stops automatically, and the user can tap Save Changes again once connectivity is restored.
Possible Antipatterns | #1 Blocked App, #3 Non-Informative Message
Caching + Retrieving Strategy | Network-first approach with offline validation before writes. The update is only sent when an active internet connection is confirmed.
Storage Type | Firestore (remote write only; no local cache needed for profile updates).
Rationale | This design prevents the user interface from freezing due to network loss. By providing clear, human-readable feedback and allowing reattempts via the existing “Save Changes” button, the app stays responsive, transparent, and avoids user frustration.

## Sales Screen

Event Description | The user opens the sales tab while offline.
-- | --
System Response | The UI shows "Connection lost. Showing saved sales." via snackbar and displays cached sales immediately. When connectivity is restored, another snackbar announces "Connection restored. Searching for new sales..." and the ViewModel automatically refreshes from Firestore.
Possible Antipatterns | #2 Silent Data Loss, #4 Lack of Offline Handling, #5 No Result Feedback
Caching + Retrieving Strategy | Persist sales list snapshots per user (`userId`) in `SharedPreferences`; when offline, serve from memory LRU first, then fall back to persisted JSON. After successful online fetches, update both layers.
Storage Type | `SharedPreferences` (`sales_cache_storage`)
Stored Data Type | `SaleEntity` list (id, buyer/seller IDs, postId, price, status, dates, post title/images, buyer name/email)
Rationale | Sellers need to track sales even offline. Caching per-user ensures historical data remains available and actions like marking items as shipped can be viewed locally; automatic refresh keeps data current when the connection returns.

---


## Flutter

## Login Screen

### Scenario 1: Login Without Internet Connection

| Aspect | Description |
|--------|-------------|
| **Event Description** | The user wants to log in but has no internet connection. |
| **System Response** | The system will display a message: "Internet connection required to log in. Please connect and try again." Login button is disabled. |
| **Possible Antipatterns** | #3 Non-informative message, #2 Stuck progress bar |
| **Caching + Retrieving Strategy** | N/A |
| **Storage Type** | N/A |
| **Stored Data Type** | N/A |
| **Rationale** | Firebase Authentication requires real-time server validation to verify user credentials and generate secure tokens, making an internet connection essential. To prevent user frustration from unsuccessful login attempts, the system promptly informs the user to try again when online. This clear messaging reduces confusion and ensures data security. Once logged in successfully, the session persists across app restarts even when offline. |

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
| **Storage Type** | 2. Local database (Hive) with sync queue |
| **Stored Data Type** | WishlistItem Documents (userId, postId, addedAt, syncStatus: pending/synced), SyncQueue (operationId, type: wishlist_add/wishlist_remove, payload: {postId}, retryCount) |
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

# Local Storage Strategy
What is saved? | Why is it saved? | Where is it saved?
-- | -- | --
Draft posts (title, description, price, category, and image URIs) | To prevent data loss when users create a post without internet connection, allowing automatic upload once connectivity is restored. | Local file storage as a JSON file (/data/data/com.example.team_23_kotlin/files/draft_post.json)
Recent search queries entered in the search bar | To improve user experience by showing quick suggestions and letting users re-access previous searches easily. | SharedPreferences under a key like "recent_searches"
Logged-in user profile (uid, email, display name, photo URL, verification flag) | Keep the session active and reuse basic data without depending on the network at every app launch. | SharedPreferences `user_session_prefs` managed by `UserSessionStorage`

## Kotlin
In **Mercandes**, a lightweight **local file storage** strategy is used to save post drafts when the user attempts to create a post without an internet connection. This ensures that all post data — including title, description, price, category, and image URIs — is safely preserved and later synchronized automatically once connectivity is restored.

The implementation centers around the `PostViewModel`, which defines two main functions: `saveDraftLocally(context)` and `syncDraftIfNeeded(context)`.

* **`saveDraftLocally`** serializes the current `PostState` into a JSON object and writes it to a file in the app’s internal storage.
* **`syncDraftIfNeeded`** checks if the file exists and the device has regained connection; if both conditions are met, it reads and uploads the draft post to Firestore before deleting the file.

```kotlin
private fun saveDraftLocally(context: Context) {
    val s = _state.value
    val json = JSONObject().apply {
        put("title", s.title)
        put("description", s.description)
        put("price", s.price)
        put("categoryId", s.categoryId ?: "")
        put("categoryName", s.categoryName ?: "")
        put("photoTokens", s.photoTokens.joinToString(","))
    }
    val file = File(context.applicationContext.filesDir, "draft_post.json")
    file.writeText(json.toString())
    Log.d("LocalStorage", "Draft saved at: ${file.absolutePath}")
}
```

When connectivity is detected again, the draft file is automatically uploaded using:

```kotlin
fun syncDraftIfNeeded(context: Context) {
    val file = File(context.applicationContext.filesDir, "draft_post.json")
    if (!file.exists() || !isOnline(context)) return
    val json = JSONObject(file.readText())
    val post = Post(
        title = json.optString("title"),
        description = json.optString("description"),
        price = json.optString("price").toLong(),
        category = FirebaseFirestore.getInstance().document("/categories/${json.optString("categoryId")}")
    )
    repository.createPost(post, emptyList())
    file.delete()
}
```

The draft file (`draft_post.json`) is stored in the app’s **internal storage directory** (`/data/data/com.example.team_23_kotlin/files/`), ensuring security and privacy since only the app can access it. JSON serialization allows flexible handling of structured data like lists and text fields without needing a full local database.

A **local file** was chosen over alternatives because the data volume is small and temporary, and the goal is resilience rather than persistence. This design ensures that even in offline conditions, users never lose progress when creating posts, reinforcing trust and continuity in the marketplace experience.

----

## Session Storage Strategy

In **Mercandes** we rely on a lightweight **SharedPreferences-based storage** to persist the signed-in user after a successful login. This lets the app restore the session and jump straight into Home even if it restarts without connectivity.

### Key Components

- **`UserSessionStorage`** encapsulates persistence duties. It exposes `save`, `get`, and `clear`, and logs every operation to Logcat so the flow can be verified quickly during development.
- **`LoginAuthViewModel`** governs the session lifecycle: it keeps the user only when the email is verified, clears the data otherwise, and logs that the user has been stored locally.

```24:34:app/src/main/java/com/example/team_23_kotlin/data/local/UserSessionStorage.kt
fun save(user: StoredUser) {
    prefs.edit()
        .putString(KEY_UID, user.uid)
        .putString(KEY_EMAIL, user.email)
        .putString(KEY_DISPLAY_NAME, user.displayName)
        .putString(KEY_PHOTO_URL, user.photoUrl)
        .putBoolean(KEY_IS_EMAIL_VERIFIED, user.isEmailVerified)
        .apply()
    Log.d(TAG, "Sesión guardada para uid=${user.uid}, email=${user.email}")
}
```

```53:61:app/src/main/java/com/example/team_23_kotlin/presentation/auth/LoginAuthViewModel.kt
userSessionStorage.save(
    StoredUser(
        uid = user.uid,
        email = user.email,
        displayName = user.displayName,
        photoUrl = user.photoUrl?.toString(),
        isEmailVerified = user.isEmailVerified
    )
)
Log.d(TAG, "Usuario persistido localmente con uid=${user.uid}")
```

### Data Scope & Location

- **What we store:** `uid`, email, display name, photo URL, and the email-verification flag.
- **Where it lives:** the `SharedPreferences` file named `user_session_prefs`, under the app’s internal directory (`/data/data/com.example.team_23_kotlin/shared_prefs/` on a device).
- **Why SharedPreferences:** the payload is tiny, requires instant and secure access, and must survive app restarts without needing a full database.

With this setup, the session is rehydrated on app launch, log statements confirm the status, and the marketplace experience remains smooth even when offline.


## Flutter

Campus Marketplace relies on Hive for structured persistence, orchestrated by `LocalStorageService`, which opens dedicated boxes for posts, chats, users, categories, and the sync queue as soon as the app boots. `CacheService` builds on top of that layer to add TTL metadata and domain-specific helpers so every write includes a timestamp and can expire gracefully.

- **Feed & catalogs.** Network responses are serialized and stored with timestamps, while single posts are cached individually for later reuse.

```20:43:lib/services/cache_service.dart
Future<void> cachePosts(List<Map<String, dynamic>> posts) async {
  final cacheData = {
    'data': posts,
    'timestamp': DateTime.now().toIso8601String(),
  };

  await _storage.save(
    LocalStorageService.postsBoxName,
    'all_posts',
    jsonEncode(cacheData),
  );

  for (final post in posts) {
    await _cacheSinglePostMap(post);
  }
}
```

- **Prefetch bootstrap.** At startup, `PrefetchService` fans out multiple asynchronous fetches and persists the results—plus the first image of each post—so the home experience works offline.

```66:98:lib/services/prefetch_service.dart
final posts = await _postRepository.getNewPosts();
await _cache.cachePosts(posts.map((p) => p.toJson()).toList());
await _preCachePostImages(posts, 'new posts');
```

- **Chats & queue.** `ChatService` mirrors every Firestore stream into Hive and creates temporary chat records when the device is offline. `SyncQueueService` keeps write operations (messages today, other mutations later) in the `sync_queue` box with retry counters so they survive restarts.

```316:369:lib/services/chat_service.dart
return _db.collection('chats')
    .doc(chatId)
    .collection('messages')
    .orderBy('sent_at', descending: true)
    .limit(100)
    .snapshots()
    .asyncMap((snapshot) async {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['_id'] = doc.id;
        return ChatMessage.fromJson(data);
      }).toList();

      final messagesJson = messages.map((m) => {
        'id': m.id,
        'sender_id': m.senderId,
        'content': m.content,
        'image': m.image,
        'sent_at': m.sentAt.toIso8601String(),
        'read': m.read,
      }).toList();
      await _cache.cacheChatMessages(chatId, messagesJson);
      return messages;
    });
```

- **Session snapshots.** Whenever profile data is pulled, `CacheService.cacheUser` writes a JSON payload into the `user` box with a seven-day TTL, letting profile and chat views rehydrate instantly when the app starts offline.

```211:244:lib/services/cache_service.dart
await _storage.save(
  LocalStorageService.userBoxName,
  'user_$userId',
  jsonEncode(cacheData),
);
```

Together these pieces keep the Flutter client usable without connectivity while avoiding stale data through predictable expirations and background refreshes.

# Multi-threading/concurrency strategy
## Kotlin

The Kotlin app uses **two concurrency strategies** — **multithreading** and **coroutines**.
Coroutines are lightweight blocks of code that can run concurrently, allowing asynchronous execution without blocking the main thread. Unlike traditional threads, coroutines are **not bound to any specific thread**, which means they can be **suspended** and **resumed** on different threads as needed.

Android’s coroutine framework provides three main thread contexts (dispatchers) where coroutines can be executed:

* **Main:** handles UI updates and user interactions.
* **IO:** optimized for network calls, file operations, or database access.
* **Default:** used for CPU-intensive or long-running tasks.

By switching between these contexts using the `Dispatchers` class (e.g., `Dispatchers.Main`, `Dispatchers.IO`), the app can perform heavy or blocking operations in background threads while keeping the UI thread responsive. This combination of **structured concurrency** and **thread-based parallelism** allows the application to **maximize performance, prevent ANRs (Application Not Responding)**, and maintain a smooth user experience.

In the following image, the `startAsServer` function creates a **manual thread** using the `Thread` class to handle Bluetooth connections in the background.
This prevents the blocking operation `serverSocket.accept()` from freezing the main thread while it waits for an incoming connection.

```kotlin
override suspend fun startAsServer(): Result<Unit> = suspendCancellableCoroutine { continuation ->
    Thread {
        try {
            _bluetoothState.value = BluetoothState.CONNECTING
            serverSocket = bluetoothAdapter?.listenUsingRfcommWithServiceRecord(SERVICE_NAME, APP_UUID)
            val socket = serverSocket?.accept() // blocking operation
            socket?.let {
                connectedSocket = it
                _bluetoothState.value = BluetoothState.CONNECTED
                startMessageListener(it)
                continuation.resume(Result.success(Unit))
            }
        } catch (e: IOException) {
            continuation.resume(Result.failure(e))
        }
    }.start()
}
```

This implementation uses **multithreading** explicitly to separate the Bluetooth connection logic from the main UI thread, ensuring the app remains responsive while the socket waits for a peer device.

In the following image, the `getCurrentLocation` function uses a **suspending coroutine** via `suspendCancellableCoroutine` to obtain the user’s location asynchronously.
This allows the function to wait for the Google Play Services callback without blocking the current thread.

```kotlin
@SuppressLint("MissingPermission")
override suspend fun getCurrentLocation(): Location? = suspendCancellableCoroutine { cont ->
    fusedLocationClient.lastLocation
        .addOnSuccessListener { location ->
            cont.resume(location)
        }
        .addOnFailureListener {
            cont.resume(null)
        }
}
```

Here, the coroutine is **suspended** while the system retrieves the GPS data on a separate thread.
Once the result is ready, the coroutine **resumes automatically**, continuing execution on the original dispatcher (usually the Main thread).

In the following image, the `loadChat` function uses the **`viewModelScope.launch`** builder to start a coroutine.
The coroutine performs multiple Firestore network calls asynchronously using `.await()`, which suspends execution without blocking.

```kotlin
fun loadChat(chatId: String) {
    viewModelScope.launch {
        _state.value = _state.value.copy(isLoading = true)

        val chatDoc = firestore.collection("chats").document(chatId).get().await()
        val peerDoc = firestore.collection("users").document(peerId).get().await()
        val productDoc = firestore.collection("posts").document(productId).get().await()

        _state.value = _state.value.copy(isLoading = false)
    }
}
```

All these coroutines are **tied to the lifecycle of the ViewModel** through `viewModelScope`, which ensures that they are automatically cancelled when the ViewModel is cleared — preventing memory leaks and unnecessary background work.

In the following image, the `listenToMessages` function sets up a **real-time listener** using Firestore’s asynchronous callback API.
This function runs concurrently with other app operations, updating the chat UI whenever new messages arrive.

```kotlin
private fun listenToMessages(chatId: String) {
    firestore.collection("chats")
        .document(chatId)
        .collection("messages")
        .orderBy("sent_at")
        .addSnapshotListener { snapshot, e ->
            val messages = snapshot?.documents?.map { ... } ?: emptyList()
            _state.value = _state.value.copy(messages = messages)
        }
}
```

This demonstrates **reactive concurrency**, where external data changes (from Firestore) trigger UI updates without manual thread management.



## Flutter

The Flutter client leans on Dart's cooperative concurrency model—`Future`s, Streams, and broadcast controllers—instead of spawning platform threads. That keeps the UI thread responsive while background work (prefetching, sync, listeners) runs asynchronously.

## Futures and coordinated tasks

`PrefetchService.prefetchAll` launches six asynchronous fetches in parallel via `Future.wait`. Guard flags (`_isPrefetching`, `_isPrefetched`) ensure only one run happens at a time, and each helper awaits its work so the cache is consistent before the method returns.

```36:64:lib/services/prefetch_service.dart
_isPrefetching = true;
try {
  await Future.wait([
    _prefetchNewPosts(),
    _prefetchRecommendedProducts(),
    _prefetchMajorBasedProducts(),
    _prefetchWishList(),
    _prefetchUserPosts(),
    _prefetchCategories(),
  ]);
  _isPrefetched = true;
} finally {
  _isPrefetching = false;
}
```

## Streams and event fan-out

`ConnectivityService` exposes a broadcast stream so multiple layers (UI, sync queues, view models) can react to network changes without contention. The `waitForConnection` utility uses a `Completer` and cancels its subscription once the first online event arrives or the timeout expires.

```12:112:lib/services/connectivity_service.dart
final StreamController<ConnectivityResult> _connectivityStreamController =
    StreamController<ConnectivityResult>.broadcast();

_connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
  final newStatus = results.first;
  _currentStatus = newStatus;
  _connectivityStreamController.add(newStatus);
});

Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
  if (isConnected) return true;
  final completer = Completer<bool>();
  StreamSubscription<ConnectivityResult>? subscription;

  subscription = onConnectivityChanged.listen((result) {
    if (result != ConnectivityResult.none && !completer.isCompleted) {
      completer.complete(true);
      subscription?.cancel();
    }
  });
  // timeout wiring omitted
  return completer.future;
}
```

## Real-time observers and cache refresh

`ChatService.streamChatMessages` maintains a per-chat broadcast controller when offline and falls back to Firestore's live stream when online. The `asyncMap` stage allows heavy work (JSON mapping, cache writes) without blocking the UI thread.

```316:369:lib/services/chat_service.dart
return _db.collection('chats')
    .doc(chatId)
    .collection('messages')
    .orderBy('sent_at', descending: true)
    .limit(100)
    .snapshots()
    .asyncMap((snapshot) async {
      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['_id'] = doc.id;
        return ChatMessage.fromJson(data);
      }).toList();

      final messagesJson = messages.map((m) => {
        'id': m.id,
        'sender_id': m.senderId,
        'content': m.content,
        'image': m.image,
        'sent_at': m.sentAt.toIso8601String(),
        'read': m.read,
      }).toList();
      await _cache.cacheChatMessages(chatId, messagesJson);
      return messages;
    });
```

## Offline queue processing

`SyncQueueService` coordinates queued mutations using `async/await`. A simple `_isSyncing` guard prevents overlapping runs, and retries happen sequentially so backoff and error logging remain deterministic.

```22:174:lib/services/sync_queue_service.dart
Future<void> _syncQueue() async {
  if (_isSyncing) return;
  if (!_connectivity.isConnected) return;

  _isSyncing = true;
  try {
    final pendingItems = await getPendingItems();
    for (final item in pendingItems) {
      await _syncItem(item);
    }
  } finally {
    _isSyncing = false;
  }
}
```

These patterns provide controlled concurrency without resorting to platform threads, keeping UI interactions smooth while background work progresses.


# Caching Strategy
## Kotlin

We implemented a **two-layer cache** for posts to guarantee fast UI responses and reliable offline support:

- **Layer 1 – In-Memory LRU (`PostsMemoryCache`)**  
  Uses `android.util.LruCache` to retain:
  - recent post lists (`listsCache`, capacity 6 entries, size based on list length),
  - individual post details (`detailsCache`, 32 entries),
  - seller names (`userNamesCache`, 32 entries).  
  Whenever a fresh list arrives, we push it into the list cache and also pre-fill the detail cache with every item.

  ```kotlin
  // app/src/main/java/com/example/team_23_kotlin/data/local/PostsMemoryCache.kt
  class PostsMemoryCache(
      postsMaxEntries: Int = 6,
      detailsMaxEntries: Int = 32,
      userNamesMaxEntries: Int = 32
  ) {
      private val listsCache = object : LruCache<String, List<PostEntity>>(postsMaxEntries) {
          override fun sizeOf(key: String, value: List<PostEntity>) = value.size.coerceAtLeast(1)
      }
      private val detailsCache = object : LruCache<String, PostEntity>(detailsMaxEntries) {
          override fun sizeOf(key: String, value: PostEntity) = 1
      }
      private val userNamesCache = object : LruCache<String, String>(userNamesMaxEntries) {
          override fun sizeOf(key: String, value: String) = 1
      }

      fun putList(key: String, posts: List<PostEntity>) {
          listsCache.put(key, posts)
          posts.forEach { putDetail(it) }
      }

      fun getList(key: String): List<PostEntity>? = listsCache.get(key)
      fun putDetail(post: PostEntity) = detailsCache.put(post.id, post)
      fun getDetail(id: String): PostEntity? = detailsCache.get(id)
      fun putUserName(userId: String, name: String) = userNamesCache.put(userId, name)
      fun getUserName(userId: String): String? = userNamesCache.get(userId)
  }
  ```

- **Layer 2 – Persistent Storage (`PostsCacheStorage`)**  
  Serializes every list and detail as JSON inside dedicated `SharedPreferences`. This makes snapshots survive app restarts and act as the offline source of truth when the device boots without internet.

- **Repository Integration (`FirestorePostsRepository`)**  
  Each repository method chooses the data source dynamically:
  1. If `isOnline()` reports `false`, it returns the hottest copy in the LRU, and if that’s empty, the persisted JSON.
  2. If online, it forces a `Source.SERVER` fetch (bypassing Firestore’s built-in cache), updates both layers, and hands the data to the UI.
  3. Searches are also cached per query (`search_<lowercaseQuery>`), so repeated offline searches remain instant.

  ```kotlin
  // app/src/main/java/com/example/team_23_kotlin/data/posts/FirestorePostsRepository.kt
  override suspend fun getActivePosts(limit: Int): List<PostEntity> {
      if (isOnline?.invoke() == false) {
          memoryCache?.getList(CACHE_KEY_ACTIVE)?.take(limit)?.takeIf { it.isNotEmpty() }?.let { return it }
          return cache?.loadPosts(CACHE_KEY_ACTIVE)?.take(limit)
              ?: cache?.loadPosts(CACHE_KEY_NEW)?.take(limit)
              ?: emptyList()
      }

      val snapshot = db.collection("posts")
          .whereEqualTo("status", "active")
          .limit(limit.toLong())
          .get(Source.SERVER)
          .await()

      val posts = snapshot.documents.map { mapToEntity(it) }
      cache?.savePosts(CACHE_KEY_ACTIVE, posts)
      memoryCache?.putList(CACHE_KEY_ACTIVE, posts)
      return posts
  }
  ```
---
## Caching Strategy for Sales

Two-layer cache for sales for fast UI and reliable offline support:

- **Layer 1 – In-Memory LRU (`SalesMemoryCache`)**  
  Uses `android.util.LruCache` to keep:
  - sales lists per user (`salesCache`, capacity 10 entries, size based on list length),
  - individual sale details (`detailsCache`, 32 entries).  
  When a fresh list arrives, it’s added to the list cache and all items are pre-filled into the detail cache.

  ```kotlin
  // app/src/main/java/com/example/team_23_kotlin/data/local/SalesMemoryCache.kt
  class SalesMemoryCache(
      salesMaxEntries: Int = 10,
      detailsMaxEntries: Int = 32
  ) {
      private val salesCache = object : LruCache<String, List<SaleEntity>>(salesMaxEntries) {
          override fun sizeOf(key: String, value: List<SaleEntity>): Int = value.size.coerceAtLeast(1)
      }
      private val detailsCache = object : LruCache<String, SaleEntity>(detailsMaxEntries) {
          override fun sizeOf(key: String, value: SaleEntity): Int = 1
      }

      fun putSales(userId: String, sales: List<SaleEntity>) {
          salesCache.put(userId, sales)
          sales.forEach { putDetail(it) }
      }

      fun getSales(userId: String): List<SaleEntity>? = salesCache.get(userId)
      fun putDetail(sale: SaleEntity) = detailsCache.put(sale.id, sale)
      fun getDetail(id: String): SaleEntity? = detailsCache.get(id)
  }
  ```

- **Layer 2 – Persistent Storage (`SalesCacheStorage`)**  
  Serializes every sales list and detail as JSON inside `SharedPreferences`, keyed by `userId`. This persists snapshots across app restarts and serves as the offline source when the device boots without internet.

- **Repository Integration (`FirestoreSalesRepository`)**  
  Each repository method chooses the source dynamically:
  1. If `isOnline()` reports `false`, it returns the hottest copy from the LRU (per user), then falls back to persisted JSON.
  2. If online, it forces a `Source.SERVER` fetch (bypassing Firestore’s built-in cache), updates both layers, and returns the data to the UI.
  3. Individual sale details (`getSaleById`) follow the same pattern: check LRU first, then disk, and update both after successful fetches.

  ```kotlin
  // app/src/main/java/com/example/team_23_kotlin/data/sales/FirestoreSalesRepository.kt
  override suspend fun getSalesBySeller(userId: String, limit: Int): List<SaleEntity> {
      if (isOnline?.invoke() == false) {
          memoryCache?.getSales(userId)?.take(limit)?.takeIf { it.isNotEmpty() }?.let { return it }
          return cache?.loadSales(userId)?.take(limit) ?: emptyList()
      }

      val salesSnapshot = db.collection(COLLECTION_SALES)
          .whereEqualTo("seller_ref", db.document("users/$userId"))
          .orderBy("created_at", Query.Direction.DESCENDING)
          .limit(limit.toLong())
          .get(Source.SERVER)
          .await()

      val sales = salesSnapshot.documents.mapNotNull { mapToSaleEntity(it) }
      cache?.saveSales(userId, sales)
      memoryCache?.putSales(userId, sales)
      return sales
  }
  ```

**Differences from Posts cache:**
- Sales cache is **user-scoped** (each seller has their own cache key), ensuring privacy and preventing data leakage between users.

## Flutter

Flutter centralizes caching in `CacheService`, which wraps Hive boxes opened by `LocalStorageService` and tags each payload with a timestamp-driven TTL. That gives the app a single entry point for storing and expiring posts, chats, categories, users, and wish lists.

- **TTL policy.** Different domains get tailored lifetimes (7 days for posts, 30 days for categories and messages) so data stays fresh without wasting bandwidth.

```14:19:lib/services/cache_service.dart
static const Duration postsCacheDuration = Duration(days: 7);
static const Duration categoriesCacheDuration = Duration(days: 30);
static const Duration userCacheDuration = Duration(days: 7);
static const Duration messagesCacheDuration = Duration(days: 30);
```

- **Network-first with fallback.** Reads try Firestore first and fall back to Hive when offline, while writes immediately update the cache. For example, post fetches persist both the collection and each individual post so detail screens open instantly.

```125:164:lib/services/cache_service.dart
await _storage.save(
  LocalStorageService.postsBoxName,
  'post_$postId',
  jsonEncode(cacheData),
);

final cached = _storage.get(
  LocalStorageService.postsBoxName,
  'post_$postId',
);
```

- **Prefetch & images.** `PrefetchService` runs in the background to hydrate caches ahead of time and calls `ImageCacheService` so hero images are available offline.

```179:207:lib/services/prefetch_service.dart
await _preCachePostImages(posts, 'new posts');
```

- **Chats & wish list.** Conversations, chat metadata, wish list entries, and the offline sync queue all live in dedicated Hive boxes (`messages`, `posts`, `sync_queue`), ensuring users can continue workflows even without connectivity.

```596:638:lib/services/cache_service.dart
await _storage.save(
  LocalStorageService.messagesBoxName,
  'user_chats',
  jsonEncode(cacheData),
);
```

By combining eager prefetch, granular TTLs, and per-feature boxes, the Flutter client keeps critical views responsive while still refreshing data as soon as the network returns.

# Ethics Video

[Video Here](https://uniandes-my.sharepoint.com/:v:/g/personal/n_casasi_uniandes_edu_co/EXHUXJystwNBrGxuNu-F27QB9AMRde0Go6ocan3GjyY3Ng?nav=eyJyZWZlcnJhbEluZm8iOnsicmVmZXJyYWxBcHAiOiJPbmVEcml2ZUZvckJ1c2luZXNzIiwicmVmZXJyYWxBcHBQbGF0Zm9ybSI6IldlYiIsInJlZmVycmFsTW9kZSI6InZpZXciLCJyZWZlcnJhbFZpZXciOiJNeUZpbGVzTGlua0NvcHkifX0&e=aCScIx)

# APKs
[APKs Here](https://uniandes-my.sharepoint.com/:f:/g/personal/s_navarretev_uniandes_edu_co/Eo3y7B_LphhAkjNuv7UPUJcB1ysOF1DgeAkYXWSoFz9LPQ?e=nrX80E)