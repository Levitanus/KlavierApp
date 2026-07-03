part of '../quill_embed_builders.dart';

String normalizeMediaUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  return '${AppConfig.instance.baseUrl}$url';
}

Widget _buildAudioEmbed(
  BuildContext context, {
  required String url,
  required String label,
  required bool showMenu,
}) {
  return GestureDetector(
    onTap: showMenu
        ? () {
            final service = context.read<AudioPlayerService>();
            service.play(url, label);
          }
        : null,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.audiotrack, color: Colors.blue[700], size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.blue[900],
                  ),
                ),
                if (showMenu)
                  Text(
                    AppLocalizations.of(context)?.commonTapToPlay ??
                        'Tap to play',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (showMenu)
            IconButton(
              tooltip: AppLocalizations.of(context)?.commonDownloadSourceFile ??
                  'Download source file',
              icon: const Icon(Icons.download),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
              onPressed: () => _downloadAttachment(context, url),
            ),
        ],
      ),
    ),
  );
}

Widget _buildVideoPreviewEmbed(
  BuildContext context, {
  required String url,
  required bool showMenu,
}) {
  const isWeb = kIsWeb;

  return GestureDetector(
    onTap: () {
      if (isWeb) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
            contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            title: Text(AppLocalizations.of(context)?.commonVideo ?? 'Video'),
            content: Text(
              AppLocalizations.of(context)?.videoWebLimited ??
                  'Web video player is limited. You can download the file or open it separately.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)?.commonClose ?? 'Close'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _downloadAttachment(context, url);
                },
                child: Text(
                  AppLocalizations.of(context)?.commonDownload ?? 'Download',
                ),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (_) => _VideoPlayerDialog(url: url),
          barrierDismissible: true,
        );
      }
    },
    child: Container(
      constraints: const BoxConstraints(
        maxHeight: 300,
        maxWidth: 400,
      ),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            color: Colors.grey[800],
            child: const Center(
              child: Icon(
                Icons.videocam,
                size: 48,
                color: Colors.white,
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black54,
            ),
            padding: const EdgeInsets.all(16),
            child: const Icon(
              Icons.play_arrow,
              size: 48,
              color: Colors.white,
            ),
          ),
          if (showMenu)
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip:
                    AppLocalizations.of(context)?.commonDownloadSourceFile ??
                        'Download source file',
                icon: const Icon(Icons.download, color: Colors.white),
                iconSize: 20,
                visualDensity: VisualDensity.compact,
                onPressed: () => _downloadAttachment(context, url),
              ),
            ),
        ],
      ),
    ),
  );
}

Widget _buildAttachmentWithMenu(
  BuildContext context, {
  required Widget content,
  required String url,
  required bool showMenu,
}) {
  if (!showMenu) {
    return content;
  }

  return Stack(
    alignment: Alignment.topRight,
    children: [
      Padding(
        padding: const EdgeInsets.only(right: 32),
        child: content,
      ),
      PopupMenuButton<String>(
        tooltip: AppLocalizations.of(context)?.feedsAttachmentActions ??
            'Attachment actions',
        onSelected: (value) {
          if (value == 'download') {
            _downloadAttachment(context, url);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'download',
            child: Text(
              AppLocalizations.of(context)?.commonDownloadSourceFile ??
                  'Download source file',
            ),
          ),
        ],
        icon: const Icon(Icons.more_horiz, size: 20),
      ),
    ],
  );
}

Future<void> _downloadAttachment(BuildContext context, String url) async {
  final filename = _fileNameFromUrl(url);
  final result = await downloadMedia(
    url: url,
    filename: filename,
    appFolderName: 'music_school_app',
  );

  if (!context.mounted) {
    return;
  }

  final message = result.success
      ? (result.filePath != null
          ? (AppLocalizations.of(context)?.commonSavedToPath(result.filePath!) ??
              'Saved to ${result.filePath}')
          : (AppLocalizations.of(context)?.commonDownloadStarted ??
              'Download started'))
      : (result.errorMessage ??
          AppLocalizations.of(context)?.commonDownloadFailed ??
          'Download failed');

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

String? _fileNameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.pathSegments.isEmpty) {
    return null;
  }
  final name = uri.pathSegments.last.trim();
  return name.isEmpty ? null : name;
}

String _formatDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = value.inHours;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}
