import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo de notificación in-app
class InAppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? postId;
  final DateTime createdAt;
  final bool read;

  const InAppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.postId,
    required this.createdAt,
    required this.read,
  });

  factory InAppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    DateTime createdAt;
    try {
      final createdAtRaw = data['createdAt'];
      if (createdAtRaw is Timestamp) {
        createdAt = createdAtRaw.toDate();
      } else if (createdAtRaw is String) {
        createdAt = DateTime.parse(createdAtRaw);
      } else {
        createdAt = DateTime.now();
      }
    } catch (e) {
      createdAt = DateTime.now();
    }

    return InAppNotification(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? 'new_product',
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      postId: data['postId'] as String?,
      createdAt: createdAt,
      read: data['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      'postId': postId,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': read,
    };
  }
}

