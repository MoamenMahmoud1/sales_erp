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
    final colors = AppColors.of(context);
    final controller = widget.controller;

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
            ? const ListView(children: [SizedBox(height: 240), Center(child: CircularProgressIndicator())])
            : controller.notifications.isEmpty
                ? const ListView(children: [SizedBox(height: 240), Center(child: Text('No notifications yet.'))])
                : ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    itemCount: controller.notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
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
    final colors = AppColors.of(context);
    return AppCard(
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: notification.isRead ? colors.surfaceMuted : colors.primaryContainer,
                  borderRadius: AppRadius.mdAll,
                ),
                child: Icon(
                  notification.notificationType == 'approval_approved'
                      ? Icons.check_circle_outline_rounded
                      : notification.notificationType == 'approval_rejected'
                          ? Icons.cancel_outlined
                          : Icons.notifications_none_rounded,
                  color: notification.isRead ? muted : colors.primary,
                ),
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
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(notification.body, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 6),
                    Text(
                      _formatCreatedAt(notification.createdAt),
                      style: TextStyle(fontSize: 11, color: muted),
                    ),
                  ],
                ),
              ),
              if (!notification.isRead)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: colors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatCreatedAt(DateTime value) {
    final local = value.toLocal();
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day}/${local.month}/${local.year} ${local.hour}:$minute';
  }
}
