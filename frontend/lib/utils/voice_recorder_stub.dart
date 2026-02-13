class RecordedAudio {
  final List<int> bytes;
  final String extension;

  RecordedAudio({
    required this.bytes,
    required this.extension,
  });
}

class VoiceRecorder {
  Future<bool> isAvailable() async => false;

  Future<void> start() async {}

  Future<RecordedAudio?> stop() async => null;

  bool get isRecording => false;
}
