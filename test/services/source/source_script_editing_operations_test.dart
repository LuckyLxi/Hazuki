import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_state_controller.dart';
import 'package:hazuki/services/source/runtime/source_script_editing_operations.dart';
import 'package:hazuki/services/source/runtime/source_script_storage.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';

void main() {
  late SourceRuntimeHost host;
  late _MemorySourceScriptStore store;
  late SourceScriptEditingOperations scripts;

  setUp(() {
    store = _MemorySourceScriptStore();
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'jm',
          name: 'JMComic',
          fileName: 'jm.js',
          directUrls: [],
        ),
        SourceCatalogEntry(
          key: 'copy_manga',
          name: 'CopyManga',
          fileName: 'copy_manga.js',
          directUrls: [],
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
    'deleting an inactive script clears state and releases its handle',
    () async {
      store.contents['copy_manga'] = 'cached source';
      store.edited['copy_manga'] = true;
      final previousHandle = host.handleFor('copy_manga');

      await scripts.deleteLocalSourceFile('copy_manga');

      expect(store.contents, isNot(contains('copy_manga')));
      expect(store.edited['copy_manga'], isFalse);
      expect(host.handleFor('copy_manga'), isNot(same(previousHandle)));
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

class _MemorySourceScriptStore implements SourceScriptStore {
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
  Future<String?> readIfExists(String sourceKey) async => contents[sourceKey];

  @override
  Future<void> setCustomEdited(String sourceKey, bool value) async {
    edited[sourceKey] = value;
  }

  @override
  Future<void> write(String sourceKey, String content) async {
    contents[sourceKey] = content;
  }

  @override
  Future<File> ensureLocalSourceFile(String sourceKey) =>
      throw UnsupportedError('not used');

  @override
  Future<File> sourceFileFor(
    String sourceKey, {
    bool ensureDirectory = false,
  }) => throw UnsupportedError('not used');
}
