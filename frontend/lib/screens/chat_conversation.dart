import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../auth.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import '../services/audio_player_service.dart';
import '../utils/media_download.dart';
import '../widgets/quill_embed_builders.dart';
import '../widgets/quill_editor_composer.dart';
import '../widgets/floating_audio_player.dart';

class ChatConversationScreen extends StatefulWidget {
  final ChatThread thread;

  const ChatConversationScreen({
    Key? key,
    required this.thread,
  }) : super(key: key);

  @override
  State<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends State<ChatConversationScreen> {
  late quill.QuillController _editorController;
  late ScrollController _scrollController;
  late FocusNode _editorFocusNode;
  bool _isSending = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final Set<int> _readMarkedMessageIds = {};
  static const int _pageSize = 50;
  final List<_PendingAttachment> _pendingAttachments = [];
  bool _isUploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _editorController = quill.QuillController.basic();
    _scrollController = ScrollController();
    _editorFocusNode = FocusNode();
    _scrollController.addListener(_handleScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load message history after first build
      _loadMessages();
    });
  }

  @override
  void dispose() {
    _editorController.dispose();
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    // Skip loading if thread is virtual (id == -1)
    if (widget.thread.id == -1) {
      setState(() {
        _hasMore = false;
      });
      return;
    }

    final chatService = context.read<ChatService>();
    final count = await chatService.loadThreadMessages(
      widget.thread.id,
      limit: _pageSize,
      offset: 0,
      append: false,
    );
    
    if (mounted) {
      _hasMore = count >= _pageSize;
      setState(() {});
      // Scroll to bottom
      _scrollToBottom();
      _markMessagesRead();
    }
  }

  Future<void> _markMessagesRead() async {
    final chatService = context.read<ChatService>();
    final authService = context.read<AuthService>();
    final currentUserId = authService.userId;
    final isAdminChat = widget.thread.isAdminChat;
    final isAdminViewer = authService.isAdmin;
    final peerUserId = widget.thread.peerUserId;

    final messages = chatService.messagesByThread[widget.thread.id] ?? [];
    bool updatedAny = false;
    for (final message in messages) {
      final isOwn = _isOwnMessage(
        message,
        currentUserId: currentUserId,
        isAdminChat: isAdminChat,
        isAdminViewer: isAdminViewer,
        peerUserId: peerUserId,
      );
      if (isOwn) continue;
      if (_readMarkedMessageIds.contains(message.id)) continue;

      _readMarkedMessageIds.add(message.id);
      await chatService.updateMessageReceipt(message.id, 'read');
      updatedAny = true;
    }

    if (updatedAny) {
      await chatService.loadThreads(mode: chatService.currentMode);
    }
  }

  bool _hasUnreadMessages(
    List<ChatMessage> messages,
    int? currentUserId,
    bool isAdminChat,
    bool isAdminViewer,
    int? peerUserId,
  ) {
    for (final message in messages) {
      final isOwn = _isOwnMessage(
        message,
        currentUserId: currentUserId,
        isAdminChat: isAdminChat,
        isAdminViewer: isAdminViewer,
        peerUserId: peerUserId,
      );
      if (isOwn) continue;
      if (_readMarkedMessageIds.contains(message.id)) continue;
      return true;
    }
    return false;
  }

  bool _isOwnMessage(
    ChatMessage message, {
    required int? currentUserId,
    required bool isAdminChat,
    required bool isAdminViewer,
    required int? peerUserId,
  }) {
    if (currentUserId != null) {
      return message.senderId == currentUserId;
    }

    if (!isAdminChat && peerUserId != null) {
      return message.senderId != peerUserId;
    }

    if (isAdminChat && !isAdminViewer) {
      return message.senderId == widget.thread.participantAId;
    }

    return false;
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 80) {
      _loadMoreMessages();
    }
  }

  Future<void> _loadMoreMessages() async {
    setState(() {
      _isLoadingMore = true;
    });

    final chatService = context.read<ChatService>();
    final currentCount = chatService.messagesByThread[widget.thread.id]?.length ?? 0;
    final count = await chatService.loadThreadMessages(
      widget.thread.id,
      limit: _pageSize,
      offset: currentCount,
      append: true,
    );

    if (!mounted) return;
    setState(() {
      _isLoadingMore = false;
      if (count < _pageSize) {
        _hasMore = false;
      }
    });
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.minScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _insertEmbed(String type, String url) {
    final selection = _editorController.selection;
    final index = selection.baseOffset < 0
        ? _editorController.document.length
        : selection.baseOffset;

    quill.BlockEmbed embed;
    switch (type) {
      case 'image':
        embed = quill.BlockEmbed.image(url);
        break;
      case 'video':
        embed = quill.BlockEmbed.video(url);
        break;
      case 'audio':
      case 'voice':
      case 'file':
        embed = quill.BlockEmbed.custom(
          quill.CustomBlockEmbed(type, url),
        );
        break;
      default:
        embed = quill.BlockEmbed.custom(
          quill.CustomBlockEmbed('file', url),
        );
    }

    _editorController.document.insert(index, embed);
    _editorController.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );
  }

  Future<void> _pickAttachment({
    required String attachmentType,
    required bool inline,
  }) async {
    if (_isUploadingAttachment) return;

    final allowed = <String, List<String>>{
      'image': ['jpg', 'jpeg', 'png', 'webp'],
      'audio': ['mp3', 'm4a', 'ogg', 'opus', 'wav'],
      'voice': ['ogg', 'opus', 'm4a', 'mp3', 'wav'],
      'video': ['mp4', 'webm', 'mov', 'mkv'],
      'file': [],
    };

    final type = attachmentType == 'file' ? FileType.any : FileType.custom;
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: type == FileType.custom ? allowed[attachmentType] : null,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _isUploadingAttachment = true;
    });

    final chatService = context.read<ChatService>();
    final mediaType = attachmentType == 'voice' ? 'audio' : attachmentType;
    final uploaded = await chatService.uploadMedia(
      mediaType: mediaType,
      bytes: bytes,
      filename: file.name,
    );

    if (!mounted) return;

    if (uploaded == null) {
      setState(() {
        _isUploadingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chatService.errorMessage ?? 'Failed to upload media')),
      );
      return;
    }

    final attachment = _PendingAttachment(
      input: ChatAttachmentInput(
        mediaId: uploaded.mediaId,
        attachmentType: attachmentType,
      ),
      url: uploaded.url,
      attachmentType: attachmentType,
      inline: inline,
    );

    setState(() {
      _pendingAttachments.add(attachment);
      _isUploadingAttachment = false;
    });

    if (inline) {
      _insertEmbed(attachmentType, uploaded.url);
    }
  }

  Future<void> _sendMessage() async {
    final chatService = context.read<ChatService>();

    if (_editorController.document.isEmpty()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message cannot be empty')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    bool success = false;
    try {
      // Get Quill JSON
      final quillJson = _editorController.document.toDelta().toJson();
      final attachments = _pendingAttachments.map((a) => a.input).toList();

      // Only use admin message endpoint for virtual threads (user creating first message to admin)
      if (widget.thread.isAdminChat && widget.thread.id == -1) {
        // Non-admin user sending first message to admin
        final threadId = await chatService.sendAdminMessage(
          {'ops': quillJson},
          attachments: attachments,
        );
        success = threadId != null;

        if (success) {
          // Thread was just created, navigate to the real thread
          final realThread = chatService.personalThreads.firstWhere(
            (t) => t.id == threadId,
            orElse: () => widget.thread,
          );
          if (mounted && realThread.id != -1) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => ChatConversationScreen(thread: realThread),
              ),
            );
            return;
          }
        }
      } else {
        // All other cases: regular peer chat, admin replying in admin chat
        success = await chatService.sendMessageWithAttachments(
          widget.thread.id,
          {'ops': quillJson},
          attachments: attachments,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }

    if (!mounted) return;

    if (success) {
      _editorController.clear();
      setState(() {
        _pendingAttachments.clear();
      });
      // Scroll to bottom to show the new message
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chatService.errorMessage ?? 'Failed to send message')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.thread.peerName ?? 'Unknown';

    return ChangeNotifierProvider(
      create: (_) => AudioPlayerService(),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(displayName),
        ),
        body: Column(
          children: [
            const FloatingAudioPlayer(),
            Expanded(
              child: _buildMessageList(),
            ),
            _buildMessageComposer(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatService>(
      builder: (context, chatService, _) {
        // For virtual threads (id == -1), show empty state
        final messages = widget.thread.id == -1 
            ? <ChatMessage>[]
            : (chatService.messagesByThread[widget.thread.id] ?? []);
        final authService = context.read<AuthService>();
        final currentUserId = authService.userId;
        final isAdminChat = widget.thread.isAdminChat;
        final isAdminViewer = authService.isAdmin;
        final hasUnread = _hasUnreadMessages(
          messages,
          currentUserId,
          isAdminChat,
          isAdminViewer,
          widget.thread.peerUserId,
        );
        if (hasUnread) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _markMessagesRead();
            }
          });
        }

        if (messages.isEmpty && !chatService.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No messages yet'),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true,
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final isOwn = _isOwnMessage(
              message,
              currentUserId: currentUserId,
              isAdminChat: isAdminChat,
              isAdminViewer: isAdminViewer,
              peerUserId: widget.thread.peerUserId,
            );
            final showSenderName = isAdminChat && (isAdminViewer || !isOwn);
            return _MessageBubble(
              message: message,
              isOwn: isOwn,
              showSenderName: showSenderName,
              onEdit: isOwn ? () => _editMessage(message) : null,
            );
          },
        );
      },
    );
  }

  Widget _buildMessageComposer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(3, 4, 3, 4),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_pendingAttachments.isNotEmpty)
            SizedBox(
              height: 48,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                scrollDirection: Axis.horizontal,
                itemCount: _pendingAttachments.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final item = _pendingAttachments[index];
                  return Chip(
                    label: Text(item.label),
                    onDeleted: () {
                      setState(() {
                        _pendingAttachments.removeAt(index);
                      });
                    },
                  );
                },
              ),
            ),
          QuillEditorComposer(
            controller: _editorController,
            config: const QuillEditorComposerConfig(
              minHeight: 40,
              maxHeight: 120,
            ),
            onSendPressed: _isSending ? null : _sendMessage,
            onAttachmentSelected: _showAttachmentMenu,
            onVoiceRecorded: _onVoiceRecorded,
          ),
        ],
      ),
    );
  }

  Future<void> _showAttachmentMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text('Image'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'image', inline: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('Video'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'video', inline: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack),
                title: const Text('Audio'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'audio', inline: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Text('File'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'file', inline: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onVoiceRecorded(List<int> bytes, String filename) async {
    if (bytes.isEmpty) return;

    setState(() {
      _isUploadingAttachment = true;
    });

    final chatService = context.read<ChatService>();
    final uploaded = await chatService.uploadMedia(
      mediaType: 'voice',
      bytes: bytes,
      filename: filename,
    );

    if (!mounted) return;

    if (uploaded == null) {
      setState(() {
        _isUploadingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chatService.errorMessage ?? 'Failed to upload voice message')),
      );
      return;
    }

    final attachment = _PendingAttachment(
      input: ChatAttachmentInput(
        mediaId: uploaded.mediaId,
        attachmentType: 'voice',
      ),
      url: uploaded.url,
      attachmentType: 'voice',
      inline: true,
    );

    setState(() {
      _pendingAttachments.add(attachment);
      _isUploadingAttachment = false;
    });

    _insertEmbed('voice', uploaded.url);
  }

  Future<void> _editMessage(ChatMessage message) async {
    final controller = quill.QuillController(
      document: message.quillController.document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: const Text('Edit message'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QuillEditorComposer(
                controller: controller,
                config: const QuillEditorComposerConfig(
                  minHeight: 80,
                  maxHeight: 180,
                  showAttachButton: false,
                  showVoiceButton: false,
                  showSendButton: false,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (updated != true || !mounted) return;

    final chatService = context.read<ChatService>();
    final body = controller.document.toDelta().toJson();
    final result = await chatService.updateMessage(message.id, {'ops': body});

    if (!mounted) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chatService.errorMessage ?? 'Failed to update message')),
      );
    }
  }
}

class _PendingAttachment {
  final ChatAttachmentInput input;
  final String url;
  final String attachmentType;
  final bool inline;

  _PendingAttachment({
    required this.input,
    required this.url,
    required this.attachmentType,
    required this.inline,
  });

  String get label => inline ? '$attachmentType (inline)' : attachmentType;
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;
  final bool showSenderName;
  final VoidCallback? onEdit;

  const _MessageBubble({
    required this.message,
    required this.isOwn,
    required this.showSenderName,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bubbleColor = isOwn
        ? colorScheme.secondaryContainer
        : colorScheme.surfaceContainerHigh;
    final align = isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final name = message.senderName;
    final controller = _buildReadOnlyController();
    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    final attachments = _visibleAttachments();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: align,
          children: [
            if (showSenderName) ...[
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
            ],
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: quill.QuillEditor.basic(
                            controller: controller,
                            config: quill.QuillEditorConfig(
                              scrollable: false,
                              autoFocus: false,
                              showCursor: false,
                              padding: EdgeInsets.zero,
                              embedBuilders: [
                                ImageEmbedBuilder(),
                                VideoEmbedBuilder(),
                                AudioEmbedBuilder(),
                                VoiceEmbedBuilder(),
                                FileEmbedBuilder(),
                              ],
                              unknownEmbedBuilder: UnknownEmbedBuilder(),
                            ),
                          ),
                        ),
                        if (onEdit != null)
                          IconButton(
                            icon: const Icon(Icons.edit, size: 16),
                            tooltip: 'Edit message',
                            onPressed: onEdit,
                          ),
                      ],
                    ),
                    if (attachments.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final attachment in attachments)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: _buildAttachmentWidget(context, attachment),
                        ),
                    ],
                    const SizedBox(height: 4),
                    if (isOwn) _buildReceiptStatus(message.receipts),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt, isEdited: message.isEdited),
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  quill.QuillController _buildReadOnlyController() {
    try {
      final ops = message.bodyJson['ops'] as List? ?? const [];
      final document = quill.Document.fromJson(ops);
      return quill.QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    } catch (_) {
      return quill.QuillController.basic();
    }
  }

  List<ChatAttachment> _visibleAttachments() {
    if (message.attachments.isEmpty) return [];
    final body = jsonEncode(message.bodyJson);
    return message.attachments
        .where((attachment) => !body.contains(attachment.url))
        .toList();
  }

  Widget _buildAttachmentWidget(BuildContext context, ChatAttachment attachment) {
    final url = normalizeMediaUrl(attachment.url);
    Widget content;
    switch (attachment.attachmentType) {
      case 'image':
        content = ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: Image.network(url, fit: BoxFit.contain),
        );
        break;
      case 'video':
        content = ChatVideoPlayer(url: url);
        break;
      case 'audio':
        content = ChatAudioPlayer(url: url, label: 'Audio');
        break;
      case 'voice':
        content = ChatAudioPlayer(url: url, label: 'Voice message');
        break;
      case 'file':
        content = Row(
          children: [
            const Icon(Icons.insert_drive_file),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                url.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
        break;
      default:
        content = Text('Unsupported attachment: ${attachment.attachmentType}');
    }

    return _buildAttachmentWithMenu(
      child: content,
      onDownload: () => _downloadAttachment(context, url),
    );
  }

  Widget _buildAttachmentWithMenu({
    required Widget child,
    required VoidCallback onDownload,
  }) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 32),
          child: child,
        ),
        PopupMenuButton<String>(
          tooltip: 'Attachment actions',
          onSelected: (value) {
            if (value == 'download') {
              onDownload();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'download',
              child: Text('Download source file'),
            ),
          ],
          icon: const Icon(Icons.more_horiz, size: 20),
        ),
      ],
    );
  }

  Future<void> _downloadAttachment(BuildContext context, String url) async {
    final filename = _fileNameFromUrl(url);
    final result = await downloadMedia(
      url: url,
      filename: filename,
      appFolderName: 'klavierapp',
    );

    if (!context.mounted) return;

    final message = result.success
        ? (result.filePath != null
            ? 'Saved to ${result.filePath}'
            : 'Download started')
        : (result.errorMessage ?? 'Download failed');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final name = uri.pathSegments.last.trim();
    return name.isEmpty ? null : name;
  }

  Widget _buildReceiptStatus(List<MessageReceipt> receipts) {
    if (receipts.isEmpty) {
      return Icon(Icons.done, size: 14, color: Colors.grey.shade600);
    }

    final hasRead = receipts.any((receipt) => receipt.isRead);
    final hasDelivered = receipts.any((receipt) => receipt.isDelivered);
    final icon = hasRead || hasDelivered ? Icons.done_all : Icons.done;
    final color = hasRead ? Colors.blue.shade700 : Colors.grey.shade700;

    return Icon(icon, size: 14, color: color);
  }

  String _formatTime(DateTime dateTime, {required bool isEdited}) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    final suffix = isEdited ? ' · edited' : '';

    if (diff.inMinutes < 1) {
      return 'now$suffix';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago$suffix';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago$suffix';
    } else if (dateTime.year == now.year) {
      return '${dateTime.month}/${dateTime.day}$suffix';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}$suffix';
    }
  }
}
