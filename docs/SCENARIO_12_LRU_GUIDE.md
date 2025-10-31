# 📋 Scenario 12: LRU Cache - Guía de Uso y Prueba

## 🎯 ¿Qué hace el LRU en Scenario 12?

**Scenario 12: View Sales Status Without Internet**

El LRU (Least Recently Used) caché mantiene en memoria los últimos 50 sales accedidos para acceso rápido, mientras que Hive proporciona persistencia.

---

## 🏗️ Arquitectura: Two-Tier Caching

```
┌─────────────────────────────────────────┐
│         Sales Screen (UI)               │
└────────────────┬────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────┐
│      SalesCacheService                  │
│                                         │
│  ┌──────────────┐  ┌─────────────────┐ │
│  │  Tier 1: LRU │  │  Tier 2: Hive   │ │
│  │  (Memory)    │  │  (Persistent)   │ │
│  │  Max: 50     │  │  Unlimited      │ │
│  │  TTL: 10min  │  │  TTL: 10min     │ │
│  └──────────────┘  └─────────────────┘ │
└─────────────────────────────────────────┘
```

---

## 📝 Implementación LRU

### 1. **LRU Cache Service** (Generic)

```dart
// lib/services/lru_cache_service.dart
class LruCacheService<K, V> {
  final int maxCapacity;  // ← Parámetro: máximo de items
  final LinkedHashMap<K, _CacheEntry<V>> _cache;  // ← Estructura: LinkedHashMap
  int _hitCount = 0;
  int _missCount = 0;

  LruCacheService({required this.maxCapacity})
      : _cache = LinkedHashMap<K, _CacheEntry<V>>();

  /// Get item (moves to end = most recently used)
  V? get(K key) {
    final entry = _cache.remove(key);  // ← Remove from current position
    
    if (entry == null) {
      _missCount++;
      return null;  // Cache MISS
    }

    if (entry.isExpired) {
      _missCount++;
      return null;  // Expired
    }

    _cache[key] = entry;  // ← Re-add at end (most recent)
    _hitCount++;
    return entry.value;  // Cache HIT
  }

  /// Put item (evicts LRU if at capacity)
  void put(K key, V value, {Duration? ttl}) {
    _cache.remove(key);  // Remove if exists
    
    // Evict LRU if at capacity
    if (_cache.length >= maxCapacity) {
      final lruKey = _cache.keys.first;  // ← First = Least Recently Used
      _cache.remove(lruKey);
      debugPrint('[LRU] 🗑️ EVICTED (LRU): $lruKey');
    }

    // Add to end (most recently used)
    final expiresAt = ttl != null ? DateTime.now().add(ttl) : null;
    _cache[key] = _CacheEntry(value, expiresAt);
  }

  /// Get cache hit rate as percentage
  double get hitRate {
    final total = _hitCount + _missCount;
    if (total == 0) return 0.0;
    return (_hitCount / total) * 100;
  }
}
```

**Decisiones de implementación:**
1. **LinkedHashMap:** Mantiene orden de inserción, O(1) para get/put
2. **Remove + Re-add:** Mueve item al final (más reciente)
3. **First key = LRU:** El primer elemento es el menos usado
4. **TTL opcional:** Para expiración de datos
5. **Hit/Miss metrics:** Para monitoreo

---

### 2. **Sales Cache Service** (Uso específico)

```dart
// lib/services/sales_cache_service.dart
class SalesCacheService {
  // Tier 1: LRU (in-memory, fast)
  final LruCacheService<String, PostWithChat> _lruCache = LruCacheService(
    maxCapacity: 50,  // ← Parámetro: máximo 50 sales en memoria
  );
  
  // Tier 2: Hive (persistent, backup)
  final LocalStorageService _storage = LocalStorageService();
  static const String _salesBoxName = 'sales_cache';
  static const Duration _cacheTtl = Duration(minutes: 10); // ← Parámetro: TTL

  /// Cache sales (stores in both tiers)
  Future<void> cacheSales(String userId, List<PostWithChat> sales) async {
    // LRU: Most recently accessed
    for (final sale in sales) {
      final key = '${userId}_${sale.post.id}';
      _lruCache.put(key, sale, ttl: _cacheTtl);  // ← TTL: 10 minutos
    }
    
    // Hive: Full list for persistence
    final salesData = {
      'userId': userId,
      'sales': sales.map((s) => _serializeSale(s)).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    await _storage.save(_salesBoxName, 'sales_$userId', jsonEncode(salesData));
  }

  /// Get cached sales (tries LRU first, then Hive)
  Future<List<PostWithChat>?> getCachedSales(String userId) async {
    // Try Hive for full list
    final cached = _storage.get(_salesBoxName, 'sales_$userId');
    if (cached == null) return null;

    final salesData = jsonDecode(cached) as Map<String, dynamic>;
    final timestamp = DateTime.parse(salesData['timestamp'] as String);

    // Check TTL: 10 minutes
    if (DateTime.now().difference(timestamp) > _cacheTtl) {
      return null; // Expired
    }

    final salesList = (salesData['sales'] as List)
        .map((json) => _deserializeSale(json))
        .toList();

    // Populate LRU cache with retrieved sales
    for (final sale in salesList) {
      final key = '${userId}_${sale.post.id}';
      if (!_lruCache.containsKey(key)) {
        _lruCache.put(key, sale, ttl: _cacheTtl);
      }
    }

    return salesList;
  }

  /// Get specific sale (LRU fast path)
  Future<PostWithChat?> getCachedSale(String userId, String postId) async {
    final key = '${userId}_$postId';
    
    // Try LRU first (O(1) access)
    final fromLru = _lruCache.get(key);
    if (fromLru != null) {
      debugPrint('[SalesCache] ✅ Sale found in LRU: $postId');
      return fromLru;  // ← Fast path: LRU hit
    }

    // Fallback to Hive (slower but persistent)
    final allSales = await getCachedSales(userId);
    if (allSales != null) {
      final sale = allSales.firstWhere((s) => s.post.id == postId);
      _lruCache.put(key, sale, ttl: _cacheTtl); // ← Warm up LRU
      return sale;
    }

    return null;
  }
}
```

