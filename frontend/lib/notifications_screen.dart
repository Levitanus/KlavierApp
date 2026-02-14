import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';
import 'widgets/notification_widget.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllAsRead();
    });
  }

  Future<void> _markAllAsRead() async {
    final notificationService = context.read<NotificationService>();
    await notificationService.fetchNotifications();
    final unreadIds = notificationService.notifications
        .where((notification) => notification.isUnread)
        .map((notification) => notification.id)
        .toList();
    if (unreadIds.isNotEmpty) {
      await notificationService.markAsRead(unreadIds);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notificationService = context.watch<NotificationService>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: NotificationDropdownContent(
        notificationService: notificationService,
      ),
    );
  }
}
