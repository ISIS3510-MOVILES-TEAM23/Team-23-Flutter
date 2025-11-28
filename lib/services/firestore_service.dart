import 'dart:io';

import 'package:campus_marketplace/services/chat_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart' hide Category;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import 'cache_service.dart'; // Scenario 8: For offline categories
import 'connectivity_service.dart'; // Scenario 8: Check connection status

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  static final Uuid _uuid = const Uuid();
  static String? _sessionId;
  static PackageInfo? _cachedPackageInfo;

  static Future<List<Post>> getHighlightedPosts() async {
    final snapshot = await _db
        .collection('posts')
        .orderBy('created_at', descending: true)
        .limit(10)
        .get();
    // Filtrar por status en el cliente temporalmente
    final posts = snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id; // Asegurar que el ID se asigne
          data['_id'] = doc.id; // También asignar _id por si acaso
          final post = Post.fromJson(data);
          return post;
        })
        .where((post) => post.status == 'active')
        .take(4)
        .toList();
    return posts;
  }

  static Future<List<Post>> getNewPosts() async {
    final snapshot = await _db
        .collection('posts')
        .orderBy('created_at', descending: true)
        .limit(30)
        .get();
    // Filtrar por status en el cliente temporalmente
    final posts = snapshot.docs
        .map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id; // Asegurar que el ID se asigne
          data['_id'] = doc.id; // También asignar _id por si acaso
          final post = Post.fromJson(data);
          return post;
        })
        .where((post) => post.status == 'active')
        .take(20)
        .toList();
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

      await _db.collection('product_search_events').add(payload);
    } catch (e) {
      final errorMsg = e.toString();
      if (!errorMsg.contains('unavailable') && !errorMsg.contains('UNAVAILABLE')) {
        print('⚠️ Error logging product search event: $e');
      }
    }
  }

  // Registrar click/vista de producto para recomendaciones
  static Future<void> logProductClickEvent({
    required String postId,
    String? category,
    String? source,
  }) async {
    try {
      final userId = _auth.currentUser?.uid ?? 'anonymous';
      
      if (userId == 'anonymous') return; // No registrar clicks de usuarios anónimos

      final postRef = _db.collection('posts').doc(postId);

      final payload = <String, dynamic>{
        'post_ref': postRef,
        'category': category,
        'source': source ?? 'unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'userId': userId,
      };

      await _db.collection('product_click_events').add(payload);
    } catch (e) {
      final errorMsg = e.toString();
      if (!errorMsg.contains('unavailable') && !errorMsg.contains('UNAVAILABLE')) {
        print('⚠️ Error logging product click event: $e');
      }
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

  static Future<void> logAppStartTime({int? launchDurationMs}) async {
    try {
      final startTime = DateTime.now();
      final appVersion = await _getAppVersion();
      final sessionId = _ensureSessionId();
      final userId = _auth.currentUser?.uid ?? 'anonymous';
      
      // Obtener información del dispositivo
      final deviceInfoPlugin = DeviceInfoPlugin();
      Map<String, dynamic> deviceInfo = {};
      
      if (kIsWeb) {
        final webInfo = await deviceInfoPlugin.webBrowserInfo;
        deviceInfo = {
          'platform': 'web',
          'browserName': webInfo.browserName.toString(),
          'userAgent': webInfo.userAgent ?? 'unknown',
          'operatingSystem': webInfo.platform ?? 'unknown',
          'language': webInfo.language ?? 'unknown',
          'vendor': webInfo.vendor ?? 'unknown',
        };
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfoPlugin.androidInfo;
        deviceInfo = {
          'platform': 'android',
          'model': androidInfo.model,
          'brand': androidInfo.brand,
          'androidVersion': androidInfo.version.release,
          'sdkInt': androidInfo.version.sdkInt,
          'manufacturer': androidInfo.manufacturer,
          'isPhysicalDevice': androidInfo.isPhysicalDevice,
        };
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfoPlugin.iosInfo;
        deviceInfo = {
          'platform': 'ios',
          'model': iosInfo.model,
          'systemVersion': iosInfo.systemVersion,
          'name': iosInfo.name,
          'isPhysicalDevice': iosInfo.isPhysicalDevice,
          'identifierForVendor': iosInfo.identifierForVendor ?? 'unknown',
        };
      }

      // Obtener información adicional de la app
      final packageInfo = _cachedPackageInfo ?? await PackageInfo.fromPlatform();
      
      final payload = <String, dynamic>{
        'startTime': startTime.toIso8601String(),
        'timestamp': FieldValue.serverTimestamp(),
        'launchDurationMs': launchDurationMs,
        'appVersion': appVersion,
        'appName': packageInfo.appName,
        'packageName': packageInfo.packageName,
        'buildNumber': packageInfo.buildNumber,
        'sessionId': sessionId,
        'userId': userId,
        'deviceInfo': deviceInfo,
        'timeZone': startTime.timeZoneName,
        'timeZoneOffset': startTime.timeZoneOffset.inMinutes,
      };

      // 🚀 [FirestoreService] Logging app start time
      await _db.collection('start-time').add(payload);
    } catch (e, st) {
      // ⚠️ [FirestoreService] Error logging app start time: $e
    }
  }

  static Future<Map<String, dynamic>> getAppStartTimeMetrics({
    String? platform,
    int? lastDays,
  }) async {
    try {
      Query query = _db.collection('start-time');
      
      // Filtrar por plataforma si se especifica
      if (platform != null) {
        query = query.where('deviceInfo.platform', isEqualTo: platform);
      }
      
      // Filtrar por fecha si se especifica
      if (lastDays != null) {
        final startDate = DateTime.now().subtract(Duration(days: lastDays));
        query = query.where('timestamp', isGreaterThan: Timestamp.fromDate(startDate));
      }
      
      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        return {
          'averageLaunchTimeMs': 0,
          'minLaunchTimeMs': 0,
          'maxLaunchTimeMs': 0,
          'totalLaunches': 0,
          'platformBreakdown': {},
        };
      }
      
      final launchTimes = <int>[];
      final platformCounts = <String, int>{};
      final platformTimes = <String, List<int>>{};
      
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final launchTime = data['launchDurationMs'] as int?;
        final devicePlatform = (data['deviceInfo'] as Map<String, dynamic>?)?['platform'] as String?;
        
        if (launchTime != null) {
          launchTimes.add(launchTime);
          
          if (devicePlatform != null) {
            platformCounts[devicePlatform] = (platformCounts[devicePlatform] ?? 0) + 1;
            platformTimes[devicePlatform] ??= [];
            platformTimes[devicePlatform]!.add(launchTime);
          }
        }
      }
      
      // Calcular métricas generales
      final averageTime = launchTimes.isEmpty 
          ? 0 
          : launchTimes.reduce((a, b) => a + b) / launchTimes.length;
      final minTime = launchTimes.isEmpty 
          ? 0 
          : launchTimes.reduce((a, b) => a < b ? a : b);
      final maxTime = launchTimes.isEmpty 
          ? 0 
          : launchTimes.reduce((a, b) => a > b ? a : b);
      
      // Calcular métricas por plataforma
      final platformMetrics = <String, Map<String, dynamic>>{};
      for (final entry in platformTimes.entries) {
        final times = entry.value;
        if (times.isNotEmpty) {
          final avgTime = times.reduce((a, b) => a + b) / times.length;
          platformMetrics[entry.key] = {
            'averageLaunchTimeMs': avgTime.round(),
            'launchCount': platformCounts[entry.key] ?? 0,
          };
        }
      }
      
      return {
        'averageLaunchTimeMs': averageTime.round(),
        'minLaunchTimeMs': minTime,
        'maxLaunchTimeMs': maxTime,
        'totalLaunches': snapshot.docs.length,
        'platformBreakdown': platformMetrics,
      };
    } catch (e) {
      // ⚠️ [FirestoreService] Error getting app start time metrics: $e
      return {
        'error': e.toString(),
        'averageLaunchTimeMs': 0,
        'minLaunchTimeMs': 0,
        'maxLaunchTimeMs': 0,
        'totalLaunches': 0,
        'platformBreakdown': {},
      };
    }
  }

  static Future<List<Category>> getCategories({bool debug = false}) async {
    // Scenario 8: Smart cache strategy for categories
    
    // Import ConnectivityService to check connection status
    final connectivity = ConnectivityService();
    final isOffline = !connectivity.isConnected;
    
    // STRATEGY 1: If offline, try cache FIRST (faster + avoids timeout)
    if (isOffline) {
      debugPrint('[Firestore] 📴 Offline detected - loading categories from cache first...');
      try {
        final cached = await CacheService().getCachedCategories();
        if (cached != null && cached.isNotEmpty) {
          debugPrint('[Firestore] ✅ Loaded ${cached.length} categories from cache (offline mode)');
          return cached.map((json) => Category.fromJson(json)).toList();
        }
        debugPrint('[Firestore] ⚠️ No cached categories found (offline mode)');
      } catch (e) {
        debugPrint('[Firestore] ✗ Failed to load from cache: $e');
      }
      
      // If cache fails and we're offline, throw error with helpful message
      throw Exception('No internet connection and no cached categories available. Please connect to internet to load categories for the first time.');
    }
    
    // STRATEGY 2: If online, fetch from Firestore and update cache
    try {
      debugPrint('[Firestore] 📂 Online - fetching categories from Firestore...');
      final snapshot = await _db.collection('categories').get();
      final allCategories = snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data());
        data['id'] = doc.id;
        data['_id'] = doc.id;
        return Category.fromJson(data);
      }).toList();
      
      debugPrint('[Firestore] ✓ Fetched ${allCategories.length} categories from Firestore');
      
      // Cache for offline use (AWAIT to ensure it's saved)
      if (allCategories.isNotEmpty) {
        try {
          await CacheService().cacheCategories(
            allCategories.map((c) => c.toJson()).toList(),
          );
          debugPrint('[Firestore] ✓ Categories cached successfully for offline use');
        } catch (e) {
          debugPrint('[Firestore] ⚠️ Failed to cache categories: $e');
        }
      }
      
      return allCategories;
    } catch (e) {
      // STRATEGY 3: If Firestore fails but we think we're online, try cache as fallback
      debugPrint('[Firestore] ⚠️ Failed to fetch from Firestore: $e');
      debugPrint('[Firestore] 🔄 Attempting fallback to cache...');
      
      final cached = await CacheService().getCachedCategories();
      if (cached != null && cached.isNotEmpty) {
        debugPrint('[Firestore] ✅ Loaded ${cached.length} categories from cache (fallback)');
        return cached.map((json) => Category.fromJson(json)).toList();
      }
      
      // No cache available
      debugPrint('[Firestore] ❌ No cached categories available');
      debugPrint('[Firestore] ℹ️  Please connect to internet to load categories');
      rethrow;
    }
  }

  static Future<List<Post>> getPostsByCategory(String categoryId,
      {FilterOptions? filters}) async {
    // Encontrar el ID de documento de la categoría basado en el nombre
    String? actualCategoryDocId;
    final categoriesSnapshot = await _db.collection('categories').get();

    for (final categoryDoc in categoriesSnapshot.docs) {
      final categoryData = categoryDoc.data();
      final categoryName = categoryData['name'] as String?;
      final categoryDocId = categoryDoc.id;

      if (categoryName == categoryId || categoryDocId == categoryId) {
        actualCategoryDocId = categoryDocId;
        break;
      }
    }

    if (actualCategoryDocId == null) return [];

    // Obtener todos los posts
    final snapshot = await _db
        .collection('posts')
        .orderBy('created_at', descending: true)
        .get();

    // Buscar ambos formatos - por ID y por nombre
    final targetById = 'categories/$actualCategoryDocId';
    final targetByName = 'categories/$categoryId';

    final filteredPosts = <Post>[];

    for (final doc in snapshot.docs) {
      final data = Map<String, dynamic>.from(doc.data());
      data['id'] = doc.id;
      data['_id'] = doc.id;
      final post = Post.fromJson(data);

      if (post.status != 'active') continue;

      final matchById = post.categoryId == targetById;
      final matchByName = post.categoryId == targetByName;

      if (matchById || matchByName) {
        filteredPosts.add(post);
      }
    }

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

  /// Get current Firebase Auth user (works offline)
  static auth.User? getCurrentFirebaseUser() {
    return _auth.currentUser;
  }

  /// Get current user from Firestore (requires network)
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
        major: null,
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
    String? major,
  }) async {
    final userDoc = _db.collection('users').doc(userId);
    final updateData = {
      'name': name,
      'email': email,
    };
    
    if (major != null) {
      updateData['major'] = major;
    }
    
    await userDoc.update(updateData);
    
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

  // Add or update user rating
  static Future<void> addUserRating({
    required String userId,
    required double rating,
  }) async {
    print('📊 Adding rating: $rating to user: $userId');
    final userDoc = _db.collection('users').doc(userId);
    
    try {
      await _db.runTransaction((transaction) async {
        final snapshot = await transaction.get(userDoc);
        
        if (!snapshot.exists) {
          print('❌ User does not exist: $userId');
          throw Exception('User does not exist');
        }
        
        final data = snapshot.data()!;
        final currentReviews = (data['number_of_reviews'] as int?) ?? 0;
        final currentScore = (data['score'] as num?)?.toDouble() ?? 0.0;
        
        print('📊 Current reviews: $currentReviews, Current score: $currentScore');
        
        // Calculate new average
        final totalScore = (currentScore * currentReviews) + rating;
        final newReviews = currentReviews + 1;
        final newScore = totalScore / newReviews;
        
        print('📊 New reviews: $newReviews, New score: $newScore');
        
        transaction.update(userDoc, {
          'number_of_reviews': newReviews,
          'score': newScore,
        });
        
        print('✅ Rating transaction completed successfully');
      });
    } catch (e) {
      print('❌ Error adding user rating: $e');
      rethrow;
    }
  }

  static Future<List<Post>> getUserPosts(String userId) async {
    debugPrint('[FirestoreService] 📦 getUserPosts for userId: $userId');
    try {
      final snapshot = await _db
          .collection('posts')
          .orderBy('created_at', descending: true)
          .get();
      debugPrint('[FirestoreService] 📥 Got ${snapshot.docs.length} total posts');

      // Filtrar por usuario en el cliente temporalmente
      final userPosts = snapshot.docs
          .map((doc) {
            final data = Map<String, dynamic>.from(doc.data());
            data['id'] = doc.id;
            data['_id'] = doc.id;
            return Post.fromJson(data);
          })
          .where((post) => post.userId == userId)
          .toList();

      debugPrint('[FirestoreService] ✅ Filtered to ${userPosts.length} user posts');
      return userPosts;
    } catch (e) {
      debugPrint('[FirestoreService] ❌ Error getting user posts: $e');
      return [];
    }
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

  static Future<String?> createSale({
    required String postId,
    required String buyerId,
    required String sellerId,
    required int price,
  }) async {
    try {
      final postRef = _db.collection('posts').doc(postId);
      final buyerRef = _db.collection('users').doc(buyerId);
      final sellerRef = _db.collection('users').doc(sellerId);

      // Check if a sale already exists for this post, buyer, and seller
      final existingSales = await _db.collection('sales')
          .where('post_ref', isEqualTo: postRef)
          .where('buyer_ref', isEqualTo: buyerRef)
          .where('seller_ref', isEqualTo: sellerRef)
          .get();

      if (existingSales.docs.isNotEmpty) {
        final existingSaleId = existingSales.docs.first.id;
        print('Sale already exists with ID: $existingSaleId');
        return existingSaleId;
      }

      final saleData = {
        'post_ref': postRef,
        'buyer_ref': buyerRef,
        'seller_ref': sellerRef,
        'price': price,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      };

      final docRef = await _db.collection('sales').add(saleData);
      await docRef.update({'_id': docRef.id});
      
      print('Sale created successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating sale: $e');
      return null;
    }
  }  static Future<bool> updateSaleStatus(String saleId, String status) async {
    try {
      await _db.collection('sales').doc(saleId).update({
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      });
      print('Sale $saleId status updated to $status');
      return true;
    } catch (e) {
      print('Error updating sale status: $e');
      return false;
    }
  }


  static Future<List<PostWithChat>> getUserPostsWithChats(String userId) async {
    List<PostWithChat> postsWithChats = [];
    try {
      final products = await FirestoreService.getUserPosts(userId);
      for (var post in products) {
        // Get sales for this product
        final sales = await FirestoreService.getSalesByPost(post.id);
        if (sales.isEmpty) continue;
        
        for (var sale in sales) {
          User buyer = await FirestoreService.getUserById(sale.buyerId);
          String chatId = await ChatService.getOrCreateChatByBuyerSellerProduct(
              buyerId: buyer.id, sellerId: userId, productId: post.id);
          
          postsWithChats.add(PostWithChat(
            post: post,
            chatId: chatId,
            buyer: buyer,
            sale: sale,
          ));
        }
      }
      return postsWithChats;
    } catch (e) {
      print('Error getting user posts with chats: $e');
      return [];
    }
  }

  /// Get user purchases (where user is the buyer) with full post and seller info
  static Future<List<PostWithChat>> getUserPurchasesWithChats(String userId) async {
    List<PostWithChat> purchases = [];
    try {
      debugPrint('[FirestoreService] 🛒 Getting purchases for user: $userId');
      
      // Get all sales where user is the buyer
      final userRef = _db.collection('users').doc(userId);
      final salesSnapshot = await _db
          .collection('sales')
          .where('buyer_ref', isEqualTo: userRef)
          .orderBy('created_at', descending: true)
          .get();

      debugPrint('[FirestoreService] 📦 Found ${salesSnapshot.docs.length} purchases');

      for (var saleDoc in salesSnapshot.docs) {
        try {
          final saleData = Map<String, dynamic>.from(saleDoc.data());
          saleData['id'] = saleDoc.id;
          saleData['_id'] = saleDoc.id;
          final sale = Sale.fromJson(saleData);

          // Get the post
          final post = await FirestoreService.getPostById(sale.postId);
          if (post == null) {
            debugPrint('[FirestoreService] ⚠️ Post not found: ${sale.postId}');
            continue;
          }
          
          // Get the seller
          final seller = await FirestoreService.getUserById(sale.sellerId);
          
          // Get or create chat
          final chatId = await ChatService.getOrCreateChatByBuyerSellerProduct(
            buyerId: userId,
            sellerId: sale.sellerId,
            productId: sale.postId,
          );

          purchases.add(PostWithChat(
            post: post,
            chatId: chatId,
            buyer: seller, // In this context, it's actually the seller
            sale: sale,
          ));

          debugPrint('[FirestoreService] ✅ Added purchase: ${post.title}');
        } catch (e) {
          debugPrint('[FirestoreService] ❌ Error processing purchase: $e');
          continue;
        }
      }

      debugPrint('[FirestoreService] ✅ Got ${purchases.length} purchases total');
      return purchases;
    } catch (e) {
      debugPrint('[FirestoreService] ❌ Error getting purchases: $e');
      return [];
    }
  }


  // Comments
  // ASYNC STRATEGY: Compute Isolation for Large Comment Lists
  // When comment count exceeds threshold (50), parsing is offloaded to separate isolate
  // to prevent UI jank and maintain smooth scrolling performance
  static const int _commentComputeThreshold = 50;
  
  static Stream<List<Comment>> getComments(String productId) {
    return _db
        .collection('posts')
        .doc(productId)
        .collection('comments')
        .orderBy('created_at', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      // ASYNC OPTIMIZATION: Use compute isolation for large comment lists
      // This prevents UI thread blocking when parsing many comments
      List<Comment> comments;
      
      if (snapshot.docs.length > _commentComputeThreshold) {
        debugPrint('[FirestoreService] 🔄 Processing ${snapshot.docs.length} comments in isolate');
        
        // Prepare data for isolate (must be simple types)
        final rawData = snapshot.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          return data;
        }).toList();
        
        // Offload parsing to separate isolate
        comments = await compute(_parseCommentsInIsolate, rawData);
      } else {
        // For small lists, parse on main thread (faster due to no isolate overhead)
        comments = snapshot.docs.map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Comment.fromJson(data);
        }).toList();
      }
      
      // CACHE COMMENTS: Save to local storage for offline viewing
      try {
        final commentsJson = comments.map((c) => c.toJson()).toList();
        await CacheService().cacheComments(productId, commentsJson);
        debugPrint('[FirestoreService] 💾 Cached ${comments.length} comments for offline use');
      } catch (e) {
        debugPrint('[FirestoreService] ⚠️ Failed to cache comments: $e');
      }
      
      return comments;
    });
  }

  // ASYNC HELPER: Top-level function for isolate execution
  // This runs in a separate isolate to avoid blocking the UI thread
  static List<Comment> _parseCommentsInIsolate(List<Map<String, dynamic>> rawData) {
    return rawData.map((data) => Comment.fromJson(data)).toList();
  }

  static Future<String?> addComment(Comment comment) async {
    // ASYNC OPTIMIZATION: Use batch write for better performance
    // This ensures atomic operation and better error handling
    // RETURNS: Firestore document ID for sync tracking
    try {
      final batch = _db.batch();
      
      final commentRef = _db
          .collection('posts')
          .doc(comment.productId)
          .collection('comments')
          .doc(); // Generate ID
      
      batch.set(commentRef, {
        'product_id': comment.productId,
        'user_id': comment.userId,
        'user_name': comment.userName,
        'content': comment.content,
        'created_at': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      debugPrint('[FirestoreService] ✅ Comment added with ID: ${commentRef.id}');
      return commentRef.id; // Return the generated ID
    } catch (e) {
      debugPrint('[FirestoreService] ❌ Error adding comment: $e');
      return null;
    }
  }

  /// Sync a pending comment to Firestore
  static Future<String?> syncPendingComment(Comment comment) async {
    try {
      debugPrint('[FirestoreService] 🔄 Syncing pending comment: ${comment.localId}');
      
      // Add comment to Firestore
      final firestoreId = await addComment(comment);
      
      if (firestoreId != null) {
        debugPrint('[FirestoreService] ✅ Pending comment synced: ${comment.localId} -> $firestoreId');
      }
      
      return firestoreId;
    } catch (e) {
      debugPrint('[FirestoreService] ❌ Error syncing pending comment: $e');
      return null;
    }
  }

  /// Sync all pending comments for a product
  static Future<int> syncAllPendingComments(List<Comment> pendingComments) async {
    int successCount = 0;
    
    debugPrint('[FirestoreService] 🔄 Syncing ${pendingComments.length} pending comments...');
    
    for (final comment in pendingComments) {
      final firestoreId = await syncPendingComment(comment);
      if (firestoreId != null) {
        successCount++;
      }
    }
    
    debugPrint('[FirestoreService] ✅ Synced $successCount/${pendingComments.length} comments');
    return successCount;
  }
}