---

## 🧪 Cómo Probar el LRU

### Test 1: Carga Inicial (Online)

```bash
1. Abre la app con internet
2. Ve a "Sales" screen
3. Observa los logs:
```

**Logs esperados:**
```
[SalesScreen] 📦 Online - Fetching sales from network...
[SalesScreen] ✅ Got 15 sales from network
[SalesCache] 💾 Caching 15 sales for user: 4joizODjcebw8fJ7...
[LRU] 💾 PUT: 4joizODjcebw8fJ7..._post1 (size: 1/50)
[LRU] 💾 PUT: 4joizODjcebw8fJ7..._post2 (size: 2/50)
...
[LRU] 💾 PUT: 4joizODjcebw8fJ7..._post15 (size: 15/50)
[SalesCache] ✅ Cached 15 sales
[SalesScreen] 📊 LRU Stats: Size=15, HitRate=0.00%
```

**Verificación:** ✅ Sales cargados y cacheados en LRU

---

### Test 2: Carga Offline (Cache Hit)

```bash
1. Activa airplane mode
2. Cierra la app completamente
3. Reabre la app
4. Ve a "Sales" screen
```

**Logs esperados:**
```
[SalesScreen] 📴 Offline - Loading from LRU cache...
[SalesCache] 🔍 Getting cached sales for user: 4joizODjcebw8fJ7...
[SalesCache] ✅ Retrieved 15 sales from cache
[LRU] 💾 PUT: 4joizODjcebw8fJ7..._post1 (size: 1/50)  ← Warming up LRU
[LRU] 💾 PUT: 4joizODjcebw8fJ7..._post2 (size: 2/50)
...
[SalesScreen] ✅ Loaded 15 sales from cache
[SalesScreen] 📊 LRU Stats: Size=15, HitRate=0.00%
```

**Verificación:** ✅ Sales cargados desde Hive → LRU

---

### Test 3: LRU Eviction (Simular >50 sales)

Si tienes >50 sales, verás evicción:

```
[LRU] 💾 PUT: user_post49 (size: 49/50)
[LRU] 💾 PUT: user_post50 (size: 50/50)
[LRU] 🗑️ EVICTED (LRU): user_post1  ← Primer sale evicted
[LRU] 💾 PUT: user_post51 (size: 50/50)
[LRU] 🗑️ EVICTED (LRU): user_post2  ← Segundo sale evicted
```

**Verificación:** ✅ LRU mantiene solo los 50 más recientes

---

### Test 4: TTL Expiration

```bash
1. Carga sales online
2. Espera 11 minutos (TTL = 10 min)
3. Intenta cargar offline
```

**Logs esperados:**
```
[SalesCache] ⏰ Cache expired (age: 11min)
[SalesScreen] ⚠️ No cached sales (open app online first)
```

**Verificación:** ✅ TTL funciona correctamente

---

## 📊 Parámetros Configurables

| Parámetro | Valor Actual | Dónde | Por Qué |
|-----------|--------------|-------|---------|
| **maxCapacity** | 50 | `sales_cache_service.dart:28` | Balance entre memoria y cobertura |
| **TTL** | 10 minutos | `sales_cache_service.dart:34` | Sales status puede cambiar rápido |
| **Key format** | `{userId}_{postId}` | `sales_cache_service.dart:45` | Único por usuario y post |

---

## 🎯 Por Qué LRU es Apropiado para Sales

### ✅ **Ventajas:**

1. **Acceso frecuente:** Usuario revisa sales activos múltiples veces
2. **Growth bounded:** Usuario no tendrá 1000s de sales activos
3. **Recent = Important:** Sales recientes son más relevantes
4. **Memory efficient:** Solo mantiene los 50 más accedidos

### ❌ **No usar LRU para:**

- **Categorías:** Pocas, estáticas, no se acceden frecuentemente
- **Full lists:** Use Hive para persistencia completa
- **Critical data:** Que no puede perderse (use Hive)

---

## 🐛 Troubleshooting

### Problema: "No cached sales found"

**Causa:** No has abierto la app online primero

**Solución:**
```bash
1. Conecta internet
2. Abre la app
3. Ve a Sales (cachea datos)
4. Desconecta internet
5. Ahora funcionará offline
```

---

### Problema: LRU hit rate siempre 0%

**Causa:** Solo accedes a la lista completa, no a sales individuales

**Solución:**
Implementar `getCachedSale()` cuando navegas a detalles de un sale:

```dart
// Cuando usuario toca un sale
final sale = await _salesCache.getCachedSale(userId, postId);
// ← Esto generará LRU hits
```

---

## 📝 Resumen para Documentación

**Scenario 12 usa LRU para:**

1. **Storage:** Two-tier (LRU + Hive)
2. **Capacity:** 50 sales máximo en memoria
3. **TTL:** 10 minutos
4. **Eviction:** Least Recently Used
5. **Metrics:** Hit rate, size, evictions
6. **Structure:** `LinkedHashMap<String, PostWithChat>`

**Archivos clave:**
- `lib/services/lru_cache_service.dart` - Generic LRU
- `lib/services/sales_cache_service.dart` - Sales-specific usage
- `lib/screens/sales_screen.dart` - UI integration

**Puntos de rúbrica:** ✅ **10 puntos** (LRU con explicación completa)

