import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth.dart';
import '../models/chat.dart';
import '../services/chat_service.dart';
import 'chat_conversation.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authService = context.read<AuthService>();
      final chatService = context.read<ChatService>();
      if (!authService.isAuthenticated) return;
      final mode = authService.isAdmin ? 'admin' : 'personal';
      chatService.loadThreads(mode: mode);
      if (!authService.isAdmin) {
        chatService.loadRelatedTeachers();
      }
    });
  }

  RelatedTeacher? _matchTeacher(String value, List<RelatedTeacher> teachers) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final byId = int.tryParse(trimmed);
    if (byId != null) {
      for (final teacher in teachers) {
        if (teacher.userId == byId) {
          return teacher;
        }
      }
      return null;
    }
    final lowered = trimmed.toLowerCase();
    for (final teacher in teachers) {
      if (teacher.name.toLowerCase().contains(lowered)) {
        return teacher;
      }
    }
    return null;
  }

  Future<void> _showNewChatDialog(ChatService chatService) async {
    final controller = TextEditingController();
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: const Text('Start a new chat'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Username or display name',
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
            child: const Text('Open'),
          ),
        ],
      ),
    );

    if (created != true) return;

    final value = controller.text.trim();
    if (value.isEmpty) return;

    final teacher = _matchTeacher(value, chatService.relatedTeachers);
    if (teacher == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Teacher not found in quick access list')),
      );
      return;
    }

    final threadCreated = await chatService.startThread(teacher.userId);
    if (threadCreated != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(chatService.errorMessage ?? 'Failed to start chat')),
      );
      return;
    }

    await chatService.loadThreads(mode: chatService.currentMode);
    if (chatService.threads.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chat created, but thread list is empty')),
      );
      return;
    }
    final thread = chatService.threads.firstWhere(
      (item) => item.peerUserId == teacher.userId,
      orElse: () => chatService.threads.first,
    );

    if (!mounted) return;
    _openThread(thread);
  }

  void _openThread(ChatThread thread) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatConversationScreen(thread: thread),
      ),
    );
  }

  Widget _buildThreadList(List<ChatThread> threads) {
    if (threads.isEmpty) {
      return const Center(
        child: Text('No conversations yet'),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: threads.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final thread = threads[index];
        final title = thread.peerName ?? 'Unknown';
        final lastMessage = thread.lastMessage?.plainText ?? 'No messages yet';
        return ListTile(
          onTap: () => _openThread(thread),
          leading: CircleAvatar(
            child: Text(title.isNotEmpty ? title[0] : '?'),
          ),
          title: Text(title),
          subtitle: Text(lastMessage),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(thread.updatedAt),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (thread.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    thread.unreadCount.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildNonAdminToolbar(
    ChatService chatService,
    List<RelatedTeacher> teachers,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    await chatService.loadThreads(mode: 'admin');
                  },
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Message Admin'),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _showNewChatDialog(chatService),
                icon: const Icon(Icons.add_comment),
                label: const Text('New Chat'),
              ),
            ],
          ),
          if (teachers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Quick access',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: teachers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final teacher = teachers[index];
                  return ActionChip(
                    avatar: CircleAvatar(
                      backgroundColor: Colors.grey.shade400,
                      radius: 6,
                    ),
                    label: Text(teacher.name),
                    onPressed: () async {
                      final created = await chatService.startThread(teacher.userId);
                      if (!created) return;
                      await chatService.loadThreads(mode: chatService.currentMode);
                      final thread = chatService.threads.firstWhere(
                        (item) => item.peerUserId == teacher.userId,
                        orElse: () => chatService.threads.first,
                      );
                      if (!mounted) return;
                      _openThread(thread);
                    },
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hours = time.hour.toString().padLeft(2, '0');
    final minutes = time.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, ChatService>(
      builder: (context, authService, chatService, child) {
        if (!authService.isAuthenticated) {
          return const Center(child: Text('Please sign in to continue.'));
        }

        if (authService.isAdmin) {
          return Column(
            children: [
              if (chatService.isLoading)
                const LinearProgressIndicator(minHeight: 2),
              if (chatService.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    chatService.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Personal'),
                      selected: chatService.currentMode == 'personal',
                      onSelected: (selected) {
                        if (selected) {
                          chatService.loadThreads(mode: 'personal');
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Admin'),
                      selected: chatService.currentMode == 'admin',
                      onSelected: (selected) {
                        if (selected) {
                          chatService.loadThreads(mode: 'admin');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _buildThreadList(chatService.threads),
              ),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (chatService.isLoading)
              const LinearProgressIndicator(minHeight: 2),
            if (chatService.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  chatService.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Text(
                'My Chats',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _buildThreadList(chatService.threads),
            ),
            _buildNonAdminToolbar(chatService, chatService.relatedTeachers),
          ],
        );
      },
    );
  }
}
