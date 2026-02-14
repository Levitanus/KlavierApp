import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../widgets/quill_embed_builders.dart';
import '../utils/voice_recorder.dart';

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
  final Future<void> Function(List<int> bytes, String filename)? onVoiceRecorded;
  final Key? controlKey;

  const QuillEditorComposer({
    Key? key,
    required this.controller,
    this.config = const QuillEditorComposerConfig(),
    this.onSendPressed,
    this.onAttachmentSelected,
    this.onVoiceRecorded,
    this.controlKey,
  }) : super(key: key);

  @override
  State<QuillEditorComposer> createState() => _QuillEditorComposerState();
}

class _QuillEditorComposerState extends State<QuillEditorComposer> {
  late FocusNode _focusNode;
  bool _isUploadingAttachment = false;
  final VoiceRecorder _voiceRecorder = VoiceRecorder();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _focusNode.dispose();
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

  Future<void> _onVoiceRecorded() async {
    try {
      if (_voiceRecorder.isRecording) {
        // Stop recording and wait a bit for the file to be fully written
        final audio = await _voiceRecorder.stop();
        if (audio == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to record audio')),
            );
          }
          return;
        }

        // Give the system time to finalize the audio file (wait for OggWriter)
        await Future.delayed(const Duration(milliseconds: 300));

        if (mounted && widget.onVoiceRecorded != null) {
          final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.${audio.extension}';
          await widget.onVoiceRecorded!(audio.bytes, filename);
          // Update UI to show recording stopped
          setState(() {});
        }
      } else {
        // Check if voice recording is available
        final available = await _voiceRecorder.isAvailable();
        if (!available) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Voice recording not available')),
            );
          }
          return;
        }
        // Start recording
        await _voiceRecorder.start();
        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Voice error: ${e.toString()}')),
        );
      }
    }
  }

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
        title: const Text('Insert link'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'URL',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Apply'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    final url = controller.text.trim();
    if (url.isEmpty) return;

    widget.controller.formatSelection(
      quill.LinkAttribute(url),
    );
  }

  Widget _buildEditorContextMenu(
    BuildContext context,
    quill.QuillRawEditorState editorState,
  ) {
    final controller = editorState.controller;
    final selection = controller.selection;

    // Get button items with error handling for layout issues
    List<ContextMenuButtonItem> buttonItems;
    try {
      buttonItems = editorState.contextMenuButtonItems;
    } catch (e) {
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
        },
        label: 'Bold',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.italic);
        },
        label: 'Italic',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.underline);
        },
        label: 'Underline',
      ),
      ContextMenuButtonItem(
        onPressed: () {
          final index = selection.start;
          final length = selection.end - selection.start;
          controller.formatText(index, length, quill.Attribute.strikeThrough);
        },
        label: 'Strike',
      ),
    ];

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editorState.contextMenuAnchors,
      buttonItems: [...formattingButtons, ...buttonItems],
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
            child: Shortcuts(
              shortcuts: {
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyB):
                    const _FormatIntent(_FormatType.bold),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyI):
                    const _FormatIntent(_FormatType.italic),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyU):
                    const _FormatIntent(_FormatType.underline),
                LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyK):
                    const _FormatIntent(_FormatType.link),
                LogicalKeySet(LogicalKeyboardKey.enter):
                    const _SendIntent(),
                LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.enter):
                    const _NewlineIntent(),
              },
              child: Actions(
                actions: {
                  _FormatIntent: CallbackAction<_FormatIntent>(
                    onInvoke: (intent) {
                      switch (intent.type) {
                        case _FormatType.bold:
                          widget.controller.formatSelection(quill.Attribute.bold);
                          break;
                        case _FormatType.italic:
                          widget.controller.formatSelection(quill.Attribute.italic);
                          break;
                        case _FormatType.underline:
                          widget.controller.formatSelection(quill.Attribute.underline);
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
                      final isShiftPressed = event.logicalKey == LogicalKeyboardKey.shiftLeft ||
                          event.logicalKey == LogicalKeyboardKey.shiftRight ||
                          HardwareKeyboard.instance.isShiftPressed;
                      if (event.logicalKey == LogicalKeyboardKey.enter &&
                          isShiftPressed) {
                        _insertNewline();
                        return KeyEventResult.handled;
                      }
                      if (event.logicalKey == LogicalKeyboardKey.enter &&
                          !isShiftPressed) {
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
          ),
          if (widget.config.showAttachButton) ...[
            const SizedBox(width: 1),
            IconButton(
              tooltip: 'Attach file',
              icon: Icon(
                _isUploadingAttachment ? Icons.hourglass_top : Icons.attach_file,
              ),
              onPressed: _isUploadingAttachment ? null : _onAttachmentSelected,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
          if (widget.config.showVoiceButton) ...[
            const SizedBox(width: 1),
            IconButton(
              tooltip: _voiceRecorder.isRecording ? 'Stop recording' : 'Record voice',
              icon: Icon(
                _voiceRecorder.isRecording ? Icons.stop_circle : Icons.mic,
                color: _voiceRecorder.isRecording ? Colors.red : null,
              ),
              onPressed: _onVoiceRecorded,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
          if (widget.config.showSendButton) ...[
            const SizedBox(width: 1),
            IconButton(
              tooltip: widget.config.sendButtonTooltip ?? 'Send',
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
