# Guía de Integración - Sistema de Feedback

Esta guía explica cómo integrar el sistema de feedback en tu aplicación Flutter.

## 1. Instalar Dependencias

```bash
flutter pub get
```

Esto instalará las nuevas dependencias agregadas:
- `sqflite: ^2.3.0` (BD relacional)
- `path: ^1.8.3` (manejo de paths)

## 2. Inicializar Servicios en main.dart

Actualiza tu archivo `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'services/draft_feedback_service.dart';
import 'services/feedback_sql_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Inicialización existente...
  await Firebase.initializeApp();
  
  // Inicializar servicios de feedback
  await DraftFeedbackService().initialize();
  await FeedbackSqlService().initialize();
  
  runApp(const MyApp());
}
```

## 3. Agregar Rutas al Router

Actualiza tu archivo `lib/router.dart`:

```dart
import 'screens/feedback_form_screen.dart';
import 'screens/pending_feedback_screen.dart';

// En tu configuración de GoRouter o routing system:
final router = GoRouter(
  routes: [
    // ... tus rutas existentes
    
    GoRoute(
      path: '/feedback',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return FeedbackFormScreen(
          purchaseId: extra?['purchaseId'] ?? '',
          sellerId: extra?['sellerId'] ?? '',
          productTitle: extra?['productTitle'],
        );
      },
    ),
    
    GoRoute(
      path: '/pending-feedback',
      builder: (context, state) => const PendingFeedbackScreen(),
    ),
  ],
);
```

## 4. Navegar al Formulario de Feedback

Desde cualquier pantalla donde quieras permitir que el usuario deje feedback:

### Opción A: Con GoRouter

```dart
import 'package:go_router/go_router.dart';

// En tu widget:
ElevatedButton(
  onPressed: () {
    context.push(
      '/feedback',
      extra: {
        'purchaseId': sale.id,
        'sellerId': sale.sellerId,
        'productTitle': product.title,
      },
    );
  },
  child: const Text('Leave Feedback'),
)
```

### Opción B: Con Navigator tradicional

```dart
import 'screens/feedback_form_screen.dart';

// En tu widget:
ElevatedButton(
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackFormScreen(
          purchaseId: sale.id,
          sellerId: sale.sellerId,
          productTitle: product.title,
        ),
      ),
    );
  },
  child: const Text('Leave Feedback'),
)
```

## 5. Mostrar Drafts Pendientes

Desde tu pantalla de perfil o menú:

```dart
ListTile(
  leading: const Icon(Icons.pending_actions),
  title: const Text('Pending Feedback'),
  trailing: FutureBuilder<int>(
    future: _getDraftsCount(),
    builder: (context, snapshot) {
      if (snapshot.hasData && snapshot.data! > 0) {
        return CircleAvatar(
          radius: 12,
          backgroundColor: Colors.red,
          child: Text(
            '${snapshot.data}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    },
  ),
  onTap: () {
    context.push('/pending-feedback');
    // o Navigator.push(...)
  },
)

// Helper method:
Future<int> _getDraftsCount() async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final draftService = DraftFeedbackService();
    return await draftService.getDraftsCount(currentUser.uid);
  }
  return 0;
}
```

## 6. Integrar en Pantalla de Sales/Purchases

Ejemplo de integración en una pantalla de ventas completadas:

```dart
// En tu SaleDetailsScreen o similar:

class SaleDetailsScreen extends StatelessWidget {
  final Sale sale;
  
  const SaleDetailsScreen({super.key, required this.sale});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ... tu UI existente
      
      body: Column(
        children: [
          // ... información de la venta
          
          // Botón de feedback (solo si la venta está completada)
          if (sale.status == 'completed')
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () => _leaveFeedback(context),
                icon: const Icon(Icons.rate_review),
                label: const Text('Leave Feedback'),
              ),
            ),
        ],
      ),
    );
  }
  
  void _leaveFeedback(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FeedbackFormScreen(
          purchaseId: sale.id,
          sellerId: sale.sellerId,
          productTitle: sale.productTitle,
        ),
      ),
    );
  }
}
```

## 7. Agregar Indicador de Drafts Pendientes en AppBar

```dart
AppBar(
  title: const Text('My App'),
  actions: [
    // Badge con drafts pendientes
    FutureBuilder<int>(
      future: _getPendingDraftsCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        if (count == 0) return const SizedBox.shrink();
        
        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.cloud_upload),
              onPressed: () => context.push('/pending-feedback'),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  ],
)
```

