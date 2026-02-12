import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/chat.dart';
import 'websocket_service.dart';

const String _baseUrl = 'http://localhost:8080/chat';

class ChatService extends ChangeNotifier {
  String _token;
  final WebSocketService wsService;
  
  List<ChatThread> threads = [];
  Map<int, List<ChatMessage>> messagesByThread = {};
  List<RelatedTeacher> relatedTeachers = [];
  bool isLoading = false;
  bool isLoadingRelatedTeachers = false;
  String? errorMessage;
  String currentMode = 'personal'; // 'personal' or 'admin'
  
  // Track subscribed threads and listening state
  Set<int> subscribedThreads = {};
  bool _wsListenersRegistered = false;
  late final WsMessageCallback _chatMessageCallback = _handleNewMessage;
  late final WsMessageCallback _receiptCallback = _handleReceiptUpdate;
  late final WsMessageCallback _typingCallback = _handleTyping;
  late final WsConnectionCallback _connectionCallback = _handleConnectionChange;

  ChatService({required String token, required this.wsService}) : _token = token {
    wsService.onConnectionStateChanged(_connectionCallback);
  }

  String get token => _token;

  void updateToken(String token) {
    if (token == _token) return;
    _token = token;
    subscribedThreads.clear();
  }

  Future<void> loadThreads({String mode = 'personal'}) async {
    isLoading = true;
    errorMessage = null;
    currentMode = mode;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/threads?mode=$mode'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        threads = data.map((t) => ChatThread.fromJson(t as Map<String, dynamic>)).toList();
        errorMessage = null;
      } else {
        errorMessage = 'Failed to load threads: ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Error loading threads: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  Future<void> loadThreadMessages(int threadId, {int limit = 50, int offset = 0}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/threads/$threadId/messages?limit=$limit&offset=$offset'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        messagesByThread[threadId] = data
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
        errorMessage = null;
        
        // Subscribe to thread for real-time updates
        _subscribeToThread(threadId);
      } else {
        errorMessage = 'Failed to load messages: ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Error loading messages: $e';
    }

