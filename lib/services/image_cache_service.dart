import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// Service to pre-cache images for offline availability
class ImageCacheService {
  static final ImageCacheService _instance = ImageCacheService._internal();
  factory ImageCacheService() => _instance;
  ImageCacheService._internal();

  final CacheManager _cacheManager = DefaultCacheManager();

  /// Pre-cache a single image URL
  Future<bool> preCacheImage(String imageUrl) async {
    if (imageUrl.isEmpty) return false;

    try {
      final cached = await _cacheManager.getFileFromCache(imageUrl);
      if (cached != null && cached.file.existsSync()) {
        return true;
      }

      await _cacheManager.downloadFile(imageUrl);
      return true;
    } catch (e) {
      debugPrint('[ImageCache] ✗ Failed to cache: $imageUrl -> $e');
      return false;
    }
  }

  /// Pre-cache multiple image URLs (deduplicated)
  Future<Map<String, bool>> preCacheImages(List<String> imageUrls) async {
    final results = <String, bool>{};
    final uniqueUrls = imageUrls.where((url) => url.isNotEmpty).toSet();

    for (final url in uniqueUrls) {
      final success = await preCacheImage(url);
      results[url] = success;
    }

    return results;
  }

  /// Check if an image is cached
  Future<bool> isImageCached(String imageUrl) async {
    if (imageUrl.isEmpty) return false;

    try {
      final fileInfo = await _cacheManager.getFileFromCache(imageUrl);
      return fileInfo != null && fileInfo.file.existsSync();
    } catch (e) {
      return false;
    }
  }

  /// Check if all images in a list are cached (checks first image only)
  Future<bool> areImagesCached(List<String> imageUrls) async {
    if (imageUrls.isEmpty) return false;

    // Only check first image
    return await isImageCached(imageUrls.first);
  }

  /// Clear all cached images
  Future<void> clearCache() async {
    await _cacheManager.emptyCache();
  }

  /// Get cache size info
  Future<int> getCacheSize() async {
    // Note: CacheManager doesn't provide direct size info
    // This is an approximation
    return 0;
  }
}
