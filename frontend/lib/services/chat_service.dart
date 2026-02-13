import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/chat.dart';
import 'websocket_service.dart';

const String _baseUrl = 'http://localhost:8080/chat';

class ChatService extends ChangeNotifier {
  String _token;
  int? _currentUserId;
  final WebSocketService wsService;
  
  List<ChatThread> threads = [];
  List<ChatThread> personalThreads = [];
  List<ChatThread> adminThreads = [];
  Map<int, List<ChatMessage>> messagesByThread = {};
  List<RelatedTeacher> relatedTeachers = [];
  List<ChatUserOption> availableUsers = [];
  bool isLoading = false;
  bool isLoadingRelatedTeachers = false;
  bool isLoadingAvailableUsers = false;
  String? errorMessage;
  String currentMode = 'personal'; // 'personal' or 'admin'
  bool _threadsLoaded = false;
  bool _isAdminUser = false;
  bool _adminCountsLoaded = false;
  int personalUnreadCount = 0;
  int adminUnreadCount = 0;
  
  // Track subscribed threads and listening state
  Set<int> subscribedThreads = {};
  bool _wsListenersRegistered = false;
  late final WsMessageCallback _chatMessageCallback = _handleNewMessage;
  late final WsMessageCallback _receiptCallback = _handleReceiptUpdate;
  late final WsMessageCallback _typingCallback = _handleTyping;
  late final WsConnectionCallback _connectionCallback = _handleConnectionChange;
  Timer? _threadRefreshTimer;
  Timer? _threadPollTimer;

  ChatService({required String token, required this.wsService}) : _token = token {
    wsService.onConnectionStateChanged(_connectionCallback);
  }

  String get token => _token;
  bool get isAdminUser => _isAdminUser;
  int get totalUnreadCount => personalUnreadCount + adminUnreadCount;

  void updateToken(String token) {
    if (token == _token) return;
    _token = token;
    subscribedThreads.clear();
    _threadsLoaded = false;
  }

  void updateCurrentUserId(int? userId) {
    _currentUserId = userId;
  }

  void updateIsAdmin(bool isAdmin) {
    _isAdminUser = isAdmin;
    if (!_isAdminUser) {
      _adminCountsLoaded = false;
      adminThreads = [];
      adminUnreadCount = 0;
    }
  }

  Future<void> ensureThreadsLoaded({String mode = 'personal'}) async {
    if (_threadsLoaded && (!_isAdminUser || _adminCountsLoaded)) return;
    await loadThreads(mode: mode);
    _threadsLoaded = true;
    if (_isAdminUser && !_adminCountsLoaded) {
      await loadThreads(mode: 'admin', setCurrent: false);
      _adminCountsLoaded = true;
    }
    _startThreadPolling();
  }

