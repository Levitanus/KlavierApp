import 'package:flutter/material.dart';
import '../models/hometask.dart';

class HometaskWidget extends StatelessWidget {
  final Hometask hometask;
  final VoidCallback? onMarkCompleted;
  final void Function(int index, bool isDone)? onToggleItem;
  final VoidCallback? onMarkAccomplished;

  const HometaskWidget({
    super.key,
    required this.hometask,
    this.onMarkCompleted,
    this.onToggleItem,
    this.onMarkAccomplished,
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
                        (entry) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              if (onToggleItem != null)
                                Checkbox(
                                  value: entry.value.isDone,
                                  onChanged: (value) {
                                    if (value != null) {
                                      onToggleItem!(entry.key, value);
                                    }
                                  },
                                )
                              else
                                Icon(
                                  entry.value.isDone
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 16,
                                  color: entry.value.isDone
                                      ? Colors.green
                                      : Colors.grey.shade500,
                                ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(entry.value.text)),
                            ],
                          ),
                        ),
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
}
