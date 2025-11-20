# Estrategias de Caching en Flutter (Sprint 3)

## Resumen técnico
- **Imágenes**: utilizamos `cached_network_image` + `flutter_cache_manager` (equivalente Flutter a Glide/Picasso/Coil). El `DefaultCacheManager` aplica política LRU con TTL y tamaño máximo en disco, mientras `OfflineNetworkImage` centraliza su uso en UI.
- **Datos estructurados**: Hive persiste snapshots versionadas (`CacheService`) con TTL por dominio; se precargan mediante `PrefetchService` y se reutilizan en escenarios offline.
- **Decisiones**: optamos por TTL + prefetch por ser multiplataforma y suficientes para la app. Para imágenes, delegamos la LRU a `DefaultCacheManager` (control de `maxNrOfCacheObjects` y vencimientos por archivo).

---

## Librerías de caché de imágenes (5 pts)

1. **Renderizado offline con `OfflineNetworkImage`**  
   Envuelve `CachedNetworkImage` y fuerza el `DefaultCacheManager`, que mantiene una lista LRU ordenada por último acceso y respeta expiración/limpieza periódica.

```
10:64:lib/widgets/offline_network_image.dart
class OfflineNetworkImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (imageUrl.isEmpty) {
      return errorChild ?? _defaultError();
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      cacheManager: DefaultCacheManager(),
      placeholder: (context, url) => placeholder ?? _defaultPlaceholder(),
      errorWidget: (context, url, error) => errorChild ?? _defaultError(),
    );
  }
}
```

2. **Servicio de precarga (`ImageCacheService.preCacheImage`)**  
   Evita descargas duplicadas revisando primero el cache de disco; el `CacheManager` elimina archivos menos usados (LRU) cuando supera los límites configurados.

```
12:24:lib/services/image_cache_service.dart
Future<bool> preCacheImage(String imageUrl) async {
  final cached = await _cacheManager.getFileFromCache(imageUrl);
  if (cached != null && cached.file.existsSync()) {
    return true;
  }
  await _cacheManager.downloadFile(imageUrl);
  return true;
}
```

3. **Precarga masiva deduplicada (`preCacheImages`)**  
   Conjunto de URLs único para optimizar la carga inicial y reducir lecturas en disco.

```
30:40:lib/services/image_cache_service.dart
Future<Map<String, bool>> preCacheImages(List<String> imageUrls) async {
  final results = <String, bool>{};
  final uniqueUrls = imageUrls.where((url) => url.isNotEmpty).toSet();
  for (final url in uniqueUrls) {
    final success = await preCacheImage(url);
    results[url] = success;
  }
  return results;
}
```

4. **Prefetch coordinado (`_preCachePostImages`)**  
   Tras descargar productos, guardamos la primera imagen de cada post en cache para que las tarjetas abran instantáneamente incluso offline.

```
179:205:lib/services/prefetch_service.dart
Future<void> _preCachePostImages(List<Post> posts, String label) async {
  final imageUrls = <String>{};
  for (final post in posts) {
    for (final image in post.images) {
      if (image.isNotEmpty) {
        imageUrls.add(image);
      }
    }
  }
  await Future.wait(imageUrls.map((imageUrl) async {
    await _imageCache.preCacheImage(imageUrl);
  }));
}
```

5. **Filtro por imágenes realmente cacheadas**  
   Antes de mostrar posts offline, verificamos que la miniatura exista en disco (evita placeholders vacíos).

```
182:201:lib/view_models/home_view_model.dart
final postsWithCachedImages = <Post>[];
for (final post in combinedPosts.values) {
  if (post.images.isNotEmpty) {
    final isImageCached = await _imageCache.isImageCached(post.images.first);
    if (isImageCached) {
      postsWithCachedImages.add(post);
    }
  }
}
newProducts = postsWithCachedImages;
```

---

## Caches de datos en Hive + TTL (10 pts)

6. **Snapshot del feed (`cachePosts`)**  
   Guarda lista + timestamp; TTL de 7 días evita datos obsoletos.

```
21:55:lib/services/cache_service.dart
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

7. **Lectura con expiración (`getCachedPosts`)**  
   Valida edad del snapshot antes de reutilizarlo.

```
62:117:lib/services/cache_service.dart
final cached = _storage.get(LocalStorageService.postsBoxName, 'all_posts');
final cacheData = jsonDecode(cached) as Map<String, dynamic>;
final timestamp = DateTime.parse(cacheData['timestamp'] as String);
if (DateTime.now().difference(timestamp) > postsCacheDuration) {
  return null;
}
return (cacheData['data'] as List)
    .map((e) => Map<String, dynamic>.from(e as Map))
    .toList();
