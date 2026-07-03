part of '../quill_embed_builders.dart';

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
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
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
                              : position.inMilliseconds
                                  .toDouble()
                                  .clamp(0.0, maxSeconds);
                          final isLandscape =
                              MediaQuery.of(context).orientation ==
                                  Orientation.landscape;

                          return Container(
                            color: Colors.grey[900],
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
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
                                        tooltip: AppLocalizations.of(context)
                                                ?.commonBack5s ??
                                            'Back 5s',
                                        icon: const Icon(
                                          Icons.replay_5,
                                          color: Colors.white,
                                        ),
                                        iconSize: 20,
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _seekBy(-_skipOffset, duration),
                                      ),
                                    ],
                                    IconButton(
                                      icon: Icon(
                                        value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
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
                                        tooltip: AppLocalizations.of(context)
                                                ?.commonForward5s ??
                                            'Forward 5s',
                                        icon: const Icon(
                                          Icons.forward_5,
                                          color: Colors.white,
                                        ),
                                        iconSize: 20,
                                        visualDensity: VisualDensity.compact,
                                        onPressed: () =>
                                            _seekBy(_skipOffset, duration),
                                      ),
                                    ],
                                    if (!isLandscape) ...[
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
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
                                          ? (AppLocalizations.of(context)
                                                  ?.commonExitFullscreen ??
                                              'Exit fullscreen')
                                          : (AppLocalizations.of(context)
                                                  ?.commonFullscreen ??
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
