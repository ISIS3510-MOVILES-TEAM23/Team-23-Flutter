import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../services/chat_service.dart';
import '../services/storage_service.dart';
import '../services/firestore_service.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;

  const ChatScreen({
    super.key,
    required this.chatId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> messages = [];
  User? currentUser;
  User? otherUser;
  Chat? conversation;
  Post? relatedProduct;
  bool isLoading = true;
  String? uploadedImage; // URL del bucket para este mensaje

  @override
  void initState() {
    super.initState();
    _loadChatData();
  }

  Future<void> _loadChatData() async {
    try {
      final me = await FirestoreService.getCurrentUser();
      if (me == null) throw Exception('Not logged in');

      final conv = await ChatService.fetchChatById(widget.chatId);
      final msgs = await ChatService.fetchChatMessages(widget.chatId);

      final otherUserId = (conv.user1Id == me.id) ? conv.user2Id : conv.user1Id;
      final other = await FirestoreService.getUserById(otherUserId);

      Post? product;
      if (msgs.isNotEmpty && msgs.first.postId != null) {
        final postId = msgs.first.postId!.toString().split('/').last;
        product = await FirestoreService.getPostById(postId);
      }

      setState(() {
        currentUser = me;
        otherUser = other;
        conversation = conv;
        messages = msgs;
        relatedProduct = product;
        isLoading = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (_) {
      setState(() => isLoading = false);
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if ((text.isEmpty) && (uploadedImage == null || uploadedImage!.isEmpty)) {
      return;
    }
    if (currentUser == null || otherUser == null) return;

    // Optimista en UI
    final local = ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser!.id,
      receiverId: otherUser!.id,
      content: text.isNotEmpty ? text : null,
      image: uploadedImage,
      sentAt: DateTime.now(),
      read: false,
    );
    setState(() {
      messages.add(local);
      uploadedImage = null;
    });
    _messageController.clear();
    _scrollToBottom();

    // Persistir
    try {
      await ChatService.sendMessage(
        chatId: widget.chatId,
        content: text.isNotEmpty ? text : null,
        imageUrl: local.image,
        postId: relatedProduct?.id,
      );
    } catch (e) {
      // Revertir si quieres (opcional). Aquí solo notificamos.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo enviar: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // Elegir imagen: galería o cámara → se sube al bucket y guardamos la URL en `uploadedImage`
  void _addImage() {
    if (currentUser == null || otherUser == null) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Elegir de galería'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final url = await StorageService.uploadChatImageFromGallery(
                    senderUid: currentUser!.id,
                    chatId: widget.chatId,
                    receiverUid: otherUser!.id,
                    // Si quieres usar el username en la ruta, pásalo por pathUserSegment
                    // pathUserSegment: currentUser!.name,
                  );
                  if (url != null && mounted) {
                    setState(() => uploadedImage = url);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Tomar foto'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final url = await StorageService.uploadChatImageFromCamera(
                    senderUid: currentUser!.id,
                    chatId: widget.chatId,
                    receiverUid: otherUser!.id,
                    // pathUserSegment: currentUser!.name,
                  );
                  if (url != null && mounted) {
                    setState(() => uploadedImage = url);
                  }
                },
              ),
              const SizedBox(height: 6),
            ],
          ),
        );
      },
    );
  }

  void _removeImage() => setState(() => uploadedImage = null);

  void _initiateNfcTransaction() {
    if (relatedProduct == null) return;

    context.push('/nfc-transaction', extra: {
      'productId': relatedProduct!.id,
      'sellerId': relatedProduct!.userId.split('/').last,
      'buyerId': currentUser?.id ?? '',
      'price': relatedProduct!.price,
      'isSeller': relatedProduct!.userId.contains(currentUser?.id ?? ''),
    });
  }

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isNotEmpty && parts[0].isNotEmpty) {
      return parts[0].substring(0, 2).toUpperCase();
    }
    return 'U';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        title: const Text('Messages'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Header con el otro usuario
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.textSecondary.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                  child: Text(
                    _getInitials(otherUser?.name ?? 'User'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    otherUser?.name ?? 'User',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Producto relacionado (opcional)
          if (relatedProduct != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: relatedProduct!.images.isNotEmpty
                        ? Image.network(
                            relatedProduct!.images.first,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          )
                        : const SizedBox(width: 40, height: 40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          relatedProduct!.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '\$${(relatedProduct!.price / 100).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          if (relatedProduct != null && relatedProduct!.status == 'active')
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: _initiateNfcTransaction,
                icon: const Icon(Icons.nfc, size: 20),
                label: const Text('Complete Transaction'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),

          // Lista de mensajes
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                final isMe = message.senderId == currentUser?.id;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment:
                        isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (!isMe) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              AppColors.primaryColor.withOpacity(0.1),
                          child: Text(
                            _getInitials(otherUser?.name ?? 'U'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Flexible(
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.65,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isMe
                                ? AppColors.backgroundDark
                                : Theme.of(context).cardTheme.color,
                            borderRadius: BorderRadius.only(
                              topLeft: const Radius.circular(16),
                              topRight: const Radius.circular(16),
                              bottomLeft: Radius.circular(isMe ? 16 : 4),
                              bottomRight: Radius.circular(isMe ? 4 : 16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (message.image != null &&
                                  message.image!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      message.image!,
                                      width: 200,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              if (message.content != null &&
                                  message.content!.isNotEmpty)
                                Text(
                                  message.content!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isMe
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Text(
                                _formatTime(message.sentAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMe
                                      ? Colors.white.withOpacity(0.7)
                                      : AppColors.textSecondary
                                          .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              AppColors.primaryColor.withOpacity(0.1),
                          child: Text(
                            _getInitials(currentUser?.name ?? 'Me'),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // Previsualización de imagen (una por mensaje)
          if (uploadedImage != null)
            Container(
              height: 80,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Stack(
                children: [
                  Container(
                    width: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      image: DecorationImage(
                        image: NetworkImage(uploadedImage!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: InkWell(
                      onTap: _removeImage,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Input + adjuntar imagen + enviar
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: Border(
                top: BorderSide(
                  color: AppColors.textSecondary.withOpacity(0.1),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                  onPressed: _addImage,
                ),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
