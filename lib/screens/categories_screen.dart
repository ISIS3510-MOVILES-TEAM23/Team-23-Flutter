import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../view_models/categories_view_model.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late CategoriesViewModel viewModel;

  @override
  void initState() {
    super.initState();
    viewModel = CategoriesViewModel();
    viewModel.loadCategories();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, child) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: viewModel.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: viewModel.loadCategories,
                  child: CustomScrollView(
                    slivers: [
                      // App header
                      SliverAppBar(
                        pinned: true,
                        centerTitle: true,
                        title: const Text('Marketplace'),
                        backgroundColor:
                            Theme.of(context).appBarTheme.backgroundColor,
                      ),

                      // Categories title
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 12),
                          child: Text(
                            'Categories',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),

                      // Categories list
                      if (viewModel.categories.isEmpty)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 80),
                            child: Center(
                              child: Text(
                                'No hay categorías disponibles',
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                        )
                      else
                        SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final category = viewModel.categories[index];
                              final icon = viewModel.getIconForCategory(category.name);

                              return InkWell(
                                onTap: () {
                                  print(
                                      'Navigating to category: ${category.name} (ID: ${category.id})');
                                  context.go('/categories/${category.name}');
                                },
                                child: Container(
                                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardTheme.color,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      // Icon
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryColor
                                              .withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          icon,
                                          size: 24,
                                          color: AppColors.primaryColor,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Text
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category.name,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              category.description.isNotEmpty
                                                  ? category.description
                                                  : 'Ver productos en ${category.name}',
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: AppColors.textPrimary
                                                    .withOpacity(0.6),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Arrow
                                      Icon(
                                        Icons.chevron_right,
                                        color: AppColors.textSecondary
                                            .withOpacity(0.5),
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            childCount: viewModel.categories.length,
                          ),
                        ),

                      const SliverToBoxAdapter(
                        child: SizedBox(height: 20),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
