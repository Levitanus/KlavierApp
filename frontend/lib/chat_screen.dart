import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth.dart';
import 'models/chat.dart';
import 'services/chat_service.dart';
import 'services/media_cache_service.dart';
import 'screens/chat_conversation.dart';
import 'config/app_config.dart';
import 'l10n/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final bool _isAdmin;
  int _activeTabIndex = 0;

  @override
  void initState() {
    super.initState();
    final authService = context.read<AuthService>();
    _isAdmin = authService.isAdmin;
    _tabController = TabController(length: _isAdmin ? 2 : 1, vsync: this);
    if (_isAdmin) {
      _tabController.addListener(_handleTabChange);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatService = context.read<ChatService>();
      chatService.loadThreads(mode: 'personal');
      if (!_isAdmin) {
        chatService.loadRelatedTeachers();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (_tabController.indexIsChanging) return;
    if (_activeTabIndex == _tabController.index) return;
    setState(() {
      _activeTabIndex = _tabController.index;
    });
    final chatService = context.read<ChatService>();
    final mode = _activeTabIndex == 1 ? 'admin' : 'personal';
    chatService.loadThreads(mode: mode);
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
    showDialog(context: context, builder: (context) => const _NewChatDialog());
  }

  void _showTeacherSelectionDialog() {
    final chatService = context.read<ChatService>();
    final teachers = chatService.relatedTeachers;

    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.chatNoTeachers ?? 'No teachers found',
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          AppLocalizations.of(context)?.chatSelectTeacher ?? 'Select Teacher',
        ),
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
      final newThread = chatService.threads.firstWhere(
        (t) => t.peerUserId == teacherId,
        orElse: () => ChatThread(
          id: -1,
          participantAId: 0,
          participantBId: null,
          peerUserId: null,
          peerName: null,
          isAdminChat: false,
          lastMessage: null,
          updatedAt: DateTime.now(),
          unreadCount: 0,
        ),
      );

      if (newThread.id != -1) {
        _openConversation(newThread);
      }
    } else if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatService.errorMessage ??
                (AppLocalizations.of(context)?.chatStartFailed ??
                    'Failed to start chat'),
          ),
        ),
      );
    }
  }

  Future<void> _sendAdminMessage() async {
    final chatService = context.read<ChatService>();
    final thread = await chatService.getOrCreateAdminThread();

    if (!mounted) return;

    if (thread == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatService.errorMessage ??
                (AppLocalizations.of(context)?.chatAdminOpenFailed ??
                    'Failed to open admin chat'),
          ),
        ),
      );
      return;
    }

    _openConversation(thread);
  }

  @override
  Widget build(BuildContext context) {
    final isAdminTab = _isAdmin && _activeTabIndex == 1;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.chatMessages ?? 'Messages'),
        elevation: 0,
        bottom: _isAdmin
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Consumer<ChatService>(
                  builder: (context, chatService, _) => TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(
                        child: _TabLabel(
                          label:
                              AppLocalizations.of(context)?.chatChats ??
                              'Chats',
                          count: chatService.personalUnreadCount,
                        ),
                      ),
                      Tab(
                        child: _TabLabel(
                          label:
                              AppLocalizations.of(context)?.chatAdmin ??
                              'Admin',
                          count: chatService.adminUnreadCount,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
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
                  Text(
                    AppLocalizations.of(context)?.chatNoConversations ??
                        'No conversations yet',
                    style: const TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _showNewChatDialog,
                    icon: const Icon(Icons.add),
                    label: Text(
                      AppLocalizations.of(context)?.chatStartConversation ??
                          'Start a conversation',
                    ),
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
                showAdminPeerName: isAdminTab,
                onTap: () => _openConversation(thread),
              );
            },
          );
        },
      ),
      bottomNavigationBar: isAdminTab
          ? null
          : _BottomChatToolbar(
              onNewChat: _showNewChatDialog,
              onMessageTeacher: _showTeacherSelectionDialog,
              onMessageAdmin: _sendAdminMessage,
              showAdminButton: !_isAdmin,
              showTeacherButton: !_isAdmin,
            ),
    );
  }
}

class _ThreadListTile extends StatelessWidget {
  final ChatThread thread;
  final VoidCallback onTap;
  final bool showAdminPeerName;

  const _ThreadListTile({
    required this.thread,
    required this.onTap,
    required this.showAdminPeerName,
  });

  ImageProvider? _avatarImage() {
    final profileImage = thread.peerProfileImage;
    if (profileImage == null || profileImage.isEmpty) return null;
    return MediaCacheService.instance.imageProvider(
      '${AppConfig.instance.baseUrl}/uploads/profile_images/$profileImage',
    );
  }

