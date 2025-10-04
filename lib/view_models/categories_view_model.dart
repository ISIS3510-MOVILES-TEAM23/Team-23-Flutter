import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/category_repository.dart';

class CategoriesViewModel extends ChangeNotifier {
  final CategoryRepository _categoryRepository;

  CategoriesViewModel({CategoryRepository? categoryRepository})
      : _categoryRepository = categoryRepository ?? CategoryRepository();

  List<Category> categories = [];
  bool isLoading = true;

  // Icon mapping for each category
  final Map<String, IconData> categoryIcons = {
    'electronics': Icons.devices_outlined,
    'books': Icons.menu_book_outlined,
    'clothes': Icons.checkroom_outlined,
    'furniture': Icons.chair_outlined,
    'school': Icons.backpack_outlined,
    'appliances': Icons.kitchen_outlined,
    'sports': Icons.sports_basketball_outlined,
    'music': Icons.music_note_outlined,
    'other': Icons.category_outlined,
  };

  Future<void> loadCategories() async {
    try {
      isLoading = true;
      notifyListeners();

      final cats = await _categoryRepository.getCategories();

      categories = cats;
      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  IconData getIconForCategory(String categoryName) {
    return categoryIcons[categoryName.toLowerCase()] ??
        Icons.category_outlined;
  }
}

