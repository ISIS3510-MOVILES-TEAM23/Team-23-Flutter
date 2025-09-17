import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationItem> notifications = [
    NotificationItem(
      id: '1',
      type: NotificationType.offer,
      title: 'New offer on MacBook Pro',
      message: 'Someone offered \$1,100 for your MacBook Pro',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      isRead: false,
      actionData: {'productId': 'h1', 'offerId': 'offer1'},
    ),
    NotificationItem(
      id: '2',
      type: NotificationType.message,
      title: 'New message from Maria García',
      message: 'Hi, is the textbook still available?',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      isRead: false,
      actionData: {'conversationId': 'conv2'},
    ),
    NotificationItem(
      id: '3',
      type: NotificationType.sold,
      title: 'Product sold!',
      message: 'Your iPhone 13 has been marked as sold',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      isRead: true,
      actionData: {'productId': 'up1'},
    ),
    NotificationItem(
      id: '4',
      type: NotificationType.favorite,
      title: 'Someone liked your product',
      message: 'Your Study Desk was added to favorites',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      isRead: true,
      actionData: {'productId': 'up2'},
    ),
    NotificationItem(
      id: '5',
      type: NotificationType.system,
      title: 'Welcome to Campus Marketplace!',
      message: 'Complete your profile to start selling',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      isRead: true,
      actionData: {},
    ),
  ];

  void _markAsRead(String notificationId) {
    setState(() {
      final index = notifications.indexWhere((n) => n.id == notificationId);
      if (index != -1) {
        notifications[index].isRead = true;
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in notifications) {
        notification.isRead = true;
      }
    });
  }

  void _deleteNotification(String notificationId) {
    setState(() {
      notifications.removeWhere((n) => n.id == notificationId);
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Notification deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            // Implementar undo
          },
        ),
      ),
    );
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return Icons.message;
      case NotificationType.offer:
        return Icons.local_offer;
      case NotificationType.sold:
        return Icons.check_circle;
      case NotificationType.favorite:
        return Icons.favorite;
      case NotificationType.system:
        return Icons.info;
    }
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.message:
        return AppColors.info;
      case NotificationType.offer:
        return AppColors.primaryColor;
      case NotificationType.sold:
        return AppColors.success;
      case NotificationType.favorite:
        return AppColors.error;
      case NotificationType.system:
        return AppColors.textSecondary;
    }
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 7) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = notifications.where((n) => !n.isRead).length;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all as read'),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No notifications',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You\'re all caught up!',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                
                return Dismissible(
                  key: Key(notification.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    color: AppColors.error,
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (direction) {
                    _deleteNotification(notification.id);
                  },
                  child: InkWell(
                    onTap: () {
                      _markAsRead(notification.id);
                      // Navigate based on notification type
                      if (notification.type == NotificationType.message) {
                        // Navigate to chat
                      } else if (notification.type == NotificationType.offer ||
                          notification.type == NotificationType.sold ||
                          notification.type == NotificationType.favorite) {
                        // Navigate to product
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: notification.isRead
                            ? null
                            : AppColors.primaryColor.withOpacity(0.05),
                        border: const Border(
                          bottom: BorderSide(
                            color: AppColors.borderColor,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _getNotificationColor(notification.type)
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getNotificationIcon(notification.type),
                              size: 20,
                              color: _getNotificationColor(notification.type),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        notification.title,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: notification.isRead
                                              ? FontWeight.w500
                                              : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (!notification.isRead)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primaryColor,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  notification.message,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _formatTime(notification.timestamp),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary.withOpacity(0.7),
                                  ),
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
    );
  }
}

enum NotificationType {
  message,
  offer,
  sold,
  favorite,
  system,
}

class NotificationItem {
  final String id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;
  final Map<String, dynamic> actionData;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    required this.actionData,
  });
}