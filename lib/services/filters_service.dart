import 'package:campus_marketplace/models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FilterService {
  late QuerySnapshot<Map<String, dynamic>> snapshot;
  
  Future<void> filter(
    CollectionReference<Map<String, dynamic>> postsReference,
    DocumentReference<Map<String, dynamic>> categoryRef,
    String status,
  );

  Future<List<Post>> getPosts(String status) async {
    print('--------------------------------------Getting posts from snapshot: ${snapshot.toString()}');
    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['_id'] = doc.id;
          return Post.fromJson(data);
        })
        .where((post) => status == 'all' || post.status == status)
        .toList();
  }
}

class FiltersContext {
  FirebaseFirestore db = FirebaseFirestore.instance;
  FilterService? _filterService;
  CollectionReference<Map<String, dynamic>> get postsCollection =>
      db.collection('posts');
  String categoryId;
  String status;

  FiltersContext({required this.categoryId, this.status = 'active'}) {
    _filterService = NoFilterService();
  }

  void setFilterService(FilterService filterService) {
    _filterService = filterService;
  }

  void setStatus(String newStatus) {
    status = newStatus;
  }

  Future<List<Post>> filter() async {
    print('--------------------------------------Filtering posts with categoryId: $categoryId, status: $status');
    final categoryRef = db.collection('categories').doc(categoryId);
    await _filterService!.filter(postsCollection, categoryRef, status);
    final posts = await _filterService!.getPosts(status);
    print('--------------------------------------Posts after filtering: ${posts.length}');
    return posts;
  }
}

class NoFilterService extends FilterService {
  @override
  Future<void> filter(
    CollectionReference<Map<String, dynamic>> postsReference,
    DocumentReference<Map<String, dynamic>> categoryRef,
    String status,
  ) async {
    Query<Map<String, dynamic>> query = postsReference
        .where('category_id', isEqualTo: categoryRef);
    
    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    
    final snapshot = await query.get();
    this.snapshot = snapshot;
  }
}

class PriceDescendingFilterService extends FilterService {
  @override
  Future<void> filter(
    CollectionReference<Map<String, dynamic>> postsReference,
    DocumentReference<Map<String, dynamic>> categoryRef,
    String status,
  ) async {
    Query<Map<String, dynamic>> query = postsReference
        .where('category_id', isEqualTo: categoryRef)
        .orderBy('price', descending: true);
    
    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    
    final snapshot = await query.get();
    this.snapshot = snapshot;
  }
}

class PriceAscendingFilterService extends FilterService {
  @override
  Future<void> filter(
    CollectionReference<Map<String, dynamic>> postsReference,
    DocumentReference<Map<String, dynamic>> categoryRef,
    String status,
  ) async {
    Query<Map<String, dynamic>> query = postsReference
        .where('category_id', isEqualTo: categoryRef)
        .orderBy('price', descending: false);
    
    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    
    final snapshot = await query.get();
    this.snapshot = snapshot;
  }
}

class NewestFilterService extends FilterService {
  @override
  Future<void> filter(
    CollectionReference<Map<String, dynamic>> postsReference,
    DocumentReference<Map<String, dynamic>> categoryRef,
    String status,
  ) async {
    Query<Map<String, dynamic>> query = postsReference
        .where('category_id', isEqualTo: categoryRef)
        .orderBy('created_at', descending: true);
    
    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    
    final snapshot = await query.get();
    this.snapshot = snapshot;
  }
}

class PriceFilterService extends FilterService {
  final double minPrice;
  final double maxPrice;

  PriceFilterService({required this.minPrice, required this.maxPrice});

  @override
  Future<void> filter(
    CollectionReference<Map<String, dynamic>> postsReference,
    DocumentReference<Map<String, dynamic>> categoryRef,
    String status,
  ) async {
    Query<Map<String, dynamic>> query = postsReference
        .where('category_id', isEqualTo: categoryRef)
        .where('price', isGreaterThanOrEqualTo: minPrice)
        .where('price', isLessThanOrEqualTo: maxPrice);
    
    if (status != 'all') {
      query = query.where('status', isEqualTo: status);
    }
    
    final snapshot = await query.get();
    this.snapshot = snapshot;
  }
}