// recommendation_service.dart - OPTIMIZED VERSION
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/models.dart';

class RecommendationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  // Cache de categorías para evitar queries repetidas
  final Map<String, String> _categoryCache = {};

  Future<List<Post>> fetchRecommendations({
    int windowDays = 30,
    int limit = 20,
    int topCategories = 3,
    bool debug = false,
  }) async {
    void dlog(String msg) {
      if (debug) debugPrint('[Reco] $msg');
    }

    final stopwatch = Stopwatch()..start();
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      dlog('No UID -> retorno vacío');
      return [];
    }

    final since = Timestamp.fromDate(
      DateTime.now().subtract(Duration(days: windowDays)),
    );

    const double W_CLICK = 5.0;
    const double W_SELECT = 3.0;
    const double W_SUGG = 1.0;

    final Map<String, double> catWeights = {};
    dlog('⚡ Inicio reco OPTIMIZADO para uid=$uid');

    // OPTIMIZATION 1: Limit events processed (last 100 of each type)
    const int MAX_EVENTS = 100;

    // 1) Clicks - Optimized with limit
    final clickSnap = await _db
        .collection('product_click_events')
        .where('userId', isEqualTo: uid)
        .where('timestamp', isGreaterThanOrEqualTo: since)
        .limit(MAX_EVENTS)
        .get();

    dlog('📊 Procesando ${clickSnap.docs.length} clicks (max $MAX_EVENTS)');

    // OPTIMIZATION 2: Use category field directly, skip post lookup
    for (final doc in clickSnap.docs) {
      final data = doc.data();

      // Try to get category directly from event (much faster!)
      String? catName = (data['category'] as String?)?.trim();

      // Only lookup post if category not in event (rare case)
      if (catName == null || catName.isEmpty) {
        final dynamic postRef = data['post_ref'];
        if (postRef != null) {
          catName = await _getPostCategory(postRef);
        }
      }

      if (catName != null && catName.isNotEmpty) {
        catWeights[catName] = (catWeights[catName] ?? 0) + W_CLICK;
        // dlog('  ✓ +${W_CLICK.toStringAsFixed(1)} click → "$catName"');
      }
    }

    // 2) Búsquedas - Optimized with limit
    final searchSnap = await _db
        .collection('product_search_events')
        .where('userId', isEqualTo: uid)
        .where('timestamp', isGreaterThanOrEqualTo: since)
        .limit(MAX_EVENTS)
        .get();

    dlog('📊 Procesando ${searchSnap.docs.length} searches (max $MAX_EVENTS)');

    // OPTIMIZATION 3: Batch category lookups
    final Set<String> categoryIdsToFetch = {};

    for (final doc in searchSnap.docs) {
      final data = doc.data();

      final dynamic sel = data['selectedCategory'];
      if (sel is DocumentReference) {
        categoryIdsToFetch.add(sel.id);
      } else if (sel is String && sel.isNotEmpty) {
        final catId = _extractCategoryId(sel);
        if (catId != null) categoryIdsToFetch.add(catId);
      }

      final List<dynamic> sugg =
          (data['suggestedCategories'] as List<dynamic>?) ?? const [];
      for (final s in sugg) {
        if (s is DocumentReference) {
          categoryIdsToFetch.add(s.id);
        } else if (s is String && s.isNotEmpty) {
          final catId = _extractCategoryId(s);
          if (catId != null) categoryIdsToFetch.add(catId);
        }
      }
    }

    // OPTIMIZATION 4: Fetch all categories in one batch
    if (categoryIdsToFetch.isNotEmpty) {
      dlog('🔍 Fetching ${categoryIdsToFetch.length} categories in batch...');
      await _batchFetchCategories(categoryIdsToFetch.toList());
    }

    // Now process search events with cached categories
    for (final doc in searchSnap.docs) {
      final data = doc.data();

      String? selName = await _resolveCategoryName(data['selectedCategory']);
      if (selName != null && selName.isNotEmpty) {
        catWeights[selName] = (catWeights[selName] ?? 0) + W_SELECT;
        // dlog('  ✓ +${W_SELECT.toStringAsFixed(1)} select → "$selName"');
      }

      final List<dynamic> sugg =
          (data['suggestedCategories'] as List<dynamic>?) ?? const [];
      for (final s in sugg) {
        String? nm = await _resolveCategoryName(s);
        if (nm != null && nm.isNotEmpty) {
          catWeights[nm] = (catWeights[nm] ?? 0) + W_SUGG;
          // dlog('  ✓ +${W_SUGG.toStringAsFixed(1)} sugg → "$nm"');
        }
      }
    }

    dlog('⏱️ Event processing: ${stopwatch.elapsedMilliseconds}ms');

    if (catWeights.isEmpty) {
      dlog('Sin señales → fallback global');
      return _fetchFallbackPosts(uid, limit, dlog);
    }

    final sortedCats = catWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    dlog('🎯 Top categorías:');
    for (final e in sortedCats.take(5)) {
      dlog('  ${e.key}: ${e.value.toStringAsFixed(1)}');
    }

    final selectedCats =
        sortedCats.take(topCategories).map((e) => e.key).toList();
    final perCat = max(5, (limit / max(1, selectedCats.length)).floor());

    final Set<String> seen = {};
    final List<Post> out = [];

    // OPTIMIZATION 5: Parallel queries for categories
    final futures = selectedCats.map((catName) async {
      final snap = await _db
          .collection('posts')
          .where('category_name', isEqualTo: catName)
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      return {'category': catName, 'docs': snap.docs};
    }).toList();

    final results = await Future.wait(futures);
    dlog('⏱️ Category queries: ${stopwatch.elapsedMilliseconds}ms');

    for (final result in results) {
      final catName = result['category'] as String;
      final docs = result['docs'] as List<QueryDocumentSnapshot<Map<String, dynamic>>>;

      int added = 0;
      for (final d in docs) {
        if (out.length >= limit || added >= perCat) break;
        if (seen.contains(d.id)) continue;

        final post = _postFromDoc(d);
        if (post == null) continue;

        final ownerId = (d.data()['user_id'] as String?) ?? '';
        if (_uidOnly(ownerId) == uid) continue;

        out.add(post);
        seen.add(d.id);
        added++;
      }
      dlog('  ✓ $catName: $added posts');
    }

    // Fallback if needed
    if (out.length < limit) {
      final extra = await _fetchFallbackPosts(uid, limit - out.length, dlog);
      for (final post in extra) {
        if (out.length >= limit) break;
        if (!seen.contains(post.id)) {
          out.add(post);
          seen.add(post.id);
        }
      }
    }

    stopwatch.stop();
    dlog('⚡ TOTAL: ${out.length} posts en ${stopwatch.elapsedMilliseconds}ms');
    return out.take(limit).toList();
  }

  Future<List<Post>> _fetchFallbackPosts(
    String uid,
    int limit,
    Function(String) dlog,
  ) async {
    final latest = await _db
        .collection('posts')
        .where('status', isEqualTo: 'active')
        .orderBy('created_at', descending: true)
        .limit(limit * 2)
        .get();

    return latest.docs
        .map(_postFromDoc)
        .whereType<Post>()
        .where((p) => _uidOnly(p.userId) != uid)
        .take(limit)
        .toList();
  }

  Future<String?> _getPostCategory(dynamic postRef) async {
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
        return (pdata['category_name'] as String?)?.trim();
      }
    } catch (_) {}
    return null;
  }

  String? _extractCategoryId(String raw) {
    var path = raw.trim();
    if (path.startsWith('/')) path = path.substring(1);
    if (path.contains('/')) {
      return path.split('/').last;
    }
    return path;
  }

  Future<void> _batchFetchCategories(List<String> categoryIds) async {
    // Fetch categories in chunks of 10 (Firestore 'in' limit)
    const chunkSize = 10;
    for (var i = 0; i < categoryIds.length; i += chunkSize) {
      final chunk = categoryIds.skip(i).take(chunkSize).toList();
      final snap = await _db
          .collection('categories')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();

      for (final doc in snap.docs) {
        final name = (doc.data()['name'] as String?)?.trim();
        if (name != null) {
          _categoryCache[doc.id] = name;
        }
      }
    }
  }

  Future<String?> _resolveCategoryName(dynamic sel) async {
    try {
      if (sel is DocumentReference) {
        final id = sel.id;
        if (_categoryCache.containsKey(id)) {
          return _categoryCache[id];
        }
        final s = await sel.get();
        final name = (s.data() as Map?)?['name'] as String? ?? id;
        _categoryCache[id] = name;
        return name;
      } else if (sel is String && sel.isNotEmpty) {
        final catId = _extractCategoryId(sel);
        if (catId != null && _categoryCache.containsKey(catId)) {
          return _categoryCache[catId];
        }
        var path = sel.trim();
        if (path.startsWith('/')) path = path.substring(1);
        if (!path.contains('/')) path = 'categories/$path';
        final s = await _db.doc(path).get();
        final name = (s.data() as Map?)?['name'] as String? ?? path.split('/').last;
        if (catId != null) _categoryCache[catId] = name;
        return name;
      }
    } catch (_) {}
    return null;
  }

  String _uidOnly(String raw) {
    if (raw.isEmpty) return raw;
    if (raw.contains('/')) return raw.split('/').last;
    return raw;
  }

  Post? _postFromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    try {
      final data = d.data()!;
      data['id'] = d.id;
      data['_id'] = d.id;
      return Post.fromJson(data);
    } catch (_) {
      return null;
    }
  }
}
