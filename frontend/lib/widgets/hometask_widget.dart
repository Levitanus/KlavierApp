import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../models/hometask.dart';
import '../l10n/app_localizations.dart';
import 'quill_embed_builders.dart';

class HometaskWidget extends StatefulWidget {
  final Hometask hometask;
  final VoidCallback? onMarkCompleted;
  final void Function(int index, bool isDone)? onToggleItem;
  final void Function(int index, int progress)? onChangeProgress;
  final void Function(List<ChecklistItem>)? onSaveItems;
  final VoidCallback? onMarkAccomplished;
  final VoidCallback? onMarkReopened;
  final VoidCallback? onEditHometask;
  final bool showDragHandle;
  final int? dragHandleIndex;
  final bool canEditItems;

  const HometaskWidget({
    super.key,
    required this.hometask,
    this.onMarkCompleted,
    this.onToggleItem,
    this.onChangeProgress,
    this.onSaveItems,
    this.onMarkAccomplished,
    this.onMarkReopened,
    this.onEditHometask,
    this.showDragHandle = false,
    this.dragHandleIndex,
    this.canEditItems = false,
  });

  @override
  State<HometaskWidget> createState() => _HometaskWidgetState();
}

class _HometaskWidgetState extends State<HometaskWidget> {
  late bool _isEditMode;
  late List<ChecklistItem> _editingItems;
  late List<TextEditingController> _itemControllers;

  @override
  void initState() {
    super.initState();
    _isEditMode = false;
    _editingItems = List<ChecklistItem>.from(widget.hometask.checklistItems);
    _initializeControllers();
  }

  void _initializeControllers() {
    _itemControllers = _editingItems
        .map((item) => TextEditingController(text: item.text))
        .toList();
  }