## 8. Testing

### Test Básico

```dart
// En tu widget de test o en la consola de desarrollador:

import 'package:firebase_auth/firebase_auth.dart';
import 'services/draft_feedback_service.dart';
import 'services/feedback_sql_service.dart';

void testFeedbackSystem() async {
  // Test SQLite
  final sqlService = FeedbackSqlService();
  await sqlService.initialize();
  
  final count = await sqlService.getRatingsCount();
  print('Ratings in SQLite: $count');
  
  // Test Hive
  final draftService = DraftFeedbackService();
  await draftService.initialize();
  
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser != null) {
    final drafts = await draftService.getAllDrafts(currentUser.uid);
    print('Drafts in Hive: ${drafts.length}');
  }
}
```

### Test de Upload

1. Crear un feedback offline
2. Verificar que se guardó como draft
3. Activar conexión
4. Ir a "Pending Feedback"
5. Hacer clic en "Upload All"
6. Verificar en Firestore Console

## 9. Firestore Security Rules

Agrega estas reglas en Firebase Console:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Regla para feedback
    match /feedback/{feedbackId} {
      // Permitir crear solo si es el comprador
      allow create: if request.auth != null 
                    && request.auth.uid == request.resource.data.buyerId;
      
      // Permitir leer si eres el comprador o el vendedor
      allow read: if request.auth != null 
                  && (request.auth.uid == resource.data.buyerId 
                      || request.auth.uid == resource.data.sellerId);
      
      // Permitir actualizar solo si eres el comprador
      allow update: if request.auth != null 
                    && request.auth.uid == resource.data.buyerId;
      
      // Permitir borrar solo si eres el comprador
      allow delete: if request.auth != null 
                    && request.auth.uid == resource.data.buyerId;
    }
  }
}
```

## 10. Firebase Storage Rules

Para las imágenes de feedback:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /public/feedback/{userId}/{feedbackId}/{imageId} {
      // Permitir subir solo si es tu propio feedback
      allow write: if request.auth != null 
                   && request.auth.uid == userId;
      
      // Permitir leer cualquier imagen de feedback
      allow read: if true;
    }
  }
}
```

## 11. Monitoreo y Analytics

Agregar eventos de analytics (opcional):

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

// En FeedbackViewModel:
Future<bool> uploadFeedback() async {
  // ... código existente
  
  if (success) {
    // Log analytics event
    await FirebaseAnalytics.instance.logEvent(
      name: 'feedback_submitted',
      parameters: {
        'rating': rating,
        'has_images': imagePaths.isNotEmpty,
        'image_count': imagePaths.length,
      },
    );
  }
  
  return success;
}
```

## 12. Troubleshooting

### Error: "Database not initialized"

```dart
// Asegúrate de llamar initialize() antes de usar los servicios
await DraftFeedbackService().initialize();
await FeedbackSqlService().initialize();
```

### Error: "Box not found"

```dart
// Verifica que LocalStorageService incluya feedbackDraftsBoxName
// Ya está agregado en local_storage_service.dart
```

### Imágenes no se muestran

```dart
// Verifica permisos de almacenamiento en AndroidManifest.xml:
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
```

### Upload falla

```dart
// Verifica:
// 1. Conexión a internet
// 2. Reglas de Firestore
// 3. Reglas de Storage
// 4. Logs en debug console
```

## 13. Recursos Adicionales

- **Documentación completa**: `FEEDBACK_SYSTEM_DOCUMENTATION.md`
- **Modelos**: `lib/models/feedback_model.dart`, `lib/models/draft_feedback_model.dart`
- **Servicios**: `lib/services/feedback_sql_service.dart`, etc.
- **ViewModels**: `lib/view_models/feedback_view_model.dart`
- **Pantallas**: `lib/screens/feedback_form_screen.dart`, `lib/screens/pending_feedback_screen.dart`

## 14. Próximos Pasos

1. Instalar dependencias
2. Inicializar servicios en main.dart
3. Agregar rutas
4. Integrar en tu UI existente
5. Probar flujo completo
6. Configurar reglas de Firestore/Storage
7. Desplegar a producción

¡Listo! El sistema de feedback está completo y listo para usar. 🎉

