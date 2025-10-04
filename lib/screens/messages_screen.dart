import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_shimmer.dart';
import '../view_models/messages_view_model.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  late MessagesViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = MessagesViewModel();
    viewModel.loadChats();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        final isEmpty = viewModel.buyersChats.isEmpty && viewModel.sellersChats.isEmpty;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Messages'),
            centerTitle: true,
          ),
          body: RefreshIndicator(
            onRefresh: viewModel.refresh,
            child: viewModel.isLoading
                ? const LoadingShimmer(width: double.infinity, height: 300)
                : isEmpty
                    ? _buildEmptyState(context)
                    : ListView(
                        children: [
                          if (viewModel.buyersChats.isNotEmpty) ...[
                            _buildSectionHeader('Buyers'),
                            ...viewModel.buyersChats.map(_buildChatTile),
                            const SizedBox(height: 12),
                          ],
                          if (viewModel.sellersChats.isNotEmpty) ...[
                            _buildSectionHeader('Sellers'),
                            ...viewModel.sellersChats.map(_buildChatTile),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No conversations yet',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Start a conversation from a product',
                style: TextStyle(fontSize: 14, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile(chat) {
    return InkWell(
      onTap: () {
        context.push(
          '/chat',
          extra: {
            'chatId': chat.chatId,
            'productId': chat.product.id,
            'sellerId': chat.isBuyer ? chat.otherUser.id : '',
          },
        ).then((_) {
          // Recargar al volver, por si cambian contadores de unread
          viewModel.loadChats();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: Row(
          children: [
            // Avatar con imagen del producto
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: chat.product.images.isNotEmpty
                      ? NetworkImage(chat.product.images.first)
                      : null,
                  backgroundColor: Colors.grey[300],
                  child: chat.product.images.isEmpty
                      ? const Icon(Icons.shopping_bag, color: Colors.white)
                      : null,
                ),
                // Badge de no leídos
                if (chat.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 20, minHeight: 20),
                      child: Text(
                        chat.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Info del chat
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del otro usuario + hora
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          chat.otherUser.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.updatedAt != null)
                        Text(
                          viewModel.formatTime(chat.updatedAt!),
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Título del producto
                  Text(
                    chat.product.title,
                    style: const TextStyle(
                      color: AppColors.primaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Último mensaje + precio
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage ?? 'No messages yet',
                          style: TextStyle(
                            color: chat.unreadCount > 0
                                ? Colors.black87
                                : Colors.grey[600],
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '\$${chat.product.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
