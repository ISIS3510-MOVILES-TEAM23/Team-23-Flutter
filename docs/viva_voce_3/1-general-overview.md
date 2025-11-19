# Guion Viva Voce Sprint 3 (Flutter)

## 1. Decisiones y Estrategias Globales
- Adoptamos un enfoque *offline-first* porque el marketplace opera en campus con WiFi irregular.
- Aprovechamos servicios ya probados en Mercandes (Kotlin) para unificar la experiencia multiplataforma.
- Conectividad eventual y colas de sincronización aseguran continuidad sin operaciones “fantasma”.

## 2. Almacenamiento Local
- Persistimos la sesión (`UserSessionStorage`) con payload mínimo (uid, email, displayName, photoUrl, flag de verificación) en `SharedPreferences`, permitiendo entrar directo al Home sin red.
- Hive organiza cajas por dominio: posts, chats, usuarios, categorías y `sync_queue`. `LocalStorageService` las abre al iniciar y `CacheService` agrega TTLs y *helpers* semánticos.
- Guardamos lotes de posts y cada post individual para que los detalles se abran offline.
- Los borradores de publicaciones viven como JSON + imágenes en el directorio de caché y se sincronizan automáticamente al volver la conexión.

```
489:515:lib/services/cache_service.dart
await _storage.save(LocalStorageService.postsBoxName, 'all_posts', jsonEncode(cacheData));
// ... existing code ...
await _cache.cacheChatMessages(chatId, messagesJson);
```

## 3. Eventual Connectivity (EvC) y Cola de Sincronización
- `ConnectivityService` expone un *stream* broadcast; todas las capas se enteran al instante del estado de la red.
- `SyncQueueService` procesa mutaciones pendientes con *backoff* secuencial y guarda estado en Hive (`sync_queue`).
- Casos clave: mensajes con badge “Queued” e icono 📤, wishlist con UI optimista, reviews como borradores y búsquedas que registran eventos cuando vuelve la red.
- Mantenemos banners (“Offline – Showing cached products”) para evitar antipatrón de falta de feedback y aclarar limitaciones temporales.

## 4. Caching y Concurrencia
- Caché en dos capas: LRU en memoria + Hive persistente, con TTLs por dominio (posts 7 d, categorías 30 d, mensajes 30 d) para balancear frescura y datos offline.
- `PrefetchService` lanza `Future.wait` con seis *fetches* paralelos; hidrata cajas e imágenes para que el Home aparezca al instante incluso sin red.
- Chats usan `snapshots().asyncMap` para transformar documentos, escribir en cache y mantener la UI fluida.
- Apostamos por el modelo cooperativo de Dart (Futures/Streams) para sostener 60 fps sin hilos nativos.
- Ejemplo de prefetch coordinado:

```
633:647:lib/services/prefetch_service.dart
await Future.wait([
  _prefetchNewPosts(),
  _prefetchRecommendedProducts(),
  _prefetchMajorBasedProducts(),
  _prefetchWishList(),
  _prefetchUserPosts(),
  _prefetchCategories(),
]);
```

## Tips de Presentación
- Arranca cada bloque con “Decidimos…” para subrayar las justificaciones.
- Cierra con impacto UX (“nadie pierde un draft aunque se caiga el WiFi”).
- Usa tono técnico natural: TTLs, *backoff*, *optimistic UI*, *broadcast stream*.
- Si hay demo rápida, muestra un banner offline o el badge “Queued” para aterrizar el concepto.

