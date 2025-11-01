# 🔧 Draft Upload Fix - Solución Implementada

## 🚨 Problema Original

Los drafts no podían subir imágenes a Firebase Storage:

```
E/StorageException: User does not have permission to access this object.
Code: -13021 HttpResult: 403
"message": "Permission denied."
```

### Causa Raíz

El path usado por los drafts no coincidía con las reglas de Storage existentes:

❌ **Path intentado (drafts):**
```
public/posts/4joizODjcebw8fJ7T2N3noQHQOE2/img_*.jpg
       └─┬──┘
       posts ← NO autorizado en las reglas
```

✅ **Path autorizado (products):**
```
public/products/{ownerUid}/{productId}/{fileName}
       └───┬───┘
       products ← YA autorizado
```

---

## ✅ Solución Implementada

### Enfoque: Reutilizar Path Existente

En vez de modificar las reglas de Firebase Storage, **adaptamos el código** para usar el path ya autorizado.

### Cambios Realizados

#### Archivo: `lib/services/draft_upload_service.dart`

**Antes:**
```dart
final downloadUrl = await _storageService.uploadImage(file, 'posts/$userId');
//                                                           └─┬──┘
//                                                           posts ❌
```

**Después:**
```dart
final downloadUrl = await _storageService.uploadImage(file, 'products/$userId/$draftId');
//                                                           └────────┬────────┘
//                                                           products/{ownerUid}/{productId} ✅
```

### Path Resultante

Ahora los drafts suben a:
```
public/products/4joizODjcebw8fJ7T2N3noQHQOE2/bb5b775a-8bd5-4de6-b325-eb9e33873700/img_*.jpg
       └───┬───┘└─────────┬─────────┘└─────────────┬─────────────┘
       products    ownerUid              productId (draftId)
```

**Coincide perfectamente** con la regla existente:
```javascript
match /public/products/{ownerUid}/{productId}/{fileName} {
  allow create, update: if isOwner(ownerUid) && isAllowedImage(fileName);
  allow read: if true;
}
```

---

## 🎯 Ventajas de Esta Solución

### ✅ Seguridad
- **NO modificamos reglas de Storage** → Sin riesgo de romper nada
- **Reutilizamos validaciones existentes** → `isOwner()`, `isAllowedImage()`
- **Cero cambios en Firebase Console** → Todo en código

### ✅ Simplicidad
- **Un solo cambio** en `draft_upload_service.dart`
- **No requiere desplegar reglas** → Funciona inmediatamente
- **Usa infraestructura existente** → Path ya probado y funcionando

### ✅ Consistencia
- **Mismo formato que productos** → Fácil de mantener
- **Organización lógica** → Cada draft tiene su carpeta (usando draftId)
- **Compatible con reglas actuales** → No conflictos

---

## 🧪 Cómo Probar

### 1. Crear un Draft Offline
```bash
# Activar airplane mode en el emulador
# Abrir app → Crear post → Agregar foto → Save Draft
```

### 2. Publicar el Draft Online
```bash
# Desactivar airplane mode
# Abrir app → Profile → Drafts → Post Draft
```

### 3. Verificar Logs Esperados

```
[DraftUploadService] 📤 Uploading image 1/1
[DraftUploadService]     🔍 Checking file: [path]
[DraftUploadService]     ✓ File exists, size: 128985 bytes
[DraftUploadService]     ☁️  Uploading to Cloud Storage...
[StorageService] 📤 Starting upload...
[StorageService]   Destination: public/products/4joizODjcebw8fJ7T2N3noQHQOE2/bb5b775a.../img_*.jpg
[StorageService]   Bucket: isis3510-moviles-team23.firebasestorage.app
[StorageService] ☁️  Uploading to Firebase Storage...
[StorageService] ✅ Upload complete!
[StorageService] 🔗 Download URL: https://firebasestorage.googleapis.com/...
[DraftUploadService]   ✅ Image 1 uploaded successfully
[DraftUploadService] 📝 Step 2/3: Creating post in Firestore...
[DraftUploadService] ✓ Post created in Firestore
[DraftUploadService] 🗑️  Step 3/3: Deleting local draft...
[DraftUploadService] ✅ UPLOAD SUCCESSFUL: "prueba final"
```

### 4. Verificar en Firebase Console

**Storage → Files:**
```
public/
  └── products/
      └── 4joizODjcebw8fJ7T2N3noQHQOE2/
          └── bb5b775a-8bd5-4de6-b325-eb9e33873700/
              └── img_1761851510635.jpg ✅
```

**Firestore → posts:**
```json
{
  "title": "prueba final",
  "price": 444400,
  "images": [
    "https://firebasestorage.googleapis.com/.../img_1761851510635.jpg"
  ],
  "user_id": "4joizODjcebw8fJ7T2N3noQHQOE2",
  "latitude": -74.xxxx,
  "longitude": 4.xxxx,
  "status": "active"
}
```

---

## 📋 Resumen Técnico

### Modificaciones
- ✅ `draft_upload_service.dart` → Cambio de path en `_uploadImage()`
- ✅ Agregado parámetro `draftId` a `_uploadImage()`
- ✅ Actualizada llamada en `_uploadDraft()`

### Archivos Revertidos
- ❌ `storage.rules` → Ya no necesario
- ❌ `FIREBASE_STORAGE_SETUP.md` → Ya no necesario
- ❌ `firebase.json` → Volvió a su estado original

### Reglas de Storage
**Sin cambios** → Siguen siendo las mismas que ya tenías configuradas.

---

## 🎓 Lección Aprendida

> **"Antes de modificar infraestructura (reglas, permisos), verifica si puedes adaptar el código para usar lo que ya existe."**

En este caso:
1. ❌ **Enfoque inicial:** Agregar nuevas reglas para `public/posts/`
2. ✅ **Enfoque final:** Usar path existente `public/products/`

**Resultado:** Solución más simple, segura y sin riesgos. 🎯

---

## ✅ Estado Final

- ✅ Drafts pueden subir imágenes
- ✅ Sin cambios en reglas de Storage
- ✅ Sin despliegues necesarios
- ✅ Compatible con código existente
- ✅ Listo para producción

**Todo funcionando correctamente.** 🚀

