import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

class ChatThread {
  final int id;
  final int participantAId;
  final int? participantBId;
  final int? peerUserId; // The "other" participant for UI convenience
  final String? peerName;
  final bool isAdminChat;
  final ChatMessage? lastMessage;
  final DateTime updatedAt;
  final int unreadCount;

  ChatThread({
    required this.id,
    required this.participantAId,
    required this.participantBId,
    required this.peerUserId,
    required this.peerName,
    required this.isAdminChat,
    required this.lastMessage,
    required this.updatedAt,
    required this.unreadCount,
  });

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    return ChatThread(
      id: json['id'] as int,
      participantAId: json['participant_a_id'] as int,
      participantBId: json['participant_b_id'] as int?,
      peerUserId: json['peer_user_id'] as int?,
      peerName: json['peer_name'] as String?,
      isAdminChat: json['is_admin_chat'] as bool,
      lastMessage: json['last_message'] != null
          ? ChatMessage.fromJson(json['last_message'] as Map<String, dynamic>)
          : null,
      updatedAt: DateTime.parse(json['updated_at'] as String),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participant_a_id': participantAId,
      'participant_b_id': participantBId,
      'peer_user_id': peerUserId,
      'peer_name': peerName,
      'is_admin_chat': isAdminChat,
      'last_message': lastMessage?.toJson(),
      'updated_at': updatedAt.toIso8601String(),
      'unread_count': unreadCount,
    };
  }
}

class ChatMessage {
  final int id;
  final int senderId;
  final String senderName;
  final Map<String, dynamic> bodyJson; // Quill JSON
  final DateTime createdAt;
  final List<MessageReceipt> receipts;
  final List<ChatAttachment> attachments;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.bodyJson,
    required this.createdAt,
    required this.receipts,
    required this.attachments,
  });

  // Convert Quill JSON to QuillController for editing
  quill.QuillController get quillController {
    try {
      final document = quill.Document.fromJson(bodyJson['ops'] ?? []);
      return quill.QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (e) {
      print('Error creating QuillController: $e');
      return quill.QuillController.basic();
    }
  }

  // Get plain text representation
  String get plainText {
    try {
      final ops = bodyJson['ops'] as List?;
      if (ops == null || ops.isEmpty) return '';
      
      final stringBuffer = StringBuffer();
      for (final op in ops) {
        if (op is Map && op.containsKey('insert')) {
          stringBuffer.write(op['insert']);
        }
      }
      return stringBuffer.toString().trim();
    } catch (e) {
      return '';
    }
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as int,
      senderId: json['sender_id'] as int,
      senderName: json['sender_name'] as String? ?? 'Unknown',
      bodyJson: json['body'] as Map<String, dynamic>? ?? {},
      createdAt: DateTime.parse(json['created_at'] as String),
      receipts: (json['receipts'] as List?)
              ?.map((r) =>
                  MessageReceipt.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      attachments: (json['attachments'] as List?)
              ?.map((a) =>
                  ChatAttachment.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_name': senderName,
      'body': bodyJson,
      'created_at': createdAt.toIso8601String(),
      'receipts': receipts.map((r) => r.toJson()).toList(),
      'attachments': attachments.map((a) => a.toJson()).toList(),
    };
  }
}

class ChatAttachment {
  final int mediaId;
  final String attachmentType;
  final String url;
  final String mimeType;
  final int sizeBytes;

  ChatAttachment({
    required this.mediaId,
    required this.attachmentType,
    required this.url,
    required this.mimeType,
    required this.sizeBytes,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      mediaId: json['media_id'] as int,
      attachmentType: json['attachment_type'] as String? ?? 'file',
      url: json['url'] as String,
      mimeType: json['mime_type'] as String? ?? 'application/octet-stream',
      sizeBytes: json['size_bytes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'media_id': mediaId,
      'attachment_type': attachmentType,
      'url': url,
      'mime_type': mimeType,
      'size_bytes': sizeBytes,
    };
  }
}

class ChatAttachmentInput {
  final int mediaId;
  final String attachmentType;

  ChatAttachmentInput({
    required this.mediaId,
    required this.attachmentType,
  });

  Map<String, dynamic> toJson() {
    return {
      'media_id': mediaId,
      'attachment_type': attachmentType,
    };
  }
}

class MessageReceipt {
  final int recipientId;
  final String state; // 'sent', 'delivered', 'read'
  final DateTime updatedAt;

  MessageReceipt({
    required this.recipientId,
    required this.state,
    required this.updatedAt,
  });

  factory MessageReceipt.fromJson(Map<String, dynamic> json) {
    return MessageReceipt(
      recipientId: json['recipient_id'] as int,
      state: json['state'] as String? ?? 'sent',
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'recipient_id': recipientId,
      'state': state,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isSent => state == 'sent';
  bool get isDelivered => state == 'delivered';
  bool get isRead => state == 'read';
}

class RelatedTeacher {
  final int userId;
  final String name;

  RelatedTeacher({
    required this.userId,
    required this.name,
  });

  factory RelatedTeacher.fromJson(Map<String, dynamic> json) {
    return RelatedTeacher(
      userId: json['user_id'] as int,
      name: json['name'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'name': name,
    };
  }
}

class ChatUserOption {
  final int userId;
  final String username;
  final String fullName;
  final String? profileImage;

  ChatUserOption({
    required this.userId,
    required this.username,
    required this.fullName,
    required this.profileImage,
  });

  factory ChatUserOption.fromJson(Map<String, dynamic> json) {
    return ChatUserOption(
      userId: json['user_id'] as int,
      username: json['username'] as String,
      fullName: json['full_name'] as String? ?? json['username'] as String,
      profileImage: json['profile_image'] as String?,
    );
  }
}
