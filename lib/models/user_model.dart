class User {
  final String id; // maps from _id
  final String name;
  final String contactPreferences; // 'push' | 'email'
  final String email;
  final String role; // 'student' | 'professor' | 'staff'
  final String? major; // carrera del usuario
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.contactPreferences,
    required this.email,
    required this.role,
    this.major,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      contactPreferences: json['contact_preferences'],
      email: json['email'],
      role: json['role'],
      major: json['major'],
      createdAt: DateTime.parse(json['created_at'])
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
    };
  }
}

