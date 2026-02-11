import 'package:flutter/material.dart';
import '../models/hometask.dart';

class HometaskWidget extends StatelessWidget {
  final Hometask hometask;
  final VoidCallback? onMarkCompleted;
  final void Function(int index, bool isDone)? onToggleItem;
  final void Function(int index, int progress)? onChangeProgress;
  final VoidCallback? onMarkAccomplished;
  final VoidCallback? onMarkReopened;

  const HometaskWidget({
    super.key,
    required this.hometask,
    this.onMarkCompleted,
    this.onToggleItem,
    this.onChangeProgress,
    this.onMarkAccomplished,
    this.onMarkReopened,
  });

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
              children: [
                Expanded(
                  child: Text(
                    hometask.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                _buildStatusChip(context),
              ],
            ),
            if (hometask.description != null && hometask.description!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  hometask.description!,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            if (hometask.dueDate != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Due: ${_formatDate(hometask.dueDate!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (hometask.checklistItems.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: hometask.checklistItems
                      .asMap()
                      .entries
                      .map(
                        (entry) {
                          final item = entry.value;
                          final isProgress = hometask.hometaskType == HometaskType.progress;
                          final isChecklist = hometask.hometaskType == HometaskType.checklist;

                          // For progress hometasks, show progress items
                          if (isProgress) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(item.text),
                                  ),
                                  if (onChangeProgress != null)
                                    DropdownButton<int>(
                                      value: item.progress ?? 0,
                                      items: [
                                        DropdownMenuItem(
                                          value: 0,
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
                                              const Text('Not started'),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 1,
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
                                              const Text('In progress'),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 2,
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
                                              const Text('Nearly done'),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 3,
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
                                              const Text('Almost complete'),
                                            ],
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 4,
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
                                              const Text('Complete'),
                                            ],
                                          ),
                                        ),
                                      ],
                                      onChanged: (value) {
                                        if (value != null) {
                                          onChangeProgress!(entry.key, value);
                                        }
                                      },
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
                                  if (onToggleItem != null)
                                    Checkbox(
                                      value: item.isDone,
                                      onChanged: (value) {
                                        if (value != null) {
                                          onToggleItem!(entry.key, value);
                                        }
                                      },
                                    )
                                  else
                                    Icon(
                                      item.isDone
                                          ? Icons.check_circle
                                          : Icons.radio_button_unchecked,
                                      size: 16,
                                      color: item.isDone
                                          ? Colors.green
                                          : Colors.grey.shade500,
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(item.text)),
                                ],
                              ),
                            );
                          }

                          // Default: show nothing if type is not checklist or progress
                          return const SizedBox.shrink();
                        },
                      )
                      .toList(),
                ),
              ),
            if (hometask.status == HometaskStatus.assigned && onMarkCompleted != null)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: ElevatedButton.icon(
                    onPressed: onMarkCompleted,
                    icon: const Icon(Icons.check),
                    label: const Text('Mark completed'),
                  ),
                ),
              ),
            if (onMarkAccomplished != null &&
                hometask.status != HometaskStatus.accomplishedByTeacher)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: OutlinedButton.icon(
                    onPressed: onMarkAccomplished,
                    icon: const Icon(Icons.verified),
                    label: const Text('Mark accomplished'),
                  ),
                ),
              ),
            if (onMarkReopened != null &&
                hometask.status != HometaskStatus.assigned)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: TextButton.icon(
                    onPressed: onMarkReopened,
                    icon: const Icon(Icons.restore),
                    label: Text(
                      hometask.status == HometaskStatus.accomplishedByTeacher
                          ? 'Return to active'
                          : 'Mark uncompleted',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    String label;
    Color color;

    switch (hometask.status) {
      case HometaskStatus.completedByStudent:
        label = 'Completed';
        color = Colors.orange;
        break;
      case HometaskStatus.accomplishedByTeacher:
        label = 'Accomplished';
        color = Colors.green;
        break;
      case HometaskStatus.assigned:
      default:
        label = 'Assigned';
        color = Colors.blue;
        break;
    }

    return Chip(
      label: Text(label),
      backgroundColor: color.withValues(alpha: 26),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color.withValues(alpha: 102)),
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
}
