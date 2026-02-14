import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth.dart';
import '../models/feed.dart';
import '../models/chat.dart';
import 'websocket_service.dart';
import '../config/app_config.dart';
import 'app_data_cache_service.dart';

class FeedService extends ChangeNotifier {
  final AuthService authService;
  final WebSocketService wsService;
  final String baseUrl;
  String? _lastToken;
  final AppDataCacheService _cache = AppDataCacheService.instance;

  FeedService({
    required this.authService,
    required this.wsService,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? AppConfig.instance.baseUrl {
    _lastToken = authService.token;
    wsService.onConnectionStateChanged(_connectionCallback);
  }

  List<Feed> _feeds = [];
  bool _isLoadingFeeds = false;
  final Map<int, List<FeedComment>> _commentsByPost = {};
  final Set<int> _subscribedPosts = {};
  bool _wsListenersRegistered = false;
  late final WsMessageCallback _commentCallback = _handleCommentMessage;
  late final WsConnectionCallback _connectionCallback = _handleConnectionChange;

  List<Feed> get feeds => _feeds;
  bool get isLoadingFeeds => _isLoadingFeeds;
  List<FeedComment> commentsForPost(int postId) => _commentsByPost[postId] ?? [];

  String _feedsCacheKey() => 'feeds';
  String _postsCacheKey(int feedId, bool importantOnly, int limit, int offset) {
    return 'feed_posts:$feedId:$importantOnly:$limit:$offset';
  }

  String _postCacheKey(int postId) => 'feed_post:$postId';
  String _commentsCacheKey(int postId) => 'feed_comments:$postId';

  void _cacheComments(int postId, List<FeedComment> comments) {
    final payload = comments.map((comment) => comment.toJson()).toList();
    _cache.writeJson(_commentsCacheKey(postId), authService.userId, payload);
  }

  void syncAuth() {
    final token = authService.token;
    if (token != _lastToken) {
      _lastToken = token;
      _feeds = [];
      _isLoadingFeeds = false;
      notifyListeners();
      if (token != null && token.isNotEmpty) {
        fetchFeeds();
      }
    }
  }

  Future<void> fetchFeeds() async {
    if (authService.token == null) return;

    if (_feeds.isEmpty) {
      final cached = await _cache.readJsonList(_feedsCacheKey(), authService.userId);
      if (cached != null && cached.isNotEmpty) {
        _feeds = cached
            .whereType<Map<String, dynamic>>()
            .map((json) => Feed.fromJson(json))
            .toList();
        notifyListeners();
      }
    }

    _isLoadingFeeds = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/feeds'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _feeds = data.map((json) => Feed.fromJson(json)).toList();
        await _cache.writeJson(_feedsCacheKey(), authService.userId, data);
      } else {
        debugPrint('Failed to fetch feeds: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching feeds: $e');
    } finally {
      _isLoadingFeeds = false;
      notifyListeners();
    }
  }

  Future<FeedSettings?> getFeedSettings(int feedId) async {
    if (authService.token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/feeds/$feedId/settings'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return FeedSettings.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching feed settings: $e');
    }

    return null;
  }

