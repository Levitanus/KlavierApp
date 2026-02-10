class NotificationModel {
  final int id;
  final int userId;
  final String type;
  final String title;
  final NotificationBody body;
  final DateTime createdAt;
  final DateTime? readAt;
  final String priority;

  NotificationModel({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    this.readAt,
    required this.priority,
  });

  bool get isRead => readAt != null;
  bool get isUnread => readAt == null;

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'],
      userId: json['user_id'],
      type: json['type'] ?? json['notification_type'],
      title: json['title'],
      body: NotificationBody.fromJson(json['body']),
      createdAt: DateTime.parse(json['created_at']),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at']) : null,
      priority: json['priority'] ?? 'normal',
    );
  }
}

class NotificationBody {
  final String type;
  final String title;
  final String? route;
  final NotificationContent content;
  final Map<String, dynamic>? metadata;

  NotificationBody({
    required this.type,
    required this.title,
    this.route,
    required this.content,
    this.metadata,
  });

  factory NotificationBody.fromJson(Map<String, dynamic> json) {
    return NotificationBody(
      type: json['type'],
      title: json['title'],
      route: json['route'],
      content: NotificationContent.fromJson(json['content']),
      metadata: json['metadata'],
    );
  }
}

class NotificationContent {
  final List<ContentBlock> blocks;
  final List<ActionButton>? actions;

  NotificationContent({
    required this.blocks,
    this.actions,
  });

  factory NotificationContent.fromJson(Map<String, dynamic> json) {
    return NotificationContent(
      blocks: (json['blocks'] as List)
          .map((block) => ContentBlock.fromJson(block))
          .toList(),
      actions: json['actions'] != null
          ? (json['actions'] as List)
              .map((action) => ActionButton.fromJson(action))
              .toList()
          : null,
    );
  }
}

abstract class ContentBlock {
  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    switch (type) {
      case 'text':
        return TextBlock.fromJson(json);
      case 'image':
        return ImageBlock.fromJson(json);
      case 'divider':
        return DividerBlock();
      case 'spacer':
        return SpacerBlock(height: json['height'] ?? 8);
      default:
        return TextBlock(text: 'Unknown block type: $type');
    }
  }
}

class TextBlock implements ContentBlock {
  final String text;
  final String? style;

  TextBlock({required this.text, this.style});

  factory TextBlock.fromJson(Map<String, dynamic> json) {
    return TextBlock(
      text: json['text'],
      style: json['style'],
    );
  }
}

class ImageBlock implements ContentBlock {
  final String url;
  final String? alt;
  final int? width;
  final int? height;

  ImageBlock({
    required this.url,
    this.alt,
    this.width,
    this.height,
  });

  factory ImageBlock.fromJson(Map<String, dynamic> json) {
    return ImageBlock(
      url: json['url'],
      alt: json['alt'],
      width: json['width'],
      height: json['height'],
    );
  }
}

class DividerBlock implements ContentBlock {}

class SpacerBlock implements ContentBlock {
  final int height;

  SpacerBlock({required this.height});
}

class ActionButton {
  final String label;
  final String? route;
  final String? action;
  final bool primary;
  final String? icon;

  ActionButton({
    required this.label,
    this.route,
    this.action,
    required this.primary,
    this.icon,
  });

  factory ActionButton.fromJson(Map<String, dynamic> json) {
    return ActionButton(
      label: json['label'],
      route: json['route'],
      action: json['action'],
      primary: json['primary'] ?? false,
      icon: json['icon'],
    );
  }
}
