part of '../quill_embed_builders.dart';

List<quill.EmbedBuilder> defaultQuillEmbedBuilders() {
  return [
    ImageEmbedBuilder(),
    VideoEmbedBuilder(),
    AudioEmbedBuilder(),
    VoiceEmbedBuilder(),
    FileEmbedBuilder(),
  ];
}

quill.EmbedBuilder defaultUnknownEmbedBuilder() {
  return UnknownEmbedBuilder();
}

class ImageEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'image';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    final content = GestureDetector(
      onTap: () {},
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 300),
        child: MediaCacheService.instance.cachedImage(
          url: absoluteUrl,
          fit: BoxFit.contain,
          errorWidget: Container(
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.broken_image),
            ),
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _buildAttachmentWithMenu(
        context,
        content: content,
        url: absoluteUrl,
        showMenu: embedContext.readOnly,
      ),
    );
  }
}

class VideoEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'video';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _buildVideoPreviewEmbed(
        context,
        url: absoluteUrl,
        showMenu: embedContext.readOnly,
      ),
    );
  }
}

class AudioEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'audio';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _buildAudioEmbed(
        context,
        url: absoluteUrl,
        label: AppLocalizations.of(context)?.commonAudio ?? 'Audio',
        showMenu: embedContext.readOnly,
      ),
    );
  }
}

class VoiceEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'voice';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: _buildAudioEmbed(
        context,
        url: absoluteUrl,
        label: AppLocalizations.of(context)?.commonVoiceMessage ??
            'Voice message',
        showMenu: embedContext.readOnly,
      ),
    );
  }
}

class FileEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'file';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    final url = embedContext.node.value.data as String;
    final absoluteUrl = normalizeMediaUrl(url);
    final content = Row(
      children: [
        const Icon(Icons.file_present),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            absoluteUrl.split('/').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: _buildAttachmentWithMenu(
        context,
        content: content,
        url: absoluteUrl,
        showMenu: embedContext.readOnly,
      ),
    );
  }
}

class UnknownEmbedBuilder extends quill.EmbedBuilder {
  @override
  String get key => 'unknown';

  @override
  Widget build(BuildContext context, quill.EmbedContext embedContext) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Container(
        color: Colors.orange[100],
        padding: const EdgeInsets.all(8),
        child: Text(
          AppLocalizations.of(context)?.feedsUnsupportedEmbed(
                embedContext.node.value.data,
              ) ??
              'Unsupported embed: ${embedContext.node.value.data}',
          style: const TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
    );
  }
}
