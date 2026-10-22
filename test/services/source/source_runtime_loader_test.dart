import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/account/source_interactive_login_operations.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/models/source_contract_models.dart';
import 'package:hazuki/services/source/runtime/source_catalog_resolver.dart';
import 'package:hazuki/services/source/runtime/source_js_bridge_cookie_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_facade.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_loader.dart';
import 'package:hazuki/services/source/runtime/source_runtime_state_controller.dart';
import 'package:hazuki/services/source/runtime/source_script_storage.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/runtime/source_text_downloader.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hazuki/services/source/content/source_cloud_reading.dart';
import 'package:hazuki/services/source/runtime/source_runtime_operations.dart';
import 'package:hazuki/services/source/models/source_task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'foreground candidate cleanup preserves the original initialization error',
    () async {
      final fixture = await _createRuntimeFixture();
      await fixture.file.writeAsString(
        _runtimeScript(
          '2.0.0',
          init: "throw Error('synthetic_initialization_failure');",
        ),
      );
      await expectLater(
        SourceUiService.instance.run(
          () => fixture.loader.loadMetadata(
            fixture.host.activeHandle,
            fixture.file,
          ),
        ),
        throwsA(
          predicate<Object>(
            (error) =>
                error.toString().contains('synthetic_initialization_failure'),
          ),
        ),
      );
    },
  );
  test(
    'private cloud loader cancellation drains its HTTP candidate without replacing the owner',
    () async {
      final fixture = await _createRuntimeFixture();
      final owner = fixture.host.activeHandle;
      final main = owner.runtime.engine!;
      await owner.session.saveSourceData('jm', 'login_session', 'account');
      await main.evaluate(
        'globalThis.__hazuki_source.comic.loadReadingProgress=()=>null',
      );
      await fixture.file.writeAsString(
        _runtimeScript(
          '2.0.0',
          init:
              "await sendMessage({method:'http',url:'https://fixture.test/private-init'});",
        ),
      );
      final entered = Completer<void>();
      final aborted = Completer<void>();
      SourceRuntimeHandle? candidate;
      final cloud = SourceCloudReadingCapability(
        fixture.host,
        _CloudOperations(),
        loadReadRuntime: (handle) async {
          candidate = handle;
          handle.dio.interceptors.add(
            InterceptorsWrapper(
              onRequest: (request, handler) async {
                entered.complete();
                await request.cancelToken!.whenCancel;
                aborted.complete();
                handler.reject(
                  DioException.requestCancelled(
                    requestOptions: request,
                    reason: 'stopped',
                  ),
                );
              },
            ),
          );
          await fixture.loader.loadMetadata(handle, fixture.file);
        },
      );
      addTearDown(() async {
        cloud.dispose();
        await cloud.whenSettled;
      });
      final pending = cloud.loadCloudReadingProgress(
        'jm',
        'comic',
        taskOrigin: const SourceTaskOrigin(
          ownerId: 'cloud',
          groupId: 'read',
          requestSequence: 1,
        ),
      );
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await entered.future;
      final receipt = await fixture.host.tasks.cancelOwner(
        'cloud',
        SourceTaskStopReason.user,
      );
      await stopped;
      await receipt.whenSettled;
      await aborted.future;
      expect(candidate!.isDisposed, isTrue);
      expect(owner.runtime.engine, same(main));
      expect(owner.runtime.sourceMeta!.version, '1.0.0');
      expect(await main.evaluate('16'), 16);
    },
  );

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

  for (final disposing in [false, true]) {
    test(
      disposing
          ? 'failed candidate cannot republish resources after handle disposal'
          : 'failed candidate preserves live metadata updates from the old engine',
      () async {
        final fixture = await _createRuntimeFixture();
        final handle = fixture.host.activeHandle;
        final oldEngine = handle.runtime.engine!;
        final entered = Completer<void>();
        final release = Completer<void>();
        handle.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (request, handler) async {
              entered.complete();
              await release.future;
              handler.resolve(
                Response(requestOptions: request, statusCode: 200, data: 'ok'),
              );
            },
          ),
        );
        await fixture.file.writeAsString(
          _runtimeScript(
            '2.0.0',
            init:
                '''await sendMessage({method:'http',url:'https://test.example/init'});
            throw new Error('candidate failed');''',
          ),
        );
        final assertion = expectLater(
          fixture.loader.loadMetadata(handle, fixture.file),
          throwsA(anything),
        );
        await entered.future;
        expect(handle.runtime.engine, same(oldEngine));
        await oldEngine.evaluate(
          '__hazuki_source.translation.message="live update";null;',
        );
        final liveMeta = handle.runtime.sourceMeta;
        if (disposing) handle.requestDispose();
        release.complete();
        await assertion;
        if (disposing) {
          await handle.whenDisposed;
          expect(handle.runtime.engine, isNull);
          expect(handle.runtime.sourceMeta, isNull);
        } else {
          expect(handle.runtime.engine, same(oldEngine));
          expect(handle.runtime.sourceMeta, same(liveMeta));
          expect(
            handle.runtime.sourceMeta!.translation['message'],
            'live update',
          );
          expect(await oldEngine.evaluate('40+2'), 42);
        }
      },
    );
  }

  test(
    'publishing a candidate retains an admitted operation on the old engine',
    () async {
      final fixture = await _createRuntimeFixture();
      final handle = fixture.host.activeHandle;
      final oldEngine = handle.runtime.engine!;
      final entered = Completer<void>();
      final resume = Completer<void>();
      final reading = handle.runOperation(() async {
        entered.complete();
        await resume.future;
        return oldEngine.evaluate('__hazuki_source.version');
      });
      await entered.future;
      await fixture.file.writeAsString(_runtimeScript('2.0.0'));
      await fixture.loader.loadMetadata(handle, fixture.file);
      expect(handle.runtime.engine, isNot(same(oldEngine)));
      expect(handle.runtime.sourceMeta!.version, '2.0.0');
      resume.complete();
      expect(await reading, '1.0.0');
      await oldEngine.whenClosed;
      expect(oldEngine.shutdownDiagnostics['nativeRuntimes'], 0);
      expect(handle.runtime.sourceMeta!.version, '2.0.0');
    },
  );

  for (final pending in [
    "sendMessage({method:'delay',time:60000})",
    'new Promise(()=>{})',
  ]) {
    test(
      'login cancellation closes an unpublished candidate awaiting $pending',
      () async {
        final fixture = await _createRuntimeFixture();
        final owner = fixture.host.activeHandle;
        final oldEngine = owner.runtime.engine!;
        final entered = Completer<void>();
        late SourceRuntimeHandle attempt;
        late Future<void> loading;
        final login = SourceInteractiveLoginOperations(
          host: fixture.host,
          loadRuntime: (handle) {
            attempt = handle;
            handle.dio.interceptors.add(
              InterceptorsWrapper(
                onRequest: (request, handler) {
                  entered.complete();
                  handler.resolve(
                    Response(
                      requestOptions: request,
                      statusCode: 200,
                      data: 'ok',
                    ),
                  );
                },
              ),
            );
            loading = fixture.loader
                .loadMetadata(handle, fixture.file)
                .then<void>((_) {});
            return loading;
          },
        );
        await fixture.file.writeAsString(
          _runtimeScript(
            '2.0.0',
            init:
                '''
        const pending = $pending;
        await sendMessage({method:'http',url:'https://test.example/init'});
        await pending;
      ''',
          ),
        );
        final cancellation = SourceLoginCancellation();
        final result = login.loginInteractive(
          account: 'account',
          password: 'password',
          method: 'sms',
          present: (_, _) async => null,
          cancellation: cancellation,
        );
        final assertion = expectLater(
          result.timeout(const Duration(seconds: 2)),
          throwsA(isA<SourceLoginCancelled>()),
        );
        await entered.future;
        expect(attempt.runtime.engine, isNull);
        cancellation.cancel();
        await assertion;
        await expectLater(loading, throwsA(anything));
        expect(attempt.isDisposed, isTrue);
        expect(owner.runtime.engine, same(oldEngine));
        expect(await oldEngine.evaluate('40+2'), 42);

        // The previous attempt must release the per-source login lock.
        await fixture.file.writeAsString(_runtimeScript('2.0.0'));
        await expectLater(
          login.loginInteractive(
            account: 'account',
            password: 'password',
            method: 'sms',
            present: (_, _) async => null,
            cancellation: SourceLoginCancellation(),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'login_method_unavailable',
            ),
          ),
        );
      },
    );
  }
}

