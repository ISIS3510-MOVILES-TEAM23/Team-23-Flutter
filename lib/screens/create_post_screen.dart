import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../theme/app_colors.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();

  String? selectedCategory;
  String? selectedCategoryName;
  List<String> imagePaths = []; // aquí guardamos los downloadURLs
  List<Category> categories = [];
  bool isLoading = false;

String? _postId;
String _ensurePostId() {
  _postId ??= FirestoreService.generatePostId(); // 👈 robusto y en el service
  return _postId!;
}


  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
    final cats = await FirestoreService.getCategories(debug: true);
      cats.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        categories = cats;
        if (selectedCategory == null && cats.isNotEmpty) {
          selectedCategory = cats.first.id;
          selectedCategoryName = cats.first.name;
        } else if (selectedCategory != null) {
          final match = cats.firstWhere(
            (c) => c.id == selectedCategory,
            orElse: () => cats.isNotEmpty
                ? cats.first
                : Category(id: '', name: '', description: ''),
          );
          if (match.id.isNotEmpty) {
            selectedCategory = match.id;
            selectedCategoryName = match.name;
          } else {
            selectedCategory = null;
            selectedCategoryName = null;
          }
        }
      });
      print('CreatePostScreen: categories loaded (${cats.length})');
    } catch (e, st) {
      print('CreatePostScreen: error loading categories -> $e');
      print(st);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron cargar las categorías: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Abre sheet para elegir galería o cámara y sube a Storage
  void _addImage() {
    if (imagePaths.length >= 5) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de galería'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUpload(fromCamera: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUpload(fromCamera: true);
              },
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }

  // Sube imagen (galería o cámara) y agrega el downloadURL a imagePaths
  Future<void> _pickAndUpload({required bool fromCamera}) async {
  try {
    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para subir imágenes')),
      );
      return;
    }

    final ownerUid = currentUser.uid;
    final productId = _ensurePostId();

    String? url;
    if (fromCamera) {
      url = await StorageService().uploadFromCamera(
        ownerUid: ownerUid,
        productId: productId,
      );
    } else {
      url = await StorageService().uploadFromGallery(
        ownerUid: ownerUid,
        productId: productId,
      );
    }

    if (!mounted) return;
    if (url != null) {
    final String downloadUrl = url;
      setState(() {
        imagePaths.add(downloadUrl); // List<String> ok
      });
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('No se pudo subir la imagen: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  }
}


  
  void _removeImage(int index) async {
    final url = imagePaths[index];
    setState(() {
      imagePaths.removeAt(index);
    });
    try {
      await StorageService().deleteByUrl(url);
    } catch (_) {
    
    }
  }

  Future<void> _submitPost() async {
  if (!_formKey.currentState!.validate()) return;
  if (imagePaths.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please add at least one image'),
        backgroundColor: AppColors.error,
      ),
    );
    return;
  }

  setState(() => isLoading = true);

  try {
    final priceInCents = (double.parse(_priceController.text) * 100).toInt();

    final user = await FirestoreService.getCurrentUser();
    if (user == null) throw Exception('User not logged in');
    final String postId = _postId ?? _ensurePostId();

    if (selectedCategory == null) {
      throw Exception('Category not selected');
    }

    final product = Post(
      id: postId,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
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

    final success = await FirestoreService.createPost(data, forceId: postId);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product posted successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      context.go('/home');
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Failed to post product: $e'),
        backgroundColor: AppColors.error,
      ),
    );
  } finally {
    if (mounted) setState(() => isLoading = false);
  }
}


  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Post'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add Photos Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: InkWell(
                  onTap: imagePaths.length < 5 ? _addImage : null,
                  child: Container(
                    width: double.infinity,
                    height: imagePaths.isEmpty ? 180 : 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.textSecondary.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          size: imagePaths.isEmpty ? 48 : 36,
                          color: AppColors.textSecondary.withOpacity(0.6),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          imagePaths.isEmpty
                              ? 'Add photos'
                              : 'Add more\nphotos',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: imagePaths.isEmpty ? 18 : 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Photo Carousel
              if (imagePaths.isNotEmpty)
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: imagePaths.length,
                    itemBuilder: (context, index) {
                      return Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 12),
                        child: Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.textSecondary.withOpacity(0.2),
                                  width: 1,
                                ),
                                image: DecorationImage(
                                  image: NetworkImage(imagePaths[index]),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: InkWell(
                                onTap: () => _removeImage(index),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

              if (imagePaths.isNotEmpty) const SizedBox(height: 20),

              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Title',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textSecondary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _titleController,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Enter product title',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textSecondary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _descriptionController,
                        maxLines: 4,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: 'Describe your product...',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Do not share contact details',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Price
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Price',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textSecondary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: TextFormField(
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          prefixText: '\$ ',
                          prefixStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: AppColors.textSecondary.withOpacity(0.5),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a price';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid price';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Category
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.textSecondary.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: selectedCategory,
                        style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Select a category',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.all(16),
                        ),
                        dropdownColor: Theme.of(context).cardTheme.color,
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category.id,
                            child: Text(category.name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          final matched = categories.firstWhere(
                            (c) => c.id == value,
                            orElse: () => Category(id: value ?? '', name: value ?? '', description: ''),
                          );
                          setState(() {
                            selectedCategory = value;
                            selectedCategoryName = matched.name;
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Submit
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Sell',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}