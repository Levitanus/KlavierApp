import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/audio_player_service.dart';
import '../utils/media_download.dart';

String _formatDuration(Duration value) {
  final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
  final hours = value.inHours;
  if (hours > 0) {
    return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String? _fileNameFromUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.pathSegments.isEmpty) return null;
  final name = uri.pathSegments.last.trim();
  return name.isEmpty ? null : name;
}

class FloatingAudioPlayer extends StatefulWidget {
  const FloatingAudioPlayer({super.key});

  @override
  State<FloatingAudioPlayer> createState() => _FloatingAudioPlayerState();
}

class _FloatingAudioPlayerState extends State<FloatingAudioPlayer> {
  StreamSubscription<Duration?>? _durationSub;
  Duration? _duration;

  @override
  void initState() {
    super.initState();
    final service = context.read<AudioPlayerService>();
    _durationSub = service.player.durationStream.listen((duration) {
      if (!mounted) return;
      setState(() {
        _duration = duration;
      });
    });
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<AudioPlayerService>();
    final currentUrl = service.currentUrl;
    final currentLabel = service.currentLabel;

    if (currentUrl == null) return const SizedBox.shrink();

    return Container(
      color: Colors.grey[850],
      child: StreamBuilder<Duration>(
        stream: service.player.positionStream,
        builder: (context, snapshot) {
          final position = snapshot.data ?? Duration.zero;
          final duration = _duration ?? service.player.duration ?? Duration.zero;
          final maxSeconds = duration.inMilliseconds <= 0
              ? 1.0
              : duration.inMilliseconds.toDouble();
          final valueSeconds = position.inMilliseconds <= 0
              ? 0.0
              : position.inMilliseconds.toDouble().clamp(0.0, maxSeconds);

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 4,
                  child: Slider(
                    value: valueSeconds,
                    min: 0,
                    max: maxSeconds,
                    onChanged: (val) => service.seekTo(
                      Duration(milliseconds: val.round()),
                    ),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back 5s',
                      icon: const Icon(Icons.replay_5, color: Colors.white),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => service.seekBy(const Duration(seconds: -5)),
                    ),
                    IconButton(
                      icon: Icon(
                        service.player.playing ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      iconSize: 24,
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        if (service.player.playing) {
                          await service.pause();
                        } else {
                          await service.player.play();
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Forward 5s',
                      icon: const Icon(Icons.forward_5, color: Colors.white),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => service.seekBy(const Duration(seconds: 5)),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentLabel ?? 'Audio',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${_formatDuration(position)} / ${_formatDuration(duration)}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Download source file',
                      icon: const Icon(Icons.download, color: Colors.white),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _downloadAttachment(context, currentUrl),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, color: Colors.white),
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
                      onPressed: () async {
                        await service.stop();
                      },
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
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
}
