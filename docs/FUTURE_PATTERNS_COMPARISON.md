# Future Patterns Comparison: async/await vs .then()/.catchError()

**Created**: October 30, 2025
**File**: `lib/view_models/notification_view_model.dart`

---

## Overview

This document explains the two different patterns for handling asynchronous operations (Futures) in Dart/Flutter, as demonstrated in the `NotificationViewModel` class.

---

## 📚 Two Patterns Demonstrated

### Pattern 1: **ASYNC/AWAIT** (Method: `markAsRead()`)
### Pattern 2: **FUTURE HANDLERS** (Method: `markAllAsRead()`)

---

## Pattern 1: ASYNC/AWAIT ✨

### Code Example
```dart
/// Marca una notificación como leída
/// 
/// **PATTERN 1: ASYNC/AWAIT**
/// - Clean, sequential code
/// - Easy to read and maintain
/// - Modern Dart/Flutter approach
Future<void> markAsRead(String notificationId) async {
  try {
    debugPrint('📝 [ASYNC/AWAIT] Marking notification as read: $notificationId');
    
    final success = await _repository.markAsRead(notificationId);
    
    if (success) {
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
      debugPrint('✅ [ASYNC/AWAIT] Notification marked as read successfully');
    } else {
      debugPrint('⚠️ [ASYNC/AWAIT] Failed to mark notification as read');
    }
  } catch (e, stackTrace) {
    debugPrint('❌ [ASYNC/AWAIT] Error marking notification as read: $e');
    debugPrint('Stack trace: $stackTrace');
    // Could rethrow or handle gracefully
  }
}
```

### Characteristics

| Aspect | Description |
|--------|-------------|
| **Syntax** | Uses `async` keyword on method, `await` on Future calls |
| **Error Handling** | Try-catch blocks (standard exception handling) |
| **Readability** | ⭐⭐⭐⭐⭐ Looks like synchronous code |
| **Debugging** | ⭐⭐⭐⭐⭐ Easy to step through |
| **Use Case** | **Default choice** for most Flutter code |

### Advantages ✅
- **Readable**: Code flows top-to-bottom like synchronous code
- **Familiar**: Developers from other languages understand it easily
- **Debuggable**: Step through code line-by-line in debugger
- **Error handling**: Standard try-catch is intuitive
- **Modern**: Recommended by Dart/Flutter style guide

### Disadvantages ❌
- Requires `async` keyword (function must be marked async)
- Cannot use outside of async functions
- Slightly different semantics than Promise chains (JS developers)

---

## Pattern 2: FUTURE HANDLERS (.then() / .catchError()) 🔗

### Code Example
```dart
/// Marca todas las notificaciones como leídas
/// 
/// **PATTERN 2: FUTURE WITH HANDLERS (.then() / .catchError())**
/// - Functional programming style
/// - Explicit success/error callbacks
/// - Good for chaining multiple operations
/// - Alternative to async/await
Future<void> markAllAsRead() {
  final ids = _notifications.map((n) => n.id).toList();
  
  debugPrint('📝 [FUTURE HANDLERS] Marking ${ids.length} notifications as read...');
  
  return _repository.markAllAsRead(ids)
      .then((success) {
        // SUCCESS HANDLER (.then)
        debugPrint('✅ [FUTURE HANDLERS] .then() called - Success: $success');
        
        if (success) {
          _notifications.clear();
          notifyListeners();
          debugPrint('✅ [FUTURE HANDLERS] All notifications cleared from list');
        } else {
          debugPrint('⚠️ [FUTURE HANDLERS] Repository returned false');
        }
      })
      .catchError((error, stackTrace) {
        // ERROR HANDLER (.catchError)
        debugPrint('❌ [FUTURE HANDLERS] .catchError() called');
        debugPrint('Error: $error');
        debugPrint('Stack trace: $stackTrace');
        
        // Could show error to user via SnackBar
        // For now, just log it
      })
      .whenComplete(() {
        // CLEANUP HANDLER (runs regardless of success/error)
        debugPrint('🏁 [FUTURE HANDLERS] .whenComplete() called');
        debugPrint('Operation finished - cleanup or final actions here');
      });
}
```

### Characteristics

| Aspect | Description |
|--------|-------------|
| **Syntax** | Chained method calls (`.then()`, `.catchError()`, `.whenComplete()`) |
| **Error Handling** | `.catchError()` callback |
| **Readability** | ⭐⭐⭐ Functional style, requires understanding of callbacks |
| **Debugging** | ⭐⭐⭐ Callback-based, slightly harder to trace |
| **Use Case** | **Good for chaining** multiple async operations |

### Advantages ✅
- **Functional style**: Good for JavaScript/Promise developers
- **Explicit handlers**: Clear separation of success/error/cleanup
- **Chaining**: Natural for multiple sequential operations
- **No async required**: Can use in non-async functions
- **whenComplete**: Built-in cleanup handler (like `finally`)

