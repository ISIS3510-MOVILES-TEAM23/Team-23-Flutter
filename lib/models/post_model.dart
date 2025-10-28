import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id; // maps from _id
  final String title;
  final String description;
  final int price; // stored as integer (e.g., cents or local currency units)
  final String status; // 'active' | 'sold' | 'archived'
  final String userId; // reference to user
  final String categoryId; // reference path: categories/<id>
  final List<String> images;
  final DateTime createdAt;
  
  // Optional location fields for nearby products feature
  final double? latitude;
  final double? longitude;

  const Post({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.status,
    required this.userId,
    required this.categoryId,
    required this.images,
    required this.createdAt,
    this.latitude,
    this.longitude,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    final dynamic createdAtRaw = json['created_at'];
    DateTime createdAt;
    if (createdAtRaw is Timestamp) {
      createdAt = createdAtRaw.toDate();
    } else if (createdAtRaw is DateTime) {
      createdAt = createdAtRaw;
    } else if (createdAtRaw is String) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      createdAt = DateTime.now();
    }

    final dynamic userIdRaw = json['user_id'] ?? json['user'];
    final String resolvedUserId;
    if (userIdRaw is DocumentReference) {
      resolvedUserId = userIdRaw.path;
    } else if (userIdRaw is String) {
      resolvedUserId = userIdRaw;
    } else {
      resolvedUserId = userIdRaw?.toString() ?? '';
    }

    final dynamic categorySource =
        json['category_id'] ?? json['category'] ?? json['category_ref'];
    final String resolvedCategoryId;
    if (categorySource is DocumentReference) {
      resolvedCategoryId = categorySource.path;
    } else if (categorySource is String) {
      resolvedCategoryId = categorySource;
    } else {
      resolvedCategoryId = categorySource?.toString() ?? '';
    }

    final imagesRaw = json['images'];
    final images = imagesRaw is List
        ? imagesRaw.map((e) => e.toString()).toList()
        : <String>[];

    final priceRaw = json['price'];
    final int price;
    if (priceRaw is int) {
      price = priceRaw;
    } else if (priceRaw is num) {
      price = priceRaw.toInt();
    } else if (priceRaw is String) {
      price = int.tryParse(priceRaw) ?? 0;
    } else {
      price = 0;
    }

    return Post(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      price: price,
      status: json['status'] ?? 'active',
      userId: resolvedUserId,
      categoryId: resolvedCategoryId,
      images: images,
      createdAt: createdAt,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'price': price,
      'status': status,
      'user_id': userId,
      'category_id': categoryId,
      'images': images,
      'created_at': createdAt.toIso8601String(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    };
  }

  /// Calcula la distancia en metros desde este post hasta una ubicación dada
  /// Usa la fórmula de Haversine para calcular distancia entre dos puntos en la Tierra
  double? distanceFromMeters(double userLat, double userLng) {
    if (latitude == null || longitude == null) return null;
    
    const earthRadiusKm = 6371.0;
    
    final dLat = _degreesToRadians(userLat - latitude!);
    final dLng = _degreesToRadians(userLng - longitude!);
    
    final lat1Rad = _degreesToRadians(latitude!);
    final lat2Rad = _degreesToRadians(userLat);
    
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1Rad) * cos(lat2Rad) *
        sin(dLng / 2) * sin(dLng / 2);
    
    final c = 2 * asin(sqrt(a));
    
    return earthRadiusKm * c * 1000; // Convertir a metros
  }
  
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180.0;
  }
}

