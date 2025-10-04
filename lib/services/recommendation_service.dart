// recommendation_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // <- para debugPrint
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/models.dart';

class RecommendationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  Future<List<Post>> fetchRecommendations({
    int windowDays = 30,
    int limit = 20,
    int topCategories = 3,
    bool debug = false, // <<< NUEVO
  }) async {
    void dlog(String msg) {
      if (debug) debugPrint('[Reco] $msg');
    }

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
    dlog('Inicio reco para uid=$uid, windowDays=$windowDays, limit=$limit');

    // 1) Clicks
    final clickSnap = await _db
        .collection('product_click_events')
        .where('userId', isEqualTo: uid)
        .where('timestamp', isGreaterThanOrEqualTo: since)
        .orderBy('timestamp')
        .get();

    dlog('Clicks encontrados: ${clickSnap.docs.length}');
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
        dlog('  +${W_CLICK.toStringAsFixed(1)} por click → "$catName"');
      }
    }

    // 2) Búsquedas
    final searchSnap = await _db
        .collection('product_search_events')
        .where('userId', isEqualTo: uid)
        .where('timestamp', isGreaterThanOrEqualTo: since)
        .orderBy('timestamp')
        .get();

    dlog('Search events encontrados: ${searchSnap.docs.length}');
    for (final doc in searchSnap.docs) {
      final data = doc.data();

      // selectedCategory puede ser 'c2', 'categories/c2' o DocumentReference
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
        dlog('  +${W_SELECT.toStringAsFixed(1)} por selectedCategory → "$selName"');
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
          dlog('  +${W_SUGG.toStringAsFixed(1)} por suggestedCategory → "$nm"');
        }
      }
    }

    if (catWeights.isEmpty) {
      dlog('Sin señales → fallback: últimos activos globales');
      final latest = await _db
          .collection('posts')
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();
      dlog('Fallback resultados: ${latest.docs.length}');
      return latest.docs.map(_postFromDoc).whereType<Post>().toList();
    }

    final sortedCats = catWeights.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    dlog('Pesos por categoría (desc):');
    for (final e in sortedCats) {
      dlog('  ${e.key} -> ${e.value.toStringAsFixed(1)}');
    }

    final selectedCats =
        sortedCats.take(topCategories).map((e) => e.key).toList();
    final perCat = max(5, (limit / max(1, selectedCats.length)).floor());
    dlog('Top cats: $selectedCats | perCat=$perCat | limit=$limit');

    final Set<String> seen = {};
    final List<Post> out = [];
    final Map<String, int> addedPerCat = {};

    for (final catName in selectedCats) {
      dlog('Buscando candidatos en posts.category_name == "$catName"');
      final snap = await _db
          .collection('posts')
          .where('status', isEqualTo: 'active')
          .where('category_name', isEqualTo: catName)
          .orderBy('created_at', descending: true)
          .limit(50)
          .get();
      dlog('  → ${snap.docs.length} docs');

      for (final d in snap.docs) {
        if (out.length >= limit) break;
        if (seen.contains(d.id)) {
          dlog('    SKIP dup: ${d.id}');
          continue;
        }

        final post = _postFromDoc(d);
        if (post == null) {
          dlog('    SKIP parse fail: ${d.id}');
          continue;
        }

        final ownerId = (d.data()['user_id'] as String?) ?? '';
        if (_uidOnly(ownerId) == uid) {
          dlog('    SKIP propio: ${post.id}');
          continue;
        }

        out.add(post);
        seen.add(d.id);
        addedPerCat[catName] = (addedPerCat[catName] ?? 0) + 1;
        dlog('    ADD  ${post.id}  ($catName)');

        if (addedPerCat[catName]! >= perCat) {
          dlog('    Cupo por categoría alcanzado para "$catName"');
          break;
        }
      }
    }

    if (out.length < limit) {
      dlog('Faltan ${limit - out.length} → fallback extra activos globales');
      final extra = await _db
          .collection('posts')
          .where('status', isEqualTo: 'active')
          .orderBy('created_at', descending: true)
          .limit(limit * 2)
          .get();
      for (final d in extra.docs) {
        if (out.length >= limit) break;
        if (seen.contains(d.id)) continue;

        final post = _postFromDoc(d);
        if (post == null) continue;
        if (_uidOnly(post.userId) == uid) continue;

        out.add(post);
        seen.add(d.id);
        dlog('    ADD-FB ${post.id}');
      }
    }

    dlog('Total recomendados: ${out.length}');
    return out.take(limit).toList();
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
