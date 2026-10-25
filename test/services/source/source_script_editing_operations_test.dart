import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_state_controller.dart';
import 'package:hazuki/services/source/runtime/source_script_editing_operations.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  late SourceRuntimeHost host;
  late _MemorySourceScriptStore store;
  late SourceScriptEditingOperations scripts;

  setUp(() {
    store = _MemorySourceScriptStore();
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(key: 'jm', name: 'JMComic', fileName: 'jm.js'),
        SourceCatalogEntry(
          key: 'copy_manga',
          name: 'CopyManga',
          fileName: 'copy_manga.js',
        ),
      ],
      defaultSourceKey: 'jm',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    scripts = SourceScriptEditingOperations(
      runtimeHost: host,
      storage: store,
      runtimeStateController: SourceRuntimeStateController(),
      ensureEditableFile: (_) => throw UnsupportedError('not used'),
    );
    addTearDown(host.dispose);
  });

  test('writing the active script marks only that source as edited', () async {
    await scripts.writeLocalActiveSource('edited source');

    expect(store.contents, {'jm': 'edited source'});
    expect(store.edited, {'jm': true});
  });

  test(
    'deleting an inactive script uninstalls it and keeps its edit state',
    () async {
      store.contents['copy_manga'] = 'cached source';
      store.edited['copy_manga'] = true;

      await scripts.deleteLocalSourceFile('copy_manga');

      expect(store.contents, isNot(contains('copy_manga')));
      expect(store.edited['copy_manga'], isTrue);
    },
  );

  test('rejects deleting the active source', () async {
    store.contents['jm'] = 'active source';

    await expectLater(
      scripts.deleteLocalSourceFile('jm'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'source_delete_active_not_allowed',
        ),
      ),
    );
    expect(store.contents['jm'], 'active source');
  });
}

class _MemorySourceScriptStore implements SourcePluginManager {
  final contents = <String, String>{};
  final edited = <String, bool>{};

  @override
  Future<void> delete(String sourceKey) async {
    contents.remove(sourceKey);
  }

  @override
  Future<bool> exists(String sourceKey) async =>
      contents.containsKey(sourceKey);

  @override
  Future<bool> isCustomEdited(String sourceKey) async =>
      edited[sourceKey] ?? false;

  @override
  Future<void> setCustomEdited(String sourceKey, bool value) async {
    edited[sourceKey] = value;
  }

  @override
  Future<void> write(String sourceKey, String content) async {
    contents[sourceKey] = content;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
