import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/connectivity_service.dart';
import '../theme/app_colors.dart';

/// Banner widget that appears when device is offline
/// Shows cache age and connectivity status
class OfflineBanner extends StatefulWidget {
  final String? cacheAge;
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key,
    this.cacheAge,
    this.onRetry,
  });

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  final ConnectivityService _connectivity = ConnectivityService();
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _checkConnectivity() {
    setState(() {
      _isVisible = !_connectivity.isConnected;
    });
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    final wasVisible = _isVisible;
    final shouldBeVisible = result == ConnectivityResult.none;

    if (wasVisible != shouldBeVisible) {
      setState(() {
        _isVisible = shouldBeVisible;
      });

      // Auto-retry when connection restored
      if (!shouldBeVisible && widget.onRetry != null) {
        Future.delayed(const Duration(milliseconds: 500), widget.onRetry);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.orange.shade700,
      child: Row(
        children: [
          const Icon(
            Icons.cloud_off,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.cacheAge != null
                  ? 'Offline - Showing cached data (${widget.cacheAge})'
                  : 'Offline - Some features limited',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (widget.onRetry != null)
            TextButton(
              onPressed: widget.onRetry,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }
}

/// Simplified offline indicator for app bar
class OfflineIndicator extends StatefulWidget {
  const OfflineIndicator({super.key});

  @override
  State<OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<OfflineIndicator> {
  final ConnectivityService _connectivity = ConnectivityService();
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _connectivity.onConnectivityChanged.listen((result) {
      setState(() {
        _isOffline = result == ConnectivityResult.none;
      });
    });
  }

  void _checkConnectivity() {
    setState(() {
      _isOffline = !_connectivity.isConnected;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.cloud_off, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Offline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
