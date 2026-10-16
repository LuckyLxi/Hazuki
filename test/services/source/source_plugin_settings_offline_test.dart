import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/plugins/source_plugin_manager.dart';
import 'package:hazuki/services/source/runtime/source_runtime_assembly.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _script = '''
Hazuki.registerSource({
  id: 'offline_settings', name: 'Offline settings', version: '1.0.0',
  translation: {zh: {'Option': '选项'}},
  settings: {
    option: {title: 'Option', type: 'switch', default: false,
      onChanged: async value => {
        await Hazuki.storage.set('changed', value);
      }},
    host: {title: 'Host', type: 'input', default: 'cached.example', location: 'lines'}
  },
  async init() {
    await Hazuki.storage.set('initStarted', true);
    try { await Hazuki.http.get('https://offline.invalid/init'); }
    catch (_) {}
    await Hazuki.storage.set('initOption', Hazuki.settings.get('option'));
  },
  search: {load: async () => ({comics: []})},
  comic: {loadInfo: async () => ({}), loadEp: async () => ({images: []})}
});
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late SourcePluginManager manager;
  late SourceRuntimeAssembly assembly;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'source_data_offline_settings': jsonEncode({
        'settings': {'option': true, 'host': 'saved.example'},
      }),
    });
    directory = await Directory.systemTemp.createTemp(
      'hazuki_offline_settings_',
    );
    manager = SourcePluginManager(
      directory: () async => directory,
      legacyDirectories: [],
      download: (_) async => throw StateError('unexpected plugin download'),
    );
    assembly = SourceRuntimeAssembly(
      pluginManager: manager,
      secureSessionStorage: MemorySourceSecureSessionStorage(),
    );
    await assembly.runtimeRegistry.loadActiveSourcePreference();
    await manager.importPackage(utf8.encode(_script));
  });

  tearDown(() async {
    assembly.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'cold settings read and save do not start network initialization',
    () async {
      final gateway = assembly.pluginGateway;
      final handle = assembly.testing.handleFor('offline_settings');
      final metadata = await gateway.loadMetadata('offline_settings');

      expect(metadata!.settings['option']['title'], 'Option');
      expect(metadata.settings['host']['location'], 'lines');
      expect(metadata.translation['zh']['Option'], '选项');
      expect(gateway.loadSetting('offline_settings', 'option'), isTrue);
      expect(gateway.loadSetting('offline_settings', 'host'), 'saved.example');
      expect(handle.runtime.engine, isNull);
      expect(handle.runtime.initFuture, isNull);
      expect(handle.facade.runtimeState.phase, SourceRuntimePhase.idle);

      handle.cache.exploreSectionsMemoryCache = [];
      await gateway.saveSetting('offline_settings', 'option', false);
      await gateway.saveSetting('offline_settings', 'host', 'offline.example');

      expect(gateway.loadSetting('offline_settings', 'option'), isFalse);
      expect(
        gateway.loadSetting('offline_settings', 'host'),
        'offline.example',
      );
      expect(
        handle.facade.loadSourceData('offline_settings', 'changed'),
        isFalse,
      );
      expect(
        handle.facade.loadSourceData('offline_settings', 'initStarted'),
        isNull,
      );
      expect(handle.cache.exploreSectionsMemoryCache, isNull);
      expect(handle.runtime.engine, isNull);

      final adapter = _StalledOfflineAdapter();
      handle.dio.httpClientAdapter = adapter;
      handle.cache.imageCacheDir = directory;
      final initialization = assembly.ensureSourceInitialized(
        'offline_settings',
      );
      await adapter.started.future;
      adapter.release.complete();
      await initialization;

      expect(handle.facade.runtimeState.phase, SourceRuntimePhase.ready);
      expect(
        handle.facade.loadSourceData('offline_settings', 'initOption'),
        isFalse,
      );
    },
  );

  test(
    'settings remain usable while network initialization is pending',
    () async {
      final handle = assembly.testing.handleFor('offline_settings');
      handle.cache.imageCacheDir = directory;
      final adapter = _StalledOfflineAdapter();
      handle.dio.httpClientAdapter = adapter;
      final initialization = assembly.ensureSourceInitialized(
        'offline_settings',
      );
      await adapter.started.future;
      try {
        final engine = handle.runtime.engine;
        final metadata = await assembly.pluginGateway
            .loadMetadata('offline_settings')
            .timeout(const Duration(seconds: 2));
        await assembly.pluginGateway
            .saveSetting('offline_settings', 'option', false)
            .timeout(const Duration(seconds: 2));

        expect(metadata!.settings, contains('option'));
        expect(handle.runtime.engine, same(engine));
        expect(handle.runtime.initFuture, isNotNull);
        expect(handle.facade.runtimeState.phase, SourceRuntimePhase.loading);
        expect(
          assembly.pluginGateway.loadSetting('offline_settings', 'option'),
          isFalse,
        );
        expect(
          handle.facade.loadSourceData('offline_settings', 'changed'),
          isFalse,
        );
      } finally {
        adapter.release.complete();
        await initialization;
      }
      expect(handle.facade.runtimeState.phase, SourceRuntimePhase.ready);
      expect(
        handle.facade.loadSourceData('offline_settings', 'initOption'),
        isFalse,
      );
    },
  );
}

class _StalledOfflineAdapter implements HttpClientAdapter {
  final started = Completer<void>();
  final release = Completer<void>();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (!started.isCompleted) started.complete();
    await release.future;
    throw DioException.connectionError(
      requestOptions: options,
      reason: 'simulated offline connection',
    );
  }

  @override
  void close({bool force = false}) {}
}
