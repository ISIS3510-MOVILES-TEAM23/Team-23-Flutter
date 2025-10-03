import '../../models/models.dart';
import '../../services/firestore_service.dart';

class SaleRepository {
  SaleRepository();

  // Get sales by post
  Future<List<Sale>> getSalesByPost(String postId) async {
    return await FirestoreService.getSalesByPost(postId);
  }
}

