import 'dart:async';
import 'dart:io';
import 'package:hazuki/models/source_meta.dart';
import 'package:hazuki/services/source/comic/comic_details_capability.dart';
import 'package:hazuki/services/source/comic/source_comic_details_cache.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/runtime/source_operation_runner.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/image/source_image_preparation_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Http implements HttpClientAdapter {
  final pending = <String, List<Completer<ResponseBody>>>{};
  final aborted = <String>[];
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    final key = options.uri.pathSegments.last;
    final result = Completer<ResponseBody>();
    (pending[key] ??= []).add(result);
    cancelFuture?.then((_) => aborted.add(key));
    return result.future;
  }

  void complete(String key, [int index = 0]) =>
      pending[key]![index].complete(ResponseBody.fromBytes([1, 2, 3], 200));
  @override
  void close({bool force = false}) {}
}

class _Storage extends MemorySourceSecureSessionStorage {
  Future<void> Function()? beforeCookieWrite;
  @override
  Future<void> write(String key, String value) async {
    if (key == SourceSecureSessionStorageKeys.cookies('one')) {
      await beforeCookieWrite?.call();
    }
    await super.write(key, value);
  }
}

Future<void> _until(bool Function() predicate) async {
  final clock = Stopwatch()..start();
  while (!predicate() && clock.elapsed < const Duration(seconds: 3)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(predicate(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceScriptEngine engine;
  late _Http http;
  late _Storage storage;
  late Future<void> Function() initialize;
  SourceTaskOrigin origin(String owner, {SourceReaderSession? session}) =>
      SourceTaskOrigin(
        ownerId: owner,
        groupId: 'group',
        requestSequence: 1,
        readerSession: session,
      );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    initialize = () async {};
    storage = _Storage();
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(
          key: 'one',
          name: 'One',
          fileName: 'one.js',
          pluginVersion: '1',
        ),
        SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
      ],
      defaultSourceKey: 'one',
      secureSessionStorage: storage,
      ensureSourceInitialized: (_) => initialize(),
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    addTearDown(host.dispose);
    final handle = host.activeHandle;
    await handle.facade.ensurePrefs();
    final directory = await Directory.systemTemp.createTemp(
      'hazuki-image-tasks-',
    );
    handle.cache.imageCacheDir = directory;
    addTearDown(() => directory.delete(recursive: true));
    engine = SourceScriptEngine(pluginId: 'one');
    addTearDown(engine.close);
    handle.runtime.engine = engine;
    engine.operationGuard = handle.runOperation;
    await engine.execute(
      'globalThis.__hazuki_source={comic:{onImageLoad:()=>({})}}',
    );
    http = _Http();
    handle.dio.httpClientAdapter = http;
    handle.httpGateway.configureCookieBridge();
  });

  test(
    'reader and download leases independently retain an idle source',
    () async {
      final old = host.activeHandle;
      final reader = host.acquireReaderSession('one');
      final download = host.acquireDownloadSession('one');
      await host.activateSource('two');
      reader.close();
      expect(host.handleFor('one'), same(old));
      final pending = old.imageCache.downloadImageBytes(
        'https://fixture.test/leasedDownload',
        useDiskCache: false,
        taskOrigin: SourceTaskOrigin(
          ownerId: 'download',
          groupId: 'run',
          requestSequence: 1,
          downloadSession: download,
        ),
      );
      await _until(() => http.pending.containsKey('leasedDownload'));
      http.complete('leasedDownload');
      expect(await pending, [1, 2, 3]);
      download.close();
      await old.whenDisposed;
      expect(host.existingHandles.map((entry) => entry.sourceKey), ['two']);
    },
  );

  test('paused download releases only its own shared HTTP consumer', () async {
    final handle = host.activeHandle;
    final session = host.acquireDownloadSession('one');
    final signal = SourceTaskCancellation();
    final download = handle.imageCache.downloadImageBytes(
      'https://fixture.test/downloadShared',
      useDiskCache: false,
      taskOrigin: SourceTaskOrigin(
        ownerId: 'download',
        groupId: 'run',
        requestSequence: 1,
        cancellation: signal,
        downloadSession: session,
      ),
    );
    final stopped = expectLater(download, throwsA(isA<SourceTaskCancelled>()));
    await _until(() => http.pending.containsKey('downloadShared'));
    final reading = handle.imageCache.downloadImageBytes(
      'https://fixture.test/downloadShared',
      useDiskCache: false,
      taskOrigin: origin('reading'),
    );
    await _until(
      () =>
          handle
              .cache
              .imageDownloadInFlight
              .values
              .single
              .consumerMetadata
              .length ==
          2,
    );
    signal.cancel(SourceTaskStopReason.downloadPaused);
    final receipt = await host.tasks.cancelGroup(
      ownerId: 'download',
      groupId: 'run',
      reason: SourceTaskStopReason.downloadPaused,
    );
    await stopped;
    await receipt.whenSettled;
    expect(http.aborted, isEmpty);
    http.complete('downloadShared');
    expect(await reading, [1, 2, 3]);
    session.close();
  });

  test(
    'catalog replacement revokes download lease before admitting new instance',
    () async {
      final old = host.activeHandle;
      final session = host.acquireDownloadSession('one');
      await host.activateSource('two');
      await host.replaceCatalog(const [
        SourceCatalogEntry(
          key: 'one',
          name: 'One',
          fileName: 'one.js',
          pluginVersion: '2',
        ),
        SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
      ]);
      expect(session.cancellation.reason, SourceTaskStopReason.pluginUpdated);
      final replacement = host.handleFor('one');
      final next = host.acquireDownloadSession('one');
      session.close();
      expect(host.handleFor('one'), same(replacement));
      expect(
        () => runSourceOperation(
          host,
          replacement,
          'fixture.download',
          (_) async => 1,
          origin: SourceTaskOrigin(
            ownerId: 'old',
            groupId: 'run',
            requestSequence: 1,
            downloadSession: session,
          ),
        ),
        throwsA(isA<SourceTaskCancelled>()),
      );
      expect(
        await runSourceOperation(
          host,
          replacement,
          'fixture.new',
          (_) async => 2,
          origin: SourceTaskOrigin(
            ownerId: 'new',
            groupId: 'run',
            requestSequence: 1,
            downloadSession: next,
          ),
        ),
        2,
      );
      next.close();
      await old.whenDisposed;
    },
  );

  test(
    'one detached reader retains unowned download and cache intent',
    () async {
      final handle = host.activeHandle;
      final first = handle.imageCache.downloadImageBytes(
        'https://fixture.test/shared',
        useDiskCache: false,
        keepInMemory: true,
        taskOrigin: origin('reader'),
      );
      final cancelled = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => http.pending.containsKey('shared'));
      final download = handle.imageCache.downloadImageBytes(
        'https://fixture.test/shared',
        useDiskCache: false,
        keepInMemory: false,
      );
      await Future<void>.delayed(Duration.zero);
      final receipt = await host.tasks.cancelOwner(
        'reader',
        SourceTaskStopReason.ownerDisposed,
      );
      await cancelled;
      await receipt.whenSettled;
      expect(receipt.sharedResourceCount, 1);
      expect(http.aborted, isEmpty);
      http.complete('shared');
      expect(await download, [1, 2, 3]);
      expect(
        handle.imageCache.peekFromMemory('https://fixture.test/shared'),
        isNull,
      );
      expect(http.pending['shared'], hasLength(1));
      expect(host.activeHandle.runtime.engine!.runtimeId, engine.runtimeId);
    },
  );

  test(
    'last subscription aborts and late old completion keeps new request',
    () async {
      final cache = host.activeHandle.imageCache;
      final first = cache.downloadImageBytes(
        'https://fixture.test/image',
        useDiskCache: false,
        taskOrigin: origin('old'),
      );
      final failed = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => http.pending.containsKey('image'));
      final receipt = await host.tasks.cancelOwner(
        'old',
        SourceTaskStopReason.superseded,
      );
      await failed;
      await receipt.whenSettled;
      expect(http.aborted, ['image']);
      final next = cache.downloadImageBytes(
        'https://fixture.test/image',
        useDiskCache: false,
        taskOrigin: origin('new'),
      );
      await _until(() => http.pending['image']!.length == 2);
      http.complete('image');
      await Future<void>.delayed(Duration.zero);
      expect(host.activeHandle.cache.imageDownloadInFlight, hasLength(1));
      http.complete('image', 1);
      expect(await next, [1, 2, 3]);
      expect(cache.peekFromMemory('https://fixture.test/image'), [1, 2, 3]);
    },
  );

  test('shared active cache intents include later disk subscriber', () async {
    final cache = host.activeHandle.imageCache;
    final first = cache.downloadImageBytes(
      'https://fixture.test/cache',
      useDiskCache: false,
      keepInMemory: false,
    );
    await _until(() => http.pending.containsKey('cache'));
    final second = cache.downloadImageBytes(
      'https://fixture.test/cache',
      keepInMemory: true,
    );
    await _until(() => host.tasks.activeTasks.length == 2);
    // Disk lookup must finish and attach before the response arrives.
    await _until(
      () =>
          host
              .activeHandle
              .cache
              .imageDownloadInFlight
              .values
              .first
              .consumerMetadata
              .length ==
          2,
    );
    http.complete('cache');
    await Future.wait([first, second]);
    expect(cache.peekFromMemory('https://fixture.test/cache'), [1, 2, 3]);
    cache.evictFromMemory(['https://fixture.test/cache']);
    expect(await cache.downloadImageBytes('https://fixture.test/cache'), [
      1,
      2,
      3,
    ]);
    expect(http.pending['cache'], hasLength(1));
  });

  test(
    'reading lease survives source change across idle then retires',
    () async {
      final handle = host.activeHandle;
      final session = host.acquireReaderSession('one');
      await host.activateSource('two');
      expect(host.handleFor('one'), same(handle));
      expect(handle.isDisposalRequested, isFalse);
      expect(
        await runSourceOperation(
          host,
          handle,
          'reader.fixture',
          (context) => context.evaluate(engine, '40+2'),
          origin: origin('reader', session: session),
        ),
        42,
      );
      session.close();
      await handle.whenDisposed;
      expect(handle.isDisposed, isTrue);
    },
  );

  test(
    'version replacement revokes old session without targeting new handle',
    () async {
      final old = host.activeHandle;
      final session = host.acquireReaderSession('one');
      final pending = old.imageCache.downloadImageBytes(
        'https://fixture.test/version',
        useDiskCache: false,
        taskOrigin: origin('reader', session: session),
      );
      final failed = expectLater(
        pending,
        throwsA(
          isA<SourceTaskCancelled>().having(
            (error) => error.reason,
            'reason',
            SourceTaskStopReason.pluginUpdated,
          ),
        ),
      );
      await _until(() => http.pending.containsKey('version'));
      await host.replaceCatalog(const [
        SourceCatalogEntry(
          key: 'one',
          name: 'One',
          fileName: 'one.js',
          pluginVersion: '2',
        ),
        SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
      ]);
      await failed;
      expect(http.aborted, ['version']);
      expect(session.checkActive, throwsA(isA<SourceTaskCancelled>()));
      final current = host.handleFor('one');
      expect(current, isNot(same(old)));
      await host.tasks.cancelOwner(
        'reader',
        SourceTaskStopReason.ownerDisposed,
      );
      expect(current.isDisposalRequested, isFalse);
    },
  );
  test(
    'cancel during shared initialization prevents the hook and GET',
    () async {
      final gate = Completer<void>();
      initialize = () => gate.future;
      final pending = host.activeHandle.imageCache.downloadImageBytes(
        'https://fixture.test/init',
        useDiskCache: false,
        taskOrigin: origin('init'),
      );
      final failed = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await Future<void>.delayed(Duration.zero);
      final receipt = await host.tasks.cancelOwner(
        'init',
        SourceTaskStopReason.ownerDisposed,
      );
      await failed;
      await receipt.whenSettled;
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(http.pending, isEmpty);
    },
  );

  test(
    'cancel queued image does not invoke source hook or occupy slot',
    () async {
      await engine.execute(
        'globalThis.hooks=[];this.__hazuki_source.comic.onImageLoad=url=>{hooks.push(url);return {}}',
      );
      final cache = host.activeHandle.imageCache;
      final active = [
        for (var i = 0; i < 4; i++)
          cache.downloadImageBytes(
            'https://fixture.test/active$i',
            useDiskCache: false,
          ),
      ];
      await _until(() => http.pending.length == 4);
      final queued = cache.downloadImageBytes(
        'https://fixture.test/queued',
        useDiskCache: false,
        taskOrigin: origin('queued'),
      );
      final rejected = expectLater(queued, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => host.tasks.activeTasks.length == 5);
      final receipt = await host.tasks.cancelOwner(
        'queued',
        SourceTaskStopReason.superseded,
      );
      await rejected;
      await receipt.whenSettled;
      expect(
        await engine.evaluate('hooks.some(url=>url.endsWith("queued"))'),
        isFalse,
      );
      final last = cache.downloadImageBytes(
        'https://fixture.test/last',
        useDiskCache: false,
      );
      http.complete('active0');
      await _until(() => http.pending.containsKey('last'));
      for (var i = 1; i < 4; i++) {
        http.complete('active$i');
      }
      http.complete('last');
      await Future.wait([...active, last]);
      expect(http.pending.containsKey('queued'), isFalse);
    },
  );

  test('image hook synchronous cancellation never falls back to a GET', () async {
    final entered = Completer<void>();
    engine.setOperationMessageHandler((_, context) {
      entered.complete();
      return null;
    });
    await engine.execute(
      'this.__hazuki_source.comic.onImageLoad=()=>{sendMessage({});while(true){}}',
    );
    final pending = host.activeHandle.imageCache.downloadImageBytes(
      'https://fixture.test/spin',
      useDiskCache: false,
      taskOrigin: origin('spin'),
    );
    final failed = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
    await entered.future;
    final receipt = await host.tasks.cancelOwner(
      'spin',
      SourceTaskStopReason.user,
    );
    await failed;
    await receipt.whenSettled;
    expect(http.pending, isEmpty);
    expect(await engine.evaluate('1+1'), 2);
  });

  test(
    'reader image hook survives active source switching in flight',
    () async {
      final handle = host.activeHandle;
      final session = host.acquireReaderSession('one');
      final ui = SourceUiOwner();
      addTearDown(ui.dispose);
      final pending = ui.run(
        () => handle.imageCache.downloadImageBytes(
          'https://fixture.test/pinned',
          useDiskCache: false,
          taskOrigin: origin('reader', session: session),
        ),
      );
      await _until(() => http.pending.containsKey('pinned'));
      await host.activateSource('two');
      expect(http.aborted, isEmpty);
      http.complete('pinned');
      expect(await pending, [1, 2, 3]);
      expect(host.handleFor('one'), same(handle));
      session.close();
    },
  );

  test(
    'stopped disk-cache subscriber does not leave its cache intent',
    () async {
      final handle = host.activeHandle;
      final cache = handle.imageCache;
      final disk = cache.downloadImageBytes(
        'https://fixture.test/intent',
        keepInMemory: false,
        taskOrigin: origin('disk'),
      );
      final failed = expectLater(disk, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => http.pending.containsKey('intent'));
      final other = cache.downloadImageBytes(
        'https://fixture.test/intent',
        keepInMemory: false,
        useDiskCache: false,
      );
      await _until(
        () =>
            handle
                .cache
                .imageDownloadInFlight
                .values
                .first
                .consumerMetadata
                .length ==
            2,
      );
      final receipt = await host.tasks.cancelOwner(
        'disk',
        SourceTaskStopReason.ownerDisposed,
      );
      await failed;
      await receipt.whenSettled;
      http.complete('intent');
      await other;
      expect(await handle.cache.imageCacheDir!.list().toList(), isEmpty);
    },
  );

  test(
    'cancel preparation task stops transform without affecting its engine',
    () async {
      final entered = Completer<void>();
      engine.setOperationMessageHandler((_, context) {
        entered.complete();
        return null;
      });
      await engine.execute(
        'this.__hazuki_source.comic.transformImageBytes=()=>{sendMessage({});while(true){}}',
      );
      final preparation = SourceImagePreparationCapability(
        runtimeHost: host,
        downloadImageBytes:
            (
              url, {
              comicId,
              epId,
              keepInMemory = true,
              useDiskCache = true,
              priority = false,
              sourceKey = '',
              taskOrigin,
            }) async => Uint8List.fromList([1]),
      );
      final pending = preparation.prepareChapterImageData(
        'https://fixture.test/transform',
        comicId: 'comic',
        epId: 'ep',
        taskOrigin: origin('transform'),
      );
      final failed = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await entered.future;
      final task = host.tasks.activeTasks.single;
      final receipt = await host.tasks.cancelTask(
        task.taskId,
        SourceTaskStopReason.user,
      );
      await failed;
      await receipt.whenSettled;
      expect(await engine.evaluate('2+3'), 5);
    },
  );

  test('last subscriber waits for an already admitted cookie commit', () async {
    final entered = Completer<void>();
    final gate = Completer<void>();
    storage.beforeCookieWrite = () {
      entered.complete();
      return gate.future;
    };
    final cache = host.activeHandle.imageCache;
    final pending = cache.downloadImageBytes(
      'https://fixture.test/cookie',
      useDiskCache: false,
      taskOrigin: origin('cookie'),
    );
    final failed = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
    await _until(() => http.pending.containsKey('cookie'));
    http.pending['cookie']!.single.complete(
      ResponseBody.fromBytes(
        [1, 2, 3],
        200,
        headers: {
          'set-cookie': ['sid=accepted; Path=/'],
        },
      ),
    );
    await entered.future;
    final receipt = await host.tasks.cancelOwner(
      'cookie',
      SourceTaskStopReason.ownerDisposed,
    );
    await failed;
    var settled = false;
    receipt.whenSettled.then((_) => settled = true);
    await Future<void>.delayed(Duration.zero);
    expect(settled, isFalse);
    gate.complete();
    await receipt.whenSettled;
    expect(cache.peekFromMemory('https://fixture.test/cookie'), isNull);
  });

  test(
    'closing last inactive reader preserves an admitted unowned hook',
    () async {
      final entered = Completer<void>();
      final gate = Completer<void>();
      engine.setOperationMessageHandler((_, context) {
        entered.complete();
        return gate.future;
      });
      await engine.execute(
        'this.__hazuki_source.comic.onImageLoad=()=>sendMessage({}).then(()=>({}))',
      );
      final handle = host.activeHandle;
      final session = host.acquireReaderSession('one');
      final reading = handle.imageCache.downloadImageBytes(
        'https://fixture.test/independent',
        useDiskCache: false,
        taskOrigin: origin('reader', session: session),
      );
      final failed = expectLater(reading, throwsA(isA<SourceTaskCancelled>()));
      await entered.future;
      final download = handle.imageCache.downloadImageBytes(
        'https://fixture.test/independent',
        useDiskCache: false,
      );
      await _until(
        () =>
            handle
                .cache
                .imageDownloadInFlight
                .values
                .single
                .consumerMetadata
                .length ==
            2,
      );
      await host.activateSource('two');
      session.close();
      await failed;
      gate.complete();
      await _until(() => http.pending.containsKey('independent'));
      http.complete('independent');
      expect(await download, [1, 2, 3]);
      await handle.whenDisposed;
    },
  );
  SourceComicDetailsCapability details() => SourceComicDetailsCapability(
    runtimeHost: host,
    cache: SourceComicDetailsCache(runtimeHost: host),
    reloginCoordinator: SourceReloginCoordinator(
      loginWithStoredAccount:
          (_, {required account, required password}) async {},
    ),
    translateSourceText: (text, {sourceKey = ''}) => text,
  );

  test(
    'chapter requests retain UI owner and handle across a source change',
    () async {
      final handle = host.activeHandle;
      final session = host.acquireReaderSession('one');
      final gate = Completer<void>();
      final entered = Completer<void>();
      engine.setOperationMessageHandler((_, context) {
        if (!entered.isCompleted) entered.complete();
        return gate.future;
      });
      await engine.execute(
        'this.__hazuki_source.comic.loadEp=()=>sendMessage({}).then(()=>({images:["page"]}))',
      );
      final ui = SourceUiOwner();
      addTearDown(ui.dispose);
      final capability = details();
      final pending = ui.run(
        () => capability.loadChapterImages(
          comicId: 'comic',
          epId: 'ep',
          sourceKey: 'one',
          taskOrigin: origin('reader', session: session),
        ),
      );
      await entered.future;
      await host.activateSource('two');
      gate.complete();
      expect(await pending, ['page']);
      expect(
        await capability.loadChapterImages(
          comicId: 'comic',
          epId: 'next',
          sourceKey: 'one',
          taskOrigin: origin('reader', session: session),
        ),
        ['page'],
      );
      expect(host.handleFor('one'), same(handle));
      session.close();
    },
  );

  test(
    'ordinary plugin-requested chapter recovery gets a fresh attempt scope',
    () async {
      final old = host.activeHandle;
      old.runtime.sourceMeta = const SourceMeta(
        name: 'One',
        key: 'one',
        version: '1',
        supportsAccount: false,
        settingsDefaults: {},
        presentation: {
          'recreateOnStatus': [403],
        },
      );
      final session = host.acquireReaderSession('one');
      engine.setOperationMessageHandler(
        (message, context) => old.httpGateway.sendJsHttpRequest(
          Map<String, dynamic>.from(message as Map),
          hostContext: context,
          execution: context.execution,
          runtimeId: context.runtimeId,
        ),
      );
      await engine.execute(
        'this.__hazuki_source.comic.loadEp=()=>sendMessage({method:"http",http_method:"GET",url:"https://fixture.test/recover"}).then(()=>({images:["old"]}))',
      );
      initialize = () async {
        final handle = host.handleFor('one');
        if (handle.runtime.engine == null) {
          final replacement = SourceScriptEngine(pluginId: 'one');
          addTearDown(replacement.close);
          replacement.operationGuard = handle.runOperation;
          handle.runtime.engine = replacement;
          await replacement.execute(
            'globalThis.__hazuki_source={comic:{loadEp:()=>({images:["new"]})}}',
          );
        }
      };
      final ui = SourceUiOwner();
      addTearDown(ui.dispose);
      final pending = ui.run(
        () => details().loadChapterImages(
          comicId: 'comic',
          epId: 'ep',
          sourceKey: 'one',
          taskOrigin: origin('reader', session: session),
        ),
      );
      await _until(() => http.pending.containsKey('recover'));
      http.pending['recover']!.single.complete(
        ResponseBody.fromString('{}', 403),
      );
      expect(await pending, ['new']);
      expect(host.handleFor('one'), isNot(same(old)));
      session.close();
    },
  );

  test(
    'download chapter recovery transfers its lease to the explicit replacement',
    () async {
      final old = host.activeHandle;
      old.runtime.sourceMeta = const SourceMeta(
        name: 'One',
        key: 'one',
        version: '1',
        supportsAccount: false,
        settingsDefaults: {},
        presentation: {
          'recreateOnStatus': [403],
        },
      );
      final session = host.acquireDownloadSession('one');
      engine.setOperationMessageHandler(
        (message, context) => old.httpGateway.sendJsHttpRequest(
          Map<String, dynamic>.from(message as Map),
          hostContext: context,
          execution: context.execution,
          runtimeId: context.runtimeId,
        ),
      );
      await engine.execute(
        'this.__hazuki_source.comic.loadEp=()=>sendMessage({method:"http",http_method:"GET",url:"https://fixture.test/recover"}).then(()=>({images:["old"]}))',
      );
      initialize = () async {
        final handle = host.handleFor('one');
        if (handle.runtime.engine == null) {
          final replacement = SourceScriptEngine(pluginId: 'one');
          addTearDown(replacement.close);
          replacement.operationGuard = handle.runOperation;
          handle.runtime.engine = replacement;
          await replacement.execute(
            'globalThis.__hazuki_source={comic:{loadEp:()=>({images:["new"]})}}',
          );
        }
      };
      final ui = SourceUiOwner();
      addTearDown(ui.dispose);
      final pending = ui.run(
        () => details().loadChapterImages(
          comicId: 'comic',
          epId: 'ep',
          sourceKey: 'one',
          taskOrigin: SourceTaskOrigin(
            ownerId: 'download',
            groupId: 'run',
            requestSequence: 1,
            downloadSession: session,
          ),
        ),
      );
      await _until(() => http.pending.containsKey('recover'));
      http.pending['recover']!.single.complete(
        ResponseBody.fromString('{}', 403),
      );
      expect(await pending, ['new']);
      expect(host.handleFor('one'), isNot(same(old)));
      expect(
        await details().loadChapterImages(
          comicId: 'comic',
          epId: 'next',
          sourceKey: 'one',
          taskOrigin: SourceTaskOrigin(
            ownerId: 'download',
            groupId: 'next',
            requestSequence: 2,
            downloadSession: session,
          ),
        ),
        ['new'],
      );
      session.close();
    },
  );

  test(
    'download preparation keeps its source and child subscription across switching',
    () async {
      final handle = host.activeHandle;
      final session = host.acquireDownloadSession('one');
      final prepare = SourceImagePreparationCapability(
        runtimeHost: host,
        downloadImageBytes: handle.imageCache.downloadImageBytes,
      );
      final pending = prepare.prepareChapterImageData(
        'https://fixture.test/downloadPrepare',
        comicId: 'comic',
        epId: 'ep',
        sourceKey: 'one',
        useDiskCache: false,
        taskOrigin: SourceTaskOrigin(
          ownerId: 'download',
          groupId: 'run',
          requestSequence: 1,
          downloadSession: session,
        ),
      );
      await _until(() => http.pending.containsKey('downloadPrepare'));
      await host.activateSource('two');
      http.complete('downloadPrepare');
      expect((await pending).bytes, [1, 2, 3]);
      expect(host.handleFor('one'), same(handle));
      session.close();
      await handle.whenDisposed;
    },
  );

  test('chapter cancellation bypasses a requested runtime recovery', () async {
    final old = host.activeHandle;
    old.runtime.sourceMeta = const SourceMeta(
      name: 'One',
      key: 'one',
      version: '1',
      supportsAccount: false,
      settingsDefaults: {},
      presentation: {
        'recreateOnStatus': [403],
      },
    );
    final entered = Completer<void>();
    engine.setOperationMessageHandler((message, context) {
      final value = Map<String, dynamic>.from(message as Map);
      if (value['entered'] == true) {
        entered.complete();
        return null;
      }
      return old.httpGateway.sendJsHttpRequest(
        value,
        hostContext: context,
        execution: context.execution,
        runtimeId: context.runtimeId,
      );
    });
    await engine.execute(
      'this.__hazuki_source.comic.loadEp=async()=>{await sendMessage({method:"http",http_method:"GET",url:"https://fixture.test/stoppedRecovery"});await sendMessage({entered:true});while(true){}}',
    );
    final pending = details().loadChapterImages(
      comicId: 'comic',
      epId: 'ep',
      taskOrigin: origin('chapter'),
    );
    final failed = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
    await _until(() => http.pending.containsKey('stoppedRecovery'));
    http.pending['stoppedRecovery']!.single.complete(
      ResponseBody.fromString('{}', 403),
    );
    await entered.future;
    expect(old.recreationRequested, isTrue);
    final receipt = await host.tasks.cancelOwner(
      'chapter',
      SourceTaskStopReason.user,
    );
    await failed;
    await receipt.whenSettled;
    expect(host.activeHandle, same(old));
    expect(await engine.evaluate('1'), 1);
  });

  test('cancel preparation releases only its child subscription', () async {
    final handle = host.activeHandle;
    final preparation = SourceImagePreparationCapability(
      runtimeHost: host,
      downloadImageBytes: handle.imageCache.downloadImageBytes,
    );
    final pending = preparation.prepareChapterImageData(
      'https://fixture.test/child',
      comicId: 'comic',
      epId: 'ep',
      useDiskCache: false,
      taskOrigin: origin('prepare'),
    );
    final failed = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
    await _until(() => http.pending.containsKey('child'));
    final download = handle.imageCache.downloadImageBytes(
      'https://fixture.test/child',
      useDiskCache: false,
    );
    await _until(
      () =>
          handle
              .cache
              .imageDownloadInFlight
              .values
              .single
              .consumerMetadata
              .length ==
          2,
    );
    final parent = host.tasks.activeTasks.firstWhere(
      (task) => task.method == 'reader.prepareImage',
    );
    final receipt = await host.tasks.cancelTask(
      parent.taskId,
      SourceTaskStopReason.ownerDisposed,
    );
    await failed;
    await receipt.whenSettled;
    expect(http.aborted, isEmpty);
    expect(receipt.sharedResourceCount, 1);
    http.complete('child');
    expect(await download, [1, 2, 3]);
  });
  test(
    'disabling inactive pinned source stops its tasks before disposal',
    () async {
      final old = host.activeHandle;
      final session = host.acquireReaderSession('one');
      await host.activateSource('two');
      final pending = old.imageCache.downloadImageBytes(
        'https://fixture.test/disabled',
        useDiskCache: false,
        taskOrigin: origin('inactive', session: session),
      );
      final failed = expectLater(
        pending,
        throwsA(
          isA<SourceTaskCancelled>().having(
            (error) => error.reason,
            'reason',
            SourceTaskStopReason.pluginDisabled,
          ),
        ),
      );
      await _until(() => http.pending.containsKey('disabled'));
      await host.replaceCatalog(const [
        SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
      ]);
      await failed;
      await old.whenDisposed;
      expect(http.aborted, ['disabled']);
      final preparation = SourceImagePreparationCapability(
        runtimeHost: host,
        downloadImageBytes: old.imageCache.downloadImageBytes,
      );
      await expectLater(
        preparation.prepareChapterImageData(
          'https://fixture.test/disabled',
          comicId: 'comic',
          epId: 'ep',
          sourceKey: 'one',
          taskOrigin: origin('inactive', session: session),
        ),
        throwsA(isA<SourceTaskCancelled>()),
      );
      expect(host.existingHandles.map((handle) => handle.sourceKey), ['two']);
    },
  );
  test(
    'catalog retirement refuses reentrant leases and late old-handle calls',
    () async {
      final old = host.activeHandle;
      host.acquireReaderSession('one');
      Object? leaseError;
      Object? downloadLeaseError;
      Future<void>? lateRejected;
      final pending = host.tasks.run<void>(
        pluginId: 'one',
        method: 'fixture.retire',
        origin: origin('retire'),
        observe: (task, event, disposition, error, stack) {
          if (task.state != SourceTaskState.cancelRequested) return;
          try {
            host.acquireReaderSession('one');
          } catch (error) {
            leaseError = error;
          }
          try {
            host.acquireDownloadSession('one');
          } catch (error) {
            downloadLeaseError = error;
          }
          lateRejected = expectLater(
            old.imageCache.downloadImageBytes(
              'https://fixture.test/retired',
              useDiskCache: false,
            ),
            throwsA(isA<SourceTaskCancelled>()),
          );
        },
        operation: (task) {
          task.bindResource(old);
          return Completer<void>().future;
        },
      );
      final rejected = expectLater(
        pending,
        throwsA(isA<SourceTaskCancelled>()),
      );
      await host.replaceCatalog(const [
        SourceCatalogEntry(
          key: 'one',
          name: 'One',
          fileName: 'one.js',
          pluginVersion: '2',
        ),
        SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
      ]);
      await rejected;
      await lateRejected;
      expect(leaseError, isA<SourceTaskCancelled>());
      expect(downloadLeaseError, isA<SourceTaskCancelled>());
      expect(http.pending, isEmpty);
      expect(host.activeHandle, isNot(same(old)));
    },
  );
}
