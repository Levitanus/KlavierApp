part of '../feeds_screen.dart';

class FeedsScreen extends StatefulWidget {
  final int? initialFeedId;
  final int? initialPostId;

  const FeedsScreen({super.key, this.initialFeedId, this.initialPostId});

  @override
  State<FeedsScreen> createState() => _FeedsScreenState();
}

class _FeedsScreenState extends State<FeedsScreen> {
  bool _openedInitialFeed = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedService>().fetchFeeds();
    });
  }

  String _formatFeedTitle(Feed feed) {
    return feed.title.replaceFirst(RegExp(r'\s*Feed$'), '').trim();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FeedService>(
      builder: (context, feedService, child) {
        final l10n = AppLocalizations.of(context);
        final feeds = feedService.feeds;
        final isLoading = feedService.isLoadingFeeds;
        final schoolFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'school')
            .toList();
        final teacherFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'teacher')
            .toList();
        final groupFeeds = feeds
            .where((feed) => feed.ownerType.toLowerCase() == 'group')
            .toList();

        if (!_openedInitialFeed &&
            widget.initialFeedId != null &&
            feeds.isNotEmpty) {
          final target = feeds.firstWhere(
            (feed) => feed.id == widget.initialFeedId,
            orElse: () => feeds.first,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _openedInitialFeed) return;
            setState(() {
              _openedInitialFeed = true;
            });
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FeedDetailScreen(
                  feed: target,
                  initialPostId: widget.initialPostId,
                ),
              ),
            );
          });
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Text(
                  l10n?.feedsTitle ?? 'Feeds',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => feedService.fetchFeeds(),
                ),
              ],
            ),
            if (isLoading) const LinearProgressIndicator(),
            if (!isLoading && feeds.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(l10n?.feedsNone ?? 'No feeds available'),
              ),
            if (schoolFeeds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n?.feedsSchool ?? 'School',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...schoolFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedDetailScreen(feed: feed),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (teacherFeeds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n?.feedsTeacherFeeds ?? 'Teacher feeds',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...teacherFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedDetailScreen(feed: feed),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (groupFeeds.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                l10n?.feedsGroupFeeds ?? 'Group feeds',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ...groupFeeds.map(
                (feed) => FeedPreviewCard(
                  feed: feed,
                  title: _formatFeedTitle(feed),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => FeedDetailScreen(feed: feed),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

