import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Service to poll the status of a sale in Firestore
/// This is useful for the seller to get real-time feedback when the buyer completes the purchase
class SalePollingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _pollingTimer;
  String? _currentSaleId;
  Function(String status)? _onStatusChanged;
  String? _lastKnownStatus;

  /// Starts polling for the sale status
  /// 
  /// [saleId] - The ID of the sale to monitor
  /// [onStatusChanged] - Callback function that gets called when the status changes
  /// [intervalSeconds] - How often to check for updates (default: 3 seconds)
  void startPolling({
    required String saleId,
    required Function(String status) onStatusChanged,
    int intervalSeconds = 3,
  }) {
    // Stop any existing polling
    stopPolling();

    _currentSaleId = saleId;
    _onStatusChanged = onStatusChanged;
    _lastKnownStatus = null;

    debugPrint('[SalePollingService] Starting polling for sale: $saleId');

    // Initial fetch
    _checkSaleStatus();

    // Start periodic polling
    _pollingTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _checkSaleStatus(),
    );
  }

  /// Checks the current status of the sale
  Future<void> _checkSaleStatus() async {
    if (_currentSaleId == null) return;

    try {
      final doc = await _db.collection('sales').doc(_currentSaleId).get();
      
      if (!doc.exists) {
        debugPrint('[SalePollingService] Sale document not found: $_currentSaleId');
        return;
      }

      final data = doc.data();
      if (data == null) return;

      final currentStatus = data['status'] as String?;
      
      if (currentStatus != null && currentStatus != _lastKnownStatus) {
        debugPrint('[SalePollingService] Status changed from $_lastKnownStatus to $currentStatus');
        _lastKnownStatus = currentStatus;
        
        // Notify the callback
        if (_onStatusChanged != null) {
          _onStatusChanged!(currentStatus);
        }

        // If the sale is completed or canceled, stop polling
        if (currentStatus == 'completed' || currentStatus == 'canceled') {
          debugPrint('[SalePollingService] Sale reached final state: $currentStatus. Stopping polling.');
          stopPolling();
        }
      }else{
        debugPrint('[SalePollingService] No status change. Current status: $currentStatus');
      }
    } catch (e) {
      debugPrint('[SalePollingService] Error checking sale status: $e');
    }
  }

  /// Stops the polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _currentSaleId = null;
    _onStatusChanged = null;
    _lastKnownStatus = null;
    debugPrint('[SalePollingService] Polling stopped');
  }

  /// Checks if currently polling
  bool get isPolling => _pollingTimer != null && _pollingTimer!.isActive;

  /// Gets the current sale ID being monitored
  String? get currentSaleId => _currentSaleId;

  /// Manually fetch the current status without starting polling
  Future<String?> fetchCurrentStatus(String saleId) async {
    try {
      final doc = await _db.collection('sales').doc(saleId).get();
      if (!doc.exists) return null;
      
      final data = doc.data();
      return data?['status'] as String?;
    } catch (e) {
      debugPrint('[SalePollingService] Error fetching status: $e');
      return null;
    }
  }

  /// Dispose and clean up resources
  void dispose() {
    stopPolling();
  }
}
