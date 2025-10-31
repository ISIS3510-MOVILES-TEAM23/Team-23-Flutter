import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';

import '../models/models.dart';
import 'firestore_service.dart';
import 'connectivity_service.dart';
import 'cache_service.dart';
import 'sync_queue_service.dart';

class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  static final ConnectivityService _connectivity = ConnectivityService();
  static final CacheService _cache = CacheService();
  static final SyncQueueService _syncQueue = SyncQueueService();

  // Stream controllers for offline message updates
  static final Map<String, StreamController<List<ChatMessage>>> _messageControllers = {};

  // Obtener o crear un chat para un producto (Modified Scenario 10)
  static Future<String> getOrCreateProductChat(String productId, String sellerId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw StateError('User not authenticated');

    // You can't chat with yourself
    if (currentUserId == sellerId) {
      throw StateError('You cannot chat with yourself');
    }

    // Scenario 10 Modified: Allow creating chat offline if product is cached
    if (!_connectivity.isConnected) {
      debugPrint('[Chat] 📴 OFFLINE - Checking if product is cached...');

      // Check if product is cached
      final cachedPost = await _cache.getCachedPost(productId);
      if (cachedPost == null) {
        throw StateError('Cannot start new chat while offline without cached product. Please connect to internet.');
      }

      debugPrint('[Chat] ✅ Product cached - allowing offline chat creation');

      // Generate temporary offline chat ID
      final offlineChatId = 'offline_${DateTime.now().millisecondsSinceEpoch}_$productId';

      // Cache the chat info for offline use
      final offlineChatInfo = {
        'chatId': offlineChatId,
        'buyer_id': currentUserId,
        'seller_id': sellerId,
        'product_id': productId,
        'participant_ids': [currentUserId, sellerId],
        'created_at': DateTime.now().toIso8601String(),
        'is_offline': true,
      };

      await _cache.cacheChatInfo(offlineChatId, offlineChatInfo);
      debugPrint('[Chat] 📤 Offline chat created with temp ID: $offlineChatId');

      return offlineChatId;
    }

    // ONLINE - Normal flow
    // Buscar chat existente
    final existingChats = await _db.collection('chats')
        .where('product_id', isEqualTo: productId)
        .where('participant_ids', arrayContains: currentUserId)
        .get();

    // Filtrar para encontrar el chat con el vendedor correcto
    for (final doc in existingChats.docs) {
      final data = doc.data();
      final participants = List<String>.from(data['participant_ids'] ?? []);
      if (participants.contains(sellerId)) {
        print('📱 Existing chat found: ${doc.id}');
        return doc.id;
      }
    }

    // Crear nuevo chat
    print('📱 Creating new chat for product: $productId');
    final chatData = {
      'buyer_id': currentUserId,
      'seller_id': sellerId,
      'product_id': productId,
      'participant_ids': [currentUserId, sellerId],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_message': null,
      'unread_count_buyer': 0,
      'unread_count_seller': 0,
    };

    final chatRef = await _db.collection('chats').add(chatData);
    print('📱 Chat created: ${chatRef.id}');
    return chatRef.id;
  }

  /// Get existing product chat without creating one (Scenario 10)
  /// Returns null if no chat exists
  static Future<String?> getExistingProductChat(String productId, String sellerId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return null;

    // You can't chat with yourself
    if (currentUserId == sellerId) return null;

    try {
      // OFFLINE - Check cache
      if (!_connectivity.isConnected) {
        debugPrint('[Chat] 📴 OFFLINE - Checking for existing chat in cache...');
        
        // Check if there's a cached chat for this product
        final cachedChats = await _cache.getCachedUserChats();
        if (cachedChats != null) {
          for (final chatJson in cachedChats) {
            final productId_ = chatJson['product_id']?.toString();
            final participants = List<String>.from(chatJson['participant_ids'] ?? []);
            if (productId_ == productId && 
                participants.contains(currentUserId) && 
                participants.contains(sellerId)) {
              final chatId = chatJson['chatId']?.toString() ?? chatJson['id']?.toString();
              debugPrint('[Chat] ✅ Found existing chat in cache: $chatId');
              return chatId;
            }
          }
        }
        
        debugPrint('[Chat] ⚠️ No existing chat found in cache');
        return null;
      }

      // ONLINE - Query Firestore
      final existingChats = await _db.collection('chats')
          .where('product_id', isEqualTo: productId)
          .where('participant_ids', arrayContains: currentUserId)
          .get();

      // Filter to find the chat with the correct seller
      for (final doc in existingChats.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participant_ids'] ?? []);
        if (participants.contains(sellerId)) {
          debugPrint('[Chat] ✅ Existing chat found: ${doc.id}');
          return doc.id;
        }
      }

      debugPrint('[Chat] ⚠️ No existing chat found');
      return null;
    } catch (e) {
      debugPrint('[Chat] ❌ Error checking existing chat: $e');
      return null;
    }
  }

  static Future<String> getOrCreateChatByBuyerSellerProduct({
    required String buyerId,
    required String sellerId,
    required String productId,
  }) async {
    // Buscar chat existente
    final existingChats = await _db.collection('chats')
        .where('product_id', isEqualTo: productId)
        .where('buyer_id', isEqualTo: buyerId)
        .where('seller_id', isEqualTo: sellerId)
        .get();
    
    if (existingChats.docs.isNotEmpty) {
      print('📱 Existing chat found: ${existingChats.docs.first.id}');
      return existingChats.docs.first.id;
    }

    // Crear nuevo chat
    print('📱 Creating new chat for product: $productId');
    final chatData = {
      'buyer_id': buyerId,
      'seller_id': sellerId,
      'product_id': productId,
      'participant_ids': [buyerId, sellerId],
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'last_message': null,
      'unread_count_buyer': 0,
      'unread_count_seller': 0,
    };

    final chatRef = await _db.collection('chats').add(chatData);
    print('Chat created: ${chatRef.id}');
    return chatRef.id;
  }

  // Stream de todos los chats del usuario actual (Scenario 7 - with offline support)
  static Stream<List<ProductChat>> streamUserChats() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

    // Offline mode - return cached chats
    if (!_connectivity.isConnected) {
      debugPrint('[Chat] 📴 Offline mode - loading cached user chats');
      return Stream.fromFuture(_loadCachedUserChats(currentUserId));
    }

    // Online mode - stream from Firestore and cache
    return _db.collection('chats')
        .where('participant_ids', arrayContains: currentUserId)
        .snapshots()
        .asyncMap((snapshot) async {
      print('📱 ChatService.streamUserChats -> docs=${snapshot.docs.length}');

      final futures = snapshot.docs.map((doc) async {
        try {
          final data = doc.data();
          data['id'] = doc.id;
          final chat = Chat.fromJson(data);
          
          print('  ↳ chat=${doc.id} buyer=${chat.buyerId} seller=${chat.sellerId} product=${chat.productId}');
          
          // Validar que los campos no estén vacíos
          if (chat.buyerId.isEmpty || chat.sellerId.isEmpty || chat.productId.isEmpty) {
            print('  ⚠️ Chat ${doc.id} has empty fields, skipping');
            return null;
          }
          
          // Determinar si el usuario actual es comprador o vendedor
          final isBuyer = chat.buyerId == currentUserId;
          final otherUserId = isBuyer ? chat.sellerId : chat.buyerId;
          final unreadCount = isBuyer ? chat.unreadCountBuyer : chat.unreadCountSeller;
          
          // Cargar datos del otro usuario y del producto
          final otherUser = await FirestoreService.getUserById(otherUserId);
          final product = await FirestoreService.getPostById(chat.productId);
          
          if (product == null) {
            print('  ⚠️ Product ${chat.productId} not found for chat ${doc.id}');
            return null;
          }
          
          return ProductChat(
            chatId: doc.id,
            otherUser: otherUser,
            product: product,
            lastMessage: chat.lastMessage,
            updatedAt: chat.updatedAt,
            unreadCount: unreadCount,
            isBuyer: isBuyer,
          );
        } catch (e) {
          print('  ⚠️ Error processing chat ${doc.id}: $e');
          return null;
        }
      }).toList();

      final results = await Future.wait(futures);
      final validChats = results.where((chat) => chat != null).cast<ProductChat>().toList();

      // Ordenar por fecha de actualización
      validChats.sort((a, b) {
        final aTime = a.updatedAt ?? DateTime(2000);
        final bTime = b.updatedAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      // Cache user chats for offline use
      if (validChats.isNotEmpty) {
        await _cacheUserChats(validChats);
      }

      return validChats;
    });
  }

  /// Cache user chats for offline access
  static Future<void> _cacheUserChats(List<ProductChat> chats) async {
    try {
      final chatsJson = chats.map((chat) => {
        'chatId': chat.chatId,
        'otherUser': chat.otherUser.toJson(),
        'product': chat.product.toJson(),
        'lastMessage': chat.lastMessage,
        'updatedAt': chat.updatedAt?.toIso8601String(),
        'unreadCount': chat.unreadCount,
        'isBuyer': chat.isBuyer,
      }).toList();

      await _cache.cacheUserChats(chatsJson);
      debugPrint('[Chat] ✓ Cached ${chats.length} user chats');

      // Also cache individual chat info for each chat so they can be opened offline
      for (final chat in chats) {
        try {
          final currentUserId = _auth.currentUser?.uid;
          if (currentUserId == null) continue;

          // Create chat info structure needed for getChatInfo
          final chatInfoData = {
            'chat': {
              'id': chat.chatId,
              'buyer_id': chat.isBuyer ? currentUserId : chat.otherUser.id,
              'seller_id': chat.isBuyer ? chat.otherUser.id : currentUserId,
              'product_id': chat.product.id,
            },
            'currentUser': (await _cache.getCachedUser(currentUserId)) ??
                          {'id': currentUserId, 'name': 'You', 'email': '', 'major': '',
                           'contact_preferences': 'push', 'role': 'student',
                           'created_at': DateTime.now().toIso8601String()},
            'otherUser': chat.otherUser.toJson(),
            'product': chat.product.toJson(),
            'isBuyer': chat.isBuyer,
          };

          await _cache.cacheChatInfo(chat.chatId, chatInfoData);
          debugPrint('[Chat] ✓ Cached info for chat ${chat.chatId}');
        } catch (e) {
          debugPrint('[Chat] ⚠️ Failed to cache info for chat ${chat.chatId}: $e');
        }
      }
    } catch (e) {
      debugPrint('[Chat] ⚠️ Failed to cache user chats: $e');
    }
  }

  /// Load cached user chats (Scenario 7)
  static Future<List<ProductChat>> _loadCachedUserChats(String currentUserId) async {
    try {
      final cachedChats = await _cache.getCachedUserChats();
      if (cachedChats == null || cachedChats.isEmpty) {
        debugPrint('[Chat] ⚠️ No cached user chats found');
        return [];
      }

      debugPrint('[Chat] ✅ Loading ${cachedChats.length} cached chats');

      final productChats = cachedChats.map((chatJson) {
        try {
          // Parse updatedAt string back to DateTime
          DateTime? updatedAt;
          if (chatJson['updatedAt'] != null) {
            updatedAt = DateTime.parse(chatJson['updatedAt'] as String);
          }

          return ProductChat(
            chatId: chatJson['chatId'] as String,
            otherUser: User.fromJson(chatJson['otherUser'] as Map<String, dynamic>),
            product: Post.fromJson(chatJson['product'] as Map<String, dynamic>),
            lastMessage: chatJson['lastMessage'] as String?,
            updatedAt: updatedAt,
            unreadCount: chatJson['unreadCount'] as int? ?? 0,
            isBuyer: chatJson['isBuyer'] as bool,
          );
        } catch (e) {
          debugPrint('[Chat] ⚠️ Error parsing cached chat: $e');
          return null;
        }
      }).whereType<ProductChat>().toList();

      debugPrint('[Chat] ✅ Successfully loaded ${productChats.length} cached chats');
      return productChats;
    } catch (e) {
      debugPrint('[Chat] ❌ Error loading cached user chats: $e');
      return [];
    }
  }

  // Stream de mensajes de un chat específico (Scenario 7 - with offline support)
  static Stream<List<ChatMessage>> streamChatMessages(String chatId) {
    // Offline mode - use StreamController for reactive updates
    if (!_connectivity.isConnected || chatId.startsWith('offline_')) {
      debugPrint('[Chat] 📴 Offline mode - loading cached messages for $chatId');

      // Create or reuse stream controller for this chat
      if (!_messageControllers.containsKey(chatId)) {
        _messageControllers[chatId] = StreamController<List<ChatMessage>>.broadcast();

        // Load initial cached messages
        _loadCachedMessages(chatId).then((messages) {
          if (_messageControllers.containsKey(chatId) && !_messageControllers[chatId]!.isClosed) {
            _messageControllers[chatId]!.add(messages);
          }
        });
      }

      return _messageControllers[chatId]!.stream;
    }

    // Online mode - stream from Firestore and cache
    return _db.collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sent_at', descending: true)
        .limit(100) // Limit to last 100 messages
        .snapshots()
        .asyncMap((snapshot) async {
      print('📱 ChatService.streamChatMessages($chatId) -> docs=${snapshot.docs.length}');

      final messages = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['_id'] = doc.id;
        print('  ↳ message ${doc.id} sender=${data['sender_id']} content=${data['content']}');
        return ChatMessage.fromJson(data);
      }).toList();

      // Cache messages for offline use
      if (messages.isNotEmpty) {
        final messagesJson = messages.map((m) => {
          'id': m.id,
          'sender_id': m.senderId,
          'content': m.content,
          'image': m.image,
          'sent_at': m.sentAt.toIso8601String(),
          'read': m.read,
        }).toList();
        await _cache.cacheChatMessages(chatId, messagesJson);
      }

      return messages;
    });
  }

  /// Refresh offline message stream after cache update
  static Future<void> _refreshOfflineMessages(String chatId) async {
    if (_messageControllers.containsKey(chatId) && !_messageControllers[chatId]!.isClosed) {
      final messages = await _loadCachedMessages(chatId);
      _messageControllers[chatId]!.add(messages);
      debugPrint('[Chat] 🔄 Refreshed offline messages for $chatId');
    }
  }

  /// Load cached messages including pending ones (Scenario 7 + Scenario 6)
  static Future<List<ChatMessage>> _loadCachedMessages(String chatId) async {
    try {
      final cached = await _cache.getCachedChatMessages(chatId);

      List<ChatMessage> messages = [];

      // Load cached messages from storage
      if (cached != null && cached.isNotEmpty) {
        messages = cached.map((json) {
          // Parse ISO string back to DateTime
          if (json['sent_at'] is String) {
            json['sent_at'] = DateTime.parse(json['sent_at'] as String);
          }
          // Check if message is pending/queued
          final status = json['status'] as String?;
          if (status == 'queued') {
            // This is a pending message - keep it
            return ChatMessage.fromJson(json);
          } else {
            // Regular synced message
            return ChatMessage.fromJson(json);
          }
        }).toList();
      }

      debugPrint('[Chat] ✅ Loaded ${messages.length} cached messages (including pending)');
      return messages;
    } catch (e) {
      debugPrint('[Chat] ❌ Error loading cached messages: $e');
      return [];
    }
  }

  // Obtener información del chat (Scenario 7 - with offline support)
  static Future<Map<String, dynamic>> getChatInfo(String chatId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw StateError('User not authenticated');

    // Offline mode - load from cache
    if (!_connectivity.isConnected || chatId.startsWith('offline_')) {
      debugPrint('[Chat] 📴 Offline mode - loading cached chat info for $chatId');
      return await _loadCachedChatInfo(chatId, currentUserId);
    }

    // Online mode - fetch from Firestore
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) throw StateError('Chat not found');

    final data = chatDoc.data()!;
    data['id'] = chatDoc.id;
    final chat = Chat.fromJson(data);

    // Determinar roles
    final isBuyer = chat.buyerId == currentUserId;
    final otherUserId = isBuyer ? chat.sellerId : chat.buyerId;

    // Cargar datos
    final currentUser = await FirestoreService.getUserById(currentUserId);
    final otherUser = await FirestoreService.getUserById(otherUserId);
    final product = await FirestoreService.getPostById(chat.productId);

    if (product == null) {
      throw StateError('Product not found');
    }

    final result = {
      'chat': chat,
      'currentUser': currentUser,
      'otherUser': otherUser,
      'product': product,
      'isBuyer': isBuyer,
    };

    // Cache chat info for offline use
    await _cacheChatInfoData(chatId, result);

    return result;
  }

  /// Load cached chat info (Scenario 7)
  static Future<Map<String, dynamic>> _loadCachedChatInfo(
      String chatId, String currentUserId) async {
    try {
      final cachedInfo = await _cache.getCachedChatInfo(chatId);
      if (cachedInfo != null) {
        debugPrint('[Chat] ✅ Loaded cached chat info');

        // Convert JSON maps back to model objects
        return {
          'chat': Chat.fromJson(cachedInfo['chat'] as Map<String, dynamic>),
          'currentUser': User.fromJson(cachedInfo['currentUser'] as Map<String, dynamic>),
          'otherUser': User.fromJson(cachedInfo['otherUser'] as Map<String, dynamic>),
          'product': Post.fromJson(cachedInfo['product'] as Map<String, dynamic>),
          'isBuyer': cachedInfo['isBuyer'] as bool,
        };
      }

      // Try to construct from cached product and user data
      debugPrint('[Chat] 🔄 Constructing chat info from cached data...');

      // Extract product ID from offline chat ID if needed
      String productId;
      String? sellerId;
      String? buyerId;

      if (chatId.startsWith('offline_')) {
        // Parse offline chat ID format: offline_timestamp_productId
        final parts = chatId.split('_');
        if (parts.length >= 3) {
          productId = parts.sublist(2).join('_');
        } else {
          throw StateError('Invalid offline chat ID format');
        }

        // Try to get cached offline chat info
        final offlineInfo = await _cache.getCachedChatInfo(chatId);
        if (offlineInfo != null) {
          sellerId = offlineInfo['seller_id'] as String?;
          buyerId = offlineInfo['buyer_id'] as String?;
        }
      } else {
        throw StateError('Chat not found in cache');
      }

      // Load cached product
      final cachedPost = await _cache.getCachedPost(productId);
      if (cachedPost == null) {
        throw StateError('Product not found in cache');
      }

      final product = Post.fromJson(cachedPost);

      // Get cached user data
      final cachedCurrentUser = await _cache.getCachedUser(currentUserId);
      final cachedOtherUser = sellerId != null
          ? await _cache.getCachedUser(sellerId)
          : null;

      final currentUser = cachedCurrentUser != null
          ? User.fromJson(cachedCurrentUser)
          : User(
              id: currentUserId,
              name: 'You',
              email: '',
              major: '',
              contactPreferences: 'push',
              role: 'student',
              createdAt: DateTime.now(),
            );

      final otherUser = cachedOtherUser != null
          ? User.fromJson(cachedOtherUser)
          : User(
              id: sellerId ?? '',
              name: 'Seller',
              email: '',
              major: '',
              contactPreferences: 'push',
              role: 'student',
              createdAt: DateTime.now(),
            );

      return {
        'chat': Chat(
          id: chatId,
          buyerId: buyerId ?? currentUserId,
          sellerId: sellerId ?? product.userId,
          productId: productId,
        ),
        'currentUser': currentUser,
        'otherUser': otherUser,
        'product': product,
        'isBuyer': true,
      };
    } catch (e) {
      debugPrint('[Chat] ❌ Error loading cached chat info: $e');
      rethrow;
    }
  }

  /// Cache chat info data
  static Future<void> _cacheChatInfoData(
      String chatId, Map<String, dynamic> chatInfo) async {
    try {
      // Convert to JSON-serializable format
      final cacheData = {
        'chat': {
          'id': (chatInfo['chat'] as Chat).id,
          'buyer_id': (chatInfo['chat'] as Chat).buyerId,
          'seller_id': (chatInfo['chat'] as Chat).sellerId,
          'product_id': (chatInfo['chat'] as Chat).productId,
        },
        'currentUser': (chatInfo['currentUser'] as User).toJson(),
        'otherUser': (chatInfo['otherUser'] as User).toJson(),
        'product': (chatInfo['product'] as Post).toJson(),
        'isBuyer': chatInfo['isBuyer'],
      };

      await _cache.cacheChatInfo(chatId, cacheData);
    } catch (e) {
      debugPrint('[Chat] ⚠️ Failed to cache chat info: $e');
    }
  }

  // Enviar mensaje (Scenario 6 - with offline queuing)
  static Future<void> sendMessage({
    required String chatId,
    String? text,
    String? imageUrl,
  }) async {
    if (text?.trim().isEmpty ?? true && imageUrl == null) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw StateError('User not authenticated');

    // Scenario 6: Offline mode - queue message
    if (!_connectivity.isConnected) {
      debugPrint('[Chat] 📴 OFFLINE - Queuing message...');

      final messageId = await _syncQueue.queueMessage(
        chatId: chatId,
        senderId: currentUserId,
        content: text?.trim() ?? '',
      );

      // Add message to local cache immediately for optimistic UI
      final localMessage = {
        'id': messageId,
        'sender_id': currentUserId,
        'content': text?.trim(),
        'image': imageUrl,
        'sent_at': DateTime.now().toIso8601String(),
        'read': false,
        'status': 'queued', // Mark as queued
      };

      // Get existing cached messages
      final cachedMessages = await _cache.getCachedChatMessages(chatId) ?? [];
      // Add new message at the beginning (reverse chronological)
      cachedMessages.insert(0, localMessage);
      await _cache.cacheChatMessages(chatId, cachedMessages);

      // Refresh the offline stream to show the new message immediately
      await _refreshOfflineMessages(chatId);

      debugPrint('[Chat] ✅ Message queued and cached locally');
      return;
    }

    // ONLINE mode - send immediately
    print('📱 Sending message in chat $chatId');

    // Obtener información del chat para actualizar contadores
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) throw StateError('Chat not found');

    final chatData = chatDoc.data()!;
    final isBuyer = chatData['buyer_id'] == currentUserId;

    // Crear el mensaje
    final messageData = {
      'sender_id': currentUserId,
      'content': text?.trim(),
      'image': imageUrl,
      'sent_at': FieldValue.serverTimestamp(),
      'read': false,
    };

    // Añadir mensaje a la subcolección
    await _db.collection('chats')
        .doc(chatId)
        .collection('messages')
        .add(messageData);

    // Actualizar el chat
    final updateData = {
      'last_message': text?.trim() ?? '[Imagen]',
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Incrementar contador de no leídos para el receptor
    if (isBuyer) {
      updateData['unread_count_seller'] = FieldValue.increment(1);
    } else {
      updateData['unread_count_buyer'] = FieldValue.increment(1);
    }

    await _db.collection('chats').doc(chatId).update(updateData);
    print('📱 Message sent successfully');
  }

  // Marcar mensajes como leídos
  static Future<void> markMessagesAsRead(String chatId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    print('📱 Marking messages as read in chat $chatId');
    
    // Obtener información del chat
    final chatDoc = await _db.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) return;
    
    final chatData = chatDoc.data()!;
    final isBuyer = chatData['buyer_id'] == currentUserId;
    
    // Resetear contador de no leídos
    final updateData = isBuyer 
        ? {'unread_count_buyer': 0}
        : {'unread_count_seller': 0};
    
    await _db.collection('chats').doc(chatId).update(updateData);
    
    // Marcar mensajes individuales como leídos
    final batch = _db.batch();
    final unreadMessages = await _db.collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('read', isEqualTo: false)
        .where('sender_id', isNotEqualTo: currentUserId)
        .get();

    for (final doc in unreadMessages.docs) {
      batch.update(doc.reference, {'read': true});
    }
    
    await batch.commit();
  }

  // Subir imagen
  static Future<String?> pickAndUploadImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return null;

      final file = File(image.path);
      final fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      
      final uploadTask = await _storage.ref(fileName).putFile(file);
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }
}