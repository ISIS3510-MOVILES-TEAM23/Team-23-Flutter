# Concurrencia y Asincronía en Flutter (Sprint 3)

## Resumen ejecutivo
- Cubrimos **Future handlers**, **async/await**, **Streams** y dejamos preparado el terreno para **Isolates** dentro de `BleService`.
- Las decisiones buscan sostener la experiencia *offline-first* descrita en `sprint_3_data.txt`, garantizando sincronización eventual y UI fluida.

---

## Futures con handler (`.then` / `catchError`) — 4 casos

- **Prefetch en segundo plano (bootstrap offline)**  
  Lanza la hidratación completa de caches sin bloquear el arranque y registra éxito/error para telemetría.

```
119:123:lib/main.dart
PrefetchService().prefetchAll().then((_) {
  debugPrint('✅ [App] Background prefetch completed');
}).catchError((e) {
  debugPrint('❌ [App] Background prefetch failed: $e');
});
```

- **Regreso desde el chat (mantener contadores frescos)**  
  Tras cerrar la pantalla de conversación, volvemos a cargar el inbox con `.then` para actualizar los badges de no leídos.

```
103:114:lib/screens/messages_screen.dart
context.push(
  '/chat',
  extra: {...},
).then((_) {
  viewModel.loadChats();
});
```

- **Streams offline de mensajes (hidratar al crear el StreamController)**  
  Reutilizamos el futuro que carga caché y, cuando termina, inyectamos el snapshot en el stream local.

```
322:333:lib/services/chat_service.dart
_loadCachedMessages(chatId).then((messages) {
  if (_messageControllers.containsKey(chatId) && !_messageControllers[chatId]!.isClosed) {
    _messageControllers[chatId]!.add(messages);
  }
});
```

- **Watcher de geolocalización (emitir estado inicial y errores)**  
  Al crear el stream periódicamente consultamos `isOnCampus()` y, con `.then/.catchError`, emitimos el valor inicial o propagamos fallos.

```
238:246:lib/services/on_campus_service.dart
isOnCampus().then((initial) {
  _lastOnCampusState = initial;
  _lastEmittedState = _lastOnCampusState;
  _onCampusController!.add(initial);
}).catchError((error) {
  _onCampusController!.addError(error);
});
```

---

## Futures con `async` / `await` — 4 ejemplos clave (de 209 totales)

1. **`PrefetchService.prefetchAll` — Paralelismo coordinado**  
   Ejecuta seis fetches en paralelo con `Future.wait`, cachea posts, wishlist, categorías y precarga imágenes para el modo offline.

```
36:55:lib/services/prefetch_service.dart
Future<void> prefetchAll() async {
  if (_isPrefetching || _isPrefetched) return;
  if (!_connectivity.isConnected) {
    debugPrint('[Prefetch] ⚠️ Offline - skipping prefetch');
    return;
  }
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
}
```

2. **`ChatService.getOrCreateProductChat` — Fallback offline con verificación de caché**  
   Si no hay red, valida que el producto esté en cache, genera un chat temporal y lo persiste localmente; online crea/recupera el chat real en Firestore.

```
29:88:lib/services/chat_service.dart
static Future<String> getOrCreateProductChat(String productId, String sellerId) async {
  final currentUserId = _auth.currentUser?.uid;
  if (currentUserId == null) throw StateError('User not authenticated');
  if (!_connectivity.isConnected) {
    final cachedPost = await _cache.getCachedPost(productId);
    if (cachedPost == null) {
      throw StateError('Cannot start new chat while offline without cached product. Please connect to internet.');
    }
    final offlineChatId = 'offline_${DateTime.now().millisecondsSinceEpoch}_$productId';
    await _cache.cacheChatInfo(offlineChatId, {...});
    return offlineChatId;
  }
  final existingChats = await _db.collection('chats')
      .where('product_id', isEqualTo: productId)
      .where('participant_ids', arrayContains: currentUserId)
      .get();
  // ... existing code ...
  final chatRef = await _db.collection('chats').add(chatData);
  return chatRef.id;
}
```

