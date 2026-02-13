import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'auth.dart';
import 'models/feed.dart';
import 'services/feed_service.dart';
import 'widgets/quill_embed_builders.dart';
import 'widgets/feed_preview_card.dart';

class FeedsScreen extends StatefulWidget {
  final int? initialFeedId;
  final int? initialPostId;

  const FeedsScreen({
    super.key,
    this.initialFeedId,
    this.initialPostId,
  });

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen> {
  bool _openedInitialFeed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedService>().fetchFeeds();
    });
  }

  String _formatFeedTitle(Feed feed) {
    return feed.title.replaceFirst(RegExp(r'\s*Feed$'), '').trim();
  }

  String _ownerLabel(Feed feed) {
    final ownerType = feed.ownerType.toLowerCase();
    if (ownerType == 'school') {
      return 'School';
    }
    if (ownerType == 'teacher') {
      return 'Teacher';
    }
    return feed.ownerType;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedService>(
      builder: (context, feedService, child) {
        final feeds = feedService.feeds;
        final isLoading = feedService.isLoadingFeeds;
        final schoolFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'school')
            .toList();
        final teacherFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'teacher')
            .toList();

        if (!_openedInitialFeed && widget.initialFeedId != null && feeds.isNotEmpty) {
          final target = feeds.firstWhere(
            (feed) => feed.id == widget.initialFeedId,
            orElse: () => feeds.first,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _openedInitialFeed) return;
            setState(() {
              _openedInitialFeed = true;
            });
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FeedDetailScreen(
                  feed: target,
                  initialPostId: widget.initialPostId,
                ),
              ),
            );
          });
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text(
                  'Feeds',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => feedService.fetchFeeds(),
                ),
              ],
            ),
            if (isLoading) const LinearProgressIndicator(),
            if (!isLoading && feeds.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No feeds available'),
              ),
            if (schoolFeeds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'School',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...schoolFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
                  ownerLabel: _ownerLabel(feed),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedDetailScreen(feed: feed),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (teacherFeeds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Teacher feeds',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...teacherFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
                  ownerLabel: _ownerLabel(feed),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedDetailScreen(feed: feed),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class FeedDetailScreen extends StatefulWidget {
  final Feed feed;
  final int? initialPostId;

  const FeedDetailScreen({
    super.key,
    required this.feed,
    this.initialPostId,
  });

  @override
  State<FeedDetailScreen> createState() => _FeedDetailScreenState();
}

class _FeedDetailScreenState extends State<FeedDetailScreen> {
  final GlobalKey<_FeedTimelineState> _timelineKey = GlobalKey();
  FeedSettings? _feedSettings;
  FeedUserSettings? _userSettings;
  bool _loadingSettings = false;
  bool _openedInitialPost = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _openInitialPost();
  }

  void _openInitialPost() {
    if (widget.initialPostId == null || _openedInitialPost) return;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _openedInitialPost) return;
      _openedInitialPost = true;
      final feedService = context.read<FeedService>();
      final post = await feedService.fetchPost(widget.initialPostId!);
      if (!mounted || post == null) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FeedPostDetailScreen(
            post: post,
            feed: widget.feed,
          ),
        ),
      );
      if (mounted) {
        _timelineKey.currentState?.refresh();
      }
    });
  }

  String _displayTitle() {
    return widget.feed.title.replaceFirst(RegExp(r'\s*Feed$'), '').trim();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loadingSettings = true;
    });

    final feedService = context.read<FeedService>();
    final settings = await feedService.getFeedSettings(widget.feed.id);
    final userSettings = await feedService.getFeedUserSettings(widget.feed.id);

    if (!mounted) return;
    setState(() {
      _feedSettings = settings;
      _userSettings = userSettings;
      _loadingSettings = false;
    });
  }

  bool _canCreatePost(AuthService authService) {
    if (_feedSettings == null) return false;

    final isSchoolFeed = widget.feed.ownerType.toLowerCase() == 'school';
    if (isSchoolFeed) {
      return authService.isAdmin;
    }

    if (authService.isAdmin || authService.roles.contains('teacher')) {
      return true;
    }
    if (authService.roles.contains('student')) {
      return _feedSettings?.allowStudentPosts ?? false;
    }
    return false;
  }

  Future<void> _openComposer(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FeedPostComposer(feed: widget.feed),
    );

    if (result == true && mounted) {
      _timelineKey.currentState?.refresh();
    }
  }

  Future<void> _openSettingsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (context) => FeedSettingsDialog(
        feed: widget.feed,
        feedSettings: _feedSettings,
        userSettings: _userSettings,
      ),
    );

    if (mounted) {
      await _loadSettings();
    }
  }

  Future<void> _markAllRead() async {
    final feedService = context.read<FeedService>();
    final success = await feedService.markFeedRead(widget.feed.id);
    if (success && mounted) {
      _timelineKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final canCreate = _canCreatePost(authService);
        return Scaffold(
          appBar: AppBar(
            title: Text(_displayTitle()),
            actions: [
              if (canCreate)
                IconButton(
                  tooltip: 'New post',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _openComposer(context),
                ),
              IconButton(
                tooltip: 'Settings',
                icon: const Icon(Icons.settings),
                onPressed: _loadingSettings
                    ? null
                    : () => _openSettingsDialog(context),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'mark_all_read') {
                    _markAllRead();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'mark_all_read',
                    child: Text('Mark all as read'),
                  ),
                ],
              ),
            ],
          ),
          body: FeedTimeline(
            key: _timelineKey,
            feed: widget.feed,
          ),
        );
      },
    );
  }
}

