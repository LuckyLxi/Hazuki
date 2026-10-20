import 'dart:io';

/// A plugin-provided chapter archive request. It never represents page images.
class SourceChapterArchive {
  const SourceChapterArchive({
    required this.url,
    this.headers = const {},
    this.fileName = 'chapter.archive',
    this.method = 'GET',
    this.body,
    this.sourceKey = '',
  });

  final String url;
  final Map<String, String> headers;
  final String fileName;
  final String method;
  final String? body;

  /// Set by the host, never taken from the plugin's response.
  final String sourceKey;

  factory SourceChapterArchive.parse(Object? value, {String sourceKey = ''}) {
    if (value is! Map || value['url'] is! String) {
      throw const FormatException('chapter_archive_invalid_request');
    }
    final url = (value['url'] as String).trim();
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !const ['http', 'https'].contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const FormatException('chapter_archive_invalid_url');
    }
    final method = value['method'] ?? 'GET';
    if (method != 'GET' && method != 'POST') {
      throw const FormatException('chapter_archive_invalid_method');
    }
    final body = value['body'];
    if (body != null && (body is! String || method != 'POST')) {
      throw const FormatException('chapter_archive_invalid_body');
    }
    final headers = <String, String>{};
    final rawHeaders = value['headers'];
    if (rawHeaders != null) {
      if (rawHeaders is! Map) {
        throw const FormatException('chapter_archive_invalid_headers');
      }
      for (final entry in rawHeaders.entries) {
        if (entry.key is! String ||
            entry.value is! String ||
            (entry.key as String).trim().isEmpty ||
            '${entry.key}${entry.value}'.contains(RegExp(r'[\r\n]'))) {
          throw const FormatException('chapter_archive_invalid_headers');
        }
        headers[entry.key as String] = entry.value as String;
      }
    }
    final suppliedName = value['fileName'];
    if (suppliedName != null && suppliedName is! String) {
      throw const FormatException('chapter_archive_invalid_file_name');
    }
    final urlName = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final name =
        suppliedName ??
        (RegExp(
              r'\.(zip|cbz|rar|cbr|7z|cb7|tar|cbt|gz|tgz)$',
              caseSensitive: false,
            ).hasMatch(urlName)
            ? urlName
            : 'chapter.archive');
    if (name.isEmpty ||
        name == '.' ||
        name == '..' ||
        name.length > 180 ||
        name.contains(RegExp(r'[<>:"/\\|?*\x00-\x1f]')) ||
        name.endsWith('.') ||
        name.endsWith(' ') ||
        RegExp(
          r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])(?:\.|$)',
          caseSensitive: false,
        ).hasMatch(name)) {
      throw const FormatException('chapter_archive_invalid_file_name');
    }
    return SourceChapterArchive(
      url: url,
      headers: Map.unmodifiable(headers),
      fileName: name,
      method: method as String,
      body: body as String?,
      sourceKey: sourceKey,
    );
  }
}

/// Optional extension, so existing reader gateways keep their image downloads.
abstract interface class SourceChapterArchiveGateway {
  /// Null means the callback is absent. Invalid results and errors must throw.
  Future<SourceChapterArchive?> loadChapterArchive({
    required String comicId,
    required String epId,
    String sourceKey = '',
  });

  Future<void> downloadChapterArchive(
    SourceChapterArchive archive,
    File destination, {
    required String sourceKey,
    required bool Function() shouldCancel,
  });
}

class SourceChapterArchiveCancelled implements Exception {
  const SourceChapterArchiveCancelled();
}
