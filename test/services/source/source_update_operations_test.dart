import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_catalog_resolver.dart';
import 'package:hazuki/services/source/runtime/source_runtime_facade.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_state_controller.dart';
import 'package:hazuki/services/source/runtime/source_script_editing_operations.dart';
import 'package:hazuki/services/source/runtime/source_script_storage.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_text_downloader.dart';
import 'package:hazuki/services/source/runtime/source_update_operations.dart';

void main() {
  group('extractSourceVersion', () {
    test('reads single and double quoted assignments', () {
      expect(extractSourceVersion("version = '1.2.3'"), '1.2.3');
      expect(extractSourceVersion('version="4.5.6"'), '4.5.6');
    });

    test('uses the legacy fallback when no assignment exists', () {
      expect(extractSourceVersion('class Source {}'), '0.0.0');
    });
  });

  group('isSourceVersionGreater', () {
    test('compares numeric components instead of lexicographic text', () {
      expect(isSourceVersionGreater('1.10.0', '1.9.9'), isTrue);
      expect(isSourceVersionGreater('2.0', '10.0'), isFalse);
    });

    test('treats omitted and invalid components as zero', () {
      expect(isSourceVersionGreater('1.0.0', '1'), isFalse);
      expect(isSourceVersionGreater('1.0.1', '1.invalid.0'), isTrue);
    });
  });

  test('checks a local script against the source catalog version', () async {
    final directory = await Directory.systemTemp.createTemp(
      'hazuki_source_update_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final sourceFile = File('${directory.path}/source.js');
    await sourceFile.writeAsString("version = '1.0.0'");
    final store = _FileBackedSourceScriptStore(sourceFile);
    late SourceRuntimeHost host;
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'jm',
          name: 'JMComic',
          fileName: 'jm.js',
          directUrls: [],
        ),
      ],
      defaultSourceKey: 'jm',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    addTearDown(host.dispose);
    final scripts = SourceScriptEditingOperations(
      runtimeHost: host,
      storage: store,
      runtimeStateController: SourceRuntimeStateController(),
      ensureEditableFile: (_) async => sourceFile,
    );
    final updates = SourceUpdateOperations(
      runtimeHost: host,
      scriptStore: store,
      scriptEditing: scripts,
      runtimeStateController: SourceRuntimeStateController(),
      downloader: _CatalogDownloader(),
      urlResolver: SourceCatalogResolver(
        runtimeHost: host,
        downloader: _CatalogDownloader(),
        sourceIndexUrls: const ['https://example.com/index.json'],
      ),
      sourceIndexUrls: const ['https://example.com/index.json'],
    );
    host.activeHandle.facade.debug.softwareLogCaptureEnabled = true;

    final result = await updates.checkActiveSourceVersion();

    expect(result?.localVersion, '1.0.0');
    expect(result?.remoteVersion, '1.2.0');
    expect(result?.hasUpdate, isTrue);
    expect(
      host.activeHandle.facade.lastSourceVersionDebugInfo?['resolvedFrom'],
      isNull,
    );
    expect(
      host
          .activeHandle
          .facade
          .lastSourceVersionDebugInfo?['remoteVersionSource'],
      'index_json',
    );
  });
}

class _CatalogDownloader implements SourceTextDownloadClient {
  @override
  Future<String?> firstAvailable(
    List<String> urls, {
    required HazukiSourceFacade facade,
    String source = 'source_fetch',
  }) async => '[{"key":"jm","fileName":"jm.js","version":"1.2.0"}]';

  @override
  Future<String?> sequential(
    List<String> urls, {
    required HazukiSourceFacade facade,
    void Function(int received, int total)? onProgress,
    String source = 'source_download',
  }) => throw UnsupportedError('not used');
}

class _FileBackedSourceScriptStore implements SourceScriptStore {
  _FileBackedSourceScriptStore(this.file);

  final File file;

  @override
  Future<File> sourceFileFor(
    String sourceKey, {
    bool ensureDirectory = false,
  }) async => file;

  @override
  Future<File> ensureLocalSourceFile(String sourceKey) async => file;

  @override
  Future<String?> readIfExists(String sourceKey) async => file.readAsString();

  @override
  Future<void> write(String sourceKey, String content) async {
    await file.writeAsString(content);
  }

  @override
  Future<bool> exists(String sourceKey) => file.exists();

  @override
  Future<void> delete(String sourceKey) async {
    await file.delete();
  }

  @override
  Future<bool> isCustomEdited(String sourceKey) async => false;

  @override
  Future<void> setCustomEdited(String sourceKey, bool value) async {}
}