    isLoading = false;
    notifyListeners();
  }

  void _subscribeToThread(int threadId) {
    if (subscribedThreads.contains(threadId)) return;
    
    subscribedThreads.add(threadId);
    _ensureWsListeners();

    if (!wsService.isConnected && !wsService.isConnecting) {
      wsService.connect();
    }
    
    // Subscribe to thread via WebSocket
    wsService.subscribeToThread(threadId);
  }

  void _ensureWsListeners() {
    if (_wsListenersRegistered) return;
    _wsListenersRegistered = true;

    // Listen for new messages
    wsService.on('chat_message', _chatMessageCallback);

    // Listen for receipt updates
    wsService.on('receipt', _receiptCallback);

    // Listen for typing indicators
    wsService.on('typing', _typingCallback);
  }

  void _handleConnectionChange(bool connected) {
    if (!connected) return;
    _ensureWsListeners();
    for (final threadId in subscribedThreads) {
      wsService.subscribeToThread(threadId);
    }
  }

  void _handleNewMessage(WsMessage wsMessage) {
    final threadId = wsMessage.threadId;
    if (threadId == null || !messagesByThread.containsKey(threadId)) return;
    
    try {
      final messageData = wsMessage.data;
      final bodyJson = messageData['body'] as Map<String, dynamic>? ?? {};
      final senderName = messageData['sender_name'] as String? ?? 'Unknown';
      
      // Parse the incoming message
      final newMessage = ChatMessage(
        id: messageData['message_id'] as int,
        senderId: messageData['sender_id'] as int,
        senderName: senderName,
        bodyJson: bodyJson,
        createdAt: DateTime.parse(messageData['created_at'] as String),
        receipts: const [],
      );
      
      // Add to the thread's message list
      messagesByThread[threadId]!.add(newMessage);
      notifyListeners();
    } catch (e) {
      print('Error handling new message: $e');
    }
  }

  void _handleReceiptUpdate(WsMessage wsMessage) {
    final threadId = wsMessage.threadId;
    if (threadId == null || !messagesByThread.containsKey(threadId)) return;
    
    try {
      final receiptData = wsMessage.data;
      final messageId = receiptData['message_id'] as int;
      final recipientId = receiptData['recipient_id'] as int;
      final newState = receiptData['state'] as String;
      final updatedAt = DateTime.now();
      
      // Find and update the message receipt
      for (final message in messagesByThread[threadId]!) {
        if (message.id == messageId) {
          final receipts = List<MessageReceipt>.from(message.receipts);
          final receiptIndex = receipts.indexWhere(
            (receipt) => receipt.recipientId == recipientId,
          );

          if (receiptIndex >= 0) {
            receipts[receiptIndex] = MessageReceipt(
              recipientId: recipientId,
              state: newState,
              updatedAt: updatedAt,
            );
          } else {
            receipts.add(MessageReceipt(
              recipientId: recipientId,
              state: newState,
              updatedAt: updatedAt,
            ));
          }

          final updated = ChatMessage(
            id: message.id,
            senderId: message.senderId,
            senderName: message.senderName,
            bodyJson: message.bodyJson,
            createdAt: message.createdAt,
            receipts: receipts,
          );
          
          final index = messagesByThread[threadId]!.indexOf(message);
          messagesByThread[threadId]![index] = updated;
          notifyListeners();
          break;
        }
      }
    } catch (e) {
      print('Error handling receipt update: $e');
    }
  }

  void _handleTyping(WsMessage wsMessage) {
    // TODO: Implement typing indicator UI
    // final userId = wsMessage.data['user_id'] as int;
    // final isTyping = wsMessage.data['is_typing'] as bool;
  }

  Future<bool> startThread(int targetUserId) async {
    errorMessage = null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/threads'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'target_user_id': targetUserId}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final threadId = data['thread_id'] as int;
        
        // Reload threads to show the new one
        await loadThreads(mode: currentMode);
        return true;
      } else {
        errorMessage = 'Failed to start thread: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      errorMessage = 'Error starting thread: $e';
      return false;
    }
  }

  Future<bool> sendMessage(int threadId, Map<String, dynamic> quillJson) async {
    errorMessage = null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/threads/$threadId/messages'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'body': quillJson}),
      );

      if (response.statusCode == 201) {
        // Reload messages to show the new one
        await loadThreadMessages(threadId);
        notifyListeners();
        return true;
      } else {
        errorMessage = 'Failed to send message: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      errorMessage = 'Error sending message: $e';
      return false;
    }
  }

  Future<bool> sendAdminMessage(Map<String, dynamic> quillJson) async {
    errorMessage = null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/message'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'body': quillJson}),
      );

      if (response.statusCode == 201) {
        // Reload threads to show the new admin thread
        await loadThreads(mode: currentMode);
        return true;
      } else {
        errorMessage = 'Failed to send message: ${response.statusCode}';
        return false;
      }
    } catch (e) {
      errorMessage = 'Error sending message: $e';
      return false;
    }
  }

  Future<void> updateMessageReceipt(int messageId, String state) async {
    try {
      final response = await http.patch(
        Uri.parse('$_baseUrl/messages/$messageId/receipt'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({'state': state}),
      );

      if (response.statusCode != 200) {
        print('Failed to update receipt: ${response.statusCode}');
      }
    } catch (e) {
      print('Error updating receipt: $e');
    }
  }

  Future<void> loadRelatedTeachers() async {
    isLoadingRelatedTeachers = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/related-teachers'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        relatedTeachers = data
            .map((t) => RelatedTeacher.fromJson(t as Map<String, dynamic>))
            .toList();
        errorMessage = null;
      } else {
        errorMessage = 'Failed to load teachers: ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Error loading teachers: $e';
    }

    isLoadingRelatedTeachers = false;
    notifyListeners();
  }

  @override
  void dispose() {
    // Clean up WebSocket subscriptions
    if (_wsListenersRegistered) {
      wsService.off('chat_message', _chatMessageCallback);
      wsService.off('receipt', _receiptCallback);
      wsService.off('typing', _typingCallback);
    }
    wsService.removeConnectionListener(_connectionCallback);
    subscribedThreads.clear();
    super.dispose();
  }
}
