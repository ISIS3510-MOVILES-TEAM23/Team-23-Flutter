import 'user_model.dart';
import 'post_model.dart';

class Sale {
  final String id; // maps from _id
  final String postId; // 'post/<id>'
  final String buyerId; // 'user/<id>'
  final String sellerId; // 'user/<id>'
  final int price;
  final String status; // pending | completed | canceled | acknowledged
  final DateTime createdAt;

  const Sale({
    required this.id,
    required this.postId,
    required this.buyerId,
    required this.sellerId,
    required this.price,
    required this.status,
    required this.createdAt,
  });

  factory Sale.fromJson(Map<String, dynamic> json) {
    // Helper to extract ID from DocumentReference or String
    String extractId(dynamic ref) {
      if (ref == null) return '';
      if (ref is String) return ref; // Already a string (from cache)
      return ref.id; // DocumentReference (from Firestore)
    }
    
    // Handle created_at from Timestamp (Firestore) or String (cache)
    DateTime parseCreatedAt(dynamic createdAt) {
      if (createdAt == null) return DateTime.now();
      if (createdAt is DateTime) return createdAt;
      if (createdAt is String) return DateTime.tryParse(createdAt) ?? DateTime.now();
      return createdAt.toDate(); // Timestamp (Firestore)
    }
    
    return Sale(
      id: json['_id'] ?? json['id'],
      postId: extractId(json['post_ref']),
      buyerId: extractId(json['buyer_ref']),
      sellerId: extractId(json['seller_ref']),
      price: json['price'] is int ? json['price'] : (json['price'] as num).toInt(),
      status: json['status'],
      createdAt: parseCreatedAt(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'post_ref': postId,
      'buyer_ref': buyerId,
      'seller_ref': sellerId,
      'price': price,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class TransactionAck {
  final String transactionId;
  final String buyerId; // 'user/<id>'
  final String sellerId; // 'user/<id>'
  final String saleId; // 'sale/<id>'

  const TransactionAck({
    required this.transactionId,
    required this.buyerId,
    required this.sellerId,
    required this.saleId,
  });

  factory TransactionAck.fromJson(Map<String, dynamic> json) {
    return TransactionAck(
      transactionId: json['transaction_id'],
      buyerId: json['buyer_id'],
      sellerId: json['seller_id'],
      saleId: json['sale_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'sale_id': saleId,
    };
  }
}

class PostWithChat {
  final Post post;
  final String? chatId;
  final User? buyer;
  final Sale? sale;

  PostWithChat({
    required this.post,
    this.chatId,
    this.buyer,
    this.sale,
  });
}

