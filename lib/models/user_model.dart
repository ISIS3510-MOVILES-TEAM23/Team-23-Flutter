import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id; // maps from _id
  final String name;
  final String contactPreferences; // 'push' | 'email'
  final String email;
  final String role; // 'student' | 'professor' | 'staff'
  final String? major; // carrera del usuario
  final DateTime createdAt;
  final int? numberOfReviews; // number of reviews received
  final double? score; // average rating score

  const User({
    required this.id,
    required this.name,
    required this.contactPreferences,
    required this.email,
    required this.role,
    this.major,
    required this.createdAt,
    this.numberOfReviews,
    this.score,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    // Handle contactPreferences which can be either String or List
    final dynamic contactPrefRaw = json['contact_preferences'];
    final String contactPreferences;
    if (contactPrefRaw is List) {
      // If it's a list, join elements with comma or take first element
      contactPreferences = contactPrefRaw.isNotEmpty 
          ? contactPrefRaw.map((e) => e.toString()).join(', ')
          : '';
    } else if (contactPrefRaw is String) {
      contactPreferences = contactPrefRaw;
    } else {
      contactPreferences = contactPrefRaw?.toString() ?? '';
    }

    // Handle createdAt which can be Timestamp, DateTime, or String
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

    return User(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      contactPreferences: contactPreferences,
      email: json['email'],
      role: json['role'],
      major: json['major'],
      createdAt: createdAt,
      numberOfReviews: json['number_of_reviews'] as int?,
      score: (json['score'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'contact_preferences': contactPreferences,
      'email': email,
      'role': role,
      'major': major,
      'created_at': createdAt.toIso8601String(),
      'number_of_reviews': numberOfReviews,
      'score': score,
    };
  }

  // Helper method to check if user has rating data
  bool get hasRating => numberOfReviews != null && score != null && numberOfReviews! > 0;
}

