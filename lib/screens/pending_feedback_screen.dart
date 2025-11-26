import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/draft_feedback_service.dart';
import '../services/feedback_upload_service.dart';
import '../services/connectivity_service.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import '../theme/app_colors.dart';
import 'feedback_form_screen.dart';

/// Screen to view and manage pending feedback drafts
/// Allows users to upload pending feedback when online
class PendingFeedbackScreen extends StatefulWidget {
  const PendingFeedbackScreen({super.key});

  @override
  State<PendingFeedbackScreen> createState() => _PendingFeedbackScreenState();
}

class _PendingFeedbackScreenState extends State<PendingFeedbackScreen> {
  final DraftFeedbackService _draftService = DraftFeedbackService();
  final FeedbackUploadService _uploadService = FeedbackUploadService();
  final ConnectivityService _connectivity = ConnectivityService();
  
  List<DraftFeedback> _drafts = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String _uploadStatus = '';
  double _uploadProgress = 0.0;

  StreamSubscription<FeedbackUploadProgress>? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
    _listenToUploadProgress();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    
    try {
      final currentUser = auth.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final drafts = await _draftService.getPendingDrafts(currentUser.uid);
        setState(() {
          _drafts = drafts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PendingFeedbackScreen] ❌ Failed to load drafts: $e');
      setState(() => _isLoading = false);
    }
  }

  void _listenToUploadProgress() {
    _progressSubscription = _uploadService.uploadProgress.listen((progress) {
      setState(() {
        _uploadProgress = progress.progress;
        _uploadStatus = progress.status;
        _isUploading = !progress.isComplete;
      });

      if (progress.isComplete) {
        // Refresh list after upload
        Future.delayed(const Duration(seconds: 1), _loadDrafts);
      }
    });
  }

  Future<void> _uploadAllDrafts() async {
    if (!_connectivity.isConnected) {
      _showSnackBar('No internet connection', Colors.red);
      return;
    }

    final currentUser = auth.FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      await _uploadService.processUploadQueue(userId: currentUser.uid);
    }
  }

  Future<void> _uploadSingleDraft(String draftId) async {
    if (!_connectivity.isConnected) {
      _showSnackBar('No internet connection', Colors.red);
      return;
    }

    final success = await _uploadService.uploadSingleDraft(draftId);
    if (success) {
      _showSnackBar('Feedback uploaded successfully!', Colors.green);
    } else {
      _showSnackBar('Failed to upload feedback', Colors.red);
    }
  }

  Future<void> _deleteDraft(DraftFeedback draft) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Draft'),
        content: const Text('Are you sure you want to delete this draft?'),
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

    if (confirm == true) {
      try {
        await _draftService.deleteDraft(draft.draftId);
        _showSnackBar('Draft deleted', Colors.blue);
        _loadDrafts();
      } catch (e) {
        _showSnackBar('Failed to delete draft', Colors.red);
      }
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pending Feedback'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (!_connectivity.isConnected)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Chip(
                label: Text(
                  'Offline',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                backgroundColor: Colors.orange,
                padding: EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? _buildEmptyState()
              : Column(
                  children: [
                    // Upload progress
                    if (_isUploading) _buildUploadProgress(),
                    
                    // Upload all button
                    if (_drafts.isNotEmpty && _connectivity.isConnected) ...[
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isUploading ? null : _uploadAllDrafts,
                            icon: const Icon(Icons.cloud_upload),
                            label: Text('Upload All (${_drafts.length})'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    
                    // Drafts list
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadDrafts,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _drafts.length,
                          itemBuilder: (context, index) {
                            final draft = _drafts[index];
                            return _buildDraftCard(draft);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: AppColors.textSecondary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No Pending Feedback',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All your feedback has been uploaded!',
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

  Widget _buildUploadProgress() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.blue[50],
      child: Column(
        children: [
          LinearProgressIndicator(
            value: _uploadProgress,
            backgroundColor: Colors.blue[100],
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
          ),
          const SizedBox(height: 12),
          Text(
            _uploadStatus,
            style: TextStyle(
              fontSize: 14,
              color: Colors.blue[900],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(DraftFeedback draft) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rating and status
            Row(
              children: [
                ...List.generate(5, (index) {
                  return Icon(
                    index < draft.rating ? Icons.star : Icons.star_border,
                    color: index < draft.rating ? Colors.amber[600] : Colors.grey[400],
                    size: 20,
                  );
                }),
                const Spacer(),
                _buildStatusChip(draft.status),
              ],
            ),
            
            const SizedBox(height: 8),
            
            // Comment
            Text(
              draft.comment.isNotEmpty ? draft.comment : 'No comment',
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 8),
            
            // Images count and date
            Row(
              children: [
                Icon(Icons.image_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${draft.localImagePaths.length} photos',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  _formatDate(draft.lastModified),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Actions
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _uploadSingleDraft(draft.draftId),
                    icon: const Icon(Icons.cloud_upload, size: 18),
                    label: const Text('Post Draft'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteDraft(draft),
                  icon: const Icon(Icons.delete_outline),
                  color: Colors.red,
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(DraftFeedbackStatus status) {
    Color backgroundColor;
    String label;
    
    switch (status) {
      case DraftFeedbackStatus.pendingUpload:
        backgroundColor = Colors.orange;
        label = 'Pending';
        break;
      case DraftFeedbackStatus.failed:
        backgroundColor = Colors.red;
        label = 'Failed';
        break;
      case DraftFeedbackStatus.uploading:
        backgroundColor = Colors.blue;
        label = 'Uploading';
        break;
      default:
        backgroundColor = Colors.grey;
        label = 'Draft';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: backgroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

