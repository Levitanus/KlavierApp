import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
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
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _editorController = quill.QuillController.basic();
    _scrollController = ScrollController();

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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    if (widget.thread == null) return;

    final chatService = context.read<ChatService>();
    await chatService.loadThreadMessages(widget.thread!.id);
    
    if (mounted) {
      setState(() {});
      // Scroll to bottom
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message sent')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(chatService.errorMessage ?? 'Failed to send message')),
        );
      }
    }
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
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _MessageBubble(message: message);
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
          const SizedBox(height: 8),
          // Editor with simplified toolbar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                // Toolbar buttons
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.format_bold),
                        onPressed: () {
                          _editorController.formatSelection(quill.Attribute.bold);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_italic),
                        onPressed: () {
                          _editorController.formatSelection(quill.Attribute.italic);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.format_underline),
                        onPressed: () {
                          _editorController.formatSelection(quill.Attribute.underline);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.code),
                        onPressed: () {
                          _editorController.formatSelection(quill.Attribute.codeBlock);
                        },
                      ),
                    ],
                  ),
                ),
                // Editor
                SizedBox(
                  height: 100,
                  child: quill.QuillEditor.basic(
                    controller: _editorController,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Send button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSending ? null : _sendMessage,
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                label: Text(_isSending ? 'Sending...' : 'Send'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.senderName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.plainText),
                const SizedBox(height: 4),
                _buildReceiptStatus(message.receipts),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatTime(message.createdAt),
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptStatus(List<MessageReceipt> receipts) {
    if (receipts.isEmpty) return const SizedBox.shrink();

    // Show the most recent receipt status
    final latestReceipt = receipts.reduce((a, b) => 
        a.updatedAt.isAfter(b.updatedAt) ? a : b);

    String icon = '✓';
    Color color = Colors.grey;

    if (latestReceipt.isRead) {
      icon = '✓✓';
      color = Colors.blue;
    } else if (latestReceipt.isDelivered) {
      icon = '✓✓';
      color = Colors.grey;
    }

    return Text(
      icon,
      style: TextStyle(color: color, fontSize: 10),
    );
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
