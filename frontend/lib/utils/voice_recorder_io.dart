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
    
    try {
      final path = await _record.stop();
      _recording = false;
      
      if (path == null || path.isEmpty) return null;

      // Give the filesystem time to finalize the audio file before reading
      await Future.delayed(const Duration(milliseconds: 200));

      final file = File(path);
      
      // Check if file exists and has content
      if (!await file.exists()) {
        return null;
      }
      
      final fileSize = await file.length();
      if (fileSize == 0) {
        // File is empty, try waiting a bit more
        await Future.delayed(const Duration(milliseconds: 300));
        final updatedSize = await file.length();
        if (updatedSize == 0) return null;
      }

      final bytes = await file.readAsBytes();
      
      // Clean up the temporary file
      try {
        await file.delete();
      } catch (_) {
        // Ignore delete errors
      }
      
      return RecordedAudio(bytes: bytes, extension: 'ogg');
    } catch (e) {
      _recording = false;
      return null;
    }
  }
}
