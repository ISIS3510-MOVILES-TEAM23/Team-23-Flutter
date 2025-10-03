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
    return Sale(
      id: json['_id'] ?? json['id'],
      postId: json['post_ref'].id,
      buyerId: json['buyer_ref'].id,
      sellerId: json['seller_ref'].id,
      price: json['price'] is int ? json['price'] : (json['price'] as num).toInt(),
      status: json['status'],
      createdAt: json['created_at'].toDate(),
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

