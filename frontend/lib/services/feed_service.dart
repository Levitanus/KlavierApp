import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../auth.dart';
import '../models/feed.dart';

class FeedService extends ChangeNotifier {
  final AuthService authService;
  final String baseUrl;
  String? _lastToken;

  FeedService({
    required this.authService,
    this.baseUrl = 'http://localhost:8080',
  }) {
    _lastToken = authService.token;
  }

  List<Feed> _feeds = [];
  bool _isLoadingFeeds = false;

  List<Feed> get feeds => _feeds;
  bool get isLoadingFeeds => _isLoadingFeeds;

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
        return data.map((json) => FeedPost.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching feed posts: $e');
    }

    return [];
  }

  Future<FeedPost?> fetchPost(int postId) async {
    if (authService.token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/feeds/posts/$postId'),
        headers: {
          'Authorization': 'Bearer ${authService.token}',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return FeedPost.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching post: $e');
    }

    return null;
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
    List<int>? mediaIds,
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
          'media_ids': mediaIds,
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

  Future<List<FeedComment>> fetchComments(int postId) async {
    if (authService.token == null) return [];

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
        return data.map((json) => FeedComment.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
    }

    return [];
  }

  Future<FeedComment?> createComment(
    int postId, {
    int? parentCommentId,
    required List<dynamic> content,
    List<int>? mediaIds,
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
          'media_ids': mediaIds,
        }),
      );

      if (response.statusCode == 201) {
        return FeedComment.fromJson(json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error creating comment: $e');
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

      return response.statusCode == 200;
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
