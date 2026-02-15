import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import '../auth.dart';

class WsMessage {
  final String msgType;
  final int? userId;
  final int? threadId;
  final int? postId;
  final Map<String, dynamic> data;

  WsMessage({
    required this.msgType,
    this.userId,
    this.threadId,
    this.postId,
    required this.data,
  });

  Map<String, dynamic> toJson() {
    return {
      'msg_type': msgType,
      'user_id': userId,
      'thread_id': threadId,
      'post_id': postId,
      'data': data,
    };
  }

  static WsMessage fromJson(Map<String, dynamic> json) {
    return WsMessage(
      msgType: json['msg_type'] as String,
      userId: json['user_id'] as int?,
      threadId: json['thread_id'] as int?,
      postId: json['post_id'] as int?,
      data: (json['data'] ?? {}) as Map<String, dynamic>,
    );
  }
}

typedef WsMessageCallback = void Function(WsMessage);
typedef WsConnectionCallback = void Function(bool);

class WebSocketService extends ChangeNotifier {
  final AuthService authService;
  final String token;
  final String serverUrl;
  
  WebSocketChannel? _channel;
  bool _isConnected = false;
  bool _isConnecting = false;
  StreamSubscription? _subscription;
  
  final Map<String, List<WsMessageCallback>> _listeners = {};
  final List<WsConnectionCallback> _connectionListeners = [];
  final List<WsMessage> _pendingMessages = [];
  
  // Auto-reconnect
  static const Duration _reconnectDelay = Duration(seconds: 3);
  static const int _maxReconnectAttempts = 5;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;
  bool _isDisposed = false;

  WebSocketService({
    required this.authService,
    required this.token,
    required this.serverUrl,
  });

  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;

  void _safeNotifyListeners() {
    if (_isDisposed) return;
    notifyListeners();
  }

  /// Connect to WebSocket server
  Future<bool> connect() async {
    if (_isDisposed) return false;
    if (_isConnected || _isConnecting) return true;
    if (token.isEmpty) return false;

    final isValid = await authService.validateToken();
    if (!isValid) {
      if (authService.token == null || authService.token!.isEmpty) {
        _reconnectAttempts = _maxReconnectAttempts;
        return false;
      }
      _scheduleReconnect();
      return false;
    }

    _isConnecting = true;
    if (kDebugMode) {
      print('WebSocket connecting to $serverUrl');
    }
    _safeNotifyListeners();

    try {
      final wsUrl = serverUrl.replaceFirst('http', 'ws') + '/ws';
      final wsUri = Uri.parse(wsUrl);
      final wsUriWithToken = token.isNotEmpty
          ? wsUri.replace(queryParameters: {
              ...wsUri.queryParameters,
              'token': token,
            })
          : wsUri;

      _channel = WebSocketChannel.connect(wsUriWithToken);

      // Listen to messages
      _subscription = _channel!.stream.listen(
        (message) => _handleMessage(message as String),
        onDone: () {
          _handleDisconnection();
        },
        onError: (error) {
          print('WebSocket error: $error');
          _handleDisconnection();
        },
      );

      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _safeNotifyListeners();
      _notifyConnectionListeners(true);

      if (kDebugMode) {
        print('WebSocket connected');
      }
      _flushPendingMessages();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Failed to connect to WebSocket: $e');
      }
      _isConnecting = false;
      _isConnected = false;
      _safeNotifyListeners();
      _notifyConnectionListeners(false);
      _scheduleReconnect();
      return false;
    }
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    if (_isDisposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectAttempts = 0;
    
    _subscription?.cancel();
    await _channel?.sink.close(status.goingAway);
    _channel = null;
    
    _isConnected = false;
    _isConnecting = false;
    _safeNotifyListeners();
    _notifyConnectionListeners(false);
  }

  /// Send a message via WebSocket
  void send(WsMessage message) {
    if (_isDisposed) {
      return;
    }
    if (!_isConnected || _channel == null) {
      if (kDebugMode) {
        print('WebSocket not connected, message not sent: ${message.msgType}');
      }
      _enqueueMessage(message);
      return;
    }

    try {
      final json = jsonEncode(message.toJson());
      _channel?.sink.add(json);
      if (kDebugMode) {
        print('WebSocket sent: ${message.msgType}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending WebSocket message: $e');
      }
      _handleDisconnection();
      _enqueueMessage(message);
    }
  }

  void _enqueueMessage(WsMessage message) {
    const maxPending = 100;
    if (_pendingMessages.length >= maxPending) {
      _pendingMessages.removeAt(0);
    }
    _pendingMessages.add(message);
  }

  void _flushPendingMessages() {
    if (!_isConnected || _pendingMessages.isEmpty) return;
    final pending = List<WsMessage>.from(_pendingMessages);
    _pendingMessages.clear();
    for (final message in pending) {
      send(message);
    }
  }

  /// Subscribe to a specific message type
  void on(String msgType, WsMessageCallback callback) {
    _listeners.putIfAbsent(msgType, () => []).add(callback);
  }

  /// Unsubscribe from a specific message type
  void off(String msgType, WsMessageCallback callback) {
    _listeners[msgType]?.remove(callback);
  }

  /// Subscribe to connection state changes
  void onConnectionStateChanged(WsConnectionCallback callback) {
    _connectionListeners.add(callback);
  }

  /// Unsubscribe from connection state changes
  void removeConnectionListener(WsConnectionCallback callback) {
    _connectionListeners.remove(callback);
  }

  /// Subscribe to a chat thread
  void subscribeToThread(int threadId) {
    send(WsMessage(
      msgType: 'subscribe_thread',
      threadId: threadId,
      data: {},
    ));
  }

  /// Subscribe to a feed post
  void subscribeToPost(int postId) {
    send(WsMessage(
      msgType: 'subscribe_post',
      postId: postId,
      data: {},
    ));
  }

  /// Send typing indicator
  void sendTyping(int threadId, bool isTyping) {
    send(WsMessage(
      msgType: 'typing',
      threadId: threadId,
      data: {'is_typing': isTyping},
    ));
  }

  /// Handle incoming message
  void _handleMessage(String messageStr) {
    try {
      final json = jsonDecode(messageStr) as Map<String, dynamic>;
      final message = WsMessage.fromJson(json);

      // Call registered listeners
      final listeners = _listeners[message.msgType] ?? [];
      for (final callback in listeners) {
        callback(message);
      }

      if (kDebugMode) {
        print('WebSocket message received: ${message.msgType}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling WebSocket message: $e');
      }
    }
  }

  /// Handle disconnection and attempt reconnect
  void _handleDisconnection() {
    if (_isDisposed) return;
    _isConnected = false;
    _isConnecting = false;
    _channel = null;
    _safeNotifyListeners();
    _notifyConnectionListeners(false);
    if (kDebugMode) {
      print('WebSocket disconnected');
    }
    _scheduleReconnect();
  }

  /// Schedule automatic reconnection
  void _scheduleReconnect() {
    if (_isDisposed) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      if (kDebugMode) {
        print('Max reconnection attempts reached');
      }
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () {
      if (_isDisposed) return;
      _reconnectAttempts++;
      print('Attempting to reconnect... (${_reconnectAttempts}/$_maxReconnectAttempts)');
      connect();
    });
  }

  /// Notify connection listeners
  void _notifyConnectionListeners(bool connected) {
    if (_isDisposed) return;
    for (final listener in _connectionListeners) {
      listener(connected);
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close(status.normalClosure);
    _listeners.clear();
    _connectionListeners.clear();
    super.dispose();
  }
}