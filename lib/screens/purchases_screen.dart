import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;

import '../models/models.dart';
import '../services/firestore_service.dart';
import '../services/connectivity_service.dart';
import '../services/purchases_cache_service.dart';
import '../theme/app_colors.dart';
import '../widgets/offline_network_image.dart';
import '../screens/feedback_form_screen.dart';
import '../services/draft_feedback_service.dart';

/// Purchases Screen - Shows user's purchases (where user is the buyer)
/// Allows leaving feedback for completed purchases
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({super.key});

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends State<PurchasesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PostWithChat> allPurchases = [];
  List<PostWithChat> pendingPurchases = [];
  List<PostWithChat> completedPurchases = [];
  User? user;
  bool isLoading = true;
  bool isLoadedFromCache = false;
  
  final ConnectivityService _connectivity = ConnectivityService();
  final DraftFeedbackService _draftService = DraftFeedbackService();
  final PurchasesCacheService _purchasesCache = PurchasesCacheService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPurchasesData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (!_connectivity.isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cannot refresh while offline'),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    await _loadPurchasesData();
  }

  Future<void> _loadPurchasesData() async {
    try {
      setState(() {
        isLoading = true;
      });

      // Get current Firebase Auth user
      final firebaseUser = auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) {
        debugPrint('[PurchasesScreen] ❌ No Firebase user logged in');
        setState(() {
          isLoading = false;
        });
        return;
      }

      final userId = firebaseUser.uid;
      debugPrint('[PurchasesScreen] 👤 User ID: $userId');

      List<PostWithChat> purchases = [];

      // Try network first if online
      if (_connectivity.isConnected) {
        user = await FirestoreService.getCurrentUser();
        
        try {
          debugPrint('[PurchasesScreen] 📦 Online - Fetching purchases from network...');
          purchases = await FirestoreService.getUserPurchasesWithChats(userId);
          
          // Cache in LRU (only most recent 5)
          await _purchasesCache.cachePurchases(userId, purchases);
          
          isLoadedFromCache = false;
          debugPrint('[PurchasesScreen] ✅ Got ${purchases.length} purchases from network');
          debugPrint('[PurchasesScreen] 📊 LRU Cache stats: ${_purchasesCache.getCacheStats()}');
        } catch (e) {
          debugPrint('[PurchasesScreen] ❌ Network failed, trying cache: $e');
          // Fallback to cache
          final cached = await _purchasesCache.getCachedPurchases(userId);
          if (cached != null) {
            purchases = cached;
            isLoadedFromCache = true;
            debugPrint('[PurchasesScreen] 📦 Loaded ${purchases.length} purchases from cache');
          }
        }
      } else {
        // Offline - load from cache
        debugPrint('[PurchasesScreen] ⚠️ Offline - Loading from LRU cache...');
        final cached = await _purchasesCache.getCachedPurchases(userId);
        if (cached != null) {
          purchases = cached;
          isLoadedFromCache = true;
          debugPrint('[PurchasesScreen] 📦 Loaded ${purchases.length} purchases from cache');
        } else {
          debugPrint('[PurchasesScreen] ❌ No cached data available');
        }
      }
        
      setState(() {
        allPurchases = purchases;
        pendingPurchases = purchases
            .where((p) => p.sale?.status == 'pending')
            .toList();
        completedPurchases = purchases
            .where((p) => p.sale?.status == 'completed')
            .toList();
        isLoading = false;
      });
      
      debugPrint('[PurchasesScreen] ✅ Display ready: ${purchases.length} purchases (fromCache: $isLoadedFromCache)');
    } catch (e) {
      debugPrint('[PurchasesScreen] ❌ Error loading purchases: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Check if user has already left feedback for this purchase
  Future<bool> _hasFeedbackDraft(String purchaseId) async {
    final firebaseUser = auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return false;

    final drafts = await _draftService.getAllDrafts(firebaseUser.uid);
    return drafts.any((draft) => draft.purchaseId == purchaseId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Purchases'),
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Pending'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Cache indicator and Stats Section
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                  decoration: BoxDecoration(
                    color: isLoadedFromCache ? Colors.orange[50] : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Cache indicator
                      if (isLoadedFromCache)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.cached, size: 16, color: Colors.orange[700]),
                              const SizedBox(width: 8),
                              Text(
                                'Showing cached data (LRU)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange[700],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Stats Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem('Total', '${allPurchases.length}'),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          _buildStatItem('Pending', '${pendingPurchases.length}'),
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey[300],
                          ),
                          _buildStatItem('Completed', '${completedPurchases.length}'),
                        ],
                      ),
                    ],
                  ),
                ),

                // TabBarView
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _handleRefresh,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPurchasesList(allPurchases),
                        _buildPurchasesList(pendingPurchases),
                        _buildPurchasesList(completedPurchases),
                      ],
                    ),
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

  Widget _buildPurchasesList(List<PostWithChat> purchases) {
    if (purchases.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No purchases in this category',
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
      padding: const EdgeInsets.all(16),
      itemCount: purchases.length,
      itemBuilder: (context, index) {
        final purchase = purchases[index];
        return _buildPurchaseCard(purchase);
      },
    );
  }

  Widget _buildPurchaseCard(PostWithChat purchaseData) {
    final post = purchaseData.post;
    final sale = purchaseData.sale;
    final seller = purchaseData.buyer; // In purchases context, buyer field contains seller info

    if (sale == null) return const SizedBox.shrink();

    final bool isCompleted = sale.status == 'completed';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: () {
          context.push('/post/${post.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Info Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product Image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: OfflineNetworkImage(
                      imageUrl: post.images.isNotEmpty ? post.images.first : '',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Product Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        
                        // Seller Info
                        if (seller != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.store,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Seller: ${seller.name}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],
                        
                        // Price
                        Text(
                          '\$${(sale.price / 100).toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status Badge
                  _buildStatusBadge(sale.status),
                ],
              ),

              // Feedback Button (only for completed purchases)
              if (isCompleted) ...[
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 12),
                
                FutureBuilder<bool>(
                  future: _hasFeedbackDraft(sale.id),
                  builder: (context, snapshot) {
                    final hasDraft = snapshot.data ?? false;
                    
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FeedbackFormScreen(
                                purchaseId: sale.id,
                                sellerId: sale.sellerId,
                                productTitle: post.title,
                              ),
                            ),
                          );
                          
                          // Refresh if feedback was submitted
                          if (result == true) {
                            setState(() {});
                          }
                        },
                        icon: Icon(
                          hasDraft ? Icons.edit : Icons.rate_review,
                          size: 18,
                        ),
                        label: Text(
                          hasDraft ? 'Continue Feedback' : 'Leave Feedback',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: hasDraft ? Colors.orange : AppColors.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color backgroundColor;
    String label;
    
    switch (status) {
      case 'pending':
        backgroundColor = Colors.orange;
        label = 'Pending';
        break;
      case 'completed':
        backgroundColor = Colors.green;
        label = 'Completed';
        break;
      case 'canceled':
        backgroundColor = Colors.red;
        label = 'Canceled';
        break;
      default:
        backgroundColor = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

