import 'package:cloud_firestore/cloud_firestore.dart';
class User {
  final String id; // maps from _id
  final String name;
  final String contactPreferences; // 'push' | 'email'
  final String email;
  final String role; // 'student' | 'professor' | 'staff'
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.contactPreferences,
    required this.email,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      contactPreferences: json['contact_preferences'],
      email: json['email'],
      role: json['role'],
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
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class SubCategory {
  final String id; // maps from _id
  final String name;
  final String description;

  const SubCategory({
    required this.id,
    required this.name,
    required this.description,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
    };
  }
}

class Category {
  final String id; // maps from _id
  final String name;
  final String description;
  final SubCategory? subcategory;
  final String? icon;

  const Category({
    required this.id,
    required this.name,
    required this.description,
    this.subcategory,
    this.icon,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    final rawName = json['name'] ?? json['title'] ?? json['label'];
    final name = rawName is String ? rawName : rawName?.toString() ?? '';
    final rawDescription = json['description'] ?? json['subtitle'] ?? '';
    final description = rawDescription is String
        ? rawDescription
        : rawDescription?.toString() ?? '';
    final rawIcon = json['icon'] ?? json['icon_url'] ?? json['image'];
    final icon = rawIcon is String ? rawIcon : rawIcon?.toString();

    return Category(
      id: json['_id'] ?? json['id'] ?? '',
      name: name,
      description: description,
      subcategory: json['subcategory'] != null
          ? SubCategory.fromJson(json['subcategory'])
          : null,
      icon: icon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'subcategory': subcategory?.toJson(),
      if (icon != null) 'icon': icon,
    };
  }
}

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
    };
  }
}

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


class Sale {
  final String id; // maps from _id
  final String postId; // 'post/<id>'
  final String buyerId; // 'user/<id>'
  final String sellerId; // 'user/<id>'
  final int price;
  final String status; // pending | completed 
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

class FilterOptions {
  final double? minPrice;
  final double? maxPrice;
  final String? sortBy;

  const FilterOptions({
    this.minPrice,
    this.maxPrice,
    this.sortBy,
  });
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
