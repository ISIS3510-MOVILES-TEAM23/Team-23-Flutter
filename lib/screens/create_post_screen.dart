import 'dart:io'; // Scenario 8: For FileImage
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../view_models/create_post_view_model.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  late CreatePostViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = CreatePostViewModel();
    viewModel.loadCategories();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  void _addImage() {
    // Scenario 8: Check total images (online + offline)
    final totalImages = viewModel.imagePaths.length + viewModel.localImagePaths.length;
    if (totalImages >= 5) return;

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

  // Scenario 8: Use pickImageForDraft which handles both online and offline
  Future<void> _pickAndUpload({required bool fromCamera}) async {
    try {
      await viewModel.pickImageForDraft(fromCamera: fromCamera);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo ${viewModel.isOffline ? "guardar" : "subir"} la imagen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _submitPost() async {
    // Scenario 8: If offline, skip full validation (category may not be loaded)
    if (viewModel.isOffline) {
      await _saveDraft();
      return;
    }

    if (!_formKey.currentState!.validate()) return;

    try {
      final success = await viewModel.submitPost();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post product: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _saveDraft() async {
    // Basic validation - just check if there's some content
    if (viewModel.titleController.text.trim().isEmpty &&
        viewModel.descriptionController.text.trim().isEmpty &&
        viewModel.imagePaths.isEmpty &&
        viewModel.localImagePaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least a title, description, or image'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      await viewModel.saveDraftManually();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post saved as draft. It will be published when you\'re online.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 3),
          ),
        );
        context.go('/profile');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save draft: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _analyzeWithAI() async {
    try {
      await viewModel.analyzeWithAI();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✨ Campos autocompletados con IA'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al analizar: $e'),
            backgroundColor: AppColors.error,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
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
                      onTap: viewModel.imagePaths.length < 5 ? _addImage : null,
                      child: Container(
                        width: double.infinity,
                        height: viewModel.imagePaths.isEmpty ? 180 : 120,
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
                              size: viewModel.imagePaths.isEmpty ? 48 : 36,
                              color: AppColors.textSecondary.withOpacity(0.6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              viewModel.imagePaths.isEmpty
                                  ? 'Add photos'
                                  : 'Add more\nphotos',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: viewModel.imagePaths.isEmpty ? 18 : 16,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Photo Carousel (Scenario 8: Shows both online and offline images)
                  if (viewModel.imagePaths.isNotEmpty || viewModel.localImagePaths.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: viewModel.imagePaths.length + viewModel.localImagePaths.length,
                        itemBuilder: (context, index) {
                          // Determine if this is an online or offline image
                          final isOnlineImage = index < viewModel.imagePaths.length;
                          final imagePath = isOnlineImage
                              ? viewModel.imagePaths[index]
                              : viewModel.localImagePaths[index - viewModel.imagePaths.length];
                          
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
                                      image: isOnlineImage 
                                          ? NetworkImage(imagePath) as ImageProvider
                                          : FileImage(File(imagePath)),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                // Offline indicator badge
                                if (!isOnlineImage)
                                  Positioned(
                                    top: 8,
                                    left: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade700,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Draft',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: InkWell(
                                    onTap: () {
                                      if (isOnlineImage) {
                                        viewModel.removeImage(index);
                                      } else {
                                        // Remove local image
                                        viewModel.removeLocalImage(index - viewModel.imagePaths.length);
                                      }
                                    },
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

                  if (viewModel.imagePaths.isNotEmpty || viewModel.localImagePaths.isNotEmpty) 
                    const SizedBox(height: 20),

                  // AI Analysis Button (Scenario 8: Disabled when offline)
                  if (viewModel.imagePaths.isNotEmpty || viewModel.localImagePaths.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: viewModel.isAnalyzing || viewModel.isOffline ? null : _analyzeWithAI,
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(
                                  color: viewModel.isOffline 
                                      ? Colors.grey.withOpacity(0.3)
                                      : AppColors.primaryColor.withOpacity(0.5),
                                  width: 1.5,
                                ),
                              ),
                              icon: viewModel.isAnalyzing
                                  ? const SizedBox(
                                      height: 18,
                                      width: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            AppColors.primaryColor),
                                      ),
                                    )
                                  : Icon(
                                      Icons.auto_awesome,
                                      size: 20,
                                      color: viewModel.isOffline ? Colors.grey : AppColors.primaryColor,
                                    ),
                              label: Text(
                                viewModel.isAnalyzing
                                    ? 'Analizando imagen...'
                                    : '✨ Autocompletar con IA',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: viewModel.isOffline ? Colors.grey : AppColors.primaryColor,
                                ),
                              ),
                            ),
                          ),
                          // Offline message for AI button
                          if (viewModel.isOffline)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'AI features require internet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange.shade700,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  if (viewModel.imagePaths.isNotEmpty) const SizedBox(height: 20),

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
                            controller: viewModel.titleController,
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
                            controller: viewModel.descriptionController,
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
                            controller: viewModel.priceController,
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

                  // Category (Scenario 8: Shows cached categories offline)
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
                          child: viewModel.categories.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        size: 20,
                                        color: Colors.orange.shade700,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          'Categories not available. Please connect to internet to load categories.',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.orange.shade900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : DropdownButtonFormField<String>(
                                  value: viewModel.selectedCategory,
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
                                  items: viewModel.categories.map((category) {
                                    return DropdownMenuItem(
                                      value: category.id,
                                      child: Text(category.name),
                                    );
                                  }).toList(),
                                  onChanged: viewModel.selectCategory,
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

                  // Submit (Scenario 8: Changes to "Save Draft" when offline)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: viewModel.isLoading ? null : _submitPost,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: viewModel.isOffline 
                              ? Colors.orange.shade700 
                              : AppColors.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: viewModel.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  if (viewModel.isOffline)
                                    const Padding(
                                      padding: EdgeInsets.only(right: 8),
                                      child: Icon(Icons.save_outlined, size: 20),
                                    ),
                                  Text(
                                    viewModel.isOffline ? 'Save Draft' : 'Sell',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
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
      },
    );
  }
}
