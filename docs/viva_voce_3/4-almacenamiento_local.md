# Estrategias de Almacenamiento Local (Flutter · Sprint 3)

## Resumen ejecutivo
- Optamos por una arquitectura *offline-first* basada en Hive (clave/valor) + cachés temporales para garantizar UX sin red, en vez de levantar un motor relacional completo.
- Complementamos con `SharedPreferences` para sesiones rápidas y cachés de imágenes manejadas por `flutter_cache_manager`. No persistimos archivos crudos porque delegamos los binarios (fotos) a Firebase Storage.

---

## BD Local Relacional (SQLite, etc.) – **No implementada**
- En este sprint no integramos un motor relacional nativo dentro del cliente Flutter.  
- Razones:
  - Hive cubre las necesidades de datos estructurados (posts, chats, usuarios, colas de sincronización) con menor fricción multiplataforma.
  - Toda la lógica analítica pesada vive en Firestore/BigQuery; duplicarla en SQLite habría incrementado mantenimiento sin valor adicional.
  - El alcance del proyecto se centró en consistencia eventual y cacheo rápido más que en joins complejos offline.
- Resultado: **no se generan puntos en la rúbrica de “BD local relacional” por el lado Flutter**.

---

## BD Llave/Valor (Hive) – **Implementada**
- `LocalStorageService` inicializa Hive y abre cajas por dominio (`posts`, `messages`, `user`, `sync_queue`, etc.).

```
21:38:lib/services/local_storage_service.dart
Future<void> initialize() async {
  if (_isInitialized) return;
  await Hive.initFlutter();
  await Future.wait([
    Hive.openBox(postsBoxName),
    Hive.openBox(messagesBoxName),
    Hive.openBox(categoriesBoxName),
    Hive.openBox(userBoxName),
    Hive.openBox(syncQueueBoxName),
    Hive.openBox(metadataBoxName),
  ]);
  _isInitialized = true;
}
```

- `CacheService` serializa listas completas de posts (y cada detalle) con timestamps para TTLs controlados.

```
21:55:lib/services/cache_service.dart
Future<void> cachePosts(List<Map<String, dynamic>> posts) async {
  final cacheData = {
    'data': posts,
    'timestamp': DateTime.now().toIso8601String(),
  };
  await _storage.save(LocalStorageService.postsBoxName, 'all_posts', jsonEncode(cacheData));
  for (final post in posts) {
    await _cacheSinglePostMap(post);
  }
}
```

- `SyncQueueService` usa la caja `sync_queue` para persistir mensajes pendientes y procesarlos cuando vuelve la conectividad.

```
22:52:lib/services/sync_queue_service.dart
Future<String> queueMessage({required String chatId, required String senderId, required String content}) async {
  final clientId = _uuid.v4();
  final queueItem = {..., 'status': 'pending', 'retryCount': 0};
  await _storage.save(LocalStorageService.syncQueueBoxName, clientId, jsonEncode(queueItem));
  if (_connectivity.isConnected) {
    _syncQueue();
  }
  return clientId;
}
```

Resultado: **obtenemos la rúbrica de BD llave/valor (Hive)** con múltiples casos de uso.

---

## Archivos Locales – **No implementados manualmente**
- No persistimos archivos crudos (por ejemplo, JSON de borradores) de manera explícita en esta app Flutter.
- Razones:
  - Las imágenes se manejan con `StorageService` → se suben directo a Firebase Storage; localmente solo se usan paths temporales suministrados por `ImagePicker`.
  - Para imágenes cacheadas reutilizamos `flutter_cache_manager`, que administra los archivos en segundo plano sin que el equipo escriba archivos manualmente.
  - El roadmap describe drafts en archivos (`draft_post.json`) implementados en la app Kotlin; en Flutter priorizamos Hive + cachés en memoria para cumplir offline sin duplicar esfuerzos.
- Resultado: **no se acumulan puntos en la rúbrica de “Archivos locales”** en Flutter durante este sprint.

---

## Preferences / UserDefaults / DataStore – **Implementadas (SharedPreferences)**
- `LoginViewModel` usa `SharedPreferences` para almacenar la sesión y permitir arranques offline si la sesión es válida.

```
30:63:lib/view_models/login_view_model.dart
Future<bool> checkCachedAuth() async {
  final user = firebase_auth.FirebaseAuth.instance.currentUser;
  if (user != null) {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user_id', user.uid);
    await prefs.setString('cached_user_email', user.email ?? '');
    await prefs.setInt('last_login_timestamp', DateTime.now().millisecondsSinceEpoch);
    return true;
  }
  final prefs = await SharedPreferences.getInstance();
  final cachedUserId = prefs.getString('cached_user_id');
  final lastLogin = prefs.getInt('last_login_timestamp');
  // ... validación de expiración (30 días) ...
}
```

- Al completar un login exitoso también cacheamos las claves para futuros arranques sin red.

```
102:109:lib/view_models/login_view_model.dart
if (userCredential?.user != null) {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('cached_user_id', userCredential!.user!.uid);
  await prefs.setString('cached_user_email', userCredential.user!.email ?? '');
  await prefs.setInt('last_login_timestamp', DateTime.now().millisecondsSinceEpoch);
  await prefs.setBool('has_logged_in_before', true);
}
```

Resultado: **ganamos la rúbrica de “Preferences/UserDefaults” con SharedPreferences** para la gestión de sesión y banderas offline.

---

## Conclusiones rápidas
- **Hive** (clave/valor) es nuestro caballo de batalla: hidrata caches de posts, chats, categorías, wishlist y cola de sincronización, alineado con el plan de conectividad eventual.
- **SharedPreferences** cubre la sesión ligera y banderas de arranque.
- **Relacional y archivos crudos** aún no se implementan en Flutter porque priorizamos consistencia y simplicidad multiplataforma; si la rúbrica exige evidencia, podemos explicar la justificación y el roadmap (ya implementado en Kotlin).

