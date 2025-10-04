import 'dart:async';
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../data/repositories/chat_repository.dart';

class ChatViewModel extends ChangeNotifier {
  final ChatRepository _chatRepository;

  ChatViewModel({ChatRepository? chatRepository})
      : _chatRepository = chatRepository ?? ChatRepository();

  final TextEditingController messageController = TextEditingController();

  StreamSubscription<List<ChatMessage>>? _messagesSub;
  List<ChatMessage> messages = [];
  User? currentUser;
  User? otherUser;
  Post? product;
  bool isLoading = true;
  bool isBuyer = true;
  String? chatId;

  Future<void> initializeChat(
    String initialChatId,
    String productId,
    String sellerId,
  ) async {
    try {
      isLoading = true;
      notifyListeners();

      // Si no tenemos chatId, crearlo o obtenerlo
      if (initialChatId.isEmpty) {
        chatId = await _chatRepository.getOrCreateProductChat(
          productId,
          sellerId,
        );
      } else {
        chatId = initialChatId;
      }

      // Cargar información del chat
      final chatInfo = await _chatRepository.getChatInfo(chatId!);

      currentUser = chatInfo['currentUser'];
      otherUser = chatInfo['otherUser'];
      product = chatInfo['product'];
      isBuyer = chatInfo['isBuyer'];
      isLoading = false;
      notifyListeners();

      // Suscribirse a los mensajes
      _messagesSub = _chatRepository.streamChatMessages(chatId!).listen((msgs) {
        messages = msgs;
        notifyListeners();
      });

      // Marcar mensajes como leídos
      _chatRepository.markMessagesAsRead(chatId!);
    } catch (e) {
      isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> sendMessage() async {
    final text = messageController.text.trim();
    if (text.isEmpty || chatId == null) return;

    messageController.clear();

    try {
      await _chatRepository.sendMessage(
        chatId: chatId!,
        text: text,
      );
    } catch (e) {
      rethrow;
    }
  }

  String formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}';
    } else {
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
  }

  @override
  void dispose() {
    _messagesSub?.cancel();
    messageController.dispose();
    super.dispose();
  }
}

