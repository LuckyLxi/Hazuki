import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/content/source_cloud_reading.dart';
import 'package:hazuki/services/source/content/source_reading_progress_uploads.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_runtime_host.dart';
import 'package:hazuki/services/source/runtime/source_runtime_operations.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Operations extends Fake implements SourceRuntimeOperations {
  @override
  Future<void> ensureSourceInitialized(String key) async {}
}

Future<void> _until(bool Function() predicate) async {
  final clock = Stopwatch()..start();
  while (!predicate() && clock.elapsed < const Duration(seconds: 4)) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(predicate(), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHost host;
  late SourceScriptEngine main;
  late SourceCloudReadingCapability cloud;
  late Map<String, Completer<Object?>> replies;
  late List<SourceRuntimeHandle> private;
  late List<String> calls;
  Future<void> Function(SourceRuntimeHandle)? beforeLoad;
  late String privateScript;
  const script =
      'globalThis.__hazuki_source={comic:{loadReadingProgress:id=>sendMessage({id})}}';

  SourceTaskOrigin origin(String owner) =>
      SourceTaskOrigin(ownerId: owner, groupId: 'read', requestSequence: 1);
  Future<void> load(SourceRuntimeHandle handle) async {
    private.add(handle);
    await beforeLoad?.call(handle);
    handle.loadControl!.checkActive();
    final engine = SourceScriptEngine(pluginId: 'one');
    engine.operationGuard = handle.runOperation;
    handle.loadControl!.bindEngine(engine);
    handle.runtime.engine = engine;
    // 与真实 loader 发布实例时一致，监听私有实例故障。
    handle.watchEngine(engine);
    engine.setOperationMessageHandler((message, context) {
      final key = (message as Map)['id'] as String;
      calls.add(key);
      return Future.any<Object?>([
        (replies[key] ??= Completer<Object?>()).future,
        context.whenStopped.then<Object?>((_) {
          context.checkActive();
          return null;
        }),
      ]);
    });
    await handle.loadControl!.execute(engine, privateScript);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    replies = {};
    private = [];
    calls = [];
    beforeLoad = null;
    privateScript = script;
    host = SourceRuntimeHost(
      catalog: const [
        SourceCatalogEntry(key: 'one', name: 'One', fileName: 'one.js'),
        SourceCatalogEntry(key: 'two', name: 'Two', fileName: 'two.js'),
      ],
      defaultSourceKey: 'one',
      secureSessionStorage: MemorySourceSecureSessionStorage(),
      ensureSourceInitialized: (_) async {},
      currentAccountForSource: (_) => null,
      isLoggedForSource: (_) => false,
    );
    await host.activeHandle.session.ensurePrefs();
    await host.activeHandle.session.saveSourceData(
      'one',
      'login_session',
      'account',
    );
    main = SourceScriptEngine(pluginId: 'one');
    main.operationGuard = host.activeHandle.runOperation;
    host.activeHandle.runtime.engine = main;
    await main.execute(script);
    cloud = SourceCloudReadingCapability(
      host,
      _Operations(),
      loadReadRuntime: load,
    );
  });
  tearDown(() async {
    cloud.dispose();
    await cloud.whenSettled;
    host.dispose();
    await main.close();
  });

  test(
    'one private initialization subscriber cancels without cancelling another',
    () async {
      final gate = Completer<void>();
      beforeLoad = (_) => gate.future;
      final first = cloud.loadCloudReadingProgress(
        'one',
        'first',
        taskOrigin: origin('first'),
      );
      final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      final second = cloud.loadCloudReadingProgress(
        'one',
        'second',
        taskOrigin: origin('second'),
      );
      await _until(
        () =>
            host.tasks.activeTasks
                .where((t) => t.method == 'cloud.initialize.wait')
                .length ==
            2,
      );
      final receipt = await host.tasks.cancelOwner(
        'first',
        SourceTaskStopReason.ownerDisposed,
      );
      await stopped.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw StateError('business did not stop'),
      );
      await receipt.whenSettled.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw StateError('resources did not settle'),
      );
      expect(private, hasLength(1));
      expect(private.single.loginCancellation!.isCancelled, isFalse);
      gate.complete();
      await _until(() => calls.contains('second'));
      replies['second']!.complete({'chapterId': 'ep', 'page': 2});
      expect((await second)!['imagePage'], 2);
      expect(calls, ['second']);
    },
  );

  test(
    'a failed private instance is discarded and the next read builds a new one',
    () async {
      final first = cloud.loadCloudReadingProgress(
        'one',
        'a',
        taskOrigin: origin('a'),
      );
      await _until(() => calls.contains('a'));
      replies['a']!.complete({'chapterId': 'ep', 'page': 1});
      expect((await first)!['imagePage'], 1);
      final failed = private.single;

      failed.runtime.engine!.debugInjectFault('internalJob');

      await _until(() => failed.runtime.engine == null);
      final second = cloud.loadCloudReadingProgress(
        'one',
        'b',
        taskOrigin: origin('b'),
      );
      await _until(() => calls.contains('b'));
      replies['b']!.complete({'chapterId': 'ep', 'page': 2});
      expect((await second)!['imagePage'], 2);
      expect(private, hasLength(2));
      await _until(() => failed.isDisposed);
      // 主运行时不受私有实例故障影响。
      expect(await main.evaluate('7'), 7);
    },
  );

  test(
    'last initializer cancellation drains and cannot publish a late candidate',
    () async {
      final gate = Completer<void>();
      beforeLoad = (_) => gate.future;
      final first = cloud.loadCloudReadingProgress(
        'one',
        'first',
        taskOrigin: origin('first'),
      );
      final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => private.isNotEmpty);
      final receipt = await host.tasks.cancelOwner(
        'first',
        SourceTaskStopReason.ownerDisposed,
      );
      var settled = false;
      final drain = receipt.whenSettled.then((_) => settled = true);
      await Future<void>.delayed(Duration.zero);
      expect(settled, isFalse);
      gate.complete();
      await stopped;
      await drain;
      expect(private.single.runtime.engine, isNull);
      expect(private.single.isDisposed, isTrue);
      expect(calls, isEmpty);
      expect(await main.evaluate('7'), 7);
    },
  );

  test(
    'concurrent ready calls keep legacy account identity and both subscriptions',
    () async {
      await host.activeHandle.session.deleteSourceData('one', 'login_session');
      await host.activeHandle.session.saveSourceData('one', 'account', [
        'user',
        'password',
      ]);
      final identity = host.activeHandle.session.loginIdentity;
      final first = cloud.loadCloudReadingProgress('one', 'first');
      final second = cloud.loadCloudReadingProgress('one', 'second');
      await _until(() => calls.length == 2);
      replies['first']!.complete({'chapterId': 'ep', 'page': 1});
      replies['second']!.complete({'chapterId': 'ep', 'page': 2});
      expect(await Future.wait([first, second]), hasLength(2));
      expect(private, hasLength(1));
      expect(host.activeHandle.session.loginIdentity, identity);
    },
  );

  test(
    'cancelling an initialized private call leaves the other call and main engine alive',
    () async {
      final first = cloud.loadCloudReadingProgress(
        'one',
        'first',
        taskOrigin: origin('first'),
      );
      final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      final second = cloud.loadCloudReadingProgress('one', 'second');
      await _until(() => calls.length == 2);
      final receipt = await host.tasks.cancelOwner(
        'first',
        SourceTaskStopReason.user,
      );
      await stopped.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw StateError('business did not stop'),
      );
      await receipt.whenSettled.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw StateError('resources did not settle'),
      );
      replies['second']!.complete({'chapterId': 'ep', 'page': 3});
      expect((await second)!['imagePage'], 3);
      expect(private.single.isDisposed, isFalse);
      expect(await main.evaluate('8'), 8);
      replies['first']!.complete({'chapterId': 'late', 'page': 99});
    },
  );

  test(
    'fallback calls cancel by task without closing the shared main engine',
    () async {
      cloud.dispose();
      await cloud.whenSettled;
      cloud = SourceCloudReadingCapability(host, _Operations());
      main.setOperationMessageHandler((message, context) {
        final key = (message as Map)['id'] as String;
        calls.add(key);
        return Future.any<Object?>([
          (replies[key] ??= Completer<Object?>()).future,
          context.whenStopped.then<Object?>((_) {
            context.checkActive();
            return null;
          }),
        ]);
      });
      final pending = cloud.loadCloudReadingProgress(
        'one',
        'first',
        taskOrigin: origin('first'),
      );
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => calls.isNotEmpty);
      final receipt = await host.tasks.cancelOwner(
        'first',
        SourceTaskStopReason.user,
      );
      await stopped.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw StateError('business did not stop'),
      );
      await receipt.whenSettled.timeout(
        const Duration(seconds: 3),
        onTimeout: () => throw StateError('resources did not settle'),
      );
      expect(await main.evaluate('9'), 9);
      expect(private, isEmpty);
      replies['first']!.complete(null);
    },
  );

  test(
    'private synchronous script cancellation interrupts only the cloud invocation',
    () async {
      privateScript =
          'globalThis.__hazuki_source={comic:{loadReadingProgress:id=>{sendMessage({id});while(true){}}}}';
      final pending = cloud.loadCloudReadingProgress(
        'one',
        'first',
        taskOrigin: origin('first'),
      );
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => calls.isNotEmpty);
      final receipt = await host.tasks.cancelOwner(
        'first',
        SourceTaskStopReason.user,
      );
      await stopped.timeout(const Duration(seconds: 2));
      await receipt.whenSettled.timeout(const Duration(seconds: 2));
      expect(await private.single.runtime.engine!.evaluate('13'), 13);
      expect(await main.evaluate('14'), 14);
    },
  );

  test(
    'switching source stops cloud reading while admitted upload and reading lease continue',
    () async {
      final old = host.activeHandle;
      final reading = host.acquireReaderSession('one');
      final uploads = SourceReadingProgressUploads(host);
      addTearDown(() async {
        uploads.dispose();
        await uploads.whenSettled;
      });
      main.setOperationMessageHandler(
        (_, context) => (replies['upload'] ??= Completer<Object?>()).future,
      );
      await main.execute(
        'globalThis.__hazuki_source.comic.onReadingProgress=p=>sendMessage(p)',
      );
      final upload = uploads.report({'page': 1}, 'one');
      final pending = cloud.loadCloudReadingProgress('one', 'first');
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await _until(
        () => calls.contains('first') && replies.containsKey('upload'),
      );
      await host.activateSource('two');
      await stopped;
      await cloud.whenSettled;
      expect(host.handleFor('one'), same(old));
      expect(private.single.isDisposed, isTrue);
      replies['upload']!.complete(null);
      await upload;
      expect(await main.evaluate('15'), 15);
      reading.close();
      await old.whenDisposed;
    },
  );

  Future<void> historyMode() async {
    await Future<void>.delayed(Duration.zero);
    privateScript =
        'globalThis.__hazuki_source={comic:{loadReadingProgress:()=>null,loadReadingHistory:page=>sendMessage({id:"history"+page})}}';
    await main.execute(
      'globalThis.__hazuki_source.comic.loadReadingHistory=()=>({items:[]})',
    );
  }

  test(
    'history subscribers share pages and cancelling one leaves the other intact',
    () async {
      await historyMode();
      final first = cloud.refreshCloudReadingHistory(
        'one',
        taskOrigin: origin('first'),
      );
      final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      final second = cloud.refreshCloudReadingHistory(
        'one',
        taskOrigin: origin('second'),
      );
      await _until(
        () =>
            calls.contains('history1') &&
            host.tasks.activeTasks
                    .where((t) => t.method == 'cloud.history')
                    .length ==
                2,
      );
      final receipt = await host.tasks.cancelOwner(
        'first',
        SourceTaskStopReason.user,
      );
      await stopped;
      await receipt.whenSettled;
      replies['history1']!.complete({
        'items': [
          {
            'comic': {'id': 'comic', 'title': 'Comic'},
            'progress': {'chapterId': 'ep', 'page': 2},
          },
        ],
        'maxPage': 2,
      });
      await _until(() => calls.contains('history2'));
      replies['history2']!.complete({'items': []});
      expect((await second).single.id, 'comic');
      expect(calls, ['history1', 'history2']);
    },
  );

  test(
    'last history subscriber stops paging and old cleanup cannot remove new work',
    () async {
      await historyMode();
      final first = cloud.refreshCloudReadingHistory(
        'one',
        taskOrigin: origin('first'),
      );
      final stopped = expectLater(first, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => calls.contains('history1'));
      final receipt = await host.tasks.cancelOwner(
        'first',
        SourceTaskStopReason.superseded,
      );
      await stopped;
      await receipt.whenSettled;
      final old = replies.remove('history1')!;
      final next = cloud.refreshCloudReadingHistory(
        'one',
        taskOrigin: origin('next'),
      );
      await _until(() => calls.length == 2);
      old.complete({'items': []});
      replies['history1']!.complete({'items': []});
      expect(await next, isEmpty);
      expect(calls, ['history1', 'history1']);
      expect(await main.evaluate('11'), 11);
    },
  );

  test(
    'account retirement settles the private worker and rejects old results',
    () async {
      final pending = cloud.loadCloudReadingProgress('one', 'first');
      final stopped = expectLater(pending, throwsA(isA<SourceTaskCancelled>()));
      await _until(() => calls.isNotEmpty);
      final old = private.single;
      await host.activeHandle.session.saveSourceData(
        'one',
        'login_session',
        'next',
      );
      host.notifyActiveRuntimeChanged('one');
      await stopped;
      await cloud.whenSettled;
      expect(old.isDisposed, isTrue);
      expect(await main.evaluate('10'), 10);
      replies['first']!.complete({'chapterId': 'late', 'page': 99});
    },
  );
}
