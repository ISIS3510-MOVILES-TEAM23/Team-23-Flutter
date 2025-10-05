import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';
import 'post_model.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String? content;
  final String? image;
  final DateTime sentAt;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.senderId,
    this.content,
    this.image,
    required this.sentAt,
    this.read = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final dynamic sentAtRaw = json['sent_at'];
    DateTime sentAt;
    if (sentAtRaw is Timestamp) {
      sentAt = sentAtRaw.toDate();
    } else if (sentAtRaw is DateTime) {
      sentAt = sentAtRaw;
    } else if (sentAtRaw is String) {
      sentAt = DateTime.tryParse(sentAtRaw) ?? DateTime.now();
    } else {
      sentAt = DateTime.now();
    }

    return ChatMessage(
      id: json['_id'] ?? json['id'] ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      content: json['content']?.toString(),
      image: json['image']?.toString(),
      sentAt: sentAt,
      read: json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'content': content,
      'sender_id': senderId,
      'sent_at': FieldValue.serverTimestamp(),
      'read': read,
      'image': image,
    };
  }
}

class Chat {
  final String id;
  final String buyerId;
  final String sellerId;
  final String productId;
  final List<String> participantIds;
  final String? lastMessage;
  final DateTime? updatedAt;
  final DateTime? createdAt;
  final int unreadCountBuyer;
  final int unreadCountSeller;

  const Chat({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.productId,
    this.participantIds = const [],
    this.lastMessage,
    this.updatedAt,
    this.createdAt,
    this.unreadCountBuyer = 0,
    this.unreadCountSeller = 0,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    DateTime? parseTimestamp(dynamic raw) {
      if (raw is Timestamp) return raw.toDate();
      if (raw is DateTime) return raw;
      if (raw is String) return DateTime.tryParse(raw);
      return null;
    }

    return Chat(
      id: json['_id'] ?? json['id'] ?? '',
      buyerId: json['buyer_id']?.toString() ?? '',
      sellerId: json['seller_id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      participantIds: (json['participant_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      lastMessage: json['last_message']?.toString(),
      updatedAt: parseTimestamp(json['updated_at']),
      createdAt: parseTimestamp(json['created_at']),
      unreadCountBuyer: json['unread_count_buyer'] ?? 0,
      unreadCountSeller: json['unread_count_seller'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'product_id': productId,
      'participant_ids': participantIds,
      'last_message': lastMessage,
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': createdAt ?? FieldValue.serverTimestamp(),
      'unread_count_buyer': unreadCountBuyer,
      'unread_count_seller': unreadCountSeller,
    };
  }
}

class ProductChat {
  final String chatId;
  final User otherUser;
  final Post product;
  final String? lastMessage;
  final DateTime? updatedAt;
  final int unreadCount;
  final bool isBuyer;

  ProductChat({
    required this.chatId,
    required this.otherUser,
    required this.product,
    this.lastMessage,
    this.updatedAt,
    this.unreadCount = 0,
    required this.isBuyer,
  });
}

