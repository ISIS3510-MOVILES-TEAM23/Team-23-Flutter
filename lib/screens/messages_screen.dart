import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/models.dart' show ProductChat;
import '../services/chat_api.dart';
import '../theme/app_colors.dart';
import '../widgets/loading_shimmer.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final ChatApi _chat = ChatApi();

  StreamSubscription<List<ProductChat>>? _subscription;
  bool _isLoading = true;

  // Dos listas separadas:
  List<ProductChat> _buyersChats = [];  // Tú eres seller (otros = buyers)
  List<ProductChat> _sellersChats = []; // Tú eres buyer  (otros = sellers)

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadChats() async {
    setState(() => _isLoading = true);

    _subscription?.cancel();
    _subscription = _chat.streamUserChats().listen(
      (chats) {
        // Particionamos por rol del usuario actual en cada chat
        final buyers = <ProductChat>[];
        final sellers = <ProductChat>[];

        for (final c in chats) {
          if (c.isBuyer) {
            // tú eres buyer => sección "Sellers"
            sellers.add(c);
          } else {
            // tú eres seller => sección "Buyers"
            buyers.add(c);
          }
        }

        // Ordenamos cada sección por updatedAt desc (por si acaso)
        int _cmp(ProductChat a, ProductChat b) {
          final aTime = a.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bTime = b.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bTime.compareTo(aTime);
        }
        buyers.sort(_cmp);
        sellers.sort(_cmp);

        if (mounted) {
          setState(() {
            _buyersChats = buyers;
            _sellersChats = sellers;
            _isLoading = false;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      },
    );
  }

  Future<void> _refresh() async {
    _loadChats();
  }

  @override
  Widget build(BuildContext context) {
    final isEmpty = _buyersChats.isEmpty && _sellersChats.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _isLoading
            ? const LoadingShimmer(width: double.infinity, height: 300)
            : isEmpty
                ? _buildEmptyState(context)
                : ListView(
                    children: [
                      if (_buyersChats.isNotEmpty) ...[
                        _buildSectionHeader('Buyers'),
                        ..._buyersChats.map(_buildChatTile),
                        const SizedBox(height: 12),
                      ],
                      if (_sellersChats.isNotEmpty) ...[
                        _buildSectionHeader('Sellers'),
                        ..._sellersChats.map(_buildChatTile),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
      ),
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

  Widget _buildChatTile(ProductChat chat) {
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
          _loadChats();
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
                          _formatTime(chat.updatedAt!),
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) return '${dateTime.year}';
    if (difference.inDays > 30) return '${dateTime.day}/${dateTime.month}';
    if (difference.inDays > 0) return '${difference.inDays}d';
    if (difference.inHours > 0) return '${difference.inHours}h';
    if (difference.inMinutes > 0) return '${difference.inMinutes}m';
    return 'Ahora';
  }
}
