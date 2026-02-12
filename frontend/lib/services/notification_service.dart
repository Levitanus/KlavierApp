import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/notification.dart';
import '../auth.dart';

class NotificationService extends ChangeNotifier {
  final AuthService authService;
  final String baseUrl;
  
  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;
  bool _isLoading = false;
  Timer? _pollTimer;

  NotificationService({
    required this.authService,
    this.baseUrl = 'http://localhost:8080',
  }) {
    // Start polling for notifications every 30 seconds
    _startPolling();
  }

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;

  void _startPolling() {
    _pollTimer?.cancel();
    // Initial fetch
    fetchNotifications();
    // Poll every 30 seconds
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (
      _) {
      fetchUnreadCount();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> fetchNotifications({
    bool unreadOnly = false,
    int limit = 50,
  }) async {
    if (authService.token == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final queryParams = {
        'limit': limit.toString(),
        if (unreadOnly) 'unread_only': 'true',
      };

      final uri = Uri.parse('$baseUrl/api/notifications')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _notifications = data
            .map((json) => NotificationModel.fromJson(json))
            .toList();
        _unreadCount = _notifications.where((n) => n.isUnread).length;
        notifyListeners();
      } else {
        debugPrint('Failed to fetch notifications: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchUnreadCount() async {
    if (authService.token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/notifications/unread-count'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newCount = data['unread_count'] ?? 0;
        if (newCount != _unreadCount) {
          _unreadCount = newCount;
          notifyListeners();
          // If count changed, fetch full list
          if (newCount > 0) {
            fetchNotifications();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching unread count: $e');
    }
  }

  Future<void> markAsRead(List<int> notificationIds) async {
    if (authService.token == null) return;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/notifications/mark-read'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'notification_ids': notificationIds,
        }),
      );

      if (response.statusCode == 200) {
        // Update local state
        for (var id in notificationIds) {
          final index = _notifications.indexWhere((n) => n.id == id);
          if (index != -1 && _notifications[index].isUnread) {
            _notifications[index] = NotificationModel(
              id: _notifications[index].id,
              userId: _notifications[index].userId,
              type: _notifications[index].type,
              title: _notifications[index].title,
              body: _notifications[index].body,
              createdAt: _notifications[index].createdAt,
              readAt: DateTime.now(),
              priority: _notifications[index].priority,
            );
          }
        }
        _unreadCount = _notifications.where((n) => n.isUnread).length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error marking notifications as read: $e');
    }
  }

  Future<void> deleteNotification(int notificationId) async {
    if (authService.token == null) return;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/notifications/$notificationId'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        _notifications.removeWhere((n) => n.id == notificationId);
        _unreadCount = _notifications.where((n) => n.isUnread).length;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error deleting notification: $e');
    }
  }
}
