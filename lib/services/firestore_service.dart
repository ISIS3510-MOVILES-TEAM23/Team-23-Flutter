import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/models.dart';

class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;

  static Future<List<Post>> getHighlightedPosts() async {
    final snapshot = await _db
        .collection('posts')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(4)
        .get();
    return snapshot.docs.map((doc) => Post.fromJson(doc.data()..['id'] = doc.id)).toList();
  }

  static Future<List<Post>> getNewPosts() async {
    final snapshot = await _db
        .collection('posts')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(5)
        .get();
    return snapshot.docs.map((doc) => Post.fromJson(doc.data()..['id'] = doc.id)).toList();
  }

  static Future<List<Category>> getCategories() async {
    final snapshot = await _db.collection('categories').get();
    return snapshot.docs.map((doc) => Category.fromJson(doc.data()..['id'] = doc.id)).toList();
  }

  static Future<List<Post>> getPostsByCategory(String categoryId, {FilterOptions? filters}) async {
    Query query = _db
        .collection('posts')
        .where('subCategoryId', isGreaterThanOrEqualTo: 'category/$categoryId')
        .where('subCategoryId', isLessThan: 'category/$categoryId' + 'z');

    if (filters != null) {
      if (filters.minPrice != null) {
        query = query.where('price', isGreaterThanOrEqualTo: (filters.minPrice! * 100).round());
      }
      if (filters.maxPrice != null) {
        query = query.where('price', isLessThanOrEqualTo: (filters.maxPrice! * 100).round());
      }
      if (filters.sortBy != null) {
        switch (filters.sortBy) {
          case 'price_low':
            query = query.orderBy('price');
            break;
          case 'price_high':
            query = query.orderBy('price', descending: true);
            break;
          case 'newest':
            query = query.orderBy('createdAt', descending: true);
            break;
        }
      }
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Post.fromJson(doc.data() as Map<String, dynamic>..['id'] = doc.id)).toList();
  }

  static Future<Post?> getPostById(String postId) async {
    final doc = await _db.collection('posts').doc(postId).get();
    if (!doc.exists) return null;
    return Post.fromJson(doc.data()!..['id'] = doc.id);
  }

  static Future<User?> getCurrentUser() async {
    //TODO: Change this to use the auth service
/*     final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return getUserById(firebaseUser.uid); */
    const userId = 'u123';
    final doc = await _db.collection('users').doc(userId).get();
    return User.fromJson(doc.data()!..['id'] = doc.id);
  }

  static Future<User> getUserById(String userId) async {
    final doc = await _db.collection('users').doc(userId).get();
    return User.fromJson(doc.data()!..['id'] = doc.id);
  }

  static Future<List<Post>> getUserPosts(String userId) async {
    final snapshot = await _db.collection('posts').where('userId', isEqualTo: 'user/$userId').get();
    return snapshot.docs.map((doc) => Post.fromJson(doc.data()..['id'] = doc.id)).toList();
  }

  static Future<List<Post>> getUserPurchases(String userId) async {
    final salesSnapshot = await _db.collection('sales').where('buyerId', isEqualTo: 'user/$userId').get();
    final postIds = salesSnapshot.docs.map((doc) => doc.data()['postId'].split('/').last).toList();
    if (postIds.isEmpty) return [];
    
    final postsSnapshot = await _db.collection('posts').where(FieldPath.documentId, whereIn: postIds).get();
    return postsSnapshot.docs.map((doc) => Post.fromJson(doc.data()..['id'] = doc.id)).toList();
  }

  static Future<List<Post>> getUserFavorites(String userId) async {
    final snapshot = await _db.collection('users').doc(userId).collection('favorites').get();
    final postIds = snapshot.docs.map((doc) => doc.id).toList();
    if (postIds.isEmpty) return [];

    final postsSnapshot = await _db.collection('posts').where(FieldPath.documentId, whereIn: postIds).get();
    return postsSnapshot.docs.map((doc) => Post.fromJson(doc.data()..['id'] = doc.id)).toList();
  }

  static Future<List<Chat>> getUserChats(String userId) async {
    final query1 = _db.collection('chats').where('user1Id', isEqualTo: userId).get();
    final query2 = _db.collection('chats').where('user2Id', isEqualTo: userId).get();
    
    final results = await Future.wait([query1, query2]);
    final chats = results[0].docs.map((doc) => Chat.fromJson(doc.data()..['id'] = doc.id)).toList();
    chats.addAll(results[1].docs.map((doc) => Chat.fromJson(doc.data()..['id'] = doc.id)).toList());

    return chats;
  }

  static Future<List<ChatMessage>> getChatMessages(String chatId) async {
    final snapshot = await _db.collection('chats').doc(chatId).collection('messages').orderBy('sentAt').get();
    return snapshot.docs.map((doc) => ChatMessage.fromJson(doc.data()..['id'] = doc.id)).toList();
  }

  static Future<bool> createPost(Map<String, dynamic> postData) async {
    try {
      await _db.collection('posts').add(postData);
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
      
      final otherUserId = chatDoc.data()!['user1Id'] == currentUser.uid ? chatDoc.data()!['user2Id'] : chatDoc.data()!['user1Id'];

      await _db.collection('chats').doc(chatId).collection('messages').add({
        'senderId': currentUser.uid,
        'receiverId': otherUserId,
        'content': content,
        'sentAt': FieldValue.serverTimestamp(),
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

      // Check if a chat already exists
      final existingChat = await _db
          .collection('chats')
          .where('user1Id', whereIn: [currentUser.uid, otherUserId])
          .get();
          
      for (var doc in existingChat.docs) {
        if (doc.data()['user2Id'] == otherUserId || doc.data()['user2Id'] == currentUser.uid) {
           return doc.id;
        }
      }

      final newChat = await _db.collection('chats').add({
        'user1Id': currentUser.uid,
        'user2Id': otherUserId,
        'messages_1': [],
      });
      return newChat.id;
    } catch (e) {
      print(e);
      return '';
    }
  }
}
