import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class MediaCacheService {
  MediaCacheService._();

  static final MediaCacheService instance = MediaCacheService._();

  static const String _cacheKey = 'music_school_media_cache';

  final CacheManager _cacheManager = CacheManager(
    Config(
      _cacheKey,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 200,
    ),
  );

  CacheManager get cacheManager => _cacheManager;

  ImageProvider imageProvider(String url) {
    return CachedNetworkImageProvider(url, cacheManager: _cacheManager);
  }

  Widget cachedImage({
    required String url,
    BoxFit? fit,
    double? width,
    double? height,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: width,
      height: height,
      cacheManager: _cacheManager,
      placeholder: placeholder == null
          ? null
          : (context, _) => placeholder,
      errorWidget: errorWidget == null
          ? null
          : (context, _, __) => errorWidget,
    );
  }

  Future<void> clear() async {
    await _cacheManager.emptyCache();
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  }
}
