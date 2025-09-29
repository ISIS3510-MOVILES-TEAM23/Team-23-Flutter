import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../models/models.dart';

class ChatService {
  ChatService._();

  static final _db = FirebaseFirestore.instance;
  static final _auth = auth.FirebaseAuth.instance;

  // Helpers para referencias reales
  static DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection('users').doc(uid);

  static DocumentReference<Map<String, dynamic>> _postRef(String postId) =>
      _db.collection('posts').doc(postId);

static Future<List<Chat>> fetchUserChats(String uid) async {
  // Referencia del usuario actual
  final myRef = _db.collection('users').doc(uid);

  // Trae los chats donde el usuario es user_1_ref o user_2_ref
  final res = await Future.wait([
    _db.collection('chats').where('user_1_ref', isEqualTo: myRef).get(),
    _db.collection('chats').where('user_2_ref', isEqualTo: myRef).get(),
  ]);

  final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[
    ...res[0].docs,
    ...res[1].docs,
  ];

  final chats = <Chat>[];

  // Para cada chat, obtenemos el último mensaje (si existe) para mostrar en la lista
  for (final d in docs) {
    ChatMessage? last;

    final lastSnap = await _db
        .collection('chats')
        .doc(d.id)
        .collection('messages')
        .orderBy('sent_at', descending: true)
        .limit(1)
        .get();

    if (lastSnap.docs.isNotEmpty) {
      final m = lastSnap.docs.first;
      final md = m.data();

      final senderRef = md['sender_ref'];
      final receiverRef = md['receiver_ref'];
      final postRef = md['post_ref'];
      final ts = md['sent_at'];

      last = ChatMessage(
        id: m.id,
        senderId: senderRef is DocumentReference ? senderRef.id : (senderRef?.toString().split('/').last ?? ''),
        receiverId: receiverRef is DocumentReference ? receiverRef.id : (receiverRef?.toString().split('/').last ?? ''),
        content: (md['content'] as String?)?.trim(),
        image: md['image'] as String?,
        // Guarda ruta completa o solo id, como prefieras:
        postId: postRef is DocumentReference ? postRef.path : (postRef?.toString()),
        sentAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
        read: (md['read'] as bool?) ?? false,
      );
    }

    final data = d.data();
    final u1Ref = data['user_1_ref'];
    final u2Ref = data['user_2_ref'];

    final u1 = u1Ref is DocumentReference ? u1Ref.id : (u1Ref?.toString().split('/').last ?? '');
    final u2 = u2Ref is DocumentReference ? u2Ref.id : (u2Ref?.toString().split('/').last ?? '');

    chats.add(
      Chat(
        id: d.id,
        user1Id: u1,
        user2Id: u2,
        // tu modelo usa 'messages1' como lista; metemos solo el último para la vista de lista
        messages1: last != null ? [last] : const [],
      ),
    );
  }

  // Ordena por el último mensaje (más reciente primero)
  chats.sort((a, b) {
    final aTs = a.messages1.isNotEmpty ? a.messages1.first.sentAt : DateTime.fromMillisecondsSinceEpoch(0);
    final bTs = b.messages1.isNotEmpty ? b.messages1.first.sentAt : DateTime.fromMillisecondsSinceEpoch(0);
    return bTs.compareTo(aTs);
  });

  return chats;
}

  /// Crea el chat si no existe y devuelve el chatId
  static Future<String> startChatIfNeeded({
    required String otherUserId,
    String? postId,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw Exception('Not logged in');

    final myRef = _userRef(me.uid);
    final theirRef = _userRef(otherUserId);

    // Busca en ambos órdenes
    final q1 = await _db
        .collection('chats')
        .where('user_1_ref', isEqualTo: myRef)
        .where('user_2_ref', isEqualTo: theirRef)
        .limit(1)
        .get();
    if (q1.docs.isNotEmpty) return q1.docs.first.id;

    final q2 = await _db
        .collection('chats')
        .where('user_1_ref', isEqualTo: theirRef)
        .where('user_2_ref', isEqualTo: myRef)
        .limit(1)
        .get();
    if (q2.docs.isNotEmpty) return q2.docs.first.id;

    // No existe: créalo
    final chatId = _db.collection('chats').doc().id;
    await _db.collection('chats').doc(chatId).set({
      'user_1_ref': myRef,
      'user_2_ref': theirRef,
      'updated_at': FieldValue.serverTimestamp(),
      if (postId != null && postId.isNotEmpty) 'post_ref': _postRef(postId),
    });
    return chatId;
  }

  /// Cargar un chat por id (convierte refs a ids para tu modelo)
  static Future<Chat> fetchChatById(String chatId) async {
    final d = await _db.collection('chats').doc(chatId).get();
    if (!d.exists) throw Exception('Chat not found');

    final data = d.data()!;
    final u1 = (data['user_1_ref'] as DocumentReference).id;
    final u2 = (data['user_2_ref'] as DocumentReference).id;

    return Chat(
      id: d.id,
      user1Id: u1,
      user2Id: u2,
      messages1: const [],
    );
  }

  /// Mensajes de un chat (ordenados por sent_at)
  static Future<List<ChatMessage>> fetchChatMessages(String chatId) async {
    final snap = await _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sent_at')
        .get();

    return snap.docs.map((m) {
      final md = m.data();
      final senderRef = md['sender_ref'] as DocumentReference?;
      final receiverRef = md['receiver_ref'] as DocumentReference?;
      final postRef = md['post_ref'] as DocumentReference?;
      final ts = md['sent_at'];

      return ChatMessage(
        id: m.id,
        senderId: senderRef?.id ?? '',
        receiverId: receiverRef?.id ?? '',
        content: (md['content'] as String?)?.trim(),
        image: md['image'] as String?,
        postId: postRef?.path, // o postRef?.id si prefieres solo el id
        sentAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
        read: (md['read'] as bool?) ?? false,
      );
    }).toList();
  }

  /// Enviar mensaje (texto y/o imagen). Guarda referencias reales.
  static Future<void> sendMessage({
    required String chatId,
    String? content,
    String? imageUrl,
    String? postId,
  }) async {
    final me = _auth.currentUser;
    if (me == null) throw Exception('Not logged in');

    final chat = await _db.collection('chats').doc(chatId).get();
    if (!chat.exists) throw Exception('Chat not found');

    final data = chat.data()!;
    final user1Ref = data['user_1_ref'] as DocumentReference;
    final user2Ref = data['user_2_ref'] as DocumentReference;

    final myRef = _userRef(me.uid);
    final otherRef = (myRef.path == user1Ref.path) ? user2Ref : user1Ref;

    // No permitimos mensajes vacíos
    final hasText = content != null && content.trim().isNotEmpty;
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;
    if (!hasText && !hasImage) return;

    final msg = <String, dynamic>{
      'sender_ref': myRef,
      'receiver_ref': otherRef,
      'sent_at': FieldValue.serverTimestamp(),
      'read': false,
      if (hasText) 'content': content!.trim(),
      if (hasImage) 'image': imageUrl,
      if (postId != null && postId.isNotEmpty) 'post_ref': _postRef(postId),
    };

    await _db.collection('chats').doc(chatId).collection('messages').add(msg);

    await _db.collection('chats').doc(chatId).update({
      'updated_at': FieldValue.serverTimestamp(),
    });
  }
}
