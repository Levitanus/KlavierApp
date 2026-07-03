part of '../feeds_screen.dart';

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
  final MenuController _fontFamilyMenuController = MenuController();
  final MenuController _fontSizeMenuController = MenuController();
  final MenuController _headerStyleMenuController = MenuController();
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

  void _toggleMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
    } else {
      controller.open();
    }
  }

  Map<String, String> _fontFamilyItems(
    quill.QuillToolbarFontFamilyButtonOptions options,
  ) {
    return options.items ??
        {
          'Sans Serif': 'sans-serif',
          'Serif': 'serif',
          'Monospace': 'monospace',
          'Ibarra Real Nova': 'ibarra-real-nova',
          'SquarePeg': 'square-peg',
          'Nunito': 'nunito',
          'Pacifico': 'pacifico',
          'Roboto Mono': 'roboto-mono',
          'Clear': 'Clear',
        };
  }

  Map<String, String> _fontSizeItems(
    quill.QuillToolbarFontSizeButtonOptions options,
  ) {
    return options.items ??
        {'Small': 'small', 'Large': 'large', 'Huge': 'huge', 'Clear': '0'};
  }

  List<quill.Attribute<int?>> _headerAttributes(
    quill.QuillToolbarSelectHeaderStyleDropdownButtonOptions options,
  ) {
    return options.attributes ??
        [
          quill.Attribute.h1,
          quill.Attribute.h2,
          quill.Attribute.h3,
          quill.Attribute.h4,
          quill.Attribute.h5,
          quill.Attribute.h6,
          quill.Attribute.header,
        ];
  }

  String _headerLabel(quill.Attribute<dynamic> value) {
    if (value == quill.Attribute.h1) return 'Heading 1';
    if (value == quill.Attribute.h2) return 'Heading 2';
    if (value == quill.Attribute.h3) return 'Heading 3';
    if (value == quill.Attribute.h4) return 'Heading 4';
    if (value == quill.Attribute.h5) return 'Heading 5';
    if (value == quill.Attribute.h6) return 'Heading 6';
    return AppLocalizations.of(context)?.feedsParagraphType ?? 'Normal';
  }

  Widget _fontFamilyIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions = options as quill.QuillToolbarFontFamilyButtonOptions;
    final typedExtra =
        extraOptions as quill.QuillToolbarFontFamilyButtonExtraOptions;
    final items = _fontFamilyItems(typedOptions);

    return MenuAnchor(
      controller: _fontFamilyMenuController,
      menuChildren: items.entries
          .map(
            (fontFamily) => MenuItemButton(
              onPressed: () {
                final value = fontFamily.value;
                typedExtra.controller.formatSelection(
                  quill.Attribute.fromKeyValue(
                    quill.Attribute.font.key,
                    value == 'Clear' ? null : value,
                  ),
                );
                typedOptions.onSelected?.call(value);
              },
              child: Text(fontFamily.key),
            ),
          )
          .toList(),
      child: quill.QuillToolbarIconButton(
        tooltip: typedOptions.tooltip,
        isSelected: false,
        iconTheme: typedOptions.iconTheme,
        onPressed: () => _toggleMenu(_fontFamilyMenuController),
        icon: const Icon(Icons.font_download_outlined, size: 18),
      ),
    );
  }

  Widget _fontSizeIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions = options as quill.QuillToolbarFontSizeButtonOptions;
    final typedExtra =
        extraOptions as quill.QuillToolbarFontSizeButtonExtraOptions;
    final items = _fontSizeItems(typedOptions);

    return MenuAnchor(
      controller: _fontSizeMenuController,
      menuChildren: items.entries
          .map(
            (fontSize) => MenuItemButton(
              onPressed: () {
                final value = fontSize.value;
                typedExtra.controller.formatSelection(
                  quill.Attribute.fromKeyValue(
                    quill.Attribute.size.key,
                    value == '0' ? null : value,
                  ),
                );
                typedOptions.onSelected?.call(value);
              },
              child: Text(fontSize.key),
            ),
          )
          .toList(),
      child: quill.QuillToolbarIconButton(
        tooltip: typedOptions.tooltip,
        isSelected: false,
        iconTheme: typedOptions.iconTheme,
        onPressed: () => _toggleMenu(_fontSizeMenuController),
        icon: const Icon(Icons.format_size_outlined, size: 18),
      ),
    );
  }

  Widget _headerStyleIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions =
        options as quill.QuillToolbarSelectHeaderStyleDropdownButtonOptions;
    final typedExtra =
        extraOptions
            as quill.QuillToolbarSelectHeaderStyleDropdownButtonExtraOptions;
    final attributes = _headerAttributes(typedOptions);

    return MenuAnchor(
      controller: _headerStyleMenuController,
      menuChildren: attributes
          .map(
            (attribute) => MenuItemButton(
              onPressed: () {
                typedExtra.controller.formatSelection(attribute);
              },
              child: Text(_headerLabel(attribute)),
            ),
          )
          .toList(),
      child: quill.QuillToolbarIconButton(
        tooltip:
            typedOptions.tooltip ??
            (AppLocalizations.of(context)?.feedsParagraphType ??
                'Paragraph type'),
        isSelected: false,
        iconTheme: typedOptions.iconTheme,
        onPressed: () => _toggleMenu(_headerStyleMenuController),
        icon: const Icon(Icons.text_fields_outlined, size: 18),
      ),
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
      showQuote: isText,
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
                            embedBuilders: defaultQuillEmbedBuilders(),
                            unknownEmbedBuilder: defaultUnknownEmbedBuilder(),
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
  final MenuController _fontFamilyMenuController = MenuController();
  final MenuController _fontSizeMenuController = MenuController();
  final MenuController _headerStyleMenuController = MenuController();
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

  void _toggleMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
    } else {
      controller.open();
    }
  }

  Map<String, String> _fontFamilyItems(
    quill.QuillToolbarFontFamilyButtonOptions options,
  ) {
    return options.items ??
        {
          'Sans Serif': 'sans-serif',
          'Serif': 'serif',
          'Monospace': 'monospace',
          'Ibarra Real Nova': 'ibarra-real-nova',
          'SquarePeg': 'square-peg',
          'Nunito': 'nunito',
          'Pacifico': 'pacifico',
          'Roboto Mono': 'roboto-mono',
          'Clear': 'Clear',
        };
  }

  Map<String, String> _fontSizeItems(
    quill.QuillToolbarFontSizeButtonOptions options,
  ) {
    return options.items ??
        {'Small': 'small', 'Large': 'large', 'Huge': 'huge', 'Clear': '0'};
  }

  List<quill.Attribute<int?>> _headerAttributes(
    quill.QuillToolbarSelectHeaderStyleDropdownButtonOptions options,
  ) {
    return options.attributes ??
        [
          quill.Attribute.h1,
          quill.Attribute.h2,
          quill.Attribute.h3,
          quill.Attribute.h4,
          quill.Attribute.h5,
          quill.Attribute.h6,
          quill.Attribute.header,
        ];
  }

  String _headerLabel(quill.Attribute<dynamic> value) {
    if (value == quill.Attribute.h1) return 'Heading 1';
    if (value == quill.Attribute.h2) return 'Heading 2';
    if (value == quill.Attribute.h3) return 'Heading 3';
    if (value == quill.Attribute.h4) return 'Heading 4';
    if (value == quill.Attribute.h5) return 'Heading 5';
    if (value == quill.Attribute.h6) return 'Heading 6';
    return AppLocalizations.of(context)?.feedsParagraphType ?? 'Normal';
  }

  Widget _fontFamilyIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions = options as quill.QuillToolbarFontFamilyButtonOptions;
    final typedExtra =
        extraOptions as quill.QuillToolbarFontFamilyButtonExtraOptions;
    final items = _fontFamilyItems(typedOptions);

    return MenuAnchor(
      controller: _fontFamilyMenuController,
      menuChildren: items.entries
          .map(
            (fontFamily) => MenuItemButton(
              onPressed: () {
                final value = fontFamily.value;
                typedExtra.controller.formatSelection(
                  quill.Attribute.fromKeyValue(
                    quill.Attribute.font.key,
                    value == 'Clear' ? null : value,
                  ),
                );
                typedOptions.onSelected?.call(value);
              },
              child: Text(fontFamily.key),
            ),
          )
          .toList(),
      child: quill.QuillToolbarIconButton(
        tooltip: typedOptions.tooltip,
        isSelected: false,
        iconTheme: typedOptions.iconTheme,
        onPressed: () => _toggleMenu(_fontFamilyMenuController),
        icon: const Icon(Icons.font_download_outlined, size: 18),
      ),
    );
  }

  Widget _fontSizeIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions = options as quill.QuillToolbarFontSizeButtonOptions;
    final typedExtra =
        extraOptions as quill.QuillToolbarFontSizeButtonExtraOptions;
    final items = _fontSizeItems(typedOptions);

    return MenuAnchor(
      controller: _fontSizeMenuController,
      menuChildren: items.entries
          .map(
            (fontSize) => MenuItemButton(
              onPressed: () {
                final value = fontSize.value;
                typedExtra.controller.formatSelection(
                  quill.Attribute.fromKeyValue(
                    quill.Attribute.size.key,
                    value == '0' ? null : value,
                  ),
                );
                typedOptions.onSelected?.call(value);
              },
              child: Text(fontSize.key),
            ),
          )
          .toList(),
      child: quill.QuillToolbarIconButton(
        tooltip: typedOptions.tooltip,
        isSelected: false,
        iconTheme: typedOptions.iconTheme,
        onPressed: () => _toggleMenu(_fontSizeMenuController),
        icon: const Icon(Icons.format_size_outlined, size: 18),
      ),
    );
  }

  Widget _headerStyleIconButton(dynamic options, dynamic extraOptions) {
    final typedOptions =
        options as quill.QuillToolbarSelectHeaderStyleDropdownButtonOptions;
    final typedExtra =
        extraOptions
            as quill.QuillToolbarSelectHeaderStyleDropdownButtonExtraOptions;
    final attributes = _headerAttributes(typedOptions);

    return MenuAnchor(
      controller: _headerStyleMenuController,
      menuChildren: attributes
          .map(
            (attribute) => MenuItemButton(
              onPressed: () {
                typedExtra.controller.formatSelection(attribute);
              },
              child: Text(_headerLabel(attribute)),
            ),
          )
          .toList(),
      child: quill.QuillToolbarIconButton(
        tooltip:
            typedOptions.tooltip ??
            (AppLocalizations.of(context)?.feedsParagraphType ??
                'Paragraph type'),
        isSelected: false,
        iconTheme: typedOptions.iconTheme,
        onPressed: () => _toggleMenu(_headerStyleMenuController),
        icon: const Icon(Icons.text_fields_outlined, size: 18),
      ),
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
      showQuote: isText,
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
                          embedBuilders: defaultQuillEmbedBuilders(),
                          unknownEmbedBuilder: defaultUnknownEmbedBuilder(),
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

