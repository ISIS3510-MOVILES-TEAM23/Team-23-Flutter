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
    return User(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      contactPreferences: json['contact_preferences'],
      email: json['email'],
      role: json['role'],
      major: json['major'],
      createdAt: DateTime.parse(json['created_at']),
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

