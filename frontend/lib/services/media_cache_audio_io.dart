import 'media_cache_service.dart';

Future<String?> resolveCachedAudioPathImpl(String url) async {
  final cacheManager = MediaCacheService.instance.cacheManager;
  try {
    final cached = await cacheManager.getFileFromCache(url);
    if (cached != null && cached.file.existsSync()) {
      return cached.file.path;
    }
  } catch (_) {
    // Ignore cache read failures.
  }

  try {
    final file = await cacheManager.getSingleFile(url);
    return file.path;
  } catch (_) {
    return null;
  }
}
