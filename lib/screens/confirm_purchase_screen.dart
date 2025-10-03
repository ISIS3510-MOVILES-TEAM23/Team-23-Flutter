import 'dart:async';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/ble_service.dart';
import '../theme/app_colors.dart';

class ConfirmPurchaseScreen extends StatefulWidget {
  const ConfirmPurchaseScreen({super.key});

  @override
  State<ConfirmPurchaseScreen> createState() => _ConfirmPurchaseScreenState();
}

class _ConfirmPurchaseScreenState extends State<ConfirmPurchaseScreen> {
  final BleService _bleService = BleService();
  String _role = 'Buyer'; // 'Buyer' or 'Seller'
  String? _postId;
  String? _buyerId;
  bool _isAdvertising = false;
  bool _isScanning = false;
  String _statusText = 'Not started';
  Map<String, Map<String, dynamic>> _discoveredDevices = {};
  String? _selectedDevice;
  String? _deviceName;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _getDeviceName();
    _setInitialRole();
  }

  void _setInitialRole() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = GoRouterState.of(context);
      final extra = state.extra as Map<String, dynamic>?;
      if (extra != null) {
        setState(() {
          _role = extra['role'] == 'seller' ? 'Seller' : 'Buyer';
          _postId = extra['postId'];
          _buyerId = extra['buyerId'];
        });
      } else {
        setState(() {
          _role = 'Buyer';
        });
      }
    });
  }

  Future<void> _getDeviceName() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      final androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _deviceName = '${androidInfo.brand} ${androidInfo.model}';
      });
    } catch (e) {
      setState(() {
        _deviceName = 'Device Info Unavailable';
      });
    }
  }

  Future<void> _requestPermissions() async {
    final granted = await _bleService.requestBlePermissions();
    if (!granted) {
      setState(() {
        _statusText = 'Permissions not granted';
      });
    }
  }

  void _startAdvertising() async {
    final postId = _postId;
    final userId = _buyerId;
    if (postId == null || postId.isEmpty || userId == null || userId.isEmpty) {
      setState(() {
        _statusText = 'Missing postId or buyerId from navigation';
      });
      return;
    }
    await _bleService.startAdvertising(postId, userId, () {
      if (mounted) {
        setState(() {
          _isAdvertising = false;
          _statusText = 'Not advertising';
        });
      }
    });
    setState(() {
      _isAdvertising = true;
      _statusText = 'Advertising (auto-stops in 60s)…';
    });
  }

  void _stopAdvertising() async {
    await _bleService.stopAdvertising(() {
      if (mounted) {
        setState(() {
          _isAdvertising = false;
          _statusText = 'Not advertising';
        });
      }
    });
  }

  void _startScanning() {
    _bleService.startScanning(
      (id, name, data) {
        if (mounted) {
          setState(() {
            _discoveredDevices[id] = {'name': name, 'data': data};
          });
        }
        debugPrint('Discovered Device: $name ($id)');
      },
    );
    setState(() {
      _isScanning = true;
      _statusText = 'Scanning…';
      _discoveredDevices.clear();
      _selectedDevice = null;
    }); 
  }

  void _stopScanning() {
    _bleService.stopScanning();
    setState(() {
      _isScanning = false;
      _statusText = 'Not scanning';
    });
  }

  void _handleBack(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/profile');
    }
  }

  @override
  void dispose() {
    _bleService.stopScanning();
    _bleService.stopAdvertising(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          color: AppColors.textPrimary,
          onPressed: () => _handleBack(context),
        ),
        title: const Text(
          'Confirm Purchase',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              if (_deviceName != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Your Device: $_deviceName',
                    style: textTheme.bodyLarge?.copyWith(
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 24),
              if (_role == 'Seller') ...[
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isAdvertising ? null : _startAdvertising,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Start Advertising'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isAdvertising ? _stopAdvertising : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Stop Advertising'),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isScanning ? null : _startScanning,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Start Scan'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isScanning ? _stopScanning : null,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Stop Scan'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Nearby Devices',
                  style: textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _discoveredDevices.isEmpty
                      ? Center(
                          child: Text(
                            'No devices found. Start scanning to discover devices.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _discoveredDevices.length,
                          itemBuilder: (context, index) {
                            final entry = _discoveredDevices.entries.elementAt(index);
                            final deviceName = entry.value['name'] as String;
                            final isSelected = _selectedDevice == entry.key;
                            return ListTile(
                              title: Text(deviceName),
                              selected: isSelected,
                              selectedTileColor: AppColors.primaryColor.withValues(alpha: 0.1),
                              onTap: () {
                                setState(() {
                                  _selectedDevice = isSelected ? null : entry.key;
                                  if (_selectedDevice != null) {
                                    final data = entry.value['data'] as Uint8List;
                                    final decoded = _bleService.decodeManufacturerData(data);
                                    if (decoded != null) {
                                      debugPrint('Decoded: postId=${decoded['postId']}, userId=${decoded['userId']}');
                                      // For seller: check if the decoded data matches expected postId and buyerId
                                      debugPrint('Expected: postId=$_postId, buyerId=$_buyerId');
                                      if (_role == 'Buyer' && _postId != null && _buyerId != null) {
                                        final matches = decoded['postId'] == _postId && decoded['userId'] == _buyerId;
                                        setState(() {
                                          _statusText = matches
                                              ? 'Device matches! Ready to confirm purchase.'
                                              : 'Device does not match the expected buyer.';
                                        });
                                      }
                                    }
                                  } else {
                                    _statusText = 'Not scanning';
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _statusText,
                  style: textTheme.bodyMedium?.copyWith(color: AppColors.primaryColor),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const _ConfirmPurchaseBottomSection(),
    );
  }
}

class _ConfirmPurchaseBottomSection extends StatelessWidget {
  const _ConfirmPurchaseBottomSection();

  int _locationToIndex(String location) {
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/categories')) return 1;
    if (location.startsWith('/post')) return 2;
    if (location.startsWith('/messages')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 4;
  }

  void _handleNavigationTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        context.go('/categories');
        break;
      case 2:
        context.go('/post');
        break;
      case 3:
        context.go('/messages');
        break;
      case 4:
      default:
        context.go('/profile');
    }
  }

  void _handleCancel(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = GoRouterState.of(context);
    final location = state.uri.toString();
    final selectedIndex = _locationToIndex(location);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _handleCancel(context),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.dividerColor),
            BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: (index) => _handleNavigationTap(context, index),
              type: BottomNavigationBarType.fixed,
              selectedItemColor: AppColors.primaryColor,
              unselectedItemColor: AppColors.textSecondary,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              unselectedLabelStyle: const TextStyle(fontSize: 12),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.category_outlined),
                  activeIcon: Icon(Icons.category),
                  label: 'Categories',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.add_circle_outline),
                  activeIcon: Icon(Icons.add_circle),
                  label: 'Post',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.message_outlined),
                  activeIcon: Icon(Icons.message),
                  label: 'Messages',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
