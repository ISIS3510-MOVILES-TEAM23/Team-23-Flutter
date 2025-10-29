import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Service to monitor and manage network connectivity state
/// Follows singleton pattern for global access
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<ConnectivityResult> _connectivityStreamController =
      StreamController<ConnectivityResult>.broadcast();

  ConnectivityResult _currentStatus = ConnectivityResult.none;
  bool _isInitialized = false;

  /// Get current connectivity status
  ConnectivityResult get currentStatus => _currentStatus;

  /// Check if device has internet connection
  bool get isConnected =>
      _currentStatus != ConnectivityResult.none;

  /// Stream of connectivity changes
  Stream<ConnectivityResult> get onConnectivityChanged =>
      _connectivityStreamController.stream;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    try {
      debugPrint('[Connectivity] 🔍 Checking connectivity...');

      // Get current status
      final result = await _connectivity.checkConnectivity();
      final newStatus = result.first;

      debugPrint('[Connectivity] 📡 Raw result: $result');
      debugPrint('[Connectivity] 📶 Status: $newStatus');

      // Update status if changed or first init
      if (newStatus != _currentStatus || !_isInitialized) {
        final wasConnected = _currentStatus != ConnectivityResult.none;
        final isNowConnected = newStatus != ConnectivityResult.none;

        _currentStatus = newStatus;

        // Log significant state changes
        if (!_isInitialized) {
          debugPrint('[Connectivity] ✓ Initialized with status: $_currentStatus');
        } else if (!wasConnected && isNowConnected) {
          debugPrint('[Connectivity] 🟢 Connection restored: $newStatus');
        } else if (wasConnected && !isNowConnected) {
          debugPrint('[Connectivity] 🔴 Connection lost');
        }
      }

      if (!_isInitialized) {
        // Listen to connectivity changes
        _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
          final newStatus = results.first;
          debugPrint('[Connectivity] 🔔 Change detected: $newStatus');

          if (newStatus != _currentStatus) {
            final wasConnected = _currentStatus != ConnectivityResult.none;
            final isNowConnected = newStatus != ConnectivityResult.none;

            _currentStatus = newStatus;
            _connectivityStreamController.add(newStatus);

            // Log significant state changes
            if (!wasConnected && isNowConnected) {
              debugPrint('[Connectivity] 🟢 Connection restored: $newStatus');
            } else if (wasConnected && !isNowConnected) {
              debugPrint('[Connectivity] 🔴 Connection lost');
            }
          }
        });
        _isInitialized = true;
      }
    } catch (e) {
      debugPrint('[Connectivity] ✗ Initialization failed: $e');
      _currentStatus = ConnectivityResult.none;
      _isInitialized = true;
    }
  }

  /// Wait for connection to be restored
  /// Returns true if connected, false if timeout
  Future<bool> waitForConnection({Duration timeout = const Duration(seconds: 30)}) async {
    if (isConnected) return true;

    final completer = Completer<bool>();
    StreamSubscription<ConnectivityResult>? subscription;

    subscription = onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none && !completer.isCompleted) {
        completer.complete(true);
        subscription?.cancel();
      }
    });

    // Set timeout
    Future.delayed(timeout, () {
      if (!completer.isCompleted) {
        completer.complete(false);
        subscription?.cancel();
      }
    });

    return completer.future;
  }

  /// Dispose resources
  void dispose() {
    _connectivityStreamController.close();
    _isInitialized = false;
  }
}
