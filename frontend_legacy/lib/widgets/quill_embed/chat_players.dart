part of '../quill_embed_builders.dart';

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
    // Unreachable: audio embeds now use simplified inline widget + floating player.
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
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
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
        final maxSeconds =
            duration.inMilliseconds <= 0 ? 1.0 : duration.inMilliseconds.toDouble();
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
                  child: Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  ),
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
