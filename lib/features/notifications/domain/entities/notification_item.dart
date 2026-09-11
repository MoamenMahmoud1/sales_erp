class NotificationItem {
  final int id;
  final String notificationType;
  final String title;
  final String body;
  final String targetType;
  final int? targetId;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;

  const NotificationItem({
    required this.id,
    required this.notificationType,
    required this.title,
    required this.body,
    required this.targetType,
    required this.targetId,
    required this.data,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
  });
}
