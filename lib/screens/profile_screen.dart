import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../widgets/product_card.dart';
import '../view_models/profile_view_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late ProfileViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = ProfileViewModel();
    viewModel.loadUserData();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(text: viewModel.currentUser?.name);
    final emailController = TextEditingController(text: viewModel.currentUser?.email);
    final passwordController = TextEditingController();

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
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
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
              onPressed: () async {
                try {
                  await viewModel.updateProfile(
                    nameController.text,
                    emailController.text,
                    passwordController.text.isNotEmpty
                        ? passwordController.text
                        : null,
                  );
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile updated successfully'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update profile: $e'),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        if (viewModel.isLoading) {
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
                icon: const Icon(Icons.settings),
                onPressed: () {
                  // Settings
                },
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 30),

                // Profile Photo, Name and Email - Centered
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.primaryColor.withOpacity(0.1),
                        child: Text(
                          (viewModel.currentUser?.name.isNotEmpty == true)
                              ? viewModel.currentUser!.name.substring(0, 2).toUpperCase()
                              : 'UN',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        viewModel.currentUser?.name ?? 'User Name',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        viewModel.currentUser?.email ?? 'email@university.edu',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                          color: AppColors.textSecondary.withOpacity(0.8),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Edit Profile Button - Full Width
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _showEditProfileDialog,
                      icon: const Icon(Icons.edit, size: 20),
                      label: const Text(
                        'Edit Profile',
                        style: TextStyle(fontSize: 16),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.borderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Sales Button - Full Width
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.push('/profile/sales');
                      },
                      icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                      label: const Text(
                        'Sales',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
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

                const SizedBox(height: 40),

                // My Products Section
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'My Products',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Products Grid
                if (viewModel.myProducts.isEmpty)
                  Center(
                    child: Column(
                      children: [
                        const SizedBox(height: 40),
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: AppColors.textSecondary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No products posted yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  )
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: viewModel.myProducts.length,
                    itemBuilder: (context, index) {
                      final product = viewModel.myProducts[index];
                      return ProductCard(
                        product: product,
                        onTap: () {
                          context.go('/home/product/${product.id}');
                        },
                      );
                    },
                  ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
