import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_catalog_resolver.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_facade.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_loader.dart';
import 'package:hazuki/services/source/runtime/source_runtime_state_controller.dart';
import 'package:hazuki/services/source/runtime/source_script_storage.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_text_downloader.dart';

void main() {
  test('extracts the source class name and rejects invalid scripts', () {
    expect(
      extractSourceClassName('class ExampleSource extends ComicSource {}'),
      'ExampleSource',
    );
    expect(
      () => extractSourceClassName('class ExampleSource {}'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('source_class_not_found'),
        ),
      ),
    );
  });

  test('extracts only declared source setting defaults', () {
    expect(
      parseSourceSettingsDefaults({
        'quality': {
          'default': 'high',
          'options': ['low', 'high'],
        },
        'enabled': {'default': false},
        'label': 'ignored',
      }),
      {'quality': 'high', 'enabled': false},
    );
    expect(parseSourceSettingsDefaults(null), isEmpty);
  });

  test('uses a local script without invoking the downloader', () async {
    final directory = await Directory.systemTemp.createTemp(
      'hazuki_runtime_loader_test_',
    );
    addTearDown(() => directory.delete(recursive: true));
    final sourceFile = File('${directory.path}/source.js');
    await sourceFile.writeAsString('cached source');
    final store = _LoaderScriptStore(sourceFile);
    final downloader = _RejectingDownloader();
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
    final loader = SourceRuntimeLoader(
      scriptStore: store,
      catalogResolver: SourceCatalogResolver(
        runtimeHost: host,
        downloader: downloader,
        sourceIndexUrls: const [],
      ),
      downloader: downloader,
      jsBridge: SourceJsBridgeCookieCapability(
        activeHandle: () => host.activeHandle,
      ),
      runtimeStateController: SourceRuntimeStateController(),
      bundledInitAssetPath: 'unused.js',
      loadAssetText: (_) async => '',
    );

    final result = await loader.downloadOrLoad(host.activeHandle);

    expect(result.sourceFile.path, sourceFile.path);
    expect(result.message, 'source_loaded_from_local_cache');
    expect(downloader.callCount, 0);
  });
}

class _RejectingDownloader implements SourceTextDownloadClient {
  var callCount = 0;

  @override
  Future<String?> firstAvailable(
    List<String> urls, {
    required HazukiSourceFacade facade,
    String source = 'source_fetch',
  }) async {
    callCount++;
    throw StateError('unexpected download');
  }

  @override
  Future<String?> sequential(
    List<String> urls, {
    required HazukiSourceFacade facade,
    void Function(int received, int total)? onProgress,
    String source = 'source_download',
  }) async {
    callCount++;
    throw StateError('unexpected download');
  }
}

class _LoaderScriptStore implements SourceScriptStore {
  _LoaderScriptStore(this.file);

  final File file;

  @override
  Future<File> ensureLocalSourceFile(String sourceKey) async => file;

  @override
  Future<File> sourceFileFor(
    String sourceKey, {
    bool ensureDirectory = false,
  }) async => file;

  @override
  Future<void> delete(String sourceKey) async {
    if (await file.exists()) await file.delete();
  }

  @override
  Future<bool> exists(String sourceKey) => file.exists();

  @override
  Future<bool> isCustomEdited(String sourceKey) async => false;

  @override
  Future<String?> readIfExists(String sourceKey) async =>
      await file.exists() ? file.readAsString() : null;

  @override
  Future<void> setCustomEdited(String sourceKey, bool value) async {}

  @override
  Future<void> write(String sourceKey, String content) async {
    await file.writeAsString(content);
  }
}
