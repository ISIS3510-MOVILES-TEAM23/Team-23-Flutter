import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../services/recommendation_service.dart';

/// Servicio para manejar notificaciones push con Firebase Cloud Messaging
class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  /// Inicializa el servicio de notificaciones
  /// Solicita permisos y guarda el token FCM del usuario
  static Future<void> initialize() async {
    try {
      // Solicitar permisos de notificaciones (iOS principalmente)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      debugPrint('📱 Notification permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Obtener el token FCM
        final token = await _messaging.getToken();
        if (token != null) {
          debugPrint('📱 FCM Token: $token');
          await _saveFCMToken(token);
        }

        // Escuchar cambios en el token
        _messaging.onTokenRefresh.listen(_saveFCMToken);

        // Configurar handlers de notificaciones
        _setupMessageHandlers();
      } else {
        debugPrint('❌ Notification permission denied');
      }
    } catch (e) {
      debugPrint('❌ Error initializing notifications: $e');
    }
  }

  /// Guarda el token FCM del usuario en Firestore
  static Future<void> _saveFCMToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('⚠️ No user logged in, skipping FCM token save');
        return;
      }

      await _db.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ FCM token saved for user ${user.uid}');
    } catch (e) {
      debugPrint('❌ Error saving FCM token: $e');
    }
  }

  /// Configura los handlers para diferentes tipos de mensajes
  static void _setupMessageHandlers() {
    // Handler para mensajes en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Got a message in foreground!');
      debugPrint('Message data: ${message.data}');

      if (message.notification != null) {
        debugPrint('Message notification: ${message.notification!.title}');
        debugPrint('Message body: ${message.notification!.body}');
        // Aquí puedes mostrar una notificación local si quieres
      }
    });

    // Handler para cuando el usuario toca la notificación (app cerrada)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Message clicked!');
      debugPrint('Message data: ${message.data}');
      // Aquí puedes navegar a la pantalla del producto
      // Por ejemplo: navigateToProduct(message.data['postId'])
    });
  }

  /// Envía notificaciones a usuarios interesados cuando se crea un nuevo post
  /// Este método se llama desde CreatePostViewModel después de crear el post
  static Future<void> notifyInterestedUsers({
    required String postId,
    required String postTitle,
    required String categoryName,
    required int price,
    required String ownerId,
  }) async {
    try {
      debugPrint('🔔 Starting notification process for post: $postId');

      // 1. Obtener todos los usuarios (excepto el dueño del post)
      final usersSnapshot = await _db
          .collection('users')
          .where('fcmToken', isNotEqualTo: null)
          .get();

      debugPrint('👥 Found ${usersSnapshot.docs.length} users with FCM tokens');

      // Crear un servicio de recomendaciones
      final recService = RecommendationService();

      // 2. Para cada usuario, verificar si le interesa esta categoría
      for (final userDoc in usersSnapshot.docs) {
        final userId = userDoc.id;
        final userData = userDoc.data();
        final fcmToken = userData['fcmToken'] as String?;

        // Saltar al dueño del post
        if (userId == ownerId) {
          debugPrint('⏭️ Skipping owner: $userId');
          continue;
        }

        if (fcmToken == null) {
          debugPrint('⚠️ User $userId has no FCM token');
          continue;
        }

        // Obtener categorías favoritas del usuario usando el servicio de recomendaciones
        final topCategories = await _getUserTopCategories(userId, recService);

        debugPrint('🔍 User $userId top categories: $topCategories');

        // Verificar si la categoría del post está en las favoritas
        if (topCategories.contains(categoryName)) {
          debugPrint('✅ Sending notification to user $userId for category "$categoryName"');

          // Crear la notificación en Firestore
          // Firebase puede enviarla automáticamente con Cloud Messaging
          await _createNotificationDocument(
            userId: userId,
            fcmToken: fcmToken,
            postId: postId,
            postTitle: postTitle,
            categoryName: categoryName,
            price: price,
          );
        } else {
          debugPrint('⏭️ User $userId not interested in "$categoryName"');
        }
      }

      debugPrint('✅ Notification process completed for post: $postId');
    } catch (e, st) {
      debugPrint('❌ Error in notifyInterestedUsers: $e');
      debugPrint('Stack trace: $st');
    }
  }

  /// Obtiene las categorías más vistas por un usuario
  static Future<List<String>> _getUserTopCategories(
    String userId,
    RecommendationService recService,
  ) async {
    try {
      // Reutilizar la lógica del servicio de recomendaciones
      final windowDays = 30;
      const topN = 3;

      // Obtener pesos de categorías (similar a fetchRecommendations pero solo categorías)
      final since = Timestamp.fromDate(
        DateTime.now().subtract(Duration(days: windowDays)),
      );

      const double W_CLICK = 5.0;
      const double W_SELECT = 3.0;
      const double W_SUGG = 1.0;

      final Map<String, double> catWeights = {};

      // 1) Clicks
      final clickSnap = await _db
          .collection('product_click_events')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: since)
          .orderBy('timestamp')
          .get();

      for (final doc in clickSnap.docs) {
        final data = doc.data();
        String? catName;

        final dynamic postRef = data['post_ref'];
        if (postRef != null) {
          try {
            DocumentSnapshot<Map<String, dynamic>>? snap;
            if (postRef is DocumentReference) {
              snap = await (postRef as DocumentReference<Map<String, dynamic>>).get();
            } else if (postRef is String) {
              var path = postRef.trim();
              if (path.startsWith('/')) path = path.substring(1);
              if (!path.contains('/')) path = 'posts/$path';
              snap = await _db.doc(path).get();
            }
            if (snap != null && snap.exists) {
              final pdata = snap.data()!;
              catName = (pdata['category_name'] as String?)?.trim();
            }
          } catch (_) {}
        }
        catName ??= (data['category'] as String?)?.trim();

        if (catName != null && catName.isNotEmpty) {
          catWeights[catName] = (catWeights[catName] ?? 0) + W_CLICK;
        }
      }

      // 2) Búsquedas
      final searchSnap = await _db
          .collection('product_search_events')
          .where('userId', isEqualTo: userId)
          .where('timestamp', isGreaterThanOrEqualTo: since)
          .orderBy('timestamp')
          .get();

      for (final doc in searchSnap.docs) {
        final data = doc.data();

        String? selName;
        final dynamic sel = data['selectedCategory'];
        try {
          if (sel is DocumentReference) {
            final s = await sel.get();
            selName = (s.data() as Map?)?['name'] as String? ?? sel.id;
          } else if (sel is String) {
            var path = sel.trim();
            if (path.startsWith('/')) path = path.substring(1);
            if (!path.contains('/')) path = 'categories/$path';
            final s = await _db.doc(path).get();
            selName = (s.data() as Map?)?['name'] as String? ?? path.split('/').last;
          }
        } catch (_) {}
        if (selName != null && selName.isNotEmpty) {
          catWeights[selName] = (catWeights[selName] ?? 0) + W_SELECT;
        }

        final List<dynamic> sugg =
            (data['suggestedCategories'] as List<dynamic>?) ?? const [];
        for (final s in sugg) {
          String? nm;
          try {
            if (s is DocumentReference) {
              final ds = await s.get();
              nm = (ds.data() as Map?)?['name'] as String? ?? s.id;
            } else if (s is String) {
              var path = s.trim();
              if (path.startsWith('/')) path = path.substring(1);
              if (!path.contains('/')) path = 'categories/$path';
              final ds = await _db.doc(path).get();
              nm = (ds.data() as Map?)?['name'] as String? ?? path.split('/').last;
            }
          } catch (_) {}
          if (nm != null && nm.isNotEmpty) {
            catWeights[nm] = (catWeights[nm] ?? 0) + W_SUGG;
          }
        }
      }

      // Ordenar por peso y retornar top N
      final sortedCategories = catWeights.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedCategories.take(topN).map((e) => e.key).toList();
    } catch (e) {
      debugPrint('❌ Error getting top categories for user $userId: $e');
      return [];
    }
  }

  /// Crea un documento de notificación en Firestore
  /// Esto se puede usar para llevar registro o para enviar desde un backend
  static Future<void> _createNotificationDocument({
    required String userId,
    required String fcmToken,
    required String postId,
    required String postTitle,
    required String categoryName,
    required int price,
  }) async {
    try {
      await _db.collection('notifications').add({
        'userId': userId,
        'fcmToken': fcmToken,
        'type': 'new_product',
        'postId': postId,
        'title': '🆕 Nuevo en $categoryName',
        'body': '$postTitle - \$${(price / 100).toStringAsFixed(2)}',
        'data': {
          'postId': postId,
          'categoryName': categoryName,
        },
        'sent': false, // Se marca como true cuando se envía
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('✅ Notification document created for user $userId');

      // TODO: Aquí podrías integrar con una Cloud Function o
      // usar el Admin SDK desde un backend para enviar la notificación real
      // Por ahora, solo creamos el documento en Firestore
    } catch (e) {
      debugPrint('❌ Error creating notification document: $e');
    }
  }
}

