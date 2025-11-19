# Vistas protegidas por Eventual Connectivity (Flutter · Sprint 3)

## Resumen
- Cada vista clave recibe tratamiento *offline-first*: validaciones antes de disparar llamadas críticas, fallback a Hive/CacheManager, y colas que sincronizan en cuanto vuelve la red.
- A continuación se listan **20 ejemplos** (máx. solicitado) con su efecto y el fragmento de código correspondiente.

---

## Catálogo de vistas/escenarios protegidos

1. **Login** – Bloquea intentos sin red y avisa al usuario.  
```
85:110:lib/view_models/login_view_model.dart
    isOffline = !_connectivity.isConnected;
    if (isOffline) {
      errorMessage =
          'Internet connection required for login. Please connect and try again.';
      notifyListeners();
      throw Exception(errorMessage);
    }
    // ... existing code ...
    if (userCredential?.user != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_user_id', userCredential!.user!.uid);
      // ... existing code ...
    }
```

2. **Signup** – Evita registros sin conectividad y muestra copy claro.  
```
60:68:lib/view_models/signup_view_model.dart
    isOffline = !_connectivity.isConnected;
    if (isOffline) {
      errorMessage =
          'Internet connection required to create account. Please connect and try again.';
      notifyListeners();
      throw Exception(errorMessage);
    }
```

3. **Home Feed** – Prefiere red, cae a Hive con TTL y filtra imágenes cacheadas.  
```
64:102:lib/view_models/home_view_model.dart
      if (_connectivity.isConnected) {
        // ... existing code ...
      } else {
        debugPrint('[Home] 📴 OFFLINE - Loading from cache');
        await _loadFromCache();
      }
```

4. **Home (primer arranque offline)** – Renderiza fallback con CTA “Retry”.  
```
571:608:lib/screens/home_screen.dart
  Widget _buildFirstTimeOfflineFallback(BuildContext context) {
    return Center(
      child: Padding(
        // ... existing code ...
        ElevatedButton.icon(
          onPressed: viewModel.loadProducts,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ),
    );
  }
```

5. **Home (reconexión automática)** – Re-hidrata secciones cuando vuelve la red.  
```
43:55:lib/screens/home_screen.dart
  void _setupConnectivityListener() {
    viewModel.connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && viewModel.isOffline) {
        viewModel.loadProducts();
        viewModel.loadNearbyProducts(limit: 10);
        setState(() {
          _recsFuture = RecommendationService()
              .fetchRecommendations(limit: 5, windowDays: 30, debug: true);
        });
      }
    });
  }
```

6. **Carrusel por carrera** – Carga desde cache si no hay red.  
```
215:260:lib/view_models/home_view_model.dart
      if (_connectivity.isConnected) {
        // ... existing code ...
      } else {
        final cached = await _cache.getCachedMajorBasedProducts();
        if (cached != null && cached.isNotEmpty) {
          majorBasedProducts =
              cached.map((json) => Post.fromJson(json)).toList();
          majorBasedTitle = 'Featured';
        }
      }
```

7. **Recomendaciones personalizadas** – Fallback a Hive cuando offline.  
```
279:309:lib/view_models/home_view_model.dart
      if (_connectivity.isConnected) {
        // ... existing code ...
      } else {
        final cached = await _cache.getCachedRecommendedProducts();
        if (cached != null && cached.isNotEmpty) {
          recommendedProducts =
              cached.map((json) => Post.fromJson(json)).toList();
        }
      }
```

8. **Búsqueda en Home** – Opera sobre `newProducts` ya cacheados, incluso sin red.  
```
369:378:lib/view_models/home_view_model.dart
  void applySearch(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      filteredNewProducts = List<Post>.from(newProducts);
    } else {
      filteredNewProducts = _filterProducts(trimmed);
    }
    notifyListeners();
  }
```

9. **Crear/abrir chat sin red** – Usa producto cacheado y genera ID temporal.  
```
38:68:lib/services/chat_service.dart
    if (!_connectivity.isConnected) {
      final cachedPost = await _cache.getCachedPost(productId);
      if (cachedPost == null) {
        throw StateError(
            'Cannot start new chat while offline without cached product.');
      }
      final offlineChatId =
          'offline_${DateTime.now().millisecondsSinceEpoch}_$productId';
      await _cache.cacheChatInfo(offlineChatId, offlineChatInfo);
      return offlineChatId;
    }
```

10. **Inbox (Messages)** – Stream híbrido: cache inmediato si no hay conexión.  
```
149:219:lib/services/chat_service.dart
    if (!_connectivity.isConnected) {
      return Stream.fromFuture(_loadCachedUserChats(currentUserId));
    }
    return _db.collection('chats')
        .where('participant_ids', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
          // ... existing code ...
          await _cacheUserChats(validChats);
          return validChats;
        });
```

