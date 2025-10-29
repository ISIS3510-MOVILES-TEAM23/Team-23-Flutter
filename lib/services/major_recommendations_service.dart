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
  /// OPTIMIZED VERSION
  Future<List<Post>> getPostsByMajor({
    int limit = 4,
    int windowDays = 30,
    bool debug = false,
  }) async {
    try {
      final stopwatch = Stopwatch()..start();
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

      if (debug) print('🎓 [MajorRecs] ⚡ OPTIMIZADO - Usuario: $currentUserId, Major: $currentMajor');

      List<String> targetUserIds = [];

      // 2. Si tiene major, buscar usuarios con el mismo major (limit to 50 users max)
      if (currentMajor != null && currentMajor.isNotEmpty) {
        final usersSnapshot = await _db
            .collection('users')
            .where('major', isEqualTo: currentMajor)
            .limit(50)
            .get();

        targetUserIds = usersSnapshot.docs
            .map((doc) => doc.id)
            .where((id) => id != currentUserId)
            .toList();

        if (debug) {
          print('🎓 [MajorRecs] Usuarios con major "$currentMajor": ${targetUserIds.length}');
        }
      }

      // 3. Si no hay usuarios con el mismo major, usar subset de usuarios (limit to 30)
      if (targetUserIds.isEmpty) {
        if (debug) print('🎓 [MajorRecs] No hay otros usuarios con el mismo major, usando subset');

        final allUsersSnapshot = await _db
            .collection('users')
            .limit(30)
            .get();
        targetUserIds = allUsersSnapshot.docs
            .map((doc) => doc.id)
            .where((id) => id != currentUserId)
            .toList();

        if (debug) print('🎓 [MajorRecs] Total usuarios disponibles: ${targetUserIds.length}');
      }

      if (targetUserIds.isEmpty) {
        if (debug) print('🎓 [MajorRecs] No hay otros usuarios en la app');
        return [];
      }

      // 4. OPTIMIZATION: Limit events processed per batch to 50
      final cutoffDate = DateTime.now().subtract(Duration(days: windowDays));
      final Map<String, int> postViewCounts = {};

      // OPTIMIZATION: Process max 2 batches (20 users) for speed
      final maxBatches = 2;
      int batchCount = 0;

      for (int i = 0; i < targetUserIds.length && batchCount < maxBatches; i += 10) {
        final batch = targetUserIds.skip(i).take(10).toList();
        batchCount++;

        final eventsSnapshot = await _db
            .collection('product_click_events')
            .where('userId', whereIn: batch)
            .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffDate))
            .limit(50) // OPTIMIZATION: Limit events per batch
            .get();

        if (debug) {
          print('🎓 [MajorRecs] Batch ${i ~/ 10 + 1}: ${eventsSnapshot.docs.length} clicks');
        }

        // Contar clicks por postId
        for (final doc in eventsSnapshot.docs) {
          final data = doc.data();
          String? postId;

          // Intentar obtener postId desde diferentes campos (estructura inconsistente en Firebase)
          // 1. Buscar campo 'postId' (string directo)
          if (data.containsKey('postId')) {
            final postIdValue = data['postId'];
            if (postIdValue is String && postIdValue.isNotEmpty) {
              postId = postIdValue;
            }
          }

          // 2. Si no, buscar campo 'post_ref' (DocumentReference o String)
          if (postId == null && data.containsKey('post_ref')) {
            final dynamic postRef = data['post_ref'];

            if (postRef is DocumentReference) {
              postId = postRef.id;
            } else if (postRef is String && postRef.isNotEmpty) {
              var path = postRef.trim();
              postId = path.contains('/') ? path.split('/').last : path;
            }
          }

          if (postId != null && postId.isNotEmpty) {
            postViewCounts[postId] = (postViewCounts[postId] ?? 0) + 1;
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

      // 6. OPTIMIZATION: Batch fetch all posts at once
      final List<Post> resultPosts = [];

      if (sortedPosts.isNotEmpty) {
        // Get top post IDs (limit * 3 to account for inactive/own posts)
        final topPostIds = sortedPosts.take(limit * 3).map((e) => e.key).toList();

        if (debug) print('🎓 [MajorRecs] ⚡ Fetching ${topPostIds.length} posts in batches...');

        // OPTIMIZATION: Fetch posts in batches of 10 using whereIn
        for (int i = 0; i < topPostIds.length && resultPosts.length < limit; i += 10) {
          final batch = topPostIds.skip(i).take(10).toList();

          try {
            final postsSnapshot = await _db
                .collection('posts')
                .where(FieldPath.documentId, whereIn: batch)
                .where('status', isEqualTo: 'active')
                .get();

            for (final doc in postsSnapshot.docs) {
              if (resultPosts.length >= limit) break;

              final postData = Map<String, dynamic>.from(doc.data());
              postData['id'] = doc.id;
              postData['_id'] = doc.id;

              final post = Post.fromJson(postData);

              // Filtrar posts propios
              if (post.userId == currentUserId) {
                if (debug) print('🎓 [MajorRecs] Post ${doc.id} es propio, saltando');
                continue;
              }

              resultPosts.add(post);
              final clicks = postViewCounts[doc.id] ?? 0;
              if (debug) print('🎓 [MajorRecs] ✓ Post agregado: ${post.title} ($clicks clicks)');
            }
          } catch (e) {
            if (debug) print('🎓 [MajorRecs] ❌ Error en batch: $e');
            continue;
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

      stopwatch.stop();
      if (debug) {
        print('🎓 [MajorRecs] ⚡ TOTAL: ${resultPosts.length} posts en ${stopwatch.elapsedMilliseconds}ms');
      }

      return resultPosts;
    } catch (e, stackTrace) {
      // Simplificar error de UNAVAILABLE (offline)
      final errorMsg = e.toString();
      if (errorMsg.contains('unavailable') || errorMsg.contains('UNAVAILABLE')) {
        if (debug) print('🎓 [MajorRecs] ⚠️ Offline - cannot fetch major-based products');
      } else {
        if (debug) {
          print('🎓 [MajorRecs] ❌ Error: $e');
          print(stackTrace);
        }
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