### Disadvantages ❌
- **Less readable**: Callbacks can be harder to follow
- **Nesting**: Can lead to "callback hell" with complex chains
- **Debugging**: Harder to step through nested callbacks
- **Not idiomatic**: Dart community prefers async/await

---

## 🔍 Side-by-Side Comparison

### Example: Fetching User Data

#### ASYNC/AWAIT
```dart
Future<void> loadUser() async {
  try {
    final userId = await getUserId();
    final user = await fetchUser(userId);
    final posts = await fetchPosts(userId);
    
    setState(() {
      this.user = user;
      this.posts = posts;
    });
  } catch (e) {
    print('Error: $e');
  }
}
```

#### FUTURE HANDLERS
```dart
Future<void> loadUser() {
  return getUserId()
      .then((userId) => fetchUser(userId))
      .then((user) {
        setState(() {
          this.user = user;
        });
        return getUserId();
      })
      .then((userId) => fetchPosts(userId))
      .then((posts) {
        setState(() {
          this.posts = posts;
        });
      })
      .catchError((e) {
        print('Error: $e');
      });
}
```

**Winner**: ASYNC/AWAIT (much more readable for sequential operations)

---

## 🎯 When to Use Each Pattern

### Use ASYNC/AWAIT when:
- ✅ **Default choice** for most code
- ✅ Sequential operations (A → B → C)
- ✅ Need clear error handling with try-catch
- ✅ Working with complex business logic
- ✅ Debugging or maintaining code readability

### Use FUTURE HANDLERS when:
- ✅ Simple one-off operations
- ✅ Functional programming style preferred
- ✅ Integrating with callback-based APIs
- ✅ Need explicit cleanup with `.whenComplete()`
- ✅ Coming from JavaScript/Promise background

---

## 🏆 Dart/Flutter Best Practice

**Recommendation**: **Use ASYNC/AWAIT by default**

The Dart and Flutter style guides recommend async/await as the primary pattern because:
1. More readable and maintainable
2. Easier to debug
3. Better error handling with try-catch
4. Familiar to developers from many languages

Use `.then()` only when:
- You have a specific reason (e.g., callback-based API)
- You're writing very simple single-operation handlers
- You need to demonstrate both patterns (like in this example!)

---

## 📊 Execution Flow Visualization

### ASYNC/AWAIT Flow
```
1. Call markAsRead(id)
2. Await _repository.markAsRead(id)
   ⏳ WAIT for result
3. Check success
4. Update notifications list
5. Notify listeners
6. ✅ Done (or ❌ catch error)
```

### FUTURE HANDLERS Flow
```
1. Call markAllAsRead()
2. Return _repository.markAllAsRead(ids)
3. Register .then() handler
4. Register .catchError() handler  
5. Register .whenComplete() handler
6. Function returns immediately
   ⏳ WAIT for Future to complete
7. Execute handlers when ready:
   - SUCCESS → .then() → .whenComplete()
   - ERROR → .catchError() → .whenComplete()
```

---

## 🧪 Testing the Patterns

To test both patterns in the app:

1. **Open the app** and navigate to notifications screen
2. **Mark single notification as read** → Triggers `markAsRead()` (ASYNC/AWAIT)
   - Look for `[ASYNC/AWAIT]` logs in console
3. **Mark all notifications as read** → Triggers `markAllAsRead()` (FUTURE HANDLERS)
   - Look for `[FUTURE HANDLERS]` logs in console

### Expected Console Output

#### Single Notification (ASYNC/AWAIT)
```
📝 [ASYNC/AWAIT] Marking notification as read: notif_123
✅ [ASYNC/AWAIT] Notification marked as read successfully
```

#### All Notifications (FUTURE HANDLERS)
```
📝 [FUTURE HANDLERS] Marking 5 notifications as read...
✅ [FUTURE HANDLERS] .then() called - Success: true
✅ [FUTURE HANDLERS] All notifications cleared from list
🏁 [FUTURE HANDLERS] .whenComplete() called
Operation finished - cleanup or final actions here
```

---

## 📚 Additional Resources

- [Dart Async Programming](https://dart.dev/codelabs/async-await)
- [Flutter Asynchronous Programming](https://docs.flutter.dev/development/ui/async)
- [Effective Dart: Usage](https://dart.dev/guides/language/effective-dart/usage#prefer-asyncawait-over-using-raw-futures)

---

## Summary

Both patterns work, but **async/await is the modern, recommended approach** for Dart/Flutter. The `.then()/.catchError()` pattern is still valid and useful in specific scenarios, but should not be the default choice.

**Implemented in**: `lib/view_models/notification_view_model.dart`
- Line 49-67: `markAsRead()` - ASYNC/AWAIT
- Line 76-108: `markAllAsRead()` - FUTURE HANDLERS

---

**Document Version**: 1.0
**Last Updated**: October 30, 2025

