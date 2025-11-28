import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String productId;
  final String userId;
  final String userName;
  final String content;
  final DateTime createdAt;
  final bool isSynced; // true for synced comments, false for pending offline comments
  final String? localId; // Local ID for pending comments before Firestore ID assignment

  Comment({
    required this.id,
    required this.productId,
    required this.userId,
    required this.userName,
    required this.content,
    required this.createdAt,
    this.isSynced = true, // Default to true for fetched comments
    this.localId,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
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

    return Comment(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name']?.toString() ?? 'Anonymous',
      content: json['content']?.toString() ?? '',
      createdAt: createdAt,
      isSynced: json['is_synced'] as bool? ?? true,
      localId: json['local_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'user_id': userId,
      'user_name': userName,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'is_synced': isSynced,
      if (localId != null) 'local_id': localId,
    };
  }

  /// Create a copy of this comment with updated fields
  Comment copyWith({
    String? id,
    String? productId,
    String? userId,
    String? userName,
    String? content,
    DateTime? createdAt,
    bool? isSynced,
    String? localId,
  }) {
    return Comment(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      localId: localId ?? this.localId,
    );
  }
}
