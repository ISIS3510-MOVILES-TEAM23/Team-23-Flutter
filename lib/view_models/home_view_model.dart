import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/post_repository.dart';
import '../services/recommendation_service.dart';
import '../services/major_recommendations_service.dart';
import '../services/nearby_products_service.dart';
import '../services/connectivity_service.dart';
import '../services/cache_service.dart';
import '../services/image_cache_service.dart';

class HomeViewModel extends ChangeNotifier {
  final PostRepository _postRepository;
  final NearbyProductsService _nearbyService;
  final ConnectivityService _connectivity = ConnectivityService();
  final CacheService _cache = CacheService();
  final ImageCacheService _imageCache = ImageCacheService();

  // Expose connectivity for listeners (Scenario 5)
  ConnectivityService get connectivity => _connectivity;

  HomeViewModel({
    PostRepository? postRepository,
    NearbyProductsService? nearbyProductsService,
  })  : _postRepository = postRepository ?? PostRepository(),
        _nearbyService = nearbyProductsService ?? NearbyProductsService();

  List<Post> highlightedProducts = [];
  List<Post> newProducts = [];
  List<Post> filteredNewProducts = [];
  bool isLoading = true;
  bool isOffline = false;
  bool isLoadingFromCache = false;
  String? cacheAge;
  String? _lastSearchQuery;

  bool get hasSearchQuery => (_lastSearchQuery?.isNotEmpty ?? false);
  String? get lastSearchQuery => _lastSearchQuery;

  // --- Recommendations state ---
  final RecommendationService _recService = RecommendationService();
  final MajorRecommendationsService _majorRecService = MajorRecommendationsService();
  List<Post> recommendedProducts = [];
  List<Post> majorBasedProducts = [];
  bool isLoadingRecommendations = false;
  bool isLoadingMajorBased = false;
  String? majorBasedTitle; // Título dinámico para la sección

  // --- Nearby products state ---
  List<Post> nearbyProducts = [];
  bool isLoadingNearbyProducts = false;

