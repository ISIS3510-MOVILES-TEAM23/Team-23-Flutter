import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'chat_service.dart' show ChatService;

class ChatApi {
  final bool enableLogs;
  ChatApi({this.enableLogs = kDebugMode});

  void _log(String msg) {
    if (enableLogs) {
      // ignore: avoid_print
      print('[ChatApi] $msg');
    }
  }

  Future<String> getOrCreateProductChat(String productId, String sellerId) async {
    final t0 = DateTime.now();
    _log('getOrCreateProductChat(productId=$productId, sellerId=$sellerId)');
    try {
      final r = await ChatService.getOrCreateProductChat(productId, sellerId);
      _log('getOrCreateProductChat -> $r in ${DateTime.now().difference(t0).inMilliseconds}ms');
      return r;
    } catch (e, s) {
      _log('getOrCreateProductChat ERROR: $e\n$s');
      rethrow;
    }
  }

  Stream<List<ProductChat>> streamUserChats() {
    _log('streamUserChats()');
    final t0 = DateTime.now();
    return ChatService.streamUserChats().map((list) {
      _log('streamUserChats -> ${list.length} chats in ${DateTime.now().difference(t0).inMilliseconds}ms');
      return list;
    });
  }

  Stream<List<ChatMessage>> streamChatMessages(String chatId) {
    _log('streamChatMessages(chatId=$chatId)');
    final t0 = DateTime.now();
    return ChatService.streamChatMessages(chatId).map((list) {
      _log('streamChatMessages -> ${list.length} msgs in ${DateTime.now().difference(t0).inMilliseconds}ms');
      return list;
    });
  }

  Future<Map<String, dynamic>> getChatInfo(String chatId) async {
    final t0 = DateTime.now();
    _log('getChatInfo(chatId=$chatId)');
    try {
      final r = await ChatService.getChatInfo(chatId);
      _log('getChatInfo -> ok in ${DateTime.now().difference(t0).inMilliseconds}ms');
      return r;
    } catch (e, s) {
      _log('getChatInfo ERROR: $e\n$s');
      rethrow;
    }
  }

  Future<void> sendMessage({
    required String chatId,
    String? text,
    String? imageUrl,
  }) async {
    final t0 = DateTime.now();
    _log('sendMessage(chatId=$chatId, hasText=${(text??"").isNotEmpty}, hasImage=${imageUrl!=null})');
    try {
      await ChatService.sendMessage(chatId: chatId, text: text, imageUrl: imageUrl);
      _log('sendMessage -> ok in ${DateTime.now().difference(t0).inMilliseconds}ms');
    } catch (e, s) {
      _log('sendMessage ERROR: $e\n$s');
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String chatId) async {
    final t0 = DateTime.now();
    _log('markMessagesAsRead(chatId=$chatId)');
    try {
      await ChatService.markMessagesAsRead(chatId);
      _log('markMessagesAsRead -> ok in ${DateTime.now().difference(t0).inMilliseconds}ms');
    } catch (e, s) {
      _log('markMessagesAsRead ERROR: $e\n$s');
      rethrow;
    }
  }

  Future<String?> pickAndUploadImage() {
    return ChatService.pickAndUploadImage();
  }
}