11. **Historial de chat** – StreamController local + cache cuando offline.  
```
317:335:lib/services/chat_service.dart
    if (!_connectivity.isConnected || chatId.startsWith('offline_')) {
      if (!_messageControllers.containsKey(chatId)) {
        _messageControllers[chatId] =
            StreamController<List<ChatMessage>>.broadcast();
        _loadCachedMessages(chatId).then((messages) {
          _messageControllers[chatId]!.add(messages);
        });
      }
      return _messageControllers[chatId]!.stream;
    }
```

12. **Enviar mensaje sin red** – Cola en Hive + UI optimista.  
```
586:628:lib/services/chat_service.dart
    if (!_connectivity.isConnected) {
      final messageId = await _syncQueue.queueMessage(
        chatId: chatId,
        senderId: currentUserId,
        content: text?.trim() ?? '',
      );
      final localMessage = {
        'id': messageId,
        'sender_id': currentUserId,
        'content': text?.trim(),
        'status': 'queued',
      };
      final cachedMessages =
          await _cache.getCachedChatMessages(chatId) ?? [];
      cachedMessages.insert(0, localMessage);
      await _cache.cacheChatMessages(chatId, cachedMessages);
      await _refreshOfflineMessages(chatId);
      return;
    }
```

13. **Indicador visual “Queued”** – Reloj en burbuja mientras la cola sincroniza.  
```
557:572:lib/screens/chat_screen.dart
                            if (isMe && message.isPending) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.access_time,
                                size: 12,
                                color: isMe ? Colors.white70 : Colors.black54,
                              ),
                            ],
```

14. **Wishlist** – Sirve de Hive cuando falla la red y mantiene totales.  
```
28:71:lib/view_models/wish_list_view_model.dart
      if (_connectivity.isConnected) {
        // ... existing code ...
      } else {
        final cached = await _cache.getCachedWishList();
        if (cached != null) {
          wishItems =
              cached.map((json) => WishListItem.fromJson(json)).toList();
          _isLoadedFromCache = true;
        }
      }
```

15. **Thumbnails offline** – `OfflineNetworkImage` reutiliza `cached_network_image`.  
```
10:45:lib/widgets/offline_network_image.dart
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
      errorWidget: (context, url, error) =>
          errorChild ?? _defaultError(),
    );
  }
```

16. **Categories** – Cache de catálogo + degradado cuando no hay datos.  
```
32:61:lib/view_models/categories_view_model.dart
      if (_connectivity.isConnected) {
        cats = await _categoryRepository.getCategories();
        await _cache.cacheCategories(cats.map((c) => c.toJson()).toList());
      } else {
        final cached = await _cache.getCachedCategories();
        if (cached != null) {
          cats = cached.map((json) => Category.fromJson(json)).toList();
          isLoadedFromCache = true;
        }
      }
```

17. **Product Detail** – Reutiliza cache (post + seller) si Firestore falla u offline.  
```
36:92:lib/view_models/product_detail_view_model.dart
      if (_connectivity.isConnected) {
        prod = await _postRepository.getPostById(productId);
        if (prod != null) {
          await _cache.cachePost(productId, prod.toJson());
          user = await _userRepository.getUserById(prod.userId);
          if (user != null) {
            await _cache.cacheUser(prod.userId, user.toJson());
          }
        }
      } else {
        final cached = await _getCachedPostData(productId);
        if (cached != null) {
          prod = Post.fromJson(cached);
          final cachedUser = await _cache.getCachedUser(prod.userId);
          if (cachedUser != null) {
            user = User.fromJson(cachedUser);
          }
        }
      }
```

18. **Cola de sincronización global** – Persiste en Hive y se reactiva con la red.  
```
22:52:lib/services/sync_queue_service.dart
  Future<String> queueMessage({
    required String chatId,
    required String senderId,
    required String content,
  }) async {
    final clientId = _uuid.v4();
    final queueItem = {..., 'status': 'pending'};
    await _storage.save(LocalStorageService.syncQueueBoxName,
        clientId, jsonEncode(queueItem));
    if (_connectivity.isConnected) {
      _syncQueue();
    }
    return clientId;
  }
```
```
168:175:lib/services/sync_queue_service.dart
  void startAutoSync() {
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _syncQueue();
      }
    });
  }
```

19. **Prefetch al arranque** – Hidrata Hive + imágenes para navegar sin red.  
```
36:63:lib/services/prefetch_service.dart
  Future<void> prefetchAll() async {
    if (_isPrefetching || _isPrefetched) return;
    if (!_connectivity.isConnected) return;
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

20. **Esperar reconexión** – Utilidad para operaciones que dependen de la red.  
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

## Escenarios no cubiertos (para transparencia)
- **Crear post completamente offline**: la app Flutter exige conexión para subir imágenes y publicar; la lógica de borradores locales solo quedó implementada en la versión Kotlin. Implementarlo aquí requeriría serializar el formulario en archivos o Hive y sincronizar con Storage cuando vuelva la red.
- **ConfirmPurchase sin internet**: la pantalla actual asume conectividad para actualizar el estado en Firestore. Deshabilitar la acción offline está en backlog.

Con esto demostramos los casos vigentes y aclaramos las brechas que aún no tienen soporte de Eventual Connectivity en el cliente Flutter.

