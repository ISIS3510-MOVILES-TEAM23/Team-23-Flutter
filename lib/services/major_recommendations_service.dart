import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/models.dart';

/// Servicio para obtener recomendaciones basadas en vistas de usuarios con el mismo major
class MajorRecommendationsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  /// Obtiene el major del usuario actual
  Future<String?> getCurrentUserMajor() async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return null;

      final currentUserDoc = await _db.collection('users').doc(currentUserId).get();
      if (!currentUserDoc.exists) return null;

      final currentUserData = currentUserDoc.data()!;
      return currentUserData['major'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Obtiene posts más vistos por usuarios con el mismo major que el usuario actual
  /// Si no hay usuarios con el mismo major, usa todos los usuarios
  Future<List<Post>> getPostsByMajor({
    int limit = 4,
    int windowDays = 30,
    bool debug = false,
  }) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        if (debug) print('🎓 [MajorRecs] No hay usuario autenticado');
        return [];
      }

      // 1. Obtener el major del usuario actual
      final currentUserDoc = await _db.collection('users').doc(currentUserId).get();
      if (!currentUserDoc.exists) {
        if (debug) print('🎓 [MajorRecs] Usuario no encontrado en Firestore');
        return [];
      }

      final currentUserData = currentUserDoc.data()!;
      final currentMajor = currentUserData['major'] as String?;
      
      if (debug) print('🎓 [MajorRecs] Usuario actual: $currentUserId, Major: $currentMajor');

      List<String> targetUserIds = [];

      // 2. Si tiene major, buscar usuarios con el mismo major
      if (currentMajor != null && currentMajor.isNotEmpty) {
        final usersSnapshot = await _db
            .collection('users')
            .where('major', isEqualTo: currentMajor)
            .get();

        targetUserIds = usersSnapshot.docs
            .map((doc) => doc.id)
            .where((id) => id != currentUserId) // Excluir usuario actual
            .toList();

        if (debug) {
          print('🎓 [MajorRecs] Usuarios con major "$currentMajor": ${targetUserIds.length}');
        }
      }

      // 3. Si no hay usuarios con el mismo major, usar todos los usuarios
      if (targetUserIds.isEmpty) {
        if (debug) print('🎓 [MajorRecs] No hay otros usuarios con el mismo major, usando todos');
        
        final allUsersSnapshot = await _db.collection('users').get();
        targetUserIds = allUsersSnapshot.docs
            .map((doc) => doc.id)
            .where((id) => id != currentUserId) // Excluir usuario actual
            .toList();

        if (debug) print('🎓 [MajorRecs] Total usuarios disponibles: ${targetUserIds.length}');
      }

      if (targetUserIds.isEmpty) {
        if (debug) print('🎓 [MajorRecs] No hay otros usuarios en la app');
        return [];
      }

      // 4. Obtener eventos de clicks/vistas de esos usuarios de product_click_events
      final cutoffDate = DateTime.now().subtract(Duration(days: windowDays));
      
      // Firestore "in" query tiene límite de 10 items, así que procesamos en batches
      final Map<String, int> postViewCounts = {};
      
      for (int i = 0; i < targetUserIds.length; i += 10) {
        final batch = targetUserIds.skip(i).take(10).toList();
        
        final eventsSnapshot = await _db
            .collection('product_click_events')
            .where('userId', whereIn: batch)
            .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffDate))
            .get();

        if (debug) {
          print('🎓 [MajorRecs] Batch ${i ~/ 10 + 1}: ${eventsSnapshot.docs.length} clicks');
        }

        // Contar clicks por post_ref
        for (final doc in eventsSnapshot.docs) {
          final data = doc.data();
          
          if (debug) print('🎓 [MajorRecs] Click data: ${data.keys.join(', ')}');
          
          // Obtener el post_ref (puede ser DocumentReference o String)
          final dynamic postRef = data['post_ref'];
          String? postId;
          
          if (postRef is DocumentReference) {
            postId = postRef.id;
            if (debug) print('🎓 [MajorRecs]   postRef es DocumentReference, ID: $postId');
          } else if (postRef is String) {
            // Si es string, extraer el ID del path
            var path = postRef.trim();
            if (path.contains('/')) {
              postId = path.split('/').last;
            } else {
              postId = path;
            }
            if (debug) print('🎓 [MajorRecs]   postRef es String: "$path", extraído ID: $postId');
          } else {
            if (debug) print('🎓 [MajorRecs]   postRef tipo desconocido: ${postRef?.runtimeType}');
          }
          
          if (postId != null && postId.isNotEmpty) {
            postViewCounts[postId] = (postViewCounts[postId] ?? 0) + 1;
            if (debug) print('🎓 [MajorRecs]   ✓ Contando click para post: $postId (total: ${postViewCounts[postId]})');
          } else {
            if (debug) print('🎓 [MajorRecs]   ✗ No se pudo extraer postId');
          }
        }
      }

      if (debug) {
        print('🎓 [MajorRecs] Posts con clicks: ${postViewCounts.length}');
        postViewCounts.forEach((postId, count) {
          print('  - $postId: $count clicks');
        });
      }

      // 5. Ordenar por número de clicks (descendente)
      final sortedPosts = postViewCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      if (sortedPosts.isEmpty) {
        if (debug) print('🎓 [MajorRecs] No hay clicks registrados, yendo directo a fallback de posts recientes');
        // NO retornar vacío aquí, continuar al paso 7 (fallback)
      }

      // 6. Obtener posts activos basados en los IDs más clickeados
      final List<Post> resultPosts = [];
      
      // Solo intentar esto si hay posts con clicks
      if (sortedPosts.isNotEmpty) {
        for (final entry in sortedPosts) {
          if (resultPosts.length >= limit) break;

          final postId = entry.key;
          
          try {
            // Obtener el post específico
            final postDoc = await _db.collection('posts').doc(postId).get();
            
            if (!postDoc.exists) {
              if (debug) print('🎓 [MajorRecs] Post $postId no existe en la BD');
              continue;
            }

            final postData = Map<String, dynamic>.from(postDoc.data()!);
            postData['id'] = postDoc.id;
            postData['_id'] = postDoc.id;
            
            final post = Post.fromJson(postData);
            
            // Filtrar posts no activos
            if (post.status != 'active') {
              if (debug) print('🎓 [MajorRecs] Post $postId no está activo (status: ${post.status})');
              continue;
            }
            
            // Filtrar posts propios
            if (post.userId == currentUserId) {
              if (debug) print('🎓 [MajorRecs] Post $postId es propio, saltando');
              continue;
            }
            
            resultPosts.add(post);
            if (debug) print('🎓 [MajorRecs] ✓ Post agregado: ${post.title} (${entry.value} clicks)');
          } catch (e) {
            if (debug) print('🎓 [MajorRecs] ❌ Error obteniendo post $postId: $e');
          }
        }
      }

      // 7. Si no hay suficientes posts (o ninguno), completar con posts recientes (que no sean propios)
      if (resultPosts.length < limit) {
        if (debug) print('🎓 [MajorRecs] Completando con posts recientes... (tenemos ${resultPosts.length}, necesitamos $limit)');
        
        final recentPostsSnapshot = await _db
            .collection('posts')
            .orderBy('created_at', descending: true)
            .limit(limit * 3) // Aumentar para tener más opciones
            .get();

        if (debug) print('🎓 [MajorRecs] Posts recientes encontrados: ${recentPostsSnapshot.docs.length}');

        for (final postDoc in recentPostsSnapshot.docs) {
          if (resultPosts.length >= limit) break;

          final postData = Map<String, dynamic>.from(postDoc.data());
          postData['id'] = postDoc.id;
          postData['_id'] = postDoc.id;
          
          try {
            final post = Post.fromJson(postData);
            
            // Verificar status active en código (no en query)
            if (post.status != 'active') {
              if (debug) print('🎓 [MajorRecs] Saltando post no activo: ${post.title} (status: ${post.status})');
              continue;
            }
            
            // Filtrar posts propios y duplicados
            if (post.userId == currentUserId) {
              if (debug) print('🎓 [MajorRecs] Saltando post propio: ${post.title}');
              continue;
            }
            if (resultPosts.any((p) => p.id == post.id)) {
              if (debug) print('🎓 [MajorRecs] Saltando post duplicado: ${post.title}');
              continue;
            }
            
            resultPosts.add(post);
            if (debug) print('🎓 [MajorRecs] ✓ Post reciente agregado: ${post.title}');
          } catch (e) {
            if (debug) print('🎓 [MajorRecs] Error parseando post ${postDoc.id}: $e');
          }
        }
      }

      if (debug) {
        print('🎓 [MajorRecs] RESULTADO FINAL: ${resultPosts.length} posts');
      }

      return resultPosts;
    } catch (e, stackTrace) {
      if (debug) {
        print('🎓 [MajorRecs] ❌ Error: $e');
        print(stackTrace);
      }
      return [];
    }
  }

  /// Resolver nombre de categoría desde path de referencia
  String? _resolveCategoryName(String? rawCategory) {
    if (rawCategory == null) return null;
    final trimmed = rawCategory.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('/')) return trimmed;
    final parts = trimmed.split('/');
    return parts.isNotEmpty ? parts.last : trimmed;
  }
}

