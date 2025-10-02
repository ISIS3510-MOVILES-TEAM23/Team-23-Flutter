import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:uuid/uuid.dart';

import '../models/models.dart';

class ProductFiltersService {
  static final _db = FirebaseFirestore.instance;

  // Para logs
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  static final Uuid _uuid = const Uuid();
  static String? _sessionId;
  static String _ensureSessionId() {
    _sessionId ??= _uuid.v4();
    return _sessionId!;
  }

  // "Sin límite" debe coincidir con tu screen (kNoMaxUsd)
  static const double _defaultMinUsd = 0;
  static const double _defaultMaxUsd = 100000000;

  /// Logger minimalista de uso de filtros
  /// { filter_used, sessionId, userId, timestamp }
  static Future<void> logFilterUsed(String filterUsed) async {
    try {
      final userId = _auth.currentUser?.uid ?? 'anonymous';
      final sessionId = _ensureSessionId();
      await _db.collection('filter_usage_events').add({
        'filter_used': filterUsed, // "category"|"price"|"sort"|"status"|"clear"
        'sessionId': sessionId,
        'userId': userId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {/* no bloquear UI */}
  }

  /// Carga posts por categoría (acepta category_id guardado como Ref o como String),
  /// con filtros y fallback si falta índice.
  static Future<List<Post>> getPostsByCategory(
    String categoryId, {
    FilterOptions? filters,
    String? statusParam, // 'active' | 'sold' | 'reserved' | 'all'
    int serverLimit = 400,
  }) async {
    // 1) Resolver docId real de la categoría (acepta id o nombre)
    String? categoryDocId;
    final cats = await _db.collection('categories').get();
    for (final c in cats.docs) {
      final name = (c.data()['name'] as String?)?.trim();
      if (name == categoryId || c.id == categoryId) {
        categoryDocId = c.id;
        break;
      }
    }
    if (categoryDocId == null) return [];

    // Valores posibles que encontramos en posts
    final DocumentReference<Map<String, dynamic>> categoryRef =
        _db.collection('categories').doc(categoryDocId);
    final String categoryPathById = 'categories/$categoryDocId';
    final String categoryPathByName = 'categories/$categoryId'; // por si algún doc guardó el nombre

    // 2) Parámetros de filtro
    final sort = (filters?.sortBy ?? 'newest').trim(); // 'newest'|'price_low'|'price_high'|'popular'
    final minUsd = filters?.minPrice ?? _defaultMinUsd;
    final maxUsd = filters?.maxPrice ?? _defaultMaxUsd;
    final hasPriceRange = (minUsd > _defaultMinUsd) || (maxUsd < _defaultMaxUsd);
    final minCents = (minUsd * 100).round();
    final maxCents = (maxUsd * 100).round();

    final status = (statusParam ?? 'active').trim();   // usa 'all' para no filtrar por estado

    // Helper para armar la query base (sin category)
    Query<Map<String, dynamic>> _baseQuery() {
      Query<Map<String, dynamic>> q = _db.collection('posts');
      if (status != 'all') {
        q = q.where('status', isEqualTo: status);
      }
      return q;
    }

    // Helper para completar sort y rango
    Query<Map<String, dynamic>> _applySortAndRange(
      Query<Map<String, dynamic>> q,
      String sort,
      bool hasRange,
      int minCents,
      int maxCents,
    ) {
      if (sort == 'price_low' || sort == 'price_high') {
        if (hasRange) {
          q = q
              .where('price', isGreaterThanOrEqualTo: minCents)
              .where('price', isLessThanOrEqualTo: maxCents);
        }
        q = q
            .orderBy('price', descending: sort == 'price_high')
            .orderBy('created_at', descending: true); // desempate estable
      } else {
        q = q.orderBy('created_at', descending: true);
      }
      return q;
    }

    // Helper para ejecutar una query por un valor de category_id (String o Ref)
    Future<List<Post>> _fetchByCategoryValue(dynamic categoryValue) async {
      Query<Map<String, dynamic>> q = _baseQuery()
          .where('category_id', isEqualTo: categoryValue);
      q = _applySortAndRange(q, sort, hasPriceRange, minCents, maxCents);

      final snap = await q.limit(serverLimit).get();
      var posts = snap.docs.map((d) {
        final data = {...d.data(), 'id': d.id, '_id': d.id};
        return Post.fromJson(data);
      }).toList();

      if ((sort == 'newest' || sort == 'popular') && hasPriceRange) {
        posts = posts.where((p) => p.price >= minCents && p.price <= maxCents).toList();
      }
      return posts;
    }

    try {
      // 3) Intento “bueno”: buscar por ambos tipos
      final results = await Future.wait<List<Post>>([
        _fetchByCategoryValue(categoryRef),      // DocumentReference
        _fetchByCategoryValue(categoryPathById), // String "categories/<docId>"
        _fetchByCategoryValue(categoryPathByName), // String "categories/<name>" (por si acaso)
      ]);

      // Unir y deduplicar por id
      final Map<String, Post> merged = {};
      for (final list in results) {
        for (final p in list) {
          merged[p.id] = p;
        }
      }
      return merged.values.toList()
        ..sort((a, b) {
          if (sort == 'price_low') return a.price.compareTo(b.price);
          if (sort == 'price_high') return b.price.compareTo(a.price);
          // newest/popular por fecha desc (asumimos createdAt en Post, si no, ya viene ordenado)
          return 0;
        });
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;

      // 4) FALLBACK: sin índices. Traer por status + fecha y filtrar en cliente.
      Query<Map<String, dynamic>> fb = _db.collection('posts');
      if (status != 'all') {
        fb = fb.where('status', isEqualTo: status);
      }
      fb = fb.orderBy('created_at', descending: true);

      final snap = await fb.limit(serverLimit).get();
      var posts = snap.docs.map((d) {
        final data = {...d.data(), 'id': d.id, '_id': d.id};
        return Post.fromJson(data);
      }).toList();

      // Filtrar por categoría admitiendo string/ref serializado
      posts = posts.where((p) {
        final cid = p.categoryId; // asumiendo que Post.fromJson lo serializa a string path
        return cid == categoryPathById || cid == categoryPathByName;
      }).toList();

      // Rango en cliente si aplica
      if (hasPriceRange) {
        posts = posts.where((p) => p.price >= minCents && p.price <= maxCents).toList();
      }

      // Ordenar en cliente si se pidió por precio
      if (sort == 'price_low') {
        posts.sort((a, b) => a.price.compareTo(b.price));
      } else if (sort == 'price_high') {
        posts.sort((a, b) => b.price.compareTo(a.price));
      }
      // newest/popular ya vienen por created_at desc

      return posts;
    }
  }
}
