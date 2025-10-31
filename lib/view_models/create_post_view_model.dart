import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:image_picker/image_picker.dart';
import '../models/models.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/storage_repository.dart';
import '../data/repositories/user_repository.dart';
import '../services/openrouter_service.dart';
import '../services/notification_service.dart';
import '../services/nearby_products_service.dart';
import '../services/draft_service.dart';
import '../services/connectivity_service.dart';

class CreatePostViewModel extends ChangeNotifier {
  final CategoryRepository _categoryRepository;
  final PostRepository _postRepository;
  final StorageRepository _storageRepository;
  final UserRepository _userRepository;
  final OpenRouterService _openRouterService;
  final NearbyProductsService _nearbyService;
  final DraftService _draftService;
  final ConnectivityService _connectivity;

  CreatePostViewModel({
    CategoryRepository? categoryRepository,
    PostRepository? postRepository,
    StorageRepository? storageRepository,
    UserRepository? userRepository,
    OpenRouterService? openRouterService,
    NearbyProductsService? nearbyProductsService,
    DraftService? draftService,
    ConnectivityService? connectivityService,
  })  : _categoryRepository = categoryRepository ?? CategoryRepository(),
        _postRepository = postRepository ?? PostRepository(),
        _storageRepository = storageRepository ?? StorageRepository(),
        _userRepository = userRepository ?? UserRepository(),
        _openRouterService = openRouterService ?? OpenRouterService(),
        _nearbyService = nearbyProductsService ?? NearbyProductsService(),
        _draftService = draftService ?? DraftService(),
        _connectivity = connectivityService ?? ConnectivityService() {
    _startAutoSave();
  }

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  String? selectedCategory;
  String? selectedCategoryName;
  List<String> imagePaths = [];
  List<String> localImagePaths = []; // Local paths for draft images (Scenario 8)
  List<Category> categories = [];
  bool isLoading = false;
  bool isAnalyzing = false;
  String? _postId;
  
  // Draft-related fields (Scenario 8)
  String? _draftId;
  Timer? _autoSaveTimer;
  bool _isDraftMode = false;
  DateTime? _lastAutoSave;

  String ensurePostId() {
    _postId ??= _postRepository.generatePostId();
    return _postId!;
  }

