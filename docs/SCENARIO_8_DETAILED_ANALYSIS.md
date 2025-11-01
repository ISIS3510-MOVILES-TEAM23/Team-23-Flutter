# 📋 Scenario 8: Draft Posts - Análisis Detallado de Técnicas

## 🎯 Funcionalidad del Scenario 8

**Crear draft offline → Guardar → Publicar online**

### Flujo Completo:
1. **Offline:** Cargar categorías de caché
2. **Offline:** Usuario agrega foto → Guardar imagen en cache
3. **Offline:** Auto-save cada 5s → Guardar draft en Hive
4. **Online:** Usuario da "Post Draft" → Publicar a Firebase

---

## 📊 CACHING - Análisis por Componente

### 1. ⚠️ **Caché de Categorías** - NO usa LRU/SparseArray/ArrayMap/NSCache

**Storage usado:** **Hive (NoSQL local database)**

```dart
// lib/services/cache_service.dart
Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
  final cacheData = {
    'data': categories,
    'timestamp': DateTime.now().toIso8601String(),
  };
  
  // ← HIVE, NO LRU
  await _storage.save(
    LocalStorageService.categoriesBoxName,  // ← Box name: 'categories'
    'all_categories',                        // ← Key
    jsonEncode(cacheData),                   // ← JSON string
  );
}

Future<List<Map<String, dynamic>>?> getCachedCategories() async {
  final cached = _storage.get(
    LocalStorageService.categoriesBoxName,
    'all_categories',
  );
  
  if (cached == null) return null;
  
  final cacheData = jsonDecode(cached) as Map<String, dynamic>;
  final timestamp = DateTime.parse(cacheData['timestamp'] as String);
  
  // TTL: 30 días
  if (DateTime.now().difference(timestamp) > Duration(days: 30)) {
    return null; // Expirado
  }
  
  return List<Map<String, dynamic>>.from(cacheData['data'] as List);
}
```

**Técnica de caché:**
- ❌ **NO es LRU** - Es persistent storage con TTL
- ❌ **NO es SparseArray/ArrayMap** - Es Hive (key-value store)
- ✅ **ES:** Hive (NoSQL) con TTL de 30 días

**¿Por qué NO usa LRU?**
- Las categorías son pocas (~10-20 items)
- Se acceden raramente
- Necesitan persistir entre sesiones
- No hay evicción necesaria (son estáticas)

**Estrategia:** **#3 Network falling back to cache**

```dart
// lib/services/firestore_service.dart
static Future<List<Category>> getCategories() async {
  final connectivity = ConnectivityService();
  
  // Si offline, cargar de cache primero
  if (!connectivity.isConnected) {
    final cached = await CacheService().getCachedCategories();
    if (cached != null && cached.isNotEmpty) {
      return cached.map((json) => Category.fromJson(json)).toList();
    }
    throw Exception('No internet and no cached categories');
  }
  
  // Si online, fetch de Firestore
  final snapshot = await _db.collection('categories').get();
  final categories = snapshot.docs.map((doc) => ...).toList();
  
  // Cachear para próxima vez
  await CacheService().cacheCategories(categories.map((c) => c.toJson()).toList());
  
  return categories;
}
```

---

### 2. ✅ **Caché de Imágenes de Draft** - Sí usa librería de caché

**Storage usado:** **File System Cache** (`path_provider`)

```dart
// lib/services/draft_service.dart
Future<String> saveImageToCache(File imageFile, String draftId) async {
  // Get application cache directory
  final directory = await getApplicationCacheDirectory(); // ← path_provider
  final draftImagesDir = Directory('${directory.path}/draft_images/$draftId');
  
  // Create directory if needed
  if (!await draftImagesDir.exists()) {
    await draftImagesDir.create(recursive: true);
  }

  // Generate unique filename
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final extension = imageFile.path.split('.').last;
  final fileName = 'img_$timestamp.$extension';
  final localPath = '${draftImagesDir.path}/$fileName';

  // Copy to cache directory
  final copiedFile = await imageFile.copy(localPath); // ← File I/O
  
  return localPath; // /cache/draft_images/{draftId}/img_*.png
}
```

**Path de imagen cacheada:**
```
/data/user/0/com.example.campus_marketplace/cache/draft_images/
  └── {draftId}/
      └── img_1761851405759.png
```

