part of '../feeds_screen.dart';

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
    if (!mounted) return;

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

