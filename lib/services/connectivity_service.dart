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
  final StreamController<bool> _connectionController = 
      StreamController<bool>.broadcast();
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  ConnectivityResult _currentStatus = ConnectivityResult.none;
  bool _isInitialized = false;
  bool _hasConnection = true;

  /// Get current connectivity status
  ConnectivityResult get currentStatus => _currentStatus;

  /// Check if device has internet connection (ConnectivityResult-based)
  bool get isConnected =>
      _currentStatus != ConnectivityResult.none;

  /// Check if device has internet connection (boolean-based, for compatibility)
  bool get hasConnection => _hasConnection;

  /// Stream of connectivity changes (ConnectivityResult)
  Stream<ConnectivityResult> get onConnectivityChanged =>
      _connectivityStreamController.stream;

  /// Stream of connectivity changes (boolean, for compatibility)
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Check current connectivity status (returns boolean for compatibility)
  Future<bool> checkConnectivity() async {
    try {
      final List<ConnectivityResult> result = await _connectivity.checkConnectivity();
      _hasConnection = !result.contains(ConnectivityResult.none);
      _currentStatus = result.first;
      
      debugPrint('[Connectivity] Check result: ${_hasConnection ? "Connected" : "Disconnected"}');
      return _hasConnection;
    } catch (e) {
      debugPrint('[Connectivity] Error checking connectivity: $e');
      _hasConnection = false;
      _currentStatus = ConnectivityResult.none;
      return false;
    }
  }

  /// Start monitoring connectivity changes
  void startMonitoring() {
    if (_connectivitySubscription != null) {
      debugPrint('[Connectivity] Already monitoring');
      return;
    }

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final newStatus = results.first;
        final hasConnection = !results.contains(ConnectivityResult.none);
        
        debugPrint('[Connectivity] 🔔 Change detected: $newStatus');

        // Update status
        if (newStatus != _currentStatus || hasConnection != _hasConnection) {
          final wasConnected = _currentStatus != ConnectivityResult.none;
          final isNowConnected = newStatus != ConnectivityResult.none;

          _currentStatus = newStatus;
          _hasConnection = hasConnection;
          
          // Emit to both streams
          _connectivityStreamController.add(newStatus);
          _connectionController.add(hasConnection);

          // Log significant state changes
          if (!wasConnected && isNowConnected) {
            debugPrint('[Connectivity] 🟢 Connection restored: $newStatus');
          } else if (wasConnected && !isNowConnected) {
            debugPrint('[Connectivity] 🔴 Connection lost');
          }
        }
      },
      onError: (error) {
        debugPrint('[Connectivity] Monitoring error: $error');
      },
    );
    
    _isInitialized = true;
    debugPrint('[Connectivity] ✓ Started monitoring');
  }

  /// Stop monitoring connectivity
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    debugPrint('[Connectivity] Stopped monitoring');
  }

  /// Initialize connectivity monitoring (auto-starts monitoring)
  Future<void> initialize() async {
    try {
      debugPrint('[Connectivity] 🔍 Initializing...');

      // Get current status
      final result = await _connectivity.checkConnectivity();
      final newStatus = result.first;
      final hasConnection = !result.contains(ConnectivityResult.none);

      _currentStatus = newStatus;
      _hasConnection = hasConnection;

      debugPrint('[Connectivity] � Raw result: $result');
      debugPrint('[Connectivity] � Status: $newStatus (${hasConnection ? "Connected" : "Disconnected"})');
      debugPrint('[Connectivity] ✓ Initialized with status: $_currentStatus');

      // Start monitoring if not already started
      if (!_isInitialized && _connectivitySubscription == null) {
        startMonitoring();
      }
    } catch (e) {
      debugPrint('[Connectivity] ✗ Initialization failed: $e');
      _currentStatus = ConnectivityResult.none;
      _hasConnection = false;
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
    stopMonitoring();
    _connectivityStreamController.close();
    _connectionController.close();
    _isInitialized = false;
  }
}
