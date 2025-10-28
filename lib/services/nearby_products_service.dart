import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';

/// Service que maneja la lógica de negocio para productos cercanos
/// y la obtención de ubicación del dispositivo
class NearbyProductsService {
  /// Obtiene la ubicación actual del dispositivo, solicitando permisos si es necesario
  /// Retorna Position si se obtuvo exitosamente, null en caso contrario
  Future<Position?> getCurrentLocationWithPermissions() async {
    try {
      // Verificar permisos actuales
      LocationPermission permission = await Geolocator.checkPermission();
      
      // Si fue denegado, solicitar permiso
      if (permission == LocationPermission.denied) {
        debugPrint('📍 [NearbyProductsService] Requesting location permission...');
        permission = await Geolocator.requestPermission();
      }
      
      // Si fue denegado permanentemente, no podemos hacer nada
      if (permission == LocationPermission.deniedForever) {
        debugPrint('⚠️ [NearbyProductsService] Location permission denied forever');
        return null;
      }
      
      // Si tenemos permisos, obtener ubicación
      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        debugPrint('✅ [NearbyProductsService] Location permission granted');
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );
        debugPrint('📍 [NearbyProductsService] Location obtained: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}');
        return position;
      }
      
      debugPrint('⚠️ [NearbyProductsService] Location permission not granted');
      return null;
    } catch (e) {
      debugPrint('❌ [NearbyProductsService] Error getting location: $e');
      return null;
    }
  }
  /// Filtra y ordena productos por distancia desde una ubicación dada
  Future<List<Post>> filterNearbyProducts({
    required List<Post> allPosts,
    required double userLatitude,
    required double userLongitude,
    required String currentUserId,
    double maxDistanceMeters = 5000.0,
    int limit = 10,
  }) async {
    try {
      final List<_PostWithDistance> postsWithDistance = [];

      for (final post in allPosts) {
        // Saltar posts propios
        final postUserId = _extractUid(post.userId);
        if (postUserId == currentUserId) continue;

        // Saltar posts sin ubicación
        if (post.latitude == null || post.longitude == null) continue;

        // Calcular distancia
        final distance = post.distanceFromMeters(userLatitude, userLongitude);
        if (distance == null) continue;

        // Solo incluir si está dentro del radio máximo
        if (distance <= maxDistanceMeters) {
          postsWithDistance.add(_PostWithDistance(post, distance));
        }
      }

      // Ordenar por distancia (más cercanos primero)
      postsWithDistance.sort((a, b) => a.distance.compareTo(b.distance));

      // Retornar top N
      return postsWithDistance
          .take(limit)
          .map((pwd) => pwd.post)
          .toList();
    } catch (e) {
      debugPrint('[NearbyProductsService] Error filtering: $e');
      return [];
    }
  }

  /// Obtiene la ubicación actual del usuario
  Future<Position?> getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always && 
          permission != LocationPermission.whileInUse) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('[NearbyProductsService] Error getting location: $e');
      return null;
    }
  }

  /// Extrae el UID del userId (maneja formatos con "/" o sin él)
  String _extractUid(String userId) {
    if (userId.contains('/')) {
      return userId.split('/').last;
    }
    return userId;
  }
}

/// Clase helper privada para almacenar post con distancia
class _PostWithDistance {
  final Post post;
  final double distance;
  _PostWithDistance(this.post, this.distance);
}
