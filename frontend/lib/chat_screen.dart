import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/chat.dart';
import 'services/chat_service.dart';
import 'screens/chat_conversation.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController? _tabController;
  bool isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  void _initializeScreen() {
    final chatService = context.read<ChatService>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Load threads and related teachers after first build
      chatService.loadThreads(mode: 'personal');
      chatService.loadRelatedTeachers();
    });

    // Check if user is admin - this would require access to user role info
    // For now, we'll assume based on whether they can see admin chat
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  void _openConversation(ChatThread thread) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationScreen(thread: thread),
      ),
    );
  }

  void _showNewChatDialog() {
    showDialog(
      context: context,
      builder: (context) => const _NewChatDialog(),
    );
  }

  void _showTeacherSelectionDialog() {
    final chatService = context.read<ChatService>();
    final teachers = chatService.relatedTeachers;

    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No teachers found')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Teacher'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              return ListTile(
                title: Text(teacher.name),
                onTap: () {
                  Navigator.pop(context);
                  _startChatWithTeacher(teacher.userId);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _startChatWithTeacher(int teacherId) async {
    final chatService = context.read<ChatService>();
    final success = await chatService.startThread(teacherId);
    
    if (success && mounted) {
      // The new thread should be in the list now
      await chatService.loadThreads(mode: 'personal');
      // Find and open the new thread
      final newThread = chatService.threads
          .firstWhere((t) => t.peerUserId == teacherId, orElse: () => ChatThread(
            id: -1, participantAId: 0, participantBId: null, peerUserId: null,
            peerName: null, isAdminChat: false, lastMessage: null,
            updatedAt: DateTime.now(), unreadCount: 0,
          ));
      
      if (newThread.id != -1) {
        _openConversation(newThread);
      }
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chatService.errorMessage ?? 'Failed to start chat')),
      );
    }
  }

  void _sendAdminMessage() {
    // Open empty message composer for admin
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ChatConversationScreen(thread: null, toAdmin: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        elevation: 0,
      ),
      body: Consumer<ChatService>(
        builder: (context, chatService, _) {
          if (chatService.isLoading && chatService.threads.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (chatService.threads.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.mail_outline, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _showNewChatDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Start a conversation'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: chatService.threads.length,
            itemBuilder: (context, index) {
              final thread = chatService.threads[index];
              return _ThreadListTile(
                thread: thread,
                onTap: () => _openConversation(thread),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _BottomChatToolbar(
        onNewChat: _showNewChatDialog,
        onMessageTeacher: _showTeacherSelectionDialog,
        onMessageAdmin: _sendAdminMessage,
      ),
    );
  }
}

class _ThreadListTile extends StatelessWidget {
  final ChatThread thread;
  final VoidCallback onTap;

  const _ThreadListTile({
    required this.thread,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final lastMsg = thread.lastMessage;
    final displayName = thread.isAdminChat ? 'Administration' : (thread.peerName ?? 'Unknown');
    final preview = lastMsg?.plainText ?? '(No messages)';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        child: Text(displayName.isEmpty ? '?' : displayName[0]),
      ),
      title: Text(displayName),
      subtitle: Text(
        preview,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: thread.unreadCount > 0
          ? CircleAvatar(
              backgroundColor: Colors.blue,
              child: Text(
                thread.unreadCount.toString(),
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            )
          : null,
    );
  }
}

class _BottomChatToolbar extends StatelessWidget {
  final VoidCallback onNewChat;
  final VoidCallback onMessageTeacher;
  final VoidCallback onMessageAdmin;

  const _BottomChatToolbar({
    required this.onNewChat,
    required this.onMessageTeacher,
    required this.onMessageAdmin,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        color: Colors.white,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ElevatedButton.icon(
              onPressed: onMessageAdmin,
              icon: const Icon(Icons.shield),
              label: const Text('Admin'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onMessageTeacher,
              icon: const Icon(Icons.person),
              label: const Text('Teachers'),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: onNewChat,
              icon: const Icon(Icons.add),
              label: const Text('New Chat'),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewChatDialog extends StatefulWidget {
  const _NewChatDialog();

  @override
  State<_NewChatDialog> createState() => _NewChatDialogState();
}

class _NewChatDialogState extends State<_NewChatDialog> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _searchUsers(String query) {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    // TODO: Implement user search from backend
    // For now, just show a placeholder
    setState(() {
      _searchResults = [];
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Start New Chat'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search users...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 16),
            if (_isSearching)
              const CircularProgressIndicator()
            else if (_searchResults.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('No results found'),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final user = _searchResults[index];
                    return ListTile(
                      title: Text(user['name'] ?? 'Unknown'),
                      onTap: () {
                        Navigator.pop(context);
                        // Start chat with this user
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