  Future<void> loadCategories() async {
    try {
      debugPrint('[CreatePostVM] 🔄 Loading categories...');
      final cats = await _categoryRepository.getCategories(debug: true);
      debugPrint('[CreatePostVM] ✓ Loaded ${cats.length} categories');
      
      // Scenario 8: Categories are automatically cached by FirestoreService.getCategories()
      // when online, so they'll be available offline next time
      
      cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      categories = cats;
      if (selectedCategory == null && cats.isNotEmpty) {
        selectedCategory = cats.first.id;
        selectedCategoryName = cats.first.name;
        debugPrint('[CreatePostVM] ✓ Selected default category: ${cats.first.name}');
      } else if (selectedCategory != null) {
        final match = cats.firstWhere(
          (c) => c.id == selectedCategory,
          orElse: () => cats.isNotEmpty
              ? cats.first
              : const Category(id: '', name: '', description: ''),
        );
        if (match.id.isNotEmpty) {
          selectedCategory = match.id;
          selectedCategoryName = match.name;
        } else {
          selectedCategory = null;
          selectedCategoryName = null;
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[CreatePostVM] ❌ Failed to load categories: $e');
      debugPrint('[CreatePostVM] ℹ️  Categories will be available after connecting to internet once');
      // Don't rethrow - allow UI to show empty state
      categories = [];
      notifyListeners();
    }
  }

  Future<String?> pickAndUploadImage({required bool fromCamera}) async {
    try {
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final ownerUid = currentUser.uid;
      final productId = ensurePostId();

      String? url;
      if (fromCamera) {
        url = await _storageRepository.uploadFromCamera(
          ownerUid: ownerUid,
          productId: productId,
        );
      } else {
        url = await _storageRepository.uploadFromGallery(
          ownerUid: ownerUid,
          productId: productId,
        );
      }

      if (url != null) {
        imagePaths.add(url);
        notifyListeners();
      }

      return url;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeImage(int index) async {
    final url = imagePaths[index];
    imagePaths.removeAt(index);
    notifyListeners();

    try {
      await _storageRepository.deleteByUrl(url);
    } catch (_) {
      // Error deleting image from storage
    }
  }

  void selectCategory(String? categoryId) {
    if (categoryId == null) return;

    final matched = categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(
        id: categoryId,
        name: categoryId,
        description: '',
      ),
    );

    selectedCategory = categoryId;
    selectedCategoryName = matched.name;
    notifyListeners();
  }

  /// Analiza la imagen con IA y autocompleta los campos del formulario
  Future<void> analyzeWithAI({String? model}) async {
    if (imagePaths.isEmpty) {
      throw Exception('Necesitas subir al menos una imagen primero');
    }

    if (categories.isEmpty) {
      throw Exception('No hay categorías disponibles');
    }

    try {
      isAnalyzing = true;
      notifyListeners();

      final categoryNames = categories.map((c) => c.name).toList();

      final suggestions = await _openRouterService.analyzeProductImage(
        imageUrl: imagePaths.first,
        availableCategories: categoryNames,
        model: model,
      );

      // Autocompletar los campos
      titleController.text = suggestions.title;
      descriptionController.text = suggestions.description;
      priceController.text = suggestions.price.toStringAsFixed(2);

      // Seleccionar categoría por nombre
      final matchedCategory = categories.firstWhere(
        (c) => c.name.toLowerCase() == suggestions.category.toLowerCase(),
        orElse: () => categories.first,
      );
      
      selectedCategory = matchedCategory.id;
      selectedCategoryName = matchedCategory.name;

      isAnalyzing = false;
      notifyListeners();

      debugPrint('✅ [CreatePostVM] Análisis completado: $suggestions');
    } catch (e) {
      isAnalyzing = false;
      notifyListeners();
      debugPrint('❌ [CreatePostVM] Error en análisis: $e');
      rethrow;
    }
  }

  Future<bool> submitPost() async {
    if (imagePaths.isEmpty) {
      throw Exception('Please add at least one image');
    }

    try {
      isLoading = true;
      notifyListeners();

      final priceInCents = (double.parse(priceController.text) * 100).toInt();

      final user = await _userRepository.getCurrentUser();
      if (user == null) throw Exception('User not logged in');

      final String postId = _postId ?? ensurePostId();

      if (selectedCategory == null) {
        throw Exception('Category not selected');
      }

      // Obtener ubicación actual (opcional) - delegado al Service
      double? latitude;
      double? longitude;
      final position = await _nearbyService.getCurrentLocationWithPermissions();
      if (position != null) {
        latitude = position.latitude;
        longitude = position.longitude;
      }

      final product = Post(
        id: postId,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        price: priceInCents,
        status: 'active',
        userId: user.id,
        categoryId: 'categories/$selectedCategory',
        images: imagePaths,
        createdAt: DateTime.now(),
        latitude: latitude,
        longitude: longitude,
      );

      final data = product.toJson();
      data['_id'] = postId;
      data['category_id'] = FirebaseFirestore.instance
          .collection('categories')
          .doc(selectedCategory);
      data['category_name'] = selectedCategoryName ?? '';

      final success = await _postRepository.createPost(data, forceId: postId);

      // 🔔 Enviar notificaciones a usuarios interesados (en background)
      if (success) {
        NotificationService.notifyInterestedUsers(
          postId: postId,
          postTitle: titleController.text.trim(),
          categoryName: selectedCategoryName ?? '',
          price: priceInCents,
          ownerId: user.id,
        ).catchError((e) {
          debugPrint('❌ Error sending notifications: $e');
          // No lanzar error, las notificaciones son "best effort"
        });
      }

      isLoading = false;
      notifyListeners();

      return success;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  // ==================== SCENARIO 8: DRAFT FUNCTIONALITY ====================

  /// Check if user is offline
  bool get isOffline => !_connectivity.isConnected;

  /// Check if in draft mode
  bool get isDraftMode => _isDraftMode || isOffline;

  /// Start auto-save timer (every 5 seconds - Scenario 8)
  void _startAutoSave() {
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _autoSaveDraft();
    });
    debugPrint('[CreatePostVM] 🔄 Auto-save started (every 5 seconds)');
  }

  /// Auto-save draft
  Future<void> _autoSaveDraft() async {
    try {
      // Only auto-save if there's content
      if (!_hasContent()) {
        return;
      }

      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      _draftId ??= const Uuid().v4();

      // Get current location (optional)
      double? latitude;
      double? longitude;
      try {
        final position = await _nearbyService.getCurrentLocationWithPermissions();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
        }
      } catch (e) {
        debugPrint('[CreatePostVM] ⚠️ Could not get location for draft: $e');
      }

      final draft = DraftPost(
        draftId: _draftId!,
        userId: currentUser.uid,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        price: double.tryParse(priceController.text) ?? 0.0,
        categoryId: selectedCategory,
        categoryName: selectedCategoryName,
        localImagePaths: isOffline ? localImagePaths : imagePaths,
        status: DraftStatus.editing,
        latitude: latitude,
        longitude: longitude,
      );

      await _draftService.saveDraft(draft);
      _lastAutoSave = DateTime.now();
      
      debugPrint('[CreatePostVM] 💾 Auto-saved draft: ${draft.title.isEmpty ? "(untitled)" : draft.title}');
    } catch (e) {
      debugPrint('[CreatePostVM] ❌ Auto-save failed: $e');
    }
  }

  /// Check if form has content
  bool _hasContent() {
    return titleController.text.trim().isNotEmpty ||
           descriptionController.text.trim().isNotEmpty ||
           priceController.text.trim().isNotEmpty ||
           imagePaths.isNotEmpty ||
           localImagePaths.isNotEmpty;
  }

  /// Load draft (when editing existing draft)
  Future<void> loadDraft(String draftId) async {
    try {
      final draft = await _draftService.getDraft(draftId);
      if (draft == null) {
        throw Exception('Draft not found');
      }

      _draftId = draft.draftId;
      _isDraftMode = true;

      titleController.text = draft.title;
      descriptionController.text = draft.description;
      priceController.text = draft.price > 0 ? draft.price.toStringAsFixed(2) : '';
      selectedCategory = draft.categoryId;
      selectedCategoryName = draft.categoryName;
      
      if (isOffline) {
        localImagePaths = List.from(draft.localImagePaths);
      } else {
        imagePaths = List.from(draft.localImagePaths);
      }

      notifyListeners();
      debugPrint('[CreatePostVM] ✓ Draft loaded: ${draft.title}');
    } catch (e) {
      debugPrint('[CreatePostVM] ❌ Failed to load draft: $e');
      rethrow;
    }
  }

  /// Save draft manually (when user taps "Save Draft")
  Future<void> saveDraftManually() async {
    try {
      isLoading = true;
      notifyListeners();

      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      _draftId ??= const Uuid().v4();

      // Get current location (optional)
      double? latitude;
      double? longitude;
      try {
        final position = await _nearbyService.getCurrentLocationWithPermissions();
        if (position != null) {
          latitude = position.latitude;
          longitude = position.longitude;
          debugPrint('[CreatePostVM] 📍 Location captured: ($latitude, $longitude)');
        }
      } catch (e) {
        debugPrint('[CreatePostVM] ⚠️ Could not get location for draft: $e');
      }

      final draft = DraftPost(
        draftId: _draftId!,
        userId: currentUser.uid,
        title: titleController.text.trim(),
        description: descriptionController.text.trim(),
        price: double.tryParse(priceController.text) ?? 0.0,
        categoryId: selectedCategory,
        categoryName: selectedCategoryName,
        localImagePaths: isOffline ? localImagePaths : imagePaths,
        status: isOffline ? DraftStatus.pendingUpload : DraftStatus.editing,
        latitude: latitude,
        longitude: longitude,
      );

      await _draftService.saveDraft(draft);

      isLoading = false;
      notifyListeners();

      debugPrint('[CreatePostVM] ✓ Draft saved manually');
    } catch (e) {
      isLoading = false;
      notifyListeners();
      debugPrint('[CreatePostVM] ❌ Failed to save draft: $e');
      rethrow;
    }
  }

  /// Pick image for draft (saves to cache when offline)
  Future<String?> pickImageForDraft({required bool fromCamera}) async {
    try {
      if (isOffline) {
        // Offline: Save to cache directory
        final currentUser = auth.FirebaseAuth.instance.currentUser;
        if (currentUser == null) {
          throw Exception('User not logged in');
        }

        _draftId ??= const Uuid().v4();

        // Pick image file
        File? imageFile;
        if (fromCamera) {
          // Use image_picker to get file
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(source: ImageSource.camera);
          if (pickedFile != null) {
            imageFile = File(pickedFile.path);
          }
        } else {
          final picker = ImagePicker();
          final pickedFile = await picker.pickImage(source: ImageSource.gallery);
          if (pickedFile != null) {
            imageFile = File(pickedFile.path);
          }
        }

        if (imageFile == null) return null;

        // Save to cache directory
        final localPath = await _draftService.saveImageToCache(imageFile, _draftId!);
        localImagePaths.add(localPath);
        notifyListeners();

        debugPrint('[CreatePostVM] 📷 Image saved to cache: $localPath');
        return localPath;
      } else {
        // Online: Upload to Firebase Storage (existing behavior)
        return await pickAndUploadImage(fromCamera: fromCamera);
      }
    } catch (e) {
      debugPrint('[CreatePostVM] ❌ Failed to pick image: $e');
      rethrow;
    }
  }

  /// Delete draft
  Future<void> deleteDraft(String draftId) async {
    try {
      await _draftService.deleteDraft(draftId);
      debugPrint('[CreatePostVM] ✓ Draft deleted');
    } catch (e) {
      debugPrint('[CreatePostVM] ❌ Failed to delete draft: $e');
      rethrow;
    }
  }

  /// Remove local image (offline draft image)
  void removeLocalImage(int index) {
    if (index >= 0 && index < localImagePaths.length) {
      localImagePaths.removeAt(index);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    super.dispose();
  }
}


