import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'screens/chat_screen.dart';
import 'screens/messages_screen.dart';
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
      ],
    ),
  ],
);