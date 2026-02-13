import 'dart:async';
import 'dart:typed_data';

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
  StreamSubscription<Uint8List>? _subscription;
  final List<int> _buffer = [];

  bool get isRecording => _recording;

  Future<bool> isAvailable() async {
    return _record.hasPermission(request: true);
  }

  Future<void> start() async {
    if (_recording) return;
    _buffer.clear();
    final stream = await _record.startStream(
      const RecordConfig(encoder: AudioEncoder.opus),
    );
    _subscription = stream.listen((chunk) {
      _buffer.addAll(chunk);
    });
    _recording = true;
  }

  Future<RecordedAudio?> stop() async {
    if (!_recording) return null;
    await _record.stop();
    await _subscription?.cancel();
    _subscription = null;
    _recording = false;
    if (_buffer.isEmpty) return null;
    return RecordedAudio(bytes: List<int>.from(_buffer), extension: 'webm');
  }
}