  Future<void> loadProducts() async {
    try {
      isLoading = true;
      isOffline = !_connectivity.isConnected;

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[Home] 🔍 START loadProducts');
      debugPrint('[Home] 📶 isOffline: $isOffline');
      debugPrint('[Home] 🌐 connectivity status: ${_connectivity.currentStatus}');

      notifyListeners();

      // Scenario 3 & 4: Try network first, fallback to cache
      if (_connectivity.isConnected) {
        // Online - fetch from network with timeout
        debugPrint('[Home] ✅ ONLINE - Fetching from network...');
        try {
          final newProds = await _postRepository.getNewPosts()
              .timeout(const Duration(seconds: 8));

          debugPrint('[Home] 📥 Received ${newProds.length} products from network');

          // Si Firestore devuelve 0 posts, usar cache
          if (newProds.isEmpty) {
            debugPrint('[Home] ⚠️ Network returned 0 posts, using cache...');
            await _loadFromCache();
          } else {
            // Cache the results
            debugPrint('[Home] 💾 Caching ${newProds.length} products to Hive...');
            await _cache.cachePosts(newProds.map((p) => p.toJson()).toList());
            debugPrint('[Home] ✅ Cache saved successfully');

            newProducts = newProds;
            filteredNewProducts = List<Post>.from(newProds);
            isLoadingFromCache = false;
            cacheAge = null;

            debugPrint('[Home] ✓ Loaded ${newProds.length} products from network');
          }
        } catch (e) {
          debugPrint('[Home] ❌ Network fetch failed: $e');
          debugPrint('[Home] 🔄 Trying cache fallback...');
          await _loadFromCache();
        }
      } else {
        // Offline - load from cache (Scenario 3)
        debugPrint('[Home] 📴 OFFLINE - Loading from cache');
        await _loadFromCache();
      }

      // Cargar productos basados en major
      debugPrint('[Home] 🎓 Loading major-based products...');
      await loadMajorBasedProducts();

      // Cache major-based products when online
      if (_connectivity.isConnected && majorBasedProducts.isNotEmpty) {
        await _cache.cacheMajorBasedProducts(
          majorBasedProducts.map((p) => p.toJson()).toList(),
        );
      }

      isLoading = false;
      notifyListeners();

      debugPrint('[Home] 🏁 END loadProducts - Final count: ${newProducts.length}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    } catch (e) {
      isLoading = false;
      notifyListeners();
      debugPrint('[Home] ✗ FATAL ERROR loading products: $e');
      rethrow;
    }
  }

  Future<void> _loadFromCache() async {
    debugPrint('[Cache] 🔍 Checking Hive for cached posts...');

    // Combine all cached products: newPosts + recommended + major-based
    final cachedNewPosts = await _cache.getCachedPosts();
    final cachedRecommended = await _cache.getCachedRecommendedProducts();
    final cachedMajorBased = await _cache.getCachedMajorBasedProducts();

    debugPrint('[Cache] 📦 New posts: ${cachedNewPosts?.length ?? 0}');
    debugPrint('[Cache] 📦 Recommended: ${cachedRecommended?.length ?? 0}');
    debugPrint('[Cache] 📦 Major-based: ${cachedMajorBased?.length ?? 0}');

    // Combine all cached posts (avoiding duplicates by ID)
    final Map<String, Post> combinedPosts = {};

    if (cachedNewPosts != null) {
      for (final json in cachedNewPosts) {
        try {
          final post = Post.fromJson(json);
          combinedPosts[post.id] = post;
        } catch (e) {
          debugPrint('[Cache] ❌ Error parsing cached post: $e');
        }
      }
    }

    if (cachedRecommended != null) {
      for (final json in cachedRecommended) {
        try {
          final post = Post.fromJson(json);
          if (!combinedPosts.containsKey(post.id)) {
            combinedPosts[post.id] = post;
          }
        } catch (e) {
          debugPrint('[Cache] ❌ Error parsing recommended post: $e');
        }
      }
    }

    if (cachedMajorBased != null) {
      for (final json in cachedMajorBased) {
        try {
          final post = Post.fromJson(json);
          if (!combinedPosts.containsKey(post.id)) {
            combinedPosts[post.id] = post;
          }
        } catch (e) {
          debugPrint('[Cache] ❌ Error parsing major-based post: $e');
        }
      }
    }

    if (combinedPosts.isNotEmpty) {
      // Scenario 3: Load combined cache
      debugPrint('[Cache] ✅ Found ${combinedPosts.length} total cached posts');

      // Filter: Only show posts with cached images (offline rule)
      final postsWithCachedImages = <Post>[];
      for (final post in combinedPosts.values) {
        if (post.images.isNotEmpty) {
          final isImageCached = await _imageCache.isImageCached(post.images.first);
          if (isImageCached) {
            postsWithCachedImages.add(post);
          }
        }
      }

      debugPrint('[Cache] 🖼️  Filtered to ${postsWithCachedImages.length}/${combinedPosts.length} posts with cached images');

      newProducts = postsWithCachedImages;
      filteredNewProducts = List<Post>.from(newProducts);
      isLoadingFromCache = true;
      cacheAge = _cache.getCacheAge('posts', 'all_posts');

      debugPrint('[Cache] ✓ Successfully loaded ${newProducts.length} products from cache');
      debugPrint('[Cache] ⏰ Cache age: $cacheAge');
    } else {
      // Scenario 4: No cache available (first time offline)
      newProducts = [];
      filteredNewProducts = [];
      isLoadingFromCache = false;
      cacheAge = null;

      debugPrint('[Cache] ⚠️ No cached products available (first time offline)');
      debugPrint('[Cache] 💡 Tip: Open app with internet first to populate cache');
    }
  }
  
  // Load products viewed by people with the same major
  Future<void> loadMajorBasedProducts({
    int limit = 4, 
    int windowDays = 30,
    bool forceRefresh = false, // New parameter for pull-to-refresh
  }) async {
    isLoadingMajorBased = true;
    notifyListeners();
    try {
      if (_connectivity.isConnected) {
        // Online - fetch from network
        final userMajor = await _majorRecService.getCurrentUserMajor();

        majorBasedProducts = await _majorRecService.getPostsByMajor(
          limit: limit,
          windowDays: windowDays,
          debug: true,
          forceRefresh: forceRefresh, // Pass to service
        );

        // Cache major-based products
        if (majorBasedProducts.isNotEmpty) {
          await _cache.cacheMajorBasedProducts(
            majorBasedProducts.map((p) => p.toJson()).toList(),
          );
        }

        // Determine dynamic title based on major
        if (userMajor != null && userMajor.isNotEmpty) {
          final shortMajor = userMajor.length > 30 ? '${userMajor.substring(0, 30)}...' : userMajor;
          majorBasedTitle = 'Popular in $shortMajor';
        } else if (majorBasedProducts.isNotEmpty) {
          majorBasedTitle = 'Featured';
        } else {
          majorBasedTitle = 'Featured';
        }
      } else {
        // Offline - load from cache
        debugPrint('[Home] 📴 Loading major-based products from cache...');
        final cached = await _cache.getCachedMajorBasedProducts();

        if (cached != null && cached.isNotEmpty) {
          majorBasedProducts = cached
              .map((json) => Post.fromJson(json))
              .toList();
          majorBasedTitle = 'Featured';
          debugPrint('[Home] ✓ Loaded ${majorBasedProducts.length} major-based products from cache');
        } else {
          majorBasedProducts = [];
          majorBasedTitle = 'Featured';
          debugPrint('[Home] ⚠️ No cached major-based products');
        }
      }
    } catch (e) {
      // Try cache fallback on error
      debugPrint('[Home] ❌ Error loading major-based products, trying cache: $e');
      final cached = await _cache.getCachedMajorBasedProducts();
      if (cached != null) {
        majorBasedProducts = cached.map((json) => Post.fromJson(json)).toList();
      } else {
        majorBasedProducts = [];
      }
      majorBasedTitle = 'Featured';
    } finally {
      isLoadingMajorBased = false;
      notifyListeners();
    }
  }

  // Cargar recomendaciones basadas en product_search_events
  Future<void> loadRecommendations({
    int limit = 5, 
    int windowDays = 30,
    bool forceRefresh = false, // New parameter for pull-to-refresh
  }) async {
    isLoadingRecommendations = true;
    notifyListeners();
    try {
      if (_connectivity.isConnected) {
        // Online - fetch from network
        recommendedProducts = await _recService.fetchRecommendations(
          limit: limit,
          windowDays: windowDays,
          debug: true, // Enable debug to see LRU hits/misses
          forceRefresh: forceRefresh, // Pass to service
        );

        // Cache recommended products
        if (recommendedProducts.isNotEmpty) {
          await _cache.cacheRecommendedProducts(
            recommendedProducts.map((p) => p.toJson()).toList(),
          );
        }
      } else {
        // Offline - load from cache
        debugPrint('[Home] 📴 Loading recommended products from cache...');
        final cached = await _cache.getCachedRecommendedProducts();

        if (cached != null && cached.isNotEmpty) {
          recommendedProducts = cached
              .map((json) => Post.fromJson(json))
              .toList();
          debugPrint('[Home] ✓ Loaded ${recommendedProducts.length} recommended products from cache');
        } else {
          recommendedProducts = [];
          debugPrint('[Home] ⚠️ No cached recommended products');
        }
      }
    } catch (e) {
      // Try cache fallback on error
      debugPrint('[Home] ❌ Error loading recommendations, trying cache: $e');
      final cached = await _cache.getCachedRecommendedProducts();
      if (cached != null) {
        recommendedProducts = cached.map((json) => Post.fromJson(json)).toList();
      } else {
        recommendedProducts = [];
      }
    } finally {
      isLoadingRecommendations = false;
      notifyListeners();
    }
  }

  // Cargar productos cercanos geográficamente
  Future<void> loadNearbyProducts({int limit = 10}) async {
    isLoadingNearbyProducts = true;
    notifyListeners();

    try {
      // 1. Obtener UID del usuario (Repository)
      final uid = _postRepository.getCurrentUserId();
      if (uid == null) {
        nearbyProducts = [];
        return;
      }

      // 2. Obtener ubicación actual (Service)
      final position = await _nearbyService.getCurrentLocation();
      if (position == null) {
        nearbyProducts = [];
        return;
      }

      // 3. Obtener todos los posts (Repository)
      final allPosts = await _postRepository.getNewPosts();

      // 4. Filtrar y ordenar por distancia (Service - lógica de negocio)
      nearbyProducts = await _nearbyService.filterNearbyProducts(
        allPosts: allPosts,
        userLatitude: position.latitude,
        userLongitude: position.longitude,
        currentUserId: uid,
        maxDistanceMeters: 5000.0, // Default 5km radius
        limit: limit,
      );

      debugPrint('[HomeViewModel] Loaded ${nearbyProducts.length} nearby products');
    } catch (e) {
      debugPrint('[HomeViewModel] Error loading nearby products: $e');
      nearbyProducts = [];
    } finally {
      isLoadingNearbyProducts = false;
      notifyListeners();
    }
  }

  void applySearch(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _lastSearchQuery = null;
      filteredNewProducts = List<Post>.from(newProducts);
    } else {
      _lastSearchQuery = trimmed;
      filteredNewProducts = _filterProducts(trimmed);
    }
    notifyListeners();
  }

