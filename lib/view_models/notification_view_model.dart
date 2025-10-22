import 'package:flutter/foundation.dart';
import '../data/repositories/notification_repository.dart';
import '../models/notification_model.dart';

/// ViewModel para notificaciones in-app
/// Maneja el estado y la lógica de presentación siguiendo MVVM
class NotificationViewModel extends ChangeNotifier {
  final NotificationRepository _repository;

  NotificationViewModel({
    NotificationRepository? repository,
  }) : _repository = repository ?? NotificationRepository();

  List<InAppNotification> _notifications = [];
  bool _isLoading = false;
  bool _hasChecked = false;

  List<InAppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  bool get hasNotifications => _notifications.isNotEmpty;

  /// Verifica y carga notificaciones pendientes
  Future<void> loadNotifications() async {
    if (_hasChecked) return; // Solo cargar una vez por sesión

    try {
      _isLoading = true;
      notifyListeners();

      _notifications = await _repository.getUnreadNotifications(limit: 10);
      
      debugPrint('📬 Loaded ${_notifications.length} pending notifications');

      _hasChecked = true;
    } catch (e) {
      debugPrint('❌ Error loading notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Marca una notificación como leída
  Future<void> markAsRead(String notificationId) async {
    final success = await _repository.markAsRead(notificationId);
    
    if (success) {
      _notifications.removeWhere((n) => n.id == notificationId);
      notifyListeners();
      debugPrint('✅ Notification marked as read: $notificationId');
    }
  }

  /// Marca todas las notificaciones como leídas
  Future<void> markAllAsRead() async {
    final ids = _notifications.map((n) => n.id).toList();
    final success = await _repository.markAllAsRead(ids);
    
    if (success) {
      _notifications.clear();
      notifyListeners();
      debugPrint('✅ All notifications marked as read');
    }
  }

  /// Reinicia el estado (útil para logout)
  void reset() {
    _notifications.clear();
    _hasChecked = false;
    notifyListeners();
  }
}

