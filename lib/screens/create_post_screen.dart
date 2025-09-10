import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../services/mock_service.dart';
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
  String selectedCondition = 'good';
  List<String> imagePaths = [];
  List<Category> categories = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final cats = await MockService.getCategories();
    setState(() {
      categories = cats;
    });
  }

  void _addImage() {
    // Simulate image selection
    if (imagePaths.length < 5) {
      setState(() {
        imagePaths.add('https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/400/400');
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      imagePaths.removeAt(index);
    });
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

    setState(() {
      isLoading = true;
    });

    try {
      final productData = {
        'title': _titleController.text,
        'description': _descriptionController.text,
        'price': double.parse(_priceController.text),
        'categoryId': selectedCategory,
        'condition': selectedCondition,
        'images': imagePaths,
      };

      final success = await MockService.createProduct(productData);
      
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to post product'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
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
        title: const Text('Create Post'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Upload Section
              const Text(
                'Photos',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Add up to 5 photos',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: imagePaths.length + (imagePaths.length < 5 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == imagePaths.length) {
                      return GestureDetector(
                        onTap: _addImage,
                        child: Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primaryColor.withOpacity(0.3),
                              width: 2,
                              style: BorderStyle.solid,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate,
                                size: 32,
                                color: AppColors.primaryColor,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Add Photo',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    return Container(
                      width: 100,
                      margin: const EdgeInsets.only(right: 12),
                      child: Stack(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              image: DecorationImage(
                                image: NetworkImage(imagePaths[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
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
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Enter product title',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Description
              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe your product...',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Price
              const Text(
                'Price',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: '0.00',
                  prefixText: '\$ ',
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
              const SizedBox(height: 24),
              
              // Category
              const Text(
                'Category',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: const InputDecoration(
                  hintText: 'Select a category',
                ),
                items: categories.map((category) {
                  return DropdownMenuItem(
                    value: category.id,
                    child: Text('${category.icon} ${category.name}'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Please select a category';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Condition
              const Text(
                'Condition',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('New'),
                    selected: selectedCondition == 'new',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedCondition = 'new';
                        });
                      }
                    },
                    selectedColor: AppColors.success.withOpacity(0.2),
                  ),
                  ChoiceChip(
                    label: const Text('Like New'),
                    selected: selectedCondition == 'like_new',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedCondition = 'like_new';
                        });
                      }
                    },
                    selectedColor: AppColors.info.withOpacity(0.2),
                  ),
                  ChoiceChip(
                    label: const Text('Good'),
                    selected: selectedCondition == 'good',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedCondition = 'good';
                        });
                      }
                    },
                    selectedColor: AppColors.warning.withOpacity(0.2),
                  ),
                  ChoiceChip(
                    label: const Text('Fair'),
                    selected: selectedCondition == 'fair',
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedCondition = 'fair';
                        });
                      }
                    },
                    selectedColor: AppColors.error.withOpacity(0.2),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submitPost,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Post Product',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}