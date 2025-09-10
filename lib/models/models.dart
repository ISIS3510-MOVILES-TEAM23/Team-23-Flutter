class User {
  final String id;
  final String name;
  final String email;
  final String? profileImageUrl;
  final bool isSeller;
  final double? rating;
  final int? totalSales;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.profileImageUrl,
    this.isSeller = false,
    this.rating,
    this.totalSales,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
      profileImageUrl: json['profileImageUrl'],
      isSeller: json['isSeller'] ?? false,
      rating: json['rating']?.toDouble(),
      totalSales: json['totalSales'],
    );
  }
}

class Category {
  final String id;
  final String name;
  final String icon;

  const Category({
    required this.id,
    required this.name,
    required this.icon,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      name: json['name'],
      icon: json['icon'],
    );
  }
}

class Product {
  final String id;
  final String title;
  final String description;
  final double price;
  final List<String> images;
  final String categoryId;
  final String sellerId;
  final String sellerName;
  final String condition; // 'new', 'like_new', 'good', 'fair'
  final DateTime createdAt;
  final bool isAvailable;
  final bool isFeatured;
  final int views;

  const Product({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.images,
    required this.categoryId,
    required this.sellerId,
    required this.sellerName,
    required this.condition,
    required this.createdAt,
    this.isAvailable = true,
    this.isFeatured = false,
    this.views = 0,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      price: json['price'].toDouble(),
      images: List<String>.from(json['images']),
      categoryId: json['categoryId'],
      sellerId: json['sellerId'],
      sellerName: json['sellerName'],
      condition: json['condition'],
      createdAt: DateTime.parse(json['createdAt']),
      isAvailable: json['isAvailable'] ?? true,
      isFeatured: json['isFeatured'] ?? false,
      views: json['views'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'images': images,
      'categoryId': categoryId,
      'sellerId': sellerId,
      'sellerName': sellerName,
      'condition': condition,
      'createdAt': createdAt.toIso8601String(),
      'isAvailable': isAvailable,
      'isFeatured': isFeatured,
      'views': views,
    };
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String receiverId;
  final String content;
  final DateTime timestamp;
  final bool isRead;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    required this.timestamp,
    this.isRead = false,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      conversationId: json['conversationId'],
      senderId: json['senderId'],
      receiverId: json['receiverId'],
      content: json['content'],
      timestamp: DateTime.parse(json['timestamp']),
      isRead: json['isRead'] ?? false,
    );
  }
}

class Conversation {
  final String id;
  final String productId;
  final String productTitle;
  final String productImage;
  final String buyerId;
  final String buyerName;
  final String sellerId;
  final String sellerName;
  final Message? lastMessage;
  final DateTime updatedAt;
  final int unreadCount;

  const Conversation({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.productImage,
    required this.buyerId,
    required this.buyerName,
    required this.sellerId,
    required this.sellerName,
    this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'],
      productId: json['productId'],
      productTitle: json['productTitle'],
      productImage: json['productImage'],
      buyerId: json['buyerId'],
      buyerName: json['buyerName'],
      sellerId: json['sellerId'],
      sellerName: json['sellerName'],
      lastMessage: json['lastMessage'] != null 
          ? Message.fromJson(json['lastMessage']) 
          : null,
      updatedAt: DateTime.parse(json['updatedAt']),
      unreadCount: json['unreadCount'] ?? 0,
    );
  }
}

class FilterOptions {
  final double? minPrice;
  final double? maxPrice;
  final String? condition;
  final String? sortBy;

  const FilterOptions({
    this.minPrice,
    this.maxPrice,
    this.condition,
    this.sortBy,
  });
}