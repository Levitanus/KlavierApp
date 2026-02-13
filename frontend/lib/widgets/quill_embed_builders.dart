import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:just_audio/just_audio.dart';
import 'package:video_player/video_player.dart';

String normalizeMediaUrl(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }
  return 'http://localhost:8080$url';
}

class ImageEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: GestureDetector(
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ChatVideoPlayer(url: normalizeMediaUrl(url)),
    );
  }
}

class AudioEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'audio';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ChatAudioPlayer(
        url: normalizeMediaUrl(url),
        label: 'Audio',
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ChatAudioPlayer(
        url: normalizeMediaUrl(url),
        label: 'Voice message',
      ),
    );
  }
}

class FileEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'file';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
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
      ),
    );
  }
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
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Row(
        children: [
          const Icon(Icons.audiotrack),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        IconButton(
          icon: Icon((_player?.playing ?? false) ? Icons.pause : Icons.play_arrow),
          onPressed: !_ready
              ? null
              : () async {
                  if (_player?.playing ?? false) {
                    await _player?.pause();
                  } else {
                    await _player?.play();
                  }
                  if (mounted) {
                    setState(() {});
                  }
                },
        ),
        Expanded(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
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

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          VideoPlayer(_controller!),
          IconButton(
            icon: Icon(
              _controller!.value.isPlaying ? Icons.pause_circle : Icons.play_circle,
              size: 48,
              color: Colors.white,
            ),
            onPressed: () {
              setState(() {
                if (_controller!.value.isPlaying) {
                  _controller!.pause();
                } else {
                  _controller!.play();
                }
              });
            },
          ),
        ],
      ),
    );
  }
}
