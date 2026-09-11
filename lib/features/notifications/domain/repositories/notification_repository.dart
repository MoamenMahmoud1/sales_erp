import '../entities/notification_item.dart';

abstract class NotificationRepository {
  Future<List<NotificationItem>> fetchNotifications({bool unreadOnly = false});

  Future<NotificationItem> markAsRead({required int notificationId});

  Future<void> markAllAsRead();
}
