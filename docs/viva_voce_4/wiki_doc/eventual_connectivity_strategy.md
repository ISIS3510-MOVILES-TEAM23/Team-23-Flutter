# Eventual Connectivity Strategies

## Flutter

## Product Detail Screen

### Scenario: View Similar Hot Products Without Internet

| Aspect | Description |
|---|---|
| **Event Description** | The user scrolls down to "Similar products that're hot" section but has no internet connection. |
| **System Response** | The system displays similar products using the last locally saved raw data (posts, clicks, sales) with a "Cached" badge next to the section title. Products are sorted by hotness calculated offline. |
| **Possible Antipatterns** | #4 Lost content, #3 Non-informative message |
| **Caching + Retrieving Strategy** | #3 Network falling back to cache, #1 Cache falling back to network |
| **Storage Type** | 2. Local database (Hive) + 1.e. Firestore cache |
| **Stored Data Type** | Raw Post Documents, raw Product Click Events, raw Sales Data |
| **Rationale** | "Hotness" is a dynamic metric based on engagement. Instead of caching a static list which becomes stale quickly, we cache the raw signals (clicks and sales) and the product pool. This allows the app to recalculate and resort the "Hot" list locally even when offline, ensuring the recommendation logic remains consistent and up-to-date with available data. A discrete "Cached" badge informs the user of the data source without blocking interaction. |