  Future<FeedSettings?> updateFeedSettings(int feedId, bool allowStudentPosts) async {
    if (authService.token == null) return null;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/feeds/$feedId/settings'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'allow_student_posts': allowStudentPosts,
        }),
      );

      if (response.statusCode == 200) {
        return FeedSettings.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error updating feed settings: $e');
    }

    return null;
  }

  Future<FeedUserSettings?> getFeedUserSettings(int feedId) async {
    if (authService.token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/feeds/$feedId/user-settings'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return FeedUserSettings.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching feed user settings: $e');
    }

    return null;
  }

  Future<FeedUserSettings?> updateFeedUserSettings(
    int feedId,
    bool autoSubscribe,
    bool notifyNewPosts,
  ) async {
    if (authService.token == null) return null;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/feeds/$feedId/user-settings'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'auto_subscribe_new_posts': autoSubscribe,
          'notify_new_posts': notifyNewPosts,
        }),
      );

      if (response.statusCode == 200) {
        return FeedUserSettings.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error updating feed user settings: $e');
    }

    return null;
  }

  Future<List<FeedPost>> fetchPosts(
    int feedId, {
    bool importantOnly = false,
    int limit = 20,
    int offset = 0,
  }) async {
    if (authService.token == null) return [];

    final cacheKey = _postsCacheKey(feedId, importantOnly, limit, offset);

    try {
      final uri = Uri.parse('$baseUrl/api/feeds/$feedId/posts').replace(
        queryParameters: {
          'limit': limit.toString(),
          'offset': offset.toString(),
          if (importantOnly) 'important_only': 'true',
        },
      );

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        await _cache.writeJson(cacheKey, authService.userId, data);
        return data.map((json) => FeedPost.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching feed posts: $e');
    }

    final cached = await _cache.readJsonList(cacheKey, authService.userId);
    if (cached != null) {
      return cached
          .whereType<Map<String, dynamic>>()
          .map((json) => FeedPost.fromJson(json))
          .toList();
    }

    return [];
  }

  Future<FeedPost?> fetchPost(int postId) async {
    if (authService.token == null) return null;

    final cacheKey = _postCacheKey(postId);

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/feeds/posts/$postId'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _cache.writeJson(cacheKey, authService.userId, data);
        return FeedPost.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching post: $e');
    }

    final cached = await _cache.readJsonMap(cacheKey, authService.userId);
    if (cached != null) {
      return FeedPost.fromJson(cached);
    }

    return null;
  }

  void clearLocalCache() {
    _feeds = [];
    _commentsByPost.clear();
    _subscribedPosts.clear();
    _isLoadingFeeds = false;
    notifyListeners();
  }

  Future<bool> markPostRead(int postId) async {
    if (authService.token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/feeds/posts/$postId/read'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error marking post read: $e');
      return false;
    }
  }

  Future<bool> markFeedRead(int feedId) async {
    if (authService.token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/feeds/$feedId/read'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error marking feed read: $e');
      return false;
    }
  }

  Future<FeedPost?> createPost(
    int feedId, {
    String? title,
    required List<dynamic> content,
    bool isImportant = false,
    int? importantRank,
    bool allowComments = true,
    List<ChatAttachmentInput>? attachments,
  }) async {
    if (authService.token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/feeds/$feedId/posts'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': title,
          'content': content,
          'is_important': isImportant,
          'important_rank': importantRank,
          'allow_comments': allowComments,
          'attachments': attachments?.map((a) => a.toJson()).toList(),
        }),
      );

      if (response.statusCode == 201) {
        return FeedPost.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error creating post: $e');
    }

    return null;
  }

  Future<FeedPost?> updatePost(
    int postId, {
    String? title,
    required List<dynamic> content,
    bool isImportant = false,
    int? importantRank,
    bool allowComments = true,
  }) async {
    if (authService.token == null) return null;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/feeds/posts/$postId'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'title': title,
          'content': content,
          'is_important': isImportant,
          'important_rank': importantRank,
          'allow_comments': allowComments,
        }),
      );

      if (response.statusCode == 200) {
        return FeedPost.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error updating post: $e');
    }

    return null;
  }

  Future<List<FeedComment>> fetchComments(int postId) async {
    if (authService.token == null) return [];

    final cacheKey = _commentsCacheKey(postId);
    if (!_commentsByPost.containsKey(postId)) {
      final cached = await _cache.readJsonList(cacheKey, authService.userId);
      if (cached != null && cached.isNotEmpty) {
        final comments = cached
            .whereType<Map<String, dynamic>>()
            .map((json) => FeedComment.fromJson(json))
            .toList();
        _commentsByPost[postId] = comments;
        notifyListeners();
      }
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/feeds/posts/$postId/comments'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final comments = data.map((json) => FeedComment.fromJson(json)).toList();
        _commentsByPost[postId] = comments;
        await _cache.writeJson(cacheKey, authService.userId, data);
        notifyListeners();
        return comments;
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }

    final cached = await _cache.readJsonList(cacheKey, authService.userId);
    if (cached != null) {
      return cached
          .whereType<Map<String, dynamic>>()
          .map((json) => FeedComment.fromJson(json))
          .toList();
    }

    return [];
  }

  void subscribeToPostComments(int postId) {
    if (_subscribedPosts.contains(postId)) return;
    _subscribedPosts.add(postId);
    _ensureWsListeners();
    if (!wsService.isConnected && !wsService.isConnecting) {
      wsService.connect();
    }
    wsService.subscribeToPost(postId);
  }

  void _handleConnectionChange(bool connected) {
    if (!connected) return;
    _ensureWsListeners();
    for (final postId in _subscribedPosts) {
      wsService.subscribeToPost(postId);
    }
  }

  void _ensureWsListeners() {
    if (_wsListenersRegistered) return;
    _wsListenersRegistered = true;
    wsService.on('comment', _commentCallback);
  }

  void _handleCommentMessage(WsMessage wsMessage) {
    final postId = wsMessage.postId;
    if (postId == null) return;

    try {
      final comment = FeedComment.fromJson(wsMessage.data);
      final existing = _commentsByPost[postId] ?? [];
      final index = existing.indexWhere((item) => item.id == comment.id);
      final updated = List<FeedComment>.from(existing);
      if (index == -1) {
        updated.add(comment);
      } else {
        updated[index] = comment;
      }
      updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _commentsByPost[postId] = updated;
      _cacheComments(postId, updated);
      notifyListeners();
    } catch (e) {
      debugPrint('Error handling comment update: $e');
    }
  }

  Future<FeedComment?> createComment(
    int postId, {
    int? parentCommentId,
    required List<dynamic> content,
    List<ChatAttachmentInput>? attachments,
  }) async {
    if (authService.token == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/feeds/posts/$postId/comments'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'parent_comment_id': parentCommentId,
          'content': content,
          'attachments': attachments?.map((a) => a.toJson()).toList(),
        }),
      );

      if (response.statusCode == 201) {
        final comment = FeedComment.fromJson(json.decode(response.body));
        final existing = _commentsByPost[postId] ?? [];
        if (!existing.any((item) => item.id == comment.id)) {
          _commentsByPost[postId] = [...existing, comment]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
          _cacheComments(postId, _commentsByPost[postId] ?? []);
          notifyListeners();
        }
        return comment;
      }
    } catch (e) {
      debugPrint('Error creating comment: $e');
    }

    return null;
  }

  Future<FeedComment?> updateComment(
    int postId,
    int commentId, {
    required List<dynamic> content,
  }) async {
    if (authService.token == null) return null;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/feeds/posts/$postId/comments/$commentId'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        final comment = FeedComment.fromJson(json.decode(response.body));
        final existing = _commentsByPost[postId] ?? [];
        final index = existing.indexWhere((item) => item.id == comment.id);
        final updated = List<FeedComment>.from(existing);
        if (index == -1) {
          updated.add(comment);
        } else {
          updated[index] = comment;
        }
        updated.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _commentsByPost[postId] = updated;
        _cacheComments(postId, updated);
        notifyListeners();
        return comment;
      }
    } catch (e) {
      debugPrint('Error updating comment: $e');
    }

    return null;
  }

  Future<bool> updatePostSubscription(int postId, bool notifyOnComments) async {
    if (authService.token == null) return false;

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/api/feeds/posts/$postId/subscribe'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'notify_on_comments': notifyOnComments,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error updating post subscription: $e');
      return false;
    }
  }

  Future<bool?> getPostSubscription(int postId) async {
    if (authService.token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/feeds/posts/$postId/subscribe'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['subscribed'] as bool?;
      }
    } catch (e) {
      debugPrint('Error fetching post subscription: $e');
    }

    return null;
  }

  Future<bool> deletePostSubscription(int postId) async {
    if (authService.token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/feeds/posts/$postId/subscribe'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting post subscription: $e');
      return false;
    }
  }

  Future<bool> deletePost(int postId) async {
    if (authService.token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/feeds/posts/$postId'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error deleting post: $e');
      return false;
    }
  }

  Future<bool> deleteComment(int postId, int commentId) async {
    if (authService.token == null) return false;

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/api/feeds/posts/$postId/comments/$commentId'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final existing = _commentsByPost[postId];
        if (existing != null) {
          final updated = existing.where((item) => item.id != commentId).toList();
          _commentsByPost[postId] = updated;
          _cacheComments(postId, updated);
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error deleting comment: $e');
      return false;
    }
  }

  Future<MediaUploadResult?> uploadMedia({
    required String mediaType,
    required List<int> bytes,
    required String filename,
  }) async {
    if (authService.token == null) return null;

    try {
      final uri = Uri.parse('$baseUrl/api/media/upload')
          .replace(queryParameters: {'type': mediaType});
      final request = http.MultipartRequest('POST', uri);

      request.headers['Authorization'] = 'Bearer ${authService.token}';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
      ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        return MediaUploadResult.fromJson(json.decode(responseBody));
      }
    } catch (e) {
      debugPrint('Error uploading media: $e');
    }

    return null;
  }
}
