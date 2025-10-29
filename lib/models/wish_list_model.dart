import 'package:cloud_firestore/cloud_firestore.dart';

class WishListItem {
  final String id;
  final String userId;
  final String productId;
  final String productTitle;
  final String productDescription;
  final int productPrice;
  final List<String> productImages;
  final DateTime addedAt;
  final String? notes;

  const WishListItem({
    required this.id,
    required this.userId,
    required this.productId,
    required this.productTitle,
    required this.productDescription,
    required this.productPrice,
    required this.productImages,
    required this.addedAt,
    this.notes,
  });

  factory WishListItem.fromJson(Map<String, dynamic> json) {
    final dynamic addedAtRaw = json['added_at'];
    DateTime addedAt;
    if (addedAtRaw is Timestamp) {
      addedAt = addedAtRaw.toDate();
    } else if (addedAtRaw is DateTime) {
      addedAt = addedAtRaw;
    } else if (addedAtRaw is String) {
      addedAt = DateTime.tryParse(addedAtRaw) ?? DateTime.now();
    } else {
      addedAt = DateTime.now();
    }

    final imagesRaw = json['product_images'];
    final images = imagesRaw is List
        ? imagesRaw.map((e) => e.toString()).toList()
        : <String>[];

    final priceRaw = json['product_price'];
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

    return WishListItem(
      id: json['_id'] ?? json['id'] ?? '',
      userId: json['user_id'] ?? '',
      productId: json['product_id'] ?? '',
      productTitle: json['product_title'] ?? '',
      productDescription: json['product_description'] ?? '',
      productPrice: price,
      productImages: images,
      addedAt: addedAt,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'user_id': userId,
      'product_id': productId,
      'product_title': productTitle,
      'product_description': productDescription,
      'product_price': productPrice,
      'product_images': productImages,
      'added_at': Timestamp.fromDate(addedAt),
      if (notes != null) 'notes': notes,
    };
  }

  WishListItem copyWith({
    String? id,
    String? userId,
    String? productId,
    String? productTitle,
    String? productDescription,
    int? productPrice,
    List<String>? productImages,
    DateTime? addedAt,
    String? notes,
  }) {
    return WishListItem(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      productId: productId ?? this.productId,
      productTitle: productTitle ?? this.productTitle,
      productDescription: productDescription ?? this.productDescription,
      productPrice: productPrice ?? this.productPrice,
      productImages: productImages ?? this.productImages,
      addedAt: addedAt ?? this.addedAt,
      notes: notes ?? this.notes,
    );
  }
}
