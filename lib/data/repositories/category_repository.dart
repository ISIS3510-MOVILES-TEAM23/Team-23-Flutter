import '../../models/models.dart';
import '../../services/firestore_service.dart';

class CategoryRepository {
  CategoryRepository();

  // Get all categories
  Future<List<Category>> getCategories({bool debug = false}) async {
    return await FirestoreService.getCategories(debug: debug);
  }
}

