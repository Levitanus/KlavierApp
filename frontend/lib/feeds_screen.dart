import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import 'auth.dart';
import 'models/chat.dart';
import 'models/feed.dart';
import 'services/feed_service.dart';
import 'services/active_view_tracker.dart';
import 'services/audio_player_service.dart';
import 'services/media_cache_service.dart';
import 'utils/media_download.dart';
import 'widgets/quill_embed_builders.dart';
import 'widgets/quill_editor_composer.dart';
import 'widgets/feed_preview_card.dart';
import 'widgets/floating_audio_player.dart';
import 'l10n/app_localizations.dart';
import 'widgets/app_body_container.dart';

class FeedsScreen extends StatefulWidget {
  final int? initialFeedId;
  final int? initialPostId;

  const FeedsScreen({super.key, this.initialFeedId, this.initialPostId});

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

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedService>(
      builder: (context, feedService, child) {
        final l10n = AppLocalizations.of(context);
        final feeds = feedService.feeds;
        final isLoading = feedService.isLoadingFeeds;
        final schoolFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'school')
            .toList();
        final teacherFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'teacher')
            .toList();
        final groupFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'group')
            .toList();

        if (!_openedInitialFeed &&
            widget.initialFeedId != null &&
            feeds.isNotEmpty) {
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
                  l10n?.feedsTitle ?? 'Feeds',
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
              Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n?.feedsNone ?? 'No feeds available'),
              ),
            if (schoolFeeds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n?.feedsSchool ?? 'School',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...schoolFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
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
                l10n?.feedsTeacherFeeds ?? 'Teacher feeds',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...teacherFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
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
            if (groupFeeds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n?.feedsGroupFeeds ?? 'Group feeds',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...groupFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
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

  const FeedDetailScreen({super.key, required this.feed, this.initialPostId});

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
          builder: (_) => FeedPostDetailScreen(post: post, feed: widget.feed),
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
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FeedPostComposer(feed: widget.feed)),
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
        final l10n = AppLocalizations.of(context);
        final canCreate = _canCreatePost(authService);
        return Scaffold(
          appBar: AppBar(
            title: Text(_displayTitle()),
            actions: [
              if (canCreate)
                IconButton(
                  tooltip: l10n?.feedsNewPostTooltip ?? 'New post',
                  icon: const Icon(Icons.edit),
                  onPressed: () => _openComposer(context),
                ),
              IconButton(
                tooltip: l10n?.commonSettings ?? 'Settings',
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
                  PopupMenuItem(
                    value: 'mark_all_read',
                    child: Text(l10n?.feedsMarkAllRead ?? 'Mark all as read'),
                  ),
                ],
              ),
            ],
          ),
          body: AppBodyContainer(
            child: FeedTimeline(key: _timelineKey, feed: widget.feed),
          ),
        );
      },
    );
  }
}

class FeedTimeline extends StatefulWidget {
  final Feed feed;

