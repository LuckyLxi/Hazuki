import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/plugins/source_plugin_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_update_operations.dart';

void main() {
  late SourceRuntimeHost host;
  late _FakePluginManager plugins;
  late SourceUpdateOperations updates;

  setUp(() {
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(key: 'jm', name: 'JMComic', fileName: 'main.js'),
      ],
      defaultSourceKey: 'jm',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    addTearDown(host.dispose);
    plugins = _FakePluginManager();
    updates = SourceUpdateOperations(runtimeHost: host, plugins: plugins);
  });

  test('reports the active plugin update from its repository index', () async {
    plugins.update = SourcePluginIndexEntry(
      id: 'jm',
      name: 'JMComic',
      version: '1.2.0',
      downloadUrl: Uri.parse('https://example.com/jm.zip'),
    );

    final result = await updates.checkActiveSourceVersion();

    expect(plugins.checkedIds, ['jm']);
    expect(result?.sourceKey, 'jm');
    expect(result?.sourceName, 'JMComic');
    expect(result?.localVersion, '1.0.0');
    expect(result?.remoteVersion, '1.2.0');
    expect(result?.hasUpdate, isTrue);
  });

  test('returns null when the active plugin is current', () async {
    expect(await updates.checkActiveSourceVersion(), isNull);
  });

  test('redownloads the active plugin from its repository', () async {
    expect(await updates.downloadActiveSource(), isTrue);
    expect(plugins.redownloadedIds, ['jm']);
  });
}

class _FakePluginManager implements SourcePluginManager {
  SourcePluginIndexEntry? update;
  final checkedIds = <String>[];
  final redownloadedIds = <String>[];

  @override
  Future<SourcePluginIndexEntry?> checkUpdate(String id) async {
    checkedIds.add(id);
    return update;
  }

  @override
  InstalledSourcePlugin? pluginFor(String id) => InstalledSourcePlugin(
    manifest: SourcePluginManifest(
      id: id,
      name: 'JMComic',
      version: '1.0.0',
      apiVersion: 1,
      entry: 'main.js',
    ),
    directory: id,
  );

  @override
  Future<bool> redownload(String id) async {
    redownloadedIds.add(id);
    return true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
