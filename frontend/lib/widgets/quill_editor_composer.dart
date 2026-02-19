import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../widgets/quill_embed_builders.dart';
// import '../utils/voice_recorder.dart';
import '../l10n/app_localizations.dart';

/// Configuration for the QuillEditorComposer
class QuillEditorComposerConfig {
  final bool showAttachButton;
  final bool showVoiceButton;
  final bool showSendButton;
  final double minHeight;
  final double maxHeight;
  final bool readOnly;
  final String? sendButtonTooltip;

  const QuillEditorComposerConfig({
    this.showAttachButton = true,
    this.showVoiceButton = true,
    this.showSendButton = true,
    this.minHeight = 40,
    this.maxHeight = 120,
    this.readOnly = false,
    this.sendButtonTooltip,
  });
}

class QuillEditorComposer extends StatefulWidget {
  final quill.QuillController controller;
  final QuillEditorComposerConfig config;
  final VoidCallback? onSendPressed;
  final Future<void> Function()? onAttachmentSelected;
  final Future<void> Function(List<int> bytes, String filename)?
  onVoiceRecorded;
  final Key? controlKey;
  final FocusNode? focusNode;

  const QuillEditorComposer({
    Key? key,
    required this.controller,
    this.config = const QuillEditorComposerConfig(),
    this.onSendPressed,
    this.onAttachmentSelected,
    this.onVoiceRecorded,
    this.controlKey,
    this.focusNode,
  }) : super(key: key);

  @override
  State<QuillEditorComposer> createState() => _QuillEditorComposerState();
}

