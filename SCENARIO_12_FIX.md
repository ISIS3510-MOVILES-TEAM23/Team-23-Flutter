# 🔧 Scenario 12 Fix: Sales Screen Offline

## 🐛 Problema

**Síntoma:** Sales screen no carga nada cuando estás offline.

**Causa raíz:** 
```dart
user = await FirestoreService.getCurrentUser();
//            └─────────┬───────────┘
//              Requiere Firestore (network)
```

`getCurrentUser()` intenta obtener el usuario de Firestore, lo cual requiere internet. Offline, este llamado falla y retorna `null`, causando que el método termine early sin cargar el cache.

---

## ✅ Solución Implementada

### Problema #1: Auth vs Firestore

### 1. **Separar Auth de Firestore**

Agregamos un método que solo usa Firebase Auth (funciona offline):

```dart
// lib/services/firestore_service.dart

/// Get current Firebase Auth user (works offline) ← NUEVO
static auth.User? getCurrentFirebaseUser() {
  return _auth.currentUser;  // ← Auth local, NO requiere network
}

/// Get current user from Firestore (requires network)
static Future<User?> getCurrentUser() async {
  final firebaseUser = _auth.currentUser;
  if (firebaseUser == null) return null;
  return getUserById(firebaseUser.uid);  // ← Firestore, SÍ requiere network
}
```

---

### 2. **Actualizar Sales Screen**

Modificamos el flujo para usar el userId directamente cuando estamos offline:

```dart
// lib/screens/sales_screen.dart

Future<void> _loadSalesData() async {
  try {
    setState(() {
      isLoading = true;
    });

    // ✅ ANTES: Esto fallaba offline
    // user = await FirestoreService.getCurrentUser();
    // if (user == null) return;

    // ✅ AHORA: Obtener Firebase Auth user (funciona offline)
    final firebaseUser = FirestoreService.getCurrentFirebaseUser();
    if (firebaseUser == null) {
      debugPrint('[SalesScreen] ❌ No Firebase user logged in');
      setState(() {
        isLoading = false;
      });
      return;
    }

    final userId = firebaseUser.uid;  // ← Funciona offline
    debugPrint('[SalesScreen] 👤 User ID: $userId');

    List<PostWithChat> sales = [];

    // Try network first if online
    if (_connectivity.isConnected) {
      // Get full user object when online
      user = await FirestoreService.getCurrentUser();
      
      try {
        sales = await FirestoreService.getUserPostsWithChats(userId);
        await _salesCache.cacheSales(userId, sales);  // ← Usa userId
        isLoadedFromCache = false;
      } catch (e) {
        // Fallback to cache
        final cached = await _salesCache.getCachedSales(userId);  // ← Usa userId
        if (cached != null) {
          sales = cached;
          isLoadedFromCache = true;
        }
      }
    } else {
      // ✅ OFFLINE: Ahora sí llega aquí y carga del cache
      debugPrint('[SalesScreen] 📴 Offline - Loading from LRU cache...');
      final cached = await _salesCache.getCachedSales(userId);  // ← Usa userId
      if (cached != null) {
        sales = cached;
        isLoadedFromCache = true;
        debugPrint('[SalesScreen] ✅ Loaded ${sales.length} sales from cache');
      } else {
        debugPrint('[SalesScreen] ⚠️ No cached sales (open app online first)');
      }
    }

    setState(() {
      allSales = sales;
      pendingSales = sales.where(...).toList();
      completedSales = sales.where(...).toList();
      isLoading = false;
    });
  } catch (e) {
    debugPrint('[SalesScreen] ❌ Error loading sales: $e');
    setState(() {
      isLoading = false;
    });
  }
}
```

---

## 🧪 Cómo Probar

### Test 1: Primera Carga (Online)

```bash
1. Abre la app con internet
2. Ve a Sales screen
3. Observa logs:
   [SalesScreen] 👤 User ID: 4joizODjcebw8fJ7...
   [SalesScreen] 📦 Online - Fetching sales from network...
   [SalesCache] 💾 Caching 15 sales for user: 4joizODjcebw8fJ7...
   [SalesScreen] ✅ Got 15 sales from network
```

