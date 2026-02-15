import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../config/app_config.dart';
import '../services/audio_player_service.dart';
import '../services/media_cache_service.dart';
import '../utils/media_download.dart';
import '../l10n/app_localizations.dart';

String normalizeMediaUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  return '${AppConfig.instance.baseUrl}$url';
}

class ImageEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    final content = GestureDetector(
      onTap: () {},
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: MediaCacheService.instance.cachedImage(
          url: absoluteUrl,
          fit: BoxFit.contain,
          errorWidget: Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _buildAttachmentWithMenu(
        context,
        content: content,
        url: absoluteUrl,
        showMenu: embedContext.readOnly,
      ),
    );
  }
}

class VideoEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'video';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _buildVideoPreviewEmbed(
        context,
        url: absoluteUrl,
        showMenu: embedContext.readOnly,
      ),
    );
  }
}

class AudioEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'audio';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _buildAudioEmbed(
        context,
        url: absoluteUrl,
        label: AppLocalizations.of(context)?.commonAudio ?? 'Audio',
        showMenu: embedContext.readOnly,
      ),
    );
  }
}

class VoiceEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'voice';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _buildAudioEmbed(
        context,
        url: absoluteUrl,
        label: AppLocalizations.of(context)?.commonVoiceMessage ??
            'Voice message',
        showMenu: embedContext.readOnly,
      ),
    );
  }
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
  final isWeb = kIsWeb;
  
  return GestureDetector(
    onTap: () {
      if (isWeb) {
        // On web, show options dialog
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
        // On mobile, show fullscreen video player
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
          // Placeholder/thumbnail
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
          // Play icon overlay
          Container(
            decoration: BoxDecoration(
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
          // Download button
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

class _VideoPlayerDialog extends StatefulWidget {
  final String url;

  const _VideoPlayerDialog({required this.url});

  @override
  State<_VideoPlayerDialog> createState() => __VideoPlayerDialogState();
}

class __VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _isFullscreen = false;
  static const Duration _skipOffset = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _ready = true;
          });
        }
      }).catchError((_) {
        if (mounted) {
          setState(() {
            _failed = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    // Restore portrait orientation when disposing
    if (_isFullscreen) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    super.dispose();
  }

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });

    if (_isFullscreen) {
      // Lock to landscape
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      // Restore portrait
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(
          AppLocalizations.of(context)?.videoErrorTitle ?? 'Video Error',
        ),
        content: Text(
          AppLocalizations.of(context)?.videoLoadFailed ?? 'Failed to load video',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.commonClose ?? 'Close'),
          ),
        ],
      );
    }

    if (!_ready || _controller == null) {
      return AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        titlePadding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        title: Text(AppLocalizations.of(context)?.commonLoading ?? 'Loading'),
        content: const SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)?.commonCancel ?? 'Cancel'),
          ),
        ],
      );
    }

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: constraints.maxHeight,
                  width: constraints.maxWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Center(
                          child: ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: _controller!,
                            builder: (context, value, child) {
                              return AspectRatio(
                                aspectRatio: value.aspectRatio,
                                child: VideoPlayer(_controller!),
                              );
                            },
                          ),
                        ),
                      ),
                      // Controls
                      ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: _controller!,
                        builder: (context, value, child) {
                          final duration = value.duration;
                          final position = value.position;
                          final maxSeconds = duration.inMilliseconds <= 0
                              ? 1.0
                              : duration.inMilliseconds.toDouble();
                          final valueSeconds = position.inMilliseconds <= 0
                              ? 0.0
                              : position.inMilliseconds.toDouble().clamp(0.0, maxSeconds);
                          final isLandscape =
                              MediaQuery.of(context).orientation == Orientation.landscape;

                          return Container(
                            color: Colors.grey[900],
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  height: 4,
                                  child: Slider(
                                    value: valueSeconds,
                                    min: 0,
                                    max: maxSeconds,
                                    onChanged: (val) => _controller!.seekTo(
                                      Duration(milliseconds: val.toInt()),
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (!isLandscape) ...[
                                      IconButton(
                                        tooltip: AppLocalizations.of(context)?.commonBack5s ??
                                            'Back 5s',
                                        icon: const Icon(Icons.replay_5, color: Colors.white),
                                        iconSize: 20,
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _seekBy(-_skipOffset, duration),
                                      ),
                                    ],
                                    IconButton(
                                      icon: Icon(
                                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                                        color: Colors.white,
                                      ),
                                      iconSize: 24,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () {
                                        setState(() {
                                          if (value.isPlaying) {
                                            _controller!.pause();
                                          } else {
                                            _controller!.play();
                                          }
                                        });
                                      },
                                    ),
                                    if (!isLandscape) ...[
                                      IconButton(
                                        tooltip: AppLocalizations.of(context)?.commonForward5s ??
                                            'Forward 5s',
                                        icon: const Icon(Icons.forward_5, color: Colors.white),
                                        iconSize: 20,
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () => _seekBy(_skipOffset, duration),
                                      ),
                                    ],
                                    if (!isLandscape) ...[
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                          child: Text(
                                            '${_formatDuration(position)} / ${_formatDuration(duration)}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    IconButton(
                                      tooltip: _isFullscreen
                                          ? (AppLocalizations.of(context)?.commonExitFullscreen ??
                                              'Exit fullscreen')
                                          : (AppLocalizations.of(context)?.commonFullscreen ??
                                              'Fullscreen'),
                                      icon: Icon(
                                        _isFullscreen
                                            ? Icons.fullscreen_exit
                                            : Icons.fullscreen,
                                        color: Colors.white,
                                      ),
                                      iconSize: 20,
                                      visualDensity: VisualDensity.compact,
                                      onPressed: _toggleFullscreen,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _seekBy(Duration delta, Duration duration) {
    final current = _controller?.value.position ?? Duration.zero;
    final target = current + delta;
    final clamped = target.inMilliseconds.clamp(0, duration.inMilliseconds);
    _controller?.seekTo(Duration(milliseconds: clamped));
  }
}

class FileEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'file';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    final content = Row(
      children: [
        const Icon(Icons.file_present),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            absoluteUrl.split('/').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: _buildAttachmentWithMenu(
        context,
        content: content,
        url: absoluteUrl,
        showMenu: embedContext.readOnly,
      ),
    );
  }
}

Widget _buildAttachmentWithMenu(
  BuildContext context, {
  required Widget content,
  required String url,
  required bool showMenu,
}) {
  if (!showMenu) return content;

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

  if (!context.mounted) return;

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
  if (uri == null || uri.pathSegments.isEmpty) return null;
  final name = uri.pathSegments.last.trim();
  return name.isEmpty ? null : name;
}

class UnknownEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'unknown';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        color: Colors.orange[100],
        padding: const EdgeInsets.all(8),
        child: Text(
          AppLocalizations.of(context)?.feedsUnsupportedEmbed(
                embedContext.node.value.data,
              ) ??
              'Unsupported embed: ${embedContext.node.value.data}',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}

class ChatAudioPlayer extends StatefulWidget {
  final String url;
  final String label;

  const ChatAudioPlayer({
    super.key,
    required this.url,
    required this.label,
  });

  @override
  State<ChatAudioPlayer> createState() => _ChatAudioPlayerState();
}

class _ChatAudioPlayerState extends State<ChatAudioPlayer> {
  @override
  Widget build(BuildContext context) {
    // Unreachable: audio embeds now use simplified inline widget + floating player
    return const SizedBox.shrink();
  }
}

class ChatVideoPlayer extends StatefulWidget {
  final String url;

  const ChatVideoPlayer({
    super.key,
    required this.url,
  });

  @override
  State<ChatVideoPlayer> createState() => _ChatVideoPlayerState();
}

class _ChatVideoPlayerState extends State<ChatVideoPlayer> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  static const Duration _skipOffset = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    if (kIsWeb || defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {
              _ready = true;
            });
          }
        }).catchError((_) {
          if (mounted) {
            setState(() {
              _failed = true;
            });
          }
        });
    } else {
      _failed = true;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: Center(
          child: Text(
            AppLocalizations.of(context)?.commonVideoLabel(
                  widget.url.split('/').last,
                ) ??
                'Video: ${widget.url.split('/').last}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (!_ready || _controller == null) {
      return Container(
        height: 200,
        color: Colors.grey[200],
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller!,
      builder: (context, value, child) {
        final duration = value.duration;
        final position = value.position;
        final maxSeconds = duration.inMilliseconds <= 0
          ? 1.0
          : duration.inMilliseconds.toDouble();
        final valueSeconds = position.inMilliseconds <= 0
          ? 0.0
          : position.inMilliseconds.toDouble().clamp(0.0, maxSeconds);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(
              aspectRatio: value.aspectRatio,
              child: VideoPlayer(_controller!),
            ),
            Row(
              children: [
                IconButton(
                  tooltip: AppLocalizations.of(context)?.commonBack5s ??
                      'Back 5s',
                  icon: const Icon(Icons.replay_5),
                  onPressed: () => _seekBy(-_skipOffset, duration),
                ),
                IconButton(
                  icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    setState(() {
                      if (value.isPlaying) {
                        _controller!.pause();
                      } else {
                        _controller!.play();
                      }
                    });
                  },
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context)?.commonForward5s ??
                      'Forward 5s',
                  icon: const Icon(Icons.forward_5),
                  onPressed: () => _seekBy(_skipOffset, duration),
                ),
                Expanded(
                  child: Slider(
                    value: valueSeconds,
                    min: 0,
                    max: maxSeconds,
                    onChanged: (val) => _controller!.seekTo(
                      Duration(milliseconds: val.round()),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Text('${_formatDuration(position)} / ${_formatDuration(duration)}'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _seekBy(Duration delta, Duration duration) {
    final current = _controller?.value.position ?? Duration.zero;
    final target = current + delta;
    final clamped = target.inMilliseconds.clamp(0, duration.inMilliseconds);
    _controller?.seekTo(Duration(milliseconds: clamped));
  }
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
