
class Category {
  final String id;
  final String name;

  const Category({required this.id, required this.name});
}

class Product {
  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String categoryId;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
  });
}
