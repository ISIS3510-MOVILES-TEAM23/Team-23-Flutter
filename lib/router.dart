import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
<<<<<<< Updated upstream
import 'screens/chat_screen.dart';
import 'screens/messages_screen.dart';
=======
import 'screens/home_screen.dart';
import 'screens/categories_screen.dart';
import 'screens/category_products_screen.dart';
import 'screens/product_detail_screen.dart';
import 'screens/create_post_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/notifications_screen.dart';
>>>>>>> Stashed changes
import 'widgets/main_scaffold.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/messages',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MainScaffold(navigationShell: navigationShell);
      },
      branches: [
<<<<<<< Updated upstream
        // Messages branch
=======
        // Home branch
>>>>>>> Stashed changes
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messages',
              builder: (context, state) => const MessagesScreen(),
              routes: [
                GoRoute(
                  path: 'chat/:conversationId',
                  builder: (context, state) => ChatScreen(
                    chatId: state.pathParameters['conversationId']!,
                  ),
                ),
                GoRoute(
                  path: 'notifications',
                  builder: (context, state) => const NotificationsScreen(),
                ),
              ],
            ),
          ],
        ),
<<<<<<< Updated upstream
=======
        
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
                  path: 'chat/:conversationId',
                  builder: (context, state) => ChatScreen(
                    chatId: state.pathParameters['conversationId']!,
                  ),
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
            ),
          ],
        ),
>>>>>>> Stashed changes
      ],
    ),
  ],
);