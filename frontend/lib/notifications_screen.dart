import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/notification_service.dart';
import 'widgets/notification_widget.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

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