String _runtimeScript(String version, {String init = ''}) =>
    '''
Hazuki.registerSource({id:'jm',name:'Test',version:'$version',
  translation:{message:'old'},init:async()=>{$init},
  search:{load:async()=>({comics:[]})},
  comic:{loadInfo:async()=>({}),loadEp:async()=>({images:[]})}});
''';

Future<({SourceRuntimeHost host, SourceRuntimeLoader loader, File file})>
_createRuntimeFixture() async {
  SharedPreferences.setMockInitialValues({});
  final root = await Directory.systemTemp.createTemp('hazuki_candidate_test_');
  final file = File('${root.path}/main.js');
  await file.writeAsString(_runtimeScript('1.0.0'));
  final host = SourceRuntimeHost(
    catalog: const [
      SourceCatalogEntry(key: 'jm', name: 'Test', fileName: 'main.js'),
    ],
    defaultSourceKey: 'jm',
    secureSessionStorage: MemorySourceSecureSessionStorage(),
    ensureSourceInitialized: (_) async {},
    currentAccountForSource: (_) => null,
    isLoggedForSource: (_) => false,
  );
  final handle = host.activeHandle;
  addTearDown(() async {
    handle.requestDispose();
    await handle.whenDisposed;
    host.dispose();
    await root.delete(recursive: true);
  });
  await handle.session.ensurePrefs();
  final downloader = _RejectingDownloader();
  final loader = SourceRuntimeLoader(
    scriptStore: _LoaderScriptStore(file),
    catalogResolver: SourceCatalogResolver(
      runtimeHost: host,
      downloader: downloader,
      sourceIndexUrls: const [],
    ),
    downloader: downloader,
    jsBridge: SourceJsBridgeCookieCapability(activeHandle: () => handle),
    runtimeStateController: SourceRuntimeStateController(),
    bundledInitAssetPath: 'assets/init.js',
    loadAssetText: (path) => File(path).readAsString(),
  );
  await loader.loadMetadata(handle, file);
  return (host: host, loader: loader, file: file);
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

class _CloudOperations extends Fake implements SourceRuntimeOperations {
  @override
  Future<void> ensureSourceInitialized(String key) async {}
}
