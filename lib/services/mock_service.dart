import '../models/models.dart';

class MockService {
  static Future<List<Post>> getHighlightedPosts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Post(
        id: 'h1',
        title: 'MacBook Pro M2',
        description: 'Excellent condition MacBook Pro with M2 chip, 16GB RAM',
        price: 120000, // integer price
        images: ['https://picsum.photos/seed/macbook/400/400'],
        status: 'active',
        userId: 'user/u1',
        subCategoryId: 'category/electronics/sub_category/laptops',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Post(
        id: 'h2',
        title: 'Calculus Textbook',
        description: 'Stewart Calculus 8th Edition, some highlights but good condition',
        price: 4500,
        images: ['https://picsum.photos/seed/calc/400/400'],
        status: 'active',
        userId: 'user/u2',
        subCategoryId: 'category/books/sub_category/textbooks',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Post(
        id: 'h3',
        title: 'Dorm Mini Fridge',
        description: 'Compact refrigerator perfect for dorm rooms',
        price: 8000,
        images: ['https://picsum.photos/seed/fridge/400/400'],
        status: 'active',
        userId: 'user/u3',
        subCategoryId: 'category/appliances/sub_category/fridge',
        createdAt: DateTime.now().subtract(const Duration(hours: 12)),
      ),
      Post(
        id: 'h4',
        title: 'Nike Air Max 90',
        description: 'Size 10, worn twice, original box included',
        price: 9500,
        images: ['https://picsum.photos/seed/nike/400/400'],
        status: 'active',
        userId: 'user/u4',
        subCategoryId: 'category/clothing/sub_category/shoes',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
    ];
  }

  static Future<List<Post>> getNewPosts() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Post(
        id: 'n1',
        title: 'Physics Lab Equipment Set',
        description: 'Complete set for Physics 101 lab, includes all required tools',
        price: 6500,
        images: ['https://picsum.photos/seed/physics/400/400'],
        status: 'active',
        userId: 'user/u5',
        subCategoryId: 'category/school/sub_category/lab',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Post(
        id: 'n2',
        title: 'Study Desk with Chair',
        description: 'Ergonomic desk and chair combo, perfect for long study sessions',
        price: 15000,
        images: ['https://picsum.photos/seed/desk/400/400'],
        status: 'active',
        userId: 'user/u6',
        subCategoryId: 'category/furniture/sub_category/desk',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      Post(
        id: 'n3',
        title: 'TI-84 Calculator',
        description: 'Graphing calculator required for engineering courses',
        price: 7000,
        images: ['https://picsum.photos/seed/calc84/400/400'],
        status: 'active',
        userId: 'user/u7',
        subCategoryId: 'category/electronics/sub_category/calculators',
        createdAt: DateTime.now().subtract(const Duration(hours: 8)),
      ),
      Post(
        id: 'n4',
        title: 'Organic Chemistry Model Kit',
        description: 'Molecular model kit for chemistry students',
        price: 2500,
        images: ['https://picsum.photos/seed/chem/400/400'],
        status: 'active',
        userId: 'user/u8',
        subCategoryId: 'category/school/sub_category/chemistry',
        createdAt: DateTime.now().subtract(const Duration(hours: 10)),
      ),
      Post(
        id: 'n5',
        title: 'Acoustic Guitar',
        description: 'Yamaha acoustic guitar, great for beginners',
        price: 12000,
        images: ['https://picsum.photos/seed/guitar/400/400'],
        status: 'active',
        userId: 'user/u9',
        subCategoryId: 'category/music/sub_category/instruments',
        createdAt: DateTime.now().subtract(const Duration(hours: 15)),
      ),
    ];
  }

  static Future<List<Category>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      const Category(id: 'electronics', name: 'Electronics', description: 'Devices and gadgets'),
      const Category(id: 'books', name: 'Books', description: 'Textbooks, novels, academic material'),
      const Category(id: 'clothing', name: 'Clothing', description: 'Apparel and accessories'),
      const Category(id: 'furniture', name: 'Furniture', description: 'Home and dorm furniture'),
      const Category(id: 'school', name: 'School Supplies', description: 'Materials for classes'),
      const Category(id: 'appliances', name: 'Appliances', description: 'Home appliances'),
      const Category(id: 'sports', name: 'Sports', description: 'Sports and outdoors'),
      const Category(id: 'music', name: 'Music', description: 'Music instruments and gear'),
    ];
  }

  static Future<List<Post>> getPostsByCategory(String categoryId, {FilterOptions? filters}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Simulamos productos por categoría
    final allProducts = [
      ...await getHighlightedPosts(),
      ...await getNewPosts(),
    ];
    
    var filtered = allProducts.where((p) => p.subCategoryId.startsWith('category/$categoryId')).toList();
    
    // Aplicar filtros
    if (filters != null) {
      // UI provides price in dollars; backend uses integer price (e.g., cents)
      final int? minCents = filters.minPrice != null
          ? (filters.minPrice! * 100).round()
          : null;
      final int? maxCents = filters.maxPrice != null
          ? (filters.maxPrice! * 100).round()
          : null;

      if (minCents != null) {
        filtered = filtered.where((p) => p.price >= minCents).toList();
      }
      if (maxCents != null) {
        filtered = filtered.where((p) => p.price <= maxCents).toList();
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
        }
      }
    }
    
    return filtered;
  }

  static Future<Post?> getPostById(String postId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final allProducts = [
      ...await getHighlightedPosts(),
      ...await getNewPosts(),
    ];
    
    try {
      return allProducts.firstWhere((p) => p.id == postId);
    } catch (e) {
      return null;
    }
  }

  static Future<User> getCurrentUser() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return User(
      id: 'u_current',
      name: 'Juan Pérez',
      contactPreferences: 'push',
      email: 'juan.perez@university.edu',
      password: 'hashed_password',
      role: 'student',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    );
  }

  static Future<User> getUserById(String userId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    // Very simple mock directory
    final Map<String, User> users = {
      'user/u1': User(
        id: 'u1',
        name: 'Carlos Mendoza',
        contactPreferences: 'push',
        email: 'carlos@university.edu',
        password: 'hashed',
        role: 'student',
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
      ),
      'user/u2': User(
        id: 'u2',
        name: 'Maria García',
        contactPreferences: 'email',
        email: 'maria@university.edu',
        password: 'hashed',
        role: 'student',
        createdAt: DateTime.now().subtract(const Duration(days: 80)),
      ),
      'user/u3': User(
        id: 'u3',
        name: 'Luis Rodriguez',
        contactPreferences: 'push',
        email: 'luis@university.edu',
        password: 'hashed',
        role: 'student',
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
      ),
      'user/u4': User(
        id: 'u4',
        name: 'Ana Silva',
        contactPreferences: 'sms',
        email: 'ana@university.edu',
        password: 'hashed',
        role: 'student',
        createdAt: DateTime.now().subtract(const Duration(days: 40)),
      ),
      'user/u_current': User(
        id: 'u_current',
        name: 'Juan Pérez',
        contactPreferences: 'push',
        email: 'juan.perez@university.edu',
        password: 'hashed_password',
        role: 'student',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    };
    return users[userId] ?? User(
      id: userId.split('/').last,
      name: userId,
      contactPreferences: 'push',
      email: 'user@university.edu',
      password: 'hashed',
      role: 'student',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    );
  }

  static Future<List<Post>> getUserPosts(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Post(
        id: 'up1',
        title: 'iPhone 13',
        description: 'Perfect condition, includes charger and case',
        price: 65000,
        images: ['https://picsum.photos/seed/iphone/400/400'],
        status: 'active',
        userId: 'user/$userId',
        subCategoryId: 'category/electronics/sub_category/phones',
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Post(
        id: 'up2',
        title: 'Statistics Textbook',
        description: 'Required for STAT 201, minimal highlighting',
        price: 3500,
        images: ['https://picsum.photos/seed/stats/400/400'],
        status: 'active',
        userId: 'user/$userId',
        subCategoryId: 'category/books/sub_category/textbooks',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
    ];
  }

  static Future<List<Post>> getUserPurchases(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Post(
        id: 'p1',
        title: 'Laptop Stand',
        description: 'Adjustable aluminum laptop stand',
        price: 2500,
        images: ['https://picsum.photos/seed/stand/400/400'],
        status: 'sold',
        userId: 'user/u10',
        subCategoryId: 'category/electronics/sub_category/accessories',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];
  }

  static Future<List<Post>> getUserFavorites(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final highlighted = await getHighlightedPosts();
    return highlighted.take(2).toList();
  }

  static Future<List<Chat>> getUserChats(String userId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      Chat(
        id: 'chat1',
        user1Id: userId,
        user2Id: 'u789',
        messages1: [
          ChatMessage(
            id: 'm101',
            senderId: userId,
            receiverId: 'u789',
            postId: 'post/h1',
            content: 'Is this book still available?',
            sentAt: DateTime.now().subtract(const Duration(hours: 2)),
            read: true,
          ),
        ],
      ),
      Chat(
        id: 'chat2',
        user1Id: 'u222',
        user2Id: userId,
        messages1: [
          ChatMessage(
            id: 'm102',
            senderId: 'u222',
            receiverId: userId,
            content: 'Sí, podemos vernos mañana',
            sentAt: DateTime.now().subtract(const Duration(hours: 5)),
            read: true,
          ),
        ],
      ),
    ];
  }

  static Future<List<ChatMessage>> getChatMessages(String chatId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [
      ChatMessage(
        id: 'm1',
        senderId: 'buyer1',
        receiverId: 'u_current',
        content: 'Hola, me interesa el producto',
        sentAt: DateTime.now().subtract(const Duration(hours: 3)),
        read: true,
      ),
      ChatMessage(
        id: 'm2',
        senderId: 'u_current',
        receiverId: 'buyer1',
        content: 'Hola! Sí, está disponible',
        sentAt: DateTime.now().subtract(const Duration(hours: 2, minutes: 30)),
        read: true,
      ),
      ChatMessage(
        id: 'm3',
        senderId: 'buyer1',
        receiverId: 'u_current',
        content: '¿Sigue disponible?',
        sentAt: DateTime.now().subtract(const Duration(hours: 2)),
        read: false,
      ),
    ];
  }

  static Future<bool> createPost(Map<String, dynamic> postData) async {
    await Future.delayed(const Duration(seconds: 1));
    // Simular guardado exitoso
    return true;
  }

  static Future<bool> sendMessage(String chatId, String content) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Simular envío exitoso
    return true;
  }

  static Future<String> createChat(String postId, String otherUserId) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Retornar ID de conversación simulado
    return 'chat_${DateTime.now().millisecondsSinceEpoch}';
  }
}