  @override
  void dispose() {
    for (final controller in _itemControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _enterEditMode() {
    setState(() {
      _isEditMode = true;
      _editingItems = List<ChecklistItem>.from(widget.hometask.checklistItems);
      _initializeControllers();
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
    });
  }

  void _saveEdit() {
    // Validate that all items have non-empty text
    final hasEmptyItems = _editingItems.any((item) => item.text.trim().isEmpty);
    if (hasEmptyItems) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.hometasksItemNameRequired ??
                'All items must have a name.',
          ),
        ),
      );
      return;
    }

    final isProgress = widget.hometask.hometaskType == HometaskType.progress;
    final normalizedItems = _editingItems.map((item) {
      final text = item.text.trim();
      if (isProgress) {
        return ChecklistItem(
          text: text,
          isDone: false,
          progress: item.progress ?? 0,
        );
      }
      return ChecklistItem(text: text, isDone: item.isDone);
    }).toList();

    widget.onSaveItems?.call(normalizedItems);
    setState(() {
      _editingItems = normalizedItems;
      _isEditMode = false;
    });
  }

  void _updateItemText(int index, String newText) {
    if (index < 0 || index >= _editingItems.length) return;
    final item = _editingItems[index];
    _editingItems[index] = ChecklistItem(
      text: newText,
      isDone: item.isDone,
      progress: item.progress,
    );
  }

  void _addItem() {
    final isProgress = widget.hometask.hometaskType == HometaskType.progress;
    setState(() {
      _editingItems.add(
        ChecklistItem(text: '', isDone: false, progress: isProgress ? 0 : null),
      );
      _itemControllers.add(TextEditingController(text: ''));
    });
  }

  void _removeItem(int index) {
    if (index < 0 || index >= _itemControllers.length) return;
    setState(() {
      _editingItems.removeAt(index);
      _itemControllers[index].dispose();
      _itemControllers.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showDragHandle)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 2),
                    child: widget.dragHandleIndex == null
                        ? Icon(
                            Icons.drag_handle,
                            size: 20,
                            color: Colors.grey.shade400,
                          )
                        : ReorderableDragStartListener(
                            index: widget.dragHandleIndex!,
                            child: Icon(
                              Icons.drag_handle,
                              size: 20,
                              color: Colors.grey.shade400,
                            ),
                          ),
                  ),
                Expanded(
                  child: Text(
                    widget.hometask.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (widget.hometask.description != null &&
                widget.hometask.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildRichTextContent(widget.hometask.description!),
              ),
            if (widget.hometask.hometaskType == HometaskType.freeAnswer &&
                widget.hometask.checklistItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildRichTextContent(
                  widget.hometask.checklistItems.first.text,
                ),
              ),
            if (widget.hometask.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  AppLocalizations.of(context)?.hometasksDueLabel(
                        _formatDate(widget.hometask.dueDate!),
                      ) ??
                      'Due: ${_formatDate(widget.hometask.dueDate!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_isEditMode &&
                widget.hometask.checklistItems.isNotEmpty &&
                (widget.hometask.hometaskType == HometaskType.checklist ||
                    widget.hometask.hometaskType == HometaskType.progress))
              _buildEditMode()
            else if (widget.hometask.checklistItems.isNotEmpty &&
                (widget.hometask.hometaskType == HometaskType.checklist ||
                    widget.hometask.hometaskType == HometaskType.progress))
              _buildViewMode(),
            if (widget.canEditItems &&
                !_isEditMode &&
                widget.hometask.checklistItems.isNotEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _enterEditMode,
                  icon: const Icon(Icons.edit),
                  label: Text(
                    AppLocalizations.of(context)?.hometasksEditItems ??
                        'Edit items',
                  ),
                ),
              ),
            if (widget.onEditHometask != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: widget.onEditHometask,
                  icon: const Icon(Icons.edit),
                  label: Text(
                    AppLocalizations.of(context)?.commonEdit ?? 'Edit',
                  ),
                ),
              ),
            if (widget.hometask.status == HometaskStatus.assigned &&
                widget.onMarkCompleted != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: ElevatedButton.icon(
                    onPressed: widget.onMarkCompleted,
                    icon: const Icon(Icons.check),
                    label: Text(
                      AppLocalizations.of(context)?.hometasksMarkCompleted ??
                          'Mark completed',
                    ),
                  ),
                ),
              ),
            if (widget.onMarkAccomplished != null &&
                widget.hometask.status != HometaskStatus.accomplishedByTeacher)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: OutlinedButton.icon(
                    onPressed: widget.onMarkAccomplished,
                    icon: const Icon(Icons.verified),
                    label: Text(
                      AppLocalizations.of(context)?.hometasksMarkAccomplished ??
                          'Mark accomplished',
                    ),
                  ),
                ),
              ),
            if (widget.onMarkReopened != null &&
                widget.hometask.status != HometaskStatus.assigned)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: TextButton.icon(
                    onPressed: widget.onMarkReopened,
                    icon: const Icon(Icons.restore),
                    label: Text(
                      widget.hometask.status ==
                              HometaskStatus.accomplishedByTeacher
                          ? (AppLocalizations.of(
                                  context,
                                )?.hometasksReturnActive ??
                                'Return to active')
                          : (AppLocalizations.of(
                                  context,
                                )?.hometasksMarkUncompleted ??
                                'Mark uncompleted'),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewMode() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.hometask.checklistItems.asMap().entries.map((entry) {
          final item = entry.value;
          final isProgress =
              widget.hometask.hometaskType == HometaskType.progress;
          final isChecklist =
              widget.hometask.hometaskType == HometaskType.checklist;

          // For progress hometasks, show progress items
          if (isProgress) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  if (widget.onChangeProgress != null)
                    SizedBox(
                      width: 160,
                      height: 24,
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: item.progress ?? 0,
                          isExpanded: true,
                          icon: const SizedBox.shrink(),
                          iconSize: 0,
                          selectedItemBuilder: (context) {
                            return [0, 1, 2, 3, 4]
                                .map(
                                  (value) => Align(
                                    alignment: Alignment.centerLeft,
                                    child: SizedBox(
                                      width: 100,
                                      height: double.infinity,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          color: _getProgressColor(value),
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList();
                          },
                          items: [
                            DropdownMenuItem(
                              value: 0,
                              child: SizedBox(
                                width: 160,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.hometasksProgressNotStarted ??
                                          'Not started',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 1,
                              child: SizedBox(
                                width: 160,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.hometasksProgressInProgress ??
                                          'In progress',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 2,
                              child: SizedBox(
                                width: 160,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.yellow,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.hometasksProgressNearlyDone ??
                                          'Nearly done',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 3,
                              child: SizedBox(
                                width: 160,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.lime,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.hometasksProgressAlmostComplete ??
                                          'Almost complete',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            DropdownMenuItem(
                              value: 4,
                              child: SizedBox(
                                width: 160,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppLocalizations.of(
                                            context,
                                          )?.hometasksProgressComplete ??
                                          'Complete',
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          onChanged: (value) {
                            if (value != null) {
                              widget.onChangeProgress!(entry.key, value);
                            }
                          },
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getProgressColor(item.progress ?? 0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.text)),
                ],
              ),
            );
          }

          // For checklist hometasks, show checklist items
          if (isChecklist) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  if (widget.onToggleItem != null)
                    Checkbox(
                      value: item.isDone,
                      onChanged: (value) {
                        if (value != null) {
                          widget.onToggleItem!(entry.key, value);
                        }
                      },
                    )
                  else
                    Icon(
                      item.isDone
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 16,
                      color: item.isDone ? Colors.green : Colors.grey.shade500,
                    ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item.text)),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        }).toList(),
      ),
    );
  }

  Widget _buildEditMode() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ..._editingItems.asMap().entries.map((entry) {
            final index = entry.key;
            // Bounds check to prevent errors
            if (index >= _itemControllers.length) {
              return const SizedBox.shrink();
            }
            final controller = _itemControllers[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText:
                            AppLocalizations.of(
                              context,
                            )?.hometasksItemHint(index + 1) ??
                            'Item ${index + 1}',
                        border: OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                      onChanged: (value) => _updateItemText(index, value),
                    ),
                  ),
                  if (_editingItems.length > 1)
                    IconButton(
                      onPressed: () => _removeItem(index),
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.red,
                    ),
                ],
              ),
            );
          }).toList(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: Text(
                AppLocalizations.of(context)?.hometasksAddItem ?? 'Add item',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _cancelEdit,
                  child: Text(
                    AppLocalizations.of(context)?.commonCancel ?? 'Cancel',
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveEdit,
                  child: Text(
                    AppLocalizations.of(context)?.commonSave ?? 'Save',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${_twoDigits(date.month)}-${_twoDigits(date.day)}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }

  Color _getProgressColor(int progress) {
    switch (progress) {
      case 0:
        return Colors.red;
      case 1:
        return Colors.orange;
      case 2:
        return Colors.yellow;
      case 3:
        return Colors.lime;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRichTextContent(String raw) {
    final parsed = _parseQuillRaw(raw);
    if (parsed == null) {
      return Text(raw, style: Theme.of(context).textTheme.bodyMedium);
    }

    return _ReadOnlyQuillContent(document: parsed);
  }

  quill.Document? _parseQuillRaw(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return quill.Document.fromJson(decoded.cast<Map<String, dynamic>>());
      }
      if (decoded is Map<String, dynamic> && decoded['ops'] is List) {
        final ops = (decoded['ops'] as List)
            .whereType<Map<String, dynamic>>()
            .toList();
        return quill.Document.fromJson(ops);
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class _ReadOnlyQuillContent extends StatefulWidget {
  final quill.Document document;

  const _ReadOnlyQuillContent({required this.document});

  @override
  State<_ReadOnlyQuillContent> createState() => _ReadOnlyQuillContentState();
}

class _ReadOnlyQuillContentState extends State<_ReadOnlyQuillContent> {
  late quill.QuillController _controller;

  @override
  void initState() {
    super.initState();
    _controller = quill.QuillController(
      document: widget.document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true,
    );
  }

  @override
  void didUpdateWidget(covariant _ReadOnlyQuillContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.document != widget.document) {
      _controller.dispose();
      _controller = quill.QuillController(
        document: widget.document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return quill.QuillEditor.basic(
      controller: _controller,
      config: quill.QuillEditorConfig(
        scrollable: false,
        autoFocus: false,
        showCursor: false,
        expands: false,
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
    );
  }
}
