part of '../feeds_screen.dart';

class FeedSettingsDialog extends StatefulWidget {
  final Feed feed;
  final FeedSettings? feedSettings;
  final FeedUserSettings? userSettings;

  const FeedSettingsDialog({
    super.key,
    required this.feed,
    required this.feedSettings,
    required this.userSettings,
  });

  @override
  State<FeedSettingsDialog> createState() => _FeedSettingsDialogState();
}

class _FeedSettingsDialogState extends State<FeedSettingsDialog> {
  bool _allowStudentPosts = false;
  bool _autoSubscribe = true;
  bool _notifyNewPosts = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _allowStudentPosts = widget.feedSettings?.allowStudentPosts ?? false;
    _autoSubscribe = widget.userSettings?.autoSubscribeNewPosts ?? true;
    _notifyNewPosts = widget.userSettings?.notifyNewPosts ?? true;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
    });

    final feedService = context.read<FeedService>();
    final authService = context.read<AuthService>();

    if (authService.isAdmin || authService.roles.contains('teacher')) {
      await feedService.updateFeedSettings(widget.feed.id, _allowStudentPosts);
    }

    await feedService.updateFeedUserSettings(
      widget.feed.id,
      _autoSubscribe,
      _notifyNewPosts,
    );

    if (!mounted) return;
    setState(() {
      _saving = false;
    });
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      title: Text(
        AppLocalizations.of(context)?.feedsSettingsTitle ?? 'Feed settings',
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if ((authService.isAdmin || authService.roles.contains('teacher')) &&
              widget.feed.ownerType.toLowerCase() != 'school')
            SwitchListTile(
              value: _allowStudentPosts,
              onChanged: (value) {
                setState(() {
                  _allowStudentPosts = value;
                });
              },
              title: Text(
                AppLocalizations.of(context)?.feedsAllowStudentPosts ??
                    'Allow student posts',
              ),
            ),
          SwitchListTile(
            value: _autoSubscribe,
            onChanged: (value) {
              setState(() {
                _autoSubscribe = value;
              });
            },
            title: Text(
              AppLocalizations.of(context)?.feedsAutoSubscribe ??
                  'Auto-subscribe to new posts',
            ),
          ),
          SwitchListTile(
            value: _notifyNewPosts,
            onChanged: (value) {
              setState(() {
                _notifyNewPosts = value;
              });
            },
            title: Text(
              AppLocalizations.of(context)?.feedsNotifyNewPosts ??
                  'Notify on new posts',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
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
