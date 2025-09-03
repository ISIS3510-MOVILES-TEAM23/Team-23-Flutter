import 'models.dart';

const List<Category> kCategories = [
  Category(id: 'c1', name: 'Clothing'),
  Category(id: 'c2', name: 'Electronics'),
  Category(id: 'c3', name: 'Home & Garden'),
  Category(id: 'c4', name: 'Books'),
];

const List<Product> kProducts = [
  // Clothing
  Product(
    id: 'p1',
    name: 'Mens T-Shirt',
    price: 25.00,
    imageUrl: 'https://picsum.photos/seed/p1/400/400',
    categoryId: 'c1',
  ),
  Product(
    id: 'p2',
    name: 'Womens Jeans',
    price: 60.00,
    imageUrl: 'https://picsum.photos/seed/p2/400/400',
    categoryId: 'c1',
  ),
  // Electronics
  Product(
    id: 'p3',
    name: 'Wireless Headphones',
    price: 150.00,
    imageUrl: 'https://picsum.photos/seed/p3/400/400',
    categoryId: 'c2',
  ),
  Product(
    id: 'p4',
    name: 'Smartwatch',
    price: 250.00,
    imageUrl: 'https://picsum.photos/seed/p4/400/400',
    categoryId: 'c2',
  ),
  // Home & Garden
  Product(
    id: 'p5',
    name: 'Indoor Plant',
    price: 35.00,
    imageUrl: 'https://picsum.photos/seed/p5/400/400',
    categoryId: 'c3',
  ),
  Product(
    id: 'p6',
    name: 'Scented Candle',
    price: 15.00,
    imageUrl: 'https://picsum.photos/seed/p6/400/400',
    categoryId: 'c3',
  ),
  // Books
  Product(
    id: 'p7',
    name: 'The Hitchhikers Guide to the Galaxy',
    price: 12.99,
    imageUrl: 'https://picsum.photos/seed/p7/400/400',
    categoryId: 'c4',
  ),
  Product(
    id: 'p8',
    name: 'Pride and Prejudice',
    price: 9.99,
    imageUrl: 'https://picsum.photos/seed/p8/400/400',
    categoryId: 'c4',
  ),
];