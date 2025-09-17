import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../models/models.dart';
import '../services/mock_service.dart';
import '../theme/app_colors.dart';
import '../widgets/product_card.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  User? currentUser;
  List<Post> myProducts = [];
  List<Post> myPurchases = [];
  List<Post> myFavorites = [];
  List<Post> pending = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await MockService.getCurrentUser();
      final products = await MockService.getUserPosts(user.id);
      final purchases = await MockService.getUserPurchases(user.id);
      final favorites = await MockService.getUserFavorites(user.id);
      
      setState(() {
        currentUser = user;
        myProducts = products;
        myPurchases = purchases;
        myFavorites = favorites;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: currentUser?.name);
    final emailController = TextEditingController(text: currentUser?.email);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 16),
              const TextField(
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password (optional)',
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // Save changes
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Profile updated successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Profile'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(
              themeProvider.themeMode == ThemeMode.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // Settings
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // User Info Section
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  child: Text(
                    (currentUser?.name.isNotEmpty == true)
                        ? currentUser!.name.substring(0, 2).toUpperCase()
                        : 'UN',
                    style: const TextStyle(fontSize: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentUser?.name ?? 'User Name',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser?.email ?? 'email@university.edu',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      // Additional badges removed (not in new user model)
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: _showEditProfileDialog,
                ),
              ],
            ),
          ),
          
          // Stats Row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: const Border(
                top: BorderSide(color: AppColors.borderColor),
                bottom: BorderSide(color: AppColors.borderColor),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatItem('Products', myProducts.length.toString()),
                _buildStatItem('Purchases', myPurchases.length.toString()),
                _buildStatItem('Favorites', myFavorites.length.toString()),
                _buildStatItem('Pending', pending.length.toString()),
              ],
            ),
          ),
          
          // Tab Bar
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              border: const Border(
                bottom: BorderSide(color: AppColors.borderColor),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primaryColor,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primaryColor,
              tabs: const [
                Tab(text: 'My Products'),
                Tab(text: 'Purchases'),
                Tab(text: 'Favorites'),
                Tab(text: 'Pending'),
              ],
            ),
          ),
          
          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // My Products Tab
                _buildProductGrid(myProducts, 'No products posted yet'),
                
                // Purchases Tab
                _buildProductGrid(myPurchases, 'No purchases yet'),
                
                // Favorites Tab
                _buildProductGrid(myFavorites, 'No favorites yet'),
                
                // Pending Tab
                _buildProductGrid(pending, 'No pending transactions'),
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
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid(List<Post> products, String emptyMessage) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: AppColors.textSecondary.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          onTap: () {
            context.go('/home/product/${product.id}');
          },
        );
      },
    );
  }
}