  void clearSearch() {
    if (hasSearchQuery) {
      _lastSearchQuery = null;
      filteredNewProducts = List<Post>.from(newProducts);
      notifyListeners();
    }
  }

  List<Post> _filterProducts(String query) {
    final lowerQuery = query.toLowerCase();
    return newProducts.where((post) {
      final titleMatches = post.title.toLowerCase().contains(lowerQuery);
      final descriptionMatches =
          post.description.toLowerCase().contains(lowerQuery);
      return titleMatches || descriptionMatches;
    }).toList();
  }

  String? resolveCategoryName(String? rawCategory) {
    if (rawCategory == null) return null;
    final trimmed = rawCategory.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.contains('/')) return trimmed;
    final parts = trimmed.split('/');
    return parts.isNotEmpty ? parts.last : trimmed;
  }

  void logProductClick({
    required String productId,
    required String categoryId,
    required String source,
    String? searchQuery,
    String? ownerId,
  }) async {
    final categoryName = resolveCategoryName(categoryId);
    
    // Registrar en product_search_events (para analytics)
    _postRepository.logProductSearchEvent(
      source: source,
      query: searchQuery,
      selectedCategory: categoryName,
      suggestedCategories:
          categoryName != null ? <String>[categoryName] : <String>[],
    );
    
    // Registrar en product_click_events (para recomendaciones basadas en major)
    // SOLO si NO es mi propio producto
    try {
      final currentUser = await _postRepository.getCurrentUser();
      if (currentUser != null && ownerId != null && currentUser.id != ownerId) {
        await _postRepository.logProductClickEvent(
          postId: productId,
          category: categoryName,
          source: source,
        );
      }
    } catch (e) {
      // Error silencioso, no afectar la navegación
      print('Error logging product click event: $e');
    }
  }

  String formatDollars(int cents) => '\$${(cents / 100).toStringAsFixed(2)}';
}

