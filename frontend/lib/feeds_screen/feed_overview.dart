part of '../feeds_screen.dart';

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
                            embedBuilders: defaultQuillEmbedBuilders(),
                            unknownEmbedBuilder: defaultUnknownEmbedBuilder(),
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
                              ).colorScheme.surface.withValues(alpha: 0),
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
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: onOpen,
                  child: Text(l10n?.feedsReadAndDiscuss ?? 'Read and discuss'),
                ),
                Text(
                  l10n?.feedsPostedAt(
                        '${post.createdAt.toLocal()}'.split('.').first,
                      ) ??
                      'Posted ${post.createdAt.toLocal()}'.split('.').first,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

