import 'dart:typed_data';

import 'package:dio/dio.dart';

import 'package:hazuki/shared/lru_cache.dart';
import 'package:hazuki/services/network/hazuki_network.dart';

typedef AnnouncementImageDownloader = Future<Uint8List> Function(String url);

class AnnouncementImageSessionCache {
  AnnouncementImageSessionCache({
    required AnnouncementImageDownloader download,
    int maxEntries = 24,
  }) : _download = download,
       _entries = LruCache<String, Future<Uint8List>>(maxSize: maxEntries);

  static final AnnouncementImageSessionCache instance =
      AnnouncementImageSessionCache(download: _downloadImage);

  final AnnouncementImageDownloader _download;
  final LruCache<String, Future<Uint8List>> _entries;

  Future<Uint8List> load(String url) {
    final normalizedUrl = url.trim();
    final cached = _entries.get(normalizedUrl);
    if (cached != null) {
      return cached;
    }

    final future = _download(normalizedUrl).onError((error, stackTrace) {
      _entries.remove(normalizedUrl);
      Error.throwWithStackTrace(
        error ?? StateError('Announcement image download failed.'),
        stackTrace,
      );
    });
    _entries.put(normalizedUrl, future);
    return future;
  }

  static Future<Uint8List> _downloadImage(String url) async {
    final response = await _client.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    final data = response.data;
    if (data == null || data.isEmpty) {
      throw StateError('Announcement image response was empty.');
    }
    return Uint8List.fromList(data);
  }

  static final Dio _client = createHazukiDio(
    baseOptions: BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 5),
      responseType: ResponseType.bytes,
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );
}
