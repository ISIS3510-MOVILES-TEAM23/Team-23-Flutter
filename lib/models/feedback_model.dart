import 'package:cloud_firestore/cloud_firestore.dart';

/// Feedback model for product reviews
/// 
/// Firestore schema:
/// - buyerId (string): ID of the user who bought the product
/// - sellerId (string): ID of the seller
/// - purchaseId (string): ID of the purchase/sale transaction
/// - comment (string): User's feedback comment
/// - rating (number): Rating from 1-5
/// - images (array): URLs of feedback images
/// - createdAt (timestamp): When the feedback was created
class Feedback {
  final String id;
  final String buyerId;
  final String sellerId;
  final String purchaseId;
  final String comment;
  final int rating; // 1-5 stars
  final List<String> images; // Firebase Storage URLs
  final DateTime createdAt;

  const Feedback({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.purchaseId,
    required this.comment,
    required this.rating,
    required this.images,
    required this.createdAt,
  });

  /// Create from Firestore document
  factory Feedback.fromJson(Map<String, dynamic> json) {
    final dynamic createdAtRaw = json['createdAt'];
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

    final imagesRaw = json['images'];
    final images = imagesRaw is List
        ? imagesRaw.map((e) => e.toString()).toList()
        : <String>[];

    final ratingRaw = json['rating'];
    final int rating;
    if (ratingRaw is int) {
      rating = ratingRaw;
    } else if (ratingRaw is num) {
      rating = ratingRaw.toInt();
    } else if (ratingRaw is String) {
      rating = int.tryParse(ratingRaw) ?? 0;
    } else {
      rating = 0;
    }

    return Feedback(
      id: json['id'] ?? json['_id'] ?? '',
      buyerId: json['buyerId'] ?? '',
      sellerId: json['sellerId'] ?? '',
      purchaseId: json['purchaseId'] ?? '',
      comment: json['comment'] ?? '',
      rating: rating,
      images: images,
      createdAt: createdAt,
    );
  }

  /// Convert to JSON for Firestore
  Map<String, dynamic> toJson() {
    return {
      'buyerId': buyerId,
      'sellerId': sellerId,
      'purchaseId': purchaseId,
      'comment': comment,
      'rating': rating,
      'images': images,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Convert to JSON string format
  Map<String, dynamic> toJsonString() {
    return {
      'id': id,
      'buyerId': buyerId,
      'sellerId': sellerId,
      'purchaseId': purchaseId,
      'comment': comment,
      'rating': rating,
      'images': images,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Check if feedback is valid
  bool get isValid {
    return buyerId.isNotEmpty &&
        sellerId.isNotEmpty &&
        purchaseId.isNotEmpty &&
        comment.trim().isNotEmpty &&
        rating > 0 &&
        rating <= 5;
  }
}

