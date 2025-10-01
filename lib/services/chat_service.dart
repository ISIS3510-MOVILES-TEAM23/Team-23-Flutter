import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../models/models.dart';
import 'firestore_service.dart';

class ChatService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static final ImagePicker _picker = ImagePicker();
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  // Obtener o crear un chat para un producto
  static Future<String> getOrCreateProductChat(String productId, String sellerId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw StateError('User not authenticated');
    
    // You can't chat with yourself
    if (currentUserId == sellerId) {
      throw StateError('You cannot chat with yourself');
    }

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

  // Stream de todos los chats del usuario actual
  static Stream<List<ProductChat>> streamUserChats() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value([]);
    }

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
      
      return validChats;
    });
  }

  // Stream de mensajes de un chat específico
  static Stream<List<ChatMessage>> streamChatMessages(String chatId) {
    return _db.collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sent_at', descending: true)
        .snapshots()
        .map((snapshot) {
      print('📱 ChatService.streamChatMessages($chatId) -> docs=${snapshot.docs.length}');
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['_id'] = doc.id;
        print('  ↳ message ${doc.id} sender=${data['sender_id']} content=${data['content']}');
        return ChatMessage.fromJson(data);
      }).toList();
    });
  }

  // Obtener información del chat
  static Future<Map<String, dynamic>> getChatInfo(String chatId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw StateError('User not authenticated');

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

    return {
      'chat': chat,
      'currentUser': currentUser,
      'otherUser': otherUser,
      'product': product,
      'isBuyer': isBuyer,
    };
  }

  // Enviar mensaje
  static Future<void> sendMessage({
    required String chatId,
    String? text,
    String? imageUrl,
  }) async {
    if (text?.trim().isEmpty ?? true && imageUrl == null) return;

    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) throw StateError('User not authenticated');

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