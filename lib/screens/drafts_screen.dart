import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../models/models.dart';
import '../services/draft_service.dart';
import '../services/draft_upload_service.dart'; // Scenario 8: Manual post
import '../services/connectivity_service.dart'; // Scenario 8: Check connection
import '../theme/app_colors.dart';
import 'dart:io';

/// Screen to display and manage draft posts (Scenario 8)
class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  final DraftService _draftService = DraftService();
  final DraftUploadService _uploadService = DraftUploadService();
  final ConnectivityService _connectivity = ConnectivityService();
  List<DraftPost> _drafts = [];
  bool _isLoading = true;
  String? _postingDraftId; // Track which draft is being posted

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    try {
      setState(() => _isLoading = true);

      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final drafts = await _draftService.getUserDrafts(currentUser.uid);

      setState(() {
        _drafts = drafts;
        _isLoading = false;
      });

      debugPrint('[DraftsScreen] ✓ Loaded ${drafts.length} drafts');
    } catch (e) {
      debugPrint('[DraftsScreen] ❌ Failed to load drafts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteDraft(DraftPost draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft'),
        content: Text('Delete "${draft.title.isEmpty ? "Untitled" : draft.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _draftService.deleteDraft(draft.draftId);
        await _loadDrafts();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Draft deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete draft: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  String _getStatusText(DraftStatus status) {
    switch (status) {
      case DraftStatus.editing:
        return 'Editing';
      case DraftStatus.pendingUpload:
        return 'Pending Upload';
      case DraftStatus.uploading:
        return 'Uploading...';
      case DraftStatus.failed:
        return 'Upload Failed';
    }
  }

  Color _getStatusColor(DraftStatus status) {
    switch (status) {
      case DraftStatus.editing:
        return Colors.blue;
      case DraftStatus.pendingUpload:
        return Colors.orange;
      case DraftStatus.uploading:
        return Colors.green;
      case DraftStatus.failed:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drafts'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadDrafts,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _drafts.length,
                    itemBuilder: (context, index) {
                      final draft = _drafts[index];
                      return _buildDraftCard(draft);
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.drafts_outlined,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No drafts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a post offline to save it as draft',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(DraftPost draft) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to edit draft
          debugPrint('Edit draft: ${draft.draftId}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image preview
              if (draft.localImagePaths.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(draft.localImagePaths.first),
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image_not_supported),
                      );
                    },
                  ),
                )
              else
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image_outlined, size: 32),
                ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      draft.title.isEmpty ? 'Untitled Draft' : draft.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Price
                    if (draft.price > 0)
                      Text(
                        '\$${draft.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    const SizedBox(height: 4),
                    // Category
                    if (draft.categoryName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          draft.categoryName!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Status and date
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(draft.status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _getStatusText(draft.status),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: _getStatusColor(draft.status),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(draft.lastModified),
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Actions
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Post Draft Button
                  ElevatedButton.icon(
                    onPressed: _postingDraftId == draft.draftId
                        ? null
                        : () => _postDraft(draft),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: _postingDraftId == draft.draftId
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.cloud_upload, size: 18),
                    label: Text(
                      _postingDraftId == draft.draftId ? 'Posting...' : 'Post Draft',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Delete Button
                  TextButton.icon(
                    onPressed: () => _deleteDraft(draft),
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text(
                      'Delete',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Post draft to Firestore (manual sync)
  Future<void> _postDraft(DraftPost draft) async {
    // Check internet connection
    if (!_connectivity.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No internet connection. Please connect to post draft.'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Confirm before posting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Post Draft?'),
        content: Text('Are you sure you want to post "${draft.title.isEmpty ? "Untitled" : draft.title}"? This will publish it to the marketplace.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
            child: const Text('Post'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _postingDraftId = draft.draftId;
    });

    try {
      final success = await _uploadService.postDraft(draft.draftId);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Draft posted successfully!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Reload drafts list
        await _loadDrafts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to post draft: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _postingDraftId = null;
        });
      }
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