  @override
  Widget build(BuildContext context) {
    final lastMsg = thread.lastMessage;
    final displayName = thread.isAdminChat && !showAdminPeerName
        ? (AppLocalizations.of(context)?.chatAdministration ?? 'Administration')
        : (thread.peerName ??
              (AppLocalizations.of(context)?.chatUnknownUser ?? 'Unknown'));
    final avatarImage = _avatarImage();
    final preview =
        lastMsg?.plainText ??
        (AppLocalizations.of(context)?.chatNoMessages ?? '(No messages)');

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundImage: avatarImage,
        child: avatarImage == null
            ? Text(displayName.isEmpty ? '?' : displayName[0].toUpperCase())
            : null,
      ),
      title: Text(displayName),
      subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: thread.unreadCount > 0
          ? CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              child: Text(
                thread.unreadCount.toString(),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                  fontSize: 12,
                ),
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
  final bool showAdminButton;
  final bool showTeacherButton;

  const _BottomChatToolbar({
    required this.onNewChat,
    required this.onMessageTeacher,
    required this.onMessageAdmin,
    required this.showAdminButton,
    required this.showTeacherButton,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        color: isDark ? colorScheme.outline : colorScheme.surface,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (showAdminButton) ...[
              ElevatedButton.icon(
                onPressed: onMessageAdmin,
                icon: const Icon(Icons.shield),
                label: Text(AppLocalizations.of(context)?.chatAdmin ?? 'Admin'),
              ),
              const SizedBox(width: 8),
            ],
            if (showTeacherButton) ...[
              ElevatedButton.icon(
                onPressed: onMessageTeacher,
                icon: const Icon(Icons.person),
                label: Text(
                  AppLocalizations.of(context)?.chatTeachers ?? 'Teachers',
                ),
              ),
              const SizedBox(width: 8),
            ],
            ElevatedButton.icon(
              onPressed: onNewChat,
              icon: const Icon(Icons.add),
              label: Text(
                AppLocalizations.of(context)?.chatNewChat ?? 'New Chat',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final int count;

  const _TabLabel({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return Text(label);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
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
  List<ChatUserOption> _allUsers = [];
  List<ChatUserOption> _filteredUsers = [];
  bool _isLoading = false;
  String? _errorMessage;
  static String get _baseUrl => AppConfig.instance.baseUrl;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final chatService = context.read<ChatService>();
    await chatService.loadAvailableUsers();

    if (!mounted) return;
    setState(() {
      _allUsers = List<ChatUserOption>.from(chatService.availableUsers);
      _filteredUsers = List<ChatUserOption>.from(_allUsers);
      _errorMessage = chatService.errorMessage;
      _isLoading = false;
    });
  }

  void _searchUsers(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() {
        _filteredUsers = List<ChatUserOption>.from(_allUsers);
      });
      return;
    }

    setState(() {
      _filteredUsers = _allUsers.where((user) {
        return user.fullName.toLowerCase().contains(trimmed) ||
            user.username.toLowerCase().contains(trimmed);
      }).toList();
    });
  }

  Future<void> _startChat(ChatUserOption user) async {
    final chatService = context.read<ChatService>();
    final success = await chatService.startThread(user.userId);

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            chatService.errorMessage ??
                (AppLocalizations.of(context)?.chatStartFailed ??
                    'Failed to start chat'),
          ),
        ),
      );
      return;
    }

    final thread = chatService.threads.firstWhere(
      (t) => t.peerUserId == user.userId,
      orElse: () => ChatThread(
        id: -1,
        participantAId: 0,
        participantBId: null,
        peerUserId: null,
        peerName: null,
        isAdminChat: false,
        lastMessage: null,
        updatedAt: DateTime.now(),
        unreadCount: 0,
      ),
    );

    if (thread.id == -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.chatThreadNotFound ??
                'Chat created, but thread not found',
          ),
        ),
      );
      return;
    }

    Navigator.of(context).pop();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatConversationScreen(thread: thread),
      ),
    );
  }

  ImageProvider? _avatarImage(ChatUserOption user) {
    final profileImage = user.profileImage;
    if (profileImage == null || profileImage.isEmpty) return null;
    return MediaCacheService.instance.imageProvider(
      '$_baseUrl/uploads/profile_images/$profileImage',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      title: Text(
        AppLocalizations.of(context)?.chatStartNew ?? 'Start New Chat',
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText:
                    AppLocalizations.of(context)?.chatSearchUsers ??
                    'Search users...',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (_filteredUsers.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  AppLocalizations.of(context)?.commonNoResults ??
                      'No results found',
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = _filteredUsers[index];
                    final initials = user.fullName.isNotEmpty
                        ? user.fullName
                              .trim()
                              .split(' ')
                              .map((part) => part[0])
                              .take(2)
                              .join()
                        : user.username.isNotEmpty
                        ? user.username[0]
                        : '?';
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: _avatarImage(user),
                        child: _avatarImage(user) == null
                            ? Text(initials.toUpperCase())
                            : null,
                      ),
                      title: Text(user.fullName),
                      subtitle: Text(user.username),
                      onTap: () => _startChat(user),
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
