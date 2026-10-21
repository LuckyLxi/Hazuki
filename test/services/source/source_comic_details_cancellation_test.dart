import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/account/source_relogin_coordinator.dart';
import 'package:hazuki/services/source/comic/comic_details_capability.dart';
import 'package:hazuki/services/source/comic/source_comic_details_cache.dart';
import 'package:hazuki/services/source/interaction/source_ui_scope.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/services/source/runtime/source_host_call_context.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StatusAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString('{}', 419);
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceComicDetailsCapability details;
  late SourceComicDetailsCache cache;
  late SourceScriptEngine engine;
  late List<Completer<Map<String, dynamic>>> responses;
  late List<SourceHostCallContext> contexts;
  late Future<void> Function() initialize;

  Future<void> waitForCalls(int count) async {
    final clock = Stopwatch()..start();
    while (contexts.length < count &&
        clock.elapsed < const Duration(seconds: 2)) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(contexts, hasLength(count));
  }

  SourceTaskOrigin origin(String owner) => SourceTaskOrigin(
    ownerId: owner,
    groupId: 'query',
    requestSequence: 1,
    cancellation: SourceTaskCancellation(),
  );
  Map<String, dynamic> result(String title) => {'id': '123', 'title': title};

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    initialize = () async {};
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(key: 'one', name: 'One', fileName: 'one.js'),
      ],
      defaultSourceKey: 'one',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) => initialize(),
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    addTearDown(host.dispose);
    cache = SourceComicDetailsCache(runtimeHost: host);
    details = SourceComicDetailsCapability(
      runtimeHost: host,
      cache: cache,
      reloginCoordinator: SourceReloginCoordinator(
        loginWithStoredAccount:
            (_, {required account, required password}) async {},
      ),
      translateSourceText: (text, {sourceKey = ''}) => text,
    );
    engine = SourceScriptEngine(pluginId: 'one');
    addTearDown(engine.close);
    final handle = host.handleFor('one');
    engine.operationGuard = handle.runOperation;
    handle.runtime.engine = engine;
    await engine.evaluate(
      'globalThis.__hazuki_source={comic:{loadInfo: id=>sendMessage({id})}}',
    );
    contexts = [];
    responses = [];
    engine.setOperationMessageHandler((_, context) {
      contexts.add(context);
      final response = Completer<Map<String, dynamic>>();
      responses.add(response);
      return response.future;
    });
  });

  test(
    'cancelling the first search subscriber preserves a detail-page consumer',
    () async {
      final first = details.loadComicDetails(
        '123',
        taskOrigin: origin('search'),
      );
      final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      final page = details.loadComicDetails('123');
      await waitForCalls(1);
      final receipt = await host.tasks.cancelOwner(
        'search',
        SourceTaskStopReason.ownerDisposed,
      );
      await stopped;
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      expect(receipt.sharedResourceCount, 1);
      expect(contexts.single.isStopped, isFalse);
      responses.single.complete(result('shared'));
      expect((await page).title, 'shared');
      expect(
        cache
            .get(
              const SourceScopedComicId(
                sourceKey: 'one',
                comicId: '123',
              ).storageKey,
            )
            ?.title,
        'shared',
      );
      expect(host.tasks.activeTasks, isEmpty);
    },
  );

  test(
    'the last subscriber waits for producer writes without blocking another search',
    () async {
      final first = details.loadComicDetails(
        '123',
        taskOrigin: origin('first'),
      );
      final second = details.loadComicDetails(
        '123',
        taskOrigin: origin('second'),
      );
      final firstStopped = expectLater(
        first,
        throwsA(isA<SourceTaskCancelled>()),
      );
      final secondStopped = expectLater(
        second,
        throwsA(isA<SourceTaskCancelled>()),
      );
      await waitForCalls(1);
      contexts.single.requiresDrain = true;
      final firstReceipt = await host.tasks.cancelOwner(
        'first',
        SourceTaskStopReason.superseded,
      );
      await firstStopped;
      await firstReceipt.whenSettled;
      expect(contexts.single.isStopped, isFalse);
      final lastReceipt = await host.tasks.cancelOwner(
        'second',
        SourceTaskStopReason.ownerDisposed,
      );
      await secondStopped;
      await contexts.single.whenStopped.timeout(const Duration(seconds: 2));
      var settled = false;
      lastReceipt.whenSettled.then((_) => settled = true);
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      expect(firstReceipt.sharedResourceCount, 0);
      final next = details.loadComicDetails('123');
      await waitForCalls(2);
      responses[1].complete(result('new'));
      expect((await next).title, 'new');
      responses[0].complete(result('obsolete'));
      await lastReceipt.whenSettled.timeout(const Duration(seconds: 2));
      final cached = await details.loadComicDetails('123');
      expect(cached.title, 'new');
      expect(contexts, hasLength(2));
    },
  );

  test(
    'a forced refresh remains authoritative over an older shared response',
    () async {
      final first = details.loadComicDetails('123');
      final shared = details.loadComicDetails(
        '123',
        taskOrigin: origin('search'),
      );
      await waitForCalls(1);
      final refreshed = details.loadComicDetails('123', forceRefresh: true);
      await waitForCalls(2);
      responses[1].complete(result('refreshed'));
      expect((await refreshed).title, 'refreshed');
      responses[0].complete(result('older'));
      expect((await first).title, 'older');
      expect((await shared).title, 'older');
      expect((await details.loadComicDetails('123')).title, 'refreshed');
      expect(contexts, hasLength(2));
    },
  );

  test(
    'cancelling an initialization subscriber never submits its later script',
    () async {
      final ready = Completer<void>();
      initialize = () => ready.future;
      final pending = details.loadComicDetails(
        '123',
        taskOrigin: origin('search'),
      );
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      final receipt = await host.tasks.cancelOwner(
        'search',
        SourceTaskStopReason.superseded,
      );
      await stopped;
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      ready.complete();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(contexts, isEmpty);
      expect(host.handleFor('one').runtime.engine, same(engine));
    },
  );

  test('cancelled production cannot cache a late success', () async {
    final pending = details.loadComicDetails(
      '123',
      taskOrigin: origin('search'),
    );
    final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
    await waitForCalls(1);
    final receipt = await host.tasks.cancelOwner(
      'search',
      SourceTaskStopReason.superseded,
    );
    await stopped;
    responses[0].complete(result('late'));
    await receipt.whenSettled.timeout(const Duration(seconds: 2));
    await Future<void>.delayed(Duration.zero);
    expect(host.handleFor('one').cache.comicDetailsMemoryCache, isEmpty);
    final next = details.loadComicDetails('123');
    await waitForCalls(2);
    responses[1].complete(result('next'));
    expect((await next).title, 'next');
  });

  test(
    'closing shared input cancels its search without cancelling an unowned subscriber',
    () async {
      final first = details.loadComicDetails(
        '123',
        taskOrigin: origin('search'),
      );
      final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      final other = details.loadComicDetails('123');
      await waitForCalls(1);
      final scope = SourceUiService.instance.scopes.singleWhere(
        (scope) => scope.id == contexts.single.execution.uiScopeId,
      );
      scope.cancel('user');
      await stopped;
      expect(contexts.single.isStopped, isFalse);
      responses.single.complete(result('still used'));
      expect((await other).title, 'still used');
    },
  );

  test(
    'an old runtime response cannot populate the replacement cache',
    () async {
      final oldHandle = host.handleFor('one');
      final pending = details.loadComicDetails('123');
      await waitForCalls(1);
      final replacement = host.recreateSourceRuntime(
        'one',
        expectedHandle: oldHandle,
      );
      responses.single.complete(result('old runtime'));
      expect((await pending).title, 'old runtime');
      expect(replacement.cache.comicDetailsMemoryCache, isEmpty);
    },
  );

  test(
    'task cancellation bypasses plugin-requested runtime recreation',
    () async {
      final handle = host.handleFor('one');
      handle.runtime.sourceMeta = SourceMeta(
        name: 'One',
        key: 'one',
        version: '1',
        supportsAccount: false,
        settingsDefaults: {},
        presentation: {
          'recreateOnStatus': [419],
        },
      );
      handle.dio.httpClientAdapter = _StatusAdapter();
      await handle.httpGateway.sendJsHttpRequest({
        'url': 'https://fixture.test/',
        'http_method': 'GET',
      });
      expect(handle.recreationRequested, isTrue);
      final pending = details.loadComicDetails(
        '123',
        taskOrigin: origin('search'),
      );
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await waitForCalls(1);
      final receipt = await host.tasks.cancelOwner(
        'search',
        SourceTaskStopReason.ownerDisposed,
      );
      await stopped;
      responses.single.complete(result('late'));
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      expect(host.handleFor('one'), same(handle));
      expect(handle.runtime.engine, same(engine));
    },
  );

  test(
    'ordinary detail recovery can use the replacement engine UI scope',
    () async {
      final handle = host.handleFor('one');
      handle.runtime.sourceMeta = SourceMeta(
        name: 'One',
        key: 'one',
        version: '1',
        supportsAccount: false,
        settingsDefaults: {},
        presentation: {
          'recreateOnStatus': [419],
        },
      );
      handle.dio.httpClientAdapter = _StatusAdapter();
      await handle.httpGateway.sendJsHttpRequest({
        'url': 'https://fixture.test/',
        'http_method': 'GET',
      });
      initialize = () async {
        final next = host.handleFor('one');
        if (next.runtime.engine != null) return;
        final replacement = SourceScriptEngine(pluginId: 'one');
        addTearDown(replacement.close);
        replacement.operationGuard = next.runOperation;
        await replacement.execute(
          'globalThis.__hazuki_source={comic:{loadInfo:()=>({id:"123",title:"recovered"})}}',
        );
        next.runtime.engine = replacement;
      };
      final pending = details.loadComicDetails('123');
      await waitForCalls(1);
      responses.single.complete(result('first attempt'));
      expect((await pending).title, 'recovered');
      expect(host.handleFor('one'), isNot(same(handle)));
      expect((await details.loadComicDetails('123')).title, 'recovered');
    },
  );

  test(
    'shared production is detached from the first subscriber UI scope',
    () async {
      final lifetime = SourceTaskCancellation();
      final firstOrigin = SourceTaskOrigin(
        ownerId: 'search',
        groupId: 'query',
        requestSequence: 1,
        cancellation: lifetime,
      );
      late SourceUiScope firstScope;
      final first = SourceUiService.instance.run(() {
        firstScope = SourceUiScope.current!;
        return details.loadComicDetails('123', taskOrigin: firstOrigin);
      });
      final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      final other = details.loadComicDetails('123');
      await waitForCalls(1);
      expect(contexts.single.execution.uiScopeId, isNot(firstScope.id));
      lifetime.cancel(SourceTaskStopReason.ownerDisposed);
      await stopped;
      responses.single.complete(result('surviving'));
      expect((await other).title, 'surviving');
    },
  );
}
