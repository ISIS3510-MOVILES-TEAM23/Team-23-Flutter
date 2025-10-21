import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/models.dart';

/// Service que maneja la lógica de negocio para productos cercanos
class NearbyProductsService {
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
