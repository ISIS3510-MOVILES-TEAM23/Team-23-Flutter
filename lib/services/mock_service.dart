import '../models/models.dart';

class MockService {
  static Future<List<Product>> getHighlightedProducts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Product(
        id: 'h1',
        title: 'MacBook Pro M2',
        description: 'Excellent condition MacBook Pro with M2 chip, 16GB RAM',
        price: 1200.00,
        images: ['https://picsum.photos/seed/macbook/400/400'],
        categoryId: 'electronics',
        sellerId: 'user1',
        sellerName: 'Carlos Mendoza',
        condition: 'like_new',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        isFeatured: true,
        views: 245,
      ),
      Product(
        id: 'h2',
        title: 'Calculus Textbook',
        description: 'Stewart Calculus 8th Edition, some highlights but good condition',
        price: 45.00,
        images: ['https://picsum.photos/seed/calc/400/400'],
        categoryId: 'books',
        sellerId: 'user2',
        sellerName: 'Maria García',
        condition: 'good',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        isFeatured: true,
        views: 89,
      ),
      Product(
        id: 'h3',
        title: 'Dorm Mini Fridge',
        description: 'Compact refrigerator perfect for dorm rooms',
        price: 80.00,
        images: ['https://picsum.photos/seed/fridge/400/400'],
        categoryId: 'appliances',
        sellerId: 'user3',
        sellerName: 'Luis Rodriguez',
        condition: 'good',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
        isFeatured: true,
        views: 156,
      ),
      Product(
        id: 'h4',
        title: 'Nike Air Max 90',
        description: 'Size 10, worn twice, original box included',
        price: 95.00,
        images: ['https://picsum.photos/seed/nike/400/400'],
        categoryId: 'clothing',
        sellerId: 'user4',
        sellerName: 'Ana Silva',
        condition: 'like_new',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
        isFeatured: true,
        views: 302,
      ),
    ];
  }

  static Future<List<Product>> getNewProducts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Product(
        id: 'n1',
        title: 'Physics Lab Equipment Set',
        description: 'Complete set for Physics 101 lab, includes all required tools',
        price: 65.00,
        images: ['https://picsum.photos/seed/physics/400/400'],
        categoryId: 'school',
        sellerId: 'user5',
        sellerName: 'Pedro Jiménez',
        condition: 'good',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        views: 12,
      ),
      Product(
        id: 'n2',
        title: 'Study Desk with Chair',
        description: 'Ergonomic desk and chair combo, perfect for long study sessions',
        price: 150.00,
        images: ['https://picsum.photos/seed/desk/400/400'],
        categoryId: 'furniture',
        sellerId: 'user6',
        sellerName: 'Sofia Martinez',
        condition: 'good',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        views: 34,
      ),
      Product(
        id: 'n3',
        title: 'TI-84 Calculator',
        description: 'Graphing calculator required for engineering courses',
        price: 70.00,
        images: ['https://picsum.photos/seed/calc84/400/400'],
        categoryId: 'electronics',
        sellerId: 'user7',
        sellerName: 'Diego Herrera',
        condition: 'like_new',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
        views: 67,
      ),
      Product(
        id: 'n4',
        title: 'Organic Chemistry Model Kit',
        description: 'Molecular model kit for chemistry students',
        price: 25.00,
        images: ['https://picsum.photos/seed/chem/400/400'],
        categoryId: 'school',
        sellerId: 'user8',
        sellerName: 'Laura Perez',
        condition: 'new',
        createdAt: DateTime.now().subtract(const Duration(hours: 10)),
        views: 45,
      ),
      Product(
        id: 'n5',
        title: 'Acoustic Guitar',
        description: 'Yamaha acoustic guitar, great for beginners',
        price: 120.00,
        images: ['https://picsum.photos/seed/guitar/400/400'],
        categoryId: 'music',
        sellerId: 'user9',
        sellerName: 'Roberto Vargas',
        condition: 'good',
        createdAt: DateTime.now().subtract(const Duration(hours: 15)),
        views: 91,
      ),
    ];
  }

  static Future<List<Category>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      const Category(id: 'electronics', name: 'Electronics', icon: '💻'),
      const Category(id: 'books', name: 'Books', icon: '📚'),
      const Category(id: 'clothing', name: 'Clothing', icon: '👕'),
      const Category(id: 'furniture', name: 'Furniture', icon: '🪑'),
      const Category(id: 'school', name: 'School Supplies', icon: '✏️'),
      const Category(id: 'appliances', name: 'Appliances', icon: '🔌'),
      const Category(id: 'sports', name: 'Sports', icon: '⚽'),
      const Category(id: 'music', name: 'Music', icon: '🎵'),
    ];
  }

  static Future<List<Product>> getProductsByCategory(String categoryId, {FilterOptions? filters}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Simulamos productos por categoría
    final allProducts = [
      ...await getHighlightedProducts(),
      ...await getNewProducts(),
    ];
    
    var filtered = allProducts.where((p) => p.categoryId == categoryId).toList();
    
    // Aplicar filtros
    if (filters != null) {
      if (filters.minPrice != null) {
        filtered = filtered.where((p) => p.price >= filters.minPrice!).toList();
      }
      if (filters.maxPrice != null) {
        filtered = filtered.where((p) => p.price <= filters.maxPrice!).toList();
      }
      if (filters.condition != null) {
        filtered = filtered.where((p) => p.condition == filters.condition).toList();
      }
      
      // Ordenar
      if (filters.sortBy != null) {
        switch (filters.sortBy) {
          case 'price_low':
            filtered.sort((a, b) => a.price.compareTo(b.price));
            break;
          case 'price_high':
            filtered.sort((a, b) => b.price.compareTo(a.price));
            break;
          case 'newest':
            filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            break;
          case 'popular':
            filtered.sort((a, b) => b.views.compareTo(a.views));
            break;
        }
      }
    }
    
    return filtered;
  }

  static Future<Product?> getProductById(String productId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final allProducts = [
      ...await getHighlightedProducts(),
      ...await getNewProducts(),
    ];
    
    try {
      return allProducts.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  static Future<User> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const User(
      id: 'current_user',
      name: 'Juan Pérez',
      email: 'juan.perez@university.edu',
      profileImageUrl: 'https://picsum.photos/seed/user/200/200',
      isSeller: true,
      rating: 4.8,
      totalSales: 15,
    );
  }

  static Future<List<Product>> getUserProducts(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Product(
        id: 'up1',
        title: 'iPhone 13',
        description: 'Perfect condition, includes charger and case',
        price: 650.00,
        images: ['https://picsum.photos/seed/iphone/400/400'],
        categoryId: 'electronics',
        sellerId: userId,
        sellerName: 'Juan Pérez',
        condition: 'like_new',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
        views: 432,
      ),
      Product(
        id: 'up2',
        title: 'Statistics Textbook',
        description: 'Required for STAT 201, minimal highlighting',
        price: 35.00,
        images: ['https://picsum.photos/seed/stats/400/400'],
        categoryId: 'books',
        sellerId: userId,
        sellerName: 'Juan Pérez',
        condition: 'good',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
        views: 156,
      ),
    ];
  }

  static Future<List<Product>> getUserPurchases(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Product(
        id: 'p1',
        title: 'Laptop Stand',
        description: 'Adjustable aluminum laptop stand',
        price: 25.00,
        images: ['https://picsum.photos/seed/stand/400/400'],
        categoryId: 'electronics',
        sellerId: 'user10',
        sellerName: 'Miguel Torres',
        condition: 'new',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
        isAvailable: false,
      ),
    ];
  }

  static Future<List<Product>> getUserFavorites(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final highlighted = await getHighlightedProducts();
    return highlighted.take(2).toList();
  }

  static Future<List<Conversation>> getUserConversations(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Conversation(
        id: 'conv1',
        productId: 'h1',
        productTitle: 'MacBook Pro M2',
        productImage: 'https://picsum.photos/seed/macbook/100/100',
        buyerId: 'buyer1',
        buyerName: 'Andrea López',
        sellerId: userId,
        sellerName: 'Juan Pérez',
        lastMessage: Message(
          id: 'm1',
          conversationId: 'conv1',
          senderId: 'buyer1',
          receiverId: userId,
          content: '¿Sigue disponible?',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        unreadCount: 1,
      ),
      Conversation(
        id: 'conv2',
        productId: 'h2',
        productTitle: 'Calculus Textbook',
        productImage: 'https://picsum.photos/seed/calc/100/100',
        buyerId: userId,
        buyerName: 'Juan Pérez',
        sellerId: 'seller2',
        sellerName: 'Maria García',
        lastMessage: Message(
          id: 'm2',
          conversationId: 'conv2',
          senderId: 'seller2',
          receiverId: userId,
          content: 'Sí, podemos vernos mañana',
          timestamp: DateTime.now().subtract(const Duration(hours: 5)),
          isRead: true,
        ),
        updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
        unreadCount: 0,
      ),
    ];
  }

  static Future<List<Message>> getConversationMessages(String conversationId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      Message(
        id: 'm1',
        conversationId: conversationId,
        senderId: 'buyer1',
        receiverId: 'current_user',
        content: 'Hola, me interesa el producto',
        timestamp: DateTime.now().subtract(const Duration(hours: 3)),
        isRead: true,
      ),
      Message(
        id: 'm2',
        conversationId: conversationId,
        senderId: 'current_user',
        receiverId: 'buyer1',
        content: 'Hola! Sí, está disponible',
        timestamp: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        isRead: true,
      ),
      Message(
        id: 'm3',
        conversationId: conversationId,
        senderId: 'buyer1',
        receiverId: 'current_user',
        content: '¿Sigue disponible?',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
    ];
  }

  static Future<bool> createProduct(Map<String, dynamic> productData) async {
    await Future.delayed(const Duration(seconds: 1));
    // Simular guardado exitoso
    return true;
  }

  static Future<bool> sendMessage(String conversationId, String content) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Simular envío exitoso
    return true;
  }

  static Future<String> createConversation(String productId, String sellerId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Retornar ID de conversación simulado
    return 'conv_${DateTime.now().millisecondsSinceEpoch}';
  }
}