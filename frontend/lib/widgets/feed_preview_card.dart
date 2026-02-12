import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/feed.dart';
import '../services/feed_service.dart';

class FeedPreviewCard extends StatelessWidget {
  final Feed feed;
  final String title;
  final String ownerLabel;
  final int importantLimit;
  final int recentLimit;
  final VoidCallback onTap;

  const FeedPreviewCard({
    super.key,
    required this.feed,
    required this.title,
    required this.ownerLabel,
    required this.onTap,
    this.importantLimit = 2,
    this.recentLimit = 3,
  });

  Future<_FeedPreviewData> _loadPreview(BuildContext context) async {
    final feedService = context.read<FeedService>();
    final important = await feedService.fetchPosts(
      feed.id,
      importantOnly: true,
      limit: importantLimit,
    );
    final recentAll = await feedService.fetchPosts(
      feed.id,
      limit: recentLimit + importantLimit,
    );
    final recent = recentAll.where((post) => !post.isImportant).take(recentLimit).toList();
    return _FeedPreviewData(important: important, recent: recent);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_FeedPreviewData>(
      future: _loadPreview(context),
      builder: (context, snapshot) {
        final preview = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$title - $ownerLabel',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (isLoading)
                    const LinearProgressIndicator()
                  else if (preview == null || (preview.important.isEmpty && preview.recent.isEmpty))
                    Text(
                      'No posts yet.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else ...[
                    if (preview.important.isNotEmpty) ...[
                      Text(
                        'Important',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      ...preview.important.map((post) => _buildPostLine(context, post)),
                      const SizedBox(height: 8),
                    ],
                    if (preview.recent.isNotEmpty) ...[
                      Text(
                        'Latest',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      ...preview.recent.map((post) => _buildPostLine(context, post)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPostLine(BuildContext context, FeedPost post) {
    final title = (post.title == null || post.title!.isEmpty)
        ? 'Untitled post'
        : post.title!;
    final baseStyle = Theme.of(context).textTheme.bodyMedium;
    final unreadStyle = baseStyle?.copyWith(
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.primary,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: post.isRead ? baseStyle : unreadStyle,
      ),
    );
  }
}

class _FeedPreviewData {
  final List<FeedPost> important;
  final List<FeedPost> recent;

  const _FeedPreviewData({
    required this.important,
    required this.recent,
  });
}
