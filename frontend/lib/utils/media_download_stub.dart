import 'media_download_types.dart';

Future<MediaDownloadResult> downloadMediaImpl({
	required String url,
	String? filename,
	String appFolderName = 'music_school_app',
}) async {
	return const MediaDownloadResult.failure(
		errorMessage: 'Downloads are not supported on this platform.',
	);
}
