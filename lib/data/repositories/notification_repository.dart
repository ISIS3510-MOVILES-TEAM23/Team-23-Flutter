import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/notification_model.dart';

/// Repository para acceso a datos de notificaciones
/// Capa de acceso a datos en la arquitectura MVVM
class NotificationRepository {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  NotificationRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  /// Obtiene el UID del usuario actual
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  /// Obtiene notificaciones no leídas del usuario actual
  Future<List<InAppNotification>> getUnreadNotifications({int limit = 10}) async {
    final uid = getCurrentUserId();
    if (uid == null) return [];

    try {
      final snapshot = await _db
          .collection('notifications')
          .where('userId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => InAppNotification.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting unread notifications: $e');
      return [];
    }
  }

  /// Marca una notificación como leída
  Future<bool> markAsRead(String notificationId) async {
    try {
      await _db.collection('notifications').doc(notificationId).update({
        'read': true,
        'readAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (e) {
      print('Error marking notification as read: $e');
      return false;
    }
  }

  /// Marca todas las notificaciones del usuario como leídas
  Future<bool> markAllAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return true;

    try {
      final batch = _db.batch();

      for (final id in notificationIds) {
        final ref = _db.collection('notifications').doc(id);
        batch.update(ref, {
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      return true;
    } catch (e) {
      print('Error marking all as read: $e');
      return false;
    }
  }

  /// Crea una nueva notificación
  Future<bool> createNotification(InAppNotification notification) async {
    try {
      await _db.collection('notifications').add(notification.toJson());
      return true;
    } catch (e) {
      print('Error creating notification: $e');
      return false;
    }
  }
}

