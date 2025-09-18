class User {
  final String id; // maps from _id
  final String name;
  final String contactPreferences; // 'push' | 'email'
  final String email;
  final String password; // ideally hashed
  final String role; // 'student' | 'professor' | 'staff'
  final DateTime createdAt;

  const User({
    required this.id,
    required this.name,
    required this.contactPreferences,
    required this.email,
    required this.password,
    required this.role,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      contactPreferences: json['contact_preferences'],
      email: json['email'],
      password: json['password'],
      role: json['role'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'contact_preferences': contactPreferences,
      'email': email,
      'password': password,
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

  const Category({
    required this.id,
    required this.name,
    required this.description,
    this.subcategory,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['_id'] ?? json['id'],
      name: json['name'],
      description: json['description'] ?? '',
      subcategory: json['subcategory'] != null
          ? SubCategory.fromJson(json['subcategory'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'subcategory': subcategory?.toJson(),
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
  final String subCategoryId; // reference path: category/<id>/sub_category/<id>
  final List<String> images;
  final DateTime createdAt;

  const Post({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.status,
    required this.userId,
    required this.subCategoryId,
    required this.images,
    required this.createdAt,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? json['id'],
      title: json['title'],
      description: json['description'],
      price: json['price'] is int ? json['price'] : (json['price'] as num).toInt(),
      status: json['status'],
      userId: json['user_id'],
      subCategoryId: json['sub_category_id'],
      images: List<String>.from(json['images'] ?? const []),
      createdAt: DateTime.parse(json['created_at']),
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
      'sub_category_id': subCategoryId,
      'images': images,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class ChatMessage {
  final String id; // maps from _id
  final String senderId;
  final String receiverId;
  final String? postId; // optional reference like 'post/<id>'
  final String? content;
  final String? image; // optional image URL
  final DateTime sentAt;
  final bool read;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    this.postId,
    this.content,
    this.image,
    required this.sentAt,
    this.read = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['_id'] ?? json['id'],
      senderId: json['sender_id'],
      receiverId: json['receiver_id'],
      postId: json['post_id'],
      content: json['content'],
      image: json['image'],
      sentAt: DateTime.parse(json['sent_at']),
      read: json['read'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'post_id': postId,
      'content': content,
      'image': image,
      'sent_at': sentAt.toIso8601String(),
      'read': read,
    };
  }
}

class Chat {
  final String id; // maps from _id
  final String user1Id;
  final String user2Id;
  final List<ChatMessage> messages1; // first batch

  const Chat({
    required this.id,
    required this.user1Id,
    required this.user2Id,
    required this.messages1,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['_id'] ?? json['id'],
      user1Id: json['user_1_id'],
      user2Id: json['user_2_id'],
      messages1: (json['messages_1'] as List<dynamic>? ?? const [])
          .map((m) => ChatMessage.fromJson(m))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user_1_id': user1Id,
      'user_2_id': user2Id,
      'messages_1': messages1.map((m) => m.toJson()).toList(),
    };
  }
}

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
      postId: json['post_id'],
      buyerId: json['buyer_id'],
      sellerId: json['seller_id'],
      price: json['price'] is int ? json['price'] : (json['price'] as num).toInt(),
      status: json['status'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'post_id': postId,
      'buyer_id': buyerId,
      'seller_id': sellerId,
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
