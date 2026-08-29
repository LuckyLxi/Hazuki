import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_cookie_store.dart';
import 'package:hazuki/services/source/runtime/source_runtime_coordinator.dart';
import 'package:hazuki/services/source/runtime/source_runtime_facade.dart';
import 'package:hazuki/services/source/runtime/source_runtime_kernel.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SourceRuntimeCoordinator', () {
    test('serializes source switches and disposes replaced handles', () async {
      final created = <String, _FakeRuntimeResource>{};
      final persisted = <String>[];
      final firstPersistStarted = Completer<void>();
      final releaseFirstPersist = Completer<void>();
      var notifications = 0;
      final coordinator = _createCoordinator(
        created: created,
        onActiveSourceChanged: () => notifications++,
      );
      final initial = coordinator.handleFor('jm');

      final first = coordinator.activate(
        'copy_manga',
        persistSelection: (handle) async {
          persisted.add(handle.sourceKey);
          firstPersistStarted.complete();
          await releaseFirstPersist.future;
        },
      );
      await firstPersistStarted.future;
      final second = coordinator.activate(
        'picacg',
        persistSelection: (handle) async {
          persisted.add(handle.sourceKey);
        },
      );

      expect(coordinator.activeSourceKey, 'jm');
      releaseFirstPersist.complete();
      await Future.wait([first, second]);

      expect(persisted, ['copy_manga', 'picacg']);
      expect(coordinator.activeSourceKey, 'picacg');
      expect(initial.disposeCount, 1);
      expect(created['copy_manga']!.disposeCount, 1);
      expect(notifications, 2);
    });

    test('rejects unknown sources before creating a handle', () {
      final created = <String, _FakeRuntimeResource>{};
      final coordinator = _createCoordinator(created: created);

      expect(
        () => coordinator.activate('unknown', persistSelection: (_) async {}),
        throwsA(isA<Exception>()),
      );
      expect(created, isEmpty);
    });

    test('repairs an invalid saved source with the default', () async {
      final coordinator = _createCoordinator(created: {});
      String? persisted;

      await coordinator.loadActiveSourcePreference(
        readSavedSourceKey: () async => 'removed_source',
        persistSourceKey: (sourceKey) async => persisted = sourceKey,
      );

      expect(coordinator.activeSourceKey, 'jm');
      expect(persisted, 'jm');
    });

    test('recreates a runtime once for concurrent recovery requests', () {
      final created = <String, _FakeRuntimeResource>{};
      final coordinator = _createCoordinator(created: created);
      final original = coordinator.handleFor('copy_manga');

      final replacement = coordinator.recreate(
        'copy_manga',
        expectedHandle: original,
      );
      final concurrentReplacement = coordinator.recreate(
        'copy_manga',
        expectedHandle: original,
      );

      expect(original.disposeCount, 1);
      expect(replacement, isNot(same(original)));
      expect(concurrentReplacement, same(replacement));
    });
  });

  group('SourceSessionStore', () {
    test('uses the injected preferences loader and secure storage', () async {
      SharedPreferences.setMockInitialValues(const {});
      final preferences = await SharedPreferences.getInstance();
      final secureStorage = MemorySourceSecureSessionStorage();
      var loadCount = 0;
      final session = SourceSessionStore(
        sourceKey: 'jm',
        secureStorage: secureStorage,
        loadPreferences: () async {
          loadCount++;
          return preferences;
        },
      );

      await session.ensurePrefs();
      await session.ensurePrefs();
      await session.saveSourceData('jm', 'account', ['user', 'pass']);
      await session.saveSourceData('jm', 'token', 'token');
      await session.saveCookieStore(const [
        SourceCookie(
          name: 'sid',
          value: 'abc',
          domain: 'example.com',
          path: '/',
        ),
      ]);

      expect(loadCount, 1);
      expect(
        jsonDecode(
          secureStorage.values[SourceSecureSessionStorageKeys.account('jm')]!,
        ),
        ['user', 'pass'],
      );
      expect(
        secureStorage.values[SourceSecureSessionStorageKeys.token('jm')],
        'token',
      );
      expect(session.loadCookieStore().single.name, 'sid');
    });

    test('retains legacy secrets when secure migration fails', () async {
      SharedPreferences.setMockInitialValues({
        'source_data_jm': jsonEncode({
          'account': ['user', 'pass'],
          'token': 'token',
        }),
      });
      final preferences = await SharedPreferences.getInstance();
      final session = SourceSessionStore(
        sourceKey: 'jm',
        secureStorage: _FailingSecureStorage(),
        loadPreferences: () async => preferences,
      );

      await session.ensurePrefs();

      final legacy = jsonDecode(preferences.getString('source_data_jm')!);
      expect(legacy['account'], ['user', 'pass']);
      expect(legacy['token'], 'token');
      expect(
        preferences.getBool('source_secure_session_migration_v1'),
        isNot(true),
      );
    });
  });

  test(
    'keeps a runtime retained while resolving a JavaScript future',
    () async {
      final handle = _FakeRuntimeHandle();
      final bridge = SourceJsBridge(SourceRuntimeKernel(), handle);
      final result = Completer<String>();

      final resolving = bridge.resolve(result.future);
      expect(handle.activeOperationCount, 1);

      result.complete('details');
      expect(await resolving, 'details');
      expect(handle.activeOperationCount, 0);
    },
  );

  test(
    'SourceCookieStore parses, persists, and selects scoped cookies',
    () async {
      var cookies = <SourceCookie>[];
      var saveCount = 0;
      final store = SourceCookieStore(
        loadCookies: () => List.of(cookies),
        saveCookies: (next) async {
          saveCount++;
          cookies = List.of(next);
        },
      );

      await store.saveFromHeaders('https://sub.example.com/path', {
        'set-cookie': [
          'sid=domain; Domain=example.com; Path=/',
          'sid=host; Path=/',
          'page=reader; Path=/reader',
        ],
      });

      expect(
        store.buildHeader('https://sub.example.com/reader/1'),
        'sid=host; page=reader',
      );
      expect(store.buildHeader('https://sub.example.com/other'), 'sid=host');
      expect(saveCount, 1);

      await store.delete('https://sub.example.com/reader/1');
      expect(store.buildHeader('https://sub.example.com/reader/1'), isNull);
    },
  );
}

