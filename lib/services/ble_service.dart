import 'dart:async';
import 'dart:convert';

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

  // Buyer (Advertising)
  Future<void> startAdvertising(
      String postId, String userId, VoidCallback onStop) async {
    final payload = 'test|test';
    final data = utf8.encode(payload);

    debugPrint(
        '[Buyer] Starting advertising payload: $payload (bytes: ${data.length})');

    await _peripheral.start(
      advertiseData: AdvertiseData(
        serviceUuid: serviceUuid,
        manufacturerId: manufacturerId,
        manufacturerData: data,
        includeDeviceName: true,
      ),
    );

    _advertisingTimer = Timer(const Duration(seconds: 60), () {
      debugPrint('[Buyer] Auto-stopping advertising after 60s.');
      stopAdvertising(onStop);
    });
  }

  Future<void> stopAdvertising(VoidCallback? onStop) async {
    try {
      await _peripheral.stop();
      debugPrint('[Buyer] Advertising stopped.');
    } catch (e) {
      debugPrint('[Buyer] Error stopping advertising: $e');
    }
    _advertisingTimer?.cancel();
    _advertisingTimer = null;
    onStop?.call();
  }

  // Seller (Scanning)
  void startScanning(
      Function(String id, String name, Uint8List data) onDeviceDiscovered) {
    debugPrint('[Seller] Starting scan.');

    _scanSubscription = _reactiveBle.scanForDevices(
      withServices: [],
      scanMode: ScanMode.lowLatency,
    ).listen((device) {
      final manufacturerData = device.manufacturerData;
      if (manufacturerData.isEmpty) return;
      if (!device.serviceUuids.contains(Uuid.parse(serviceUuid))) return;
      try {
        String device_name = device.name;
        if (device_name.isEmpty) {
          device_name = 'Unknown Device';
        }
        onDeviceDiscovered(
            device.id, device_name, manufacturerData);
      } catch (e) {
        debugPrint('[Seller] Error: $e');
      }
    }, onError: (error) {
      debugPrint('[Seller] Scan error: $error');
      stopScanning();
    });
  }

  void stopScanning() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
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
}
