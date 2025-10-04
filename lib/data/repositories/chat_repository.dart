import '../../models/models.dart';
import '../../services/chat_api.dart';
import '../../services/chat_service.dart';

class ChatRepository {
  final ChatApi _chatApi;

  ChatRepository({ChatApi? chatApi}) : _chatApi = chatApi ?? ChatApi();

  // Get or create product chat
  Future<String> getOrCreateProductChat(
    String productId,
    String sellerId,
  ) async {
    return await _chatApi.getOrCreateProductChat(productId, sellerId);
  }

  // Get chat info
  Future<Map<String, dynamic>> getChatInfo(String chatId) async {
    return await _chatApi.getChatInfo(chatId);
  }

  // Stream chat messages
  Stream<List<ChatMessage>> streamChatMessages(String chatId) {
    return _chatApi.streamChatMessages(chatId);
  }

  // Send message
  Future<void> sendMessage({
    required String chatId,
    required String text,
    String? imageUrl,
  }) async {
    await _chatApi.sendMessage(
      chatId: chatId,
      text: text,
      imageUrl: imageUrl,
    );
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    await _chatApi.markMessagesAsRead(chatId);
  }

  // Get or create chat by buyer, seller, and product
  Future<String> getOrCreateChatByBuyerSellerProduct({
    required String buyerId,
    required String sellerId,
    required String productId,
  }) async {
    return await ChatService.getOrCreateChatByBuyerSellerProduct(
      buyerId: buyerId,
      sellerId: sellerId,
      productId: productId,
    );
  }
}

