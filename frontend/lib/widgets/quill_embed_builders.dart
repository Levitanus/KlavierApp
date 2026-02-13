import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import '../config/app_config.dart';
import '../services/audio_player_service.dart';
import '../utils/media_download.dart';

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
        child: Image.network(
          absoluteUrl,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Center(
                child: Icon(Icons.broken_image),
              ),
            );
          },
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
      child: _buildAttachmentWithMenu(
        context,
        content: ChatVideoPlayer(url: absoluteUrl),
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
        label: 'Audio',
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
        label: 'Voice message',
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
                  const Text(
                    'Tap to play',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (showMenu)
            IconButton(
              tooltip: 'Download source file',
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
        tooltip: 'Attachment actions',
        onSelected: (value) {
          if (value == 'download') {
            _downloadAttachment(context, url);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: 'download',
            child: Text('Download source file'),
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
    appFolderName: 'klavierapp',
  );

  if (!context.mounted) return;

  final message = result.success
      ? (result.filePath != null ? 'Saved to ${result.filePath}' : 'Download started')
      : (result.errorMessage ?? 'Download failed');

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
  AudioPlayer? _player;
  bool _ready = false;
  bool _failed = false;
  StreamSubscription<Duration?>? _durationSub;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      _player = AudioPlayer();
      _init();
    } else {
      _failed = true;
    }
  }

  Future<void> _init() async {
    try {
      await _player?.setUrl(widget.url);
      _durationSub = _player?.durationStream.listen((duration) {
        if (!mounted) return;
        setState(() {
          _duration = duration;
        });
      });
      if (mounted) {
        setState(() {
          _ready = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _ready = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

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
                  tooltip: 'Back 5s',
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
                  tooltip: 'Forward 5s',
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