  void _startThreadPolling() {
    _threadPollTimer?.cancel();
    _threadPollTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      loadThreads(mode: currentMode);
      if (_isAdminUser) {
        final otherMode = currentMode == 'admin' ? 'personal' : 'admin';
        loadThreads(mode: otherMode, setCurrent: false);
      }
    });
  }

  Future<void> loadThreads({String mode = 'personal', bool setCurrent = true}) async {
    if (setCurrent) {
      isLoading = true;
      errorMessage = null;
      currentMode = mode;
      notifyListeners();
    }

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/threads?mode=$mode'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final loadedThreads = data
            .map((t) => ChatThread.fromJson(t as Map<String, dynamic>))
            .toList();

        if (mode == 'admin') {
          adminThreads = loadedThreads;
          adminUnreadCount = _calculateUnreadCount(loadedThreads);
        } else {
          personalThreads = loadedThreads;
          personalUnreadCount = _calculateUnreadCount(loadedThreads);
        }

        // Subscribe to all loaded threads for real-time updates
        for (final thread in loadedThreads) {
          _subscribeToThread(thread.id);
        }

        if (setCurrent) {
          threads = loadedThreads;
          errorMessage = null;
        }
      } else if (setCurrent) {
        errorMessage = 'Failed to load threads: ${response.statusCode}';
      }
    } catch (e) {
      if (setCurrent) {
        errorMessage = 'Error loading threads: $e';
      }
    }

    if (setCurrent) {
      isLoading = false;
    }
    notifyListeners();
  }

  int _calculateUnreadCount(List<ChatThread> items) {
    return items.fold<int>(0, (sum, thread) => sum + thread.unreadCount);
  }

  Future<int> loadThreadMessages(
    int threadId, {
    int limit = 50,
    int offset = 0,
    bool append = false,
  }) async {
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
        final newMessages = data
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList();
        if (!append && messagesByThread.containsKey(threadId)) {
          final existing = messagesByThread[threadId] ?? [];
          final existingById = {for (final message in existing) message.id: message};
          final mergedMessages = <ChatMessage>[];
          for (final message in newMessages) {
            final local = existingById[message.id];
            if (local == null) {
              mergedMessages.add(message);
              continue;
            }
            final mergedReceipts = _mergeReceipts(message.receipts, local.receipts);
            mergedMessages.add(ChatMessage(
              id: message.id,
              senderId: message.senderId,
              senderName: message.senderName,
              bodyJson: message.bodyJson,
              createdAt: message.createdAt,
              receipts: mergedReceipts,
              attachments: message.attachments,
            ));
          }
          messagesByThread[threadId] = mergedMessages;
        } else if (append && messagesByThread.containsKey(threadId)) {
          final existing = messagesByThread[threadId] ?? [];
          final existingIds = existing.map((m) => m.id).toSet();
          final merged = List<ChatMessage>.from(existing);
          for (final message in newMessages) {
            if (!existingIds.contains(message.id)) {
              merged.add(message);
            }
          }
          messagesByThread[threadId] = merged;
        } else {
          messagesByThread[threadId] = newMessages;
        }
        errorMessage = null;

        // Subscribe to thread for real-time updates
        _subscribeToThread(threadId);
        isLoading = false;
        notifyListeners();
        return newMessages.length;
      } else {
        errorMessage = 'Failed to load messages: ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Error loading messages: $e';
    }

    isLoading = false;
    notifyListeners();
    return 0;
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
    if (threadId == null) return;
    
    try {
      final messageData = wsMessage.data;
      final bodyJson = messageData['body'] as Map<String, dynamic>? ?? {};
        final senderName = messageData['sender_name'] as String? ?? 'Unknown';
        final attachmentsData = (messageData['attachments'] as List?) ?? [];
        final attachments = attachmentsData
          .map((a) => ChatAttachment.fromJson(a as Map<String, dynamic>))
          .toList();
      
      // Parse the incoming message
      final newMessage = ChatMessage(
        id: messageData['message_id'] as int,
        senderId: messageData['sender_id'] as int,
        senderName: senderName,
        bodyJson: bodyJson,
        createdAt: DateTime.parse(messageData['created_at'] as String),
        receipts: const [],
        attachments: attachments,
      );

      final isOwn = _currentUserId != null && newMessage.senderId == _currentUserId;
      
      if (!isOwn) {
        updateMessageReceipt(newMessage.id, 'delivered');
      }

      final existing = messagesByThread[threadId];
      if (existing != null) {
        final alreadyExists = existing.any((message) => message.id == newMessage.id);
        if (!alreadyExists) {
          existing.insert(0, newMessage);
        }
      } else {
        messagesByThread[threadId] = [newMessage];
      }

      _updateThreadPreview(threadId, newMessage, incrementUnread: !isOwn);
      notifyListeners();
    } catch (e) {
      print('Error handling new message: $e');
    }
  }

  void _updateThreadPreview(
    int threadId,
    ChatMessage newMessage, {
    required bool incrementUnread,
  }) {
    // Update in current mode list
    final index = threads.indexWhere((thread) => thread.id == threadId);
    if (index != -1) {
      final thread = threads[index];
      final updatedThread = ChatThread(
        id: thread.id,
        participantAId: thread.participantAId,
        participantBId: thread.participantBId,
        peerUserId: thread.peerUserId,
        peerName: thread.peerName,
        isAdminChat: thread.isAdminChat,
        lastMessage: newMessage,
        updatedAt: newMessage.createdAt,
        unreadCount: incrementUnread ? thread.unreadCount + 1 : thread.unreadCount,
      );

      threads[index] = updatedThread;
    }

    // Update in personal list if present
    final pIndex = personalThreads.indexWhere((thread) => thread.id == threadId);
    if (pIndex != -1) {
      final thread = personalThreads[pIndex];
      personalThreads[pIndex] = ChatThread(
        id: thread.id,
        participantAId: thread.participantAId,
        participantBId: thread.participantBId,
        peerUserId: thread.peerUserId,
        peerName: thread.peerName,
        isAdminChat: thread.isAdminChat,
        lastMessage: newMessage,
        updatedAt: newMessage.createdAt,
        unreadCount: incrementUnread ? thread.unreadCount + 1 : thread.unreadCount,
      );
      personalUnreadCount = _calculateUnreadCount(personalThreads);
    }

    // Update in admin list if present
    final aIndex = adminThreads.indexWhere((thread) => thread.id == threadId);
    if (aIndex != -1) {
      final thread = adminThreads[aIndex];
      adminThreads[aIndex] = ChatThread(
        id: thread.id,
        participantAId: thread.participantAId,
        participantBId: thread.participantBId,
        peerUserId: thread.peerUserId,
        peerName: thread.peerName,
        isAdminChat: thread.isAdminChat,
        lastMessage: newMessage,
        updatedAt: newMessage.createdAt,
        unreadCount: incrementUnread ? thread.unreadCount + 1 : thread.unreadCount,
      );
      adminUnreadCount = _calculateUnreadCount(adminThreads);
    }

    // If thread not found in any list, schedule full reload
    if (index == -1 && pIndex == -1 && aIndex == -1) {
      _scheduleThreadRefresh();
    }
  }

  void _scheduleThreadRefresh() {
    _threadRefreshTimer?.cancel();
    _threadRefreshTimer = Timer(const Duration(milliseconds: 400), () {
      loadThreads(mode: currentMode);
    });
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
            attachments: message.attachments,
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

  List<MessageReceipt> _mergeReceipts(
    List<MessageReceipt> serverReceipts,
    List<MessageReceipt> localReceipts,
  ) {
    if (localReceipts.isEmpty) return serverReceipts;
    if (serverReceipts.isEmpty) return localReceipts;

    final merged = <int, MessageReceipt>{
      for (final receipt in serverReceipts) receipt.recipientId: receipt,
    };

    for (final local in localReceipts) {
      final current = merged[local.recipientId];
      if (current == null) {
        merged[local.recipientId] = local;
        continue;
      }

      final currentRank = _receiptRank(current.state);
      final localRank = _receiptRank(local.state);
      if (localRank > currentRank) {
        merged[local.recipientId] = local;
      } else if (localRank == currentRank && local.updatedAt.isAfter(current.updatedAt)) {
        merged[local.recipientId] = local;
      }
    }

    return merged.values.toList();
  }

  int _receiptRank(String state) {
    switch (state) {
      case 'read':
        return 2;
      case 'delivered':
        return 1;
      default:
        return 0;
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
        if (!messagesByThread.containsKey(threadId)) {
          await loadThreadMessages(threadId);
        }
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

  Future<bool> sendMessageWithAttachments(
    int threadId,
    Map<String, dynamic> quillJson, {
    List<ChatAttachmentInput> attachments = const [],
  }) async {
    errorMessage = null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/threads/$threadId/messages'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'body': quillJson,
          'attachments': attachments.map((a) => a.toJson()).toList(),
        }),
      );

      if (response.statusCode == 201) {
        if (!messagesByThread.containsKey(threadId)) {
          await loadThreadMessages(threadId);
        }
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

  Future<ChatThread?> getOrCreateAdminThread() async {
    errorMessage = null;

    try {
      // Reload personal threads to make sure we have latest
      await loadThreads(mode: 'personal', setCurrent: false);

      // Check if admin thread exists
      final existingThread = personalThreads.firstWhere(
        (t) => t.isAdminChat,
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

      if (existingThread.id != -1) {
        return existingThread;
      }

      // Return virtual thread that will be created on first message
      return ChatThread(
        id: -1,
        participantAId: 0,
        participantBId: null,
        peerUserId: null,
        peerName: 'Administration',
        isAdminChat: true,
        lastMessage: null,
        updatedAt: DateTime.now(),
        unreadCount: 0,
      );
    } catch (e) {
      errorMessage = 'Error finding admin thread: $e';
      return null;
    }
  }

  Future<int?> sendAdminMessage(
    Map<String, dynamic> quillJson, {
    List<ChatAttachmentInput> attachments = const [],
  }) async {
    errorMessage = null;

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/admin/message'),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'body': quillJson,
          'attachments': attachments.map((a) => a.toJson()).toList(),
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final threadId = data['thread_id'] as int?;
        
        // Reload personal threads to get the new/updated thread
        await loadThreads(mode: 'personal', setCurrent: false);
        
        return threadId;
      } else {
        errorMessage = 'Failed to send message: ${response.statusCode}';
        return null;
      }
    } catch (e) {
      errorMessage = 'Error sending message: $e';
      return null;
    }
  }

  Future<ChatAttachment?> uploadMedia({
    required String mediaType,
    required List<int> bytes,
    required String filename,
  }) async {
    if (_token.isEmpty) return null;

    try {
      final uri = Uri.parse('http://localhost:8080/api/media/upload')
          .replace(queryParameters: {'type': mediaType});
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer $_token';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = json.decode(responseBody) as Map<String, dynamic>;
        return ChatAttachment(
          mediaId: data['id'] as int,
          attachmentType: mediaType,
          url: data['url'] as String,
          mimeType: data['mime_type'] as String? ?? 'application/octet-stream',
          sizeBytes: data['size_bytes'] as int? ?? 0,
        );
      }
    } catch (e) {
      errorMessage = 'Error uploading media: $e';
    }

    return null;
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

  Future<void> loadAvailableUsers() async {
    if (_token.isEmpty) return;

    isLoadingAvailableUsers = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/available-users'),
        headers: {'Authorization': 'Bearer $_token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        availableUsers = data
            .map((u) => ChatUserOption.fromJson(u as Map<String, dynamic>))
            .toList();
        errorMessage = null;
      } else {
        errorMessage = 'Failed to load users: ${response.statusCode}';
      }
    } catch (e) {
      errorMessage = 'Error loading users: $e';
    }

    isLoadingAvailableUsers = false;
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
    _threadRefreshTimer?.cancel();
    _threadPollTimer?.cancel();
    super.dispose();
  }
}
