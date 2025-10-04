import 'package:campus_marketplace/models/models.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

abstract class FilterService {
  late QuerySnapshot<Map<String, dynamic>> snapshot;
  Future<void> filter(CollectionReference<Map<String, dynamic>> postsReference,
      DocumentReference<Map<String, dynamic>> categoryRef);

  Future<List<Post>> getPosts() async {
    print(
        '--------------------------------------Getting posts from snapshot: ${snapshot.toString()}');
    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['_id'] = doc.id;
          return Post.fromJson(data);
        })
        .where((post) => post.status == 'active')
        .toList();
  }
}

class FiltersContext {
  FirebaseFirestore db = FirebaseFirestore.instance;
  FilterService? _filterService;
  CollectionReference<Map<String, dynamic>> get postsCollection =>
      db.collection('posts');
  String categoryId;

  FiltersContext({required this.categoryId}) {
    _filterService = NoFilterService();
  }

  void setFilterService(FilterService filterService) {
    _filterService = filterService;
  }

  Future<List<Post>> filter() async {
    print(
        '--------------------------------------Filtering posts with categoryId: $categoryId');
    final categoryRef = db.collection('categories').doc(categoryId);
    await _filterService!.filter(postsCollection, categoryRef);
    final posts = await _filterService!.getPosts();
    print(
        '--------------------------------------Posts after filtering: ${posts.length}');
    return posts;
  }
}

class NoFilterService extends FilterService {
  @override
  Future<void> filter(CollectionReference<Map<String, dynamic>> postsReference,
      DocumentReference<Map<String, dynamic>> categoryRef) async {
    final snapshot = await postsReference
        .where('category_id', isEqualTo: categoryRef)
        .get();
    this.snapshot = snapshot;
  }
}

class PriceDescendingFilterService extends FilterService {
  @override
  Future<void> filter(CollectionReference<Map<String, dynamic>> postsReference,
      DocumentReference<Map<String, dynamic>> categoryRef) async {
    final snapshot = await postsReference
        .where('category_id', isEqualTo: categoryRef)
        .orderBy('price', descending: true)
        .get();
    this.snapshot = snapshot;
  }
}

class PriceAscendingFilterService extends FilterService {
  @override
  Future<void> filter(CollectionReference<Map<String, dynamic>> postsReference,
      DocumentReference<Map<String, dynamic>> categoryRef) async {
    final snapshot = await postsReference
        .where('category_id', isEqualTo: categoryRef)
        .orderBy('price', descending: false)
        .get();
    this.snapshot = snapshot;
  }
}

class NewestFilterService extends FilterService {
  @override
  Future<void> filter(CollectionReference<Map<String, dynamic>> postsReference,
      DocumentReference<Map<String, dynamic>> categoryRef) async {
    final snapshot = await postsReference
        .where('category_id', isEqualTo: categoryRef)
        .orderBy('created_at', descending: true)
        .get();
    this.snapshot = snapshot;
  }
}

class PriceFilterService extends FilterService {
  final double minPrice;
  final double maxPrice;

  PriceFilterService({required this.minPrice, required this.maxPrice});

  @override
  Future<void> filter(CollectionReference<Map<String, dynamic>> postsReference,
      DocumentReference<Map<String, dynamic>> categoryRef) async {
    final snapshot = await postsReference
        .where('category_id', isEqualTo: categoryRef)
        .where('price', isGreaterThanOrEqualTo: minPrice)
        .where('price', isLessThanOrEqualTo: maxPrice)
        .get();
    this.snapshot = snapshot;
  }
}
