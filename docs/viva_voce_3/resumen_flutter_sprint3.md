## Resumen Ejecutivo Flutter – Sprint 3

## Parte 1 · Discurso de sustentación (1 minuto por columna)
- **Apertura estratégica**  
  “En Flutter apostamos por un marketplace offline-first: garantizamos navegación, mensajería y compras aun sin red, con datos calientes nutridos por analítica en BigQuery. Todo se apoya en Hive, sincronización diferida y un pipeline que alimenta notificaciones y tableros en tiempo real.”
- **Columna: Almacenamiento local (explicar decisiones del equipo)**  
  “Abrimos cajas Hive por dominio –posts, chats, usuarios, wishlist, sync queue– para datos estructurados; guardamos borradores en archivos JSON con imágenes cacheadas; y persistimos sesión en SharedPreferences. Así explicamos y defendemos lo que desarrollaron mis compañeros dentro del mismo cliente Flutter.”
- **Columna: Conectividad eventual y caching**  
  “Diseñamos 16 escenarios offline con banners, botones deshabilitados y sincronización en background. CacheService asigna TTL a cada entidad, cached_network_image precarga assets y mantenemos fallback jerárquico (red, memoria, Hive, defaults).”
- **Columna: Multithreading/asincronía**  
  “Orquestamos Futures con handlers, `async/await`, Streams broadcast y tareas diferidas para mantener la UI reactiva. Podemos mostrar contribuciones de cualquier compañero porque seguimos el mismo patrón: `PrefetchService`, `ConnectivityService`, `SyncQueueService`.”
- **Columna: Pipeline analítico conectado**  
  “El app consume los endpoints `/wishlist_analytics`, `/wishlist_time_distribution`, `/top_categories_by_major` y `/crashlytics_summary`, que vienen de BigQuery y FastAPI. Nada es manual: los datos alimentan notificaciones segmentadas y tarjetas dentro de Flutter.”
- **Cierre**  
  “Con estas estrategias cumplimos las rúbricas técnicas y de negocio: demostramos código, mostramos dashboards conectados y defendemos cómo cada pieza eleva retención y transacciones.”

## Parte 2 · Detalle técnico por rúbrica

### Almacenamiento local
- **BD llave/valor (5 pts)**: `LocalStorageService` abre cajas Hive (`postsBoxName`, `messagesBoxName`, `userBoxName`, `syncQueueBox`, etc.) y `CacheService` añade TTL por dominio.
- **Archivos locales (5 pts)**: borradores de publicación se serializan como `draft_post.json`; imágenes se guardan en el cache directory mientras esperan sincronización.
- **Preferencias (5 pts)**: `UserSessionStorage` persiste uid, email, displayName, photoUrl y flag de verificación en `user_session_prefs` para restaurar sesión sin red.
- **Vistas protegidas (≥5 pts c/u)**: Home, Search, Product Detail, Chats, Wishlist, Profile, Sales, Rankings y ConfirmPurchase detectan offline, muestran mensajes contextuales y degradan acciones críticas.

### Estrategias de caching
- **TTL diferenciadas**: posts (7 días), usuarios y chats (7-30 días), categorías (30 días). `CacheService.cachePosts`, `cacheUser` y `cacheChatMessages` guardan payload y timestamp.
- **Librería de imágenes (5 pts)**: `cached_network_image` precarga hero images y mantiene cache en disco; `PrefetchService` baja la primera imagen de cada post destacado.
- **Prefetch y fallback**: `PrefetchService.prefetchAll` (Future.wait) hidrata nuevos posts, recomendaciones, wishlist, user posts y categorías; fallback jerárquico garantiza contenido aun en primer arranque offline.

### Conectividad eventual (EvC)
- **Catálogo de escenarios**: login, signup, home, búsqueda, chats, creación de post, wishlist, rankings, ventas, confirmación de compra, entre otros, cada uno con copy y acciones específicas.
- **Sync Queue**: `SyncQueueService` guarda operaciones pendientes (mensajes, wishlist, reviews, perfil) con retries 0s/5s/15s y limpieza tras éxito.
- **Detección automática**: `ConnectivityService` publica cambios como Stream broadcast; `waitForConnection` permite esperar reconexión sin bloquear la UI.

### Multithreading / Asincronía
- **Future (5 pts)**: repositorios y servicios retornan Futures para cada operación remota o de cache.
- **Future con handler (5 pts)**: `PrefetchService.prefetchAll` usa `try/finally` para marcar `_isPrefetching`; `_syncQueue` controla `_isSyncing` y administra errores.
- **Future con handler + async/await (10 pts)**: lookups a Firestore, Hive y colas se estructuran con `async/await`, incluyendo `await Future.wait([...])`.
- **Streams (5 pts)**: `ConnectivityService.onConnectivityChanged` y `ChatService.streamChatMessages` distribuyen eventos en tiempo real a múltiples listeners.
- **Procesamiento diferido**: precarga de imágenes y escrituras masivas en Hive se ejecutan fuera del hilo principal mediante tareas asíncronas programadas, manteniendo la UI libre.

### Pipeline analítico conectado
- **Integración con BigQuery**: endpoints `/wishlist_analytics`, `/wishlist_time_distribution`, `/top_categories_by_major`, `/crashlytics_summary` se consultan desde Flutter para graficar métricas en tiempo real o bajo demanda.
- **Notificaciones tipo 2**: Cloud Functions detectan nuevas publicaciones y envían payloads a usuarios suscritos por categoría; Flutter abre directamente el detalle usando `postId`.
- **Eventos offline → online**: búsquedas y wishlist sincronizan eventos cuando regresa la red, alimentando el `product_search_events` y la tabla `WishlistAnalytics`.

### Estado de calidad y evidencias
- **Pruebas**: escenarios de desconexión/reconexión validados manualmente; banners, placeholders y botones deshabilitados evitan antipatrónes.
- **Lenguaje técnico listo**: cada sección cita clases/servicios (Hive, CacheService, SyncQueueService, ConnectivityService) y describe su alcance para responder preguntas de la rúbrica.
- **Preparados para VivaVoce3**: podemos mostrar código relevante, recorrer el tablero analítico conectado y responder cómo cada estrategia mejora retención, ventas y estabilidad.

