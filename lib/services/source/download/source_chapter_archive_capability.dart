import 'dart:io';

import 'package:dio/dio.dart';

import '../../network/hazuki_network.dart';
import '../runtime/source_runtime_host.dart';
import '../runtime/source_runtime_operations.dart';
import 'source_chapter_archive.dart';

class SourceChapterArchiveCapability implements SourceChapterArchiveGateway {
  SourceChapterArchiveCapability(this.host, this.operations);

  final SourceRuntimeHost host;
  final SourceRuntimeOperations operations;

  String _sourceKey(String value) {
    final key = value.trim().isEmpty ? host.activeSourceKey : value.trim();
    if (!host.runtimeRegistry.isAllowedSourceKey(key)) {
      throw StateError('chapter_archive_source_unavailable:$key');
    }
    return key;
  }

  @override
  Future<SourceChapterArchive?> loadChapterArchive({
    required String comicId,
    required String epId,
    String sourceKey = '',
  }) async {
    final key = _sourceKey(sourceKey);
    await operations.ensureSourceInitialized(key);
    final handle = host.handleFor(key);
    return handle.runOperation(() async {
      final engine = handle.runtime.engine;
      if (engine == null) throw StateError('source_not_initialized');
      final declared = await engine.evaluate(
        'globalThis.__hazuki_source.comic?.downloadChapter != null',
      );
      if (declared != true) return null;
      final result = await handle.facade.js.resolve(
        engine.invoke(
          '(comicId, chapterId) => globalThis.__hazuki_source.comic.downloadChapter(comicId, chapterId)',
          [comicId, epId],
        ),
      );
      return SourceChapterArchive.parse(result, sourceKey: key);
    });
  }

  @override
  Future<void> downloadChapterArchive(
    SourceChapterArchive archive,
    File destination, {
    required String sourceKey,
    required bool Function() shouldCancel,
  }) async {
    final key = archive.sourceKey.isEmpty ? sourceKey : archive.sourceKey;
    if (sourceKey.isNotEmpty && sourceKey != key) {
      throw StateError('chapter_archive_source_mismatch');
    }
    final resolvedKey = _sourceKey(key);
    // Switching sources may retire the handle that resolved the request.
    // Reinitialize that same source to restore its persisted cookies/client.
    await operations.ensureSourceInitialized(resolvedKey);
    final handle = host.handleFor(resolvedKey);
    await handle.runOperation(() async {
      if (shouldCancel()) throw const SourceChapterArchiveCancelled();
      final token = CancelToken();
      final response = await handle.httpGateway.request<ResponseBody>(
        archive.url,
        method: archive.method,
        data: archive.body,
        cancelToken: token,
        retryPolicy: HazukiNetworkRetryPolicy.none,
        options: Options(
          responseType: ResponseType.stream,
          headers: archive.headers,
          validateStatus: (status) =>
              status != null && status >= 200 && status < 300,
          extra: const {'hazukiLogCategory': 'chapter_archive_download'},
        ),
      );
      final body = response.data;
      if (body == null) throw StateError('chapter_archive_empty_response');
      final output = await destination.open(mode: FileMode.write);
      var received = 0;
      try {
        await for (final chunk in body.stream) {
          if (shouldCancel()) {
            token.cancel();
            throw const SourceChapterArchiveCancelled();
          }
          received += chunk.length;
          await output.writeFrom(chunk);
        }
        await output.flush();
      } finally {
        await output.close();
        token.cancel();
      }
      if (received == 0) throw StateError('chapter_archive_empty_response');
    });
  }
}