  const FeedTimeline({super.key, required this.feed});

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
    final l10n = AppLocalizations.of(context);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          Text(
            l10n?.feedsImportant ?? 'Important',
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
                return Text(
                  l10n?.feedsNoImportantPosts ?? 'No important posts yet.',
                );
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
            l10n?.feedsAllPosts ?? 'All posts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<FeedPost>>(
            future: _recentPosts,
            builder: (context, snapshot) {
              final posts = snapshot.data ?? [];
              final regularPosts = posts
                  .where((post) => !post.isImportant)
                  .toList();
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (regularPosts.isEmpty) {
                return Text(l10n?.feedsNoPosts ?? 'No posts yet.');
              }
              return Column(
                children: regularPosts
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
    final l10n = AppLocalizations.of(context);
    final document = post.toDocument();
    final controller = quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    final hasPreviewContent =
        document.toPlainText().trim().isNotEmpty || post.attachments.isNotEmpty;

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
                    ? Theme.of(context).textTheme.headlineSmall
                    : Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
              ),
              const SizedBox(height: 8),
            ],
            if (hasPreviewContent)
              Stack(
                children: [
                  SizedBox(
                    height: 170,
                    child: AbsorbPointer(
                      child: DefaultTextStyle.merge(
                        style:
                            Theme.of(context).textTheme.bodyMedium ??
                            const TextStyle(),
                        child: quill.QuillEditor.basic(
                          controller: controller,
                          config: quill.QuillEditorConfig(
                            showCursor: false,
                            embedBuilders: [
                              ImageEmbedBuilder(),
                              VideoEmbedBuilder(),
                              AudioEmbedBuilder(),
                              VoiceEmbedBuilder(),
                              FileEmbedBuilder(),
                            ],
                            unknownEmbedBuilder: UnknownEmbedBuilder(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Theme.of(
                                context,
                              ).colorScheme.surface.withOpacity(0),
                              Theme.of(context).colorScheme.surface,
                            ],
                          ),
                        ),
                        alignment: Alignment.bottomRight,
                        padding: const EdgeInsets.only(right: 8, bottom: 6),
                      ),
                    ),
                  ),
                ],
              )
            else
              Text(
                l10n?.feedsNoTextPreview ?? 'No text preview available.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  l10n?.feedsPostedAt(
                        '${post.createdAt.toLocal()}'.split('.').first,
                      ) ??
                      'Posted ${post.createdAt.toLocal()}'.split('.').first,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: onOpen,
                  child: Text(l10n?.feedsReadAndDiscuss ?? 'Read and discuss'),
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
  late FeedPost _post;
  List<FeedComment> _comments = [];
  bool _loading = true;
  bool _isDeleting = false;
  bool _loadingSubscription = true;
  bool _isSubscribed = false;
  late FeedService _feedService;

  @override
  void initState() {
    super.initState();
    ActiveViewTracker.setActiveFeedPost(widget.post.id);
    _post = widget.post;
    _feedService = context.read<FeedService>();
    _feedService.addListener(_handleFeedUpdate);
    _feedService.subscribeToPostComments(_post.id);
    _loadComments();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _feedService.markPostRead(_post.id);
    });
    _loadSubscription();
  }

  void _handleFeedUpdate() {
    if (!mounted) return;
    final updated = _feedService.commentsForPost(_post.id);
    setState(() {
      _comments = updated;
    });
  }

  Future<void> _loadSubscription() async {
    final service = context.read<FeedService>();
    final subscribed = await service.getPostSubscription(_post.id);
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
      success = await service.deletePostSubscription(_post.id);
    } else {
      success = await service.updatePostSubscription(_post.id, true);
    }

    if (!mounted) return;
    setState(() {
      _isSubscribed = success ? !_isSubscribed : _isSubscribed;
      _loadingSubscription = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.feedsSubscriptionFailed ??
                'Failed to update subscription',
          ),
        ),
      );
    }
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
    });
    final comments = await _feedService.fetchComments(_post.id);
    if (!mounted) return;
    setState(() {
      _comments = comments;
      _loading = false;
    });
  }

  @override
  void dispose() {
    ActiveViewTracker.clearActiveFeedPost(widget.post.id);
    _feedService.removeListener(_handleFeedUpdate);
    super.dispose();
  }

  Future<void> _deletePost() async {
    final auth = context.watch<AuthService>();

    // Check permissions: admin, feed owner, or post author
    final canDelete = auth.isAdmin || auth.userId == _post.authorUserId;

    if (!canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.feedsDeleteDenied ??
                'You do not have permission to delete this post',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(
          AppLocalizations.of(context)?.feedsDeleteTitle ?? 'Delete Post',
        ),
        content: Text(
          AppLocalizations.of(context)?.feedsDeleteMessage ??
              'Are you sure you want to delete this post? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(AppLocalizations.of(context)?.commonDelete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    final service = context.read<FeedService>();
    final success = await service.deletePost(_post.id);

    if (!mounted) return;

    setState(() {
      _isDeleting = false;
    });

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.feedsDeleteFailed ??
                'Failed to delete post',
          ),
        ),
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

  List<ChatAttachment> _visibleAttachments(
    List<dynamic> content,
    List<ChatAttachment> attachments,
  ) {
    if (attachments.isEmpty) return [];
    final body = jsonEncode(content);
    return attachments
        .where((attachment) => !body.contains(attachment.url))
        .toList();
  }

  Widget _buildAttachmentWidget(ChatAttachment attachment) {
    final url = normalizeMediaUrl(attachment.url);
    Widget content;
    switch (attachment.attachmentType) {
      case 'image':
        content = ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: MediaCacheService.instance.cachedImage(
            url: url,
            fit: BoxFit.contain,
          ),
        );
        break;
      case 'video':
        content = ChatVideoPlayer(url: url);
        break;
      case 'audio':
        content = ChatAudioPlayer(
          url: url,
          label: AppLocalizations.of(context)?.commonAudio ?? 'Audio',
        );
        break;
      case 'voice':
        content = ChatAudioPlayer(
          url: url,
          label:
              AppLocalizations.of(context)?.commonVoiceMessage ??
              'Voice message',
        );
        break;
      case 'file':
        content = Row(
          children: [
            const Icon(Icons.insert_drive_file),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                url.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
        break;
      default:
        content = Text(
          AppLocalizations.of(
                context,
              )?.feedsUnsupportedAttachment(attachment.attachmentType) ??
              'Unsupported attachment: ${attachment.attachmentType}',
        );
    }

    return _buildAttachmentWithMenu(
      child: content,
      onDownload: () => _downloadAttachment(url),
    );
  }

  Widget _buildAttachmentWithMenu({
    required Widget child,
    required VoidCallback onDownload,
  }) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        Padding(padding: const EdgeInsets.only(right: 32), child: child),
        PopupMenuButton<String>(
          tooltip:
              AppLocalizations.of(context)?.feedsAttachmentActions ??
              'Attachment actions',
          onSelected: (value) {
            if (value == 'download') {
              onDownload();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'download',
              child: Text(
                AppLocalizations.of(context)?.commonDownloadSourceFile ??
                    'Download source file',
              ),
            ),
          ],
          icon: const Icon(Icons.more_horiz, size: 20),
        ),
      ],
    );
  }

  Future<void> _downloadAttachment(String url) async {
    final filename = _fileNameFromUrl(url);
    final result = await downloadMedia(
      url: url,
      filename: filename,
      appFolderName: 'music_school_app',
    );

    if (!mounted) return;

    final message = result.success
        ? (result.filePath != null
              ? (AppLocalizations.of(
                      context,
                    )?.commonSavedToPath(result.filePath!) ??
                    'Saved to ${result.filePath}')
              : (AppLocalizations.of(context)?.commonDownloadStarted ??
                    'Download started'))
        : (result.errorMessage ??
              AppLocalizations.of(context)?.commonDownloadFailed ??
              'Download failed');

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String? _fileNameFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.pathSegments.isEmpty) return null;
    final name = uri.pathSegments.last.trim();
    return name.isEmpty ? null : name;
  }

  List<Widget> _buildCommentWidgets(
    Map<int?, List<FeedComment>> tree,
    int? parentId,
    int depth,
  ) {
    final items = tree[parentId] ?? [];
    final auth = context.watch<AuthService>();
    final l10n = AppLocalizations.of(context);
    return items.expand((comment) {
      final controller = quill.QuillController(
        document: comment.toDocument(),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      final commentAttachments = _visibleAttachments(
        comment.content,
        comment.attachments,
      );

      final children = _buildCommentWidgets(tree, comment.id, depth + 1);

      return [
        Container(
          margin: EdgeInsets.only(left: depth * 16.0, bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DefaultTextStyle.merge(
                style:
                    Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
                child: quill.QuillEditor.basic(
                  controller: controller,
                  config: quill.QuillEditorConfig(
                    showCursor: false,
                    embedBuilders: [
                      ImageEmbedBuilder(),
                      VideoEmbedBuilder(),
                      AudioEmbedBuilder(),
                      VoiceEmbedBuilder(),
                      FileEmbedBuilder(),
                    ],
                    unknownEmbedBuilder: UnknownEmbedBuilder(),
                  ),
                ),
              ),
              if (commentAttachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final attachment in commentAttachments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _buildAttachmentWidget(attachment),
                  ),
              ],
              const SizedBox(height: 8),
              Text(
                _formatTimestamp(context, comment.createdAt, comment.updatedAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _openCommentComposer(comment.id),
                    child: Text(l10n?.commonReply ?? 'Reply'),
                  ),
                  if ((auth.userId ?? -1) == comment.authorUserId)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, size: 18),
                      tooltip:
                          l10n?.feedsCommentActions ??
                          l10n?.chatMessageActions ??
                          'Comment actions',
                      onSelected: (value) {
                        if (value == 'edit') {
                          _openCommentEditor(comment);
                        } else if (value == 'delete') {
                          _deleteComment(comment);
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<String>(
                          value: 'edit',
                          child: Text(l10n?.feedsEditComment ?? 'Edit comment'),
                        ),
                        PopupMenuItem<String>(
                          value: 'delete',
                          child: Text(l10n?.commonDelete ?? 'Delete'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        ...children,
      ];
    }).toList();
  }

  Future<void> _openCommentComposer(int? parentCommentId) async {
    if (!_post.allowComments) return;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FeedCommentComposer(
        postId: _post.id,
        parentCommentId: parentCommentId,
      ),
    );

    if (result == true) {
      await _loadComments();
    }
  }

  String _formatTimestamp(
    BuildContext context,
    DateTime createdAt,
    DateTime updatedAt,
  ) {
    final l10n = AppLocalizations.of(context);
    final timestamp = '${createdAt.toLocal()}'.split('.').first;
    if (updatedAt.isAfter(createdAt)) {
      return l10n?.feedsPostedEditedAt(timestamp) ??
          'Posted $timestamp · edited';
    }
    return l10n?.feedsPostedAt(timestamp) ?? 'Posted $timestamp';
  }

  Future<void> _editPost() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FeedPostEditor(feed: widget.feed, post: _post),
        fullscreenDialog: true,
      ),
    );

    if (updated == true && mounted) {
      final refreshed = await _feedService.fetchPost(_post.id);
      if (refreshed != null && mounted) {
        setState(() {
          _post = refreshed;
        });
      }
    }
  }

  Future<void> _openCommentEditor(FeedComment comment) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => FeedCommentEditor(postId: _post.id, comment: comment),
    );

    if (updated == true) {
      await _loadComments();
    }
  }

  Future<void> _deleteComment(FeedComment comment) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(l10n?.feedsDeleteCommentTitle ?? 'Delete comment'),
        content: Text(
          l10n?.feedsDeleteCommentMessage ??
              'Are you sure you want to delete this comment? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n?.commonCancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n?.commonDelete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final service = context.read<FeedService>();
    final success = await service.deleteComment(_post.id, comment.id);
    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n?.feedsDeleteCommentFailed ?? 'Failed to delete comment',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final postController = quill.QuillController(
      document: _post.toDocument(),
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
    final postAttachments = _visibleAttachments(
      _post.content,
      _post.attachments,
    );

    final tree = _buildTree(_comments);

    // For school feeds, only admins can edit/delete
    // For personal/teacher feeds, admins or the post author can edit/delete
    final isSchoolFeed = widget.feed.ownerType.toLowerCase() == 'school';
    final isAuthor = (auth.userId ?? -1) == _post.authorUserId;
    final canEdit = isSchoolFeed ? (auth.isAdmin || isAuthor) : isAuthor;
    final canDelete = isSchoolFeed ? (auth.isAdmin || isAuthor) : isAuthor;

    final listBottomPadding = _post.allowComments ? 96.0 : 16.0;

    return ChangeNotifierProvider.value(
      value: AudioPlayerService(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)?.feedsPostTitle ?? 'Post'),
          actions: [
            if (canEdit)
              IconButton(icon: const Icon(Icons.edit), onPressed: _editPost),
            if (canDelete)
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: _isDeleting ? null : _deletePost,
              ),
          ],
        ),
        body: AppBodyContainer(
          child: _isDeleting
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    const FloatingAudioPlayer(),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.fromLTRB(
                          16,
                          16,
                          16,
                          listBottomPadding,
                        ),
                        children: [
                          if (_post.title != null &&
                              _post.title!.isNotEmpty) ...[
                            Text(
                              _post.title!,
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const SizedBox(height: 12),
                          ],
                          DefaultTextStyle.merge(
                            style:
                                Theme.of(context).textTheme.bodyMedium ??
                                const TextStyle(),
                            child: quill.QuillEditor.basic(
                              controller: postController,
                              config: quill.QuillEditorConfig(
                                showCursor: false,
                                embedBuilders: [
                                  ImageEmbedBuilder(),
                                  VideoEmbedBuilder(),
                                  AudioEmbedBuilder(),
                                  VoiceEmbedBuilder(),
                                  FileEmbedBuilder(),
                                ],
                                unknownEmbedBuilder: UnknownEmbedBuilder(),
                              ),
                            ),
                          ),
                          if (postAttachments.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            for (final attachment in postAttachments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: _buildAttachmentWidget(attachment),
                              ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            _formatTimestamp(
                              context,
                              _post.createdAt,
                              _post.updatedAt,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: _loadingSubscription
                                  ? null
                                  : _toggleSubscription,
                              icon: Icon(
                                _isSubscribed
                                    ? Icons.notifications_active
                                    : Icons.notifications_none,
                              ),
                              label: Text(
                                _isSubscribed
                                    ? (AppLocalizations.of(
                                            context,
                                          )?.feedsUnsubscribeComments ??
                                          'Unsubscribe from comments')
                                    : (AppLocalizations.of(
                                            context,
                                          )?.feedsSubscribeComments ??
                                          'Subscribe to comments'),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            AppLocalizations.of(context)?.feedsComments ??
                                'Comments',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 12),
                          if (_loading)
                            const Center(child: CircularProgressIndicator())
                          else if (_comments.isEmpty)
                            Text(
                              AppLocalizations.of(context)?.feedsNoComments ??
                                  'No comments yet.',
                            )
                          else
                            ..._buildCommentWidgets(tree, null, 0),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        floatingActionButton: _post.allowComments
            ? FloatingActionButton.extended(
                onPressed: () => _openCommentComposer(null),
                icon: const Icon(Icons.add_comment),
                label: Text(
                  AppLocalizations.of(context)?.feedsAddComment ??
                      'Add Comment',
                ),
              )
            : null,
      ),
    );
  }
}

class FeedPostComposer extends StatefulWidget {
  final Feed feed;

  const FeedPostComposer({super.key, required this.feed});

  @override
  State<FeedPostComposer> createState() => _FeedPostComposerState();
}

class FeedPostEditor extends StatefulWidget {
  final Feed feed;
  final FeedPost post;

  const FeedPostEditor({super.key, required this.feed, required this.post});

  @override
  State<FeedPostEditor> createState() => _FeedPostEditorState();
}

class _FeedPostEditorState extends State<FeedPostEditor> {
  late final TextEditingController _titleController;
  late final quill.QuillController _controller;
  bool _isImportant = false;
  bool _allowComments = true;
  bool _isSubmitting = false;
  int _activeToolbarTab = 0;
  bool _showToolbar = false;
  bool _isUploadingAttachment = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title ?? '');
    _controller = quill.QuillController(
      document: widget.post.toDocument(),
      selection: const TextSelection.collapsed(offset: 0),
    );
    _isImportant = widget.post.isImportant;
    _allowComments = widget.post.allowComments;
  }

  void _insertEmbed(String type, String url) {
    final selection = _controller.selection;
    final index = selection.baseOffset < 0
        ? _controller.document.length
        : selection.baseOffset;

    quill.BlockEmbed embed;
    switch (type) {
      case 'image':
        embed = quill.BlockEmbed.image(url);
        break;
      case 'video':
        embed = quill.BlockEmbed.video(url);
        break;
      case 'audio':
      case 'voice':
      case 'file':
        embed = quill.BlockEmbed.custom(quill.CustomBlockEmbed(type, url));
        break;
      default:
        embed = quill.BlockEmbed.custom(quill.CustomBlockEmbed('file', url));
    }

    _controller.document.insert(index, embed);
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );
  }

  Future<void> _pickEditorAttachment({required String attachmentType}) async {
    if (_isUploadingAttachment) return;

    final allowed = <String, List<String>>{
      'image': ['jpg', 'jpeg', 'png', 'webp'],
      'audio': ['mp3', 'm4a', 'ogg', 'opus', 'wav'],
      'video': ['mp4', 'webm', 'mov', 'mkv'],
      'file': [],
    };

    final type = attachmentType == 'file' ? FileType.any : FileType.custom;
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: type == FileType.custom
          ? allowed[attachmentType]
          : null,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _isUploadingAttachment = true;
    });

    final service = context.read<FeedService>();
    final uploaded = await service.uploadMedia(
      mediaType: attachmentType,
      bytes: bytes,
      filename: file.name,
    );

    if (!mounted) return;

    if (uploaded == null) {
      setState(() {
        _isUploadingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.feedsUploadFailed ??
                'Failed to upload media',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isUploadingAttachment = false;
    });

    _insertEmbed(attachmentType, uploaded.url);
  }

  void _showEditorAttachmentMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: Text(
                  AppLocalizations.of(context)?.commonImage ?? 'Image',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickEditorAttachment(attachmentType: 'image');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: Text(
                  AppLocalizations.of(context)?.commonVideo ?? 'Video',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickEditorAttachment(attachmentType: 'video');
                },
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack),
                title: Text(
                  AppLocalizations.of(context)?.commonAudio ?? 'Audio',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickEditorAttachment(attachmentType: 'audio');
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(AppLocalizations.of(context)?.commonFile ?? 'File'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickEditorAttachment(attachmentType: 'file');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleToolbarTab(int index) {
    setState(() {
      if (_activeToolbarTab == index) {
        _showToolbar = !_showToolbar;
      } else {
        _activeToolbarTab = index;
        _showToolbar = true;
      }
    });
  }

  Widget _fontFamilyIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions = options as quill.QuillToolbarFontFamilyButtonOptions;
    final typedExtra =
        extraOptions as quill.QuillToolbarFontFamilyButtonExtraOptions;
    return quill.QuillToolbarIconButton(
      tooltip: typedOptions.tooltip,
      isSelected: false,
      iconTheme: typedOptions.iconTheme,
      onPressed: typedExtra.onPressed,
      icon: const Icon(Icons.font_download_outlined, size: 18),
    );
  }

  Widget _fontSizeIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions = options as quill.QuillToolbarFontSizeButtonOptions;
    final typedExtra =
        extraOptions as quill.QuillToolbarFontSizeButtonExtraOptions;
    return quill.QuillToolbarIconButton(
      tooltip: typedOptions.tooltip,
      isSelected: false,
      iconTheme: typedOptions.iconTheme,
      onPressed: typedExtra.onPressed,
      icon: const Icon(Icons.format_size_outlined, size: 18),
    );
  }

  Widget _headerStyleIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions =
        options as quill.QuillToolbarSelectHeaderStyleDropdownButtonOptions;
    final typedExtra =
        extraOptions
            as quill.QuillToolbarSelectHeaderStyleDropdownButtonExtraOptions;
    return quill.QuillToolbarIconButton(
      tooltip:
          typedOptions.tooltip ??
          (AppLocalizations.of(context)?.feedsParagraphType ??
              'Paragraph type'),
      isSelected: false,
      iconTheme: typedOptions.iconTheme,
      onPressed: typedExtra.onPressed,
      icon: const Icon(Icons.text_fields_outlined, size: 18),
    );
  }

  quill.QuillSimpleToolbarConfig _toolbarConfigForTab(int index) {
    final l10n = AppLocalizations.of(context);
    final isText = index == 0;
    final isFormatting = index == 1;
    final isJustify = index == 2;
    final isLists = index == 3;
    final isAttachments = index == 4;

    return quill.QuillSimpleToolbarConfig(
      buttonOptions: quill.QuillSimpleToolbarButtonOptions(
        fontFamily: quill.QuillToolbarFontFamilyButtonOptions(
          childBuilder: _fontFamilyIconButton,
          tooltip: l10n?.feedsFont ?? 'Font',
        ),
        fontSize: quill.QuillToolbarFontSizeButtonOptions(
          childBuilder: _fontSizeIconButton,
          tooltip: l10n?.feedsSize ?? 'Size',
        ),
        selectHeaderStyleDropdownButton:
            quill.QuillToolbarSelectHeaderStyleDropdownButtonOptions(
              childBuilder: _headerStyleIconButton,
              tooltip: l10n?.feedsParagraphType ?? 'Paragraph type',
            ),
      ),
      showFontFamily: isText,
      showFontSize: isText,
      showHeaderStyle: isText,
      showColorButton: isText,
      showBackgroundColorButton: isText,
      showAlignmentButtons: isJustify,
      showListNumbers: isLists,
      showListBullets: isLists,
      showListCheck: isLists,
      showIndent: isLists,
      showUndo: false,
      showRedo: false,
      showBoldButton: isFormatting,
      showItalicButton: isFormatting,
      showSmallButton: false,
      showUnderLineButton: isFormatting,
      showStrikeThrough: isFormatting,
      showInlineCode: false,
      showClearFormat: false,
      showSubscript: isFormatting,
      showSuperscript: isFormatting,
      showLink: isAttachments,
      showSearchButton: false,
      showCodeBlock: false,
      showQuote: false,
      showLineHeightButton: false,
      showDirection: false,
      customButtons: isAttachments
          ? [
              quill.QuillToolbarCustomButtonOptions(
                icon: Icon(
                  _isUploadingAttachment
                      ? Icons.hourglass_top
                      : Icons.attach_file,
                ),
                tooltip: l10n?.feedsAttach ?? 'Attach',
                onPressed: _isUploadingAttachment
                    ? null
                    : _showEditorAttachmentMenu,
              ),
            ]
          : const [],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildEditorContextMenu(
    BuildContext context,
    quill.QuillRawEditorState editorState,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = editorState.controller;
    final selection = controller.selection;

    // Get button items with error handling for layout issues
    List<ContextMenuButtonItem> buttonItems;
    try {
      buttonItems = editorState.contextMenuButtonItems;
    } catch (e) {
      // If context menu can't be built yet (layout not ready), return empty
      return const SizedBox.shrink();
    }

    // If no selection, just show default buttons
    if (selection.isCollapsed) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editorState.contextMenuAnchors,
        buttonItems: buttonItems,
      );
    }

    // Add custom formatting buttons for text selections
    final formattingButtons = <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.bold);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonBold ?? 'Bold',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.italic);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonItalic ?? 'Italic',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.underline);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonUnderline ?? 'Underline',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.strikeThrough);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonStrike ?? 'Strike',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.subscript);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonSubscript ?? 'Sub',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.superscript);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonSuperscript ?? 'Super',
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editorState.contextMenuAnchors,
      buttonItems: [...formattingButtons, ...buttonItems],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final service = context.read<FeedService>();
    final content = _controller.document.toDelta().toJson();

    final updated = await service.updatePost(
      widget.post.id,
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      content: content,
      isImportant: _isImportant,
      importantRank: widget.post.importantRank,
      allowComments: _allowComments,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (updated != null) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    final mediaQuery = MediaQuery.of(context);
    final isPhone = mediaQuery.size.width < 600;
    final spacing = isPhone ? 8.0 : 12.0;
    final toolbarIconColor =
        Theme.of(context).iconTheme.color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final toolbarActiveColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.feedsEditPost ?? 'Edit post'),
      ),
      body: AppBodyContainer(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isPhone ? 12 : 24,
                  vertical: isPhone ? 12 : 16,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText:
                              AppLocalizations.of(context)?.commonTitle ??
                              'Title',
                        ),
                      ),
                      SizedBox(height: spacing),
                      Row(
                        children: [
                          Expanded(
                            child: IconButton(
                              tooltip:
                                  AppLocalizations.of(
                                    context,
                                  )?.feedsTextTools ??
                                  'Text tools',
                              onPressed: () => _toggleToolbarTab(0),
                              icon: Icon(
                                Icons.text_fields,
                                color: _activeToolbarTab == 0 && _showToolbar
                                    ? toolbarActiveColor
                                    : toolbarIconColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: IconButton(
                              tooltip:
                                  AppLocalizations.of(
                                    context,
                                  )?.feedsTextFormatting ??
                                  'Text formatting',
                              onPressed: () => _toggleToolbarTab(1),
                              icon: Icon(
                                Icons.format_bold,
                                color: _activeToolbarTab == 1 && _showToolbar
                                    ? toolbarActiveColor
                                    : toolbarIconColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: IconButton(
                              tooltip:
                                  AppLocalizations.of(
                                    context,
                                  )?.feedsJustificationTools ??
                                  'Justification tools',
                              onPressed: () => _toggleToolbarTab(2),
                              icon: Icon(
                                Icons.format_align_left,
                                color: _activeToolbarTab == 2 && _showToolbar
                                    ? toolbarActiveColor
                                    : toolbarIconColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: IconButton(
                              tooltip:
                                  AppLocalizations.of(
                                    context,
                                  )?.feedsListsPaddingTools ??
                                  'Lists and padding tools',
                              onPressed: () => _toggleToolbarTab(3),
                              icon: Icon(
                                Icons.format_list_bulleted,
                                color: _activeToolbarTab == 3 && _showToolbar
                                    ? toolbarActiveColor
                                    : toolbarIconColor,
                              ),
                            ),
                          ),
                          Expanded(
                            child: IconButton(
                              tooltip:
                                  AppLocalizations.of(
                                    context,
                                  )?.feedsAttachments ??
                                  'Attachments',
                              onPressed: () => _toggleToolbarTab(4),
                              icon: Icon(
                                Icons.attach_file,
                                color: _activeToolbarTab == 4 && _showToolbar
                                    ? toolbarActiveColor
                                    : toolbarIconColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_showToolbar) ...[
                        SizedBox(height: spacing),
                        quill.QuillSimpleToolbar(
                          controller: _controller,
                          config: _toolbarConfigForTab(_activeToolbarTab),
                        ),
                      ],
                      SizedBox(height: spacing),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: isPhone ? 200 : 240,
                        ),
                        child: quill.QuillEditor.basic(
                          controller: _controller,
                          config: quill.QuillEditorConfig(
                            contextMenuBuilder: _buildEditorContextMenu,
                            embedBuilders: [
                              ImageEmbedBuilder(),
                              VideoEmbedBuilder(),
                              AudioEmbedBuilder(),
                              VoiceEmbedBuilder(),
                              FileEmbedBuilder(),
                            ],
                            unknownEmbedBuilder: UnknownEmbedBuilder(),
                          ),
                        ),
                      ),
                      SizedBox(height: spacing),
                      Row(
                        children: [
                          Checkbox(
                            value: _allowComments,
                            onChanged: (value) {
                              setState(() {
                                _allowComments = value ?? true;
                              });
                            },
                          ),
                          Text(
                            AppLocalizations.of(context)?.feedsAllowComments ??
                                'Allow comments',
                          ),
                        ],
                      ),
                      if (authService.isAdmin ||
                          authService.roles.contains('teacher'))
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
                            Text(
                              AppLocalizations.of(
                                    context,
                                  )?.feedsMarkImportant ??
                                  'Mark as important',
                            ),
                          ],
                        ),
                      SizedBox(height: spacing),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Text(
                              AppLocalizations.of(context)?.commonCancel ??
                                  'Cancel',
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: _isSubmitting ? null : _submit,
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    AppLocalizations.of(context)?.commonSave ??
                                        'Save',
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _FeedPostComposerState extends State<FeedPostComposer> {
  final TextEditingController _titleController = TextEditingController();
  final quill.QuillController _controller = quill.QuillController.basic();
  bool _isImportant = false;
  bool _allowComments = true;
  bool _isSubmitting = false;
  int _activeToolbarTab = 0;
  bool _showToolbar = false;
  bool _isUploadingAttachment = false;
  final List<_PendingAttachment> _pendingAttachments = [];

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _insertEmbed(String type, String url) {
    final selection = _controller.selection;
    final index = selection.baseOffset < 0
        ? _controller.document.length
        : selection.baseOffset;

    quill.BlockEmbed embed;
    switch (type) {
      case 'image':
        embed = quill.BlockEmbed.image(url);
        break;
      case 'video':
        embed = quill.BlockEmbed.video(url);
        break;
      case 'audio':
      case 'voice':
      case 'file':
        embed = quill.BlockEmbed.custom(quill.CustomBlockEmbed(type, url));
        break;
      default:
        embed = quill.BlockEmbed.custom(quill.CustomBlockEmbed('file', url));
    }

    _controller.document.insert(index, embed);
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );
  }

  Future<void> _pickAttachment({
    required String attachmentType,
    required bool inline,
  }) async {
    if (_isUploadingAttachment) return;

    final allowed = <String, List<String>>{
      'image': ['jpg', 'jpeg', 'png', 'webp'],
      'audio': ['mp3', 'm4a', 'ogg', 'opus', 'wav'],
      'video': ['mp4', 'webm', 'mov', 'mkv'],
      'file': [],
    };

    final type = attachmentType == 'file' ? FileType.any : FileType.custom;
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: type == FileType.custom
          ? allowed[attachmentType]
          : null,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _isUploadingAttachment = true;
    });

    final service = context.read<FeedService>();
    final uploaded = await service.uploadMedia(
      mediaType: attachmentType,
      bytes: bytes,
      filename: file.name,
    );

    if (!mounted) return;

    if (uploaded == null) {
      setState(() {
        _isUploadingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.feedsUploadFailed ??
                'Failed to upload media',
          ),
        ),
      );
      return;
    }

    final attachment = _PendingAttachment(
      input: ChatAttachmentInput(
        mediaId: uploaded.id,
        attachmentType: attachmentType,
      ),
      url: uploaded.url,
      attachmentType: attachmentType,
      inline: inline,
    );

    setState(() {
      _pendingAttachments.add(attachment);
      _isUploadingAttachment = false;
    });

    if (inline) {
      _insertEmbed(attachmentType, uploaded.url);
    }
  }

  void _showAttachmentMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: Text(
                  AppLocalizations.of(context)?.commonImage ?? 'Image',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'image', inline: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: Text(
                  AppLocalizations.of(context)?.commonVideo ?? 'Video',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'video', inline: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack),
                title: Text(
                  AppLocalizations.of(context)?.commonAudio ?? 'Audio',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'audio', inline: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(AppLocalizations.of(context)?.commonFile ?? 'File'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'file', inline: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleToolbarTab(int index) {
    setState(() {
      if (_activeToolbarTab == index) {
        _showToolbar = !_showToolbar;
      } else {
        _activeToolbarTab = index;
        _showToolbar = true;
      }
    });
  }

  Widget _fontFamilyIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions = options as quill.QuillToolbarFontFamilyButtonOptions;
    final typedExtra =
        extraOptions as quill.QuillToolbarFontFamilyButtonExtraOptions;
    return quill.QuillToolbarIconButton(
      tooltip: typedOptions.tooltip,
      isSelected: false,
      iconTheme: typedOptions.iconTheme,
      onPressed: typedExtra.onPressed,
      icon: const Icon(Icons.font_download_outlined, size: 18),
    );
  }

  Widget _fontSizeIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions = options as quill.QuillToolbarFontSizeButtonOptions;
    final typedExtra =
        extraOptions as quill.QuillToolbarFontSizeButtonExtraOptions;
    return quill.QuillToolbarIconButton(
      tooltip: typedOptions.tooltip,
      isSelected: false,
      iconTheme: typedOptions.iconTheme,
      onPressed: typedExtra.onPressed,
      icon: const Icon(Icons.format_size_outlined, size: 18),
    );
  }

  Widget _headerStyleIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions =
        options as quill.QuillToolbarSelectHeaderStyleDropdownButtonOptions;
    final typedExtra =
        extraOptions
            as quill.QuillToolbarSelectHeaderStyleDropdownButtonExtraOptions;
    return quill.QuillToolbarIconButton(
      tooltip:
          typedOptions.tooltip ??
          (AppLocalizations.of(context)?.feedsParagraphType ??
              'Paragraph type'),
      isSelected: false,
      iconTheme: typedOptions.iconTheme,
      onPressed: typedExtra.onPressed,
      icon: const Icon(Icons.text_fields_outlined, size: 18),
    );
  }

  quill.QuillSimpleToolbarConfig _toolbarConfigForTab(int index) {
    final l10n = AppLocalizations.of(context);
    final isText = index == 0;
    final isFormatting = index == 1;
    final isJustify = index == 2;
    final isLists = index == 3;
    final isAttachments = index == 4;

    return quill.QuillSimpleToolbarConfig(
      buttonOptions: quill.QuillSimpleToolbarButtonOptions(
        fontFamily: quill.QuillToolbarFontFamilyButtonOptions(
          childBuilder: _fontFamilyIconButton,
          tooltip: l10n?.feedsFont ?? 'Font',
        ),
        fontSize: quill.QuillToolbarFontSizeButtonOptions(
          childBuilder: _fontSizeIconButton,
          tooltip: l10n?.feedsSize ?? 'Size',
        ),
        selectHeaderStyleDropdownButton:
            quill.QuillToolbarSelectHeaderStyleDropdownButtonOptions(
              childBuilder: _headerStyleIconButton,
              tooltip: l10n?.feedsParagraphType ?? 'Paragraph type',
            ),
      ),
      showFontFamily: isText,
      showFontSize: isText,
      showHeaderStyle: isText,
      showColorButton: isText,
      showBackgroundColorButton: isText,
      showAlignmentButtons: isJustify,
      showListNumbers: isLists,
      showListBullets: isLists,
      showListCheck: isLists,
      showIndent: isLists,
      showUndo: false,
      showRedo: false,
      showBoldButton: isFormatting,
      showItalicButton: isFormatting,
      showSmallButton: false,
      showUnderLineButton: isFormatting,
      showStrikeThrough: isFormatting,
      showInlineCode: false,
      showClearFormat: false,
      showSubscript: isFormatting,
      showSuperscript: isFormatting,
      showLink: isAttachments,
      showSearchButton: false,
      showCodeBlock: false,
      showQuote: false,
      showLineHeightButton: false,
      showDirection: false,
      customButtons: isAttachments
          ? [
              quill.QuillToolbarCustomButtonOptions(
                icon: Icon(
                  _isUploadingAttachment
                      ? Icons.hourglass_top
                      : Icons.attach_file,
                ),
                tooltip: l10n?.feedsAttach ?? 'Attach',
                onPressed: _isUploadingAttachment ? null : _showAttachmentMenu,
              ),
            ]
          : const [],
    );
  }

  Widget _buildEditorContextMenu(
    BuildContext context,
    quill.QuillRawEditorState editorState,
  ) {
    final l10n = AppLocalizations.of(context);
    final controller = editorState.controller;
    final selection = controller.selection;

    List<ContextMenuButtonItem> buttonItems;
    try {
      buttonItems = editorState.contextMenuButtonItems;
    } catch (e) {
      return const SizedBox.shrink();
    }

    if (selection.isCollapsed) {
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editorState.contextMenuAnchors,
        buttonItems: buttonItems,
      );
    }

    final formattingButtons = <ContextMenuButtonItem>[
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.bold);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonBold ?? 'Bold',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.italic);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonItalic ?? 'Italic',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.underline);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonUnderline ?? 'Underline',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.strikeThrough);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonStrike ?? 'Strike',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.subscript);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonSubscript ?? 'Sub',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.superscript);
          controller.updateSelection(
            TextSelection.collapsed(offset: selection.end),
            quill.ChangeSource.local,
          );
          ContextMenuController.removeAny();
        },
        label: l10n?.commonSuperscript ?? 'Super',
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editorState.contextMenuAnchors,
      buttonItems: [...formattingButtons, ...buttonItems],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final service = context.read<FeedService>();
    final content = _controller.document.toDelta().toJson();
    final attachments = _pendingAttachments.map((a) => a.input).toList();

    final created = await service.createPost(
      widget.feed.id,
      title: _titleController.text.trim().isEmpty
          ? null
          : _titleController.text.trim(),
      content: content,
      isImportant: _isImportant,
      allowComments: _allowComments,
      attachments: attachments.isEmpty ? null : attachments,
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
    final mediaQuery = MediaQuery.of(context);
    final isPhone = mediaQuery.size.width < 600;
    final spacing = isPhone ? 8.0 : 12.0;
    final toolbarIconColor =
        Theme.of(context).iconTheme.color ??
        Theme.of(context).colorScheme.onSurfaceVariant;
    final toolbarActiveColor = Theme.of(context).colorScheme.primary;
    final nonInlineAttachments = _pendingAttachments
        .where((item) => !item.inline)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.feedsNewPost ?? 'New post'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isPhone ? 12 : 24,
                vertical: isPhone ? 12 : 16,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText:
                            AppLocalizations.of(context)?.commonTitle ??
                            'Title',
                      ),
                    ),
                    SizedBox(height: spacing),
                    Row(
                      children: [
                        Expanded(
                          child: IconButton(
                            tooltip:
                                AppLocalizations.of(context)?.feedsTextTools ??
                                'Text tools',
                            onPressed: () => _toggleToolbarTab(0),
                            icon: Icon(
                              Icons.text_fields,
                              color: _activeToolbarTab == 0 && _showToolbar
                                  ? toolbarActiveColor
                                  : toolbarIconColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            tooltip:
                                AppLocalizations.of(
                                  context,
                                )?.feedsTextFormatting ??
                                'Text formatting',
                            onPressed: () => _toggleToolbarTab(1),
                            icon: Icon(
                              Icons.format_bold,
                              color: _activeToolbarTab == 1 && _showToolbar
                                  ? toolbarActiveColor
                                  : toolbarIconColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            tooltip:
                                AppLocalizations.of(
                                  context,
                                )?.feedsJustificationTools ??
                                'Justification tools',
                            onPressed: () => _toggleToolbarTab(2),
                            icon: Icon(
                              Icons.format_align_left,
                              color: _activeToolbarTab == 2 && _showToolbar
                                  ? toolbarActiveColor
                                  : toolbarIconColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            tooltip:
                                AppLocalizations.of(
                                  context,
                                )?.feedsListsPaddingTools ??
                                'Lists and padding tools',
                            onPressed: () => _toggleToolbarTab(3),
                            icon: Icon(
                              Icons.format_list_bulleted,
                              color: _activeToolbarTab == 3 && _showToolbar
                                  ? toolbarActiveColor
                                  : toolbarIconColor,
                            ),
                          ),
                        ),
                        Expanded(
                          child: IconButton(
                            tooltip:
                                AppLocalizations.of(
                                  context,
                                )?.feedsAttachments ??
                                'Attachments',
                            onPressed: () => _toggleToolbarTab(4),
                            icon: Icon(
                              Icons.attach_file,
                              color: _activeToolbarTab == 4 && _showToolbar
                                  ? toolbarActiveColor
                                  : toolbarIconColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_showToolbar) ...[
                      SizedBox(height: spacing),
                      quill.QuillSimpleToolbar(
                        controller: _controller,
                        config: _toolbarConfigForTab(_activeToolbarTab),
                      ),
                    ],
                    SizedBox(height: spacing),
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: isPhone ? 200 : 240,
                      ),
                      child: quill.QuillEditor.basic(
                        controller: _controller,
                        config: quill.QuillEditorConfig(
                          contextMenuBuilder: _buildEditorContextMenu,
                          embedBuilders: [
                            ImageEmbedBuilder(),
                            VideoEmbedBuilder(),
                            AudioEmbedBuilder(),
                            VoiceEmbedBuilder(),
                            FileEmbedBuilder(),
                          ],
                          unknownEmbedBuilder: UnknownEmbedBuilder(),
                        ),
                      ),
                    ),
                    if (nonInlineAttachments.isNotEmpty) ...[
                      SizedBox(height: spacing),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: nonInlineAttachments.map((item) {
                          return Chip(
                            label: Text(item.label(context)),
                            onDeleted: () {
                              setState(() {
                                _pendingAttachments.remove(item);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ],
                    SizedBox(height: spacing),
                    Row(
                      children: [
                        Checkbox(
                          value: _allowComments,
                          onChanged: (value) {
                            setState(() {
                              _allowComments = value ?? true;
                            });
                          },
                        ),
                        Text(
                          AppLocalizations.of(context)?.feedsAllowComments ??
                              'Allow comments',
                        ),
                      ],
                    ),
                    if (authService.isAdmin ||
                        authService.roles.contains('teacher'))
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
                          Text(
                            AppLocalizations.of(context)?.feedsMarkImportant ??
                                'Mark as important',
                          ),
                        ],
                      ),
                    SizedBox(height: spacing),
                    Row(
                      children: [
                        TextButton(
                          onPressed: _isSubmitting
                              ? null
                              : () => Navigator.of(context).pop(false),
                          child: Text(
                            AppLocalizations.of(context)?.commonCancel ??
                                'Cancel',
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  AppLocalizations.of(context)?.commonPost ??
                                      'Post',
                                ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
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

class FeedCommentEditor extends StatefulWidget {
  final int postId;
  final FeedComment comment;

  const FeedCommentEditor({
    super.key,
    required this.postId,
    required this.comment,
  });

  @override
  State<FeedCommentEditor> createState() => _FeedCommentEditorState();
}

class _FeedCommentEditorState extends State<FeedCommentEditor> {
  late final quill.QuillController _controller;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController(
      document: widget.comment.toDocument(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final service = context.read<FeedService>();
    final content = _controller.document.toDelta().toJson();

    final updated = await service.updateComment(
      widget.postId,
      widget.comment.id,
      content: content,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (updated != null) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      title: Text(
        AppLocalizations.of(context)?.feedsEditComment ?? 'Edit comment',
      ),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QuillEditorComposer(
              controller: _controller,
              config: const QuillEditorComposerConfig(
                minHeight: 80,
                maxHeight: 180,
                showAttachButton: false,
                showVoiceButton: false,
                showSendButton: false,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context)?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}

class _FeedCommentComposerState extends State<FeedCommentComposer> {
  final quill.QuillController _controller = quill.QuillController.basic();
  bool _isSubmitting = false;
  bool _isUploadingAttachment = false;
  final List<_PendingAttachment> _pendingAttachments = [];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _insertEmbed(String type, String url) {
    final selection = _controller.selection;
    final index = selection.baseOffset < 0
        ? _controller.document.length
        : selection.baseOffset;

    quill.BlockEmbed embed;
    switch (type) {
      case 'image':
        embed = quill.BlockEmbed.image(url);
        break;
      case 'video':
        embed = quill.BlockEmbed.video(url);
        break;
      case 'audio':
      case 'voice':
      case 'file':
        embed = quill.BlockEmbed.custom(quill.CustomBlockEmbed(type, url));
        break;
      default:
        embed = quill.BlockEmbed.custom(quill.CustomBlockEmbed('file', url));
    }

    _controller.document.insert(index, embed);
    _controller.updateSelection(
      TextSelection.collapsed(offset: index + 1),
      quill.ChangeSource.local,
    );
  }

  Future<void> _pickAttachment({
    required String attachmentType,
    required bool inline,
  }) async {
    if (_isUploadingAttachment) return;

    final allowed = <String, List<String>>{
      'image': ['jpg', 'jpeg', 'png', 'webp'],
      'audio': ['mp3', 'm4a', 'ogg', 'opus', 'wav'],
      'video': ['mp4', 'webm', 'mov', 'mkv'],
      'file': [],
    };

    final type = attachmentType == 'file' ? FileType.any : FileType.custom;
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: type == FileType.custom
          ? allowed[attachmentType]
          : null,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() {
      _isUploadingAttachment = true;
    });

    final service = context.read<FeedService>();
    final uploaded = await service.uploadMedia(
      mediaType: attachmentType,
      bytes: bytes,
      filename: file.name,
    );

    if (!mounted) return;

    if (uploaded == null) {
      setState(() {
        _isUploadingAttachment = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.feedsUploadFailed ??
                'Failed to upload media',
          ),
        ),
      );
      return;
    }

    final attachment = _PendingAttachment(
      input: ChatAttachmentInput(
        mediaId: uploaded.id,
        attachmentType: attachmentType,
      ),
      url: uploaded.url,
      attachmentType: attachmentType,
      inline: inline,
    );

    setState(() {
      _pendingAttachments.add(attachment);
      _isUploadingAttachment = false;
    });

    if (inline) {
      _insertEmbed(attachmentType, uploaded.url);
    }
  }

  Future<void> _showAttachmentMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.image),
                title: Text(
                  AppLocalizations.of(context)?.commonImage ?? 'Image',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'image', inline: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: Text(
                  AppLocalizations.of(context)?.commonVideo ?? 'Video',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'video', inline: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.audiotrack),
                title: Text(
                  AppLocalizations.of(context)?.commonAudio ?? 'Audio',
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'audio', inline: true);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: Text(AppLocalizations.of(context)?.commonFile ?? 'File'),
                onTap: () {
                  Navigator.of(context).pop();
                  _pickAttachment(attachmentType: 'file', inline: false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    final service = context.read<FeedService>();
    final content = _controller.document.toDelta().toJson();
    final attachments = _pendingAttachments.map((a) => a.input).toList();

    final created = await service.createComment(
      widget.postId,
      parentCommentId: widget.parentCommentId,
      content: content,
      attachments: attachments.isEmpty ? null : attachments,
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      title: Text(
        AppLocalizations.of(context)?.feedsNewComment ?? 'New comment',
      ),
      content: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_pendingAttachments.isNotEmpty)
              SizedBox(
                height: 48,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  scrollDirection: Axis.horizontal,
                  itemCount: _pendingAttachments.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, index) {
                    final item = _pendingAttachments[index];
                    return Chip(
                      label: Text(item.label(context)),
                      onDeleted: () {
                        setState(() {
                          _pendingAttachments.removeAt(index);
                        });
                      },
                    );
                  },
                ),
              ),
            if (_pendingAttachments.isNotEmpty) const SizedBox(height: 12),
            QuillEditorComposer(
              controller: _controller,
              config: const QuillEditorComposerConfig(
                minHeight: 80,
                maxHeight: 200,
                showAttachButton: true,
                showVoiceButton: false,
                showSendButton: false,
              ),
              onAttachmentSelected: _showAttachmentMenu,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context)?.commonPost ?? 'Post'),
        ),
      ],
    );
  }
}

class _PendingAttachment {
  final ChatAttachmentInput input;
  final String url;
  final String attachmentType;
  final bool inline;

  _PendingAttachment({
    required this.input,
    required this.url,
    required this.attachmentType,
    required this.inline,
  });

  String label(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final localizedType = () {
      switch (attachmentType) {
        case 'image':
          return l10n?.commonImage ?? 'Image';
        case 'video':
          return l10n?.commonVideo ?? 'Video';
        case 'audio':
          return l10n?.commonAudio ?? 'Audio';
        case 'voice':
          return l10n?.commonVoiceMessage ?? 'Voice message';
        case 'file':
          return l10n?.commonFile ?? 'File';
        default:
          return attachmentType;
      }
    }();
    if (inline) {
      return l10n?.feedsAttachmentInline(localizedType) ??
          '$localizedType (inline)';
    }
    return localizedType;
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      title: Text(
        AppLocalizations.of(context)?.feedsSettingsTitle ?? 'Feed settings',
      ),
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
              title: Text(
                AppLocalizations.of(context)?.feedsAllowStudentPosts ??
                    'Allow student posts',
              ),
            ),
          SwitchListTile(
            value: _autoSubscribe,
            onChanged: (value) {
              setState(() {
                _autoSubscribe = value;
              });
            },
            title: Text(
              AppLocalizations.of(context)?.feedsAutoSubscribe ??
                  'Auto-subscribe to new posts',
            ),
          ),
          SwitchListTile(
            value: _notifyNewPosts,
            onChanged: (value) {
              setState(() {
                _notifyNewPosts = value;
              });
            },
            title: Text(
              AppLocalizations.of(context)?.feedsNotifyNewPosts ??
                  'Notify on new posts',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(AppLocalizations.of(context)?.commonSave ?? 'Save'),
        ),
      ],
    );
  }
}
