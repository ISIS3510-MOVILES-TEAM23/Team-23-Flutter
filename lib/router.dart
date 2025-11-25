import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import 'screens/categories_screen.dart';
import 'screens/category_products_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/confirm_purchase_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/drafts_screen.dart';
import 'screens/home_screen.dart';
import 'screens/hot_category_screen.dart';
import 'screens/login_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/sales_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/verification_screen.dart';
import 'screens/wish_list_screen.dart';
import 'widgets/main_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    final user = firebase_auth.FirebaseAuth.instance.currentUser;
    final isLoginRoute = state.matchedLocation == '/login';
    final isSignupRoute = state.matchedLocation == '/signup';
    final isVerificationRoute = state.matchedLocation == '/verification';

    // If user is logged in and trying to access auth screens, redirect to home
    if (user != null && (isLoginRoute || isSignupRoute)) {
      return '/home';
    }

    // If user is not logged in and trying to access protected routes
    if (user == null && !isLoginRoute && !isSignupRoute && !isVerificationRoute) {
      return '/login';
    }

    return null; // No redirect needed
  },
  routes: [
    GoRoute(
      path: '/',
      redirect: (context, state) => '/login',
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/signup',
      builder: (context, state) => const SignupScreen(),
    ),
    GoRoute(
      path: '/verification',
      builder: (context, state) {
        final extra = (state.extra as Map?) ?? {};
        return VerificationScreen(
          email: (extra['email'] as String?) ?? '',
        );
      },
    ),
    GoRoute(
      path: '/chat',
      name: 'chat-direct',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>? ?? {};
        return ChatScreen(
          chatId: args['chatId']?.toString() ?? '',
          productId: args['productId']?.toString() ?? '',
          sellerId: args['sellerId']?.toString() ?? '',
        );
      },
    ),
    GoRoute(
      path: '/confirm_purchase',
      builder: (context, state) => const ConfirmPurchaseScreen(),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffold(navigationShell: navigationShell);
      },
      branches: [
        // Home branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'product/:productId',
                  builder: (context, state) => ProductDetailScreen(
                    productId: state.pathParameters['productId']!,
                  ),
                ),
                GoRoute(
                  path: 'hot-products/:categoryId',
                  builder: (context, state) {
                    final extra = (state.extra as Map?) ?? {};
                    // Decode the categoryId to handle special characters and slashes
                    final encodedCategoryId = state.pathParameters['categoryId']!;
                    final categoryId = Uri.decodeComponent(encodedCategoryId);
                    return HotCategoryScreen(
                      categoryId: categoryId,
                      categoryName: extra['categoryName'] as String?,
                    );
                  },
                ),
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) => const NotificationsScreen(),
                ),
                GoRoute(
                  path: 'wishlist',
                  builder: (context, state) => const WishListScreen(),
                ),
              ],
            ),
          ],
        ),
        
        // Categories branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/categories',
              builder: (context, state) => const CategoriesScreen(),
              routes: [
                GoRoute(
                  path: ':categoryId',
                  builder: (context, state) => CategoryProductsScreen(
                    categoryId: state.pathParameters['categoryId']!,
                  ),
                  routes: [
                    GoRoute(
                      path: 'product/:productId',
                      builder: (context, state) => ProductDetailScreen(
                        productId: state.pathParameters['productId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        
        // Create Post branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/post',
              builder: (context, state) => const CreatePostScreen(),
            ),
          ],
        ),
        
        // Messages branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messages',
              builder: (context, state) => const MessagesScreen(),
              routes: [
                GoRoute(
                  path: 'chat',
                  name: 'chat',
                  builder: (context, state) {
                    final args = state.extra as Map<String, dynamic>? ?? {};
                    return ChatScreen(
                      chatId: args['chatId']?.toString() ?? '',
                      productId: args['productId']?.toString() ?? '',
                      sellerId: args['sellerId']?.toString() ?? '',
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        
        // Profile branch
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
              routes: [
                GoRoute(
                  path: 'sales',
                  builder: (context, state) => const SalesScreen(),
                ),
                GoRoute(
                  path: 'drafts',
                  builder: (context, state) => const DraftsScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);