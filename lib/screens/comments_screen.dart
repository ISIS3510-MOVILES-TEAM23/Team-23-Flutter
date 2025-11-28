import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../view_models/comments_view_model.dart';
import '../theme/app_colors.dart';
import 'package:timeago/timeago.dart' as timeago;

class CommentsScreen extends StatefulWidget {
  final String productId;

  const CommentsScreen({
    super.key,
    required this.productId,
  });

  @override
  State<CommentsScreen> createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  late CommentsViewModel viewModel;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    viewModel = CommentsViewModel(widget.productId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    final success = await viewModel.addComment(_commentController.text);
    if (success) {
      _commentController.clear();
      if (mounted) {
        FocusScope.of(context).unfocus();
      }
    } else if (viewModel.error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(viewModel.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Comments'),
          actions: [
            // Pending comments indicator
            ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) {
                if (viewModel.pendingCount > 0) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Chip(
                      avatar: const Icon(Icons.cloud_upload, size: 18),
                      label: Text('${viewModel.pendingCount} pending'),
                      backgroundColor: Colors.orange.shade100,
                      labelStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  // Trigger sync when user pulls to refresh
                  await viewModel.syncPendingComments();
                },
                child: StreamBuilder<List<Comment>>(
                  stream: viewModel.commentsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }

                    final comments = snapshot.data ?? [];

                    if (comments.isEmpty) {
                      return const Center(
                        child: Text(
                          'No comments yet. Be the first to comment!',
                          style: TextStyle(color: Colors.grey),
                        ),
                      );
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _CommentItem(
                          comment: comment,
                          onRetry: comment.localId != null && !comment.isSynced
                              ? () => viewModel.retryFailedComment(comment.localId!)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, -2),
            blurRadius: 10,
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: 'Add a comment...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                minLines: 1,
                maxLines: 3,
              ),
            ),
            const SizedBox(width: 8),
            ListenableBuilder(
              listenable: viewModel,
              builder: (context, _) {
                return IconButton(
                  onPressed: viewModel.isLoading ? null : _submitComment,
                  icon: viewModel.isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  color: AppColors.primaryColor,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  final Comment comment;
  final VoidCallback? onRetry;

  const _CommentItem({
    required this.comment,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primaryColor.withOpacity(0.1),
            child: Text(
              comment.userName.isNotEmpty
                  ? comment.userName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: AppColors.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeago.format(comment.createdAt),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sync status indicator
                    if (!comment.isSynced) ...[
                      Icon(
                        Icons.cloud_upload_outlined,
                        size: 14,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pending',
                        style: TextStyle(
                          color: Colors.orange[700],
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.content,
                  style: const TextStyle(fontSize: 14),
                ),
                // Retry button for pending comments
                if (!comment.isSynced && onRetry != null) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