```

8. **Detalle individual (`cachePost`)**  
   Permite abrir fichas previamente vistas sin golpe a red.

```
126:138:lib/services/cache_service.dart
Future<void> cachePost(String postId, Map<String, dynamic> post) async {
  final cacheData = {
    'data': post,
    'timestamp': DateTime.now().toIso8601String(),
  };
  await _storage.save(
    LocalStorageService.postsBoxName,
    'post_$postId',
    jsonEncode(cacheData),
  );
}
```

9. **Perfil de usuario (`cacheUser`)**  
   TTL de 7 días para rehidratar la pantalla Profile en frío.

```
212:224:lib/services/cache_service.dart
await _storage.save(
  LocalStorageService.userBoxName,
  'user_$userId',
  jsonEncode({
    'data': userData,
    'timestamp': DateTime.now().toIso8601String(),
  }),
);
```

10. **Wish list persistente (`cacheWishList`)**  
    Se cachea aunque venga vacío para distinguir “sin datos” vs “sin conexión”.

```
277:291:lib/services/cache_service.dart
final cacheData = {
  'data': items,
  'timestamp': DateTime.now().toIso8601String(),
};
await _storage.save(
  LocalStorageService.postsBoxName,
  'wish_list',
  jsonEncode(cacheData),
);
```

11. **Recomendaciones (`cacheRecommendedProducts`)**  
    Reutiliza el mismo TTL que posts y precalienta detalle.

```
324:343:lib/services/cache_service.dart
await _storage.save(
  LocalStorageService.postsBoxName,
  'recommended_products',
  jsonEncode({
    'data': products,
    'timestamp': DateTime.now().toIso8601String(),
  }),
);
for (final product in products) {
  await _cacheSinglePostMap(product);
}
```

12. **Productos por carrera (`cacheMajorBasedProducts`)**

```
376:395:lib/services/cache_service.dart
await _storage.save(
  LocalStorageService.postsBoxName,
  'major_based_products',
  jsonEncode({
    'data': products,
    'timestamp': DateTime.now().toIso8601String(),
  }),
);
```

13. **Catálogo de categorías (`cacheCategories`)**  
    TTL de 30 días: dato casi estático.

```
168:179:lib/services/cache_service.dart
await _storage.save(
  LocalStorageService.categoriesBoxName,
  'all_categories',
  jsonEncode({
    'data': categories,
    'timestamp': DateTime.now().toIso8601String(),
  }),
);
```

14. **Historial de chats (`cacheChatMessages`)**  
    Guarda últimos 100 mensajes con TTL de 30 días para reabrir conversaciones offline.

```
497:515:lib/services/cache_service.dart
await _storage.save(
  LocalStorageService.messagesBoxName,
  'chat_messages_$chatId',
  jsonEncode({
    'data': messages,
    'timestamp': DateTime.now().toIso8601String(),
  }),
);
```

15. **Metadata de chat (`cacheChatInfo`)**  
    Permite reconstruir header con usuario/producto sin red.

```
553:566:lib/services/cache_service.dart
await _storage.save(
  LocalStorageService.messagesBoxName,
  'chat_info_$chatId',
  jsonEncode({
    'data': chatInfo,
    'timestamp': DateTime.now().toIso8601String(),
  }),
);
```

16. **Posts del usuario (`cacheUserPosts`)**  
    Cachea y repuebla la pestaña “Mis publicaciones”.

```
430:446:lib/services/cache_service.dart
await _storage.save(
  LocalStorageService.postsBoxName,
  'user_posts_$userId',
  jsonEncode({
    'data': posts,
    'timestamp': DateTime.now().toIso8601String(),
  }),
);
for (final post in posts) {
  await _cacheSinglePostMap(post);
}
```

17. **Edad de cache (`getCacheAge`)**  
    Convierte timestamps a etiquetas amigables para banners offline.

```
254:270:lib/services/cache_service.dart
final cached = _storage.get(boxName, key);
final cacheData = jsonDecode(cached) as Map<String, dynamic>;
final timestamp = DateTime.parse(cacheData['timestamp'] as String);
final age = DateTime.now().difference(timestamp);
return age.inDays > 0
    ? '${age.inDays} day${age.inDays > 1 ? 's' : ''} ago'
    : age.inHours > 0
        ? '${age.inHours} hour${age.inHours > 1 ? 's' : ''} ago'
        : '${age.inMinutes} minute${age.inMinutes > 1 ? 's' : ''} ago';
```

18. **Carga de wishlist con fallback**  
    Prioriza red, pero cae al cache cuando el fetch falla o se está offline.

```
28:69:lib/view_models/wish_list_view_model.dart
if (_connectivity.isConnected) {
  wishItems = await _repository.getWishListItems();
  await _cache.cacheWishList(...);
} else {
  final cached = await _cache.getCachedWishList();
  if (cached != null) {
    wishItems =
        cached.map((json) => WishListItem.fromJson(json)).toList();
    _isLoadedFromCache = true;
  }
}
```

19. **Stream de chats con almacenamiento**  
    Cada snapshot se persiste para lectura posterior sin internet.

```
342:368:lib/services/chat_service.dart
return _db.collection('chats')
    .doc(chatId)
    .collection('messages')
    .snapshots()
    .asyncMap((snapshot) async {
      final messages = snapshot.docs.map((doc) => ChatMessage.fromJson(...)).toList();
      if (messages.isNotEmpty) {
        final messagesJson = messages.map((m) => {...}).toList();
        await _cache.cacheChatMessages(chatId, messagesJson);
      }
      return messages;
    });
```

20. **Prefetch de listas clave**  
    En un solo `Future.wait` guardamos posts, wishlist, categorías y posts del usuario para arrancar offline.

```
36:55:lib/services/prefetch_service.dart
await Future.wait([
  _prefetchNewPosts(),
  _prefetchRecommendedProducts(),
  _prefetchMajorBasedProducts(),
  _prefetchWishList(),
  _prefetchUserPosts(),
  _prefetchCategories(),
]);
```

---

## Observaciones y pendientes
- **LRU explícito**: no construimos un LRU manual en Hive porque la cantidad de registros es baja y controlamos vigencia con TTL. Para binarios, `DefaultCacheManager` ya aplica LRU con límites ajustables; usarlo nos evita reinventar memoria y políticas de eviction.
- **Ajustes futuros**: si la app crece, podemos exponer parámetros de `DefaultCacheManager` (por ejemplo `CacheManager(Config('images', stalePeriod: ...))`) o crear un wrapper LRU específico para Hive (ej. lista circular de llaves).

