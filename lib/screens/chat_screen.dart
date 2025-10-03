import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../view_models/chat_view_model.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String productId;
  final String sellerId;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.productId,
    required this.sellerId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  late ChatViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = ChatViewModel();
    viewModel.initializeChat(widget.chatId, widget.productId, widget.sellerId);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        if (viewModel.isLoading) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Loading...'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewModel.otherUser?.name ?? 'Chat',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  viewModel.isBuyer ? 'Seller' : 'Buyer',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                ),
              ],
            ),
            actions: [
              // Mostrar miniatura del producto
              if (viewModel.product != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      if (viewModel.product!.images.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            viewModel.product!.images.first,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${viewModel.product!.price.toStringAsFixed(0)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          body: Column(
            children: [
              // Información del producto
              if (viewModel.product != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      if (viewModel.product!.images.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            viewModel.product!.images.first,
                            width: 60,
                            height: 60,
                            fit: BoxFit.cover,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              viewModel.product!.title,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '\$${viewModel.product!.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // Lista de mensajes
              Expanded(
                child: viewModel.messages.isEmpty
                    ? Center(
                        child: Text(
                          'Start a conversation about ${viewModel.product?.title ?? "this product"}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: viewModel.messages.length,
                        itemBuilder: (context, index) {
                          final message = viewModel.messages[index];
                          final isMe = message.senderId == viewModel.currentUser?.id;
                          
                          return _buildMessageBubble(message, isMe);
                        },
                      ),
              ),
              // Input de mensaje
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: viewModel.messageController,
                          decoration: InputDecoration(
                            hintText: 'Write a message...',
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => viewModel.sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleAvatar(
                        backgroundColor: AppColors.primaryColor,
                        child: IconButton(
                          icon: const Icon(Icons.send, color: Colors.white),
                          onPressed: viewModel.sendMessage,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(message, bool isMe) {
    final messageUser = isMe ? viewModel.currentUser : viewModel.otherUser;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  'https://picsum.photos/seed/${messageUser?.id ?? 'user'}/100/100',
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Nombre del usuario
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      messageUser?.name ?? 'User',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  // Burbuja del mensaje
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppColors.deepNavy : Colors.grey[200],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.image != null) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              message.image!,
                              fit: BoxFit.cover,
                              loadingBuilder: (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: 200,
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                );
                              },
                            ),
                          ),
                          if (message.content != null) const SizedBox(height: 8),
                        ],
                        if (message.content != null)
                          Text(
                            message.content!,
                            style: TextStyle(
                              color: isMe ? Colors.white : Colors.black87,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          viewModel.formatTime(message.sentAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isMe ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 20,
                backgroundImage: NetworkImage(
                  'https://picsum.photos/seed/${messageUser?.id ?? 'user'}/100/100',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
