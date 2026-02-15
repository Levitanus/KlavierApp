import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth.dart';
import '../models/chat.dart';
import '../home_screen.dart';
import '../services/chat_service.dart';
import '../screens/chat_conversation.dart';

Future<void> navigateToNotificationRoute(
  BuildContext context,
  String route,
  Map<String, dynamic>? metadata,
) async {
  final uri = Uri.parse(route);
  final navigator = Navigator.of(context, rootNavigator: true);

  if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'admin') {
    if (uri.pathSegments.length >= 2 && uri.pathSegments[1] == 'users') {
      final username = uri.pathSegments.length > 2 ? uri.pathSegments[2] : null;
      final page = HomeScreen(adminUsername: username);
      if (navigator.canPop()) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (context) => page),
        );
      } else {
        navigator.push(
          MaterialPageRoute(builder: (context) => page),
        );
      }
    } else {
      if (navigator.canPop()) {
        navigator.pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        navigator.push(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  } else if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'hometasks') {
    final rawStudentId = metadata?['student_id'] ?? uri.queryParameters['student_id'];
    final studentId = rawStudentId is int
        ? rawStudentId
        : (rawStudentId is String ? int.tryParse(rawStudentId) : null);
    final page = HomeScreen(initialStudentId: studentId);
    if (navigator.canPop()) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => page),
      );
    } else {
      navigator.push(
        MaterialPageRoute(builder: (context) => page),
      );
    }
  } else if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'feeds') {
    final rawFeedId = metadata?['feed_id'] ?? uri.queryParameters['feed_id'];
    final rawPostId = metadata?['post_id'] ?? uri.queryParameters['post_id'];
    final feedId = rawFeedId is int
        ? rawFeedId
        : (rawFeedId is String ? int.tryParse(rawFeedId) : null);
    final postId = rawPostId is int
        ? rawPostId
        : (rawPostId is String ? int.tryParse(rawPostId) : null);
    final page = HomeScreen(
      initialFeedId: feedId,
      initialPostId: postId,
    );
    if (navigator.canPop()) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => page),
      );
    } else {
      navigator.push(
        MaterialPageRoute(builder: (context) => page),
      );
    }
  } else if (uri.pathSegments.isNotEmpty && uri.pathSegments[0] == 'chat') {
    final threadId = uri.pathSegments.length > 1
        ? int.tryParse(uri.pathSegments[1])
        : null;
    if (threadId != null) {
      final authService = context.read<AuthService>();
      final chatService = context.read<ChatService>();
      await chatService.loadThreads(mode: 'personal');
      if (authService.isAdmin) {
        await chatService.loadThreads(mode: 'admin', setCurrent: false);
      }
      final threads = authService.isAdmin
          ? [...chatService.personalThreads, ...chatService.adminThreads]
          : chatService.threads;
      ChatThread? match;
      for (final thread in threads) {
        if (thread.id == threadId) {
          match = thread;
          break;
        }
      }
      if (match != null) {
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(thread: match!),
          ),
        );
        return;
      }
    }
    if (navigator.canPop()) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      navigator.push(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  } else {
    if (navigator.canPop()) {
      navigator.pushReplacement(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      navigator.push(
        MaterialPageRoute(builder: (context) => const HomeScreen()),
      );
    }
  }
}
