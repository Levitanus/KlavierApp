import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notification_service.dart';
import '../models/notification.dart';
import '../home_screen.dart';
import 'package:intl/intl.dart';

void _navigateToRoute(BuildContext context, String route, Map<String, dynamic>? metadata) {
  // Parse the route and navigate accordingly
  final uri = Uri.parse(route);
  
  if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'admin') {
    if (uri.pathSegments.length >= 2 && uri.pathSegments[1] == 'users') {
      // Route: /admin/users/{username}
      final username = uri.pathSegments.length > 2 ? uri.pathSegments[2] : null;
      
      // Navigate to HomeScreen with admin panel opened for specific user
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => HomeScreen(adminUsername: username),
        ),
      );
    } else {
      // Generic admin route - go back to home
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    }
  } else if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'hometasks') {
    final rawStudentId = metadata?['student_id'];
    final studentId = rawStudentId is int ? rawStudentId : null;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(initialStudentId: studentId),
      ),
    );
  } else if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'feeds') {
    final rawFeedId = metadata?['feed_id'];
    final rawPostId = metadata?['post_id'];
    final feedId = rawFeedId is int ? rawFeedId : null;
    final postId = rawPostId is int ? rawPostId : null;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => HomeScreen(
          initialFeedId: feedId,
          initialPostId: postId,
        ),
      ),
    );
  } else {
    // Handle other routes - just go back to home
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      ),
    );
  }
}

class NotificationBellWidget extends StatelessWidget {
  const NotificationBellWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationService>(
      builder: (context, notificationService, child) {
        final unreadCount = notificationService.unreadCount;

        return Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                _showNotificationsDropdown(context, notificationService);
              },
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    unreadCount > 99 ? '99+' : unreadCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsDropdown(
    BuildContext context,
    NotificationService notificationService,
  ) {
    // Fetch latest notifications
    notificationService.fetchNotifications();

    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        MediaQuery.of(context).size.width - 400,
        kToolbarHeight,
        0,
        0,
      ),
      items: [
        PopupMenuItem(
          enabled: false,
          child: SizedBox(
            width: 380,
            height: 500,
            child: NotificationDropdownContent(
              notificationService: notificationService,
            ),
          ),
        ),
      ],
    );
  }
}

class NotificationDropdownContent extends StatefulWidget {
  final NotificationService notificationService;

  const NotificationDropdownContent({
    super.key,
    required this.notificationService,
  });

  @override
  State<NotificationDropdownContent> createState() =>
      _NotificationDropdownContentState();
}

class _NotificationDropdownContentState
    extends State<NotificationDropdownContent> {
  bool _showUnreadOnly = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            const Expanded(
              child: Text(
                'Notifications',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilterChip(
                  label: const Text('Unread'),
                  selected: _showUnreadOnly,
                  onSelected: (selected) {
                    setState(() {
                      _showUnreadOnly = selected;
                      widget.notificationService.fetchNotifications(
                        unreadOnly: selected,
                      );
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    widget.notificationService.fetchNotifications(
                      unreadOnly: _showUnreadOnly,
                    );
                  },
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ],
        ),
        const Divider(),
        // Notifications list
        Expanded(
          child: Consumer<NotificationService>(
            builder: (context, service, child) {
              if (service.isLoading && service.notifications.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (service.notifications.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_none, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: service.notifications.length,
                itemBuilder: (context, index) {
                  final notification = service.notifications[index];
                  return NotificationTile(
                    notification: notification,
                    onTap: () {
                      if (notification.isUnread) {
                        service.markAsRead([notification.id]);
                      }
                      Navigator.of(context).pop();
                      // Navigate to route if specified
                      if (notification.body.route != null) {
                        _navigateToRoute(context, notification.body.route!, notification.body.metadata);
                      }
                    },
                    onDelete: () {
                      service.deleteNotification(notification.id);
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class NotificationTile extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    required this.onDelete,
  });

  Color _getPriorityColor() {
    switch (notification.priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'low':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('notification_${notification.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (_) => onDelete(),
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: notification.isUnread
                ? Colors.blue.withValues(alpha: 0.05)
                : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: _getPriorityColor(),
                width: 4,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (notification.isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        notification.title,
                        style: TextStyle(
                          fontWeight: notification.isUnread
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Text(
                      _formatTime(notification.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Render content blocks
                ...notification.body.content.blocks
                    .take(3)
                    .map((block) => _buildContentBlock(block)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContentBlock(ContentBlock block) {
    if (block is TextBlock) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _buildStyledText(
          block.text,
          fontSize: _getTextSize(block.style),
          baseWeight: _getTextWeight(block.style),
        ),
      );
    } else if (block is SpacerBlock) {
      return SizedBox(height: block.height.toDouble());
    } else if (block is DividerBlock) {
      return const Divider();
    }
    return const SizedBox.shrink();
  }

  /// Parse simple markdown (**bold**) and return a RichText widget
  Widget _buildStyledText(String text, {double fontSize = 13, FontWeight baseWeight = FontWeight.normal}) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastIndex = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before the match
      if (match.start > lastIndex) {
        spans.add(TextSpan(
          text: text.substring(lastIndex, match.start),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: baseWeight,
            color: Colors.grey[700],
          ),
        ));
      }
      
      // Add bold text
      spans.add(TextSpan(
        text: match.group(1),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
        ),
      ));
      
      lastIndex = match.end;
    }

    // Add remaining text
    if (lastIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIndex),
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: baseWeight,
          color: Colors.grey[700],
        ),
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  double _getTextSize(String? style) {
    switch (style) {
      case 'title':
        return 16;
      case 'subtitle':
        return 14;
      case 'caption':
        return 11;
      default:
        return 13;
    }
  }

  FontWeight _getTextWeight(String? style) {
    switch (style) {
      case 'title':
      case 'subtitle':
        return FontWeight.bold;
      default:
        return FontWeight.normal;
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(time);
    }
  }
}