SourceRuntimeCoordinator<_FakeRuntimeResource> _createCoordinator({
  required Map<String, _FakeRuntimeResource> created,
  void Function()? onActiveSourceChanged,
}) {
  return SourceRuntimeCoordinator<_FakeRuntimeResource>(
    catalog: const [
      SourceCatalogEntry(key: 'jm', name: 'JM', fileName: 'jm.js'),
      SourceCatalogEntry(
        key: 'copy_manga',
        name: 'CopyManga',
        fileName: 'copy_manga.js',
      ),
      SourceCatalogEntry(key: 'picacg', name: 'Picacg', fileName: 'picacg.js'),
    ],
    defaultSourceKey: 'jm',
    createHandle: (sourceKey) {
      final resource = _FakeRuntimeResource(sourceKey);
      created[sourceKey] = resource;
      return resource;
    },
    onActiveSourceChanged: onActiveSourceChanged ?? () {},
  );
}

class _FakeRuntimeResource implements SourceRuntimeResource {
  _FakeRuntimeResource(this.sourceKey);

  @override
  final String sourceKey;
  int disposeCount = 0;

  @override
  void requestDispose() => disposeCount++;
}

class _FakeRuntimeHandle implements SourceRuntimeHandleView {
  var activeOperationCount = 0;

  @override
  final SourceCookieStore cookieStore = SourceCookieStore(
    loadCookies: () => const [],
    saveCookies: (_) async {},
  );

  @override
  bool get isDisposed => false;

  @override
  String get sourceKey => 'copy_manga';

  @override
  Future<T> runOperation<T>(Future<T> Function() operation) async {
    activeOperationCount++;
    try {
      return await operation();
    } finally {
      activeOperationCount--;
    }
  }
}

class _FailingSecureStorage implements SourceSecureSessionStorage {
  @override
  Future<void> delete(String key) async {}

  @override
  Future<String?> read(String key) async => null;

  @override
  Future<void> write(String key, String value) async {
    throw StateError('secure_storage_unavailable');
  }
}