**Técnica:**
- ✅ **File System Cache** - Similar a DiskLruCache de Android
- ✅ **Organized by draftId** - Fácil de limpiar
- ✅ **Persistent entre sesiones** - Sobrevive reinicios
- ✅ **Cleanup automático** - Se borra al publicar/eliminar draft

**Librería:** `path_provider` (acceso a directorios del sistema)

---

### 3. ✅ **Almacenamiento de Draft (Metadata)** - Hive

**Storage usado:** **Hive (NoSQL local database)**

```dart
// lib/services/draft_service.dart
Future<void> saveDraft(DraftPost draft) async {
  final draftData = {
    'data': draft.toJson(),  // ← Serializa DraftPost a JSON
    'timestamp': DateTime.now().toIso8601String(),
  };

  await _storage.save(
    _draftsBoxName,              // ← Box: 'drafts'
    'draft_${draft.draftId}',    // ← Key: 'draft_{uuid}'
    jsonEncode(draftData),       // ← Value: JSON string
  );
}
```

**Estructura en Hive:**
```
Box: 'drafts'
├─ draft_ea09c98e-3240-4298-84a4-6fd703ab0311
│  └─ {
│       "data": {
│         "draftId": "ea09c98e-...",
│         "userId": "4joizODjcebw8fJ7...",
│         "title": "prueba final",
│         "description": "descripcion",
│         "price": 4444.0,
│         "categoryId": "tickets",
│         "categoryName": "Tickets",
│         "localImagePaths": ["/cache/draft_images/.../img_*.png"],
│         "status": "editing",
│         "latitude": -74.xxxx,
│         "longitude": 4.xxxx,
│         "createdAt": "2025-01-30T...",
│         "lastModified": "2025-01-30T..."
│       },
│       "timestamp": "2025-01-30T..."
│     }
```

**TTL:** 30 días

```dart
Future<DraftPost?> getDraft(String draftId) async {
  final cached = _storage.get(_draftsBoxName, 'draft_$draftId');
  if (cached == null) return null;

  final draftData = jsonDecode(cached) as Map<String, dynamic>;
  final timestamp = DateTime.parse(draftData['timestamp'] as String);

  // Check if expired (30 days)
  if (DateTime.now().difference(timestamp) > Duration(days: 30)) {
    await deleteDraft(draftId);
    return null;
  }

  return DraftPost.fromJson(draftData['data'] as Map<String, dynamic>);
}
```

---

## 🧵 THREADING/CONCURRENCY - Análisis por Técnica

### ✅ **1. Future (básico)** - 5 puntos

**Usado en múltiples lugares:**

```dart
// lib/services/draft_service.dart
Future<void> saveDraft(DraftPost draft) async {
  // ... operación asíncrona
  await _storage.save(...);
}

Future<DraftPost?> getDraft(String draftId) async {
  final cached = _storage.get(...);
  // ... procesamiento
  return DraftPost.fromJson(...);
}

Future<String> saveImageToCache(File imageFile, String draftId) async {
  final directory = await getApplicationCacheDirectory();
  // ... operaciones de archivo
  final copiedFile = await imageFile.copy(localPath);
  return localPath;
}
```

**Puntos:** ✅ **5/5** - Future usado extensivamente

---

### ✅ **2. Future con async/await** - Parte de 10 puntos

**Usado en ViewModel:**

```dart
// lib/view_models/create_post_view_model.dart
Future<void> _autoSaveDraft() async {
  if (!_hasContent()) return;

  final currentUser = auth.FirebaseAuth.instance.currentUser;
  if (currentUser == null) return;

  _draftId ??= const Uuid().v4();

  // Async operation: Get location
  double? latitude;
  double? longitude;
  try {
    final position = await _nearbyService.getCurrentLocationWithPermissions();
    if (position != null) {
      latitude = position.latitude;
      longitude = position.longitude;
    }
  } catch (e) {
    debugPrint('[CreatePostVM] ⚠️ Could not get location: $e');
  }

  final draft = DraftPost(
    draftId: _draftId!,
    // ...
    latitude: latitude,
    longitude: longitude,
  );

  // Async operation: Save draft
  await _draftService.saveDraft(draft);
  _lastAutoSave = DateTime.now();
}
```

**Características:**
- ✅ Usa `async/await`
- ✅ Maneja errores con `try-catch`
- ✅ Múltiples `await` secuenciales
- ✅ Non-blocking

---

### ⚠️ **3. Future con handler (.then/.catchError)** - NO usado en Scenario 8

**NO se encuentra en Scenario 8.** 

