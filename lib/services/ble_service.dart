import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
import 'package:permission_handler/permission_handler.dart';

class BleService {
  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';
  static const int manufacturerId = 0xFFFF;
  Map<String, DiscoveredDevice> discoveredDevices = {};
  DiscoveredDevice? selectedDevice;

  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();
  final FlutterReactiveBle _reactiveBle = FlutterReactiveBle();

  StreamSubscription<DiscoveredDevice>? _scanSubscription;
  Timer? _advertisingTimer;
  
  // Isolate management for data processing (if needed in future)
  Isolate? _dataProcessingIsolate;
  ReceivePort? _dataProcessingReceivePort;
  
  bool _isAdvertising = false;
  bool _isScanning = false;

  Future<bool> requestBlePermissions() async {
    final androidVersion = await _getAndroidVersion();
    bool allGranted = true;

    if (androidVersion >= 31) {
      // Android 12+
      final permissions = [
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ];
      for (final permission in permissions) {
        final status = await permission.request();
        debugPrint('[Permissions] ${permission.toString()}: $status');
        if (status != PermissionStatus.granted) {
          allGranted = false;
        }
      }
    } else {
      final status = await Permission.location.request();
      debugPrint('[Permissions] location: $status');
      if (status != PermissionStatus.granted) {
        allGranted = false;
      }
    }

    return allGranted;
  }

  Future<int> _getAndroidVersion() async {
    // Simplified, assume Android 12+ for now, or use device_info_plus
    // For simplicity, return 31 (Android 12)
    return 31;
  }

  // Buyer (Advertising) - Runs on main isolate with async operations
  Future<void> startAdvertising(
      String postId, String userId, VoidCallback onStop) async {
    if (_isAdvertising) {
      debugPrint('[Buyer] Already advertising. Stop existing advertising first.');
      return;
    }

    final payload = '$postId|$userId';
    debugPrint('[Buyer] Starting advertising with payload: $payload');

    try {
      final data = utf8.encode(payload);
      
      await _peripheral.start(
        advertiseData: AdvertiseData(
          serviceUuid: serviceUuid,
          manufacturerId: manufacturerId,
          manufacturerData: data,
          includeDeviceName: true,
        ),
      );

      _isAdvertising = true;
      debugPrint('[Buyer] Advertising started successfully');

      // Auto-stop after 60 seconds
      _advertisingTimer = Timer(const Duration(seconds: 60), () {
        debugPrint('[Buyer] Advertising timeout reached');
        stopAdvertising(onStop);
      });
    } catch (e) {
      debugPrint('[Buyer] Error starting advertising: $e');
      _isAdvertising = false;
    }
  }

  Future<void> stopAdvertising(VoidCallback? onStop) async {
    if (!_isAdvertising) {
      debugPrint('[Buyer] Not currently advertising');
      return;
    }

    try {
      await _peripheral.stop();
      _isAdvertising = false;
      debugPrint('[Buyer] Advertising stopped.');
    } catch (e) {
      debugPrint('[Buyer] Error stopping advertising: $e');
    }
    
    _advertisingTimer?.cancel();
    _advertisingTimer = null;
    onStop?.call();
  }

  // Seller (Scanning) - Runs on main isolate with stream subscription
  void startScanning(
      Function(String id, String name, Uint8List data) onDeviceDiscovered) {
    if (_isScanning) {
      debugPrint('[Seller] Already scanning. Stop existing scan first.');
      return;
    }

    debugPrint('[Seller] Starting scan.');
    
    try {
      _scanSubscription = _reactiveBle.scanForDevices(
        withServices: [],
        scanMode: ScanMode.lowLatency,
      ).listen((device) {
        _processScannedDevice(device, onDeviceDiscovered);
      }, onError: (error) {
        debugPrint('[Seller] Scan error: $error');
      });
      
      _isScanning = true;
      debugPrint('[Seller] Scan started successfully');
    } catch (e) {
      debugPrint('[Seller] Error starting scan: $e');
    }
  }

  // Process scanned devices - can be offloaded to compute if needed
  void _processScannedDevice(
      DiscoveredDevice device,
      Function(String id, String name, Uint8List data) onDeviceDiscovered) {
    final manufacturerData = device.manufacturerData;
    if (manufacturerData.isEmpty) return;
    
    // Check if device advertises our service UUID
    if (!device.serviceUuids.contains(Uuid.parse(serviceUuid))) return;
    
    try {
      String deviceName = device.name;
      if (deviceName.isEmpty) {
        deviceName = 'Unknown Device';
      }
      
      // Use compute for heavy data processing if needed
      onDeviceDiscovered(device.id, deviceName, manufacturerData);
    } catch (e) {
      debugPrint('[Seller] Error processing device: $e');
    }
  }

  void stopScanning() {
    if (!_isScanning) {
      debugPrint('[Seller] Not currently scanning');
      return;
    }

    _scanSubscription?.cancel();
    _scanSubscription = null;
    
    _isScanning = false;
    debugPrint('[Seller] Scan stopped.');
  }

  Map<String, String>? decodeManufacturerData(Uint8List data) {
    try {
      final decoded = utf8.decode(data.sublist(2)); // Skip first 2 bytes (manufacturer ID)
      final parts = decoded.split('|');
      if (parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
        return {'postId': parts[0], 'userId': parts[1]};
      }
    } catch (e) {
      debugPrint('[Seller] Error decoding manufacturer data: $e');
    }
    return null;
  }
  
  // Cleanup method to dispose of all resources
  Future<void> dispose() async {
    await stopAdvertising(null);
    stopScanning();
    _dataProcessingReceivePort?.close();
    _dataProcessingIsolate?.kill(priority: Isolate.immediate);
    debugPrint('[BleService] Disposed all resources');
  }
}
