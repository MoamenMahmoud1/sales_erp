import 'package:flutter/foundation.dart';

import '../domain/entities/notification_item.dart';
import '../domain/repositories/notification_repository.dart';

class NotificationsController extends ChangeNotifier {
  final NotificationRepository repository;

  NotificationsController({required this.repository});

  List<NotificationItem> notifications = const [];
  bool isLoading = false;
  String? errorMessage;

  int get unreadCount => notifications.where((item) => !item.isRead).length;

  Future<void> load() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      notifications = await repository.fetchNotifications();
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markAsRead(NotificationItem notification) async {
    if (notification.isRead) return;
    try {
      final updated = await repository.markAsRead(notificationId: notification.id);
      notifications = [
        for (final item in notifications)
          item.id == updated.id ? updated : item,
      ];
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await repository.markAllAsRead();
      final now = DateTime.now();
      notifications = [
        for (final item in notifications)
          NotificationItem(
            id: item.id,
            notificationType: item.notificationType,
            title: item.title,
            body: item.body,
            targetType: item.targetType,
            targetId: item.targetId,
            data: item.data,
            isRead: true,
            readAt: item.readAt ?? now,
            createdAt: item.createdAt,
          ),
      ];
      notifyListeners();
    } catch (error) {
      errorMessage = error.toString();
      notifyListeners();
    }
  }
}
