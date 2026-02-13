import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class RecordedAudio {
  final List<int> bytes;
  final String extension;

  RecordedAudio({
    required this.bytes,
    required this.extension,
  });
}

class VoiceRecorder {
  final AudioRecorder _record = AudioRecorder();
  bool _recording = false;

  bool get isRecording => _recording;

  Future<bool> isAvailable() async {
    return _record.hasPermission();
  }

  Future<void> start() async {
    if (_recording) return;
    final dir = await getTemporaryDirectory();
    final filename = 'voice_${DateTime.now().millisecondsSinceEpoch}.ogg';
    final path = '${dir.path}/$filename';
    await _record.start(
      const RecordConfig(encoder: AudioEncoder.opus),
      path: path,
    );
    _recording = true;
  }

  Future<RecordedAudio?> stop() async {
    if (!_recording) return null;
    final path = await _record.stop();
    _recording = false;
    if (path == null) return null;

    final bytes = await File(path).readAsBytes();
    return RecordedAudio(bytes: bytes, extension: 'ogg');
  }
}