3. **`SyncQueueService._syncQueue` — Procesamiento secuencial con reintentos**  
   Cuando vuelve la red, extrae la cola de Hive, sincroniza cada item esperando `_syncItem`, maneja fallos y desbloquea `_isSyncing`.

```
88:111:lib/services/sync_queue_service.dart
Future<void> _syncQueue() async {
  if (_isSyncing) return;
  if (!_connectivity.isConnected) return;
  _isSyncing = true;
  try {
    final pendingItems = await getPendingItems();
    for (final item in pendingItems) {
      try {
        await _syncItem(item);
      } catch (e) {
        debugPrint('[SyncQueue] ✗ Failed to sync item ${item['id']}: $e');
      }
    }
  } finally {
    _isSyncing = false;
  }
}
```

4. **`ConnectivityService.waitForConnection` — Puente hacia la reconexión**  
   Suspende la llamada hasta que el stream de conectividad detecte señal o se agote el timeout.

```
91:112:lib/services/connectivity_service.dart
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
  Future.delayed(timeout, () {
    if (!completer.isCompleted) {
      completer.complete(false);
      subscription?.cancel();
    }
  });
  return completer.future;
}
```

---

## Streams — Observabilidad y datos en vivo

- **Chats del usuario (Firestore + cache offline)**  
  `snapshots().asyncMap` mantiene la lista reactiva, ordena por `updatedAt` y persiste la vista para escenarios offline.

```
155:220:lib/services/chat_service.dart
return _db.collection('chats')
    .where('participant_ids', arrayContains: currentUserId)
    .snapshots()
    .asyncMap((snapshot) async {
      final futures = snapshot.docs.map((doc) async { ... });
      final results = await Future.wait(futures);
      final validChats = results.where((chat) => chat != null).cast<ProductChat>().toList();
      validChats.sort((a, b) => /* orden descendente por fecha */);
      if (validChats.isNotEmpty) {
        await _cacheUserChats(validChats);
      }
      return validChats;
    });
```

- **Broadcast de conectividad (EvC)**  
  Un `StreamController.broadcast` reparte el estado de red a UI, cola y servicios de precarga.

```
13:28:lib/services/connectivity_service.dart
final StreamController<ConnectivityResult> _connectivityStreamController =
    StreamController<ConnectivityResult>.broadcast();
Stream<ConnectivityResult> get onConnectivityChanged =>
    _connectivityStreamController.stream;
```

- **Watcher de geofencing**  
  Combina `getPositionStream`, timer periódico y emisiones manuales para notificar cambios de on/off campus sin perder eventos.

```
187:249:lib/services/on_campus_service.dart
Stream<bool> watchOnCampus({Duration interval = const Duration(seconds: 10)}) {
  _onCampusController = StreamController<bool>.broadcast();
  _positionSubscription = Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((position) {
    final onCampus = /* cálculo de distancia */;
    if (_lastOnCampusState != _lastEmittedState) {
      _lastEmittedState = _lastOnCampusState;
      _onCampusController!.add(onCampus);
    }
  }, onError: (error) {
    _onCampusController!.addError(OnCampusException('Error in position stream', error));
  });
  // ... existing code ...
  return _onCampusController!.stream;
}
```

---

## Isolates

- **Preparado en `BleService`**  
  Declaramos campos para aislar procesamiento pesado de BLE (parseo de payloads grandes) y liberar el UI thread cuando la feature se active. Actualmente no se instancia ningún `Isolate.spawn`, así que la infraestructura está lista pero dormida.

```
22:25:lib/services/ble_service.dart
// Isolate management for data processing (if needed in future)
Isolate? _dataProcessingIsolate;
ReceivePort? _dataProcessingReceivePort;
```

---

## Próximos pasos sugeridos
- Activar el isolate en `BleService` cuando integremos procesamiento de paquetes (por ejemplo, desencriptar payloads o correlacionar múltiples beacons).
- Añadir métricas (logging/analytics) a los handlers para medir frecuencia de reintentos en la cola y tiempos de reconexión.
- Considerar `compute` o `Isolate.run` para tareas pesadas de IA (auto-completar post) si el modelo crece.

