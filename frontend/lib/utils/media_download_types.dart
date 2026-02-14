class MediaDownloadResult {
  final bool success;
  final String? filePath;
  final String? errorMessage;

  const MediaDownloadResult._({
    required this.success,
    this.filePath,
    this.errorMessage,
  });

  const MediaDownloadResult.success({String? filePath})
      : this._(success: true, filePath: filePath);

  const MediaDownloadResult.failure({String? errorMessage})
      : this._(success: false, errorMessage: errorMessage);
}
