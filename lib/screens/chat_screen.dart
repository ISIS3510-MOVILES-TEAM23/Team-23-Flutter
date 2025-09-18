import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../services/mock_service.dart';
import '../theme/app_colors.dart';

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
  String? uploadedImage;

  @override
  void initState() {
    super.initState();
    _loadChatData();
  }

  Future<void> _loadChatData() async {
    try {
      // Load current user
      final user = await MockService.getCurrentUser();
      
      // Load conversation
      final convs = await MockService.getUserChats('u_current');
      final conv = convs.firstWhere((c) => c.id == widget.chatId);
      
      // Load messages
      final chatMessages = await MockService.getChatMessages(widget.chatId);
      
      // Get other user info
      String otherUserId = conv.user1Id == 'u_current' 
          ? conv.user2Id 
          : conv.user1Id;
      
      final other = await MockService.getUserById('user/$otherUserId');
      
      // Try to load related product if exists
      Post? product;
      if (chatMessages.isNotEmpty && chatMessages.first.postId != null) {
        product = await MockService.getPostById(chatMessages.first.postId!.split('/').last);
      }
      
      setState(() {
        currentUser = user;
        otherUser = other;
        conversation = conv;
        messages = chatMessages;
        relatedProduct = product;
        isLoading = false;
      });
      
      // Scroll to bottom after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
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
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty && uploadedImage == null) return;
    
    // Create new message locally
    final newMessage = ChatMessage(
      id: 'm_${DateTime.now().millisecondsSinceEpoch}',
      senderId: currentUser?.id ?? 'u_current',
      receiverId: otherUser?.id ?? '',
      content: messageText.isNotEmpty ? messageText : null,
      image: uploadedImage,
      sentAt: DateTime.now(),
      read: false,
    );
    
    setState(() {
      messages.add(newMessage);
      uploadedImage = null;
    });
    
    _messageController.clear();
    _scrollToBottom();
    
    // Send to backend
    await MockService.sendMessage(widget.chatId, messageText);
  }

  void _addImage() {
    // Simulate image selection - only one image allowed per message
    setState(() {
      uploadedImage = 'https://picsum.photos/seed/${DateTime.now().millisecondsSinceEpoch}/400/400';
    });
  }

  void _removeImage() {
    setState(() {
      uploadedImage = null;
    });
  }

  void _initiateNfcTransaction() {
    if (relatedProduct == null) return;
    
    context.push('/nfc-transaction', extra: {
      'productId': relatedProduct!.id,
      'sellerId': relatedProduct!.userId.split('/').last,
      'buyerId': currentUser?.id ?? 'u_current',
      'price': relatedProduct!.price,
      'isSeller': relatedProduct!.userId.contains(currentUser?.id ?? 'u_current'),
    });
  }

  String _formatTime(DateTime timestamp) {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getInitials(String name) {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
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
          // User info header with profile picture and name
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
                // Profile picture
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
                // Name only (removed status)
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
          
          // Related product (if exists)
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
                    child: Image.network(
                      relatedProduct!.images.isNotEmpty 
                          ? relatedProduct!.images.first 
                          : 'https://picsum.photos/seed/product/50/50',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    ),
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
          
          // NFC Transaction Button (NEW)
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
          
          // Messages list with profile pictures
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
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Other user's profile picture on the left
                      if (!isMe) ...[
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryColor.withOpacity(0.1),
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
                      
                      // Message bubble
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
                                ? AppColors.primaryColor 
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
                              // Image if any
                              if (message.image != null && message.image!.isNotEmpty)
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
                              
                              // Message text
                              if (message.content != null && message.content!.isNotEmpty)
                                Text(
                                  message.content!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: isMe ? Colors.white : AppColors.textPrimary,
                                  ),
                                ),
                              
                              const SizedBox(height: 4),
                              
                              // Time
                              Text(
                                _formatTime(message.sentAt),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMe 
                                      ? Colors.white.withOpacity(0.7)
                                      : AppColors.textSecondary.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // My profile picture on the right
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryColor.withOpacity(0.1),
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
          
          // Image preview (only one image allowed)
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
          
          // Input field with image button
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
                // Add image button
                IconButton(
                  icon: Icon(
                    Icons.add_photo_alternate_outlined,
                    color: AppColors.textSecondary.withOpacity(0.6),
                  ),
                  onPressed: _addImage,
                ),
                
                // Message input
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
                
                // Send button
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