import '../../../core/network/api_client.dart';
import '../domain/entities/notification_item.dart';
import '../domain/repositories/notification_repository.dart';

class DioNotificationRepository implements NotificationRepository {
  final ApiClient client;

  const DioNotificationRepository(this.client);

  @override
  Future<List<NotificationItem>> fetchNotifications({bool unreadOnly = false}) async {
    final response = await client.dio.get(
      '/notifications/',
      queryParameters: unreadOnly ? {'unread': 'true'} : null,
    );
    final results = response.data is Map<String, dynamic>
        ? (response.data['results'] as List? ?? const [])
        : const [];

    return [
      for (final item in results)
        if (item is Map) _mapNotification(Map<String, dynamic>.from(item)),
    ];
  }

  @override
  Future<NotificationItem> markAsRead({required int notificationId}) async {
    final response = await client.dio.post('/notifications/$notificationId/read/');
    return _mapNotification(Map<String, dynamic>.from(response.data as Map));
  }

  @override
  Future<void> markAllAsRead() async {
    await client.dio.post('/notifications/read-all/');
  }

  NotificationItem _mapNotification(Map<String, dynamic> row) {
    final data = row['data'];
    return NotificationItem(
      id: _readInt(row['id']),
      notificationType: _readString(row['notification_type']),
      title: _readString(row['title']),
      body: _readString(row['body']),
      targetType: _readString(row['target_type']),
      targetId: _readNullableInt(row['target_id']),
      data: data is Map ? Map<String, dynamic>.from(data) : const {},
      isRead: row['is_read'] == true,
      readAt: DateTime.tryParse(_readString(row['read_at'])),
      createdAt: DateTime.tryParse(_readString(row['created_at'])) ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  String _readString(dynamic value) => value?.toString() ?? '';

  int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    return _readInt(value);
  }
}
