import 'media_download_types.dart';
import 'media_download_stub.dart'
		if (dart.library.io) 'media_download_io.dart'
		if (dart.library.html) 'media_download_web.dart';

Future<MediaDownloadResult> downloadMedia({
	required String url,
	String? filename,
	String appFolderName = 'klavierapp',
}) {
	return downloadMediaImpl(
		url: url,
		filename: filename,
		appFolderName: appFolderName,
	);
}
