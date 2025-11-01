import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../view_models/wish_list_view_model.dart';
import '../widgets/offline_network_image.dart';

class WishListScreen extends StatefulWidget {
  const WishListScreen({super.key});

  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  late WishListViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = WishListViewModel();
    viewModel.loadWishList();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  void _showNotesDialog(String itemId, String currentNotes) {
    final controller = TextEditingController(text: currentNotes);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Add notes about this item...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await viewModel.updateNotes(itemId, controller.text);
              if (mounted) {
                Navigator.pop(context);
                // Show feedback based on connectivity
                if (viewModel.isOffline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notes saved. Will sync when online.'),
                      duration: Duration(seconds: 2),
                      backgroundColor: Colors.orange,
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String itemId, String productTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove from Wish List'),
        content: Text('Remove "$productTitle" from your wish list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await viewModel.removeFromWishList(itemId);
              if (mounted) Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Wish List'),
            centerTitle: true,
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          ),
          body: Column(
            children: [
              // Offline banner
              if (viewModel.isOffline)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: Colors.orange.shade100,
                  child: Row(
                    children: [
                      Icon(Icons.cloud_off, size: 20, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Offline - Showing your saved wishlist. Last synced: ${viewModel.getLastSyncTimeText()}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Main content
              Expanded(
                child: viewModel.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : viewModel.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.favorite_border,
                                  size: 80,
                                  color: AppColors.textSecondary.withOpacity(0.5),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Your wish list is empty',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Add items you want to buy later',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              if (viewModel.isOffline) {
                                // Show snackbar when offline
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Cannot refresh while offline'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                return;
                              }
                              await viewModel.loadWishList();
                            },
                            child: Column(
                        children: [
                          // Summary card
                          Container(
                            margin: const EdgeInsets.all(16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardTheme.color,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${viewModel.totalItems} ${viewModel.totalItems == 1 ? 'item' : 'items'}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Total value',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  viewModel.formattedTotalValue,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Items list
                          Expanded(
                            child: ListView.builder(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: viewModel.items.length,
                              itemBuilder: (context, index) {
                                final item = viewModel.items[index];
                                final imageUrl = item.productImages.isNotEmpty
                                    ? item.productImages.first
                                    : 'https://picsum.photos/seed/${item.productId}/300/200';

                                return Dismissible(
                                  key: Key(item.id),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.only(right: 20),
                                    alignment: Alignment.centerRight,
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  confirmDismiss: (direction) async {
                                    // Show confirmation on dismiss
                                    return await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Remove from Wish List'),
                                        content: Text('Remove "${item.productTitle}" from your wish list?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                                            child: const Text('Remove'),
                                          ),
                                        ],
                                      ),
                                    ) ?? false;
                                  },
                                  onDismissed: (direction) async {
                                    final success = await viewModel.removeFromWishList(item.id);
                                    if (!success && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Failed to remove item. Please try again.'),
                                          duration: Duration(seconds: 2),
                                        ),
                                      );
                                    } else if (viewModel.isOffline && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Wishlist updated. Changes will sync when online.'),
                                          duration: Duration(seconds: 2),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    }
                                  },
                                  child: InkWell(
                                    onTap: () {
                                      context.go(
                                          '/home/product/${item.productId}');
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            Theme.of(context).cardTheme.color,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        children: [
                                          // Image
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: SizedBox(
                                              width: 80,
                                              height: 80,
                                              child: OfflineNetworkImage(
                                                imageUrl: imageUrl,
                                                fit: BoxFit.cover,
                                                width: 80,
                                                height: 80,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Content
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  item.productTitle,
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  item.productDescription,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: AppColors.textPrimary
                                                        .withOpacity(0.7),
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Text(
                                                      viewModel.formatPrice(
                                                          item.productPrice),
                                                      style: const TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: AppColors
                                                            .primaryColor,
                                                      ),
                                                    ),
                                                    const Spacer(),
                                                    if (item.notes != null &&
                                                        item.notes!.isNotEmpty)
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons.note,
                                                            size: 20),
                                                        onPressed: () =>
                                                            _showNotesDialog(
                                                          item.id,
                                                          item.notes ?? '',
                                                        ),
                                                        tooltip: 'View notes',
                                                      )
                                                    else
                                                      IconButton(
                                                        icon: const Icon(
                                                            Icons
                                                                .note_add_outlined,
                                                            size: 20),
                                                        onPressed: () =>
                                                            _showNotesDialog(
                                                          item.id,
                                                          item.notes ?? '',
                                                        ),
                                                        tooltip: 'Add notes',
                                                      ),
                                                    IconButton(
                                                      icon: const Icon(
                                                          Icons.delete_outline,
                                                          size: 20),
                                                      onPressed: () =>
                                                          _showDeleteConfirmation(
                                                        item.id,
                                                        item.productTitle,
                                                      ),
                                                      color: Colors.red,
                                                      tooltip: 'Remove',
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
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
}
