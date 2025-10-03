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
  final TextEditingController _postIdController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();
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

  void _toggleRole(String role) {
    setState(() {
      _role = role;
      _statusText = 'Not started';
      _isAdvertising = false;
      _isScanning = false;
      _discoveredDevices.clear();
      _selectedDevice = null;
    });
  }

  void _startAdvertising() async {
    final postId = _postIdController.text.trim();
    final userId = _userIdController.text.trim();
    if (postId.isEmpty || userId.isEmpty) {
      setState(() {
        _statusText = 'Enter postId and userId';
      });
      return;
    }
    await _bleService.startAdvertising(postId, userId, () {
      setState(() {
        _isAdvertising = false;
        _statusText = 'Not advertising';
      });
    });
    setState(() {
      _isAdvertising = true;
      _statusText = 'Advertising (auto-stops in 60s)…';
    });
  }

  void _stopAdvertising() async {
    await _bleService.stopAdvertising(() {
      setState(() {
        _isAdvertising = false;
        _statusText = 'Not advertising';
      });
    });
  }

  void _startScanning() {
    _bleService.startScanning(
      (id, name, data) {
        setState(() {
          _discoveredDevices[id] = {'name': name, 'data': data};
        });
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
              if (_selectedDevice != null) ...[
                Builder(
                  builder: (context) {
                    final data = _discoveredDevices[_selectedDevice!]!['data'] as Uint8List;
                    final decoded = _bleService.decodeManufacturerData(data);
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.secondaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        decoded != null
                            ? 'Selected Device: Post ID: ${decoded['postId']}, User ID: ${decoded['userId']}'
                            : 'Selected Device: Unable to decode data',
                        style: textTheme.bodyMedium?.copyWith(
                          color: AppColors.secondaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'Buyer', label: Text('Buyer')),
                  ButtonSegment(value: 'Seller', label: Text('Seller')),
                ],
                selected: {_role},
                onSelectionChanged: (Set<String> selected) {
                  _toggleRole(selected.first);
                },
              ),
              const SizedBox(height: 24),
              if (_role == 'Buyer') ...[
                TextField(
                  controller: _postIdController,
                  decoration: const InputDecoration(labelText: 'Post ID'),
                ),
                TextField(
                  controller: _userIdController,
                  decoration: const InputDecoration(labelText: 'User ID'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _isAdvertising ? null : _startAdvertising,
                      child: const Text('Start Advertising'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isAdvertising ? _stopAdvertising : null,
                      child: const Text('Stop Advertising'),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _isScanning ? null : _startScanning,
                      child: const Text('Start Scan'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isScanning ? _stopScanning : null,
                      child: const Text('Stop Scan'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Results are printed to console.',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
                                    }
                                  }
                                });
                              },
                            );
                          },
                        ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                _statusText,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.primaryColor),
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