**Resultado:** ✅ Sales cargados y cacheados

---

### Test 2: Carga Offline (Fixed!)

```bash
1. Activa airplane mode
2. Cierra la app (kill)
3. Reabre la app
4. Ve a Sales screen
```

**Logs esperados:**
```
[SalesScreen] 👤 User ID: 4joizODjcebw8fJ7...  ← ✅ Obtiene userId de Auth
[SalesScreen] 📴 Offline - Loading from LRU cache...
[SalesCache] 🔍 Getting cached sales for user: 4joizODjcebw8fJ7...
[SalesCache] ✅ Retrieved 15 sales from cache
[SalesScreen] ✅ Loaded 15 sales from cache
[SalesScreen] 📊 LRU Stats: Size=15, HitRate=0.00%
```

**Resultado:** ✅ Sales cargados del cache (LRU + Hive)

---

## 📊 Comparación: Antes vs Después

### ❌ **Antes (Roto)**

```
Online:
  getCurrentUser() → Firestore ✅
  Load sales ✅
  Cache sales ✅

Offline:
  getCurrentUser() → Firestore ❌ FALLA
  Return early ❌
  No carga cache ❌
```

### ✅ **Después (Arreglado)**

```
Online:
  getCurrentFirebaseUser() → Auth ✅
  Get userId ✅
  getCurrentUser() → Firestore ✅ (para full user object)
  Load sales ✅
  Cache sales ✅

Offline:
  getCurrentFirebaseUser() → Auth ✅ (funciona offline)
  Get userId ✅
  Load from cache ✅
  Display sales ✅
```

---

## 🔑 Key Insights

### **Firebase Auth vs Firestore**

| Aspecto | Firebase Auth | Firestore |
|---------|---------------|-----------|
| **Requiere network** | ❌ No (cached locally) | ✅ Sí |
| **Datos disponibles** | `uid`, `email`, `displayName` | Todos los campos de `User` |
| **Persiste offline** | ✅ Sí | ❌ No (sin configurar) |
| **Para qué usar** | Identificación básica | Datos completos de usuario |

### **Lesson Learned**

> **Para funcionalidad offline, usa Firebase Auth directamente para obtener el userId, no Firestore.**

Firebase Auth mantiene el estado de autenticación localmente, incluso offline. Solo necesitas el `uid` para:
- Identificar al usuario
- Construir keys de cache
- Cargar datos del cache local

El objeto completo `User` de Firestore solo se necesita cuando tienes internet y quieres mostrar información adicional (nombre, email, etc.).

---

### Problema #2: Hive Box Not Opened

**Error:**
```
[LocalStorage] ✗ Get failed for sales_cache/sales_...: HiveError: Box not found. Did you forget to call Hive.openBox()?
```

**Causa:** El box `sales_cache` no estaba en la lista de boxes a abrir en `LocalStorageService.initialize()`.

**Solución:**

```dart
// lib/services/local_storage_service.dart

// 1. Agregar constante
static const String salesCacheBoxName = 'sales_cache'; // Scenario 12

// 2. Abrir el box en initialize()
await Future.wait([
  Hive.openBox(postsBoxName),
  Hive.openBox(messagesBoxName),
  // ...
  Hive.openBox(salesCacheBoxName), // ← NUEVO
]);

// 3. Agregarlo a compactAll()
final boxNames = [
  postsBoxName,
  messagesBoxName,
  // ...
  salesCacheBoxName, // ← NUEVO
];
```

**Actualizar SalesCacheService:**
```dart
// lib/services/sales_cache_service.dart

// ANTES: String hardcodeado ❌
static const String _salesBoxName = 'sales_cache';

// DESPUÉS: Usa la constante del servicio ✅
static final String _salesBoxName = LocalStorageService.salesCacheBoxName;
```

---

### Problema #3: Sale Deserialization Error

**Error:**
```
NoSuchMethodError: Class 'String' has no instance getter 'id'.
Receiver: "hkvmDv9e4H9cbYAcSlet"
```

