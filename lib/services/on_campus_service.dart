import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';


/// Campus center coordinates (Bogotá)
const kCampusLatitude = 4.601795;
const kCampusLongitude = -74.066150;


/// Default radius in meters for "On Campus"
const kCampusRadiusMeters = 400.0;

/// Enum representing the status of location permission and services.
enum LocationPermissionStatus {
  /// Permission granted and location services enabled.
  granted,

  /// Permission denied.
  denied,

  /// Permission denied forever (user selected "Don't ask again").
  deniedForever,

  /// Location services are disabled.
  serviceDisabled,
}

/// Exception thrown for unexpected errors in OnCampusService.
class OnCampusException implements Exception {
  final String message;
  final Object? cause;

  OnCampusException(this.message, [this.cause]);

  @override
  String toString() => 'OnCampusException: $message${cause != null ? ' (cause: $cause)' : ''}';
}


class OnCampusService {
  final double campusLat;
  final double campusLng;
  final double radiusMeters;
  final bool enableLogging;

  /// Cache for the last position and timestamp.
  Position? _cachedPosition;
  DateTime? _cacheTimestamp;
  static const Duration _cacheTtl = Duration(seconds: 180);

  /// Stream controller for watchOnCampus.
  StreamController<bool>? _onCampusController;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _timer;
  bool? _lastOnCampusState;
  bool? _lastEmittedState;

  OnCampusService({
    this.campusLat = kCampusLatitude,
    this.campusLng = kCampusLongitude,
    this.radiusMeters = kCampusRadiusMeters,
    this.enableLogging = false,
  });

  void _log(String message) {
    if (enableLogging) {
      debugPrint('[OnCampusService] $message');
    }
  }

  /// Ensures location permissions and services are enabled.
  /// Returns the status without throwing for normal denials.
  Future<LocationPermissionStatus> ensurePermission() async {
    try {
      _log('Checking location services...');
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _log('Location services disabled');
        return LocationPermissionStatus.serviceDisabled;
      }

      _log('Checking permissions...');
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _log('Permission denied, requesting...');
        permission = await Geolocator.requestPermission();
      }

      switch (permission) {
        case LocationPermission.denied:
          _log('Permission denied');
          return LocationPermissionStatus.denied;
        case LocationPermission.deniedForever:
          _log('Permission denied forever');
          return LocationPermissionStatus.deniedForever;
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          _log('Permission granted');
          return LocationPermissionStatus.granted;
        default:
          _log('Unknown permission status');
          return LocationPermissionStatus.denied;
      }
    } catch (e) {
      throw OnCampusException('Failed to ensure permissions', e);
    }
  }

  /// Gets the current position, using cache if fresh and forceFresh is false.
  Future<Position> _getCurrentPosition({bool forceFresh = false}) async {
    final now = DateTime.now();
    if (!forceFresh &&
        _cachedPosition != null &&
        _cacheTimestamp != null &&
        now.difference(_cacheTimestamp!) < _cacheTtl) {
      _log('Using cached position');
      return _cachedPosition!;
    }

    _log('Fetching fresh position');
    // Determine accuracy: use best if close to boundary (300-500m)
    LocationAccuracy accuracy = LocationAccuracy.medium;
    if (_cachedPosition != null) {
      final cachedDistance = Geolocator.distanceBetween(
        _cachedPosition!.latitude,
        _cachedPosition!.longitude,
        campusLat,
        campusLng,
      );
      if (cachedDistance >= 300 && cachedDistance <= 500) {
        accuracy = LocationAccuracy.best;
      }
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: const Duration(seconds: 30),
        ),
      );
      _cachedPosition = position;
      _cacheTimestamp = now;
      return position;
    } catch (e) {
      throw OnCampusException('Failed to get current position', e);
    }
  }

  /// Returns true if the user is within the campus radius.
  Future<bool> isOnCampus({bool forceFresh = false}) async {
    try {
      final position = await _getCurrentPosition(forceFresh: forceFresh);
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        campusLat,
        campusLng,
      );
      final onCampus = distance <= radiusMeters;
      _log('Distance: ${distance.toStringAsFixed(2)}m, On campus: $onCampus');
      return onCampus;
    } catch (e) {
      throw OnCampusException('Failed to check if on campus', e);
    }
  }

  /// Returns the straight-line distance in meters from the device to campus center.
  Future<double> distanceFromCampusMeters({bool forceFresh = false}) async {
    try {
      final position = await _getCurrentPosition(forceFresh: forceFresh);
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        campusLat,
        campusLng,
      );
      _log('Distance from campus: ${distance.toStringAsFixed(2)}m');
      return distance;
    } catch (e) {
      throw OnCampusException('Failed to get distance from campus', e);
    }
  }

  /// Emits true/false whenever the user crosses the boundary or at least once per interval.
  Stream<bool> watchOnCampus({Duration interval = const Duration(seconds: 10)}) {
    _onCampusController?.close();
    _positionSubscription?.cancel();
    _timer?.cancel();

    _onCampusController = StreamController<bool>.broadcast();
    _lastOnCampusState = null;
    _lastEmittedState = null;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 10,
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (position) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          campusLat,
          campusLng,
        );
        final onCampus = distance <= radiusMeters;
        _lastOnCampusState = onCampus;
        _log('Distance: ${distance.toStringAsFixed(2)}m, On campus: $onCampus');
        if (_lastOnCampusState != _lastEmittedState) {
          _lastEmittedState = _lastOnCampusState;
          _onCampusController!.add(onCampus);
          _log('On campus state changed to: $onCampus');
        }
      },
      onError: (error) {
        _onCampusController!.addError(
          OnCampusException('Error in position stream', error),
        );
      },
    );

    // Timer to emit at least once per interval
    _timer = Timer.periodic(interval, (_) {
      if (_lastOnCampusState != null && _lastOnCampusState != _lastEmittedState) {
        _lastEmittedState = _lastOnCampusState;
        _onCampusController!.add(_lastOnCampusState!);
        _log('Periodic emit: $_lastOnCampusState');
      }
    });

    // Emit initial state
    isOnCampus().then((initial) {
      _lastOnCampusState = initial;
      if (_lastOnCampusState != _lastEmittedState) {
        _lastEmittedState = _lastOnCampusState;
        _onCampusController!.add(initial);
        _log('Initial on campus state: $initial');
      }
    }).catchError((error) {
      _onCampusController!.addError(error);
    });

    return _onCampusController!.stream;
  }

  /// Cancels any internal stream subscriptions/timers.
  void dispose() {
    _log('Disposing service');
    _positionSubscription?.cancel();
    _timer?.cancel();
    _onCampusController?.close();
    _cachedPosition = null;
    _cacheTimestamp = null;
    _lastOnCampusState = null;
    _lastEmittedState = null;
  }
}

/// Example usage (comment in service file)
/// ```dart
/// final service = OnCampusService();
///
/// Future<void> example() async {
///   final status = await service.ensurePermission();
///   if (status != LocationPermissionStatus.granted) {
///     // Show a UI hint to enable permission or services
///     return;
///   }
///
///   final onCampus = await service.isOnCampus();
///   debugPrint('On campus? $onCampus');
///
///   final sub = service.watchOnCampus().listen((v) {
///     debugPrint('On campus changed → $v');
///   });
///
///   // Later
///   await Future<void>.delayed(const Duration(minutes: 5));
///   await sub.cancel();
///   service.dispose();
/// }
/// ```