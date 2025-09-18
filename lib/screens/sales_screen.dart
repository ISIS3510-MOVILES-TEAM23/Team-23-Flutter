import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/models.dart';
import '../services/mock_service.dart';
import '../theme/app_colors.dart';

class SalesScreen extends StatefulWidget {
  const SalesScreen({super.key});

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PostWithChat> allSales = [];
  List<PostWithChat> pendingSales = [];
  List<PostWithChat> completedSales = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSalesData();
  }

  Future<void> _loadSalesData() async {
    try {
      final user = await MockService.getCurrentUser();
      final sales = await MockService.getUserPostsWithChats(user.id);
      
      setState(() {
        allSales = sales;
        pendingSales = sales.where((s) => 
          s.sale?.status == 'pending' || 
          s.sale?.status == 'acknowledged' ||
          (s.sale == null && s.chatId != null)
        ).toList();
        completedSales = sales.where((s) => s.sale?.status == 'completed').toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  String _formatDollars(int cents) => '\$' + (cents / 100).toStringAsFixed(2);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Sales'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Statistics Section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    border: const Border(
                      bottom: BorderSide(color: AppColors.borderColor, width: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('Total Products', allSales.length.toString()),
                      _buildStatItem('Completed', completedSales.length.toString()),
                      _buildStatItem('Pending', pendingSales.length.toString()),
                    ],
                  ),
                ),
                
                // TabBar
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppColors.primaryColor,
                    unselectedLabelColor: AppColors.textSecondary,
                    indicatorColor: AppColors.primaryColor,
                    tabs: [
                      Tab(text: 'All (${allSales.length})'),
                      Tab(text: 'Pending (${pendingSales.length})'),
                      Tab(text: 'Completed (${completedSales.length})'),
                    ],
                  ),
                ),
                
                // TabBarView
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSalesList(allSales),
                      _buildSalesList(pendingSales),
                      _buildSalesList(completedSales),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSalesList(List<PostWithChat> sales) {
    if (sales.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No sales in this category',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary.withOpacity(0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sales.length,
      itemBuilder: (context, index) {
        final sale = sales[index];
        return _buildSaleCard(sale);
      },
    );
  }

  Widget _buildSaleCard(PostWithChat saleData) {
    final post = saleData.post;
    final buyer = saleData.buyer;
    final status = saleData.sale?.status ?? 'pending';
    final showChatButton = status != 'completed' && status != 'canceled';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Product Row with Status Badge
            Stack(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        post.images.isNotEmpty 
                            ? post.images.first 
                            : 'https://picsum.photos/seed/${post.id}/400/400',
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 80,
                            height: 80,
                            color: AppColors.borderColor,
                            child: const Icon(
                              Icons.image_not_supported,
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Product Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            post.description,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary.withOpacity(0.8),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _formatDollars(post.price),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Status Badge - Top Right
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(status).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _getStatusText(status),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _getStatusColor(status),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Buyer Info Row
            if (buyer != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                    child: Text(
                      buyer.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      buyer.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            
            // Action Buttons Row
            Row(
              children: [
                // Detail Button - 75% width
                Expanded(
                  flex: 3,
                  child: ElevatedButton(
                    onPressed: () {
                      context.go('/home/product/${post.id}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'View Details',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Chat Button - 25% width (only if active/pending)
                if (showChatButton && saleData.chatId != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () {
                        context.push('/messages/chat/${saleData.chatId}');
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppColors.primaryColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Icon(
                        Icons.message_outlined,
                        size: 20,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed':
        return AppColors.success;
      case 'canceled':
        return AppColors.error;
      case 'acknowledged':
        return Colors.blue;
      default:
        return AppColors.warning;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed':
        return 'Completed';
      case 'canceled':
        return 'Canceled';
      case 'acknowledged':
        return 'In Progress';
      case 'pending':
        return 'Pending';
      default:
        return status;
    }
  }
}