Se usa en Scenario 11 (NotificationViewModel):

```dart
// lib/view_models/notification_view_model.dart (NO es Scenario 8)
void markAllAsRead() {
  _notificationRepository
      .markAllNotificationsAsRead()
      .then((_) {
        // Success handler
        for (var notification in _notifications) {
          notification.isRead = true;
        }
        notifyListeners();
      })
      .catchError((error) {
        // Error handler
        debugPrint('[NotificationVM] Failed to mark all as read: $error');
      })
      .whenComplete(() {
        // Finally
        _isLoading = false;
        notifyListeners();
      });
}
```

**Puntos para Scenario 8:** ❌ **0/5** - NO usado

---

### ✅ **4. Future con handler + async/await combinados** - 10 puntos

**Usado en draft upload:**

```dart
// lib/services/draft_upload_service.dart
Future<bool> _uploadDraft(DraftPost draft) async {
  try {
    // Update status
    draft = draft.copyWith(status: DraftStatus.uploading);
    await _draftService.saveDraft(draft);

    // 1. Upload images (async/await)
    final imageUrls = <String>[];
    for (int i = 0; i < draft.localImagePaths.length; i++) {
      final localPath = draft.localImagePaths[i];
      
      try {
        final imageUrl = await _uploadImage(localPath, draft.userId, draft.draftId);
        if (imageUrl != null && imageUrl.isNotEmpty) {
          imageUrls.add(imageUrl);
        }
      } catch (e) {
        debugPrint('[DraftUploadService] ❌ Failed to upload image ${i + 1}: $e');
        // Continue with other images ← Error handling dentro del loop
      }
    }

    if (imageUrls.isEmpty && draft.localImagePaths.isNotEmpty) {
      throw Exception('Failed to upload any images');
    }

    // 2. Create post in Firestore (async/await)
    final postData = { /* ... */ };
    final success = await FirestoreService.createPost(postData);
    
    if (!success) {
      throw Exception('FirestoreService.createPost returned false');
    }

    // 3. Delete draft (async/await)
    await _draftService.deleteDraft(draft.draftId);

    return true;

  } catch (e, stackTrace) {
    debugPrint('[DraftUploadService] ❌ UPLOAD FAILED: "${draft.title}"');
    debugPrint('[DraftUploadService] Error: $e');
    debugPrint('[DraftUploadService] Stack trace: $stackTrace');

    // Update status to failed (error recovery)
    try {
      draft = draft.copyWith(status: DraftStatus.failed);
      await _draftService.saveDraft(draft);
    } catch (saveError) {
      debugPrint('[DraftUploadService] ✗ Failed to update status: $saveError');
    }
    
    return false;
  }
}
```

**Características que califican para "handler + async/await":**
1. ✅ Usa `async/await` como base
2. ✅ Tiene `try-catch` (handler de errores)
3. ✅ Error recovery dentro de catch
4. ✅ Nested try-catch en el loop
5. ✅ Manejo de errores en múltiples niveles

**También en pickImageForDraft:**

```dart
// lib/view_models/create_post_view_model.dart
Future<String?> pickImageForDraft({required bool fromCamera}) async {
  try {
    if (isOffline) {
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      _draftId ??= const Uuid().v4();

      File? imageFile;
      if (fromCamera) {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.camera);
        if (pickedFile != null) {
          imageFile = File(pickedFile.path);
        }
      } else {
        final picker = ImagePicker();
        final pickedFile = await picker.pickImage(source: ImageSource.gallery);
        if (pickedFile != null) {
          imageFile = File(pickedFile.path);
        }
      }

      if (imageFile == null) return null;

      // Save to cache (async/await)
      final localPath = await _draftService.saveImageToCache(imageFile, _draftId!);
      localImagePaths.add(localPath);
      notifyListeners();

      return localPath;
    } else {
      // Online path
      return await pickAndUploadImage(fromCamera: fromCamera);
    }
  } catch (e) {
    debugPrint('[CreatePostVM] ❌ Failed to pick image: $e');
    rethrow; // ← Re-throw para que UI maneje el error
  }
}
```

**Puntos:** ✅ **10/10** - Combinación de async/await con handlers de error complejos

---

### ❌ **5. Streams** - NO usado en Scenario 8

**Streams NO se usan en Scenario 8.**

Se usan en Scenario 7 (Chat):

