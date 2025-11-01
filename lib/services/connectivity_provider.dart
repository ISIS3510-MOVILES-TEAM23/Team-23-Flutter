import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'connectivity_service.dart';
import 'cache_service.dart';

/// Global connectivity provider for app-wide offline state
class ConnectivityProvider extends ChangeNotifier {
  final ConnectivityService _connectivity = ConnectivityService();
  final CacheService _cache = CacheService();
  bool _isOffline = false;
  String? _cacheAge;

  bool get isOffline => _isOffline;
  bool get isOnline => !_isOffline;
  String? get cacheAge => _cacheAge;

  ConnectivityProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    // Get initial status
    await _connectivity.initialize();
    _isOffline = !_connectivity.isConnected;
    _updateCacheAge();
    notifyListeners();

    // Listen for changes
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOffline = _isOffline;
      _isOffline = (result == ConnectivityResult.none);

      if (wasOffline != _isOffline) {
        debugPrint('[ConnectivityProvider] Status changed: ${_isOffline ? "OFFLINE" : "ONLINE"}');
        _updateCacheAge();
        notifyListeners();
      }
    });
  }

  void _updateCacheAge() {
    if (_isOffline) {
      _cacheAge = _cache.getCacheAge('posts', 'all_posts') ?? 'Unknown';
    } else {
      _cacheAge = null;
    }
  }

  /// Force refresh connectivity status
  Future<void> refresh() async {
    await _connectivity.initialize();
    _isOffline = !_connectivity.isConnected;
    _updateCacheAge();
    notifyListeners();
  }
}
