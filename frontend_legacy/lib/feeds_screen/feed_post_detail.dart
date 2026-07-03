part of '../feeds_screen.dart';

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
  static String get _baseUrl => AppConfig.instance.baseUrl;

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
    if (!mounted) return;

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

  ImageProvider? _commentAuthorAvatarImage(FeedComment comment) {
    final profileImage = comment.authorProfileImage;
    if (profileImage == null || profileImage.isEmpty) return null;
    return MediaCacheService.instance.imageProvider(
      '$_baseUrl/uploads/profile_images/$profileImage',
    );
  }

  String _commentAuthorDisplayName(FeedComment comment) {
    final name = comment.authorName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'User #${comment.authorUserId}';
  }

  String _initialsFromName(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
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
      final isOwnComment = (auth.userId ?? -1) == comment.authorUserId;
      final authorName = _commentAuthorDisplayName(comment);
      final authorAvatar = _commentAuthorAvatarImage(comment);
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
              if (!isOwnComment) ...[
                Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundImage: authorAvatar,
                      child: authorAvatar == null
                          ? Text(
                              _initialsFromName(authorName),
                              style: const TextStyle(fontSize: 11),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        authorName,
                        style: Theme.of(context).textTheme.labelLarge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              DefaultTextStyle.merge(
                style:
                    Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
                child: quill.QuillEditor.basic(
                  controller: controller,
                  config: quill.QuillEditorConfig(
                    showCursor: false,
                    embedBuilders: defaultQuillEmbedBuilders(),
                    unknownEmbedBuilder: defaultUnknownEmbedBuilder(),
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
                  if (isOwnComment)
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
    if (!mounted) return;

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
                                embedBuilders: defaultQuillEmbedBuilders(),
                                unknownEmbedBuilder:
                                    defaultUnknownEmbedBuilder(),
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

