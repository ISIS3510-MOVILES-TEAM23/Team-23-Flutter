import '../../services/storage_service.dart';

class StorageRepository {
  final StorageService _storageService;

  StorageRepository({StorageService? storageService})
      : _storageService = storageService ?? StorageService();

  // Upload from camera
  Future<String?> uploadFromCamera({
    required String ownerUid,
    required String productId,
  }) async {
    return await _storageService.uploadFromCamera(
      ownerUid: ownerUid,
      productId: productId,
    );
  }

  // Upload from gallery
  Future<String?> uploadFromGallery({
    required String ownerUid,
    required String productId,
  }) async {
    return await _storageService.uploadFromGallery(
      ownerUid: ownerUid,
      productId: productId,
    );
  }

  // Delete by URL
  Future<void> deleteByUrl(String url) async {
    await _storageService.deleteByUrl(url);
  }
}

