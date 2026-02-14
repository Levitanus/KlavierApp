import 'media_cache_audio_stub.dart'
    if (dart.library.io) 'media_cache_audio_io.dart'
    if (dart.library.html) 'media_cache_audio_web.dart';

Future<String?> resolveCachedAudioPath(String url) {
  return resolveCachedAudioPathImpl(url);
}
