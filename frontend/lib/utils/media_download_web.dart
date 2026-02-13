import 'dart:html' as html;

import 'media_download_types.dart';

Future<MediaDownloadResult> downloadMediaImpl({
	required String url,
	String? filename,
	String appFolderName = 'klavierapp',
}) async {
	final uri = Uri.tryParse(url);
	if (uri == null) {
		return const MediaDownloadResult.failure(errorMessage: 'Invalid URL.');
	}

	final anchor = html.AnchorElement(href: uri.toString())
		..target = '_blank'
		..download = filename ?? '';
	html.document.body?.append(anchor);
	anchor.click();
	anchor.remove();

	return const MediaDownloadResult.success();
}