class _QuillEditorComposerState extends State<QuillEditorComposer> {
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  bool _isUploadingAttachment = false;
  bool get _sendOnEnterEnabled {
    return defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows;
  }
  // final VoiceRecorder _voiceRecorder = VoiceRecorder();

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  Future<void> _onAttachmentSelected() async {
    if (widget.onAttachmentSelected == null) return;

    setState(() {
      _isUploadingAttachment = true;
    });

    try {
      await widget.onAttachmentSelected!();
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingAttachment = false;
        });
      }
    }
  }

  // Future<void> _onVoiceRecorded() async {
  //   try {
  //     if (_voiceRecorder.isRecording) {
  //       // Stop recording and wait a bit for the file to be fully written
  //       final audio = await _voiceRecorder.stop();
  //       if (audio == null) {
  //         if (mounted) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(
  //               content: Text(
  //                 AppLocalizations.of(context)?.voiceRecordFailed ??
  //                     'Failed to record audio',
  //               ),
  //             ),
  //           );
  //         }
  //         return;
  //       }

  //       // Give the system time to finalize the audio file (wait for OggWriter)
  //       await Future.delayed(const Duration(milliseconds: 300));

  //       if (mounted && widget.onVoiceRecorded != null) {
  //         final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.${audio.extension}';
  //         await widget.onVoiceRecorded!(audio.bytes, filename);
  //         // Update UI to show recording stopped
  //         setState(() {});
  //       }
  //     } else {
  //       // Check if voice recording is available
  //       final available = await _voiceRecorder.isAvailable();
  //       if (!available) {
  //         if (mounted) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             SnackBar(
  //               content: Text(
  //                 AppLocalizations.of(context)?.voiceRecordUnavailable ??
  //                     'Voice recording not available',
  //               ),
  //             ),
  //           );
  //         }
  //         return;
  //       }
  //       // Start recording
  //       await _voiceRecorder.start();
  //       if (mounted) {
  //         setState(() {});
  //       }
  //     }
  //   } catch (e) {
  //     if (mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             AppLocalizations.of(context)?.voiceRecordError(e.toString()) ??
  //                 'Voice error: ${e.toString()}',
  //           ),
  //         ),
  //       );
  //     }
  //   }
  // }

  void _insertNewline() {
    final index = widget.controller.selection.extentOffset;
    widget.controller.replaceText(
      index,
      0,
      '\n',
      TextSelection.collapsed(offset: index + 1),
    );
  }

  void _promptForLink() async {
    final selection = widget.controller.selection;
    if (selection.isCollapsed) return;

    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(
          AppLocalizations.of(context)?.commonInsertLink ?? 'Insert link',
        ),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)?.commonUrl ?? 'URL',
            border: const OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)?.commonApply ?? 'Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final url = controller.text.trim();
    if (url.isEmpty) return;

    widget.controller.formatSelection(quill.LinkAttribute(url));
  }

  void _applySelectionAttribute(quill.Attribute<dynamic> attribute) {
    final selection = widget.controller.selection;
    if (selection.isCollapsed) {
      widget.controller.formatSelection(attribute);
      return;
    }

    final index = selection.start;
    final length = selection.end - selection.start;
    widget.controller.formatText(index, length, attribute);
    widget.controller.updateSelection(
      TextSelection.collapsed(offset: selection.end),
      quill.ChangeSource.local,
    );
  }

  Widget _buildFormatIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
    );
  }

  List<Widget> _buildFormattingButtons(
    BuildContext context, {
    required bool closeContextMenuOnAction,
  }) {
    final l10n = AppLocalizations.of(context);

    void applyAttribute(quill.Attribute<dynamic> attribute) {
      _applySelectionAttribute(attribute);
      if (closeContextMenuOnAction) {
        ContextMenuController.removeAny();
      }
    }

    return [
      _buildFormatIconButton(
        icon: Icons.format_bold,
        tooltip: l10n?.commonBold ?? 'Bold',
        onPressed: () => applyAttribute(quill.Attribute.bold),
      ),
      _buildFormatIconButton(
        icon: Icons.format_italic,
        tooltip: l10n?.commonItalic ?? 'Italic',
        onPressed: () => applyAttribute(quill.Attribute.italic),
      ),
      _buildFormatIconButton(
        icon: Icons.format_underlined,
        tooltip: l10n?.commonUnderline ?? 'Underline',
        onPressed: () => applyAttribute(quill.Attribute.underline),
      ),
      _buildFormatIconButton(
        icon: Icons.strikethrough_s,
        tooltip: l10n?.commonStrike ?? 'Strike',
        onPressed: () => applyAttribute(quill.Attribute.strikeThrough),
      ),
      _buildFormatIconButton(
        icon: Icons.looks_two,
        tooltip: l10n?.commonHeading2 ?? 'H2',
        onPressed: () => applyAttribute(quill.Attribute.h2),
      ),
      _buildFormatIconButton(
        icon: Icons.looks_5,
        tooltip: l10n?.commonHeading5 ?? 'H5',
        onPressed: () => applyAttribute(quill.Attribute.h5),
      ),
      _buildFormatIconButton(
        icon: Icons.link,
        tooltip: l10n?.commonInsertLink ?? 'Link',
        onPressed: () {
          _promptForLink();
          if (closeContextMenuOnAction) {
            ContextMenuController.removeAny();
          }
        },
      ),
      _buildFormatIconButton(
        icon: Icons.format_quote,
        tooltip: l10n?.commonQuote ?? 'Quote',
        onPressed: () => applyAttribute(quill.Attribute.blockQuote),
      ),
    ];
  }

  Widget _buildInlineSelectionToolbar(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final hasSelection = !widget.controller.selection.isCollapsed;
        if (!hasSelection || widget.config.readOnly) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _buildFormattingButtons(
                context,
                closeContextMenuOnAction: false,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditorContextMenu(
    BuildContext context,
    quill.QuillRawEditorState editorState,
  ) {
    // Get button items with error handling for layout issues
    List<ContextMenuButtonItem> buttonItems;
    try {
      buttonItems = editorState.contextMenuButtonItems;
    } catch (e) {
      return const SizedBox.shrink();
    }

    // Keep default platform actions (copy/paste/etc.)
    final defaultButtons = AdaptiveTextSelectionToolbar.getAdaptiveButtons(
      context,
      buttonItems,
    ).toList();
    final formattingWidgets = _buildFormattingButtons(
      context,
      closeContextMenuOnAction: true,
    );

    return AdaptiveTextSelectionToolbar(
      anchors: editorState.contextMenuAnchors,
      children: [...formattingWidgets, ...defaultButtons],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInlineSelectionToolbar(context),
                Shortcuts(
                  shortcuts: {
                    LogicalKeySet(
                      LogicalKeyboardKey.control,
                      LogicalKeyboardKey.keyB,
                    ): const _FormatIntent(
                      _FormatType.bold,
                    ),
                    LogicalKeySet(
                      LogicalKeyboardKey.control,
                      LogicalKeyboardKey.keyI,
                    ): const _FormatIntent(
                      _FormatType.italic,
                    ),
                    LogicalKeySet(
                      LogicalKeyboardKey.control,
                      LogicalKeyboardKey.keyU,
                    ): const _FormatIntent(
                      _FormatType.underline,
                    ),
                    LogicalKeySet(
                      LogicalKeyboardKey.control,
                      LogicalKeyboardKey.keyK,
                    ): const _FormatIntent(
                      _FormatType.link,
                    ),
                    if (_sendOnEnterEnabled)
                      LogicalKeySet(LogicalKeyboardKey.enter):
                          const _SendIntent(),
                    LogicalKeySet(
                      LogicalKeyboardKey.shift,
                      LogicalKeyboardKey.enter,
                    ): const _NewlineIntent(),
                  },
                  child: Actions(
                    actions: {
                      _FormatIntent: CallbackAction<_FormatIntent>(
                        onInvoke: (intent) {
                          switch (intent.type) {
                            case _FormatType.bold:
                              widget.controller.formatSelection(
                                quill.Attribute.bold,
                              );
                              break;
                            case _FormatType.italic:
                              widget.controller.formatSelection(
                                quill.Attribute.italic,
                              );
                              break;
                            case _FormatType.underline:
                              widget.controller.formatSelection(
                                quill.Attribute.underline,
                              );
                              break;
                            case _FormatType.link:
                              _promptForLink();
                              break;
                          }
                          return null;
                        },
                      ),
                      _SendIntent: CallbackAction<_SendIntent>(
                        onInvoke: (intent) {
                          widget.onSendPressed?.call();
                          return null;
                        },
                      ),
                      _NewlineIntent: CallbackAction<_NewlineIntent>(
                        onInvoke: (intent) {
                          _insertNewline();
                          return null;
                        },
                      ),
                    },
                    child: Focus(
                      focusNode: _focusNode,
                      onKeyEvent: (node, event) {
                        if (event is KeyDownEvent) {
                          final isShiftPressed =
                              event.logicalKey ==
                                  LogicalKeyboardKey.shiftLeft ||
                              event.logicalKey ==
                                  LogicalKeyboardKey.shiftRight ||
                              HardwareKeyboard.instance.isShiftPressed;
                          if (event.logicalKey == LogicalKeyboardKey.enter &&
                              isShiftPressed) {
                            _insertNewline();
                            return KeyEventResult.handled;
                          }
                          if (event.logicalKey == LogicalKeyboardKey.enter &&
                              !isShiftPressed &&
                              _sendOnEnterEnabled) {
                            widget.onSendPressed?.call();
                            return KeyEventResult.handled;
                          }
                        }
                        return KeyEventResult.ignored;
                      },
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: widget.config.minHeight,
                          maxHeight: widget.config.maxHeight,
                        ),
                        child: quill.QuillEditor.basic(
                          controller: widget.controller,
                          config: quill.QuillEditorConfig(
                            contextMenuBuilder: _buildEditorContextMenu,
                            padding: EdgeInsets.zero,
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
                ),
              ],
            ),
          ),
          if (widget.config.showAttachButton) ...[
            const SizedBox(width: 1),
            IconButton(
              tooltip:
                  AppLocalizations.of(context)?.commonAttachFile ??
                  'Attach file',
              icon: Icon(
                _isUploadingAttachment
                    ? Icons.hourglass_top
                    : Icons.attach_file,
              ),
              onPressed: _isUploadingAttachment ? null : _onAttachmentSelected,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
          // if (widget.config.showVoiceButton) ...[
          //   const SizedBox(width: 1),
          //   IconButton(
          //     tooltip: _voiceRecorder.isRecording
          //         ? (AppLocalizations.of(context)?.voiceStopRecording ??
          //             'Stop recording')
          //         : (AppLocalizations.of(context)?.voiceRecord ?? 'Record voice'),
          //     icon: Icon(
          //       _voiceRecorder.isRecording ? Icons.stop_circle : Icons.mic,
          //       color: _voiceRecorder.isRecording ? Colors.red : null,
          //     ),
          //     onPressed: _onVoiceRecorded,
          //     visualDensity: VisualDensity.compact,
          //     padding: EdgeInsets.zero,
          //     constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          //   ),
          // ],
          if (widget.config.showSendButton) ...[
            const SizedBox(width: 1),
            IconButton(
              tooltip:
                  widget.config.sendButtonTooltip ??
                  (AppLocalizations.of(context)?.commonSend ?? 'Send'),
              icon: const Icon(Icons.send),
              onPressed: widget.onSendPressed,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ],
      ),
    );
  }
}

enum _FormatType { bold, italic, underline, link }

class _FormatIntent extends Intent {
  const _FormatIntent(this.type);
  final _FormatType type;
}

class _SendIntent extends Intent {
  const _SendIntent();
}

class _NewlineIntent extends Intent {
  const _NewlineIntent();
}
