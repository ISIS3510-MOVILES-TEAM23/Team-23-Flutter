import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/notification_model.dart';
import '../view_models/notification_view_model.dart';

/// Widget de banner individual de notificación (View)
class NotificationBanner extends StatelessWidget {
  final InAppNotification notification;
  final VoidCallback onDismiss;
  final VoidCallback onTap;

  const NotificationBanner({
    super.key,
    required this.notification,
    required this.onDismiss,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      color: Theme.of(context).primaryColor,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Icono
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.shopping_bag,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              // Texto
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      notification.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Botón cerrar
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onDismiss,
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Widget contenedor que muestra banners de notificaciones (View)
class NotificationBannerContainer extends StatefulWidget {
  final Widget child;
  final NotificationViewModel viewModel;

  const NotificationBannerContainer({
    super.key,
    required this.child,
    required this.viewModel,
  });

  @override
  State<NotificationBannerContainer> createState() =>
      _NotificationBannerContainerState();
}

class _NotificationBannerContainerState
    extends State<NotificationBannerContainer> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.viewModel,
      builder: (context, _) {
        final notifications = widget.viewModel.notifications;

        if (notifications.isEmpty) {
          return widget.child;
        }

        // Asegurar que el índice es válido
        if (_currentIndex >= notifications.length) {
          _currentIndex = notifications.length - 1;
        }

        final currentNotification = notifications[_currentIndex];

        return Stack(
          children: [
            widget.child,
            // Banner en la parte superior
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NotificationBanner(
                      notification: currentNotification,
                      onDismiss: () {
                        widget.viewModel.markAsRead(currentNotification.id);
                        
                        // Mostrar siguiente notificación si hay
                        if (notifications.length > 1) {
                          setState(() {
                            _currentIndex = _currentIndex % (notifications.length - 1);
                          });
                        }
                      },
                      onTap: () {
                        // Marcar como leída
                        widget.viewModel.markAsRead(currentNotification.id);

                        // Navegar al producto si existe
                        if (currentNotification.postId != null) {
                          context.go('/home/product/${currentNotification.postId}');
                        }
                      },
                    ),
                    // Indicador de múltiples notificaciones
                    if (notifications.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        color: Theme.of(context).primaryColor.withOpacity(0.8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '${_currentIndex + 1} de ${notifications.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: widget.viewModel.markAllAsRead,
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                'Descartar todas',
                                style: TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

