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
  /// 
  /// **PATTERN 1: ASYNC/AWAIT**
  /// - Clean, sequential code
  /// - Easy to read and maintain
  /// - Modern Dart/Flutter approach
  Future<void> markAsRead(String notificationId) async {
    try {
      debugPrint('📝 [ASYNC/AWAIT] Marking notification as read: $notificationId');
      
      final success = await _repository.markAsRead(notificationId);
      
      if (success) {
        _notifications.removeWhere((n) => n.id == notificationId);
        notifyListeners();
        debugPrint('✅ [ASYNC/AWAIT] Notification marked as read successfully');
      } else {
        debugPrint('⚠️ [ASYNC/AWAIT] Failed to mark notification as read');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [ASYNC/AWAIT] Error marking notification as read: $e');
      debugPrint('Stack trace: $stackTrace');
      // Could rethrow or handle gracefully
    }
  }

  /// Marca todas las notificaciones como leídas
  /// 
  /// **PATTERN 2: FUTURE WITH HANDLERS (.then() / .catchError())**
  /// - Functional programming style
  /// - Explicit success/error callbacks
  /// - Good for chaining multiple operations
  /// - Alternative to async/await
  Future<void> markAllAsRead() {
    final ids = _notifications.map((n) => n.id).toList();
    
    debugPrint('📝 [FUTURE HANDLERS] Marking ${ids.length} notifications as read...');
    
    return _repository.markAllAsRead(ids)
        .then((success) {
          // SUCCESS HANDLER (.then)
          debugPrint('✅ [FUTURE HANDLERS] .then() called - Success: $success');
          
          if (success) {
            _notifications.clear();
            notifyListeners();
            debugPrint('✅ [FUTURE HANDLERS] All notifications cleared from list');
          } else {
            debugPrint('⚠️ [FUTURE HANDLERS] Repository returned false');
          }
        })
        .catchError((error, stackTrace) {
          // ERROR HANDLER (.catchError)
          debugPrint('❌ [FUTURE HANDLERS] .catchError() called');
          debugPrint('Error: $error');
          debugPrint('Stack trace: $stackTrace');
          
          // Could show error to user via SnackBar
          // For now, just log it
        })
        .whenComplete(() {
          // CLEANUP HANDLER (runs regardless of success/error)
          debugPrint('🏁 [FUTURE HANDLERS] .whenComplete() called');
          debugPrint('Operation finished - cleanup or final actions here');
        });
  }

  /// Reinicia el estado (útil para logout)
  void reset() {
    _notifications.clear();
    _hasChecked = false;
    notifyListeners();
  }
}

