import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../domain/entities/notification_item.dart';
import 'notifications_controller.dart';

class NotificationsPage extends StatefulWidget {
  final NotificationsController controller;

  const NotificationsPage({
    super.key,
    required this.controller,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
    widget.controller.load();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (controller.unreadCount > 0)
            TextButton(
              onPressed: controller.markAllAsRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: controller.load,
        child: controller.isLoading && controller.notifications.isEmpty
            ? ListView(children: const [SizedBox(height: 240)])
            : controller.notifications.isEmpty
                ? ListView(children: const [SizedBox(height: 240), Center(child: Text('No notifications yet.'))])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: controller.notifications.length,
                    separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final notification = controller.notifications[index];
                      return _NotificationCard(
                        notification: notification,
                        onTap: () => controller.markAsRead(notification),
                        muted: colors.textMuted,
                      );
                    },
                  ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;
  final Color muted;

  const _NotificationCard({
    required this.notification,
    required this.onTap,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            notification.isRead ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
            color: notification.isRead ? muted : null,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(notification.body),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _formatDate(notification.createdAt),
                  style: TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}
