import 'package:campus_marketplace/services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  static final Uuid _uuid = const Uuid();
  static String? _sessionId;
  static PackageInfo? _cachedPackageInfo;

  static Future<List<Post>> getHighlightedPosts() async {
    print('🔥 [FirestoreService] getHighlightedPosts() - inicio');
    final snapshot = await _db
        .collection('posts')
        .orderBy('created_at', descending: true)
        .limit(10)
        .get();
    print(
        '🔥 [FirestoreService] getHighlightedPosts() - documentos obtenidos: ${snapshot.docs.length}');
    // Filtrar por status en el cliente temporalmente
    final posts = snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id; // Asegurar que el ID se asigne
          data['_id'] = doc.id; // También asignar _id por si acaso
          print(
              '🔥 [FirestoreService] getHighlightedPosts() - crudo doc ${doc.id}: $data');
          final post = Post.fromJson(data);
          print(
              '🔥 [FirestoreService] getHighlightedPosts() - post parsed ID=${post.id}, title="${post.title}", status=${post.status}, category=${post.categoryId}');
          return post;
        })
        .where((post) => post.status == 'active')
        .take(4)
        .toList();
    print(
        '🔥 [FirestoreService] getHighlightedPosts() - posts activos finales: ${posts.length}');
    return posts;
  }

  static Future<List<Post>> getNewPosts() async {
    print('🆕 [FirestoreService] getNewPosts() - inicio');
    final snapshot = await _db
        .collection('posts')
        .orderBy('created_at', descending: true)
        .limit(10)
        .get();
    print(
        '🆕 [FirestoreService] getNewPosts() - documentos obtenidos: ${snapshot.docs.length}');
    // Filtrar por status en el cliente temporalmente
    final posts = snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id; // Asegurar que el ID se asigne
          data['_id'] = doc.id; // También asignar _id por si acaso
          print(
              '🆕 [FirestoreService] getNewPosts() - crudo doc ${doc.id}: $data');
          final post = Post.fromJson(data);
          print(
              '🆕 [FirestoreService] getNewPosts() - post parsed ID=${post.id}, title="${post.title}", status=${post.status}, category=${post.categoryId}');
          return post;
        })
        .where((post) => post.status == 'active')
        .take(5)
        .toList();
    print(
        '🆕 [FirestoreService] getNewPosts() - posts activos finales: ${posts.length}');
    return posts;
  }

  static Future<void> logProductSearchEvent({
    required String source,
    String? query,
    String? selectedCategory,
    List<String>? suggestedCategories,
  }) async {
    try {
      final appVersion = await _getAppVersion();
      final sessionId = _ensureSessionId();
      final userId = _auth.currentUser?.uid ?? 'anonymous';

      final payload = <String, dynamic>{
        'appVersion': appVersion,
        'query': query,
        'selectedCategory': selectedCategory,
        'sessionId': sessionId,
        'source': source,
        'suggestedCategories': suggestedCategories ?? <String>[],
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
      };

      print('📊 [FirestoreService] Logging product search event -> $payload');
      await _db.collection('product_search_events').add(payload);
    } catch (e, st) {
      print('⚠️ [FirestoreService] Error logging product search event: $e');
      print(st);
    }
  }

  static String _ensureSessionId() {
    _sessionId ??= _uuid.v4();
    return _sessionId!;
  }

  static Future<String> _getAppVersion() async {
    try {
      _cachedPackageInfo ??= await PackageInfo.fromPlatform();
      return _cachedPackageInfo?.version ?? 'unknown';
    } catch (e) {
      print('⚠️ [FirestoreService] Error obtaining app version: $e');
      return 'unknown';
    }
  }

  static Future<List<Category>> getCategories({bool debug = false}) async {
    if (debug) print('🔍 GETTING CATEGORIES - START');

    final snapshot = await _db.collection('categories').get();
    if (debug)
      print('📁 Found ${snapshot.docs.length} category documents in Firestore');

    final allCategories = snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['_id'] = doc.id;
      final category = Category.fromJson(data);
      if (debug)
        print('📂 Category: ID="${category.id}", Name="${category.name}"');
      return category;
    }).toList();

    if (debug) {
      final postsSnapshot = await _db.collection('posts').get();
      print(
          '📄 Found ${postsSnapshot.docs.length} post documents in Firestore');
      for (final postDoc in postsSnapshot.docs) {
        final postData = postDoc.data();
        final dynamic rawCategoryId = postData['category_id'];
        final categoryId = rawCategoryId is DocumentReference
            ? rawCategoryId.path
            : rawCategoryId?.toString();
        final status = postData['status']?.toString();
        final title = postData['title']?.toString();
        print(
            '📝 Post: Title="$title", category_id="$categoryId", status="$status"');
      }
      print('✅ Returning ALL ${allCategories.length} categories for debugging');
    }

    return allCategories;
  }

  static Future<List<Post>> getPostsByCategory(String categoryId,
      {FilterOptions? filters}) async {
    print('🚀 GETTING POSTS BY CATEGORY - START'); // Debug
    print('🎯 Input categoryId: "$categoryId"'); // Debug

    // PASO 1: Encontrar el ID de documento de la categoría basado en el nombre
    String? actualCategoryDocId;
    final categoriesSnapshot = await _db.collection('categories').get();

    for (final categoryDoc in categoriesSnapshot.docs) {
      final categoryData = categoryDoc.data();
      final categoryName = categoryData['name'] as String?;
      final categoryDocId = categoryDoc.id;

      print(
          '📂 Checking category: ID="$categoryDocId", Name="$categoryName"'); // Debug

      if (categoryName == categoryId || categoryDocId == categoryId) {
        actualCategoryDocId = categoryDocId;
        print(
            '🎯 FOUND MATCH! Using document ID: "$actualCategoryDocId" for input: "$categoryId"'); // Debug
        break;
      }
    }

    if (actualCategoryDocId == null) {
      print('❌ No matching category found for: "$categoryId"'); // Debug
      return [];
    }

    // PASO 2: Obtener TODOS los posts sin filtro
    final snapshot = await _db
        .collection('posts')
        .orderBy('created_at', descending: true)
        .get();
    print('📄 Found ${snapshot.docs.length} total posts in Firestore'); // Debug

    // PASO 3: Buscar AMBOS formatos - por ID y por nombre
    final targetById = 'categories/$actualCategoryDocId';
    final targetByName = 'categories/$categoryId';
    print(
        '🎯 Looking for posts with category_id="$targetById" OR "$targetByName"'); // Debug

    final filteredPosts = <Post>[];

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['_id'] = doc.id;
      final post = Post.fromJson(data);

      // Solo posts activos
      if (post.status != 'active') continue;

      // Verificar match con AMBOS formatos
      final matchById = post.categoryId == targetById;
      final matchByName = post.categoryId == targetByName;

      if (matchById || matchByName) {
        print(
            '✅ MATCH: "${post.title}" has category_id="${post.categoryId}" (${matchById ? "by ID" : "by NAME"})'); // Debug
        filteredPosts.add(post);
      } else {
        print(
            '❌ NO MATCH: "${post.title}" has category_id="${post.categoryId}"'); // Debug
      }
    }

    print('🎉 FINAL RESULT: ${filteredPosts.length} posts found'); // Debug

    return filteredPosts;
  }

  static Future<Post?> getPostById(String postId) async {
    final doc = await _db.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    final data = Map<String, dynamic>.from(doc.data()!);
    data['id'] = doc.id; // Asegurar que el ID se asigne
    data['_id'] = doc.id; // También asignar _id por si acaso
    print('getPostById: ID=${doc.id}'); // Debug
    return Post.fromJson(data);
  }

  static Future<List<Sale>> getSalesByPost(String postId) async {
    print('Fetching sales for postId: $postId');
    final postRef = _db.collection('posts').doc(postId);
    final snapshot = await _db
        .collection('sales')
        .where('post_ref', isEqualTo: postRef)
        .get();
    if (snapshot.docs.isEmpty) return [];
    print('Found ${snapshot.docs.length} sales for postId: $postId');
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['_id'] = doc.id;
      print('Sale found: ${doc.id}');
      return Sale.fromJson(data);
    }).toList();
  }

  static Future<User?> getCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return getUserById(firebaseUser.uid);
  }

  static Future<User?> createUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    final userDoc = _db.collection('users').doc(firebaseUser.uid);
    final doc = await userDoc.get();
    if (doc.exists) {
      final data = Map<String, dynamic>.from(doc.data()!);
      data['id'] = doc.id;
      data['_id'] = doc.id;
      return User.fromJson(data);
    } else {
      final newUser = User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? 'New User',
        contactPreferences: '',
        role: '',
        createdAt: DateTime.now(),
      );
      await userDoc.set(newUser.toJson());
      return newUser;
    }
  }

  static Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String email,
    String? password,
  }) async {
    final userDoc = _db.collection('users').doc(userId);
    await userDoc.update({
      'name': name,
      'email': email,
    });
    if (password != null && password.isNotEmpty) {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null && firebaseUser.uid == userId) {
        try {
          await firebaseUser.updatePassword(password);
        } catch (e) {
          print('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%Error updating password: $e');
          // Handle password update errors (e.g., re-authentication required)
        }
        
      }
    }

  }

  static Future<User> getUserById(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = Map<String, dynamic>.from(doc.data()!);
    data['id'] = doc.id;
    data['_id'] = doc.id;
    return User.fromJson(data);
  }

  static Future<List<Post>> getUserPosts(String userId) async {
    final snapshot = await _db
        .collection('posts')
        .orderBy('created_at', descending: true)
        .get();
    // Filtrar por usuario en el cliente temporalmente
    return snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          data['_id'] = doc.id;
          return Post.fromJson(data);
        })
        .where((post) => post.userId == userId)
        .toList();
  }

  static Future<List<Post>> getUserPurchases(String userId) async {
    // Obtener todas las ventas y filtrar en cliente
    final salesSnapshot = await _db.collection('sales').get();
    final postIds = salesSnapshot.docs
        .map((doc) => doc.data())
        .where((sale) => sale['buyer_id'] == userId)
        .map((sale) => sale['post_id'])
        .toList();
    if (postIds.isEmpty) return [];

    final postsSnapshot = await _db
        .collection('posts')
        .where(FieldPath.documentId, whereIn: postIds)
        .get();
    return postsSnapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['_id'] = doc.id;
      return Post.fromJson(data);
    }).toList();
  }

  static Future<List<Post>> getUserFavorites(String userId) async {
    final snapshot =
        await _db.collection('users').doc(userId).collection('favorites').get();
    final postIds = snapshot.docs.map((doc) => doc.id).toList();
    if (postIds.isEmpty) return [];

    final postsSnapshot = await _db
        .collection('posts')
        .where(FieldPath.documentId, whereIn: postIds)
        .get();
    return postsSnapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['_id'] = doc.id;
      return Post.fromJson(data);
    }).toList();
  }

  // DEPRECATED: Use ChatService.streamUserChats() instead
  static Future<List<Chat>> getUserChats(String userId) async {
    // This method is deprecated as the Chat model has changed
    // Use ChatService for all chat-related operations
    return [];
  }

  static Future<List<ChatMessage>> getChatMessages(String chatId) async {
    final snapshot = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sent_at')
        .get();
    return snapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['_id'] = doc.id;
      return ChatMessage.fromJson(data);
    }).toList();
  }

  static String generatePostId() {
    return _db.collection('posts').doc().id;
  }

  static Future<bool> createPost(Map<String, dynamic> postData,
      {String? forceId}) async {
    try {
      final col = _db.collection('posts');
      if (forceId != null && forceId.isNotEmpty) {
        postData['_id'] = forceId;
        await col.doc(forceId).set(postData);
      } else {
        final docRef = await col.add(postData);
        await docRef.update({'_id': docRef.id});
      }
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  static Future<bool> sendMessage(String chatId, String content) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return false;

      final chatDoc = await _db.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return false;

      final otherUserId = chatDoc.data()!['user_1_id'] == currentUser.uid
          ? chatDoc.data()!['user_2_id']
          : chatDoc.data()!['user_1_id'];

      await _db.collection('chats').doc(chatId).collection('messages').add({
        'sender_id': currentUser.uid,
        'receiver_id': otherUserId,
        'content': content,
        'sent_at': FieldValue.serverTimestamp(),
        'read': false,
      });
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  static Future<String> createChat(String postId, String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return '';

      // Check if a chat already exists - obtener todos y filtrar en cliente
      final existingChat = await _db.collection('chats').get();

      for (var doc in existingChat.docs) {
        final data = doc.data();
        final user1 = data['user_1_id'];
        final user2 = data['user_2_id'];
        if ((user1 == currentUser.uid && user2 == otherUserId) ||
            (user1 == otherUserId && user2 == currentUser.uid)) {
          return doc.id;
        }
      }

      final newChat = await _db.collection('chats').add({
        'user_1_id': currentUser.uid,
        'user_2_id': otherUserId,
        'messages_1': [],
      });
      return newChat.id;
    } catch (e) {
      print(e);
      return '';
    }
  }

  static Future<List<PostWithChat>> getUserPostsWithChats(String userId) async {
    List<PostWithChat> postsWithChats = [];
    try {
      final products = await FirestoreService.getUserPosts(userId);
      for (var post in products) {
        print('Sales for post ${post.id}');
        final sales = await FirestoreService.getSalesByPost(post.id);
        if (sales.isEmpty) continue;
        for (var sale in sales) {
          print('Sale: ${sale.id}');
          User buyer = await FirestoreService.getUserById(sale.buyerId);
          print('Buyer: ${buyer.id}');
          String chatId = await ChatService.getOrCreateChatByBuyerSellerProduct(
              buyerId: buyer.id, sellerId: userId, productId: post.id);
          print('Chat ID: $chatId');
          postsWithChats.add(PostWithChat(
            post: post,
            chatId: chatId,
            buyer: buyer,
            sale: sale,
          ));
        }
      }
      print(postsWithChats);
    } catch (e) {
      print('Error fetching posts with chats: $e');
      return postsWithChats;
    }
    print('is not working');
    return postsWithChats;
  }
}
