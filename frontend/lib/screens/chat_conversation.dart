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
import '../widgets/quill_embed_builders.dart';
import '../utils/voice_recorder.dart';

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
  final VoiceRecorder _voiceRecorder = VoiceRecorder();
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

  Future<void> _toggleVoiceRecording() async {
    if (_voiceRecorder.isRecording) {
      final audio = await _voiceRecorder.stop();
      if (audio == null) return;

      setState(() {
        _isUploadingAttachment = true;
      });

      final chatService = context.read<ChatService>();
      final uploaded = await chatService.uploadMedia(
        mediaType: 'audio',
        bytes: audio.bytes,
        filename: 'voice.${audio.extension}',
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
      return;
    }

    final available = await _voiceRecorder.isAvailable();
    if (!available) {
      _pickAttachment(attachmentType: 'voice', inline: true);
      return;
    }

    await _voiceRecorder.start();
    if (mounted) {
      setState(() {});
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

    // Get Quill JSON
    final quillJson = _editorController.document.toDelta().toJson();
    final attachments = _pendingAttachments.map((a) => a.input).toList();

    bool success = false;
    
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

    if (mounted) {
      setState(() {
        _isSending = false;
      });

      if (success) {
        _editorController.clear();
        setState(() {
          _pendingAttachments.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(chatService.errorMessage ?? 'Failed to send message')),
        );
      }
    }
  }

  void _insertNewline() {
    final selection = _editorController.selection;
    final offset = selection.baseOffset;
    if (offset < 0) return;
    _editorController.replaceText(
      offset,
      0,
      '\n',
      TextSelection.collapsed(offset: offset + 1),
    );
  }

  Future<void> _promptForLink() async {
    final selection = _editorController.selection;
    if (selection.isCollapsed) return;

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Insert link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'URL',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final url = controller.text.trim();
    if (url.isEmpty) return;

    _editorController.formatSelection(
      quill.LinkAttribute(url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.thread.peerName ?? 'Unknown';

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(),
          ),
          _buildMessageComposer(),
        ],
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
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 8,
      ),
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Shortcuts(
                    shortcuts: {
                      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB):
                          const _FormatIntent(_FormatType.bold),
                      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI):
                          const _FormatIntent(_FormatType.italic),
                      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyU):
                          const _FormatIntent(_FormatType.underline),
                      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
                          const _FormatIntent(_FormatType.link),
                      LogicalKeySet(LogicalKeyboardKey.enter):
                          const _SendIntent(),
                      LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.enter):
                          const _NewlineIntent(),
                    },
                    child: Actions(
                      actions: {
                        _FormatIntent: CallbackAction<_FormatIntent>(
                          onInvoke: (intent) {
                            switch (intent.type) {
                              case _FormatType.bold:
                                _editorController.formatSelection(quill.Attribute.bold);
                                break;
                              case _FormatType.italic:
                                _editorController.formatSelection(quill.Attribute.italic);
                                break;
                              case _FormatType.underline:
                                _editorController.formatSelection(quill.Attribute.underline);
                                break;
                              case _FormatType.link:
                                _promptForLink();
                                break;
                            }
                            return null;
                          },
                        ),
                        _SendIntent: CallbackAction<_SendIntent>(
                          onInvoke: (intent) {
                            if (!_isSending) {
                              _sendMessage();
                            }
                            return null;
                          },
                        ),
                        _NewlineIntent: CallbackAction<_NewlineIntent>(
                          onInvoke: (intent) {
                            _insertNewline();
                            return null;
                          },
                        ),
                      },
                      child: Focus(
                        focusNode: _editorFocusNode,
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent) {
                            final isShiftPressed = event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                                event.logicalKey == LogicalKeyboardKey.shiftRight ||
                                HardwareKeyboard.instance.isShiftPressed;
                            if (event.logicalKey == LogicalKeyboardKey.enter &&
                                isShiftPressed) {
                              _insertNewline();
                              return KeyEventResult.handled;
                            }
                            if (event.logicalKey == LogicalKeyboardKey.enter &&
                                !isShiftPressed) {
                              if (!_isSending) {
                                _sendMessage();
                              }
                              return KeyEventResult.handled;
                            }
                          }
                          return KeyEventResult.ignored;
                        },
                        child: SizedBox(
                          height: 100,
                          child: GestureDetector(
                            onTap: () {
                              if (!_editorFocusNode.hasFocus) {
                                _editorFocusNode.requestFocus();
                              }
                            },
                            child: quill.QuillEditor.basic(
                              controller: _editorController,
                              config: quill.QuillEditorConfig(
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
                        ),
                      ),
                    ),
                  ),
                ),
                if (_isTouchPlatform()) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Format',
                    icon: const Icon(Icons.text_format),
                    onPressed: _showFormatMenu,
                  ),
                ],
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Attach',
                  icon: Icon(_isUploadingAttachment ? Icons.hourglass_top : Icons.attach_file),
                  onPressed: _isUploadingAttachment ? null : _showAttachmentMenu,
                ),
                const SizedBox(width: 4),
                IconButton(
                  tooltip: _voiceRecorder.isRecording ? 'Stop recording' : 'Record voice',
                  icon: Icon(
                    _voiceRecorder.isRecording ? Icons.stop_circle : Icons.mic,
                    color: _voiceRecorder.isRecording ? Colors.red : null,
                  ),
                  onPressed: _toggleVoiceRecording,
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: _isSending ? null : _sendMessage,
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isTouchPlatform() {
    if (kIsWeb) return false;
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  void _showFormatMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.format_bold),
                title: const Text('Bold'),
                onTap: () {
                  _editorController.formatSelection(quill.Attribute.bold);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_italic),
                title: const Text('Italic'),
                onTap: () {
                  _editorController.formatSelection(quill.Attribute.italic);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.format_underline),
                title: const Text('Underline'),
                onTap: () {
                  _editorController.formatSelection(quill.Attribute.underline);
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Insert link'),
                onTap: () {
                  Navigator.of(context).pop();
                  _promptForLink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet<void>(
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

  Future<void> _editMessage(ChatMessage message) async {
    final controller = quill.QuillController(
      document: message.quillController.document,
      selection: const TextSelection.collapsed(offset: 0),
    );

    final updated = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit message'),
        content: SizedBox(
          width: 600,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              quill.QuillSimpleToolbar(
                controller: controller,
                config: const quill.QuillSimpleToolbarConfig(
                  showAlignmentButtons: true,
                  showCodeBlock: false,
                  showQuote: false,
                ),
              ),
              SizedBox(
                height: 180,
                child: quill.QuillEditor.basic(
                  controller: controller,
                  config: quill.QuillEditorConfig(
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

enum _FormatType { bold, italic, underline, link }

class _FormatIntent extends Intent {
  final _FormatType type;
  const _FormatIntent(this.type);
}

class _SendIntent extends Intent {
  const _SendIntent();
}

class _NewlineIntent extends Intent {
  const _NewlineIntent();
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
    final bubbleColor = isOwn ? Colors.blue.shade100 : Colors.grey.shade100;
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
                          child: IgnorePointer(
                            child: quill.QuillEditor.basic(
                              controller: controller,
                              config: quill.QuillEditorConfig(
                                scrollable: false,
                                autoFocus: false,
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
                          child: _buildAttachmentWidget(attachment),
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

  Widget _buildAttachmentWidget(ChatAttachment attachment) {
    final url = normalizeMediaUrl(attachment.url);
    switch (attachment.attachmentType) {
      case 'image':
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: Image.network(url, fit: BoxFit.contain),
        );
      case 'video':
        return ChatVideoPlayer(url: url);
      case 'audio':
        return ChatAudioPlayer(url: url, label: 'Audio');
      case 'voice':
        return ChatAudioPlayer(url: url, label: 'Voice message');
      case 'file':
        return Row(
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
      default:
        return Text('Unsupported attachment: ${attachment.attachmentType}');
    }
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