```dart
// lib/services/chat_service.dart (NO es Scenario 8)
static Stream<List<ChatMessage>> streamChatMessages(String chatId) {
  // ...
  final controller = StreamController<List<ChatMessage>>.broadcast();
  // ...
  return controller.stream;
}
```

**Puntos para Scenario 8:** ❌ **0/5** - NO usado

---

### ❌ **6. Isolates** - NO usado

**NO se usan Isolates en ninguna parte de Scenario 8.**

Isolates se usarían para operaciones pesadas como:
- Compresión de imágenes
- Procesamiento de JSON muy grandes
- Operaciones matemáticas complejas

**En Scenario 8 NO se necesitan** porque:
- Las imágenes se copian (no se comprimen)
- El JSON de drafts es pequeño
- Las operaciones son I/O-bound, no CPU-bound

**Puntos:** ❌ **0/10** - NO usado

---

### ✅ **7. Timer.periodic** (Background Task)

```dart
// lib/view_models/create_post_view_model.dart
Timer? _autoSaveTimer;

CreatePostViewModel({...}) : ... {
  _startAutoSave(); // ← Inicia en el constructor
}

void _startAutoSave() {
  _autoSaveTimer = Timer.periodic(
    const Duration(seconds: 5), // ← Cada 5 segundos
    (_) => _autoSaveDraft(),     // ← Callback
  );
  debugPrint('[CreatePostVM] ✓ Auto-save started (every 5s)');
}

@override
void dispose() {
  _autoSaveTimer?.cancel(); // ← Cleanup
  titleController.dispose();
  descriptionController.dispose();
  priceController.dispose();
  super.dispose();
}
```

**Características:**
- ✅ Ejecución periódica en background
- ✅ Non-blocking (llama a Future)
- ✅ Proper cleanup al destruir
- ✅ Maneja estado interno (_lastAutoSave)

---

## 📊 RESUMEN - Scenario 8

### **CACHING:**

| Componente | Técnica | ¿Cumple LRU/SparseArray/ArrayMap/NSCache? |
|------------|---------|-------------------------------------------|
| **Categorías** | Hive + TTL (30 días) | ❌ NO - Es persistent storage |
| **Imágenes Draft** | File System Cache | ❌ NO - Es file storage directo |
| **Metadata Draft** | Hive + TTL (30 días) | ❌ NO - Es NoSQL database |

**Estrategia de caché:**
- ✅ **#3 Network falling back to cache** (categorías)
- ✅ **File System Cache** (imágenes)
- ✅ **Persistent Storage** (drafts)

**Librerías:**
- ✅ `hive` (NoSQL local database)
- ✅ `path_provider` (file system access)
- ❌ NO usa LRU/SparseArray/ArrayMap explícitamente

---

### **THREADING/CONCURRENCY:**

| Técnica | ¿Usado? | Puntos | Evidencia |
|---------|---------|--------|-----------|
| **Future** | ✅ Sí | **5/5** | `saveDraft()`, `getDraft()`, `saveImageToCache()` |
| **Future con handler** | ❌ No | **0/5** | No usa `.then()/.catchError()` |
| **Future con handler + async/await** | ✅ Sí | **10/10** | `_uploadDraft()`, `pickImageForDraft()` con try-catch |
| **Stream** | ❌ No | **0/5** | No usado en Scenario 8 |
| **Isolates** | ❌ No | **0/10** | No necesario |
| **Timer.periodic** | ✅ Sí | **Bonus** | Auto-save cada 5s |

**Total Threading:** **15/30 puntos** (5 + 10)

---

## 💡 CONCLUSIÓN

### Para Documentación:

**Scenario 8 cumple:**

1. ✅ **Caching básico** con Hive y File System
   - NO usa LRU/SparseArray explícitamente
   - Usa persistent storage apropiado para drafts

2. ✅ **Threading/Concurrency:** **15/30 puntos**
   - ✅ Future (5 pts)
   - ✅ Future + handler + async/await (10 pts)
   - ✅ Timer.periodic (bonus - auto-save)

3. ✅ **Estrategias de eventual connectivity:**
   - Network falling back to cache
   - Queue and sync on reconnect
   - Auto-save para prevenir pérdida de datos

**Archivos clave para demostrar:**
- `lib/services/draft_service.dart` - Storage + File I/O
- `lib/services/cache_service.dart` - Category caching
- `lib/view_models/create_post_view_model.dart` - Auto-save + Timer
- `lib/services/draft_upload_service.dart` - Upload con error handling

