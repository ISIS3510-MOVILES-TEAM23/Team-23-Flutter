import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/category_repository.dart';
import '../services/cache_service.dart';
import '../services/connectivity_service.dart';

class CategoriesViewModel extends ChangeNotifier {
  final CategoryRepository _categoryRepository;
  final CacheService _cache = CacheService();
  final ConnectivityService _connectivity = ConnectivityService();

  CategoriesViewModel({CategoryRepository? categoryRepository})
      : _categoryRepository = categoryRepository ?? CategoryRepository();

  List<Category> categories = [];
  bool isLoading = true;
  bool isLoadedFromCache = false;

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

      List<Category> cats = [];

      // Try network first if online
      if (_connectivity.isConnected) {
        try {
          cats = await _categoryRepository.getCategories();
          // Cache categories
          await _cache.cacheCategories(cats.map((c) => c.toJson()).toList());
          isLoadedFromCache = false;
        } catch (e) {
          debugPrint('[Categories] Network failed, trying cache: $e');
          // Fallback to cache
          final cached = await _cache.getCachedCategories();
          if (cached != null) {
            cats = cached.map((json) => Category.fromJson(json)).toList();
            isLoadedFromCache = true;
          }
        }
      } else {
        // Offline - load from cache
        debugPrint('[Categories] Offline - loading from cache');
        final cached = await _cache.getCachedCategories();
        if (cached != null) {
          cats = cached.map((json) => Category.fromJson(json)).toList();
          isLoadedFromCache = true;
        }
      }

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

