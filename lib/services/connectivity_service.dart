import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Service to monitor internet connectivity status
class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  /// Current connectivity status
  bool _hasConnection = true;
  bool get hasConnection => _hasConnection;
  
  /// Stream controller for connectivity changes
  final _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
      _hasConnection = !result.contains(ConnectivityResult.none);
      return _hasConnection;
    } catch (e) {
      debugPrint('Error checking connectivity: $e');
      return false;
    }
  }

  /// Start listening to connectivity changes
  void startMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> result) {
        final hasConnection = !result.contains(ConnectivityResult.none);
        if (_hasConnection != hasConnection) {
          _hasConnection = hasConnection;
          _connectionController.add(_hasConnection);
          debugPrint('Connectivity changed: ${_hasConnection ? "Connected" : "Disconnected"}');
        }
      },
      onError: (error) {
        debugPrint('Connectivity monitoring error: $error');
      },
    );
  }

  /// Stop monitoring connectivity
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Dispose resources
  void dispose() {
    stopMonitoring();
    _connectionController.close();
  }
}
