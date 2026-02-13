import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlayerService extends ChangeNotifier {
  static final AudioPlayerService _instance = AudioPlayerService._internal();

  factory AudioPlayerService() {
    return _instance;
  }

  AudioPlayerService._internal();

  final AudioPlayer _player = AudioPlayer();
  String? _currentUrl;
  String? _currentLabel;

  String? get currentUrl => _currentUrl;
  String? get currentLabel => _currentLabel;
  AudioPlayer get player => _player;

  Future<void> play(String url, String label) async {
    try {
      // If switching to a different URL, stop and reset first
      if (_currentUrl != url) {
        await _player.stop();
        await _player.setUrl(url);
        _currentUrl = url;
        _currentLabel = label;
        notifyListeners();
      }
      await _player.play();
      notifyListeners();
    } catch (e) {
      print('Error playing audio: $e');
      rethrow;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    notifyListeners();
  }

  Future<void> stop() async {
    await _player.stop();
    _currentUrl = null;
    _currentLabel = null;
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> seekBy(Duration delta) async {
    final current = _player.position;
    final target = current + delta;
    final duration = _player.duration ?? Duration.zero;
    final clamped = target.inMilliseconds.clamp(0, duration.inMilliseconds);
    await _player.seek(Duration(milliseconds: clamped));
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
