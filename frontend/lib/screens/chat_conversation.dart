import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import '../auth.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';

class ChatConversationScreen extends StatefulWidget {
  final ChatThread? thread;
  final bool toAdmin;

  const ChatConversationScreen({
    Key? key,
    this.thread,
    this.toAdmin = false,
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

  @override
  void initState() {
    super.initState();
    _editorController = quill.QuillController.basic();
    _scrollController = ScrollController();
    _editorFocusNode = FocusNode();
    _scrollController.addListener(_handleScroll);

    if (widget.thread != null && !widget.toAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Load message history after first build
        _loadMessages();
      });
    }
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
    if (widget.thread == null) return;

    final chatService = context.read<ChatService>();
    final count = await chatService.loadThreadMessages(
      widget.thread!.id,
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
    if (widget.thread == null) return;
    final chatService = context.read<ChatService>();
    final authService = context.read<AuthService>();
    final currentUserId = authService.userId;
    final peerUserId = widget.thread?.peerUserId;

    final messages = chatService.messagesByThread[widget.thread!.id] ?? [];
    bool updatedAny = false;
    for (final message in messages) {
      final isOwn = currentUserId != null
          ? message.senderId == currentUserId
          : (peerUserId != null && message.senderId != peerUserId);
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
    int? peerUserId,
  ) {
    for (final message in messages) {
      final isOwn = currentUserId != null
          ? message.senderId == currentUserId
          : (peerUserId != null && message.senderId != peerUserId);
      if (isOwn) continue;
      if (_readMarkedMessageIds.contains(message.id)) continue;
      return true;
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
    if (widget.thread == null) return;
    setState(() {
      _isLoadingMore = true;
    });

    final chatService = context.read<ChatService>();
    final currentCount = chatService.messagesByThread[widget.thread!.id]?.length ?? 0;
    final count = await chatService.loadThreadMessages(
      widget.thread!.id,
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

    bool success = false;
    if (widget.toAdmin) {
      success = await chatService.sendAdminMessage({'ops': quillJson});
    } else if (widget.thread != null) {
      success = await chatService.sendMessage(widget.thread!.id, {'ops': quillJson});
    }

    if (mounted) {
      setState(() {
        _isSending = false;
      });

      if (success) {
        _editorController.clear();
        
        // Reload messages
        if (widget.thread != null && !widget.toAdmin) {
          await _loadMessages();
        }
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
    final displayName = widget.toAdmin
        ? 'Administration'
        : (widget.thread?.peerName ?? 'Unknown');

    return Scaffold(
      appBar: AppBar(
        title: Text(displayName),
      ),
      body: Column(
        children: [
          Expanded(
            child: widget.toAdmin ? _buildNewMessageView() : _buildMessageList(),
          ),
          _buildMessageComposer(),
        ],
      ),
    );
  }

  Widget _buildNewMessageView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mail, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'Message Administration',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('Your message will be sent to all admin users'),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return Consumer<ChatService>(
      builder: (context, chatService, _) {
        if (widget.thread == null) {
          return const SizedBox.shrink();
        }

        final messages = chatService.messagesByThread[widget.thread!.id] ?? [];
        final authService = context.read<AuthService>();
        final currentUserId = authService.userId;
        final peerUserId = widget.thread?.peerUserId;
        final hasUnread = _hasUnreadMessages(messages, currentUserId, peerUserId);
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
            final isOwn = currentUserId != null
                ? message.senderId == currentUserId
                : (peerUserId != null && message.senderId != peerUserId);
            return _MessageBubble(message: message, isOwn: isOwn);
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

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwn;

  const _MessageBubble({required this.message, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isOwn ? Colors.blue.shade100 : Colors.grey.shade100;
    final align = isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final name = isOwn ? 'You' : message.senderName;
    final controller = _buildReadOnlyController();
    final maxWidth = MediaQuery.of(context).size.width * 0.72;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: align,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
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
                    quill.QuillEditor.basic(
                      controller: controller,
                      config: const quill.QuillEditorConfig(
                        scrollable: false,
                        autoFocus: false,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isOwn) _buildReceiptStatus(message.receipts),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(message.createdAt),
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

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours}h ago';
    } else if (dateTime.year == now.year) {
      return '${dateTime.month}/${dateTime.day}';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    }
  }
}