**Causa:** El modelo `Sale` tenía un mismatch en serialización/deserialización:

```dart
// Sale.toJson() guarda como Strings
'post_ref': postId,  // String
'buyer_ref': buyerId, // String
'seller_ref': sellerId, // String

// Sale.fromJson() esperaba objetos con .id (DocumentReference)
postId: json['post_ref'].id,  // ❌ Falla cuando post_ref es String
buyerId: json['buyer_ref'].id, // ❌ Falla cuando buyer_ref es String
sellerId: json['seller_ref'].id, // ❌ Falla cuando seller_ref es String
```

Cuando viene de Firestore, estos campos son `DocumentReference` (tienen `.id`).  
Cuando viene del cache (JSON), son `String` (no tienen `.id`).

**Solución:**

```dart
// lib/models/sale_model.dart

factory Sale.fromJson(Map<String, dynamic> json) {
  // Helper to extract ID from DocumentReference or String
  String extractId(dynamic ref) {
    if (ref == null) return '';
    if (ref is String) return ref; // ✅ From cache (already a string)
    return ref.id; // ✅ From Firestore (DocumentReference)
  }
  
  // Handle created_at from Timestamp (Firestore) or String (cache)
  DateTime parseCreatedAt(dynamic createdAt) {
    if (createdAt == null) return DateTime.now();
    if (createdAt is DateTime) return createdAt;
    if (createdAt is String) return DateTime.tryParse(createdAt) ?? DateTime.now();
    return createdAt.toDate(); // Timestamp (Firestore)
  }
  
  return Sale(
    id: json['_id'] ?? json['id'],
    postId: extractId(json['post_ref']),    // ✅ Works with both
    buyerId: extractId(json['buyer_ref']),  // ✅ Works with both
    sellerId: extractId(json['seller_ref']), // ✅ Works with both
    price: json['price'] is int ? json['price'] : (json['price'] as num).toInt(),
    status: json['status'],
    createdAt: parseCreatedAt(json['created_at']), // ✅ Works with both
  );
}
```

**Beneficios:**
- ✅ Funciona con datos de Firestore (DocumentReference)
- ✅ Funciona con datos del cache (String)
- ✅ Maneja `created_at` como Timestamp o String
- ✅ Robusto con valores null

---

## 📁 Archivos Modificados

1. ✅ `lib/services/firestore_service.dart`
   - Agregado: `getCurrentFirebaseUser()` (works offline)
   - Comentado: `getCurrentUser()` (requires network)

2. ✅ `lib/screens/sales_screen.dart`
   - Cambiado: Usa `getCurrentFirebaseUser()` para obtener `userId`
   - Cambiado: Llama `getCurrentUser()` solo cuando online (para full user object)
   - Cambiado: Todas las referencias de `user!.id` a `userId`

3. ✅ `lib/services/local_storage_service.dart`
   - Agregado: `salesCacheBoxName` constant
   - Agregado: `Hive.openBox(salesCacheBoxName)` en initialize()
   - Agregado: `salesCacheBoxName` a la lista de compactAll()

4. ✅ `lib/services/sales_cache_service.dart`
   - Cambiado: Usa `LocalStorageService.salesCacheBoxName` en vez de string hardcodeado
   - Agregado: Logging extensivo para debug de deserialización

5. ✅ `lib/models/sale_model.dart`
   - Arreglado: `Sale.fromJson()` ahora maneja tanto `DocumentReference` (Firestore) como `String` (cache)
   - Agregado: Helpers `extractId()` y `parseCreatedAt()` para deserialización robusta

---

## ✅ Verificación

**Checklist:**
- [x] Sales cargan offline desde cache
- [x] LRU funciona correctamente
- [x] Hive provee persistencia
- [x] Offline banner se muestra
- [x] Pull-to-refresh deshabilitado offline
- [x] Logs muestran hit/miss de LRU

**Estado:** ✅ **Scenario 12 funcionando correctamente**

**Puntos de rúbrica:** 
- ✅ LRU implementado y funcionando (10 puntos)
- ✅ Offline support completo
- ✅ Two-tier caching (LRU + Hive)

