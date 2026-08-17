import 'dart:convert';

import '../models/source_contract_models.dart';
import 'source_runtime_facade.dart';
import 'source_runtime_handle.dart';
import 'source_runtime_host.dart';
import 'source_text_downloader.dart';

/// Resolves a catalog entry to concrete source-script download URLs.
class SourceCatalogResolver {
  SourceCatalogResolver({
    required SourceRuntimeHost runtimeHost,
    required SourceTextDownloadClient downloader,
    required List<String> sourceIndexUrls,
  }) : _runtimeHost = runtimeHost,
       _downloader = downloader,
       _sourceIndexUrls = List.unmodifiable(sourceIndexUrls);

  final SourceRuntimeHost _runtimeHost;
  final SourceTextDownloadClient _downloader;
  final List<String> _sourceIndexUrls;

  Future<List<String>> resolve(SourceRuntimeHandle handle) => resolveDefinition(
    _runtimeHost.definitionFor(handle.sourceKey),
    handle.facade,
  );

  Future<List<String>> resolveDefinition(
    SourceCatalogEntry definition,
    HazukiSourceFacade facade, {
    String indexLogSource = 'source_catalog_index',
  }) async {
    final directUrls = definition.directUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    if (directUrls.isNotEmpty) return directUrls;

    final indexRaw = await _downloader.firstAvailable(
      _sourceIndexUrls,
      facade: facade,
      source: indexLogSource,
    );
    if (indexRaw == null || indexRaw.trim().isEmpty) {
      return definition.fallbackUrls();
    }

    try {
      final decoded = jsonDecode(indexRaw);
      if (decoded is List) {
        for (final item in decoded) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          if (!definition.matchesIndexEntry(map)) continue;
          final rawUrl = map['url']?.toString().trim();
          if (rawUrl != null && rawUrl.isNotEmpty) return [rawUrl];
          final fileName =
              map['fileName']?.toString().trim() ?? definition.fileName;
          if (fileName.isNotEmpty) {
            return [
              'https://cdn.jsdelivr.net/gh/venera-app/venera-configs@main/$fileName',
            ];
          }
        }
      }
    } catch (_) {}
    return definition.fallbackUrls();
  }
}