class FeedTimeline extends StatefulWidget {
  final Feed feed;

  const FeedTimeline({
    super.key,
    required this.feed,
  });

  @override
  State<FeedTimeline> createState() => _FeedTimelineState();
}

class _FeedTimelineState extends State<FeedTimeline> {
  late Future<List<FeedPost>> _importantPosts;
  late Future<List<FeedPost>> _recentPosts;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void didUpdateWidget(covariant FeedTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.feed.id != widget.feed.id) {
      _loadPosts();
    }
  }

  void _loadPosts() {
    final feedService = context.read<FeedService>();
    _importantPosts = feedService.fetchPosts(
      widget.feed.id,
      importantOnly: true,
      limit: 5,
    );
    _recentPosts = feedService.fetchPosts(widget.feed.id);
  }

  Future<void> _refresh() async {
    setState(() {
      _loadPosts();
    });
  }

  Future<void> refresh() async {
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Text(
            'Important',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<FeedPost>>(
            future: _importantPosts,
            builder: (context, snapshot) {
              final posts = snapshot.data ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (posts.isEmpty) {
                return const Text('No important posts yet.');
              }
              return Column(
                children: posts
                    .map(
                      (post) => FeedPostCard(
                        post: post,
                        feed: widget.feed,
                        onOpen: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FeedPostDetailScreen(
                                post: post,
                                feed: widget.feed,
                              ),
                            ),
                          );
                          if (mounted) {
                            _refresh();
                          }
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'All posts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<FeedPost>>(
            future: _recentPosts,
            builder: (context, snapshot) {
              final posts = snapshot.data ?? [];
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (posts.isEmpty) {
                return const Text('No posts yet.');
              }
              return Column(
                children: posts
                    .map(
                      (post) => FeedPostCard(
                        post: post,
                        feed: widget.feed,
                        onOpen: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => FeedPostDetailScreen(
                                post: post,
                                feed: widget.feed,
                              ),
                            ),
                          );
                          if (mounted) {
                            _refresh();
                          }
                        },
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class FeedPostCard extends StatelessWidget {
  final FeedPost post;
  final Feed feed;
  final VoidCallback onOpen;

  const FeedPostCard({
    super.key,
    required this.post,
    required this.feed,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final controller = quill.QuillController(
      document: post.toDocument(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.title != null && post.title!.isNotEmpty) ...[
              Text(
                post.title!,
                style: post.isRead
                    ? Theme.of(context).textTheme.titleMedium
                    : Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
              ),
              const SizedBox(height: 8),
            ],
            quill.QuillEditor.basic(
              controller: controller,
              config: quill.QuillEditorConfig(
                embedBuilders: [
                  ImageEmbedBuilder(),
                  VideoEmbedBuilder(),
                  FileEmbedBuilder(),
                ],
                unknownEmbedBuilder: UnknownEmbedBuilder(),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Posted ${post.createdAt.toLocal()}'.split('.').first,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: onOpen,
                  child: const Text('Open'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FeedPostDetailScreen extends StatefulWidget {
  final FeedPost post;
  final Feed feed;

  const FeedPostDetailScreen({
    super.key,
    required this.post,
    required this.feed,
  });

  @override
  State<FeedPostDetailScreen> createState() => _FeedPostDetailScreenState();
}

class _FeedPostDetailScreenState extends State<FeedPostDetailScreen> {
  List<FeedComment> _comments = [];
  bool _loading = true;
  bool _isDeleting = false;
  bool _loadingSubscription = true;
  bool _isSubscribed = false;
  late FeedService _feedService;

  @override
  void initState() {
    super.initState();
    _feedService = context.read<FeedService>();
    _feedService.addListener(_handleFeedUpdate);
    _feedService.subscribeToPostComments(widget.post.id);
    _loadComments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _feedService.markPostRead(widget.post.id);
    });
    _loadSubscription();
  }

  void _handleFeedUpdate() {
    if (!mounted) return;
    final updated = _feedService.commentsForPost(widget.post.id);
    setState(() {
      _comments = updated;
    });
  }

  Future<void> _loadSubscription() async {
    final service = context.read<FeedService>();
    final subscribed = await service.getPostSubscription(widget.post.id);
    if (!mounted) return;
    setState(() {
      _isSubscribed = subscribed ?? false;
      _loadingSubscription = false;
    });
  }

  Future<void> _toggleSubscription() async {
    if (_loadingSubscription) return;
    setState(() {
      _loadingSubscription = true;
    });

    final service = context.read<FeedService>();
    bool success;
    if (_isSubscribed) {
      success = await service.deletePostSubscription(widget.post.id);
    } else {
      success = await service.updatePostSubscription(widget.post.id, true);
    }

    if (!mounted) return;
    setState(() {
      _isSubscribed = success ? !_isSubscribed : _isSubscribed;
      _loadingSubscription = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update subscription')),
      );
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
    });
    final comments = await _feedService.fetchComments(widget.post.id);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _feedService.removeListener(_handleFeedUpdate);
    super.dispose();
  }

  Future<void> _deletePost() async {
    final auth = context.read<AuthService>();
    
    // Check permissions: admin, feed owner, or post author
    final canDelete = auth.isAdmin || 
                      auth.userId == widget.post.authorUserId;
    
    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You do not have permission to delete this post')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    final service = context.read<FeedService>();
    final success = await service.deletePost(widget.post.id);

    if (!mounted) return;

    setState(() {
      _isDeleting = false;
    });

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to delete post')),
      );
    }
  }

  Map<int?, List<FeedComment>> _buildTree(List<FeedComment> comments) {
    final map = <int?, List<FeedComment>>{};
    for (final comment in comments) {
      map.putIfAbsent(comment.parentCommentId, () => []).add(comment);
    }
    return map;
  }

  List<Widget> _buildCommentWidgets(
    Map<int?, List<FeedComment>> tree,
    int? parentId,
    int depth,
  ) {
    final items = tree[parentId] ?? [];
    return items.expand((comment) {
      final controller = quill.QuillController(
        document: comment.toDocument(),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );

      final children = _buildCommentWidgets(tree, comment.id, depth + 1);

      return [
        Container(
          margin: EdgeInsets.only(left: depth * 16.0, bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            quill.QuillEditor.basic(
              controller: controller,
              config: quill.QuillEditorConfig(
                embedBuilders: [
                  ImageEmbedBuilder(),
                  VideoEmbedBuilder(),
                  FileEmbedBuilder(),
                ],
                unknownEmbedBuilder: UnknownEmbedBuilder(),
              ),
            ),
              const SizedBox(height: 8),
              Text(
                'Posted ${comment.createdAt.toLocal()}'.split('.').first,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _openCommentComposer(comment.id),
                  child: const Text('Reply'),
                ),
              ),
            ],
          ),
        ),
        ...children,
      ];
    }).toList();
  }

  Future<void> _openCommentComposer(int? parentCommentId) async {
    if (!widget.post.allowComments) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FeedCommentComposer(
        postId: widget.post.id,
        parentCommentId: parentCommentId,
      ),
    );

    if (result == true) {
      await _loadComments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final postController = quill.QuillController(
      document: widget.post.toDocument(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );

    final tree = _buildTree(_comments);

    // For school feeds, only admins can edit/delete
    // For personal/teacher feeds, admins or the post author can edit/delete
    final isSchoolFeed = widget.feed.ownerType.toLowerCase() == 'school';
    final canEdit = (isSchoolFeed && auth.isAdmin) || 
                    (!isSchoolFeed && (auth.isAdmin || (auth.userId ?? -1) == widget.post.authorUserId));
    final canDelete = (isSchoolFeed && auth.isAdmin) || 
                      (!isSchoolFeed && (auth.isAdmin || (auth.userId ?? -1) == widget.post.authorUserId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Post'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: Implement edit post
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit post coming soon')),
                );
              },
            ),
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isDeleting ? null : _deletePost,
            ),
        ],
      ),
      body: _isDeleting
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (widget.post.title != null && widget.post.title!.isNotEmpty) ...[
                  Text(
                    widget.post.title!,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                ],
                quill.QuillEditor.basic(
                  controller: postController,
                  config: quill.QuillEditorConfig(
                    embedBuilders: [
                      ImageEmbedBuilder(),
                      VideoEmbedBuilder(),
                      FileEmbedBuilder(),
                    ],
                    unknownEmbedBuilder: UnknownEmbedBuilder(),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _loadingSubscription ? null : _toggleSubscription,
                    icon: Icon(
                      _isSubscribed
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                    ),
                    label: Text(
                      _isSubscribed
                          ? 'Unsubscribe from comments'
                          : 'Subscribe to comments',
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Comments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_comments.isEmpty)
                  const Text('No comments yet.')
                else
                  ..._buildCommentWidgets(tree, null, 0),
              ],
            ),
      floatingActionButton: widget.post.allowComments
          ? FloatingActionButton.extended(
              onPressed: () => _openCommentComposer(null),
              icon: const Icon(Icons.add_comment),
              label: const Text('Add Comment'),
            )
          : null,
    );
  }
}

class FeedPostComposer extends StatefulWidget {
  final Feed feed;

  const FeedPostComposer({super.key, required this.feed});

  @override
  State<FeedPostComposer> createState() => _FeedPostComposerState();
}

class _FeedPostComposerState extends State<FeedPostComposer> {
  final TextEditingController _titleController = TextEditingController();
  final quill.QuillController _controller = quill.QuillController.basic();
  bool _isImportant = false;
  bool _allowComments = true;
  bool _isSubmitting = false;
  final List<int> _mediaIds = [];

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _attachMedia() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    final extension = file.extension?.toLowerCase() ?? '';
    String mediaType = 'file';

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      mediaType = 'image';
    } else if (['mp3', 'wav', 'aac', 'm4a', 'ogg', 'opus'].contains(extension)) {
      mediaType = 'audio';
    } else if (['mp4', 'mov', 'webm', 'mkv', 'avi', 'm4v'].contains(extension)) {
      mediaType = 'video';
    }

    final service = context.read<FeedService>();
    final upload = await service.uploadMedia(
      mediaType: mediaType,
      bytes: file.bytes!,
      filename: file.name,
    );

    if (upload == null) return;

    setState(() {
      _mediaIds.add(upload.id);
    });

    try {
      // Ensure document has content - insert placeholder if empty
      if (_controller.document.length <= 1) {
        _controller.document.insert(0, '\n');
      }

      // Insert media at a safe position within the document
      final insertIndex = _controller.document.length > 1 
        ? _controller.document.length - 1  // Before final newline
        : 0;  // Empty or minimal document
      
      if (mediaType == 'image') {
        _controller.document.insert(insertIndex, quill.BlockEmbed.image(upload.url));
      } else if (mediaType == 'video') {
        _controller.document.insert(insertIndex, quill.BlockEmbed.video(upload.url));
      } else {
        _controller.document.insert(insertIndex, '\nAttachment: ${upload.url}\n');
      }
    } catch (e) {
      print('Error inserting media: $e');
      // Remove media ID if insertion failed
      setState(() {
        _mediaIds.removeLast();
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final service = context.read<FeedService>();
    final content = _controller.document.toDelta().toJson();

    final created = await service.createPost(
      widget.feed.id,
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      content: content,
      isImportant: _isImportant,
      allowComments: _allowComments,
      mediaIds: _mediaIds.isEmpty ? null : _mediaIds,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (created != null) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return AlertDialog(
      title: const Text('New post'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 12),
            quill.QuillSimpleToolbar(
              controller: _controller,
              config: const quill.QuillSimpleToolbarConfig(
                showAlignmentButtons: true,
                showCodeBlock: false,
                showQuote: false,
              ),
            ),
            SizedBox(
              height: 200,
              child: quill.QuillEditor.basic(
                controller: _controller,
                config: quill.QuillEditorConfig(
                  embedBuilders: [
                    ImageEmbedBuilder(),
                    VideoEmbedBuilder(),
                    FileEmbedBuilder(),
                  ],
                  unknownEmbedBuilder: UnknownEmbedBuilder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _attachMedia,
                  icon: const Icon(Icons.attach_file),
                  label: const Text('Attach'),
                ),
                const Spacer(),
                Checkbox(
                  value: _allowComments,
                  onChanged: (value) {
                    setState(() {
                      _allowComments = value ?? true;
                    });
                  },
                ),
                const Text('Allow comments'),
              ],
            ),
            if (authService.isAdmin || authService.roles.contains('teacher'))
              Row(
                children: [
                  Checkbox(
                    value: _isImportant,
                    onChanged: (value) {
                      setState(() {
                        _isImportant = value ?? false;
                      });
                    },
                  ),
                  const Text('Mark as important'),
                ],
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Post'),
        ),
      ],
    );
  }
}

class FeedCommentComposer extends StatefulWidget {
  final int postId;
  final int? parentCommentId;

  const FeedCommentComposer({
    super.key,
    required this.postId,
    this.parentCommentId,
  });

  @override
  State<FeedCommentComposer> createState() => _FeedCommentComposerState();
}

class _FeedCommentComposerState extends State<FeedCommentComposer> {
  final quill.QuillController _controller = quill.QuillController.basic();
  bool _isSubmitting = false;
  final List<int> _mediaIds = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _attachMedia() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null) return;

    final extension = file.extension?.toLowerCase() ?? '';
    String mediaType = 'file';

    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
      mediaType = 'image';
    } else if (['mp3', 'wav', 'aac', 'm4a', 'ogg', 'opus'].contains(extension)) {
      mediaType = 'audio';
    } else if (['mp4', 'mov', 'webm', 'mkv', 'avi', 'm4v'].contains(extension)) {
      mediaType = 'video';
    }

    final service = context.read<FeedService>();
    final upload = await service.uploadMedia(
      mediaType: mediaType,
      bytes: file.bytes!,
      filename: file.name,
    );

    if (upload == null) return;

    setState(() {
      _mediaIds.add(upload.id);
    });

    try {
      // Ensure document has content - insert placeholder if empty
      if (_controller.document.length <= 1) {
        _controller.document.insert(0, '\n');
      }

      // Insert media at a safe position within the document
      final insertIndex = _controller.document.length > 1 
        ? _controller.document.length - 1  // Before final newline
        : 0;  // Empty or minimal document
      
      if (mediaType == 'image') {
        _controller.document.insert(insertIndex, quill.BlockEmbed.image(upload.url));
      } else if (mediaType == 'video') {
        _controller.document.insert(insertIndex, quill.BlockEmbed.video(upload.url));
      } else {
        _controller.document.insert(insertIndex, '\nAttachment: ${upload.url}\n');
      }
    } catch (e) {
      print('Error inserting media: $e');
      // Remove media ID if insertion failed
      setState(() {
        _mediaIds.removeLast();
      });
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final service = context.read<FeedService>();
    final content = _controller.document.toDelta().toJson();

    final created = await service.createComment(
      widget.postId,
      parentCommentId: widget.parentCommentId,
      content: content,
      mediaIds: _mediaIds.isEmpty ? null : _mediaIds,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (created != null) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New comment'),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            quill.QuillSimpleToolbar(
              controller: _controller,
              config: const quill.QuillSimpleToolbarConfig(
                showAlignmentButtons: true,
                showCodeBlock: false,
                showQuote: false,
              ),
            ),
            SizedBox(
              height: 180,
              child: quill.QuillEditor.basic(
                controller: _controller,
                config: quill.QuillEditorConfig(
                  embedBuilders: [
                    ImageEmbedBuilder(),
                    VideoEmbedBuilder(),
                    FileEmbedBuilder(),
                  ],
                  unknownEmbedBuilder: UnknownEmbedBuilder(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton.icon(
                onPressed: _attachMedia,
                icon: const Icon(Icons.attach_file),
                label: const Text('Attach'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Post'),
        ),
      ],
    );
  }
}

class FeedSettingsDialog extends StatefulWidget {
  final Feed feed;
  final FeedSettings? feedSettings;
  final FeedUserSettings? userSettings;

  const FeedSettingsDialog({
    super.key,
    required this.feed,
    required this.feedSettings,
    required this.userSettings,
  });

  @override
  State<FeedSettingsDialog> createState() => _FeedSettingsDialogState();
}

class _FeedSettingsDialogState extends State<FeedSettingsDialog> {
  bool _allowStudentPosts = false;
  bool _autoSubscribe = true;
  bool _notifyNewPosts = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _allowStudentPosts = widget.feedSettings?.allowStudentPosts ?? false;
    _autoSubscribe = widget.userSettings?.autoSubscribeNewPosts ?? true;
    _notifyNewPosts = widget.userSettings?.notifyNewPosts ?? true;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    final feedService = context.read<FeedService>();
    final authService = context.read<AuthService>();

    if (authService.isAdmin || authService.roles.contains('teacher')) {
      await feedService.updateFeedSettings(widget.feed.id, _allowStudentPosts);
    }

    await feedService.updateFeedUserSettings(
      widget.feed.id,
      _autoSubscribe,
      _notifyNewPosts,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return AlertDialog(
      title: const Text('Feed settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((authService.isAdmin || authService.roles.contains('teacher')) &&
              widget.feed.ownerType.toLowerCase() != 'school')
            SwitchListTile(
              value: _allowStudentPosts,
              onChanged: (value) {
                setState(() {
                  _allowStudentPosts = value;
                });
              },
              title: const Text('Allow student posts'),
            ),
          SwitchListTile(
            value: _autoSubscribe,
            onChanged: (value) {
              setState(() {
                _autoSubscribe = value;
              });
            },
            title: const Text('Auto-subscribe to new posts'),
          ),
          SwitchListTile(
            value: _notifyNewPosts,
            onChanged: (value) {
              setState(() {
                _notifyNewPosts = value;
              });
            },
            title: const Text('Notify on new posts'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

