import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

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

	try {
		final response = await http.get(uri);
		if (response.statusCode < 200 || response.statusCode >= 300) {
			return MediaDownloadResult.failure(
				errorMessage: 'Download failed (${response.statusCode}).',
			);
		}

		final baseDir = await _resolveBaseDirectory();
		if (baseDir == null) {
			return const MediaDownloadResult.failure(
				errorMessage: 'Unable to resolve download directory.',
			);
		}

		final folder = Directory('${baseDir.path}/$appFolderName');
		await folder.create(recursive: true);

		final targetName = _sanitizeFileName(
			filename ?? _fileNameFromUri(uri) ?? 'download.bin',
		);
		final path = await _nextAvailablePath(folder.path, targetName);

		final file = File(path);
		await file.writeAsBytes(response.bodyBytes, flush: true);

		return MediaDownloadResult.success(filePath: path);
	} catch (error) {
		return MediaDownloadResult.failure(errorMessage: error.toString());
	}
}

Future<Directory?> _resolveBaseDirectory() async {
	final publicDir = await _resolvePublicDownloads();
	if (publicDir != null) return publicDir;

	try {
		final downloads = await getDownloadsDirectory();
		if (downloads != null) return downloads;
	} catch (_) {
		// Ignore downloads directory errors.
	}

	try {
		final external = await getExternalStorageDirectory();
		if (external != null) return external;
	} catch (_) {
		// Ignore external storage errors.
	}

	try {
		return await getApplicationDocumentsDirectory();
	} catch (_) {
		return null;
	}
}

Future<Directory?> _resolvePublicDownloads() async {
	if (Platform.isAndroid) {
		final candidates = [
			Directory('/storage/emulated/0/Download'),
			Directory('/sdcard/Download'),
		];

		for (final dir in candidates) {
			try {
				if (!await dir.exists()) {
					await dir.create(recursive: true);
				}
				return dir;
			} catch (_) {
				// Try next candidate.
			}
		}
	}

	return null;
}

String? _fileNameFromUri(Uri uri) {
	if (uri.pathSegments.isEmpty) return null;
	final name = uri.pathSegments.last.trim();
	return name.isEmpty ? null : name;
}

String _sanitizeFileName(String name) {
	final sanitized = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
	return sanitized.isEmpty ? 'download.bin' : sanitized;
}

Future<String> _nextAvailablePath(String dirPath, String fileName) async {
	final separatorIndex = fileName.lastIndexOf('.');
	final base = separatorIndex > 0 ? fileName.substring(0, separatorIndex) : fileName;
	final ext = separatorIndex > 0 ? fileName.substring(separatorIndex) : '';

	var candidate = '$dirPath/$fileName';
	var counter = 1;

	while (await File(candidate).exists()) {
		candidate = '$dirPath/$base ($counter)$ext';
		counter += 1;
	}

	return candidate;
}
