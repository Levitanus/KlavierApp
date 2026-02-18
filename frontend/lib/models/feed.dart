import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'chat.dart';

int _parseIntField(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final raw = json[key];
    if (raw == null) continue;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final parsed = int.tryParse(raw);
      if (parsed != null) return parsed;
    }
  }
  throw FormatException('Missing integer field: ${keys.join(' or ')}');
}

class Feed {
  final int id;
  final String ownerType;
  final int? ownerUserId;
  final int? ownerGroupId;
  final String title;
  final DateTime createdAt;

  Feed({
    required this.id,
    required this.ownerType,
    required this.ownerUserId,
    required this.ownerGroupId,
    required this.title,
    required this.createdAt,
  });

  factory Feed.fromJson(Map<String, dynamic> json) {
    return Feed(
      id: json['id'] as int,
      ownerType: json['owner_type'] as String,
      ownerUserId: json['owner_user_id'] as int?,
      ownerGroupId: json['owner_group_id'] as int?,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Feed &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          ownerType == other.ownerType &&
          ownerUserId == other.ownerUserId &&
          ownerGroupId == other.ownerGroupId &&
          title == other.title &&
          createdAt == other.createdAt;

  @override
  int get hashCode =>
      id.hashCode ^
      ownerType.hashCode ^
      ownerUserId.hashCode ^
      ownerGroupId.hashCode ^
      title.hashCode ^
      createdAt.hashCode;
}

class FeedSettings {
  final int feedId;
  final bool allowStudentPosts;

  FeedSettings({required this.feedId, required this.allowStudentPosts});

  factory FeedSettings.fromJson(Map<String, dynamic> json) {
    return FeedSettings(
      feedId: json['feed_id'] as int,
      allowStudentPosts: json['allow_student_posts'] as bool,
    );
  }
}

class FeedUserSettings {
  final int feedId;
  final int userId;
  final bool autoSubscribeNewPosts;
  final bool notifyNewPosts;

  FeedUserSettings({
    required this.feedId,
    required this.userId,
    required this.autoSubscribeNewPosts,
    required this.notifyNewPosts,
  });

  factory FeedUserSettings.fromJson(Map<String, dynamic> json) {
    return FeedUserSettings(
      feedId: json['feed_id'] as int,
      userId: json['user_id'] as int,
      autoSubscribeNewPosts: json['auto_subscribe_new_posts'] as bool,
      notifyNewPosts: json['notify_new_posts'] as bool,
    );
  }
}

class FeedPost {
  final int id;
  final int feedId;
  final int authorUserId;
  final String? title;
  final List<dynamic> content;
  final List<ChatAttachment> attachments;
  final bool isImportant;
  final int? importantRank;
  final bool allowComments;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isRead;

  FeedPost({
    required this.id,
    required this.feedId,
    required this.authorUserId,
    required this.title,
    required this.content,
    required this.attachments,
    required this.isImportant,
    required this.importantRank,
    required this.allowComments,
    required this.createdAt,
    required this.updatedAt,
    required this.isRead,
  });

  factory FeedPost.fromJson(Map<String, dynamic> json) {
    return FeedPost(
      id: _parseIntField(json, ['id']),
      feedId: _parseIntField(json, ['feed_id', 'feedId']),
      authorUserId: _parseIntField(json, ['author_user_id', 'authorUserId']),
      title: json['title'] as String?,
      content: (json['content'] as List<dynamic>? ?? []).toList(),
      attachments:
          (json['attachments'] as List?)
              ?.map((a) => ChatAttachment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      isImportant: json['is_important'] as bool? ?? false,
      importantRank: json['important_rank'] as int?,
      allowComments: json['allow_comments'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isRead: json['is_read'] as bool? ?? false,
    );
  }

  quill.Document toDocument() {
    try {
      return quill.Document.fromJson(content);
    } catch (_) {
      return quill.Document();
    }
  }
}

class FeedComment {
  final int id;
  final int postId;
  final int authorUserId;
  final int? parentCommentId;
  final List<dynamic> content;
  final List<ChatAttachment> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  FeedComment({
    required this.id,
    required this.postId,
    required this.authorUserId,
    required this.parentCommentId,
    required this.content,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FeedComment.fromJson(Map<String, dynamic> json) {
    return FeedComment(
      id: _parseIntField(json, ['id']),
      postId: _parseIntField(json, ['post_id', 'postId']),
      authorUserId: _parseIntField(json, ['author_user_id', 'authorUserId']),
      parentCommentId:
          (json['parent_comment_id'] as num?)?.toInt() ??
          (json['parentCommentId'] as num?)?.toInt(),
      content: (json['content'] as List<dynamic>? ?? []).toList(),
      attachments:
          (json['attachments'] as List?)
              ?.map((a) => ChatAttachment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'post_id': postId,
      'author_user_id': authorUserId,
      'parent_comment_id': parentCommentId,
      'content': content,
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  quill.Document toDocument() {
    try {
      return quill.Document.fromJson(content);
    } catch (_) {
      return quill.Document();
    }
  }
}

class MediaUploadResult {
  final int id;
  final String url;
  final String mimeType;
  final int sizeBytes;

  MediaUploadResult({
    required this.id,
    required this.url,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory MediaUploadResult.fromJson(Map<String, dynamic> json) {
    return MediaUploadResult(
      id: json['id'] as int,
      url: json['url'] as String,
      mimeType: json['mime_type'] as String,
      sizeBytes: json['size_bytes'] as int,
    );
  }
}
