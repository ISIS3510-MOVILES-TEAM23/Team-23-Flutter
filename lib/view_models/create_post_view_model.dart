import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/models.dart';
import '../data/repositories/category_repository.dart';
import '../data/repositories/post_repository.dart';
import '../data/repositories/storage_repository.dart';
import '../data/repositories/user_repository.dart';

class CreatePostViewModel extends ChangeNotifier {
  final CategoryRepository _categoryRepository;
  final PostRepository _postRepository;
  final StorageRepository _storageRepository;
  final UserRepository _userRepository;

  CreatePostViewModel({
    CategoryRepository? categoryRepository,
    PostRepository? postRepository,
    StorageRepository? storageRepository,
    UserRepository? userRepository,
  })  : _categoryRepository = categoryRepository ?? CategoryRepository(),
        _postRepository = postRepository ?? PostRepository(),
        _storageRepository = storageRepository ?? StorageRepository(),
        _userRepository = userRepository ?? UserRepository();

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController priceController = TextEditingController();

  String? selectedCategory;
  String? selectedCategoryName;
  List<String> imagePaths = [];
  List<Category> categories = [];
  bool isLoading = false;
  String? _postId;

  String ensurePostId() {
    _postId ??= _postRepository.generatePostId();
    return _postId!;
  }

  Future<void> loadCategories() async {
    try {
      final cats = await _categoryRepository.getCategories(debug: true);
      cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      categories = cats;
      if (selectedCategory == null && cats.isNotEmpty) {
        selectedCategory = cats.first.id;
        selectedCategoryName = cats.first.name;
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
      rethrow;
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
      );

      final data = product.toJson();
      data['_id'] = postId;
      data['category_id'] = FirebaseFirestore.instance
          .collection('categories')
          .doc(selectedCategory);
      data['category_name'] = selectedCategoryName ?? '';

      final success = await _postRepository.createPost(data, forceId: postId);

      isLoading = false;
      notifyListeners();

      return success;
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    priceController.dispose();
    super.dispose();
  }
}

